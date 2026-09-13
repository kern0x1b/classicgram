#import "TGInviteLinksViewController.h"
#import "TGInviteLinksViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGInviteLinkService.h"
#import "TGActionSheetIndexBuilder.h"
#import "TGAlertView.h"

@implementation TGInviteLinksViewController (Creation)

#pragma mark - creating a link

- (void)createLink {
	if (!self.canManage)
		return;

	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:TGL(@"InviteLink.Create.Title", @"New Invite Link")
					  delegate:self
				   otherTitles:@[ TGL(@"InviteLink.PermanentLink", @"Permanent Link"),
					   TGL(@"InviteLink.Create.TimeLimitExpiryDate", @"Expiry Date"),
					   TGL(@"InviteLink.Create.UsersLimitNumberOfUsers", @"Number of Uses"),
					   TGL(@"InviteLink.Create.RequestApproval", @"Request Admin Approval"),
					   TGL(@"InviteLink.Create.Fee", @"Paid Subscription") ]
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	self.createSheet = sheet;

	UIBarButtonItem *item = self.navigationItem.rightBarButtonItem;
	if (item && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
		[sheet showFromBarButtonItem:item animated:YES];
	else
		[sheet showInView:[self sheetHostView]];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
	if (sheet != self.createSheet)
		return;
	self.createSheet = nil;
	if (index < 0 || index == sheet.cancelButtonIndex)
		return;

	if (index == 1) {
		[self presentExpiryPickerForLink:nil];
		return;
	}
	if (index == 2) {
		[self askUsesForLink:nil];
		return;
	}
	if (index == 3) {
		[self createLinkExpiring:0 limit:0 requiresApproval:YES];
		return;
	}
	if (index == 4) {
		[self askSubscriptionPrice];
		return;
	}

	[self createLinkExpiring:0 limit:0 requiresApproval:NO];
}

- (void)askSubscriptionPrice {
	UIAlertView *alert = [[TGAlertView alloc]
			initWithTitle:TGL(@"InviteLink.Create.Fee", @"Paid Subscription")
				  message:TGL(@"InviteLink.Create.FeeInfo", @"Charge a subscription fee from people joining your channel via this link. [Learn More >]()")
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Common.Create", @"Create"), nil];
	alert.tag = kInviteSubscriptionPriceAlertTag;
	if ([alert respondsToSelector:@selector(setAlertViewStyle:)]) {
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
		[alert textFieldAtIndex:0].keyboardType = UIKeyboardTypeNumberPad;
		[alert textFieldAtIndex:0].placeholder = TGL(@"InviteLink.Create.Subscription.Placeholder", @"Stars per month");
	}
	dispatch_async(dispatch_get_main_queue(), ^{
		[alert show];
	});
}

- (void)createSubscriptionLinkWithStarCount:(int64_t)starCount {
	if (self.busy)
		return;
	if (starCount <= 0) {
		[self failedWithMessage:TGL(@"InviteLink.Create.Subscription.InvalidAmount", @"Enter a number of Stars greater than zero.")];
		return;
	}
	self.busy = YES;
	__weak typeof(self) weakSelf = self;
	void (^created)(NSDictionary *) = ^(NSDictionary *link) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		strongSelf.busy = NO;
		if (!link) {
			[strongSelf failedWithMessage:TGL(@"InviteLink.SubscriptionCouldNotBeCreated", @"The subscription link could not be created.")];
			return;
		}
		[strongSelf reload];
	};
	[TGInviteLinkService createSubscriptionInviteLinkForChat:self.chatId name:@"" starCount:starCount completion:created];
}

- (void)createLinkExpiring:(NSInteger)expirationDate limit:(NSInteger)memberLimit
		  requiresApproval:(BOOL)requiresApproval {
	if (self.busy)
		return;
	self.busy = YES;
	NSInteger limit = requiresApproval ? 0 : memberLimit;

	__weak typeof(self) weakSelf = self;
	[TGInviteLinkService createInviteLinkForChat:self.chatId
											name:@""
								  expirationDate:expirationDate
									 memberLimit:limit
								requiresApproval:requiresApproval
									  completion:^(NSDictionary *link) {
										  __strong typeof(weakSelf) strongSelf = weakSelf;
										  strongSelf.busy = NO;
										  if (!link) {
											  [strongSelf failedWithMessage:TGL(@"InviteLink.CouldNotBeCreated", @"The link could not be created.")];
											  return;
										  }
										  [strongSelf reload];
									  }];
}

@end

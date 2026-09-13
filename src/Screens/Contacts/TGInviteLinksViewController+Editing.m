#import "TGInviteLinksViewController.h"
#import "TGInviteLinksViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGInviteLinkService.h"
#import "TGInviteLinkSubscriptionGuard.h"
#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "TGStringTruncation.h"

static const NSInteger kInviteRenameAlertTag = 7812;
static const NSInteger kInviteUsesAlertTag = 7814;
static const NSTimeInterval kInviteLinkMaxExpiryTimestamp = 2145916800.0;

static NSDate *TGInviteLinkMaxExpiryDate(void) {
	return [NSDate dateWithTimeIntervalSince1970:kInviteLinkMaxExpiryTimestamp];
}

static NSInteger TGInviteLinkExpiryTimestamp(NSDate *date) {
	NSTimeInterval seconds = [date timeIntervalSince1970];
	if (seconds > kInviteLinkMaxExpiryTimestamp)
		seconds = kInviteLinkMaxExpiryTimestamp;
	return (NSInteger)seconds;
}

@implementation TGInviteLinksViewController (Editing)

#pragma mark - editing a link

- (NSArray *)editSheetActionsForLink:(NSDictionary *)link {
	BOOL requiresApproval = [link[@"requiresApproval"] boolValue];
	BOOL isSubscription = TGInviteLinkIsSubscriptionLink(link);
	NSMutableArray *actions = [NSMutableArray array];
	TGActionSheetAction *sheetAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"VoiceChat.ChangeName", @"Change Name") action:@"name"];
	[actions addObject:sheetAction];
	if (!isSubscription) {
		sheetAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"InviteLink.Create.TimeLimitExpiryDate", @"Expiry Date") action:@"expiry"];
		[actions addObject:sheetAction];
		sheetAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"InviteLink.Create.TimeLimitExpiryDateNever", @"Never") action:@"never"];
		[actions addObject:sheetAction];
		if (!requiresApproval) {
			sheetAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"InviteLink.Create.UsersLimitNumberOfUsers", @"Number of Uses") action:@"uses"];
			[actions addObject:sheetAction];
			sheetAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"InviteLink.Create.UsersLimitNoLimit", @"No Limit") action:@"nolimit"];
			[actions addObject:sheetAction];
		}
		NSString *approvalTitle = requiresApproval ? TGL(@"InviteLink.RequireAdminApprovalToJoin", @"Require Admin Approval to Join") : TGL(@"InviteLink.Create.RequestApproval", @"Request Admin Approval");
		sheetAction = [[TGActionSheetAction alloc] initWithTitle:approvalTitle action:@"toggleapproval"];
		[actions addObject:sheetAction];
	}
	sheetAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"Common.Cancel", @"Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel];
	[actions addObject:sheetAction];
	return actions;
}

- (void)applyEditAction:(NSString *)action toLink:(NSDictionary *)editing {
	NSInteger expires = [editing[@"expirationDate"] integerValue];
	NSInteger limit = [editing[@"memberLimit"] integerValue];
	BOOL requiresApproval = [editing[@"requiresApproval"] boolValue];
	if ([action isEqualToString:@"never"])
		expires = 0;
	else if ([action isEqualToString:@"nolimit"])
		limit = 0;
	else if ([action isEqualToString:@"toggleapproval"])
		requiresApproval = !requiresApproval;

	[self applyEditToLink:editing
					 name:[self nameOfLink:editing]
		   expirationDate:expires
			  memberLimit:limit
		 requiresApproval:requiresApproval];
}

- (void)showEditSheetForLink:(NSDictionary *)link {
	NSString *url = link[@"link"];
	if (![url isKindOfClass:[NSString class]] || !url.length)
		return;
	self.editingLink = link;

	__weak typeof(self) weakSelf = self;
	TGActionSheet *sheet = [[TGActionSheet alloc]
		initWithTitle:[self titleForLink:link]
			  actions:[self editSheetActionsForLink:link]
		  actionBlock:^(__unused id target, NSString *action) {
			  __strong typeof(weakSelf) strongSelf = weakSelf;
			  strongSelf.currentActionSheet = nil;
			  NSDictionary *editing = strongSelf.editingLink;
			  if (!editing || [action isEqualToString:@"cancel"]) {
				  strongSelf.editingLink = nil;
				  return;
			  }
			  if ([action isEqualToString:@"name"]) {
				  [strongSelf askNameForLink:editing];
				  return;
			  }
			  if ([action isEqualToString:@"expiry"]) {
				  [strongSelf presentExpiryPickerForLink:editing];
				  return;
			  }
			  if ([action isEqualToString:@"uses"]) {
				  [strongSelf askUsesForLink:editing];
				  return;
			  }
			  strongSelf.editingLink = nil;
			  [strongSelf applyEditAction:action toLink:editing];
		  }
			   target:self];

	self.currentActionSheet = sheet;
	UIView *host = [self sheetHostView];
	dispatch_async(dispatch_get_main_queue(), ^{
		[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(host.bounds), CGRectGetMidY(host.bounds), 1, 1)
						 inView:host];
	});
}

- (NSString *)nameOfLink:(NSDictionary *)link {
	NSString *name = link[@"name"];
	return [name isKindOfClass:[NSString class]] ? name : @"";
}

- (void)askUsesForLink:(NSDictionary *)link {
	self.editingLink = link;
	NSInteger limit = [link[@"memberLimit"] integerValue];
	UIAlertView *alert = [[TGAlertView alloc]
			initWithTitle:TGL(@"InviteLink.Create.UsersLimit", @"Limit By Number Of Users")
				  message:TGL(@"InviteLink.Create.UsersLimitInfo", @"You can make the link expire after it has been used for a certain number of times.")
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Conversation.LinkDialogSave", @"Save"), nil];
	alert.tag = kInviteUsesAlertTag;
	if ([alert respondsToSelector:@selector(setAlertViewStyle:)]) {
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
		UITextField *field = [alert textFieldAtIndex:0];
		field.keyboardType = UIKeyboardTypeNumberPad;
		field.placeholder = TGL(@"InviteLink.Create.UsersLimitNumberOfUsers", @"Number of Uses");
		if (limit > 0)
			field.text = [NSString stringWithFormat:@"%d", (int)limit];
	}
	dispatch_async(dispatch_get_main_queue(), ^{
		[alert show];
	});
}

- (void)presentExpiryPickerForLink:(NSDictionary *)link {
	if (self.expiryPanel)
		return;
	self.editingLink = link;
	self.createSheet = nil;

	CGRect b = self.view.bounds;
	CGFloat panelHeight = 260;
	UIView *panel = [[UIView alloc] initWithFrame:
			CGRectMake(0, b.size.height, b.size.width, panelHeight)];
	panel.backgroundColor = [UIColor whiteColor];
	panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

	UIToolbar *bar = [[UIToolbar alloc] initWithFrame:
			CGRectMake(0, 0, b.size.width, 44)];
	bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	UIBarButtonItem *cancel = [[UIBarButtonItem alloc]
		initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
							 target:self
							 action:@selector(dismissExpiryPicker)];
	UIBarButtonItem *space = [[UIBarButtonItem alloc]
		initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
							 target:nil
							 action:nil];
	UIBarButtonItem *done = [[UIBarButtonItem alloc]
		initWithBarButtonSystemItem:UIBarButtonSystemItemDone
							 target:self
							 action:@selector(commitExpiryPicker)];
	bar.items = @[ cancel, space, done ];
	[panel addSubview:bar];

	NSInteger existing = [link[@"expirationDate"] integerValue];
	UIDatePicker *picker = [[UIDatePicker alloc] initWithFrame:
			CGRectMake(0, 44, b.size.width, panelHeight - 44)];
	picker.datePickerMode = UIDatePickerModeDateAndTime;
	picker.minuteInterval = 5;
	picker.minimumDate = [NSDate dateWithTimeIntervalSinceNow:60];
	picker.maximumDate = TGInviteLinkMaxExpiryDate();
	picker.date = existing > 0
		? [NSDate dateWithTimeIntervalSince1970:existing]
		: [NSDate dateWithTimeIntervalSinceNow:60 * 60 * 24];
	picker.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[panel addSubview:picker];

	self.expiryPicker = picker;
	self.expiryPanel = panel;
	[self.view addSubview:panel];
	[UIView animateWithDuration:0.25 animations:^{
		panel.frame = CGRectMake(0, b.size.height - panelHeight,
			b.size.width, panelHeight);
	}];
}

- (void)dismissExpiryPicker {
	UIView *panel = self.expiryPanel;
	self.expiryPanel = nil;
	self.expiryPicker = nil;
	self.editingLink = nil;
	if (!panel)
		return;
	CGRect b = self.view.bounds;
	[UIView animateWithDuration:0.25
		animations:^{
			panel.frame = CGRectMake(0, b.size.height, b.size.width, panel.frame.size.height);
		}
		completion:^(BOOL finished) {
			[panel removeFromSuperview];
		}];
}

- (void)commitExpiryPicker {
	NSDictionary *link = self.editingLink;
	NSDate *chosen = self.expiryPicker.date;
	UIView *panel = self.expiryPanel;
	self.expiryPanel = nil;
	self.expiryPicker = nil;
	self.editingLink = nil;
	[panel removeFromSuperview];
	if (!chosen)
		return;
	if (!link) {
		[self createLinkExpiring:TGInviteLinkExpiryTimestamp(chosen)
						   limit:0
				requiresApproval:NO];
		return;
	}
	[self applyEditToLink:link
					 name:[self nameOfLink:link]
		   expirationDate:TGInviteLinkExpiryTimestamp(chosen)
			  memberLimit:[link[@"memberLimit"] integerValue]
		 requiresApproval:[link[@"requiresApproval"] boolValue]];
}

- (void)askNameForLink:(NSDictionary *)link {
	self.editingLink = link;
	UIAlertView *alert = [[TGAlertView alloc]
			initWithTitle:TGL(@"InviteLink.Create.LinkNameTitle", @"Link Name")
				  message:TGL(@"InviteLink.Create.LinkNameInfo", @"Name this link.")
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Conversation.LinkDialogSave", @"Save"), nil];
	alert.tag = kInviteRenameAlertTag;
	if ([alert respondsToSelector:@selector(setAlertViewStyle:)]) {
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
		[alert textFieldAtIndex:0].text = [self nameOfLink:link];
	}
	dispatch_async(dispatch_get_main_queue(), ^{
		[alert show];
	});
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (alertView.tag == kInviteSubscriptionPriceAlertTag) {
		if (buttonIndex == alertView.cancelButtonIndex)
			return;
		if (![alertView respondsToSelector:@selector(textFieldAtIndex:)])
			return;
		int64_t starCount = [[alertView textFieldAtIndex:0].text longLongValue];
		[self createSubscriptionLinkWithStarCount:starCount];
		return;
	}

	if (alertView.tag == kInviteUsesAlertTag) {
		NSDictionary *link = self.editingLink;
		self.editingLink = nil;
		if (buttonIndex == alertView.cancelButtonIndex)
			return;
		if (![alertView respondsToSelector:@selector(textFieldAtIndex:)])
			return;
		NSInteger uses = [[alertView textFieldAtIndex:0].text integerValue];
		if (uses < 0)
			uses = 0;
		if (!link) {
			[self createLinkExpiring:0 limit:uses requiresApproval:NO];
			return;
		}
		[self applyEditToLink:link
						 name:[self nameOfLink:link]
			   expirationDate:[link[@"expirationDate"] integerValue]
				  memberLimit:uses
			 requiresApproval:[link[@"requiresApproval"] boolValue]];
		return;
	}

	if (alertView.tag != kInviteRenameAlertTag)
		return;
	NSDictionary *link = self.editingLink;
	self.editingLink = nil;
	if (buttonIndex == alertView.cancelButtonIndex || !link)
		return;
	if (![alertView respondsToSelector:@selector(textFieldAtIndex:)])
		return;

	NSString *name = [[alertView textFieldAtIndex:0].text
		stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!name)
		name = @"";
	if (name.length > 32)
		name = TGSafeSubstringToIndex(name, 32);

	if (TGInviteLinkIsSubscriptionLink(link)) {
		[self applySubscriptionRenameToLink:link name:name];
		return;
	}
	[self applyEditToLink:link
					 name:name
		   expirationDate:[link[@"expirationDate"] integerValue]
			  memberLimit:[link[@"memberLimit"] integerValue]
		 requiresApproval:[link[@"requiresApproval"] boolValue]];
}

- (void)applySubscriptionRenameToLink:(NSDictionary *)link name:(NSString *)name {
	NSString *url = link[@"link"];
	if (![url isKindOfClass:[NSString class]] || !url.length || self.busy)
		return;
	self.busy = YES;
	__weak typeof(self) weakSelf = self;
	[TGInviteLinkService editSubscriptionInviteLink:url inChat:self.chatId name:name ?: @""
										 completion:^(NSDictionary *updated) {
											 __strong typeof(weakSelf) strongSelf = weakSelf;
											 strongSelf.busy = NO;
											 if (!updated) {
												 [strongSelf failedWithMessage:TGL(@"InviteLink.CouldNotBeChanged", @"The link could not be changed.")];
												 return;
											 }
											 [strongSelf reload];
										 }];
}

- (void)applyEditToLink:(NSDictionary *)link
				   name:(NSString *)name
		 expirationDate:(NSInteger)expirationDate
			memberLimit:(NSInteger)memberLimit
	   requiresApproval:(BOOL)requiresApproval {
	NSString *url = link[@"link"];
	if (![url isKindOfClass:[NSString class]] || !url.length)
		return;
	if (self.busy)
		return;
	self.busy = YES;

	if (requiresApproval)
		memberLimit = 0;

	__weak typeof(self) weakSelf = self;
	[TGInviteLinkService editInviteLink:url
								 inChat:self.chatId
								   name:name ?: @""
						 expirationDate:expirationDate
							memberLimit:memberLimit
					   requiresApproval:requiresApproval
							 completion:^(NSDictionary *updated) {
								 __strong typeof(weakSelf) strongSelf = weakSelf;
								 strongSelf.busy = NO;
								 if (!updated) {
									 [strongSelf failedWithMessage:TGL(@"InviteLink.CouldNotBeChanged", @"The link could not be changed.")];
									 return;
								 }
								 [strongSelf reload];
							 }];
}

@end

#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGTermsOfServiceUpdateViewController.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGClient.h"
#import "TGClient+Account.h"
#import "TGClient+Privacy.h"
#import "TGTheme.h"
#import "TGSecurityStepViewController.h"
#import "TGRichText.h"
#import "TGWebViewController.h"

static const NSInteger kDeclineConfirmAlertTag = 1;

static void TGTermsOfServiceComplain(NSString *message) {
	UIAlertView *alert = [[UIAlertView alloc]
			initWithTitle:nil
				  message:message
				 delegate:nil
		cancelButtonTitle:TGL(@"Common.OK", @"OK")
		otherButtonTitles:nil];
	[alert show];
}

@interface TGTermsOfServiceBodyView : UIView
@property (nonatomic, strong) TGRichTextLayout *richLayout;
@property (nonatomic, copy) void (^onTapLink)(NSDictionary *link);
@end

@implementation TGTermsOfServiceBodyView

- (instancetype)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		self.backgroundColor = [UIColor clearColor];
		self.userInteractionEnabled = YES;
		UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
			initWithTarget:self action:@selector(handleTap:)];
		[self addGestureRecognizer:tap];
	}
	return self;
}

- (void)drawRect:(CGRect)rect {
	[self.richLayout drawInRect:self.bounds];
}

- (void)handleTap:(UITapGestureRecognizer *)recognizer {
	if (!self.richLayout || !self.onTapLink)
		return;
	CGPoint point = [recognizer locationInView:self];
	NSDictionary *link = [self.richLayout linkAtPoint:point inRect:self.bounds];
	if (link)
		self.onTapLink(link);
}

@end

@interface TGTermsOfServiceUpdateViewController () <UIAlertViewDelegate>
@property (nonatomic, copy) NSString *termsId;
@property (nonatomic, strong) NSAttributedString *bodyText;
@end

@implementation TGTermsOfServiceUpdateViewController

+ (UIFont *)bodyFont {
	return [UIFont systemFontOfSize:14];
}

- (instancetype)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		self.termsId = [[TGClient shared] pendingTermsOfServiceId];
		NSString *text = [[TGClient shared] pendingTermsOfServiceText];
		NSArray *entities = [[TGClient shared] pendingTermsOfServiceEntities];
		NSInteger minAge = [[TGClient shared] pendingTermsOfServiceMinAge];

		TGTheme *theme = [TGTheme shared];
		TGRichTextPalette *palette = [TGRichTextPalette
			paletteWithFont:[TGTermsOfServiceUpdateViewController bodyFont]
					 colour:[theme cellDetailColour]
				 linkColour:[theme groupedActionColour]
			   accentColour:[theme groupedActionColour]];
		palette.underlineLinks = YES;

		NSMutableString *combined = [NSMutableString string];
		if (text.length > 0)
			[combined appendString:text];
		if (minAge > 0) {
			if (combined.length > 0)
				[combined appendString:@"\n\n"];
			[combined appendFormat:
					TGL(@"Login.TermsOfServiceMinAgeFormat", @"You must be at least %d years old to use Telegram."),
				(int)minAge];
		}
		self.bodyText = TGRichTextBuild(combined, entities, palette, YES);
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"Login.TermsOfServiceHeader", @"Terms of Service");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.rowHeight = 44;

	self.navigationItem.rightBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"Call.Accept", @"Accept") bold:YES
									   target:self
									   action:@selector(acceptTapped)];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 1;
}

- (CGFloat)footerContentWidth:(CGFloat)tableWidth {
	CGFloat width = tableWidth > 0 ? tableWidth : [UIScreen mainScreen].bounds.size.width;
	return MAX(40.0f, width - 30.0f);
}

- (TGRichTextLayout *)bodyLayoutForWidth:(CGFloat)tableWidth {
	if (!self.bodyText.length)
		return nil;
	return [TGRichTextLayout layoutWithText:self.bodyText
									   width:[self footerContentWidth:tableWidth]
									maxLines:0
								   alignment:NSTextAlignmentLeft
							  expandedBlocks:nil];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	TGRichTextLayout *layout = [self bodyLayoutForWidth:tableView.bounds.size.width];
	return layout ? layout.size.height + 14 : 1;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	TGRichTextLayout *layout = [self bodyLayoutForWidth:tableView.bounds.size.width];
	if (!layout)
		return nil;

	CGFloat width = tableView.bounds.size.width > 0
		? tableView.bounds.size.width
		: [UIScreen mainScreen].bounds.size.width;
	CGFloat contentWidth = [self footerContentWidth:width];
	CGFloat height = layout.size.height + 14;

	UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
	container.backgroundColor = [UIColor clearColor];
	container.autoresizingMask = UIViewAutoresizingFlexibleWidth;

	TGTermsOfServiceBodyView *body = [[TGTermsOfServiceBodyView alloc]
		initWithFrame:CGRectMake(15, 7, contentWidth, layout.size.height)];
	body.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	body.richLayout = layout;
	__weak typeof(self) weakSelf = self;
	body.onTapLink = ^(NSDictionary *link) {
		[weakSelf openTermsLink:link];
	};
	[container addSubview:body];
	return container;
}

- (void)openTermsLink:(NSDictionary *)link {
	NSString *kind = link[TGRichLinkKindKey];
	NSString *value = link[TGRichLinkValueKey];
	if (![kind isEqualToString:@"url"] || ![value isKindOfClass:NSString.class] || !value.length)
		return;
	[TGWebViewController openURLString:value fromViewController:self];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"decline"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"decline"];
	[TGIcons actionButtonInCell:cell
						  title:TGL(@"Call.Decline", @"Decline")
						   kind:TGActionButtonKindDestructive
						 target:self
						 action:@selector(confirmDecline)];
	return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return TGActionRowHeight();
}

- (void)acceptTapped {
	self.navigationItem.rightBarButtonItem.enabled = NO;
	NSString *termsId = self.termsId;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] acceptTermsOfService:termsId completion:^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			strongSelf.navigationItem.rightBarButtonItem.enabled = YES;
			TGTermsOfServiceComplain(TGL(@"Login.UnknownError", @"An error occurred, please try again later."));
			return;
		}
		[[TGClient shared] clearPendingTermsOfService];
		[strongSelf dismissViewControllerAnimated:YES completion:nil];
	}];
}

- (void)confirmDecline {
	UIAlertView *alert = [[UIAlertView alloc]
			initWithTitle:TGL(@"DeleteAccount.ConfirmationAlertDelete", @"Delete Account")
				  message:TGL(@"DeleteAccount.ConfirmationAlertText", @"All your chats, messages and contacts on Telegram will be lost. This cannot be undone.")
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Common.Delete", @"Delete"), nil];
	alert.tag = kDeclineConfirmAlertTag;
	[alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (alertView.tag != kDeclineConfirmAlertTag)
		return;
	if (buttonIndex == alertView.cancelButtonIndex)
		return;
	[self beginAccountDeletion];
}

- (void)beginAccountDeletion {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] passwordStateWithCompletion:^(NSDictionary *state) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (![state isKindOfClass:[NSDictionary class]]) {
			TGTermsOfServiceComplain(TGL(@"DeleteAccount.CouldNotBeDeletedMessage", @"The account could not be deleted. Please try again later."));
			return;
		}
		if ([state[@"hasPassword"] boolValue]) {
			[strongSelf askAccountDeletionPassword];
			return;
		}
		[strongSelf deleteAccountWithPassword:@""];
	}];
}

- (void)askAccountDeletionPassword {
	__weak typeof(self) weakSelf = self;
	TGSecurityStepViewController *step = [[TGSecurityStepViewController alloc] init];
	step.stepTitle = TGL(@"LoginPassword.PasswordPlaceholder", @"Password");
	step.stepCaption = TGL(@"TwoStepAuth.EnterPasswordPassword", @"Your current password");
	step.placeholder = TGL(@"LoginPassword.PasswordPlaceholder", @"Password");
	step.footerText = TGL(@"DeleteAccount.EnterPasswordFooter", @"Enter your password to permanently delete your account.");
	step.actionTitle = TGL(@"DeleteAccount.ConfirmationAlertDelete", @"Delete Account");
	step.onSubmit = ^(TGSecurityStepViewController *sender, NSString *text) {
		if (!text.length) {
			[sender refuseWithMessage:TGL(@"TwoStepAuth.PleaseEnterYourPassword", @"Please enter your password.")];
			return;
		}
		[sender setBusy:YES];
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf deleteAccountWithPassword:text step:sender];
	};
	[self.navigationController pushViewController:step animated:YES];
}

- (void)deleteAccountWithPassword:(NSString *)password {
	[self deleteAccountWithPassword:password step:nil];
}

- (void)deleteAccountWithPassword:(NSString *)password step:(TGSecurityStepViewController *)step {
	[[TGClient shared] deleteAccountWithReason:@"Decline ToS update"
									   password:password
									 completion:^(BOOL ok) {
		if (ok)
			return;
		if (step)
			[step refuseWithMessage:TGL(@"TwoStepAuth.ThatPasswordIsWrong", @"That password is wrong.")];
		else
			TGTermsOfServiceComplain(TGL(@"DeleteAccount.CouldNotBeDeletedMessage", @"The account could not be deleted. Please try again later."));
	}];
}

@end

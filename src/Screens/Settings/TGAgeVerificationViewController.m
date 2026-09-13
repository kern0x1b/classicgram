#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGAgeVerificationViewController.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGClient.h"
#import "TGClient+ChatState.h"
#import "TGTheme.h"
#import "TGChatViewController.h"

@interface TGAgeVerificationViewController ()
@property (nonatomic, copy) NSString *bodyText;
@property (nonatomic, copy) NSString *botUsername;
@property (nonatomic, assign) BOOL requestingChat;
@end

@implementation TGAgeVerificationViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"AgeVerification.Title", @"Age Verification");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.rowHeight = 44;

	self.navigationItem.leftBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"Common.Done", @"Done") bold:YES
									   target:self
									   action:@selector(doneTapped)];

	NSInteger minAge = [[TGClient shared] ageVerificationMinAge];
	NSString *country = [[TGClient shared] ageVerificationCountry];
	self.botUsername = [[TGClient shared] ageVerificationBotUsername];

	NSString *format = TGL(@"AgeVerification.Text",
		@"To view sensitive content, you must confirm you are at least %ld years old.");
	if (country.length) {
		NSString *countryKey = [NSString stringWithFormat:@"AgeVerification.Text.%@", country];
		NSString *countryFormat = TGLocalizedString(countryKey, @"");
		if (countryFormat.length)
			format = countryFormat;
	}
	self.bodyText = [NSString stringWithFormat:format, (long)minAge];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)doneTapped {
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.botUsername.length ? 1 : 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	return [[TGTheme shared] groupedCommentHeightForText:self.bodyText width:tableView.bounds.size.width];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	return [[TGTheme shared] groupedCommentViewWithText:self.bodyText width:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"bot"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"bot"];
	[[TGTheme shared] styleCell:cell];
	[TGIcons actionButtonInCell:cell
						  title:TGL(@"AgeVerification.Verify", @"Verify My Age")
						   kind:TGActionButtonKindNeutral
						 target:self
						 action:@selector(verifyPressed)];
	return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return TGActionRowHeight();
}

- (void)verifyPressed {
	if (!self.botUsername.length || !self.navigationController || self.requestingChat)
		return;
	self.requestingChat = YES;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] chatWithUsername:self.botUsername
							 completion:^(int64_t chatId, NSString *title) {
								 TGAgeVerificationViewController *strongSelf = weakSelf;
								 if (!strongSelf)
									 return;
								 strongSelf.requestingChat = NO;
								 if (!chatId)
									 return;
								 TGChatViewController *chat = [[TGChatViewController alloc] init];
								 chat.chatId = chatId;
								 chat.chatTitle = title.length ? title : strongSelf.botUsername;
								 [strongSelf.navigationController pushViewController:chat animated:YES];
							 }];
}

@end

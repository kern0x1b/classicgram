#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGFrozenAccountViewController.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGClient.h"
#import "TGClient+Account.h"
#import "TGTheme.h"
#import "TGWebViewController.h"

@interface TGFrozenAccountViewController ()
@property (nonatomic, copy) NSString *appealFooterText;
@end

@implementation TGFrozenAccountViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"FrozenAccount.Title", @"Your Account is Frozen");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.rowHeight = 44;

	self.navigationItem.leftBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"Common.Done", @"Done") bold:YES
									   target:self
									   action:@selector(doneTapped)];

	[self refreshAppealFooterText];

	__weak typeof(self) weakSelf = self;
	self.frozenStateObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGFreezeStateDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					(void)note;
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf frozenStateChanged];
				}];
}

- (void)dealloc {
	if (_frozenStateObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_frozenStateObserverToken];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)refreshAppealFooterText {
	long long deletionDate = [[TGClient shared] freezeDeletionDate];
	NSString *deletionText = deletionDate > 0
		? [NSDateFormatter localizedStringFromDate:
				  [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)deletionDate]
										 dateStyle:NSDateFormatterMediumStyle
										 timeStyle:NSDateFormatterNoStyle]
		: @"";
	self.appealFooterText = deletionText.length
		? [NSString stringWithFormat:
				  TGL(@"FrozenAccount.Appeal.Text",
					  @"Appeal before %@, or your account will be deleted."),
			  deletionText]
		: TGL(@"FrozenAccount.SubmitAppeal", @"Submit an Appeal");
}

- (void)frozenStateChanged {
	if (![[TGClient shared] frozen]) {
		[self dismissViewControllerAnimated:YES completion:nil];
		return;
	}
	[self refreshAppealFooterText];
	[self.tableView reloadData];
}

- (void)doneTapped {
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)hasAppealLink {
	return [[TGClient shared] freezeAppealLink].length > 0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (section == 2 && [self hasAppealLink]) ? 1 : 0;
}

- (NSString *)titleForHeaderInSection:(NSInteger)section {
	if (section == 0)
		return TGL(@"FrozenAccount.Violation.Title", @"Violation of Terms");
	if (section == 1)
		return TGL(@"FrozenAccount.ReadOnly.Title", @"Read-Only Mode");
	return TGL(@"FrozenAccount.Appeal.Title", @"Appeal Before Deactivation");
}

- (NSString *)textForFooterInSection:(NSInteger)section {
	if (section == 0)
		return TGL(@"FrozenAccount.Violation.Text",
			@"Your account was frozen for breaking Telegram's Terms and Conditions.");
	if (section == 1)
		return TGL(@"FrozenAccount.ReadOnly.Text",
			@"You can access your account but can't send messages or take actions.");
	return self.appealFooterText;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return [[TGTheme shared] groupedHeaderHeightForTitle:[self titleForHeaderInSection:section]];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	TGTheme *theme = [TGTheme shared];
	return [theme groupedHeaderViewWithTitle:[self titleForHeaderInSection:section]
									   width:tableView.bounds.size.width];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *text = [self textForFooterInSection:section];
	CGFloat measured = [[TGTheme shared] groupedCommentHeightForText:text width:tableView.bounds.size.width];
	return TGGroupedFooterHeight(text, measured);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *text = [self textForFooterInSection:section];
	if (!text.length)
		return nil;
	return [[TGTheme shared] groupedCommentViewWithText:text width:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"appeal"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"appeal"];
	[[TGTheme shared] styleCell:cell];
	[TGIcons actionButtonInCell:cell
						  title:TGL(@"FrozenAccount.SubmitAppeal", @"Submit an Appeal")
						   kind:TGActionButtonKindNeutral
						 target:self
						 action:@selector(appealPressed)];
	return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return TGActionRowHeight();
}

- (void)appealPressed {
	NSString *link = [[TGClient shared] freezeAppealLink];
	if (link.length)
		[TGWebViewController openURLString:link fromViewController:self];
}

@end

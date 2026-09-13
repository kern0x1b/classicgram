#import "TGGroupedCaption.h"
#import "TGPrivacyViewController.h"
#import "TGListLoadFailure.h"
#import "TGPrivacyViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGClient+Privacy.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGSessionsViewController.h"
#import "TGPasscodeLock.h"
#import "TGSecurityStepViewController.h"

#import "TGPrivacyContactPickerViewController.h"
#import "TGBlockedListPaging.h"
#pragma mark - blocked users

static const NSInteger kBlockedUsersPageSize = 100;

@interface TGBlockedUsersViewController ()
@property (nonatomic, strong) NSMutableArray *senders;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL failed;
@property (nonatomic, assign) NSInteger loadedOffset;
@property (nonatomic, assign) BOOL loadingMore;
@property (nonatomic, assign) BOOL exhausted;
@property (nonatomic, assign) NSUInteger loadGeneration;
@property (nonatomic, strong) id userBlockedStateObserverToken;
@end

@implementation TGBlockedUsersViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStylePlain];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
	self.title = TGL(@"Settings.BlockedUsers", @"Blocked Users");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tableView.rowHeight = 44;
	self.senders = [NSMutableArray array];
	[self buildAddButton];
	[self reload];
	__weak typeof(self) weakSelf = self;
	self.userBlockedStateObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGUserBlockedStateDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf reload];
				}];
}

- (void)dealloc {
	if (_userBlockedStateObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_userBlockedStateObserverToken];
}

- (void)buildAddButton {
	UIButton *add = [UIButton buttonWithType:UIButtonTypeCustom];
	[TGIcons styleHeaderButton:add];
	[add addTarget:self action:@selector(addTapped)
		forControlEvents:UIControlEventTouchUpInside];
	add.frame = CGRectMake(0, 0, 30, 30);
	UILabel *plus = [[UILabel alloc] initWithFrame:CGRectOffset(add.bounds, 0, -2)];
	plus.text = @"+";
	plus.textColor = [UIColor whiteColor];
	plus.textAlignment = NSTextAlignmentCenter;
	plus.backgroundColor = [UIColor clearColor];
	plus.font = [UIFont boldSystemFontOfSize:18];
	plus.userInteractionEnabled = NO;
	UIImage *addIcon = [UIImage imageNamed:@"AddIcon"];
	if (addIcon) {
		plus.hidden = YES;
		[add setImage:addIcon forState:UIControlStateNormal];
		add.frame = CGRectMake(0, 0, MAX(35.0f, addIcon.size.width + 12), 30);
	}
	[add addSubview:plus];
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:add];
}

- (void)addTapped {
	__weak typeof(self) weakSelf = self;
	TGPrivacyContactPickerViewController *picker = [TGPrivacyContactPickerViewController alloc];
	picker = [picker initWithTitle:TGL(@"Conversation.BlockUser", @"Block User")
						  selected:nil
						completion:^(NSArray *userIds) {
							[weakSelf blockUsers:userIds];
						}];
	[self.navigationController pushViewController:picker animated:YES];
}

- (void)blockUsers:(NSArray *)userIds {
	if (![userIds isKindOfClass:[NSArray class]] || !userIds.count)
		return;
	__weak typeof(self) weakSelf = self;
	__block NSInteger outstanding = (NSInteger)userIds.count;
	__block BOOL anyFailed = NO;
	for (NSNumber *userId in userIds) {
		if (![userId isKindOfClass:[NSNumber class]]) {
			outstanding--;
			continue;
		}
		[[TGClient shared] setUser:[userId longLongValue] blocked:YES completion:^(BOOL ok) {
			if (!ok)
				anyFailed = YES;
			if (--outstanding > 0)
				return;
			if (anyFailed)
				TGPrivacyComplain(TGL(@"BlockedUsers.NotEveryoneCouldBeBlocked", @"Not everyone could be blocked."));
			[weakSelf reload];
		}];
	}
	if (outstanding <= 0)
		[self reload];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)reload {
	self.loadingMore = NO;
	self.exhausted = NO;
	self.failed = NO;
	self.loadedOffset = 0;
	self.loadGeneration++;
	NSUInteger generation = self.loadGeneration;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] blockedSendersFromOffset:0 limit:kBlockedUsersPageSize
									 completion:^(NSArray *senders, NSInteger total) {
										 __strong typeof(weakSelf) strongSelf = weakSelf;
										 if (!strongSelf || strongSelf.loadGeneration != generation)
											 return;
										 if (![senders isKindOfClass:[NSArray class]]) {
											 strongSelf.failed = YES;
											 [strongSelf.tableView reloadData];
											 return;
										 }
										 strongSelf.loaded = YES;
										 strongSelf.failed = NO;
										 [strongSelf.senders removeAllObjects];
										 [strongSelf.senders addObjectsFromArray:senders];
										 NSInteger fetchedCount = (NSInteger)senders.count;
										 strongSelf.loadedOffset = fetchedCount;
										 strongSelf.exhausted = TGBlockedListIsExhausted(fetchedCount,
											 kBlockedUsersPageSize, strongSelf.loadedOffset, total);
										 [strongSelf.tableView reloadData];
									 }];
}

- (void)loadMoreBlockedSenders {
	if (self.loadingMore || self.exhausted || self.senders.count == 0)
		return;
	self.loadingMore = YES;
	NSUInteger generation = self.loadGeneration;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] blockedSendersFromOffset:self.loadedOffset limit:kBlockedUsersPageSize
									 completion:^(NSArray *senders, NSInteger total) {
										 __strong typeof(weakSelf) strongSelf = weakSelf;
										 if (!strongSelf || strongSelf.loadGeneration != generation)
											 return;
										 strongSelf.loadingMore = NO;
										 if (![senders isKindOfClass:[NSArray class]])
											 return;
										 NSInteger fetchedCount = (NSInteger)senders.count;
										 if (fetchedCount) {
											 [strongSelf.senders addObjectsFromArray:senders];
											 [strongSelf.tableView reloadData];
										 }
										 strongSelf.loadedOffset += fetchedCount;
										 strongSelf.exhausted = TGBlockedListIsExhausted(fetchedCount,
											 kBlockedUsersPageSize, strongSelf.loadedOffset, total);
									 }];
}

- (void)tableView:(UITableView *)tableView
	  willDisplayCell:(UITableViewCell *)cell
	forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row < (NSInteger)self.senders.count - 3)
		return;
	[self loadMoreBlockedSenders];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.senders.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (TGListShowsLoadFailureNotice(self.failed, self.senders.count))
		return TGL(@"BlockedUsers.LoadFailed", @"The list of blocked users could not be loaded.");
	if (!self.loaded)
		return TGL(@"Channel.NotificationLoading", @"Loading…");
	if (!self.senders.count)
		return TGL(@"BlockedUsers.EmptyFooter", @"You have not blocked anyone. Blocked users cannot send you messages or add you to groups."
				"messages or add you to groups.");
	return TGL(@"BlockedUsers.SwipeToUnblockFooter", @"Swipe a name to unblock.");
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	TGTheme *theme = [TGTheme shared];
	CGFloat measured = [theme groupedCommentHeightForText:caption width:tableView.bounds.size.width];
	return TGGroupedFooterHeight(caption, measured);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	TGTheme *theme = [TGTheme shared];
	return [theme groupedCommentViewWithText:caption width:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"blocked"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"blocked"];
	[[TGTheme shared] styleCell:cell];
	NSDictionary *sender = self.senders[indexPath.row];
	id name = sender[@"name"];
	cell.textLabel.text = [name isKindOfClass:[NSString class]] ? name : TGL(@"User.DeletedAccount", @"Deleted Account");
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	NSString *username = [sender[@"username"] isKindOfClass:[NSString class]] ? sender[@"username"] : @"";
	cell.detailTextLabel.text = [sender[@"isChat"] boolValue]
		? TGL(@"Conversation.InfoGroup", @"Group")
		: (username.length ? [@"@" stringByAppendingString:username] : @"");
	cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return YES;
}

- (NSString *)tableView:(UITableView *)tableView
	titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
	return TGL(@"BlockedUsers.Unblock", @"Unblock");
}

- (void)tableView:(UITableView *)tableView
	commitEditingStyle:(UITableViewCellEditingStyle)style
	 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (style != UITableViewCellEditingStyleDelete)
		return;
	if ((NSUInteger)indexPath.row >= self.senders.count)
		return;
	NSDictionary *sender = self.senders[indexPath.row];
	id senderId = sender[@"id"];
	if (![senderId isKindOfClass:[NSNumber class]])
		return;
	BOOL isChat = [sender[@"isChat"] boolValue];
	[self.senders removeObjectAtIndex:indexPath.row];
	self.loadedOffset = MAX(0, self.loadedOffset - 1);
	[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
					 withRowAnimation:UITableViewRowAnimationLeft];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setSender:[senderId longLongValue] isChat:isChat blocked:NO completion:^(BOOL ok) {
		if (ok)
			return;
		TGPrivacyComplain(TGL(@"BlockedUsers.CouldNotBeUnblocked", @"That person could not be unblocked."));
		[weakSelf reload];
	}];
}

@end

#import "TGGroupedCaption.h"
#import "TGPrivacyViewController.h"
#import "TGListLoadFailure.h"
#import "TGPrivacyViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGClient+Stories.h"
#import "TGAlertView.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGSessionsViewController.h"
#import "TGPasscodeLock.h"
#import "TGSecurityStepViewController.h"
#import "TGHiddenStoriesViewController.h"
#import "TGHiddenStoriesPresenter.h"
#import "TGHiddenStoriesRowBridge.h"

@interface TGHiddenStoriesViewController ()
@property (nonatomic, strong) NSMutableArray *posters;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL loadFailed;
@property (nonatomic, assign) NSUInteger loadGeneration;
@property (nonatomic, strong) TGHiddenStoriesPresenter *rowPresenter;
@property (nonatomic, strong) TGHiddenStoriesRowBridge *rowBridge;
@end

@implementation TGHiddenStoriesViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStylePlain];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
	self.title = TGL(@"Story.Privacy.HideMyStoriesFrom", @"Hide My Stories From");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tableView.rowHeight = 44;
	self.posters = [NSMutableArray array];
	self.rowPresenter = [[TGHiddenStoriesPresenter alloc] init];
	self.rowBridge = [[TGHiddenStoriesRowBridge alloc] initWithPresenter:self.rowPresenter];
	[self reload];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)reload {
	self.loadGeneration++;
	NSUInteger generation = self.loadGeneration;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] hiddenStoryPostersWithCompletion:^(NSArray *users) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || strongSelf.loadGeneration != generation)
			return;
		strongSelf.loaded = YES;
		strongSelf.loadFailed = ![users isKindOfClass:[NSArray class]];
		[strongSelf.posters removeAllObjects];
		if ([users isKindOfClass:[NSArray class]])
			[strongSelf.posters addObjectsFromArray:users];
		[strongSelf.rowPresenter updateWithPosters:strongSelf.posters];
		[strongSelf.tableView reloadData];
	}];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.posters.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	switch (TGListStatusOfList(self.loaded, self.loadFailed, self.posters.count)) {
		case TGListStatusLoading:
			return TGL(@"Channel.NotificationLoading", @"Loading…");
		case TGListStatusFailed:
			return TGL(@"HiddenStories.LoadFailed",
				@"The people whose stories you hid could not be loaded.");
		case TGListStatusEmpty:
			return TGL(@"HiddenStories.EmptyFooter", @"Stories you hide are listed here.");
		case TGListStatusRows:
			break;
	}
	return TGL(@"HiddenStories.SwipeToUnhideFooter", @"Swipe a name to put their stories back in the tray.");
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
	if ([self.rowBridge ownsRowAtIndex:indexPath.row])
		return [self.rowBridge cellForRow:indexPath.row inTable:tableView];

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"poster"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"poster"];
	[[TGTheme shared] styleCell:cell];
	id name = self.posters[indexPath.row][@"name"];
	cell.textLabel.text = [name isKindOfClass:[NSString class]] ? name : TGL(@"User.DeletedAccount", @"Deleted Account");
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return YES;
}

- (NSString *)tableView:(UITableView *)tableView
	titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
	return TGL(@"ChatList.ThreadUnhideAction", @"Unhide");
}

- (void)tableView:(UITableView *)tableView
	commitEditingStyle:(UITableViewCellEditingStyle)style
	 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (style != UITableViewCellEditingStyleDelete)
		return;
	if ((NSUInteger)indexPath.row >= self.posters.count)
		return;
	NSDictionary *poster = self.posters[indexPath.row];
	id posterId = poster[@"id"];
	if (![posterId isKindOfClass:[NSNumber class]])
		return;
	BOOL posterIsChat = [poster[@"isChat"] boolValue];
	NSUInteger row = indexPath.row;
	[self.posters removeObjectAtIndex:row];
	[self.rowPresenter updateWithPosters:self.posters];
	[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
					 withRowAnimation:UITableViewRowAnimationLeft];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setStorySender:[posterId longLongValue]
							   isChat:posterIsChat
						storiesHidden:NO
						   completion:^(BOOL ok) {
		if (ok)
			return;
		TGHiddenStoriesViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSUInteger insertAt = MIN(row, strongSelf.posters.count);
		[strongSelf.posters insertObject:poster atIndex:insertAt];
		[strongSelf.rowPresenter updateWithPosters:strongSelf.posters];
		[strongSelf.tableView reloadData];
		[[[TGAlertView alloc] initWithTitle:nil
									message:TGL(@"Toast.CouldNotUnhideStories", @"Could not unhide this account's stories")
						  cancelButtonTitle:TGL(@"Common.OK", @"OK")
							  okButtonTitle:nil
							completionBlock:nil] show];
	}];
}

@end

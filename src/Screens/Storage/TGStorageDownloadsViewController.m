#import "TGGroupedCaption.h"
#import "TGStorageDownloadsViewController.h"
#import "TGIcons.h"
#import "TGStorageInternal.h"
#import "TGLocalization.h"
#import "TGStorageService.h"
#import "TGTheme.h"
#import "TGActionSheet.h"
#import "TGActionSheetIndexBuilder.h"
#import "TGStorageDownloadsPresenter.h"
#import "TGStorageDownloadsRowBridge.h"
#import "TGStorageDownloadsItemBuilder.h"
#import "TGByteFormat.h"
#import "TGHexColour.h"
#import "TGClient.h"
#import "TGDownloadsUpdate.h"

@interface TGStorageDownloadsViewController ()
@property (nonatomic, strong) NSMutableArray *entries;
@property (nonatomic, strong) NSDictionary *counts;
@property (nonatomic, copy) NSString *nextOffset;
@property (nonatomic, strong) NSMutableDictionary *suggestedNames;
@property (nonatomic, strong) NSMutableArray *pendingActions;
@property (nonatomic, assign) NSInteger pendingIndex;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) NSInteger generation;
@property (nonatomic, strong) TGStorageDownloadsPresenter *rowPresenter;
@property (nonatomic, strong) TGStorageDownloadsRowBridge *rowBridge;
@property (nonatomic, strong) id downloadsObserverToken;
@property (nonatomic, strong) id fileStateObserverToken;
@end

enum {
	TGStorageDownloadActionCancel = 1,
	TGStorageDownloadActionDelete,
	TGStorageDownloadActionRemove
};

enum {
	TGStorageDownloadSheetItem = 3401,
	TGStorageDownloadSheetClear
};

static const NSInteger kDownloadNameRequestsPerPass = 24;

@implementation TGStorageDownloadsViewController

- (instancetype)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		_entries = [NSMutableArray array];
		_suggestedNames = [NSMutableDictionary dictionary];
		_pendingIndex = -1;
		_rowPresenter = [[TGStorageDownloadsPresenter alloc] init];
		_rowBridge = [[TGStorageDownloadsRowBridge alloc] initWithPresenter:_rowPresenter];
	}
	return self;
}

- (void)syncRowPresenter {
	[self.rowPresenter updateWithEntries:self.entries
								  loaded:self.loaded
								 loading:self.loading
							   showsMore:[self showsLoadMore]
						  suggestedNames:self.suggestedNames];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"ChatList.Search.FilterDownloads", @"Downloads");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	TGStorageApplyTableBackground(self.tableView);
	self.tableView.separatorColor = [[TGTheme shared] bubbleBorderColour];
	self.navigationItem.rightBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"DownloadList.PauseAll", @"Pause All") bold:NO
									   target:self
									   action:@selector(pauseAllTapped)];
	[self reload];
	[self installDownloadObservers];
}

- (void)installDownloadObservers {
	if (self.downloadsObserverToken)
		return;
	NSNotificationCenter *centre = [NSNotificationCenter defaultCenter];
	NSOperationQueue *main = [NSOperationQueue mainQueue];
	__weak typeof(self) weakSelf = self;
	self.downloadsObserverToken = [centre addObserverForName:TGDownloadsDidChangeNotification
													  object:nil
													   queue:main
												  usingBlock:^(NSNotification *note) {
		(void)note;
		[weakSelf reloadSoon];
	}];
	self.fileStateObserverToken = [centre addObserverForName:TGFileStateDidChangeNotification
													  object:nil
													   queue:main
												  usingBlock:^(NSNotification *note) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		long long fileId = [note.userInfo[TGFileStateFileIdKey] longLongValue];
		if (TGDownloadsListShowsFileId(strongSelf.entries, fileId))
			[strongSelf reloadSoon];
	}];
}

- (BOOL)anyActiveDownloads {
	return [[self.counts objectForKey:@"active"] integerValue] > 0;
}

- (void)updatePauseAllButtonTitle {
	self.navigationItem.rightBarButtonItem.title =
		[self anyActiveDownloads] ? TGL(@"DownloadList.PauseAll", @"Pause All") : TGL(@"DownloadList.ResumeAll", @"Resume All");
	self.navigationItem.rightBarButtonItem.enabled = self.entries.count > 0;
}

- (void)pauseAllTapped {
	BOOL pause = [self anyActiveDownloads];
	[TGStorageService setAllDownloadsPaused:pause];
	[self reloadSoon];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	NSNotificationCenter *centre = [NSNotificationCenter defaultCenter];
	if (_downloadsObserverToken)
		[centre removeObserver:_downloadsObserverToken];
	if (_fileStateObserverToken)
		[centre removeObserver:_fileStateObserverToken];
}

- (void)reload {
	self.generation++;
	[self.entries removeAllObjects];
	self.nextOffset = nil;
	self.loaded = NO;
	self.loading = NO;
	[self loadPageFromOffset:nil];
}

- (void)reloadSoon {
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(reload)
											   object:nil];
	[self performSelector:@selector(reload) withObject:nil afterDelay:0.7];
}

- (void)loadPageFromOffset:(NSString *)offset {
	if (self.loading)
		return;
	self.loading = YES;
	[self.tableView reloadData];

	NSInteger generation = self.generation;
	__weak typeof(self) weakSelf = self;
	[TGStorageService downloadsWithQuery:nil
							  onlyActive:NO
						   onlyCompleted:NO
								  offset:offset
								   limit:24
							  completion:^(NSArray *files, NSDictionary *counts,
								  NSString *nextOffset) {
								  typeof(self) strongSelf = weakSelf;
								  if (!strongSelf || strongSelf.generation != generation)
									  return;
								  strongSelf.loading = NO;
								  strongSelf.loaded = YES;
								  strongSelf.counts = counts;
								  strongSelf.nextOffset = nextOffset.length ? nextOffset : nil;
								  for (NSDictionary *entry in files) {
									  if ([entry isKindOfClass:[NSDictionary class]])
										  [strongSelf.entries addObject:entry];
								  }
								  [strongSelf updatePauseAllButtonTitle];
								  [strongSelf.tableView reloadData];
								  [strongSelf fetchMissingNames];
							  }];
}

- (void)fetchMissingNames {
	NSString *directory = [NSSearchPathForDirectoriesInDomains(
		NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
	if (!directory.length)
		return;
	NSInteger asked = 0;
	__weak typeof(self) weakSelf = self;
	for (NSDictionary *entry in self.entries) {
		if (asked >= kDownloadNameRequestsPerPass)
			break;
		NSString *name = [entry objectForKey:@"name"];
		if ([name isKindOfClass:[NSString class]] && name.length)
			continue;
		NSNumber *key = [entry objectForKey:@"fileId"];
		if (!key || [self.suggestedNames objectForKey:key])
			continue;
		[self.suggestedNames setObject:@"" forKey:key];
		asked++;
		[TGStorageService suggestedFileNameForFile:[key integerValue]
									   inDirectory:directory
										completion:^(NSString *suggested) {
											typeof(self) strongSelf = weakSelf;
											if (!strongSelf || !suggested.length)
												return;
											[strongSelf.suggestedNames setObject:[suggested lastPathComponent] forKey:key];
											[strongSelf.tableView reloadData];
										}];
	}
}

- (BOOL)showsLoadMore {
	return self.nextOffset.length > 0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 1)
		return self.entries.count ? 1 : 0;
	if (!self.loaded)
		return 1;
	if (!self.entries.count)
		return 1;
	return (NSInteger)self.entries.count + ([self showsLoadMore] ? 1 : 0);
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 1)
		return TGActionRowHeight();
	return 44;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return section == 0 ? 46 : 14;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	if (section != 0)
		return nil;
	BOOL anyActive = [[self.counts objectForKey:@"active"] integerValue] > 0
		|| [[self.counts objectForKey:@"paused"] integerValue] > 0;
	NSString *title = anyActive
		? TGL(@"DownloadList.DownloadingHeader", @"Downloading")
		: TGL(@"DownloadList.DownloadedHeader", @"Recently Downloaded");
	TGTheme *theme = [TGTheme shared];
	return [theme groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	[self syncRowPresenter];

	if (indexPath.section == 1 && [self.rowBridge ownsClearRow])
		return [self.rowBridge cellForClearRowInTable:tableView];
	if (indexPath.section == 0 && [self.rowBridge ownsEntryRowAtIndex:indexPath.row])
		return [self.rowBridge cellForEntryRow:indexPath.row inTable:tableView];

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"downloadRow"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:@"downloadRow"];
	[[TGTheme shared] styleCell:cell];
	cell.accessoryView = nil;
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.textLabel.highlightedTextColor = [UIColor whiteColor];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	cell.detailTextLabel.highlightedTextColor = [UIColor whiteColor];
	cell.detailTextLabel.text = @"";

	if (indexPath.section == 1) {
		[TGIcons actionButtonInCell:cell
							  title:TGL(@"DownloadList.ClearDownloadList", @"Clear Download List")
							   kind:TGActionButtonKindDestructive
							 target:self
							 action:@selector(presentClearSheet)];
		return cell;
	}

	if (!self.loaded) {
		cell.textLabel.text = TGL(@"Channel.NotificationLoading", @"Loading…");
		cell.textLabel.textColor = [[TGTheme shared] groupedDisabledColour];
		UIActivityIndicatorView *view = [[UIActivityIndicatorView alloc]
			initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		[view startAnimating];
		cell.accessoryView = view;
		return cell;
	}

	if (!self.entries.count) {
		cell.textLabel.text = TGL(@"Storage.NothingDownloaded", @"Nothing downloaded");
		cell.textLabel.textColor = [[TGTheme shared] groupedDisabledColour];
		return cell;
	}

	if (indexPath.row >= (NSInteger)self.entries.count) {
		cell.textLabel.text = self.loading ? TGL(@"Channel.NotificationLoading", @"Loading…") : TGL(@"Chat.RichText.ShowMore", @"Show more");
		cell.textLabel.textColor = [[TGTheme shared] groupedActionColour];
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		return cell;
	}

	NSDictionary *entry = [self.entries objectAtIndex:indexPath.row];
	cell.textLabel.text = [TGStorageDownloadsItemBuilder titleForEntry:entry
													  suggestedNames:self.suggestedNames];
	cell.detailTextLabel.text = [TGStorageDownloadsItemBuilder detailForEntry:entry];
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (!self.loaded || !self.entries.count)
		return;
	if (indexPath.row >= (NSInteger)self.entries.count) {
		if (!self.loading)
			[self loadPageFromOffset:self.nextOffset];
		return;
	}
	[self presentSheetForIndex:indexPath.row];
}

- (void)presentSheetForIndex:(NSInteger)index {
	NSDictionary *entry = [self.entries objectAtIndex:index];
	BOOL complete = [[entry objectForKey:@"isComplete"] boolValue];

	self.pendingIndex = index;
	NSArray *titles;
	NSArray *actions;
	NSInteger destructiveIndex;
	if (!complete) {
		titles = @[ TGL(@"DownloadList.CancelDownloading", @"Cancel Downloading"),
			TGL(@"DownloadList.RemoveFileAlertRemove", @"Remove") ];
		actions = @[ @(TGStorageDownloadActionCancel), @(TGStorageDownloadActionRemove) ];
		destructiveIndex = 0;
	} else {
		titles = @[ TGL(@"DownloadList.DeleteFromCache", @"Delete from Cache"),
			TGL(@"DownloadList.RemoveFileAlertRemove", @"Remove") ];
		actions = @[ @(TGStorageDownloadActionDelete), @(TGStorageDownloadActionRemove) ];
		destructiveIndex = 0;
	}
	self.pendingActions = [actions mutableCopy];
	NSInteger destructiveButtonIndex, cancelButtonIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:[TGStorageDownloadsItemBuilder titleForEntry:entry
																suggestedNames:self.suggestedNames]
					  delegate:self
				   otherTitles:titles
			  destructiveIndex:destructiveIndex
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:&destructiveButtonIndex
			 cancelButtonIndex:&cancelButtonIndex];
	sheet.tag = TGStorageDownloadSheetItem;
	UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
	[sheet tg_showFromRect:cell.frame inView:self.tableView];
}

- (void)presentClearSheet {
	self.pendingIndex = -1;
	NSInteger destructiveButtonIndex, cancelButtonIndex;
	NSString *heading = [NSString stringWithFormat:@"%@\n\n%@",
		TGL(@"DownloadList.ClearAlertTitle", @"Downloaded Files"),
		TGL(@"DownloadList.ClearAlertText", @"Telegram allows to store all received and sent\ndocuments in the cloud and save storage\nspace on your device.")];
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:heading
					  delegate:self
				   otherTitles:@[ TGL(@"DownloadList.OptionManageDeviceStorage", @"Manage Device Storage"),
					   TGL(@"DownloadList.ClearDownloadList", @"Clear Download List") ]
			  destructiveIndex:1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:&destructiveButtonIndex
			 cancelButtonIndex:&cancelButtonIndex];
	sheet.tag = TGStorageDownloadSheetClear;
	UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1]];
	[sheet tg_showFromRect:cell.frame inView:self.tableView];
}

- (void)actionSheet:(UIActionSheet *)actionSheet
	clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex == actionSheet.cancelButtonIndex)
		return;

	if (actionSheet.tag == TGStorageDownloadSheetClear) {
		if (buttonIndex == 0) {
			[self.navigationController popViewControllerAnimated:YES];
			return;
		}
		[TGStorageService clearDownloadsOnlyActive:NO
									 onlyCompleted:YES
								   deleteFromCache:NO];
		[self reloadSoon];
		if (self.didChange)
			self.didChange();
		return;
	}

	if (actionSheet.tag != TGStorageDownloadSheetItem)
		return;
	if (self.pendingIndex < 0 || self.pendingIndex >= (NSInteger)self.entries.count)
		return;
	if (buttonIndex < 0 || buttonIndex >= (NSInteger)self.pendingActions.count)
		return;

	NSInteger index = self.pendingIndex;
	NSDictionary *entry = [self.entries objectAtIndex:index];
	long long fileId = [[entry objectForKey:@"fileId"] longLongValue];
	NSInteger action = [[self.pendingActions objectAtIndex:buttonIndex] integerValue];
	self.pendingIndex = -1;

	switch (action) {
		case TGStorageDownloadActionCancel:
			[TGStorageService cancelDownloadFile:fileId onlyIfPending:NO];
			break;
		case TGStorageDownloadActionRemove:
			[TGStorageService removeFileFromDownloads:fileId deleteFromCache:NO];
			break;
		default:
			[TGStorageService deleteCachedFile:fileId];
			if (self.didChange)
				self.didChange();
			break;
	}
	[self reloadSoon];
}

@end

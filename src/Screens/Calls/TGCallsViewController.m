#import "TGListBackground.h"
#import "TGCallsViewController.h"
#import "TGCallsEmptyText.h"
#import "TGCallsRowText.h"
#import "TGCallsReloadPolicy.h"
#import "TGCallListCell.h"
#import "TGCallsItem.h"
#import "TGCallsPresenter.h"
#import "TGCallsRowBridge.h"
#import "TGFileDownloadService.h"
#import "TGCallService.h"
#import "TGSettingsService.h"
#import "TGUserDisplayNameStore.h"
#import "TGAvatarPrefetcher.h"
#import "TGAvatarRowKey.h"
#import "TGCallViewController.h"
#import "TGChatViewController.h"
#import "TGContactsViewController.h"
#import "TGProfileViewController.h"
#import "TGActionSheet.h"
#import "TGDateUtils.h"
#import "TGEmoji.h"
#import "TGIcons.h"
#import "TGImageDecode.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "RootViewController.h"
#import "TGSnackbar.h"
#import <QuartzCore/QuartzCore.h>

static const CGFloat kCallRowHeight = 51.0f;
static const CGFloat kCallDetailRowHeight = 44.0f;
static const NSInteger kCallPageSize = 50;
static const NSInteger kCallPhotoPrefetchRows = 12;
static const NSInteger kCallPhotoRetainRows = 40;

static UIImage *TGCallsStretch(NSString *name, int leftCap) {
	UIImage *raw = [UIImage imageNamed:name];
	if (!raw)
		return nil;
	return [raw stretchableImageWithLeftCapWidth:leftCap topCapHeight:0];
}

static BOOL TGCallsTabletLayout(void) {
	return [RootViewController isSplitLayoutActive];
}

#pragma mark - detail screen

@interface TGCallDetailViewController : UITableViewController
- (instancetype)initWithGroup:(NSDictionary *)group;
@end

#pragma mark - calls list

@interface TGCallsViewController () <UIActionSheetDelegate, TGCallsRowBridgeDelegate> {
	TGCallsPresenter *_callsPresenter;
	TGCallsRowBridge *_callsRowBridge;
	NSArray *_callsPresenterSnapshot;
}
@property (nonatomic, strong) NSArray *groups;
@property (nonatomic, strong) NSString *nextOffset;
@property (nonatomic, assign) BOOL onlyMissed;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL reachedEnd;
@property (nonatomic, assign) BOOL loadedOnce;
@property (nonatomic, assign) BOOL loadFailed;
@property (nonatomic, assign) BOOL tabRoot;
@property (nonatomic, strong) TGAvatarPrefetcher *avatarPrefetcher;
@property (nonatomic, strong) NSMutableSet *namesRequested;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIActivityIndicatorView *footerSpinner;
@property (nonatomic, strong) NSMutableArray *modeButtons;
@property (nonatomic, strong) NSMutableArray *modeSeparators;
@property (nonatomic, strong) TGActionSheet *currentActionSheet;
@property (nonatomic, assign) NSInteger reloadGeneration;
@property (nonatomic, assign) BOOL reloadScheduled;
@property (nonatomic, assign) BOOL pendingRebuild;
@property (nonatomic, assign) NSTimeInterval lastLoadedAt;
@property (nonatomic, assign) NSTimeInterval loadStartedAt;
@end

@implementation TGCallsViewController

- (void)refreshVisibleRowsForUserKey:(NSNumber *)key {
	NSMutableArray *paths = [NSMutableArray array];
	for (NSIndexPath *path in [self.tableView indexPathsForVisibleRows]) {
		if (path.row < 0 || path.row >= (NSInteger)self.groups.count)
			continue;
		if (TGAvatarRowKeyMatches(self.groups[(NSUInteger)path.row][@"userId"], key))
			[paths addObject:path];
	}
	if (paths.count)
		[self.tableView reloadRowsAtIndexPaths:paths
							  withRowAnimation:UITableViewRowAnimationNone];
}

- (void)viewDidLoad {
	[super viewDidLoad];

	self.title = TGL(@"Calls.TabTitle", @"Calls");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	self.groups = [NSArray array];
	self.nextOffset = @"";
	_callsPresenter = [[TGCallsPresenter alloc] init];
	_callsRowBridge = [[TGCallsRowBridge alloc] initWithPresenter:_callsPresenter];
	_callsRowBridge.delegate = self;
	self.namesRequested = [NSMutableSet set];
	self.avatarPrefetcher = [[TGAvatarPrefetcher alloc] initWithAvatarSide:kCallAvatarSide
															 prefetchMargin:kCallPhotoPrefetchRows
															   retainMargin:kCallPhotoRetainRows];
	self.avatarPrefetcher.tableView = self.tableView;
	__weak typeof(self) weakSelf = self;
	self.avatarPrefetcher.rowCountProvider = ^NSInteger{
		return (NSInteger)weakSelf.groups.count;
	};
	self.avatarPrefetcher.rowKeyProvider = ^NSNumber *(NSInteger row) {
		TGCallsViewController *strongSelf = weakSelf;
		if (!strongSelf || row < 0 || row >= (NSInteger)strongSelf.groups.count)
			return nil;
		return [strongSelf.groups objectAtIndex:(NSUInteger)row][@"userId"];
	};
	self.avatarPrefetcher.fileIdProvider = ^NSNumber *(int64_t userId) {
		return [TGSettingsService photoFileIdForUserId:userId];
	};
	self.avatarPrefetcher.downloadProvider = ^(int64_t fileId, void (^completion)(NSString *path)) {
		[TGFileDownloadService downloadFile:fileId completion:completion];
	};
	self.avatarPrefetcher.photosChangedHandler = ^(NSNumber *key) {
		[weakSelf refreshVisibleRowsForUserKey:key];
	};

	self.tableView.rowHeight = kCallRowHeight;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];

	self.tabRoot = !self.pushedStandalone && self.navigationController.viewControllers.firstObject == self;

	self.navigationItem.titleView = [self buildModeSwitch];
	if (self.tabRoot) {
		NSString *newCallTitle = TGL(@"Calls.NewCall", @"New Call");
		self.navigationItem.rightBarButtonItem = [TGIcons headerBarButtonItemWithTitle:newCallTitle bold:NO target:self action:@selector(newCallTapped)];
		NSString *clearTitle = TGL(@"WebSearch.RecentSectionClear", @"Clear");
		self.navigationItem.leftBarButtonItem = [TGIcons headerBarButtonItemWithTitle:clearTitle bold:NO target:self action:@selector(clearHistoryTapped)];
	} else {
		NSString *buttonTitle = TGL(@"Common.More", @"More");
		self.navigationItem.rightBarButtonItem = [TGIcons headerBarButtonItemWithTitle:buttonTitle bold:NO target:self action:@selector(moreTapped)];
	}

	self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.emptyLabel.backgroundColor = [UIColor clearColor];
	self.emptyLabel.textAlignment = NSTextAlignmentCenter;
	self.emptyLabel.font = [UIFont systemFontOfSize:16];
	self.emptyLabel.textColor = [[TGTheme shared] secondaryTextColour];
	self.emptyLabel.numberOfLines = 0;
	self.emptyLabel.hidden = YES;
	[self.view addSubview:self.emptyLabel];

	[self reloadClearingRows:YES];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	if (TGCallsShouldReloadOnAppear(self.loading, now - self.loadStartedAt,
			self.loadedOnce, now - self.lastLoadedAt))
		[self reloadClearingRows:NO];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	if (self.currentActionSheet) {
		TGActionSheet *sheet = self.currentActionSheet;
		[sheet dismissWithClickedButtonIndex:sheet.cancelButtonIndex animated:NO];
		self.currentActionSheet = nil;
	}
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	[self layoutEmptyLabel];
}

- (void)layoutEmptyLabel {
	CGRect bounds = self.tableView.bounds;
	CGFloat visibleHeight = bounds.size.height - self.tableView.contentInset.top - self.tableView.contentInset.bottom;
	CGFloat centreY = self.tableView.contentOffset.y + self.tableView.contentInset.top + visibleHeight / 2;
	self.emptyLabel.frame = CGRectMake(20, (CGFloat)(int)(centreY - 60),
		bounds.size.width - 40, 44);
}

- (void)dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
}

#pragma mark - mode switch

- (NSArray *)modeTitles {
	return [NSArray arrayWithObjects:TGL(@"Calls.All", @"All"), TGL(@"Calls.Missed", @"Missed"), nil];
}

- (UIView *)buildModeSwitch {
	self.modeButtons = [NSMutableArray array];
	self.modeSeparators = [NSMutableArray array];

	NSArray *titles = [self modeTitles];
	NSInteger count = (NSInteger)titles.count;
	CGFloat separatorWidth = 2.0f;
	CGFloat buttonWidth = 68.0f;
	CGFloat groupWidth = buttonWidth * count + separatorWidth * (count - 1);
	CGFloat groupHeight = 30.0f;

	UIView *group = [[UIView alloc] initWithFrame:CGRectMake(0, 0, groupWidth, groupHeight)];

	UIColor *shadowColour = [UIColor colorWithRed:0x0e / 255.0f green:0x28 / 255.0f
											 blue:0x4d / 255.0f
											alpha:0.4f];
	CGFloat currentX = 0;
	for (NSInteger i = 0; i < count; i++) {
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.exclusiveTouch = YES;
		button.frame = CGRectMake(currentX, 0, buttonWidth, groupHeight);
		button.tag = i;
		[button setTitle:[titles objectAtIndex:(NSUInteger)i] forState:UIControlStateNormal];
		button.titleLabel.font = [UIFont boldSystemFontOfSize:12];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
		[button setTitleShadowColor:shadowColour forState:UIControlStateNormal];
		[button setTitleShadowColor:shadowColour forState:UIControlStateHighlighted];
		button.titleLabel.shadowOffset = CGSizeMake(0, -1);
		button.adjustsImageWhenDisabled = NO;
		button.adjustsImageWhenHighlighted = NO;
		[button addTarget:self action:@selector(modeButtonPressed:)
			forControlEvents:UIControlEventTouchUpInside];
		[group addSubview:button];
		[self.modeButtons addObject:button];

		currentX += buttonWidth;

		if (i + 1 < count) {
			UIView *separator = [[UIView alloc] initWithFrame:
					CGRectMake(currentX, 0, separatorWidth, groupHeight)];
			NSArray *names = [NSArray arrayWithObjects:@"ButtonGroupDivider.png",
				@"ButtonGroupDivider_LeftHighlighted.png",
				@"ButtonGroupDivider_RightHighlighted.png", nil];
			for (NSInteger j = 0; j < names.count; j++) {
				UIImageView *layer = [[UIImageView alloc] initWithImage:
						TGCallsStretch([names objectAtIndex:j], 6)];
				layer.tag = (NSInteger)(100 + j);
				layer.frame = separator.bounds;
				layer.alpha = (j == 0) ? 1.0f : 0.0f;
				[separator addSubview:layer];
			}
			[group addSubview:separator];
			[self.modeSeparators addObject:separator];
			currentX += separatorWidth;
		}
	}

	[self updateModeButtons];
	return group;
}

- (void)updateModeButtons {
	NSInteger selected = self.onlyMissed ? 1 : 0;
	NSInteger count = self.modeButtons.count;
	for (NSInteger i = 0; i < count; i++) {
		UIButton *button = [self.modeButtons objectAtIndex:i];
		NSString *normalName = @"ButtonGroupCenter.png";
		NSString *highlightedName = @"ButtonGroupCenter_Highlighted.png";
		int leftCap = 1;
		if (i == 0) {
			normalName = @"ButtonGroupLeft.png";
			highlightedName = @"ButtonGroupLeft_Highlighted.png";
			leftCap = 8;
		} else if (i == count - 1) {
			normalName = @"ButtonGroupRight.png";
			highlightedName = @"ButtonGroupRight_Highlighted.png";
		}

		UIImage *normal = TGCallsStretch(normalName, leftCap);
		UIImage *highlighted = TGCallsStretch(highlightedName, leftCap);
		UIImage *shown = ((NSInteger)i == selected) ? highlighted : normal;
		[button setBackgroundImage:shown forState:UIControlStateNormal];
		[button setBackgroundImage:shown forState:UIControlStateHighlighted];
		if (!normal)
			button.backgroundColor = ((NSInteger)i == selected)
				? [[TGTheme shared] accentColour]
				: [UIColor colorWithWhite:0.62f alpha:1.0f];
	}

	for (NSInteger i = 0; i < self.modeSeparators.count; i++) {
		UIView *separator = [self.modeSeparators objectAtIndex:i];
		UIView *normal = [separator viewWithTag:100];
		UIView *leftLit = [separator viewWithTag:101];
		UIView *rightLit = [separator viewWithTag:102];
		UIView *shown = normal;
		if (selected == (NSInteger)i)
			shown = leftLit;
		else if (selected == (NSInteger)i + 1)
			shown = rightLit;
		shown.alpha = 1.0f;
		[separator bringSubviewToFront:shown];
		if (normal != shown)
			normal.alpha = 0.0f;
		if (leftLit != shown)
			leftLit.alpha = 0.0f;
		if (rightLit != shown)
			rightLit.alpha = 0.0f;
	}
}

- (void)modeButtonPressed:(UIButton *)button {
	BOOL missed = button.tag == 1;
	if (missed == self.onlyMissed)
		return;
	self.onlyMissed = missed;
	[self updateModeButtons];
	[self.tableView setContentOffset:CGPointZero animated:NO];
	[self reloadClearingRows:YES];
}

#pragma mark - loading

- (void)reloadClearingRows:(BOOL)clear {
	self.reloadGeneration++;
	self.pendingRebuild = YES;
	self.nextOffset = @"";
	self.reachedEnd = NO;
	self.loading = NO;
	if (clear) {
		self.groups = [NSArray array];
		[self.tableView reloadData];
	}
	[self loadNextPage];
	[self updateEmptyState];
}

- (void)setFooterSpinning:(BOOL)spinning {
	if (!spinning) {
		self.tableView.tableFooterView = nil;
		self.footerSpinner = nil;
		return;
	}
	if (self.footerSpinner)
		return;
	self.footerSpinner = [[UIActivityIndicatorView alloc]
		initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	UIView *footer = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, self.tableView.bounds.size.width, 44)];
	self.footerSpinner.center = CGPointMake(footer.bounds.size.width / 2, 22);
	self.footerSpinner.autoresizingMask =
		UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	[self.footerSpinner startAnimating];
	[footer addSubview:self.footerSpinner];
	self.tableView.tableFooterView = footer;
}

- (void)loadNextPage {
	if (self.loading || self.reachedEnd)
		return;
	self.loading = YES;
	self.loadStartedAt = [NSDate timeIntervalSinceReferenceDate];

	NSInteger generation = self.reloadGeneration;
	BOOL missed = self.onlyMissed;
	NSString *offset = self.nextOffset ?: @"";
	[self setFooterSpinning:YES];
	__weak typeof(self) weakSelf = self;

	[TGCallService callHistoryOnlyMissed:missed
								  offset:offset
								   limit:kCallPageSize
							  completion:^(NSArray *calls, NSString *nextOffset, BOOL failed) {
								  TGCallsViewController *strongSelf = weakSelf;
								  if (!strongSelf || strongSelf.reloadGeneration != generation)
									  return;
								  strongSelf.loading = NO;
								  [strongSelf setFooterSpinning:NO];
								  if (!calls) {
									  strongSelf.loadedOnce = YES;
									  strongSelf.loadFailed = failed;
									  [strongSelf updateEmptyState];
									  return;
								  }
								  strongSelf.loadedOnce = YES;
								  strongSelf.loadFailed = NO;
								  strongSelf.lastLoadedAt = [NSDate timeIntervalSinceReferenceDate];

								  if (calls.count == 0 || !nextOffset.length)
									  strongSelf.reachedEnd = YES;
								  strongSelf.nextOffset = nextOffset ?: @"";

								  if (strongSelf.pendingRebuild) {
									  strongSelf.pendingRebuild = NO;
									  strongSelf.groups = [NSArray array];
									  [strongSelf.avatarPrefetcher.photosRequested removeAllObjects];
								  }
								  if (calls.count)
									  [strongSelf appendCalls:calls];

								  [strongSelf.tableView reloadData];
								  [strongSelf updateEmptyState];
								  [strongSelf resolveMissingNames];
								  [strongSelf.avatarPrefetcher fetchPhotosForRows];
							  }];
}

- (void)appendCalls:(NSArray *)calls {
	NSMutableArray *merged = [self.groups mutableCopy];

	for (NSDictionary *call in calls) {
		NSMutableDictionary *last = [merged lastObject];
		BOOL sameRun = last != nil && [last[@"userId"] longLongValue] == [call[@"userId"] longLongValue] && [last[@"missed"] boolValue] == [call[@"missed"] boolValue] && [last[@"declined"] boolValue] == [call[@"declined"] boolValue] && [last[@"outgoing"] boolValue] == [call[@"outgoing"] boolValue];

		if (sameRun) {
			[last[@"calls"] addObject:call];
			continue;
		}

		NSMutableDictionary *group = [NSMutableDictionary dictionary];
		group[@"userId"] = call[@"userId"];
		group[@"chatId"] = call[@"chatId"];
		group[@"name"] = call[@"name"] ?: @"";
		group[@"missed"] = call[@"missed"];
		group[@"declined"] = call[@"declined"];
		group[@"outgoing"] = call[@"outgoing"];
		group[@"video"] = call[@"video"];
		group[@"date"] = call[@"date"];
		group[@"calls"] = [NSMutableArray arrayWithObject:call];
		[merged addObject:group];
	}

	self.groups = merged;
}

- (void)resolveMissingNames {
	__weak typeof(self) weakSelf = self;
	for (NSMutableDictionary *group in self.groups) {
		NSString *name = group[@"name"];
		if ([name isKindOfClass:NSString.class] && name.length)
			continue;
		NSNumber *key = group[@"userId"];
		if (!key || [self.namesRequested containsObject:key])
			continue;
		[self.namesRequested addObject:key];
		[TGUserDisplayNameStore ensureUserName:[key longLongValue] completion:^{
			TGCallsViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			NSString *resolved = [TGUserDisplayNameStore nameForUserId:[key longLongValue]];
			if (!resolved.length)
				return;
			for (NSMutableDictionary *entry in strongSelf.groups)
				if ([entry[@"userId"] isEqualToNumber:key])
					entry[@"name"] = resolved;
			[strongSelf invalidateCallsPresenter];
			[strongSelf reloadTableSoon];
		}];
	}
}

- (void)reloadTableSoon {
	if (self.reloadScheduled)
		return;
	self.reloadScheduled = YES;
	[self performSelector:@selector(performScheduledReload) withObject:nil afterDelay:0.1];
}

- (void)performScheduledReload {
	self.reloadScheduled = NO;
	[self.tableView reloadData];
}

- (void)updateEmptyState {
	BOOL settled = self.loadedOnce && !self.loading && (self.reachedEnd || self.loadFailed);
	NSString *text = TGCallsEmptyText(settled, self.loadFailed, self.onlyMissed,
			self.groups.count);
	self.emptyLabel.text = text;
	self.emptyLabel.hidden = !text.length;
	[self layoutEmptyLabel];
	if (self.tabRoot)
		self.navigationItem.leftBarButtonItem.enabled = self.groups.count > 0;
}

#pragma mark - avatars

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	[self.avatarPrefetcher fetchPhotosForRowsThrottled];

	if (self.loading || self.reachedEnd || self.groups.count == 0)
		return;
	CGFloat distanceFromBottom = scrollView.contentSize.height - scrollView.contentOffset.y - scrollView.bounds.size.height;
	if (distanceFromBottom < scrollView.bounds.size.height)
		[self loadNextPage];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
	if (!decelerate)
		[self.avatarPrefetcher fetchPhotosForRows];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
	[self.avatarPrefetcher fetchPhotosForRows];
}

#pragma mark - table

- (NSDictionary *)groupAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section != 0)
		return nil;
	if (indexPath.row < 0 || indexPath.row >= (NSInteger)self.groups.count)
		return nil;
	return [self.groups objectAtIndex:(NSUInteger)indexPath.row];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.groups.count;
}

- (void)invalidateCallsPresenter {
	_callsPresenterSnapshot = nil;
}

- (void)syncCallsPresenterIfNeeded {
	if (self.groups == _callsPresenterSnapshot)
		return;
	_callsPresenterSnapshot = self.groups;
	[_callsPresenter updateWithGroups:self.groups];
}

- (UIImage *)callsRowBridge:(TGCallsRowBridge *)bridge avatarForKey:(NSNumber *)avatarKey {
	return [self.avatarPrefetcher.photos objectForKey:avatarKey];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	[self syncCallsPresenterIfNeeded];
	if ([_callsRowBridge ownsRowAtIndex:indexPath.row])
		return [_callsRowBridge cellForRow:indexPath.row inTable:tableView];

	static NSString *identifier = @"TGCallListCell";
	TGCallListCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
	if (!cell)
		cell = [[TGCallListCell alloc] initWithStyle:UITableViewCellStyleDefault
									 reuseIdentifier:identifier];

	NSDictionary *group = [self groupAtIndexPath:indexPath];
	if (!group)
		return cell;

	NSString *name = TGCallsDisplayName(group);
	NSInteger count = [group[@"calls"] count];

	NSDictionary *newest = [group[@"calls"] firstObject] ?: group;

	cell.nameLabel.text = name;
	cell.nameLabel.textColor = TGCallsWasMissedByMe(group)
		? TGCallsMissedColour()
		: [UIColor blackColor];
	cell.countLabel.text = count > 1 ? [NSString stringWithFormat:@"(%d)", (int)count] : nil;
	cell.countLabel.textColor = cell.nameLabel.textColor;

	cell.dateLabel.text = [TGDateUtils stringForMessageListDate:[group[@"date"] intValue]];
	cell.subtitleLabel.text = count > 1
		? TGCallsKindText(newest)
		: TGCallsSubtitleText(newest);
	cell.arrowView.image = [TGIcons callArrowOutgoing:[group[@"outgoing"] boolValue]
											   missed:TGCallsWasMissedByMe(group)];

	NSNumber *key = group[@"userId"];
	UIImage *photo = key ? [self.avatarPrefetcher.photos objectForKey:key] : nil;
	cell.avatarView.image = photo ?: [TGIcons avatarWithInitials:TGCallsInitials(name) size:kCallAvatarSide colourId:[key longLongValue]];
	[cell setNeedsLayout];
	return cell;
}

- (BOOL)keepsSelectionForDetailPane {
	return TGCallsTabletLayout();
}

- (void)openTarget:(UIViewController *)target {
	if (!target)
		return;
	if (TGCallsTabletLayout() && [RootViewController pushInDetail:target])
		return;
	[self.navigationController pushViewController:target animated:YES];
}

- (void)openDetailForIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *group = [self groupAtIndexPath:indexPath];
	if (!group)
		return;
	[self openTarget:[[TGCallDetailViewController alloc] initWithGroup:group]];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (![self keepsSelectionForDetailPane])
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
	[self openDetailForIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView
	accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
	[self openDetailForIndexPath:indexPath];
}

#pragma mark - placing a call

- (UIView *)sheetHostView {
	if (self.navigationController.view)
		return self.navigationController.view;
	return self.view;
}

- (void)moreTapped {
	NSMutableArray *actions = [NSMutableArray arrayWithObject:
			[[TGActionSheetAction alloc] initWithTitle:TGL(@"Calls.NewCall", @"New Call") action:@"newCall"]];
	if (self.groups.count) {
		TGActionSheetAction *clearAction = [TGActionSheetAction alloc];
		clearAction = [clearAction initWithTitle:TGL(@"CallList.DeleteAll", @"Clear Call History")
										  action:@"clear"
											type:TGActionSheetActionTypeDestructive];
		[actions addObject:clearAction];
	}
	TGActionSheetAction *cancelAction = [TGActionSheetAction alloc];
	cancelAction = [cancelAction initWithTitle:TGL(@"Common.Cancel", @"Cancel")
										action:@"cancel"
										  type:TGActionSheetActionTypeCancel];
	[actions addObject:cancelAction];

	__weak typeof(self) weakSelf = self;
	self.currentActionSheet = [[TGActionSheet alloc]
		initWithTitle:nil
			  actions:actions
		  actionBlock:^(__unused id target, NSString *action) {
			  TGCallsViewController *strongSelf = weakSelf;
			  if (strongSelf)
				  strongSelf.currentActionSheet = nil;
			  if (!strongSelf)
				  return;
			  if ([action isEqualToString:@"newCall"])
				  [strongSelf newCallTapped];
			  else if ([action isEqualToString:@"clear"])
				  [strongSelf clearHistoryTapped];
		  }
			   target:self];
	[self.currentActionSheet tg_showFromBarButtonItem:self.navigationItem.rightBarButtonItem inView:[self sheetHostView]];
}

- (void)clearHistoryTapped {
	if (!self.groups.count)
		return;

	TGActionSheetAction *clearForMeAction = [TGActionSheetAction alloc];
	clearForMeAction = [clearForMeAction initWithTitle:TGL(@"CallList.DeleteAllForMe", @"Delete for me")
												 action:@"clearForMe"
												   type:TGActionSheetActionTypeDestructive];
	TGActionSheetAction *clearForEveryoneAction = [TGActionSheetAction alloc];
	clearForEveryoneAction = [clearForEveryoneAction initWithTitle:TGL(@"CallList.DeleteAllForEveryone", @"Delete for me and Others")
															 action:@"clearForEveryone"
															   type:TGActionSheetActionTypeDestructive];
	TGActionSheetAction *cancelAction = [TGActionSheetAction alloc];
	cancelAction = [cancelAction initWithTitle:TGL(@"Common.Cancel", @"Cancel")
										action:@"cancel"
										  type:TGActionSheetActionTypeCancel];
	NSArray *actions = [NSArray arrayWithObjects:clearForMeAction, clearForEveryoneAction, cancelAction, nil];

	__weak typeof(self) weakSelf = self;
	self.currentActionSheet = [[TGActionSheet alloc]
		initWithTitle:TGL(@"CallList.DeleteAll", @"Clear Call History")
			  actions:actions
		  actionBlock:^(__unused id target, NSString *action) {
			  TGCallsViewController *strongSelf = weakSelf;
			  if (strongSelf)
				  strongSelf.currentActionSheet = nil;
			  BOOL forEveryone = [action isEqualToString:@"clearForEveryone"];
			  if ((!forEveryone && ![action isEqualToString:@"clearForMe"]) || !strongSelf)
				  return;
			  [TGCallService clearCallHistoryForEveryone:forEveryone completion:^(BOOL ok) {
				  TGCallsViewController *innerSelf = weakSelf;
				  if (!innerSelf)
					  return;
				  if (ok) {
					  [innerSelf reloadClearingRows:YES];
					  return;
				  }
				  [TGSnackbar showInView:[innerSelf sheetHostView]
									text:TGL(@"CallList.CouldNotClearHistory", @"Could not clear the call history.")
								 seconds:2
								onCommit:nil];
			  }];
		  }
			   target:self];
	[self.currentActionSheet tg_showFromBarButtonItem:self.navigationItem.leftBarButtonItem inView:[self sheetHostView]];
}

- (void)newCallTapped {
	TGContactsViewController *contacts = [[TGContactsViewController alloc] init];
	contacts.title = TGL(@"Calls.NewCall", @"New Call");
	contacts.pickerMode = YES;

	__weak typeof(self) weakSelf = self;
	contacts.onUserPicked = ^(int64_t userId, NSString *name) {
		TGCallsViewController *strongSelf = weakSelf;
		if (strongSelf)
			[strongSelf confirmCallToUser:userId name:name];
	};
	[self.navigationController pushViewController:contacts animated:YES];
}

- (void)confirmCallToUser:(int64_t)userId name:(NSString *)name {
	if (userId == 0)
		return;

	NSString *shown = name.length ? name : TGL(@"User.DeletedAccount", @"Deleted Account");
	NSArray *actions = [NSArray arrayWithObjects:
			[[TGActionSheetAction alloc] initWithTitle:TGL(@"Conversation.Call", @"Call") action:@"call"],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Common.Cancel", @"Cancel") action:@"cancel"
											  type:TGActionSheetActionTypeCancel],
		nil];

	__weak typeof(self) weakSelf = self;
	self.currentActionSheet = [[TGActionSheet alloc]
		initWithTitle:[NSString stringWithFormat:TGL(@"NewCall.ActionCallSingle", @"Call %@?"), shown]
			  actions:actions
		  actionBlock:^(__unused id target, NSString *action) {
			  TGCallsViewController *strongSelf = weakSelf;
			  if (strongSelf)
				  strongSelf.currentActionSheet = nil;
			  if (![action isEqualToString:@"call"])
				  return;
			  [TGCallViewController presentForUserId:userId name:name outgoing:YES video:NO];
		  }
			   target:self];
	UIView *view = [self sheetHostView];
	[self.currentActionSheet tg_showFromRect:CGRectMake(CGRectGetMidX(view.bounds), CGRectGetMidY(view.bounds), 1, 1) inView:view];
}

@end

#pragma mark - detail screen

@interface TGCallDetailViewController ()
@property (nonatomic, strong) NSDictionary *group;
@property (nonatomic, strong) NSArray *calls;
@property (nonatomic, strong) NSArray *actions;
@property (nonatomic, strong) UIImage *photo;
@property (nonatomic, strong) TGActionSheet *currentActionSheet;
@end

@implementation TGCallDetailViewController

- (instancetype)initWithGroup:(NSDictionary *)group {
	if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
		_group = group;
		_calls = [group[@"calls"] isKindOfClass:NSArray.class] ? [group[@"calls"] copy] : @[];
		_actions = [NSArray arrayWithObjects:@"call", @"message", @"info", nil];
	}
	return self;
}

- (int64_t)userId {
	return [self.group[@"userId"] longLongValue];
}

- (NSString *)peerName {
	return TGCallsDisplayName(self.group);
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = [self peerName];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.rowHeight = kCallDetailRowHeight;
	[self loadPhoto];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	if (self.currentActionSheet) {
		TGActionSheet *sheet = self.currentActionSheet;
		[sheet dismissWithClickedButtonIndex:sheet.cancelButtonIndex animated:NO];
		self.currentActionSheet = nil;
	}
}

- (void)loadPhoto {
	NSNumber *fileId = [TGSettingsService photoFileIdForUserId:[self userId]];
	if (![fileId isKindOfClass:NSNumber.class])
		return;
	__weak typeof(self) weakSelf = self;
	[TGFileDownloadService downloadFile:[fileId longLongValue] completion:^(NSString *path) {
		if (!path.length)
			return;
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			UIImage *thumb = TGDecodeSquareThumbnail(path, 60);
			dispatch_async(dispatch_get_main_queue(), ^{
				TGCallDetailViewController *strongSelf = weakSelf;
				if (!strongSelf || !thumb)
					return;
				strongSelf.photo = thumb;
				[strongSelf.tableView reloadData];
			});
		});
	}];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return 1;
	if (section == 1)
		return (NSInteger)self.calls.count;
	return (NSInteger)self.actions.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 1)
		return self.calls.count > 1 ? TGL(@"CallSettings.RecentCalls", @"Recent Calls") : TGL(@"Conversation.Call", @"Call");
	return nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderHeightForTitle:title];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return indexPath.section == 0 ? 72.0f : kCallDetailRowHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 0) {
		static NSString *identifier = @"TGCallDetailHeader";
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
		if (!cell) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
										  reuseIdentifier:identifier];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
			cell.imageView.clipsToBounds = YES;
			cell.imageView.layer.cornerRadius = 6.0f;
			cell.textLabel.font = [UIFont boldSystemFontOfSize:18];
			cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
		}
		[[TGTheme shared] styleCell:cell];
		cell.textLabel.text = [self peerName];
		NSInteger total = (NSInteger)self.calls.count;
		NSString *kindText = TGCallsKindText([self.calls firstObject] ?: self.group);
		cell.detailTextLabel.text = total > 1
			? [NSString stringWithFormat:@"%@ (%d)", kindText, (int)total]
			: kindText;
		cell.imageView.image = self.photo ?: [TGIcons avatarWithInitials:TGCallsInitials([self peerName]) size:60 colourId:[self userId]];
		return cell;
	}

	if (indexPath.section == 1) {
		static NSString *identifier = @"TGCallDetailEntry";
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
		if (!cell) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
										  reuseIdentifier:identifier];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			cell.textLabel.font = [UIFont systemFontOfSize:16];
			cell.detailTextLabel.font = [UIFont systemFontOfSize:15];
		}
		[[TGTheme shared] styleCell:cell];
		NSDictionary *call = [self.calls objectAtIndex:(NSUInteger)indexPath.row];
		cell.textLabel.text = TGCallsSubtitleText(call);
		cell.textLabel.textColor = TGCallsWasMissedByMe(call)
			? TGCallsMissedColour()
			: [[TGTheme shared] primaryTextColour];
		cell.detailTextLabel.text = [TGDateUtils stringForMessageListDate:[call[@"date"] intValue]];
		BOOL outgoing = [call[@"outgoing"] boolValue];
		cell.imageView.image = [TGIcons callArrowOutgoing:outgoing missed:TGCallsWasMissedByMe(call)];
		return cell;
	}

	static NSString *identifier = @"TGCallDetailAction";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:identifier];
		cell.textLabel.textAlignment = NSTextAlignmentCenter;
		cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
	}
	[[TGTheme shared] styleCell:cell];
	NSString *action = [self.actions objectAtIndex:(NSUInteger)indexPath.row];
	if ([action isEqualToString:@"call"])
		cell.textLabel.text = TGL(@"Conversation.Call", @"Call");
	else if ([action isEqualToString:@"message"])
		cell.textLabel.text = TGL(@"UserInfo.SendMessage", @"Send Message");
	else
		cell.textLabel.text = TGL(@"ContactInfo.Title", @"Contact Info");
	cell.textLabel.textColor = [[TGTheme shared] accentColour];
	return cell;
}

- (UIView *)sheetHostView {
	if (self.navigationController.view)
		return self.navigationController.view;
	return self.view;
}

- (void)openTarget:(UIViewController *)target {
	if (!target)
		return;
	if (TGCallsTabletLayout() && [RootViewController pushInDetail:target])
		return;
	[self.navigationController pushViewController:target animated:YES];
}

- (void)openProfile {
	[self openTarget:[[TGProfileViewController alloc]
						 initWithChatId:[self.group[@"chatId"] longLongValue]
								 userId:[self userId]
								  title:[self peerName]]];
}

- (void)openConversation {
	int64_t chatId = [self.group[@"chatId"] longLongValue];
	NSString *name = [self peerName];
	if (chatId == 0)
		return;
	TGChatViewController *chat = [[TGChatViewController alloc] init];
	chat.chatId = chatId;
	chat.chatTitle = name;
	[self openTarget:chat];
}

- (void)confirmCall {
	int64_t userId = [self userId];
	if (userId == 0)
		return;
	NSString *name = [self peerName];
	NSArray *actions = [NSArray arrayWithObjects:
			[[TGActionSheetAction alloc] initWithTitle:TGL(@"Conversation.Call", @"Call") action:@"call"],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Common.Cancel", @"Cancel") action:@"cancel"
											  type:TGActionSheetActionTypeCancel],
		nil];

	__weak typeof(self) weakSelf = self;
	self.currentActionSheet = [[TGActionSheet alloc]
		initWithTitle:[NSString stringWithFormat:TGL(@"NewCall.ActionCallSingle", @"Call %@?"), name]
			  actions:actions
		  actionBlock:^(__unused id target, NSString *action) {
			  TGCallDetailViewController *strongSelf = weakSelf;
			  if (strongSelf)
				  strongSelf.currentActionSheet = nil;
			  if (![action isEqualToString:@"call"])
				  return;
			  [TGCallViewController presentForUserId:userId name:name outgoing:YES video:NO];
		  }
			   target:self];
	NSIndexPath *callRow = [NSIndexPath indexPathForRow:(NSInteger)[self.actions indexOfObject:@"call"] inSection:2];
	UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:callRow];
	[self.currentActionSheet tg_showFromRect:cell.frame inView:self.tableView];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (indexPath.section == 0) {
		[self openProfile];
		return;
	}
	if (indexPath.section != 2)
		return;

	NSString *action = [self.actions objectAtIndex:(NSUInteger)indexPath.row];
	if ([action isEqualToString:@"call"])
		[self confirmCall];
	else if ([action isEqualToString:@"message"])
		[self openConversation];
	else
		[self openProfile];
}

@end

#import "TGStickersViewController.h"
#import "TGClient+Stickers.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "UIImage+WebP.h"
#import "TGOwnedStickerSetsViewController.h"
#import "TGStickersViewControllerInternal.h"
#import "TGStickerEmojiKeywordsViewController.h"
#import "TGStickerTilesCell.h"
#import "TGStickerTrendCell.h"
#import "TGHexColour.h"

const CGFloat kSetRowHeight = 51.0f;
const CGFloat kPlainRowHeight = 44.0f;
const CGFloat kCoverSide = 40.0f;

const CGFloat kTileSide = 72.0f;
const CGFloat kTileGap = 4.0f;
const CGFloat kTileInset = 2.0f;
const CGFloat kGridRowHeight = 78.0f;

const CGFloat kTrendRowHeight = 78.0f;
const CGFloat kTrendCoverSide = 34.0f;

const NSInteger kArchivedPageSize = 20;
const NSInteger kTrendingPageSize = 20;

static const CGFloat kBottomBarHeight = 45.0f;
const NSUInteger kCoverCacheLimit = 220;
const NSUInteger kCoverCacheByteLimit = 8 * 1024 * 1024;

const NSInteger kStickersPageMasks = 5;
const NSInteger kStickersPageEmoji = 6;
const NSInteger kStickersPageEmojiTrending = 7;
const NSInteger kStickersPageEmojiArchived = 8;
const NSInteger kStickersPageMasksArchived = 9;
const NSInteger kStickersPageRecent = 10;
const NSInteger kStickersPagePremium = 11;
const NSInteger kStickersPageGreeting = 12;

const NSInteger kSearchLimit = 40;
const NSInteger kPremiumLimit = 40;
const CGFloat kStickersSearchBarHeight = 44.0f;

const NSInteger kRootSectionSettings = 0;
const NSInteger kRootSectionPages = 1;
const NSInteger kRootSectionSets = 2;
const NSInteger kRootSectionRecent = 3;

NSString *const TGStickerLoopAnimatedKey = @"TGStickerLoopAnimated";
NSString *const TGStickerLargeEmojiKey = @"TGStickerLargeEmoji";

NSString *TGStickersSuggestModeName(TGStickerSuggestMode mode) {
	switch (mode) {
		case TGStickerSuggestModeInstalled:
			return TGL(@"Stickers.SuggestAdded", @"My Sets");
		case TGStickerSuggestModeNone:
			return TGL(@"Stickers.SuggestNone", @"None");
		default:
			return TGL(@"Stickers.SuggestAll", @"All Sets");
	}
}

static UIImage *TGStickersStretch(NSString *name, int leftCap) {
	UIImage *raw = [UIImage imageNamed:name];
	if (!raw)
		return nil;
	return [raw stretchableImageWithLeftCapWidth:leftCap topCapHeight:0];
}

UIImage *TGStickersPlate(NSString *name) {
	UIImage *raw = [UIImage imageNamed:name];
	if (!raw)
		return nil;
	return [raw stretchableImageWithLeftCapWidth:(int)(raw.size.width / 2) topCapHeight:0];
}

CGFloat TGStickersPlateHeight(NSString *name, CGFloat fallback) {
	UIImage *raw = [UIImage imageNamed:name];
	return raw ? raw.size.height : fallback;
}

UIColor *TGStickersRGBA(int rgb, CGFloat alpha) {
	return [UIColor colorWithRed:((rgb >> 16) & 0xff) / 255.0f
						   green:((rgb >> 8) & 0xff) / 255.0f
							blue:(rgb & 0xff) / 255.0f
						   alpha:alpha];
}

UIColor *TGStickersGreenShadow(void) {
	return TGStickersRGBA(0x124606, 0.3f);
}

UIColor *TGStickersRedShadow(void) {
	return TGStickersRGBA(0xa10603, 0.5f);
}

static UIImageView *TGStickersDisclosureView(void) {
	UIImage *arrow = TGLocalizedDirectionalImage([UIImage imageNamed:@"MenuDisclosureIndicator.png"]);
	if (!arrow)
		return nil;
	UIImage *highlightedArrow = [UIImage imageNamed:@"MenuDisclosureIndicator_Highlighted.png"];
	return [[UIImageView alloc] initWithImage:arrow
							 highlightedImage:highlightedArrow];
}

void TGStickersApplyDisclosure(UITableViewCell *cell) {
	UIImageView *arrow = TGStickersDisclosureView();
	if (!arrow) {
		cell.accessoryView = nil;
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		return;
	}
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.accessoryView = arrow;
}

const CGFloat kStickersGroupedInset = 9.0f;
const CGFloat kActionRowHeight = 45.0f;
const CGFloat kGroupSpacerHeight = 12.0f;

CGFloat TGStickersRetinaPixel(void) {
	return [UIScreen mainScreen].scale > 1.0f ? 0.5f : 0.0f;
}

NSString *TGStickersCacheKey(long long fileId, CGFloat side) {
	return [NSString stringWithFormat:@"%lld-%d", fileId, (int)side];
}

@implementation TGStickersViewController

- (instancetype)init {
	self = [super initWithNibName:nil bundle:nil];
	if (self) {
		_page = TGStickersPageRoot;
		_sets = [NSMutableArray array];
		_covers = [NSMutableDictionary dictionary];
		_coverOrder = [NSMutableArray array];
		_coversInFlight = [NSMutableSet set];
	}
	return self;
}

- (BOOL)isGridPage {
	return self.page == TGStickersPageFavourites || self.page == TGStickersPageSet ||
		(NSInteger)self.page == kStickersPageRecent ||
		(NSInteger)self.page == kStickersPagePremium ||
		(NSInteger)self.page == kStickersPageGreeting;
}

- (BOOL)isMaskPage {
	return (NSInteger)self.page == kStickersPageMasks;
}

- (BOOL)isEmojiListPage {
	return (NSInteger)self.page == kStickersPageEmoji;
}

- (BOOL)isTwoSectionListPage {
	return [self isMaskPage] || [self isEmojiListPage];
}

- (BOOL)isTrendingPage {
	return self.page == TGStickersPageTrending ||
		(NSInteger)self.page == kStickersPageEmojiTrending;
}

- (BOOL)isArchivePage {
	return self.page == TGStickersPageArchived ||
		(NSInteger)self.page == kStickersPageEmojiArchived ||
		(NSInteger)self.page == kStickersPageMasksArchived;
}

- (BOOL)isReorderPage {
	return self.page == TGStickersPageRoot || [self isTwoSectionListPage];
}

- (BOOL)isFavouritesOrRecentPage {
	return self.page == TGStickersPageFavourites || (NSInteger)self.page == kStickersPageRecent;
}

- (BOOL)showsSearchBar {
	return [self isMaskPage] || self.page == TGStickersPageRoot ||
		[self isTrendingPage];
}

- (NSInteger)setsSection {
	if (self.page == TGStickersPageRoot)
		return kRootSectionSets;
	if ([self isTwoSectionListPage])
		return 1;
	return 0;
}

- (NSString *)pageTitle {
	if ([self isMaskPage])
		return TGL(@"Paint.Masks", @"Masks");
	if ([self isEmojiListPage])
		return TGL(@"StickersList.EmojiItem", @"Custom Emoji");
	if ((NSInteger)self.page == kStickersPageEmojiTrending)
		return TGL(@"EmojiInput.TrendingEmoji", @"Trending Emoji");
	if ((NSInteger)self.page == kStickersPageEmojiArchived)
		return TGL(@"StickersList.ArchivedEmojiItem", @"Archived Emoji");
	if ((NSInteger)self.page == kStickersPageMasksArchived)
		return TGL(@"StickerPacksSettings.ArchivedMasks", @"Archived Masks");
	if ((NSInteger)self.page == kStickersPageRecent)
		return TGL(@"Stickers.FrequentlyUsed", @"Recently Used");
	if ((NSInteger)self.page == kStickersPagePremium)
		return TGL(@"Stickers.PremiumStickers", @"Premium Stickers");
	if ((NSInteger)self.page == kStickersPageGreeting)
		return TGL(@"Stickers.GreetingStickersTitle", @"Greeting Stickers");
	switch (self.page) {
		case TGStickersPageTrending:
			return TGL(@"StickerPacksSettings.TrendingStickers", @"Trending Stickers");
		case TGStickersPageArchived:
			return TGL(@"StickerPacksSettings.ArchivedPacks", @"Archived Stickers");
		case TGStickersPageFavourites:
			return TGL(@"Stickers.FavoriteStickers", @"Favourite Stickers");
		case TGStickersPageSet: {
			NSString *title = self.set[@"title"];
			return title.length ? title : TGL(@"EmojiInput.TabStickers", @"Stickers");
		}
		default:
			return TGL(@"EmojiInput.TabStickers", @"Stickers");
	}
}

#pragma mark - lifecycle

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = [self pageTitle];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	__weak typeof(self) weakSelf = self;
	self.stickerSetsObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGInstalledStickerSetsDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf installedStickerSetsChanged:note];
				}];

	self.trendingStickerSetsObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGTrendingStickerSetsDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf trendingStickerSetsChanged:note];
				}];

	self.favoriteStickersObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGFavoriteStickersDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf favoriteStickersChanged:note];
				}];

	self.recentStickersObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGRecentStickersDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf recentStickersChanged:note];
				}];

	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];

	[self buildTable];

	if ([self showsSearchBar])
		[self buildSearchBar];

	if ([self showsBottomBar])
		[self buildBottomBar];

	[self buildPlaceholder];

	self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:
			UIActivityIndicatorViewStyleGray];
	self.spinner.hidesWhenStopped = YES;
	[self.view addSubview:self.spinner];

	if ([self isReorderPage])
		[self installEditButton];
	if (self.page == TGStickersPageSet) {
		[self refreshSetBarButton];
		[self refreshBottomBar];
	}

	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	[self reload];

	if (self.page == TGStickersPageTrending || self.page == TGStickersPageSet)
		[self captureArchivedSnapshot];
}

- (void)buildSearchBar {
	self.searchBar = [[UISearchBar alloc] initWithFrame:
			CGRectMake(0, 0, self.view.bounds.size.width, kStickersSearchBarHeight)];
	self.searchBar.delegate = self;
	self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.searchBar.placeholder = TGL(@"Stickers.Search", @"Search Stickers");
	self.table.tableHeaderView = self.searchBar;
}

- (NSString *)archiveCheckStickerType {
	if (self.page == TGStickersPageSet) {
		if ([self.set[@"isMask"] boolValue])
			return @"stickerTypeMask";
		if ([self.set[@"isEmoji"] boolValue])
			return @"stickerTypeCustomEmoji";
		return @"stickerTypeRegular";
	}
	if ([self isMaskPage])
		return @"stickerTypeMask";
	if ([self isEmojiListPage])
		return @"stickerTypeCustomEmoji";
	return @"stickerTypeRegular";
}

- (TGStickersPage)archivedPageForStickerType:(NSString *)stickerType {
	if ([stickerType isEqualToString:@"stickerTypeMask"])
		return (TGStickersPage)kStickersPageMasksArchived;
	if ([stickerType isEqualToString:@"stickerTypeCustomEmoji"])
		return (TGStickersPage)kStickersPageEmojiArchived;
	return TGStickersPageArchived;
}

- (void)fetchArchivedSnapshotOfType:(NSString *)stickerType
						  completion:(void (^)(NSArray *, NSInteger))completion {
	TGClient *client = [TGClient shared];
	if ([stickerType isEqualToString:@"stickerTypeMask"]) {
		[client archivedMaskStickerSetsFromSetId:0 limit:kArchivedPageSize completion:completion];
		return;
	}
	if ([stickerType isEqualToString:@"stickerTypeCustomEmoji"]) {
		[client archivedEmojiStickerSetsFromSetId:0 limit:kArchivedPageSize completion:completion];
		return;
	}
	[client archivedStickerSetsFromSetId:0 limit:kArchivedPageSize completion:completion];
}

- (void)captureArchivedSnapshot {
	NSString *stickerType = [self archiveCheckStickerType];
	__weak typeof(self) weakSelf = self;
	void (^completion)(NSArray *, NSInteger) = ^(NSArray *sets, __unused NSInteger total) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || !sets)
			return;
		NSMutableSet *ids = [NSMutableSet set];
		for (NSDictionary *set in sets)
			if (set[@"id"])
				[ids addObject:set[@"id"]];
		strongSelf.archivedIdsBeforeInstall = ids;
	};
	[self fetchArchivedSnapshotOfType:stickerType completion:completion];
}

- (void)checkAutoArchivedSets {
	NSSet *before = self.archivedIdsBeforeInstall;
	if (!before)
		return;

	NSString *stickerType = [self archiveCheckStickerType];
	__weak typeof(self) weakSelf = self;
	void (^completion)(NSArray *, NSInteger) = ^(NSArray *sets, __unused NSInteger total) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || !sets)
			return;

		NSMutableSet *ids = [NSMutableSet set];
		BOOL foundNewlyArchived = NO;
		for (NSDictionary *set in sets) {
			if (!set[@"id"])
				continue;
			[ids addObject:set[@"id"]];
			if (![before containsObject:set[@"id"]])
				foundNewlyArchived = YES;
		}
		strongSelf.archivedIdsBeforeInstall = ids;
		if (!foundNewlyArchived)
			return;

		NSString *title = TGL(@"ArchivedPacksAlert.Title", @"Some of your older sticker sets have been archived. You can reactivate them in the Sticker Settings.");
		TGActionSheetAction *showArchiveAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"StoryList.ContextShowArchive", @"Show Archive") action:@"openArchive"];
		TGActionSheetAction *cancelAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"Common.OK", @"OK") action:@"cancel" type:TGActionSheetActionTypeCancel];
		NSArray *actions = @[ showArchiveAction, cancelAction ];
		[strongSelf presentSheetWithTitle:title actions:actions];
	};
	[self fetchArchivedSnapshotOfType:stickerType completion:completion];
}

- (BOOL)stickerTypeMatchesTrendingDisplay:(NSString *)stickerType {
	if ((NSInteger)self.page == kStickersPageEmojiTrending)
		return [stickerType isEqualToString:@"stickerTypeCustomEmoji"];
	return [stickerType isEqualToString:@"stickerTypeRegular"];
}

- (BOOL)installedStickerSetsChangeAffectsThisPage:(NSString *)stickerType {
	if ([self isMaskPage])
		return [stickerType isEqualToString:@"stickerTypeMask"];
	if ([self isEmojiListPage])
		return [stickerType isEqualToString:@"stickerTypeCustomEmoji"];
	if (self.page == TGStickersPageRoot)
		return [stickerType isEqualToString:@"stickerTypeRegular"];
	if ([self isTrendingPage])
		return [self stickerTypeMatchesTrendingDisplay:stickerType];
	return NO;
}

- (void)installedStickerSetsChanged:(NSNotification *)note {
	if (![self installedStickerSetsChangeAffectsThisPage:note.userInfo[TGInstalledStickerSetsTypeKey]])
		return;
	if (self.loaded && !self.reordering && !self.searching)
		[self reload];
}

- (BOOL)trendingStickerSetsChangeAffectsThisPage:(NSString *)stickerType {
	if (![self isTrendingPage])
		return NO;
	return [self stickerTypeMatchesTrendingDisplay:stickerType];
}

- (void)trendingStickerSetsChanged:(NSNotification *)note {
	if (![self trendingStickerSetsChangeAffectsThisPage:note.userInfo[TGTrendingStickerSetsTypeKey]])
		return;
	if (self.loaded && !self.reordering && !self.searching)
		[self reloadTrending];
}

- (void)favoriteStickersChanged:(__unused NSNotification *)note {
	if (self.page != TGStickersPageFavourites)
		return;
	if (self.loaded && !self.reordering && !self.searching)
		[self reload];
}

- (void)recentStickersChanged:(__unused NSNotification *)note {
	if ((NSInteger)self.page != kStickersPageRecent)
		return;
	if (self.loaded && !self.reordering && !self.searching)
		[self reload];
}

- (void)dealloc {
	if (self.stickerSetsObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.stickerSetsObserverToken];
	if (self.trendingStickerSetsObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.trendingStickerSetsObserverToken];
	if (self.favoriteStickersObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.favoriteStickersObserverToken];
	if (self.recentStickersObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.recentStickersObserverToken];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	if (([self isReorderPage] || [self isFavouritesOrRecentPage]) &&
		self.loaded && !self.reordering && !self.searching)
		[self reload];
	[self.table deselectRowAtIndexPath:[self.table indexPathForSelectedRow] animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	TGActionSheet *sheet = self.currentActionSheet;
	if (sheet) {
		[sheet dismissWithClickedButtonIndex:sheet.cancelButtonIndex
									animated:NO];
		self.currentActionSheet = nil;
	}
	if (self.reordering)
		[self commitOrder];
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(runSearch)
											   object:nil];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	[self layoutChrome];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	[self flushCovers];
	[self.table reloadData];
}

#pragma mark - chrome

- (void)buildTable {
	UITableViewStyle style = [self isGridPage] ? UITableViewStylePlain
											   : UITableViewStyleGrouped;
	self.table = [[UITableView alloc] initWithFrame:self.view.bounds style:style];
	self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth |
		UIViewAutoresizingFlexibleHeight;
	self.table.dataSource = self;
	self.table.delegate = self;
	self.table.rowHeight = [self isGridPage] ? kGridRowHeight : kPlainRowHeight;
	self.table.separatorColor = [[TGTheme shared] separatorColour];

	if ([self isGridPage]) {
		self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
		self.table.backgroundColor = [UIColor whiteColor];
		self.table.tableFooterView = [self gridFooterView];
	} else {
		self.table.backgroundColor = [[TGTheme shared] listBackgroundColour];
	}
	[self.view addSubview:self.table];
}

- (UIView *)gridFooterView {
	UIImage *plate = TGStickersStretch(@"Footer.png", 1);
	if (!plate)
		return [[UIView alloc] initWithFrame:
				CGRectMake(0, 0, self.view.bounds.size.width, 1)];
	UIImageView *footer = [[UIImageView alloc] initWithImage:plate];
	footer.frame = CGRectMake(0, 0, self.view.bounds.size.width, plate.size.height);
	footer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	return footer;
}

- (BOOL)showsBottomBar {
	return self.page == TGStickersPageSet;
}

- (BOOL)currentSetInstalled {
	return [self.set[@"installed"] boolValue];
}

- (BOOL)currentSetIsEditable {
	return self.page == TGStickersPageSet &&
		[self currentSetInstalled] &&
		[self.set[@"owned"] boolValue] &&
		![self.set[@"isEmoji"] boolValue];
}

- (void)buildBottomBar {
	self.bottomBar = [[UIView alloc] initWithFrame:CGRectZero];
	self.bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth |
		UIViewAutoresizingFlexibleTopMargin;

	UIImage *plate = TGStickersStretch(@"Footer.png", 1);
	if (plate)
		self.bottomBar.backgroundColor = [UIColor colorWithPatternImage:plate];
	else
		self.bottomBar.backgroundColor = TGColourFromHex(0xf7f7f7);

	self.bottomBarLine = [[UIView alloc] initWithFrame:CGRectZero];
	self.bottomBarLine.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.bottomBarLine.backgroundColor = [[TGTheme shared] separatorColour];
	[self.bottomBar addSubview:self.bottomBarLine];

	self.bottomButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.bottomButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.bottomButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
	self.bottomButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
	[self.bottomButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[self.bottomButton addTarget:self action:@selector(bottomButtonTapped)
				forControlEvents:UIControlEventTouchUpInside];
	[self.bottomBar addSubview:self.bottomButton];

	self.bottomBar.hidden = YES;
	[self.view addSubview:self.bottomBar];
}

- (void)refreshBottomBar {
	if (!self.bottomBar)
		return;

	BOOL installed = [self currentSetInstalled];
	BOOL editable = [self currentSetIsEditable];
	NSString *asset = (installed && !editable) ? @"MenuRedButton" : @"GroupedActionButtonGreen";
	[self.bottomButton setBackgroundImage:
			TGStickersPlate([asset stringByAppendingString:@".png"])
								 forState:UIControlStateNormal];
	[self.bottomButton setBackgroundImage:
			TGStickersPlate([asset stringByAppendingString:@"_Highlighted.png"])
								 forState:UIControlStateHighlighted];
	UIColor *shadow = (installed && !editable) ? TGStickersRedShadow() : TGStickersGreenShadow();
	[self.bottomButton setTitleShadowColor:shadow forState:UIControlStateNormal];
	[self.bottomButton setTitleShadowColor:shadow forState:UIControlStateHighlighted];

	NSInteger count = (NSInteger)self.stickers.count;
	if (count == 0)
		count = [self.set[@"count"] integerValue];
	NSString *title;
	if (editable) {
		title = TGL(@"StickerPack.EditStickers", @"Edit Stickers");
	} else if (count > 0) {
		title = installed
			? TGLPlural(@"StickerPack.RemoveStickerCount", count, @"Remove 1 Sticker", @"Remove %d Stickers")
			: TGLPlural(@"StickerPack.AddStickerCount", count, @"Add 1 Sticker", @"Add %d Stickers");
	} else {
		title = installed ? TGL(@"StickerPack.RemoveStickerSet", @"Remove Sticker Set")
						  : TGL(@"Conversation.ContextMenuStickerPackAdd", @"Add Stickers");
	}
	[self.bottomButton setTitle:title forState:UIControlStateNormal];

	self.bottomBar.hidden = !self.loaded || self.table.hidden;
	[self layoutChrome];
}

- (void)bottomButtonTapped {
	if ([self currentSetIsEditable]) {
		[self editCurrentSet];
		return;
	}
	[self toggleCurrentSet];
}

- (void)layoutBottomBar {
	if (!self.bottomBar)
		return;
	CGFloat width = self.view.bounds.size.width;
	CGFloat height = self.view.bounds.size.height;
	self.bottomBar.frame = CGRectMake(0, height - kBottomBarHeight, width, kBottomBarHeight);
	self.bottomBarLine.frame = CGRectMake(0, 0, width, 1.0f / [UIScreen mainScreen].scale);

	CGFloat buttonHeight = ([self currentSetInstalled] && ![self currentSetIsEditable])
		? TGStickersPlateHeight(@"MenuRedButton.png", 45.0f)
		: TGStickersPlateHeight(@"GroupedActionButtonGreen.png", 43.0f);
	CGFloat buttonWidth = width - kStickersGroupedInset * 2;
	self.bottomButton.frame = CGRectMake(kStickersGroupedInset,
		floorf((kBottomBarHeight - buttonHeight) / 2), buttonWidth, buttonHeight);

	UIEdgeInsets insets = self.table.contentInset;
	insets.bottom = self.bottomBar.hidden ? 0 : kBottomBarHeight;
	self.table.contentInset = insets;
	self.table.scrollIndicatorInsets = insets;
}

- (void)buildPlaceholder {
	self.placeholder = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 232, 70)];
	self.placeholder.backgroundColor = [UIColor clearColor];
	self.placeholder.hidden = YES;

	UIColor *colour = TGColourFromHex(0x8b97a5);

	self.placeholderTitle = [[UILabel alloc] initWithFrame:CGRectZero];
	self.placeholderTitle.backgroundColor = [UIColor clearColor];
	self.placeholderTitle.font = [UIFont boldSystemFontOfSize:15];
	self.placeholderTitle.textColor = colour;
	self.placeholderTitle.textAlignment = NSTextAlignmentCenter;
	[self.placeholder addSubview:self.placeholderTitle];

	self.placeholderBody = [[UILabel alloc] initWithFrame:CGRectZero];
	self.placeholderBody.backgroundColor = [UIColor clearColor];
	self.placeholderBody.font = [UIFont systemFontOfSize:14];
	self.placeholderBody.textColor = colour;
	self.placeholderBody.textAlignment = NSTextAlignmentCenter;
	self.placeholderBody.lineBreakMode = NSLineBreakByWordWrapping;
	self.placeholderBody.numberOfLines = 0;
	[self.placeholder addSubview:self.placeholderBody];

	[self.view addSubview:self.placeholder];
}

- (void)installEditButton {
	NSString *title = self.reordering ? TGL(@"Common.Done", @"Done") : TGL(@"Common.Edit", @"Edit");
	UIButton *button = [TGIcons headerButtonWithTitle:title bold:self.reordering
											   target:self
											   action:@selector(editTapped)];
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:button];
	self.navigationItem.rightBarButtonItem.customView.hidden = (self.sets.count == 0);
}

- (void)refreshSetBarButton {
	UIBarButtonItem *shareItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"StickerPack.ShareLink", @"Share Link")
																   bold:NO
																 target:self
																 action:@selector(shareCurrentSet)];
	if ([self currentSetIsEditable]) {
		UIButton *button = [TGIcons headerButtonWithTitle:TGL(@"StickerPack.EditStickers", @"Edit Stickers")
													 bold:YES
												   target:self
												   action:@selector(editCurrentSet)];
		UIBarButtonItem *editItem = [[UIBarButtonItem alloc] initWithCustomView:button];
		self.navigationItem.rightBarButtonItems = @[ editItem, shareItem ];
		return;
	}
	BOOL installed = [self currentSetInstalled];
	NSString *title = installed ? TGL(@"Appearance.RemoveTheme", @"Remove") : TGL(@"StickerPack.Add", @"Add");
	UIButton *button = [TGIcons headerButtonWithTitle:title
												 bold:!installed
											   target:self
											   action:@selector(toggleCurrentSet)];
	UIBarButtonItem *primaryItem = [[UIBarButtonItem alloc] initWithCustomView:button];
	self.navigationItem.rightBarButtonItems = @[ primaryItem, shareItem ];
}

- (void)layoutChrome {
	CGFloat width = self.view.bounds.size.width;
	CGFloat height = self.view.bounds.size.height;

	self.spinner.center = CGPointMake(floorf(width / 2), floorf(height / 2));

	if (!self.placeholder.hidden) {
		CGFloat containerWidth = 232;
		CGSize titleSize = [self.placeholderTitle.text
			sizeWithFont:self.placeholderTitle.font];
		CGSize bodySize = [self.placeholderBody.text
				 sizeWithFont:self.placeholderBody.font
			constrainedToSize:CGSizeMake(containerWidth, 1000)
				lineBreakMode:NSLineBreakByWordWrapping];

		self.placeholderTitle.frame = CGRectMake(0, 0, containerWidth, titleSize.height);
		self.placeholderBody.frame = CGRectMake(0, titleSize.height + 8,
			containerWidth, bodySize.height);
		CGFloat containerHeight = titleSize.height + 8 + bodySize.height;
		self.placeholder.frame = CGRectMake(floorf((width - containerWidth) / 2),
			floorf((height - containerHeight) / 2), containerWidth, containerHeight);
	}

	[self layoutBottomBar];
}

#pragma mark - state

- (void)showLoading {
	self.placeholder.hidden = YES;
	self.table.hidden = (self.sets.count == 0 && self.stickers.count == 0 &&
		self.page != TGStickersPageRoot);
	[self.spinner startAnimating];
	[self layoutChrome];
}

- (void)showContent {
	[self.spinner stopAnimating];
	self.placeholder.hidden = YES;
	self.table.hidden = NO;
	self.bottomBar.hidden = ![self showsBottomBar];
	[self layoutChrome];
}

- (void)showFailure {
	[self showContent];
}

@end

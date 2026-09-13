#import <UIKit/UIKit.h>
#import "TGStickersViewController.h"
#import "TGActionSheet.h"
#import "TGStickerCatalogService.h"

extern const CGFloat kStickersSearchBarHeight;
extern const CGFloat kTrendCoverSide;

extern const CGFloat kSetRowHeight;
extern const CGFloat kPlainRowHeight;
extern const CGFloat kCoverSide;

extern const CGFloat kTileSide;
extern const CGFloat kTileGap;
extern const CGFloat kTileInset;
extern const CGFloat kGridRowHeight;

extern const CGFloat kTrendRowHeight;

extern const NSInteger kArchivedPageSize;
extern const NSInteger kTrendingPageSize;

extern const NSUInteger kCoverCacheLimit;
extern const NSUInteger kCoverCacheByteLimit;

extern const NSInteger kStickersPageMasks;
extern const NSInteger kStickersPageEmoji;
extern const NSInteger kStickersPageEmojiTrending;
extern const NSInteger kStickersPageEmojiArchived;
extern const NSInteger kStickersPageMasksArchived;
extern const NSInteger kStickersPageRecent;
extern const NSInteger kStickersPagePremium;
extern const NSInteger kStickersPageGreeting;

extern const NSInteger kSearchLimit;
extern const NSInteger kPremiumLimit;

extern const NSInteger kRootSectionSettings;
extern const NSInteger kRootSectionPages;
extern const NSInteger kRootSectionSets;
extern const NSInteger kRootSectionRecent;

extern NSString *const TGStickerLoopAnimatedKey;
extern NSString *const TGStickerLargeEmojiKey;

NSString *TGStickersSuggestModeName(TGStickerSuggestMode mode);

extern const CGFloat kStickersGroupedInset;
extern const CGFloat kActionRowHeight;
extern const CGFloat kGroupSpacerHeight;

UIColor *TGStickersRGBA(int rgb, CGFloat alpha);
UIColor *TGStickersGreenShadow(void);
UIColor *TGStickersRedShadow(void);
UIImage *TGStickersPlate(NSString *name);
CGFloat TGStickersPlateHeight(NSString *name, CGFloat fallback);
CGFloat TGStickersRetinaPixel(void);
void TGStickersApplyDisclosure(UITableViewCell *cell);
NSString *TGStickersCacheKey(long long fileId, CGFloat side);

@interface TGStickersViewController () <UISearchBarDelegate>

@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIView *placeholder;
@property (nonatomic, strong) UILabel *placeholderTitle;
@property (nonatomic, strong) UILabel *placeholderBody;

@property (nonatomic, strong) NSMutableArray *sets;
@property (nonatomic, strong) NSArray *stickers;
@property (nonatomic, strong) NSMutableDictionary *covers;
@property (nonatomic, strong) NSMutableArray *coverOrder;
@property (nonatomic, assign) NSUInteger coverBytes;
@property (nonatomic, strong) NSMutableSet *coversInFlight;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UIView *bottomBarLine;
@property (nonatomic, strong) UIButton *bottomButton;
@property (nonatomic, strong) NSArray *orderBeforeEdit;
@property (nonatomic, copy) void (^setStateChanged)(BOOL installed);

@property (nonatomic, assign) NSInteger favouriteCount;
@property (nonatomic, assign) NSInteger archivedCount;
@property (nonatomic, assign) NSInteger trendingNewCount;
@property (nonatomic, assign) NSInteger totalRemote;
@property (nonatomic, assign) NSInteger trendingOffset;
@property (nonatomic, assign) NSInteger maskCount;
@property (nonatomic, strong) NSSet *archivedIdsBeforeInstall;

@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL failed;
@property (nonatomic, assign) BOOL loadingMore;
@property (nonatomic, assign) BOOL exhausted;
@property (nonatomic, assign) BOOL reordering;
@property (nonatomic, assign) BOOL installedHere;

@property (nonatomic, strong) TGActionSheet *currentActionSheet;
@property (nonatomic, strong) NSDictionary *actionSheetSet;
@property (nonatomic, strong) NSDictionary *actionSheetSticker;

@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSMutableArray *setsBeforeSearch;
@property (nonatomic, assign) BOOL searching;
@property (nonatomic, assign) BOOL searchFailed;
@property (nonatomic, assign) NSInteger recentCount;
@property (nonatomic, assign) NSInteger emojiSetCount;
@property (nonatomic, assign) NSInteger subpageTrendingCount;
@property (nonatomic, strong) id stickerSetsObserverToken;
@property (nonatomic, strong) id trendingStickerSetsObserverToken;
@property (nonatomic, strong) id favoriteStickersObserverToken;
@property (nonatomic, strong) id recentStickersObserverToken;
@end

@interface TGStickersViewController (Chrome)
- (BOOL)isGridPage;
- (BOOL)isMaskPage;
- (BOOL)isEmojiListPage;
- (BOOL)isTwoSectionListPage;
- (BOOL)isTrendingPage;
- (BOOL)isArchivePage;
- (BOOL)isReorderPage;
- (BOOL)isFavouritesOrRecentPage;
- (BOOL)showsSearchBar;
- (NSInteger)setsSection;
- (NSString *)pageTitle;
- (void)buildSearchBar;
- (NSString *)archiveCheckStickerType;
- (TGStickersPage)archivedPageForStickerType:(NSString *)stickerType;
- (void)fetchArchivedSnapshotOfType:(NSString *)stickerType
						  completion:(void (^)(NSArray *sets, NSInteger totalCount))completion;
- (void)captureArchivedSnapshot;
- (void)checkAutoArchivedSets;
- (BOOL)stickerTypeMatchesTrendingDisplay:(NSString *)stickerType;
- (BOOL)installedStickerSetsChangeAffectsThisPage:(NSString *)stickerType;
- (void)installedStickerSetsChanged:(NSNotification *)note;
- (BOOL)trendingStickerSetsChangeAffectsThisPage:(NSString *)stickerType;
- (void)trendingStickerSetsChanged:(NSNotification *)note;
- (void)favoriteStickersChanged:(NSNotification *)note;
- (void)recentStickersChanged:(NSNotification *)note;
- (void)buildTable;
- (UIView *)gridFooterView;
- (BOOL)showsBottomBar;
- (BOOL)currentSetInstalled;
- (void)buildBottomBar;
- (void)refreshBottomBar;
- (void)bottomButtonTapped;
- (void)layoutBottomBar;
- (void)buildPlaceholder;
- (void)installEditButton;
- (void)refreshSetBarButton;
- (void)layoutChrome;
- (void)showLoading;
- (void)showContent;
- (void)showFailure;
@end

@interface TGStickersViewController (Loading)
- (void)reload;
- (void)fetchArchivedFromSetId:(int64_t)offsetSetId completion:(void (^)(NSArray *sets, NSInteger totalCount))completion;
- (void)fetchTrendingFromOffset:(NSInteger)offset completion:(void (^)(NSArray *sets, NSInteger totalCount))completion;
- (void)reloadEmojiSets;
- (void)reloadSubpageSection;
- (void)reloadRecent;
- (void)reloadPremium;
- (void)reloadGreeting;
- (void)reloadRoot;
- (void)reloadSettingsSection;
- (void)reloadMasks;
- (void)reloadFirstSection;
- (void)reloadArchivedCountBadge;
- (void)reloadTrending;
- (void)loadMoreTrending;
- (void)markShownSetsViewed;
- (void)markSetsViewed:(NSArray *)sets;
- (void)reloadArchived;
- (void)loadMoreArchived;
- (void)reloadFavourites;
- (void)reloadSet;
- (void)flushCovers;
- (NSUInteger)byteCostOfImage:(UIImage *)image;
- (void)storeCover:(UIImage *)image forKey:(NSString *)key;
- (UIImage *)scale:(UIImage *)image toSide:(CGFloat)side;
- (BOOL)stickerIsStill:(NSDictionary *)sticker;
- (UIImage *)imageForFileId:(long long)fileId side:(CGFloat)side indexPath:(NSIndexPath *)indexPath;
- (UIImage *)renderOutlinePaths:(NSArray *)paths width:(CGFloat)width height:(CGFloat)height side:(CGFloat)side;
- (UIImage *)outlineForSticker:(NSDictionary *)sticker side:(CGFloat)side indexPath:(NSIndexPath *)indexPath;
- (long long)coverFileIdForSet:(NSDictionary *)set;
- (UIImage *)coverForSet:(NSDictionary *)set atIndexPath:(NSIndexPath *)indexPath;
- (NSInteger)gridColumns;
- (NSInteger)gridRowCount;
- (UITableViewCell *)tilesCellForTable:(UITableView *)tableView indexPath:(NSIndexPath *)indexPath;
- (void)tileTapped:(UIButton *)tile;
@end

@interface TGStickersViewController (Actions)
- (void)presentSheetWithTitle:(NSString *)title actions:(NSArray *)actions;
- (void)performAction:(NSString *)action;
- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message;
- (void)copyLinkForSet:(NSDictionary *)set;
- (void)shareLinkForSet:(NSDictionary *)set;
- (void)setCurrentStickerFavourite:(BOOL)favourite;
- (void)removeCurrentRecent;
- (void)applySuggestMode:(TGStickerSuggestMode)mode;
- (void)presentSuggestModeSheet;
- (void)largeEmojiToggled:(UISwitch *)toggle;
- (void)loopAnimatedToggled:(UISwitch *)toggle;
- (void)archiveSet:(NSDictionary *)set;
- (void)uninstallSet:(NSDictionary *)set;
- (void)installSet:(NSDictionary *)set fromRow:(NSInteger)row button:(UIButton *)button;
- (void)removeArchivedRow:(NSInteger)row;
- (void)restoreArchivedSet:(NSDictionary *)set;
- (void)applyCurrentSetInstalled:(BOOL)installed;
- (void)toggleCurrentSet;
- (void)shareCurrentSet;
- (void)editCurrentSet;
- (void)clearRecent;
- (void)removeCurrentFavourite;
- (void)editTapped;
- (void)commitOrder;
- (NSString *)trimmedQuery;
- (void)endSearch;
- (void)runSearch;
- (void)openPage:(TGStickersPage)page;
- (void)openSet:(NSDictionary *)set;
- (void)previewedSet:(NSDictionary *)set becameInstalled:(BOOL)installed;
- (NSString *)headerTitleForSection:(NSInteger)section;
- (NSString *)footerTitleForSection:(NSInteger)section;
@end

@interface TGStickersViewController (TableData) <UITableViewDataSource, UITableViewDelegate>
- (NSArray *)rootPageRows;
- (NSArray *)subpageRows;
- (NSDictionary *)setAtIndexPath:(NSIndexPath *)indexPath;
- (NSInteger)stickerCountForSet:(NSDictionary *)set;
- (NSString *)countTextForSet:(NSDictionary *)set;
- (NSString *)addButtonTitle;
- (UIButton *)addButton;
- (void)configureAddButton:(UIButton *)button forRow:(NSInteger)row installed:(BOOL)installed;
- (void)addButtonTapped:(UIButton *)button;
- (UITableViewCell *)plainCellForTable:(UITableView *)tableView;
- (UITableViewCell *)setCellForTable:(UITableView *)tableView indexPath:(NSIndexPath *)indexPath;
- (UITableViewCell *)trendCellForTable:(UITableView *)tableView indexPath:(NSIndexPath *)indexPath;
- (UITableViewCell *)clearRecentCellForTable:(UITableView *)tableView;
- (void)clearRecentTapped;
- (UITableViewCell *)settingsCellForTable:(UITableView *)tableView row:(NSInteger)row;
- (UITableViewCell *)subpageCellForTable:(UITableView *)tableView rowInfo:(NSDictionary *)rowInfo;
@end

@interface TGStickersViewController (Internal)

- (BOOL)currentSetIsEditable;

@end

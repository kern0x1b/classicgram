#import "TGStickerPanelView.h"
#import "TGLocalization.h"

#import <QuartzCore/QuartzCore.h>

#import "TGActionSheet.h"
#import "TGStickerThumbnailCache.h"
#import "TGTheme.h"
#import "TGViewRecycler.h"
#import "TGReusableView.h"
#import "UIView+SafeTint.h"
#import "TGStickerTile.h"

extern const CGFloat kStickerPanelKeyBarHeight;
extern const CGFloat kStickerPanelKeyHeight;
extern const CGFloat kStickerPanelKeyTop;
extern const CGFloat kStickerPanelKeyMinWidth;
extern const CGFloat kStickerPanelFunctionKeyWidth;
extern const CGFloat kStickerPanelHeaderHeight;
extern const CGFloat kStickerPanelTileSide;
extern const CGFloat kStickerPanelSideInset;
extern const CGFloat kStickerPanelRowSpacing;
extern const NSInteger kStickerPanelMinColumns;
extern const CGFloat kStickerPanelTileCornerRadius;
extern const CGFloat kStickerPanelPreviewSide;
extern const CGFloat kStickerPanelSearchHeight;
extern const CGFloat kStickerPanelTabThumbSide;
extern const CGFloat kStickerPanelPurgeDistance;
extern const NSInteger kStickerPanelPageSize;

extern const CGFloat kStickerPanelKeyboardHeightPortrait;
extern const CGFloat kStickerPanelKeyboardHeightLandscape;

extern CGFloat TGStickerPanelMeasuredPortrait;
extern CGFloat TGStickerPanelMeasuredLandscape;
extern const NSInteger kStickerSectionRecent;
extern const NSInteger kStickerSectionFavourite;
extern const NSInteger kStickerSectionSet;
extern const NSInteger kStickerSectionEmojiSet;
extern const NSInteger kStickerSectionTrending;
extern const NSInteger kStickerSectionPublicSet;
extern const NSInteger kStickerSectionSearch;

extern const NSInteger kStickerPanelTrendingLimit;
extern const NSInteger kStickerPanelAddButtonTag;

extern BOOL TGStickerSectionIsSet(NSInteger kind);

UIColor *TGStickerPanelGroundTopColour(void);
UIColor *TGStickerPanelGroundBottomColour(void);
UIColor *TGStickerPanelSeamColour(void);
UIColor *TGStickerPanelEngravedColour(void);
UIImage *TGStickerPanelKeyPlate(BOOL pressed);
UIImage *TGStickerPanelBackspaceGlyph(void);
UIImage *TGStickerPanelSearchGlyph(void);

extern NSMutableArray *TGStickerPanelSectionSnapshot;
extern NSTimeInterval TGStickerPanelSnapshotTaken;
extern const NSTimeInterval kStickerPanelSnapshotLifetime;

@interface TGStickerPanelView () <UIScrollViewDelegate, UISearchBarDelegate> {
	BOOL _searchVisible;
}

@property (nonatomic, strong) UIScrollView *tabStrip;
@property (nonatomic, strong) UIScrollView *grid;
@property (nonatomic, strong) UIView *topSeparator;
@property (nonatomic, strong) CAGradientLayer *ground;
@property (nonatomic, strong) UIView *keyBar;
@property (nonatomic, strong) UIView *keyBarSeam;
@property (nonatomic, strong) UIView *keyBarSheen;
@property (nonatomic, strong) UIButton *backspaceKey;
@property (nonatomic, strong) UIButton *searchKey;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *retryButton;
@property (nonatomic, strong) UISearchBar *searchBar;

@property (nonatomic, strong) TGViewRecycler *recycler;
@property (nonatomic, strong) NSMutableArray *allSections;
@property (nonatomic, strong) NSMutableArray *sections;
@property (nonatomic, strong) NSMutableArray *searchSections;
@property (nonatomic, strong) TGActionSheet *currentActionSheet;
@property (nonatomic, strong) NSDictionary *menuSticker;
@property (nonatomic, assign) NSInteger menuSectionIndex;
@property (nonatomic, assign) BOOL menuStickerFavourite;
@property (nonatomic, strong) NSMutableDictionary *visibleTiles;
@property (nonatomic, strong) NSMutableArray *headerViews;
@property (nonatomic, strong) NSMutableArray *tabButtons;
@property (nonatomic, strong) NSMutableArray *tabDividers;
@property (nonatomic, strong) NSMutableArray *tabImageTokens;
@property (nonatomic, strong) UIView *previewOverlay;
@property (nonatomic, strong) UIView *previewPlate;
@property (nonatomic, strong) UIImageView *previewImageView;
@property (nonatomic, strong) UILabel *previewEmojiLabel;
@property (nonatomic, strong) id previewToken;

@property (nonatomic, copy) NSString *searchQuery;
@property (nonatomic, assign) BOOL searchVisible;
@property (nonatomic, assign) CGFloat gridOffsetBeforeSearch;
@property (nonatomic, assign) NSInteger columns;
@property (nonatomic, assign) CGFloat tileSide;
@property (nonatomic, assign) CGFloat tileSpacing;
@property (nonatomic, assign) CGFloat rowSpacing;
@property (nonatomic, assign) CGFloat sideInset;
@property (nonatomic, assign) NSInteger selectedSection;
@property (nonatomic, assign) CGFloat laidOutWidth;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL failed;
@property (nonatomic, assign) NSInteger generation;
@property (nonatomic, assign) NSInteger searchGeneration;
@property (nonatomic, assign) BOOL searchLoading;
@property (nonatomic, assign) NSInteger searchOutstanding;
@property (nonatomic, assign) NSTimeInterval openedAt;
@property (nonatomic, assign) BOOL openTimingReported;
@property (nonatomic, assign) BOOL restoredFromSnapshot;
@property (nonatomic, strong) id memoryWarningObserverToken;
@property (nonatomic, strong) id stickerSetsObserverToken;
@property (nonatomic, strong) id recentStickersObserverToken;
@property (nonatomic, strong) id favoriteStickersObserverToken;

@end

@interface TGStickerPanelView (Private)

+ (void)noteSystemKeyboardHeight:(CGFloat)height landscape:(BOOL)landscape;

+ (CGFloat)preferredHeightForLandscape:(BOOL)landscape;

- (id)initWithFrame:(CGRect)frame;

- (void)dealloc;

- (void)releaseImageForTile:(TGStickerTile *)tile;

- (void)cancelTabImageLoads;

- (void)cancelAllPendingImageLoads;

- (void)handleMemoryWarning;

- (void)installedStickerSetsChanged:(NSNotification *)note;

- (void)invalidateSectionSnapshot;

- (void)takeSectionSnapshot;

- (BOOL)restoreSectionSnapshot;

- (void)reload;

- (void)reloadShowingSpinner:(BOOL)showSpinner;

- (NSMutableDictionary *)sectionForSet:(NSDictionary *)set kind:(NSInteger)kind;

- (void)buildSectionsWithRecent:(NSArray *)recent
					 favourites:(NSArray *)favourites
						   sets:(NSArray *)sets
					  emojiSets:(NSArray *)emojiSets
					   trending:(NSArray *)trending
						 failed:(BOOL)failed;

- (void)ensureSection:(NSInteger)index loadedUpToItem:(NSInteger)item;

- (void)toggleSearch;

- (void)setSearchVisible:(BOOL)visible;

- (void)restoreGridOffset:(CGFloat)offset;

- (void)applyFilter;

- (BOOL)searchStillCurrent:(NSString *)query
				generation:(NSInteger)generation
		  searchGeneration:(NSInteger)searchGeneration;

- (BOOL)knowsSetId:(NSNumber *)setId;

- (void)insertSearchSection:(NSMutableDictionary *)section order:(NSInteger)order;

- (void)addSearchSection:(NSMutableDictionary *)section order:(NSInteger)order;

- (NSMutableDictionary *)searchResultSectionForStickers:(NSArray *)stickers;

- (void)searchStickersByEmoji:(NSString *)emoji
					 forQuery:(NSString *)query
				   generation:(NSInteger)generation
			 searchGeneration:(NSInteger)searchGeneration;

- (void)runStickerSearchForQuery:(NSString *)query
					  generation:(NSInteger)generation
				searchGeneration:(NSInteger)searchGeneration;

- (void)runPublicSetSearchForQuery:(NSString *)query
						generation:(NSInteger)generation
				  searchGeneration:(NSInteger)searchGeneration;

- (void)runServerSearch;

- (void)searchRequestFinishedForGeneration:(NSInteger)generation
						  searchGeneration:(NSInteger)searchGeneration;

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)text;

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar;

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar;

- (void)layoutSubviews;

- (void)relayoutSections;

- (UIButton *)addButtonForSectionIndex:(NSInteger)index;

- (void)addSetTapped:(UIButton *)button;

- (void)checkArchivedAfterInstall;

- (void)showArchivedNoticeForTitles:(NSArray *)titles;

- (CGRect)frameForItem:(NSInteger)item inSection:(NSInteger)sectionIndex;

- (void)clearTiles;

- (void)updateVisibleTiles;

- (void)reportOpenTiming;

- (void)purgeDistantSectionsAggressively:(BOOL)aggressive;

- (void)configureTile:(TGStickerTile *)tile withSticker:(NSDictionary *)sticker;

- (long long)drawableFileIdForSticker:(NSDictionary *)sticker;

- (NSString *)drawableUniqueIdForSticker:(NSDictionary *)sticker;

- (void)rebuildTabs;

- (NSString *)shortTabTitle:(NSString *)title;

- (void)styleKey:(UIButton *)button;

- (UIButton *)tabKey;

- (UIButton *)functionKeyWithGlyph:(UIImage *)glyph title:(NSString *)title;

- (void)layoutTabs;

- (void)updateTabDividers;

- (void)updateTabSelection;

- (void)setSelectedSection:(NSInteger)index scrollGrid:(BOOL)scrollGrid;

- (void)tabTapped:(UIButton *)button;

- (void)hideTapped;

- (void)backspaceTapped;

- (void)updateStatus;

- (void)tileTapped:(TGStickerTile *)tile;

- (void)cancelPreviewLoad;

- (void)layoutPreview;

- (void)showPreviewForSticker:(NSDictionary *)sticker;

- (void)hidePreview;

- (void)tileLongPressed:(UILongPressGestureRecognizer *)recogniser;

- (NSInteger)sectionIndexForSetId:(NSNumber *)setId;

- (void)presentMenuForSticker:(NSDictionary *)sticker
				 sectionIndex:(NSInteger)sectionIndex
					favourite:(BOOL)favourite;

- (void)performStickerMenuAction:(NSString *)action;

- (void)removeRecentSticker:(NSDictionary *)sticker;

- (void)refreshFavourites;

- (void)refreshRecent;

- (void)scrollViewDidScroll:(UIScrollView *)scrollView;

@end

#import <UIKit/UIKit.h>
#import "TGMediaViewController.h"
#import "TGMediaTileView.h"
#import "TGMediaGridCell.h"

UIImage *TGMediaMinithumbImage(NSDictionary *item);

@class TGClient;
@class TGViewRecycler;

extern const CGFloat kMediaRowHeight;
extern const CGFloat kMediaBannerHeight;
extern const NSInteger kMediaPageSize;
extern const CGFloat kMediaPageGap;
extern const CGFloat kMediaScopeHeight;
extern const CGFloat kMediaScopeButtonHeight;
extern const CGFloat kMediaSearchBarHeight;
extern const CGFloat kMediaListRowHeight;
extern const CGFloat kMediaTopBarFallbackHeight;

CGFloat TGMediaTopBarHeight(void);
CGFloat TGMediaStatusBarInset(void);

UIImage *TGMediaPauseGlyph(CGSize size);
CGFloat TGMediaFullScreenWidth(void);
NSMutableDictionary *TGMediaPhotoFields(NSDictionary *content, TGClient *client, CGFloat scale);
NSMutableDictionary *TGMediaMovingImageFields(NSDictionary *content, TGClient *client,
	NSString *key, NSString *fileType);
NSDictionary *TGMediaItemFromMessage(NSDictionary *message);
NSArray *TGMediaScopeTitles(void);
NSString *TGMediaFilterForScope(NSInteger scope);
BOOL TGMediaScopeIsGrid(NSInteger scope);
NSString *TGMediaEmptyTextForScope(NSInteger scope);
NSString *TGMediaMonthForDate(NSInteger date);
NSString *TGMediaDayForDate(NSInteger date);
NSString *TGMediaFirstUrlInText(NSString *text, NSDictionary *content);
NSMutableDictionary *TGMediaDocumentFields(NSDictionary *content);
NSMutableDictionary *TGMediaAudioFields(NSDictionary *content);
NSMutableDictionary *TGMediaLinkFields(NSDictionary *content);
NSMutableDictionary *TGMediaVoiceFields(NSDictionary *content);
NSDictionary *TGMediaListItemFromMessage(NSDictionary *message, NSInteger scope);

@interface TGMediaViewController () <UIDocumentInteractionControllerDelegate, UISearchBarDelegate>

@property (nonatomic, assign) NSInteger scope;
@property (nonatomic, assign) NSInteger loadToken;
@property (nonatomic, strong) UIView *scopeBar;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, copy) NSString *query;
@property (nonatomic, strong) NSMutableArray *scopeButtons;
@property (nonatomic, strong) UILabel *dateIndicator;
@property (nonatomic, strong) UIDocumentInteractionController *documentController;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) TGViewRecycler *recycler;
@property (nonatomic, strong) NSMutableArray *items;
@property (nonatomic, assign) NSInteger itemsPerRow;
@property (nonatomic, assign) int64_t lastMessageId;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL canLoadMore;
@property (nonatomic, assign) BOOL loadedOnce;
@property (nonatomic, strong) id messageObserverToken;

@property (nonatomic, strong) UIControl *banner;
@property (nonatomic, strong) UILabel *bannerTitle;
@property (nonatomic, strong) UILabel *bannerDetail;
@property (nonatomic, assign) BOOL bannerVisible;

@property (nonatomic, strong) NSMutableDictionary *extensionCache;
@property (nonatomic, strong) NSMutableSet *pendingDownloadFileIds;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) UIImageView *emptyImageView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, assign) BOOL emptyVisible;

- (UIColor *)backgroundColourForScope:(NSInteger)scope;
- (void)layoutEmptyView;
- (void)setEmptyVisible:(BOOL)visible animated:(BOOL)animated;
@end

@interface TGMediaViewController (Search)

- (void)buildScopeBar;
- (void)buildSearchBar;
- (void)updateSearchBarVisibility;
- (void)layoutScopeButtons;

@end

@interface TGMediaViewController (Loading)

- (void)buildDownloadsBanner;
- (void)loadNextPage;
- (void)installMessageObserver;
- (void)checkForMatchingNewMessageId:(int64_t)messageId;
- (void)prependMatchedMessage:(NSDictionary *)message scope:(NSInteger)scope;
- (void)refreshDownloadsBanner;
- (NSInteger)indexOfItemWithMessageId:(int64_t)messageId;
- (BOOL)replaceItemAtMessageId:(int64_t)messageId withMessage:(NSDictionary *)message;

@end

@interface TGMediaViewController (Table) <UITableViewDataSource, UITableViewDelegate, TGMediaGridCellDelegate>

- (void)openChatFocusingMessage:(int64_t)messageId;
- (void)removeItemWithMessageId:(int64_t)messageId;

@end

@interface TGMediaViewController (Actions)

- (void)loadExtensionForMime:(NSString *)mime;

@end

@interface TGMediaViewController (Internal)

- (void)updateTitleForScope;

@end

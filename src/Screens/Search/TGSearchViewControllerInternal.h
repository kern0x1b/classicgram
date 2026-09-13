#import "TGTableReloadCoalescer.h"
#import <UIKit/UIKit.h>
#import "TGSearchViewController.h"
#import "TGSearchResultsPresenter.h"
#import "TGSearchResultsRowBridge.h"
#import "TGSearchRowMetrics.h"

extern const NSInteger kSheetRowActions;
extern const NSInteger kSheetSender;

extern NSString *const kSearchRecentsKey;
extern const NSUInteger kSearchRecentsLimit;

@interface TGSearchViewController () <UISearchBarDelegate, UIActionSheetDelegate,
	TGSearchResultsRowBridgeDelegate> {
  @public
	BOOL _searchFieldStyled;
	TGSearchResultsPresenter *_resultsPresenter;
	TGSearchResultsRowBridge *_resultsRowBridge;
	NSString *_query;
	NSUInteger _generation;
	NSInteger _pending;
	NSInteger _chatSearchPending;
	BOOL _debouncing;
	NSInteger _scope;
	NSString *_messagesOffset;
	int64_t _messagesFromId;
	BOOL _loadingMore;
	int64_t _scopedChatId;
	NSString *_scopedChatTitle;
	int64_t _sheetChatId;
	NSString *_sheetChatTitle;
	BOOL _sheetIsGroup;
	BOOL _sheetIsTopPeer;
	NSInteger _chatTypeIndex;
	NSString *_tagEmoji;
	int64_t _tagCustomEmojiId;
	NSInteger _sheetKind;
	BOOL _scopedIsGroup;
	int64_t _senderUserId;
	NSString *_senderName;
	BOOL _dateAnchored;
	NSString *_anchorLabel;
	NSArray *_contacts;
	NSArray *_contactKeys;
	NSArray *_chatKeys;
	NSArray *_chatKeysBuiltFrom;
}
@property (nonatomic, strong) UISearchBar *bar;
@property (nonatomic, strong) NSArray *chatHits;
@property (nonatomic, strong) NSArray *contactHits;
@property (nonatomic, strong) NSArray *globalHits;
@property (nonatomic, strong) NSArray *messageHits;
@property (nonatomic, strong) NSArray *recents;
@property (nonatomic, strong) NSArray *contacts;
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) NSMutableDictionary *avatars;
@property (nonatomic, strong) NSMutableSet *avatarsRequested;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) NSArray *hashtagHits;
@property (nonatomic, strong) NSArray *recentTags;
@property (nonatomic, strong) NSArray *remoteRecents;
@property (nonatomic, strong) NSMutableArray *scopeButtons;
@property (nonatomic, strong) NSMutableArray *scopeDividers;
@property (nonatomic, strong) UIView *scopeBar;
@property (nonatomic, strong) UIButton *scopeChatButton;
@property (nonatomic, strong) UIButton *scopeSenderButton;
@property (nonatomic, strong) NSArray *topPeers;
@property (nonatomic, strong) NSArray *tmeLinks;
@property (nonatomic, strong) NSArray *senderCandidates;
@property (nonatomic, strong) UIScrollView *tagStrip;
@property (nonatomic, strong) NSMutableArray *tagButtons;
@property (nonatomic, strong) NSArray *savedTags;
@property (nonatomic, strong) UIScrollView *chatTypeStrip;
@property (nonatomic, strong) NSMutableArray *chatTypeButtons;
@property (nonatomic, weak) UITextField *searchField;
@property (nonatomic, strong) NSArray *liveLocations;
@property (nonatomic, strong) NSArray *recentMatches;
@property (nonatomic, strong) id savedTagsObserverToken;
@property (nonatomic, strong) id savedTagImagesObserverToken;
@property (nonatomic, strong) TGTableReloadCoalescer *resultsReload;
@end

@interface TGSearchViewController (Modes)
+ (NSArray *)chatTypeTitles;
+ (NSString *)chatTypeForIndex:(NSInteger)index;
+ (NSArray *)scopeTitles;
+ (NSString *)filterForScope:(NSInteger)scope;
+ (BOOL)isTagQuery:(NSString *)query;
- (BOOL)hasActiveQuery;
@end

@interface TGSearchViewController (ScopeBar)
- (void)buildScopeBar;
- (CGFloat)scopeBarHeight;
- (void)applyScopeInset;
- (void)positionFloatingViews;
- (void)layoutScopeBar;
- (void)updateScopeDividers;
- (void)scopeTapped:(UIButton *)button;
- (UIActionSheet *)sheetWithTitle:(NSString *)title options:(NSArray *)options kind:(NSInteger)kind;
- (void)showSenderSheet;
- (void)presentSenderSheet;
- (void)applySender:(int64_t)userId name:(NSString *)name;
- (void)updatePlaceholder:(NSString *)placeholder;
- (void)applyPlaceholderColour;
- (void)enterChatScope:(int64_t)chatId title:(NSString *)title isGroup:(BOOL)isGroup;
- (void)leaveChatScope;
- (void)loadLiveLocations;
- (void)openCalendarForChat:(int64_t)chatId title:(NSString *)title isGroup:(BOOL)isGroup;
- (void)jumpToDate:(NSInteger)date chat:(int64_t)chatId title:(NSString *)title isGroup:(BOOL)isGroup;
- (void)anchorChat:(int64_t)chatId title:(NSString *)title isGroup:(BOOL)isGroup atMessage:(int64_t)messageId label:(NSString *)label;
- (void)restartSearch;
- (BOOL)scopeIsSavedMessages;
- (void)loadSavedTagsIfNeeded;
- (void)rebuildTagStrip;
- (void)tagTapped:(UIButton *)button;
- (void)chatTypeTapped:(UIButton *)button;
- (NSArray *)flattenSavedMessages:(NSArray *)messages;
- (void)loadTaggedSavedMessagesPage:(NSString *)query generation:(NSUInteger)generation;
@end

@interface TGSearchViewController (Searching)
- (void)loadRecents;
- (void)rememberRecent:(NSDictionary *)row;
- (void)forgetRecentChat:(int64_t)chatId;
- (void)forgetTopPeer:(int64_t)chatId;
- (void)clearRecentTags;
- (void)clearRecents;
- (void)styleSearchInputField:(UIView *)view;
- (void)cancel;
- (void)rebuildContactKeys;
- (void)rebuildChatKeys;
- (void)setContacts:(NSArray *)contacts;
- (void)runLocalSearch;
- (NSArray *)recentRows;
- (void)matchRecentsForQuery:(NSString *)query generation:(NSUInteger)generation;
- (NSString *)shortDateFor:(NSNumber *)stamp;
- (NSArray *)rowsForMessages:(NSArray *)messages inChat:(BOOL)inChat;
- (void)appendMessageRows:(NSArray *)rows;
- (void)centreSnippetsFrom:(NSUInteger)start generation:(NSUInteger)generation;
- (void)runServerSearch:(NSString *)query generation:(NSUInteger)generation;
- (void)loadGlobalMessagesPage:(NSString *)query generation:(NSUInteger)generation;
- (void)loadChatMessagesPage:(NSString *)query generation:(NSUInteger)generation;
- (void)loadTagMessagesPage:(NSString *)tag generation:(NSUInteger)generation;
- (void)loadHashtagSuggestions:(NSString *)tag generation:(NSUInteger)generation;
- (void)loadMoreIfPossible;
- (void)searchPublicChats:(NSString *)query generation:(NSUInteger)generation;
- (BOOL)localChatListIsShort;
- (void)searchChatsOnServer:(NSString *)query generation:(NSUInteger)generation;
- (void)dedupeGlobalHitsAgainstChatHitsIfBothSearchesFinished;
@end

@interface TGSearchViewController (Table)
- (void)rebuildSections;
- (void)updateStatusLabel;
- (NSDictionary *)rowAtIndexPath:(NSIndexPath *)indexPath;
- (UIImage *)avatarForChat:(int64_t)chatId title:(NSString *)title fileId:(NSNumber *)fileId size:(CGFloat)size;
- (BOOL)sectionIsMessages:(NSInteger)section;
- (void)openChat:(int64_t)chatId title:(NSString *)title isGroup:(BOOL)isGroup focusMessageId:(int64_t)focusMessageId;
- (void)openRecentLinkRow:(NSDictionary *)row;
- (void)handleLongPress:(UILongPressGestureRecognizer *)press;
@end

@interface TGSearchViewController (Internal)

- (void)loadOutgoingDocuments:(NSUInteger)generation;

@end

#import "TGStorageViewController.h"

typedef enum {
	TGStorageActionKinds = 0,
	TGStorageActionEverything,
	TGStorageActionClearDrafts
} TGStorageAction;

enum {
	TGStorageSheetConfirm = 3301,
	TGStorageSheetTTL,
	TGStorageSheetSize
};

enum {
	TGStorageSectionSummary = 0,
	TGStorageSectionTypes,
	TGStorageSectionChats,
	TGStorageSectionPolicy,
	TGStorageSectionDownloads,
	TGStorageSectionClear,
	TGStorageSectionEverything,
	TGStorageSectionCount
};

extern NSString *const TGStorageLocalThumbnailKind;
extern const NSInteger kStorageTTLValues[4];
extern const long long TGStorageSizeLadder[8];

void TGStorageApplyTableBackground(UITableView *tableView);
UIView *TGStorageDisclosureIndicator(void);
#import "TGStorageKindName.h"
long long TGStorageDiskTotalBytes(void);
long long TGStorageDiskFreeBytes(void);
long long TGStorageSizeValueAtIndex(NSInteger index);
NSString *TGStorageTTLName(NSInteger ttl);
NSString *TGStorageSizeName(long long maxBytes);

@interface TGStorageViewController () <UIActionSheetDelegate>
@property (nonatomic, assign) long long bytes;
@property (nonatomic, assign) NSInteger files;
@property (nonatomic, assign) BOOL working;
@property (nonatomic, assign) BOOL clearingDrafts;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL refreshing;
@property (nonatomic, assign) BOOL detailLoading;
@property (nonatomic, assign) BOOL detailLoaded;
@property (nonatomic, strong) NSDictionary *overview;
@property (nonatomic, strong) NSArray *typeRows;
@property (nonatomic, assign) long long localThumbnailBytes;
@property (nonatomic, strong) NSArray *chatRows;
@property (nonatomic, strong) NSArray *pendingKinds;
@property (nonatomic, assign) TGStorageAction pendingAction;
@property (nonatomic, copy) NSString *pendingTitle;
@property (nonatomic, strong) NSDictionary *downloadCounts;

- (void)refresh;
- (void)refreshDetail;
- (NSString *)downloadsDetailText;
- (NSInteger)summaryBaseRows;
- (void)openDownloads;
- (void)purgeLocalThumbnailsWithCompletion:(void (^)(long long freed))completion;
- (BOOL)cacheIsEmpty;
- (BOOL)canClear;

@end

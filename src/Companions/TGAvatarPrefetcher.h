#import <UIKit/UIKit.h>

@interface TGAvatarPrefetcher : NSObject

@property (nonatomic, weak) UITableView *tableView;
@property (nonatomic, readonly) NSMutableDictionary *photos;
@property (nonatomic, readonly) NSMutableSet *photosRequested;
@property (nonatomic, readonly) CGFloat avatarSide;
@property (nonatomic, readonly) NSInteger prefetchMargin;
@property (nonatomic, readonly) NSInteger retainMargin;

@property (nonatomic, copy) NSInteger (^rowCountProvider)(void);
@property (nonatomic, copy) NSNumber *(^rowKeyProvider)(NSInteger row);
@property (nonatomic, copy) NSNumber *(^fileIdProvider)(int64_t userId);
@property (nonatomic, copy) void (^downloadProvider)(int64_t fileId, void (^completion)(NSString *path));
@property (nonatomic, copy) void (^photosChangedHandler)(NSNumber *key);
@property (nonatomic, copy) BOOL (^evictionSkipHandler)(void);

- (instancetype)initWithAvatarSide:(CGFloat)avatarSide
					 prefetchMargin:(NSInteger)prefetchMargin
					   retainMargin:(NSInteger)retainMargin;

- (NSSet *)photoKeysWithinRows:(NSInteger)margin;
- (void)evictPhotosOutsideRows:(NSInteger)margin;
- (void)fetchPhotosForRows;
- (void)fetchPhotosForRowsThrottled;

@end

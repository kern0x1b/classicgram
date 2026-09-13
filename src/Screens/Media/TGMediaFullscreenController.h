#import <UIKit/UIKit.h>

@interface TGMediaFullscreenController : UIViewController

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, copy) void (^onMessageDeleted)(int64_t messageId);
@property (nonatomic, copy) void (^onShowInChat)(int64_t messageId);
@property (nonatomic, copy) void (^onOpenStickerSet)(int64_t setId);

- (instancetype)initWithItems:(NSArray *)items index:(NSInteger)index;

@end

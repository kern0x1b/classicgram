#import <UIKit/UIKit.h>

@interface TGStickerPanelView : UIView

@property (nonatomic, copy) void (^onStickerPicked)(NSDictionary *sticker);

@property (nonatomic, copy) void (^onCloseRequested)(void);

@property (nonatomic, copy) BOOL (^onBackspace)(void);

@property (nonatomic, copy) void (^onSearchVisibilityChanged)(BOOL searching);

@property (nonatomic, assign) BOOL suppressesRecentStickerTracking;

+ (CGFloat)preferredHeightForLandscape:(BOOL)landscape;

+ (void)noteSystemKeyboardHeight:(CGFloat)height landscape:(BOOL)landscape;
@end

@interface TGStickerPanelView (Loading)

+ (void)resetSectionSnapshotForAccountSwitch;
- (void)reload;

@end

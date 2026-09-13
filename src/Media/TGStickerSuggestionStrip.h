#import <UIKit/UIKit.h>

@interface TGStickerSuggestionStrip : UIView

@property (nonatomic, copy) void (^onStickerPicked)(NSDictionary *sticker);

@property (nonatomic, copy) void (^onVisibilityChanged)(BOOL visible);

+ (CGFloat)preferredHeight;

- (void)updateForText:(NSString *)text;

- (void)clear;

@end

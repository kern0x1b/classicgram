#import <UIKit/UIKit.h>

@interface TGInlineQueryResultStrip : UIView

@property (nonatomic, copy) void (^onResultPicked)(NSDictionary *result);

@property (nonatomic, copy) void (^onVisibilityChanged)(BOOL visible);

@property (nonatomic, copy) void (^onButtonPicked)(void);

@property (nonatomic, copy) void (^onNeedsMoreResults)(void);

+ (CGFloat)heightForResultCount:(NSUInteger)count;

- (void)showResults:(NSArray *)results;

- (void)appendResults:(NSArray *)results;

- (void)setButtonText:(NSString *)buttonText;

- (void)clear;

@end

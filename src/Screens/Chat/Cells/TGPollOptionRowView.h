#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, TGPollOptionMarkState) {
	TGPollOptionMarkStateNone = 0,
	TGPollOptionMarkStateCorrect,
	TGPollOptionMarkStateWrong
};

@interface TGPollOptionRowView : UIControl

@property (nonatomic, strong, readonly) UIView *fillBar;
@property (nonatomic, strong, readonly) UILabel *titleLabel;
@property (nonatomic, strong, readonly) UILabel *percentLabel;
@property (nonatomic, strong, readonly) UIView *dot;
@property (nonatomic, strong, readonly) UILabel *markLabel;

- (void)setFraction:(CGFloat)fraction percentValue:(NSInteger)percentValue chosen:(BOOL)chosen closed:(BOOL)closed resultsVisible:(BOOL)resultsVisible;
- (void)setFraction:(CGFloat)fraction percentValue:(NSInteger)percentValue chosen:(BOOL)chosen closed:(BOOL)closed resultsVisible:(BOOL)resultsVisible markState:(TGPollOptionMarkState)markState;

@end

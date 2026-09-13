#import <UIKit/UIKit.h>
#import <UIKit/UIGestureRecognizerSubclass.h>

@class TGReplySwipeRecognizer;

@protocol TGReplySwipeCell <NSObject>
@property (nonatomic, strong, readonly) TGReplySwipeRecognizer *replySwipe;
@property (nonatomic, strong) UIView *replyArrow;
@property (nonatomic, strong) UIView *replyArrowPlate;
@property (nonatomic, strong, readonly) UIView *contentView;
@end

@interface TGReplySwipeRecognizer : UIPanGestureRecognizer
@property (nonatomic, copy) BOOL (^shouldBegin)(void);
@end

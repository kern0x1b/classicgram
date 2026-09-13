#import <UIKit/UIKit.h>

@class TGRichTextLayout;

@interface TGTextSelectionOverlay : UIView

@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) TGRichTextLayout *layout;
@property (nonatomic, assign) CGRect bodyFrame;
@property (nonatomic, copy) void (^onCopy)(NSString *selectedText);
@property (nonatomic, copy) void (^onDismiss)(void);

- (void)presentInView:(UIView *)host;

- (void)dismiss;

@end

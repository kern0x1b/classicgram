#import <UIKit/UIKit.h>

@interface TGMediaSendPreviewViewController : UIViewController

@property (nonatomic, strong) UIImage *image;
@property (nonatomic, copy) NSString *videoPath;
@property (nonatomic, assign) NSTimeInterval videoDuration;
@property (nonatomic, assign) CGSize videoSize;
@property (nonatomic, assign) BOOL initialSendOnce;
@property (nonatomic, assign) BOOL allowsSendOnce;
@property (nonatomic, copy) NSString *initialCaption;

@property (nonatomic, copy) void (^onSend)(NSString *caption, BOOL sendOnce, BOOL spoiler, BOOL silent);
@property (nonatomic, copy) void (^onCancel)(void);

@end

#import <UIKit/UIKit.h>

@interface TGStoryAreaEditorViewController : UIViewController

@property (nonatomic, strong) UIImage *preview;
@property (nonatomic, assign) BOOL premium;
@property (nonatomic, copy) NSArray *existingAreas;

@property (nonatomic, copy) void (^onDone)(NSArray *areas);

@end

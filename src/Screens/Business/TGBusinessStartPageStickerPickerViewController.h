#import <UIKit/UIKit.h>

@interface TGBusinessStartPageStickerPickerViewController : UIViewController

@property (nonatomic, copy) void (^onPicked)(NSDictionary *sticker);

@end

#import <UIKit/UIKit.h>

@interface TGGifPickerViewController : UIViewController

+ (void)purgeVideoStillCacheForAccountSwitch;

@property (nonatomic, copy) void (^onPicked)(NSDictionary *gif);

@property (nonatomic, copy) void (^onPickFromLibrary)(void);

@end

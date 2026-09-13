#import <UIKit/UIKit.h>

@interface TGBusinessLocationPickerViewController : UIViewController

- (instancetype)initWithHasPoint:(BOOL)hasPoint
						 latitude:(double)latitude
						longitude:(double)longitude;

@property (nonatomic, copy) void (^onPicked)(double latitude, double longitude);

@end

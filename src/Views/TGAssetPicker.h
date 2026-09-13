#import <UIKit/UIKit.h>

@interface TGAssetPicker : UIViewController

@property (nonatomic, assign) NSUInteger selectionLimit;
@property (nonatomic, copy) void (^onPicked)(NSArray *paths, BOOL spoiler);
@property (nonatomic, copy) void (^onCancelled)(void);

+ (BOOL)available;

+ (void)warmAvailability;

@end

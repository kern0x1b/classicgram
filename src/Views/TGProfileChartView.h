#import <UIKit/UIKit.h>

@interface TGProfileChartView : UIView
@property (nonatomic, strong) NSArray *points;
@property (nonatomic, strong) NSString *leftDate;
@property (nonatomic, strong) NSString *rightDate;
@property (nonatomic, copy) NSString *errorText;
@end

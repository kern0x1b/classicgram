#import <UIKit/UIKit.h>

@interface TGDateLabel : UILabel

@property (nonatomic, strong) NSString *dateText;
@property (nonatomic, strong) NSString *rawDateText;

@property (nonatomic, strong) UIFont *dateFont;
@property (nonatomic, strong) UIFont *dateTextFont;
@property (nonatomic, strong) UIFont *dateLabelFont;

@property (nonatomic, strong) UIColor *disabledColor;

@property (nonatomic) float amWidth;
@property (nonatomic) float pmWidth;
@property (nonatomic) float dstOffset;

@property (nonatomic) bool isDisabled;

- (CGSize)measureTextSize;

@end

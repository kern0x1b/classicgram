#import <UIKit/UIKit.h>

@interface TGInstantViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *fallbackUrl;
@property (nonatomic, copy) NSArray *presetBlocks;
@property (nonatomic, copy) NSString *readerTitle;

+ (UIFont *)fontForKind:(NSString *)kind;
+ (UIColor *)colourForKind:(NSString *)kind;
+ (BOOL)kindIsText:(NSString *)kind;
+ (NSString *)textOfBlock:(NSDictionary *)block;
+ (CGFloat)textWidthForKind:(NSString *)kind width:(CGFloat)width;
+ (CGFloat)heightForBlock:(NSDictionary *)block width:(CGFloat)width;
+ (NSArray *)styledEntitiesForBlock:(NSDictionary *)block kind:(NSString *)kind;

@end

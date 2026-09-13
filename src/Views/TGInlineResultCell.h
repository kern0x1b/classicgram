#import <UIKit/UIKit.h>

@interface TGInlineResultCell : UITableViewCell

+ (NSString *)reuseIdentifier;

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier;

- (void)configureWithResult:(NSDictionary *)result;

- (void)configureAsButtonWithText:(NSString *)text;

@end

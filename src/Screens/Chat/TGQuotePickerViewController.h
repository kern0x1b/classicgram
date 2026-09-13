#import <UIKit/UIKit.h>

@interface TGQuotePickerViewController : UIViewController

@property (nonatomic, copy) NSString *sourceText;
@property (nonatomic, copy) NSArray *sourceEntities;
@property (nonatomic, copy) NSString *authorName;
@property (nonatomic, copy) void (^onQuote)(NSString *quoteText, NSArray *quoteEntities, NSInteger position);

- (id)initWithText:(NSString *)text entities:(NSArray *)entities author:(NSString *)author;

@end

#import <UIKit/UIKit.h>

@interface TGStickerEmojiKeywordsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>

@property (nonatomic, strong) NSDictionary *category;

@end

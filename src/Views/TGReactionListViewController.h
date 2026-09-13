#import <UIKit/UIKit.h>
#import "TGReactionPickerView.h"

@interface TGReactionListViewController : UIViewController

@property (nonatomic, copy) TGReactionOpenProfileBlock onOpenProfile;

- (id)initWithMessage:(int64_t)messageId chatId:(int64_t)chatId chips:(NSArray *)chips;

@end

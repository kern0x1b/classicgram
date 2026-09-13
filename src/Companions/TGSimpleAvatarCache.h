#import <UIKit/UIKit.h>

@interface TGSimpleAvatarCache : NSObject

@property (nonatomic, weak) UITableView *tableView;

- (instancetype)initWithAvatarSide:(CGFloat)avatarSide;

- (UIImage *)avatarForChatId:(int64_t)chatId title:(NSString *)title;

@end

#import <UIKit/UIKit.h>

#import "TGMediaFullscreenController.h"

enum {
	TGMediaScopeMedia = 0,
	TGMediaScopeFiles = 1,
	TGMediaScopeLinks = 2,
	TGMediaScopeMusic = 3,
	TGMediaScopeGifs = 4,
	TGMediaScopeVoice = 5,
};

@interface TGMediaViewController : UIViewController

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) int64_t topicId;
@property (nonatomic, copy) NSString *chatTitle;
@property (nonatomic, assign) NSInteger initialScope;

- (instancetype)initWithChatId:(int64_t)chatId;

@end

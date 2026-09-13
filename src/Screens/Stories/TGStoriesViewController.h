#import <UIKit/UIKit.h>
#import "TGStoryComposer.h"

@interface TGStoriesViewController : UIViewController

- (instancetype)initWithChatId:(int64_t)chatId
					  storyIds:(NSArray *)storyIds
					startIndex:(NSInteger)startIndex;

@property (nonatomic, readonly) int64_t chatId;
@property (nonatomic, strong) NSString *posterName;

+ (void)openStoriesForChat:(int64_t)chatId
					  name:(NSString *)name
					  from:(UIViewController *)controller;

+ (void)pushMyStoriesFrom:(UIViewController *)controller;

+ (UIViewController *)myStoriesController;

+ (void)pushStoriesOfChat:(int64_t)chatId
					 name:(NSString *)name
					 from:(UIViewController *)controller;

@end

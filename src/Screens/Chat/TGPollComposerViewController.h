#import <UIKit/UIKit.h>

@interface TGPollComposerViewController : UITableViewController

@property (nonatomic, copy) void (^onSend)(NSString *question,
	NSArray *options,
	BOOL anonymous,
	BOOL multipleAnswers,
	NSInteger correctOption,
	NSString *explanation,
	void (^completion)(BOOL success));
@end

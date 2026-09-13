#import "TGStoryTextViewController.h"
#import "TGTheme.h"

@implementation TGStoryTextViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];
	UITextView *view = [[UITextView alloc] initWithFrame:self.view.bounds];
	view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	view.editable = NO;
	view.backgroundColor = [UIColor clearColor];
	view.textColor = [[TGTheme shared] primaryTextColour];
	view.font = [UIFont systemFontOfSize:15];
	view.text = self.text ?: @"";
	[self.view addSubview:view];
}

@end

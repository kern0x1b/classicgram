#import "TGChatInputTextView.h"

@implementation TGChatInputTextView

- (void)setText:(NSString *)text {
	[super setText:text];
	if (self.onTextAssigned)
		self.onTextAssigned();
}

@end

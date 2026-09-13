#import "TGBackspaceTextField.h"

@implementation TGBackspaceTextField

- (void)deleteBackward {
	BOOL wasEmpty = self.text.length == 0;
	[super deleteBackward];
	if (wasEmpty)
		[self.backspaceDelegate textFieldDidHitLastBackspace];
}

@end

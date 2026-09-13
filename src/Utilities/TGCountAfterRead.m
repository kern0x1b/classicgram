#import "TGCountAfterRead.h"

NSInteger TGCountAfterRead(NSInteger previous, NSInteger read, BOOL failed) {
	if (failed)
		return previous;
	return read < 0 ? 0 : read;
}

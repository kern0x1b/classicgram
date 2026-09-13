#import <Foundation/Foundation.h>
#import "../../src/Wire/Flatten/TGFlattenMessage.h"
#import "../support/tg_flatten_message_fixture.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
	@autoreleasepool {
		NSData *raw = [NSData dataWithBytesNoCopy:(void *)data length:size freeWhenDone:NO];
		id parsed = [NSJSONSerialization JSONObjectWithData:raw
													 options:NSJSONReadingMutableContainers | NSJSONReadingAllowFragments
													   error:nil];
		if (![parsed isKindOfClass:NSDictionary.class])
			return 0;
		TGFlattenContext *context = TGFlattenMessageFixtureContext();
		TGFlattenMessage((NSDictionary *)parsed, context);
		TGMessagePreview((NSDictionary *)parsed, context);
	}
	return 0;
}

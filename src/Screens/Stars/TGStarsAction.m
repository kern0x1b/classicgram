#import "TGStarsAction.h"

NSDictionary *TGStarsAction(NSString *title,
	NSString *value,
	BOOL destructive,
	void (^block)(void)) {
	NSMutableDictionary *action = [NSMutableDictionary dictionary];
	action[@"title"] = title ?: @"";
	if (value.length)
		action[@"value"] = value;
	if (destructive)
		action[@"destructive"] = @YES;
	if (block)
		action[@"block"] = [block copy];
	return action;
}

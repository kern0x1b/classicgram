#import "TGWallpaperRevertEligibility.h"

NSNumber *TGWallpaperRevertTarget(NSDictionary *message, NSString *currentBackgroundId) {
	if (![message[@"kind"] isEqualToString:@"messageChatSetBackground"])
		return nil;
	if ([message[@"outgoing"] boolValue])
		return nil;
	if ([message[@"onlyForSelf"] boolValue])
		return nil;

	NSNumber *backgroundId = [message[@"backgroundId"] isKindOfClass:NSNumber.class]
		? message[@"backgroundId"]
		: nil;
	if (!backgroundId || !currentBackgroundId.length)
		return nil;
	if ([currentBackgroundId longLongValue] != [backgroundId longLongValue])
		return nil;

	NSNumber *oldId = [message[@"oldBackgroundMessageId"] isKindOfClass:NSNumber.class]
		? message[@"oldBackgroundMessageId"]
		: nil;
	if (oldId && [oldId longLongValue])
		return oldId;

	NSNumber *messageId = [message[@"id"] isKindOfClass:NSNumber.class] ? message[@"id"] : nil;
	if (!messageId || ![messageId longLongValue])
		return nil;
	return messageId;
}

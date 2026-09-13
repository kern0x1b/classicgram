#import "TGServiceNotificationAlert.h"

NSString *const TGServiceNotificationTextKey = @"text";
NSString *const TGServiceNotificationNeedsLogOutKey = @"needsLogOut";

static NSString *TGServiceNotificationText(NSDictionary *content) {
	if (![content isKindOfClass:NSDictionary.class])
		return nil;
	id formatted = content[@"text"] ?: content[@"caption"];
	if ([formatted isKindOfClass:NSDictionary.class])
		formatted = ((NSDictionary *) formatted)[@"text"];
	if (![formatted isKindOfClass:NSString.class])
		return nil;
	NSString *text = [formatted stringByTrimmingCharactersInSet:
		[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	return text.length ? text : nil;
}

NSDictionary *TGServiceNotificationAlert(NSDictionary *update) {
	if (![update isKindOfClass:NSDictionary.class])
		return nil;
	NSString *text = TGServiceNotificationText(update[@"content"]);
	if (!text)
		return nil;
	id type = update[@"type"];
	BOOL needsLogOut = [type isKindOfClass:NSString.class] &&
		[(NSString *) type hasPrefix:@"AUTH_KEY_DROP_"];
	return @{
		TGServiceNotificationTextKey : text,
		TGServiceNotificationNeedsLogOutKey : @(needsLogOut),
	};
}

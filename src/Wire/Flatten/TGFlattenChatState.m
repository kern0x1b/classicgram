#import "TGFlattenChatState.h"

NSString *TGScopeType(NSString *scope) {
	if ([scope isEqualToString:@"groups"])
		return @"notificationSettingsScopeGroupChats";
	if ([scope isEqualToString:@"channels"])
		return @"notificationSettingsScopeChannelChats";
	return @"notificationSettingsScopePrivateChats";
}

NSString *TGScopeName(NSString *scopeType) {
	if ([scopeType isEqualToString:@"notificationSettingsScopeGroupChats"])
		return @"groups";
	if ([scopeType isEqualToString:@"notificationSettingsScopeChannelChats"])
		return @"channels";
	return @"private";
}

NSString *TGScopeForChatFlags(BOOL isChannel, BOOL isGroup) {
	if (isChannel)
		return @"channels";
	if (isGroup)
		return @"groups";
	return @"private";
}

BOOL TGEffectiveChatMuted(BOOL useDefaultMuteFor, long long chatMuteFor, long long scopeDefaultMuteFor) {
	if (useDefaultMuteFor)
		return scopeDefaultMuteFor > 0;
	return chatMuteFor > 0;
}

NSDictionary *TGFlattenFileObjectState(NSDictionary *file) {
	if (![file isKindOfClass:NSDictionary.class])
		return nil;
	NSDictionary *local = [file[@"local"] isKindOfClass:NSDictionary.class]
		? file[@"local"]
		: @{};
	long long size = [file[@"size"] longLongValue];
	if (size <= 0)
		size = [file[@"expected_size"] longLongValue];
	NSString *path = [local[@"path"] isKindOfClass:NSString.class] ? local[@"path"] : @"";
	return @{
		@"fileId" : file[@"id"] ?: @0,
		@"size" : @(size),
		@"downloaded" : local[@"downloaded_size"] ?: @0,
		@"complete" : @([local[@"is_downloading_completed"] boolValue]),
		@"active" : @([local[@"is_downloading_active"] boolValue]),
		@"path" : path,
	};
}

#import "TGChatRowText.h"
#import "TGDurationText.h"
#import "TGFlattenMessage.h"
#import "TGLocalization.h"
#import "TGStringTruncation.h"

NSString *TGPinnedDescriptor(NSDictionary *target) {
	NSString *kind = [target isKindOfClass:[NSDictionary class]] ? target[@"kind"] : nil;
	NSString *descriptor = TGPinnedDescriptorForContentKind(kind);
	if (descriptor.length)
		return descriptor;

	NSString *body = [target[@"text"] isKindOfClass:NSString.class]
		? target[@"text"]
		: @"";
	body = [[body componentsSeparatedByCharactersInSet:
			[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" "];
	body = [body stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceCharacterSet]];
	if (!body.length)
		return TGL(@"Chat.PinnedDescriptor.Message", @"a message");
	if (body.length > 14)
		body = [TGSafeSubstringToIndex(body, 14) stringByAppendingString:@"..."];
	return [NSString stringWithFormat:@"\"%@\"", body];
}

TGFileStatusKind TGFileStatusKindForState(NSDictionary *state, BOOL playable, BOOL playing) {
	if (playing)
		return TGFileStatusKindPause;
	if ([state[@"active"] boolValue] && ![state[@"local"] boolValue])
		return TGFileStatusKindProgress;
	if (playable)
		return TGFileStatusKindPlay;
	if ([state[@"local"] boolValue])
		return TGFileStatusKindFile;
	return TGFileStatusKindDownload;
}

NSString *TGClockText(NSInteger seconds) {
	return TGDurationText(seconds);
}

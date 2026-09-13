#import "TGCallsRowText.h"
#import "TGTheme.h"
#import "TGStringTruncation.h"
#import "TGDurationText.h"
#import "TGLocalization.h"

UIColor *TGCallsMissedColour(void) {
	return [[TGTheme shared] groupedDestructiveColour];
}

NSString *TGCallsDurationText(NSInteger seconds) {
	if (seconds <= 0)
		return @"";
	return TGDurationText(seconds);
}

BOOL TGCallsWasMissedByMe(NSDictionary *call) {
	return [call[@"missed"] boolValue] && ![call[@"declined"] boolValue] && ![call[@"outgoing"] boolValue];
}

NSString *TGCallsKindText(NSDictionary *call) {
	BOOL outgoing = [call[@"outgoing"] boolValue];
	BOOL video = [call[@"video"] boolValue];

	if (TGCallsWasMissedByMe(call))
		return video ? TGL(@"Notification.VideoCallMissed", @"Missed Video Call")
					 : TGL(@"Notification.CallMissed", @"Missed Call");
	return outgoing ? (video ? TGL(@"Notification.VideoCallOutgoing", @"Outgoing Video Call")
								: TGL(@"Notification.CallOutgoing", @"Outgoing Call"))
					: (video ? TGL(@"Notification.VideoCallIncoming", @"Incoming Video Call")
								: TGL(@"Notification.CallIncoming", @"Incoming Call"));
}

NSString *TGCallsSubtitleText(NSDictionary *call) {
	NSString *kind = TGCallsKindText(call);
	NSString *duration = TGCallsDurationText([call[@"duration"] integerValue]);
	if (!duration.length)
		return kind;
	return [NSString stringWithFormat:@"%@ (%@)", kind, duration];
}

NSString *TGCallsInitials(NSString *name) {
	NSString *trimmed = [(name ?: @"") stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!trimmed.length)
		return @"?";
	return [TGSafeFirstCharacter(trimmed) uppercaseString];
}

NSString *TGCallsDisplayName(NSDictionary *group) {
	NSString *name = group[@"name"];
	if ([name isKindOfClass:NSString.class] && name.length)
		return name;
	return TGL(@"Contacts.UnknownName", @"Unknown");
}

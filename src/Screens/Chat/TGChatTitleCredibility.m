#import "TGChatTitleCredibility.h"

#import "TGChatTitleMute.h"
#import "TGLocalization.h"

static const CGFloat kMarkTopOffset = 3.0f;

static BOOL TGChatTitleBool(id value) {
	return [value isKindOfClass:NSNumber.class] && [value boolValue];
}

NSString *TGChatTitleCredibilityMark(NSDictionary *badges) {
	if (![badges isKindOfClass:NSDictionary.class])
		return nil;
	if (TGChatTitleBool(badges[@"isScam"]))
		return [TGL(@"Message.ScamAccount", @"Scam") uppercaseString];
	if (TGChatTitleBool(badges[@"isFake"]))
		return [TGL(@"Message.FakeAccount", @"Fake") uppercaseString];
	if (TGChatTitleBool(badges[@"isVerified"]))
		return @"✓";
	return nil;
}

BOOL TGChatTitleCredibilityMarkIsWarning(NSDictionary *badges) {
	if (![badges isKindOfClass:NSDictionary.class])
		return NO;
	return TGChatTitleBool(badges[@"isScam"]) || TGChatTitleBool(badges[@"isFake"]);
}

CGFloat TGChatTitleCredibilityRoom(CGFloat markWidth) {
	if (markWidth <= 0.0f)
		return 0.0f;
	return markWidth + kTGChatTitleMuteIconGap;
}

CGRect TGChatTitleCredibilityFrame(CGFloat titleWidth, CGFloat nameTextWidth, CGSize markSize,
	CGFloat nameTop) {
	CGFloat textWidth = MIN(titleWidth, nameTextWidth);
	CGFloat left = (titleWidth - textWidth) / 2 + textWidth + kTGChatTitleMuteIconGap;
	return CGRectMake(left, nameTop + kMarkTopOffset, markSize.width, markSize.height);
}

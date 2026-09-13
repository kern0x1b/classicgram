#import "TGFlattenReactions.h"
#import "TGLocalization.h"

NSString *TGReactionUnavailability(NSDictionary *reason) {
	if (![reason isKindOfClass:NSDictionary.class])
		return @"";
	NSString *t = reason[@"@type"];
	if ([t isEqualToString:@"reactionUnavailabilityReasonAnonymousAdministrator"]
		|| [t isEqualToString:@"reactionUnavailabilityReasonGuest"]
		|| [t isEqualToString:@"reactionUnavailabilityReasonRestricted"])
		return TGL(@"Chat.SendReactionRestricted", @"You cannot send reactions in this chat.");
	return @"";
}

NSString *TGReactionChipSignature(NSArray *chips) {
	if (![chips isKindOfClass:NSArray.class])
		return @"";
	NSMutableString *sig = [NSMutableString string];
	for (NSDictionary *chip in chips) {
		if (![chip isKindOfClass:NSDictionary.class])
			continue;
		NSString *emoji = chip[@"emoji"];
		if (![emoji isKindOfClass:NSString.class])
			emoji = @"";
		[sig appendFormat:@"%@|%d|%d;", emoji,
			(int)[chip[@"count"] integerValue],
			[chip[@"chosen"] boolValue] ? 1 : 0];
	}
	return sig;
}

int64_t TGReactionSenderId(NSDictionary *sender) {
	if (![sender isKindOfClass:NSDictionary.class])
		return 0;
	if ([sender[@"@type"] isEqualToString:@"messageSenderChat"])
		return [sender[@"chat_id"] longLongValue];
	return [sender[@"user_id"] longLongValue];
}

NSInteger TGReactionUserQuota(BOOL isPremium) {
	return isPremium ? 3 : 1;
}

BOOL TGReactionHasRoomForMore(NSInteger chosenByCurrentUser,
							  NSInteger totalDistinctOnMessage,
							  NSInteger chatMaxReactionCount,
							  BOOL isPremium) {
	if (chosenByCurrentUser >= TGReactionUserQuota(isPremium))
		return NO;
	NSInteger effectiveChatMax = chatMaxReactionCount > 0 ? chatMaxReactionCount : 1;
	return totalDistinctOnMessage < effectiveChatMax;
}

BOOL TGReactionTypeExistsOnMessage(NSString *emoji, NSArray *existingReactionTypes) {
	if (![emoji isKindOfClass:NSString.class] || emoji.length == 0)
		return NO;
	if (![existingReactionTypes isKindOfClass:NSArray.class])
		return NO;
	for (id candidate in existingReactionTypes) {
		if ([candidate isKindOfClass:NSString.class] && [candidate isEqualToString:emoji])
			return YES;
	}
	return NO;
}

BOOL TGChatIsSavedMessages(int64_t chatId, int64_t savedMessagesChatId) {
	return chatId != 0 && savedMessagesChatId != 0 && chatId == savedMessagesChatId;
}

NSString *TGSavedMessagesTagLookupKey(NSString *emoji, int64_t customEmojiId) {
	if (emoji.length)
		return emoji;
	if (customEmojiId)
		return [NSString stringWithFormat:@"custom:%lld", customEmojiId];
	return nil;
}

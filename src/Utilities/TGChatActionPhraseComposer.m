#import "TGChatActionPhraseComposer.h"
#import "TGLocalization.h"

NSString *TGChatActionTypingVerb(void) {
	return TGL(@"Chat.TypingVerb", @"typing...");
}

NSString *TGComposeChatActionDisplayPhrase(NSArray<NSString *> *displayNames, NSArray<NSString *> *allPhrases) {
	if (!allPhrases.count)
		return @"";

	NSString *firstName = displayNames.firstObject ?: @"";
	NSString *firstPhrase = allPhrases.firstObject ?: @"";
	if (allPhrases.count == 1)
		return [NSString stringWithFormat:TGL(@"Chat.TypingSingleUserFormat", @"%@ is %@"),
			firstName, firstPhrase];

	BOOL sameKind = YES;
	for (NSString *phrase in allPhrases) {
		if (![phrase isEqualToString:firstPhrase]) {
			sameKind = NO;
			break;
		}
	}
	NSString *verb = sameKind ? firstPhrase : TGChatActionTypingVerb();

	if (allPhrases.count == 2) {
		NSString *secondName = displayNames.count > 1 ? displayNames[1] : @"";
		return [NSString stringWithFormat:TGL(@"Chat.TypingTwoUsersFormat", @"%@ and %@ are %@"),
			firstName, secondName, verb];
	}

	NSInteger othersCount = (NSInteger)allPhrases.count - 1;
	return [NSString stringWithFormat:TGL(@"Chat.TypingUserAndOthersFormat", @"%@ and %@ others are %@"),
		firstName, @(othersCount), verb];
}

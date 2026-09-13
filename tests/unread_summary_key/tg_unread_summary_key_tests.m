#import "tg_unread_summary_key_tests.h"
#import "../../src/Screens/ChatList/TGUnreadSummaryKey.h"

TGTestOutcome TGUnreadSummaryKeyTestTheChipReadsWhatTheBadgeCounts(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGUnreadSummaryKeyForBadge(NO, NO) isEqualToString:@"unmutedMessages"],
			"the default - count messages, leave muted chats out - is what the folder chip shows");
	TGTestExpectTrue(&outcome,
			[TGUnreadSummaryKeyForBadge(NO, YES) isEqualToString:@"messages"],
			"including muted chats counts their messages too");
	TGTestExpectTrue(&outcome,
			[TGUnreadSummaryKeyForBadge(YES, NO) isEqualToString:@"unmutedChats"],
			"when the badge counts chats the chip counts chats, or the two numbers on one screen "
			"would mean different things");
	TGTestExpectTrue(&outcome,
			[TGUnreadSummaryKeyForBadge(YES, YES) isEqualToString:@"chats"],
			"and with muted chats included it is every chat that has something unread");

	return outcome;
}

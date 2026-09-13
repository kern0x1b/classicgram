#import "tg_chat_date_kind_tests.h"
#import "../../src/Screens/ChatList/TGChatDateKind.h"

TGTestOutcome TGChatDateKindTestTheRowShowsTimeThenWeekdayThenDate(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGChatDateKindForAge(YES, 0) == TGChatDateKindTime,
			"today's message shows the time it arrived");
	TGTestExpectTrue(&outcome, TGChatDateKindForAge(YES, 1) == TGChatDateKindWeekday,
			"yesterday shows the weekday, as the original client does");
	TGTestExpectTrue(&outcome, TGChatDateKindForAge(YES, 6) == TGChatDateKindWeekday,
			"six days back is the last day a weekday name is still unambiguous");
	TGTestExpectTrue(&outcome, TGChatDateKindForAge(YES, 7) == TGChatDateKindFullDate,
			"a week back would repeat a weekday name, so the date is shown instead");
	TGTestExpectTrue(&outcome, TGChatDateKindForAge(NO, 0) == TGChatDateKindFullDate,
			"another year is always the full date, even on the same day of the year");
	TGTestExpectTrue(&outcome, TGChatDateKindForAge(YES, -1) == TGChatDateKindFullDate,
			"a message dated in the future - a clock out of step - falls back to the date rather "
			"than being called today");

	return outcome;
}

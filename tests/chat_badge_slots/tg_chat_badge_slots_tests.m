#import "tg_chat_badge_slots_tests.h"
#import "../../src/Screens/ChatList/TGChatBadgeSlots.h"

TGTestOutcome TGChatBadgeSlotsTestTheCounterKeepsItsOldPlace(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatBadgeSlots slots = TGChatBadgeSlotsInWidth(320, 9, YES, NO, NO, NO);
	TGTestExpectTrue(&outcome, slots.count.size.width == 27,
			"a one-digit counter keeps the minimum badge width");
	TGTestExpectTrue(&outcome, slots.count.origin.x == 320 - 28 - 27,
			"the counter still sits 28 points from the right edge");
	TGTestExpectTrue(&outcome, slots.count.origin.y == 29 && slots.count.size.height == 21,
			"the counter keeps its row position and height");
	TGTestExpectTrue(&outcome, slots.consumedWidth == 27 + 7,
			"a lone counter consumes its own width plus the trailing gap");

	TGChatBadgeSlots wide = TGChatBadgeSlotsInWidth(320, 30, YES, NO, NO, NO);
	TGTestExpectTrue(&outcome, wide.count.size.width == 40,
			"a wider count text widens the badge by its padding");

	return outcome;
}

TGTestOutcome TGChatBadgeSlotsTestAMentionSitsLeftOfTheCounter(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatBadgeSlots both = TGChatBadgeSlotsInWidth(320, 9, YES, YES, NO, NO);
	TGTestExpectTrue(&outcome, both.count.origin.x == 320 - 28 - 27,
			"the counter stays right-most when a mention is present");
	TGTestExpectTrue(&outcome, both.mention.origin.x == both.count.origin.x - 6 - 27,
			"the mention badge sits a gap to the left of the counter");
	TGTestExpectTrue(&outcome, both.consumedWidth == 27 + 6 + 27 + 7,
			"both badges together consume their widths, the gap between them and the trailing gap");

	TGChatBadgeSlots alone = TGChatBadgeSlotsInWidth(320, 0, NO, YES, NO, NO);
	TGTestExpectTrue(&outcome, alone.mention.origin.x == 320 - 28 - 27,
			"a mention with no counter takes the counter's place");
	TGTestExpectTrue(&outcome, alone.consumedWidth == 27 + 7,
			"a lone mention consumes one badge width");

	return outcome;
}

TGTestOutcome TGChatBadgeSlotsTestAPinOnlyAppearsWhenNothingElseDoes(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatBadgeSlots pinned = TGChatBadgeSlotsInWidth(320, 0, NO, NO, NO, YES);
	TGTestExpectTrue(&outcome, pinned.pin.origin.x == 320 - 28 - 27,
			"a lone pin takes the right-most place");
	TGTestExpectTrue(&outcome, pinned.consumedWidth == 27 + 7,
			"a lone pin consumes one badge width");

	TGChatBadgeSlots crowded = TGChatBadgeSlotsInWidth(320, 9, YES, YES, NO, YES);
	TGTestExpectTrue(&outcome, CGRectIsEmpty(crowded.pin),
			"the pin gives way to a counter and a mention");
	TGTestExpectTrue(&outcome, crowded.consumedWidth == 27 + 6 + 27 + 7,
			"a suppressed pin consumes nothing");

	TGChatBadgeSlots empty = TGChatBadgeSlotsInWidth(320, 0, NO, NO, NO, NO);
	TGTestExpectTrue(&outcome, empty.consumedWidth == 0,
			"a row with no badge at all consumes nothing");

	return outcome;
}

TGTestOutcome TGChatBadgeSlotsTestAReactionSitsLeftOfTheMention(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGChatBadgeSlots all = TGChatBadgeSlotsInWidth(320, 9, YES, YES, YES, NO);
	TGTestExpectTrue(&outcome, all.count.origin.x == 320 - 28 - 27,
			"the counter stays right-most whatever else is shown");
	TGTestExpectTrue(&outcome, all.mention.origin.x == all.count.origin.x - 6 - 27,
			"the mention keeps its place beside the counter");
	TGTestExpectTrue(&outcome, all.reaction.origin.x == all.mention.origin.x - 6 - 27,
			"the reaction badge sits a gap to the left of the mention");
	TGTestExpectTrue(&outcome, all.consumedWidth == 27 * 3 + 6 * 2 + 7,
			"three badges consume their widths, both gaps and the trailing gap");

	TGChatBadgeSlots alone = TGChatBadgeSlotsInWidth(320, 0, NO, NO, YES, NO);
	TGTestExpectTrue(&outcome, alone.reaction.origin.x == 320 - 28 - 27,
			"a lone reaction takes the right-most place");
	TGTestExpectTrue(&outcome, CGRectIsEmpty(alone.mention),
			"a reaction alone leaves no mention frame behind");

	TGChatBadgeSlots pinned = TGChatBadgeSlotsInWidth(320, 0, NO, NO, YES, YES);
	TGTestExpectTrue(&outcome, CGRectIsEmpty(pinned.pin),
			"the pin gives way to a reaction as it does to a mention");

	return outcome;
}

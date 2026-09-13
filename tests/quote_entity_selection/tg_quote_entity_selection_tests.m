#import "tg_quote_entity_selection_tests.h"
#import "../../src/Screens/Chat/TGQuoteEntitySelection.h"

static NSDictionary *TGQuoteEntityTestEntity(NSString *kind, NSInteger offset, NSInteger length) {
	return @{@"kind" : kind, @"offset" : @(offset), @"length" : @(length)};
}

TGTestOutcome TGQuoteEntitySelectionTestEmptySelectionReturnsNoEntities(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *entities = @[TGQuoteEntityTestEntity(@"Bold", 0, 5)];
	NSArray *result = TGQuoteEntitiesForSelectedRange(entities, NSMakeRange(3, 0));

	TGTestExpectEqualInteger(&outcome, result.count, 0,
			"a zero-length selection must never carry any entity into the quote");

	return outcome;
}

TGTestOutcome TGQuoteEntitySelectionTestEntityFullyInsideSelectionKeepsLengthAndShiftsOffset(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *entities = @[TGQuoteEntityTestEntity(@"Bold", 5, 3)];
	NSArray *result = TGQuoteEntitiesForSelectedRange(entities, NSMakeRange(2, 20));

	TGTestExpectEqualInteger(&outcome, result.count, 1,
			"an entity entirely within the selection must survive");
	NSDictionary *shifted = result.firstObject;
	TGTestExpectEqualLongLong(&outcome, [shifted[@"offset"] longLongValue], 3,
			"offset must be relative to the start of the selection");
	TGTestExpectEqualLongLong(&outcome, [shifted[@"length"] longLongValue], 3,
			"length must be unchanged when the entity is not clipped");

	return outcome;
}

TGTestOutcome TGQuoteEntitySelectionTestEntityFullyOutsideSelectionIsDropped(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *entities = @[TGQuoteEntityTestEntity(@"Italic", 0, 2)];
	NSArray *result = TGQuoteEntitiesForSelectedRange(entities, NSMakeRange(10, 5));

	TGTestExpectEqualInteger(&outcome, result.count, 0,
			"an entity that ends before the selection starts must not appear in the quote");

	return outcome;
}

TGTestOutcome TGQuoteEntitySelectionTestEntityClippedAtSelectionStart(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *entities = @[TGQuoteEntityTestEntity(@"Bold", 0, 10)];
	NSArray *result = TGQuoteEntitiesForSelectedRange(entities, NSMakeRange(5, 10));

	TGTestExpectEqualInteger(&outcome, result.count, 1,
			"an entity that starts before the selection but overlaps it must be clipped, not dropped");
	NSDictionary *shifted = result.firstObject;
	TGTestExpectEqualLongLong(&outcome, [shifted[@"offset"] longLongValue], 0,
			"the clipped entity must start at the beginning of the quote");
	TGTestExpectEqualLongLong(&outcome, [shifted[@"length"] longLongValue], 5,
			"only the part of the entity inside the selection must be kept");

	return outcome;
}

TGTestOutcome TGQuoteEntitySelectionTestEntityClippedAtSelectionEnd(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *entities = @[TGQuoteEntityTestEntity(@"Underline", 8, 10)];
	NSArray *result = TGQuoteEntitiesForSelectedRange(entities, NSMakeRange(0, 10));

	TGTestExpectEqualInteger(&outcome, result.count, 1,
			"an entity that extends past the selection end must be clipped, not dropped");
	NSDictionary *shifted = result.firstObject;
	TGTestExpectEqualLongLong(&outcome, [shifted[@"offset"] longLongValue], 8,
			"the clipped entity keeps its position relative to the selection start");
	TGTestExpectEqualLongLong(&outcome, [shifted[@"length"] longLongValue], 2,
			"only the part of the entity inside the selection must be kept");

	return outcome;
}

TGTestOutcome TGQuoteEntitySelectionTestEntitySpanningWholeSelectionIsClippedBothSides(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *entities = @[TGQuoteEntityTestEntity(@"Spoiler", 0, 100)];
	NSArray *result = TGQuoteEntitiesForSelectedRange(entities, NSMakeRange(5, 10));

	TGTestExpectEqualInteger(&outcome, result.count, 1,
			"an entity that spans the entire selection must still be represented once");
	NSDictionary *shifted = result.firstObject;
	TGTestExpectEqualLongLong(&outcome, [shifted[@"offset"] longLongValue], 0,
			"an entity that starts before the selection must be re-based to offset zero");
	TGTestExpectEqualLongLong(&outcome, [shifted[@"length"] longLongValue], 10,
			"the kept length must equal the selection length when the entity covers it entirely");

	return outcome;
}

TGTestOutcome TGQuoteEntitySelectionTestOtherFieldsArePreservedAfterAdjustment(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *entity = @{
		@"kind" : @"CustomEmoji",
		@"offset" : @(2),
		@"length" : @(3),
		@"customEmojiId" : @(998877),
	};
	NSArray *result = TGQuoteEntitiesForSelectedRange(@[entity], NSMakeRange(0, 10));

	TGTestExpectEqualInteger(&outcome, result.count, 1,
			"the entity must still be included when it fits inside the selection");
	NSDictionary *shifted = result.firstObject;
	TGTestExpectTrue(&outcome, [shifted[@"kind"] isEqualToString:@"CustomEmoji"],
			"the entity kind must survive the range adjustment untouched");
	TGTestExpectEqualLongLong(&outcome, [shifted[@"customEmojiId"] longLongValue], 998877,
			"fields other than offset and length must be carried over unchanged");

	return outcome;
}

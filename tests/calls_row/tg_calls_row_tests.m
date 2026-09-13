#import "tg_calls_row_tests.h"
#import "../../src/Screens/Calls/TGCallsRowText.h"
#import "../../src/Screens/Calls/TGCallListCell.h"
#import "../../src/Screens/Calls/Items/TGCallsItem.h"
#import "../../src/Screens/Calls/Items/TGCallsItemBuilder.h"

TGTestOutcome TGCallsRowTestKindTextNamesEveryCombination(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGCallsKindText(@{}) isEqualToString:@"Incoming Call"],
			"a call with no flags at all is an incoming voice call");
	TGTestExpectTrue(&outcome,
			[TGCallsKindText(@{@"outgoing" : @YES}) isEqualToString:@"Outgoing Call"],
			"an outgoing voice call says so");
	TGTestExpectTrue(&outcome,
			[TGCallsKindText(@{@"video" : @YES}) isEqualToString:@"Incoming Video Call"],
			"video changes the noun, not the direction");
	TGTestExpectTrue(&outcome,
			[TGCallsKindText(@{@"outgoing" : @YES, @"video" : @YES})
					isEqualToString:@"Outgoing Video Call"],
			"an outgoing video call names both");
	TGTestExpectTrue(&outcome,
			[TGCallsKindText(@{@"missed" : @YES}) isEqualToString:@"Missed Call"],
			"a call that rang here and was never answered is the one the list calls missed");
	TGTestExpectTrue(&outcome,
			[TGCallsKindText(@{@"missed" : @YES, @"outgoing" : @YES})
					isEqualToString:@"Outgoing Call"],
			"a call we placed and gave up on is still a call we made, never one we missed");
	TGTestExpectTrue(&outcome,
			[TGCallsKindText(@{@"missed" : @YES, @"video" : @YES})
					isEqualToString:@"Missed Video Call"],
			"a missed video call keeps the noun");
	TGTestExpectTrue(&outcome,
			[TGCallsKindText(@{@"missed" : @YES, @"declined" : @YES})
					isEqualToString:@"Incoming Call"],
			"a call we turned down was not missed - we answered it by declining it");
	TGTestExpectTrue(&outcome,
			[TGCallsKindText(@{@"missed" : @YES, @"declined" : @YES, @"video" : @YES})
					isEqualToString:@"Incoming Video Call"],
			"declining a video call reads the same way");
	TGTestExpectTrue(&outcome,
			[TGCallsKindText(@{@"missed" : @YES, @"declined" : @YES, @"outgoing" : @YES})
					isEqualToString:@"Outgoing Call"],
			"the other side declining our call leaves it an outgoing call");
	TGTestExpectTrue(&outcome,
			[TGCallsKindText(@{@"missed" : @YES, @"outgoing" : @YES, @"video" : @YES})
					isEqualToString:@"Outgoing Video Call"],
			"all three flags together");

	NSArray *everyCall = @[ @{}, @{@"outgoing" : @YES}, @{@"video" : @YES},
		@{@"missed" : @YES}, @{@"missed" : @YES, @"outgoing" : @YES},
		@{@"missed" : @YES, @"declined" : @YES},
		@{@"missed" : @YES, @"declined" : @YES, @"outgoing" : @YES} ];
	for (NSDictionary *call in everyCall) {
		BOOL saysMissed = [TGCallsKindText(call) rangeOfString:@"Missed"].location != NSNotFound;
		TGTestExpectTrue(&outcome, saysMissed == TGCallsWasMissedByMe(call),
				"a row reads as missed exactly when it is drawn in the missed colour");
	}

	return outcome;
}

TGTestOutcome TGCallsRowTestMissedByMeExcludesDeclinedAndOutgoing(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGCallsWasMissedByMe(@{@"missed" : @YES}),
			"a missed incoming call I did not decline was missed by me");
	TGTestExpectTrue(&outcome, !TGCallsWasMissedByMe(@{@"missed" : @YES, @"declined" : @YES}),
			"a call I declined is not one I missed, so it is not drawn in red");
	TGTestExpectTrue(&outcome, !TGCallsWasMissedByMe(@{@"missed" : @YES, @"outgoing" : @YES}),
			"a call the other side missed is not mine to have missed");
	TGTestExpectTrue(&outcome, !TGCallsWasMissedByMe(@{}), "a connected call was not missed");
	TGTestExpectTrue(&outcome, !TGCallsWasMissedByMe(nil), "a nil call must not crash the row");

	return outcome;
}

TGTestOutcome TGCallsRowTestDurationTextGrowsAnHourColumn(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGCallsDurationText(0) isEqualToString:@""],
			"a call of no length has no duration to print");
	TGTestExpectTrue(&outcome, [TGCallsDurationText(-5) isEqualToString:@""],
			"a negative duration is no duration");
	TGTestExpectTrue(&outcome, [TGCallsDurationText(9) isEqualToString:@"0:09"],
			"seconds are two digits behind a zero minute");
	TGTestExpectTrue(&outcome, [TGCallsDurationText(59) isEqualToString:@"0:59"],
			"the last second before a minute");
	TGTestExpectTrue(&outcome, [TGCallsDurationText(60) isEqualToString:@"1:00"],
			"a whole minute");
	TGTestExpectTrue(&outcome, [TGCallsDurationText(3599) isEqualToString:@"59:59"],
			"the last second before an hour still has no hour column");
	TGTestExpectTrue(&outcome, [TGCallsDurationText(3600) isEqualToString:@"1:00:00"],
			"an hour adds a column rather than counting to 60 minutes");
	TGTestExpectTrue(&outcome, [TGCallsDurationText(3661) isEqualToString:@"1:01:01"],
			"hours, minutes and seconds are each padded");

	return outcome;
}

TGTestOutcome TGCallsRowTestSubtitleAppendsADurationOnlyWhenThereIsOne(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGCallsSubtitleText(@{@"duration" : @95}) isEqualToString:@"Incoming Call (1:35)"],
			"a connected call shows its length in brackets after the kind");
	TGTestExpectTrue(&outcome,
			[TGCallsSubtitleText(@{@"missed" : @YES}) isEqualToString:@"Missed Call"],
			"a missed call has no length, so no empty brackets");
	TGTestExpectTrue(&outcome,
			[TGCallsSubtitleText(@{@"duration" : @0}) isEqualToString:@"Incoming Call"],
			"a zero duration is treated as absent");

	return outcome;
}

TGTestOutcome TGCallsRowTestInitialsTakeOneComposedCharacter(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGCallsInitials(@"ada") isEqualToString:@"A"],
			"an initial is upper case");
	TGTestExpectTrue(&outcome, [TGCallsInitials(@"  ada") isEqualToString:@"A"],
			"leading space is not an initial");
	TGTestExpectTrue(&outcome, [TGCallsInitials(@"") isEqualToString:@"?"],
			"a nameless caller gets a question mark, not an empty plate");
	TGTestExpectTrue(&outcome, [TGCallsInitials(@"   ") isEqualToString:@"?"],
			"a name of only spaces is no name");
	TGTestExpectTrue(&outcome, [TGCallsInitials(nil) isEqualToString:@"?"],
			"a nil name must not crash the avatar");
	TGTestExpectTrue(&outcome, [TGCallsInitials(@"\U0001F600ada") isEqualToString:@"\U0001F600"],
			"an emoji is one composed character, never half a surrogate pair");

	return outcome;
}

TGTestOutcome TGCallsRowTestDisplayNameFallsBackToUnknown(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGCallsDisplayName(@{@"name" : @"Ada"}) isEqualToString:@"Ada"],
			"a resolved name is shown");
	TGTestExpectTrue(&outcome, [TGCallsDisplayName(@{@"name" : @""}) isEqualToString:@"Unknown"],
			"an empty name is not a name");
	TGTestExpectTrue(&outcome, [TGCallsDisplayName(@{@"name" : @41}) isEqualToString:@"Unknown"],
			"a name of the wrong type off the wire must not reach the label");
	TGTestExpectTrue(&outcome, [TGCallsDisplayName(@{}) isEqualToString:@"Unknown"],
			"a caller with no name at all is unknown");

	return outcome;
}

TGTestOutcome TGCallsRowTestItemCarriesTheGroupsFields(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGCallsItem *item = [TGCallsItemBuilder itemFromGroup:@{
		@"name" : @"Ada",
		@"userId" : @77,
		@"date" : @1000000000,
		@"calls" : @[ @{@"duration" : @95} ]
	}];

	TGTestExpectTrue(&outcome, item.kind == TGCallsRowKindGroup, "a call group is the one row kind");
	TGTestExpectTrue(&outcome, [item.reuseIdentifier isEqualToString:@"TGCallsRow.Group"],
			"the row names the cell it is rendered by");
	TGTestExpectTrue(&outcome, item.cellClass == [TGCallListCell class],
			"and the class of that cell");
	TGTestExpectTrue(&outcome, [item.nameText isEqualToString:@"Ada"], "the caller's name is the title");
	TGTestExpectTrue(&outcome, [item.subtitleText isEqualToString:@"Incoming Call (1:35)"],
			"a single call reads as its kind and length");
	TGTestExpectTrue(&outcome, item.countText == nil,
			"one call carries no repeat count");
	TGTestExpectTrue(&outcome, item.dateText.length > 0, "every row is dated");
	TGTestExpectTrue(&outcome, [item.avatarKey isEqualToNumber:@77],
			"the avatar is keyed on the caller so the prefetcher can find it");
	TGTestExpectTrue(&outcome, item.avatarPlaceholder != nil,
			"there is always something to draw before the photo arrives");
	TGTestExpectTrue(&outcome, item.arrowImage != nil, "and an arrow for the direction");

	TGCallsItem *nameless = [TGCallsItemBuilder itemFromGroup:@{}];
	TGTestExpectTrue(&outcome, [nameless.nameText isEqualToString:@"Unknown"] &&
					nameless.avatarKey == nil,
			"a group with nothing in it still builds a row");

	return outcome;
}

TGTestOutcome TGCallsRowTestItemColoursOnlyACallMissedByMe(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGCallsItem *missed = [TGCallsItemBuilder itemFromGroup:@{@"name" : @"Ada", @"missed" : @YES}];
	TGTestExpectTrue(&outcome, missed.nameColour == TGCallsMissedColour(),
			"a call I missed is drawn in the missed colour");

	TGCallsItem *declined = [TGCallsItemBuilder
			itemFromGroup:@{@"name" : @"Ada", @"missed" : @YES, @"declined" : @YES}];
	TGTestExpectTrue(&outcome, declined.nameColour != TGCallsMissedColour(),
			"a call I declined is not red");

	TGCallsItem *outgoing = [TGCallsItemBuilder
			itemFromGroup:@{@"name" : @"Ada", @"missed" : @YES, @"outgoing" : @YES}];
	TGTestExpectTrue(&outcome, outgoing.nameColour != TGCallsMissedColour(),
			"a call the other side missed is not red on my side");

	return outcome;
}

TGTestOutcome TGCallsRowTestItemCountsRepeatedCallsAndDropsTheDuration(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGCallsItem *repeated = [TGCallsItemBuilder itemFromGroup:@{
		@"name" : @"Ada",
		@"calls" : @[ @{@"duration" : @95}, @{@"duration" : @10}, @{@"duration" : @3} ]
	}];
	TGTestExpectTrue(&outcome, [repeated.countText isEqualToString:@"(3)"],
			"three calls in a row are counted beside the name");
	TGTestExpectTrue(&outcome, [repeated.subtitleText isEqualToString:@"Incoming Call"],
			"a group of calls has no single length to show, so the subtitle is the kind alone");

	TGCallsItem *newest = [TGCallsItemBuilder itemFromGroup:@{
		@"name" : @"Ada",
		@"calls" : @[ @{@"missed" : @YES}, @{@"duration" : @95} ]
	}];
	TGTestExpectTrue(&outcome, [newest.subtitleText isEqualToString:@"Missed Call"],
			"the subtitle describes the newest call in the group, which is the first");

	return outcome;
}

TGTestOutcome TGCallsRowTestCellShowsTheItemAndPrefersALoadedAvatar(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGCallsItem *item = [TGCallsItemBuilder itemFromGroup:@{
		@"name" : @"Ada",
		@"userId" : @77,
		@"calls" : @[ @{@"duration" : @95}, @{@"duration" : @10} ]
	}];
	TGCallListCell *cell = [[TGCallListCell alloc] initWithStyle:UITableViewCellStyleDefault
												reuseIdentifier:item.reuseIdentifier];

	[cell applyItem:item avatar:nil];
	TGTestExpectTrue(&outcome, [cell.nameLabel.text isEqualToString:@"Ada"],
			"the cell shows the item's name");
	TGTestExpectTrue(&outcome, [cell.countLabel.text isEqualToString:@"(2)"],
			"and its repeat count");
	TGTestExpectTrue(&outcome, [cell.subtitleLabel.text isEqualToString:item.subtitleText],
			"and its subtitle");
	TGTestExpectTrue(&outcome, cell.nameLabel.textColor == item.nameColour &&
					cell.countLabel.textColor == item.nameColour,
			"the name and the count are coloured together, so a missed call reddens both");
	TGTestExpectTrue(&outcome, cell.avatarView.image == item.avatarPlaceholder,
			"with no photo loaded the placeholder is drawn");

	TGHostSetNamedImageSize(@"TGHostCallPhoto", CGSizeMake(kCallAvatarSide, kCallAvatarSide));
	UIImage *photo = [UIImage imageNamed:@"TGHostCallPhoto"];
	[cell applyItem:item avatar:photo];
	TGTestExpectTrue(&outcome, cell.avatarView.image == photo,
			"a loaded photo replaces the placeholder");

	TGCallsItem *plain = [TGCallsItemBuilder itemFromGroup:@{@"name" : @"Bob"}];
	[cell applyItem:plain avatar:nil];
	TGTestExpectTrue(&outcome, cell.countLabel.text == nil,
			"a reused cell must not keep the previous row's repeat count");

	return outcome;
}

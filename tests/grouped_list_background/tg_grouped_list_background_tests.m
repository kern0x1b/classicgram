#import "tg_grouped_list_background_tests.h"

#import "../../src/Theme/TGListBackground.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGGroupedListBackgroundTestWithoutTheTile(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	UIColor *background = TGGroupedListBackground();

	TGTestExpectTrue(&outcome, background != nil,
			"a grouped list has a background even where the tile is missing");
	TGTestExpectTrue(&outcome, background.patternImage == nil,
			"and it is the theme's own list colour, not a tile that is not there");

	return outcome;
}

TGTestOutcome TGGroupedListBackgroundTestTheTileIsTheBackground(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGHostSetNamedImageSize(@"SettingsBackground.png", CGSizeMake(320, 35));
	UIColor *background = TGGroupedListBackground();

	TGTestExpectTrue(&outcome, background.patternImage != nil,
			"every grouped list stands on the settings tile, where all but the settings "
			"root and the profile screens used to be plain white");

	return outcome;
}

TGTestOutcome TGGroupedListBackgroundTestTheTileIsBuiltOnce(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGHostSetNamedImageSize(@"SettingsBackground.png", CGSizeMake(320, 35));
	UIColor *first = TGGroupedListBackground();
	UIColor *second = TGGroupedListBackground();

	TGTestExpectTrue(&outcome, first == second,
			"the tiled colour is built once and handed to every screen that asks");

	return outcome;
}

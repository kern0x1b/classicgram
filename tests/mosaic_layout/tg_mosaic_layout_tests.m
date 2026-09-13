#import "tg_mosaic_layout_tests.h"
#import "../../src/Layout/TGMosaicLayout.h"

#include <stdio.h>

static void TGMosaicCheckInvariants(TGTestOutcome *outcome, const char *label,
		TGMosaicTile *tiles, NSUInteger laid, CGSize total) {
	for (NSUInteger i = 0; i < laid; i++) {
		char widthDesc[192];
		snprintf(widthDesc, sizeof(widthDesc),
				"%s tile %lu must not have a non-positive width", label, (unsigned long)i);
		TGTestExpectTrue(outcome, tiles[i].frame.size.width >= 1.0, widthDesc);

		char heightDesc[192];
		snprintf(heightDesc, sizeof(heightDesc),
				"%s tile %lu must not have a non-positive height", label, (unsigned long)i);
		TGTestExpectTrue(outcome, tiles[i].frame.size.height >= 1.0, heightDesc);

		char originDesc[192];
		snprintf(originDesc, sizeof(originDesc),
				"%s tile %lu must not start above or left of the mosaic origin", label, (unsigned long)i);
		TGTestExpectTrue(outcome,
				tiles[i].frame.origin.x >= -0.01 && tiles[i].frame.origin.y >= -0.01,
				originDesc);

		char fitDesc[192];
		snprintf(fitDesc, sizeof(fitDesc),
				"%s tile %lu must fit inside the mosaic's own reported total size", label, (unsigned long)i);
		TGTestExpectTrue(outcome,
				CGRectGetMaxX(tiles[i].frame) <= total.width + 1.0 &&
				CGRectGetMaxY(tiles[i].frame) <= total.height + 1.0,
				fitDesc);
	}
}

TGTestOutcome TGMosaicLayoutTestCountTwoLandscapePairStacksTopAndBottom(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGSize sizes[2] = {{1200, 675}, {1600, 900}};
	TGMosaicTile tiles[kMosaicMaxItems];
	CGSize total = CGSizeZero;
	NSUInteger laid = TGMosaicLayoutTiles(sizes, 2, CGSizeMake(300, 380), 2.0f,
			NO, tiles, kMosaicMaxItems, &total);

	TGTestExpectEqualLongLong(&outcome, laid, 2,
			"a two-photo album must always lay out exactly two tiles");
	TGTestExpectEqualDouble(&outcome, total.width, 300, 0.01,
			"two similarly-wide landscape photos must fill the full mosaic width");
	TGTestExpectEqualDouble(&outcome, total.height, 338, 0.01,
			"two stacked landscape rows plus the spacing between them set the mosaic height");
	TGTestExpectEqualDouble(&outcome, tiles[0].frame.size.width, 300, 0.01,
			"the top landscape tile must span the full mosaic width when photos stack");
	TGTestExpectEqualDouble(&outcome, tiles[0].frame.size.height, 168, 0.01,
			"the top landscape tile's height must match the bottom tile's height");
	TGTestExpectEqualDouble(&outcome, tiles[1].frame.origin.y, 170, 0.01,
			"the bottom tile must begin exactly one row height plus spacing below the top tile");
	TGTestExpectEqualLongLong(&outcome, tiles[0].position,
			TGMosaicPositionTop | TGMosaicPositionLeft | TGMosaicPositionRight,
			"the top tile of a stacked landscape pair touches the top, left and right mosaic edges");
	TGTestExpectEqualLongLong(&outcome, tiles[1].position,
			TGMosaicPositionBottom | TGMosaicPositionLeft | TGMosaicPositionRight,
			"the bottom tile of a stacked landscape pair touches the bottom, left and right mosaic edges");

	return outcome;
}

TGTestOutcome TGMosaicLayoutTestCountTwoSideBySideForWwAndQqProportions(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGSize wideSizes[2] = {{1300, 1000}, {1900, 1000}};
	TGMosaicTile wideTiles[kMosaicMaxItems];
	CGSize wideTotal = CGSizeZero;
	NSUInteger wideLaid = TGMosaicLayoutTiles(wideSizes, 2, CGSizeMake(300, 380), 2.0f,
			NO, wideTiles, kMosaicMaxItems, &wideTotal);

	TGTestExpectEqualLongLong(&outcome, wideLaid, 2,
			"a two-photo album must always lay out exactly two tiles");
	TGTestExpectEqualDouble(&outcome, wideTiles[0].frame.size.width, 149, 0.01,
			"two landscape photos that are not near-identical in ratio split the width evenly, minus spacing");
	TGTestExpectEqualDouble(&outcome, wideTiles[1].frame.size.width, 149, 0.01,
			"both side-by-side tiles must claim the same share of the mosaic width");
	TGTestExpectEqualDouble(&outcome, wideTiles[1].frame.origin.x, 151, 0.01,
			"the right tile must start exactly spacing pixels after the left tile ends");
	TGTestExpectEqualLongLong(&outcome, wideTiles[0].position,
			TGMosaicPositionTop | TGMosaicPositionLeft | TGMosaicPositionBottom,
			"a side-by-side left tile touches the top, left and bottom mosaic edges");

	CGSize squareSizes[2] = {{1000, 1000}, {1050, 1000}};
	TGMosaicTile squareTiles[kMosaicMaxItems];
	CGSize squareTotal = CGSizeZero;
	NSUInteger squareLaid = TGMosaicLayoutTiles(squareSizes, 2, CGSizeMake(300, 380), 2.0f,
			NO, squareTiles, kMosaicMaxItems, &squareTotal);

	TGTestExpectEqualLongLong(&outcome, squareLaid, 2,
			"a two near-square photo album must also lay out exactly two tiles");
	TGTestExpectEqualDouble(&outcome, squareTiles[0].frame.size.width, 149, 0.01,
			"two near-square photos also split the width evenly, minus spacing");
	TGTestExpectEqualDouble(&outcome, squareTiles[0].frame.size.height, 141, 0.01,
			"both near-square tiles must share the same height");
	TGTestExpectEqualDouble(&outcome, squareTiles[0].frame.size.height,
			squareTiles[1].frame.size.height, 0.01,
			"a side-by-side pair must never end up with two different tile heights");

	return outcome;
}

TGTestOutcome TGMosaicLayoutTestCountTwoPortraitPairSplitsEvenly(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGSize sizes[2] = {{675, 1200}, {900, 1600}};
	TGMosaicTile tiles[kMosaicMaxItems];
	CGSize total = CGSizeZero;
	NSUInteger laid = TGMosaicLayoutTiles(sizes, 2, CGSizeMake(300, 380), 2.0f,
			NO, tiles, kMosaicMaxItems, &total);

	TGTestExpectEqualLongLong(&outcome, laid, 2,
			"a two-photo album must always lay out exactly two tiles");
	TGTestExpectEqualDouble(&outcome, total.width, 300, 0.01,
			"a portrait pair must still fill the full mosaic width");
	TGTestExpectEqualDouble(&outcome, tiles[0].frame.size.width, 149, 0.01,
			"two equally-narrow portrait photos split the width evenly, minus spacing");
	TGTestExpectEqualDouble(&outcome, tiles[1].frame.size.width, 149, 0.01,
			"the second portrait tile must claim the same width share as the first");
	TGTestExpectEqualDouble(&outcome, tiles[0].frame.size.height, tiles[1].frame.size.height, 0.01,
			"a side-by-side portrait pair must share a single row height");
	TGTestExpectEqualDouble(&outcome, tiles[1].frame.origin.x, 151, 0.01,
			"the right portrait tile must start exactly spacing pixels after the left tile ends");

	return outcome;
}

TGTestOutcome TGMosaicLayoutTestCountTwoMixedRatioPairWeightsWidthByAspect(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGSize sizes[2] = {{1600, 900}, {900, 1600}};
	TGMosaicTile tiles[kMosaicMaxItems];
	CGSize total = CGSizeZero;
	NSUInteger laid = TGMosaicLayoutTiles(sizes, 2, CGSizeMake(300, 380), 2.0f,
			NO, tiles, kMosaicMaxItems, &total);

	TGTestExpectEqualLongLong(&outcome, laid, 2,
			"a two-photo album must always lay out exactly two tiles");
	TGTestExpectEqualDouble(&outcome, tiles[0].frame.size.width, 226, 0.01,
			"a wide first photo paired with a narrow second photo must claim most of the width");
	TGTestExpectEqualDouble(&outcome, tiles[1].frame.size.width, 72, 0.01,
			"the narrow second photo must be squeezed into the remaining width, not split evenly");
	TGTestExpectTrue(&outcome, tiles[0].frame.size.width > tiles[1].frame.size.width,
			"a mismatched aspect-ratio pair must not fall back to an even width split");
	TGTestExpectEqualDouble(&outcome, tiles[0].frame.size.height, tiles[1].frame.size.height, 0.01,
			"both tiles of a mixed-ratio pair still share exactly one row height");

	return outcome;
}

TGTestOutcome TGMosaicLayoutTestCountThreeNarrowFirstImageMakesTallLeftColumn(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGSize sizes[3] = {{675, 1200}, {1200, 675}, {1200, 675}};
	TGMosaicTile tiles[kMosaicMaxItems];
	CGSize total = CGSizeZero;
	NSUInteger laid = TGMosaicLayoutTiles(sizes, 3, CGSizeMake(300, 380), 2.0f,
			NO, tiles, kMosaicMaxItems, &total);

	TGTestExpectEqualLongLong(&outcome, laid, 3,
			"a three-photo album must always lay out exactly three tiles");
	TGTestExpectEqualDouble(&outcome, tiles[0].frame.size.width, 149, 0.01,
			"a narrow first photo becomes a single tall column on the left");
	TGTestExpectEqualDouble(&outcome, tiles[0].frame.size.height, 380, 0.01,
			"the tall left column must span the full mosaic height");
	TGTestExpectEqualDouble(&outcome, tiles[1].frame.origin.y, 0, 0.01,
			"the top-right tile of the narrow-first layout must sit flush with the mosaic top");
	TGTestExpectEqualDouble(&outcome, tiles[2].frame.origin.y, 231, 0.01,
			"the bottom-right tile must start right below the top-right tile plus spacing");
	TGTestExpectEqualLongLong(&outcome, tiles[1].position,
			TGMosaicPositionTop | TGMosaicPositionRight,
			"the top-right tile of a narrow-first triple only touches the top and right edges");
	TGTestExpectEqualLongLong(&outcome, tiles[2].position,
			TGMosaicPositionBottom | TGMosaicPositionRight,
			"the bottom-right tile of a narrow-first triple only touches the bottom and right edges");

	return outcome;
}

TGTestOutcome TGMosaicLayoutTestCountThreeFillWidthForcesExactHalfRightColumn(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGSize sizes[3] = {{675, 1200}, {1200, 675}, {1200, 675}};
	TGMosaicTile fitTiles[kMosaicMaxItems];
	CGSize fitTotal = CGSizeZero;
	TGMosaicLayoutTiles(sizes, 3, CGSizeMake(300, 380), 2.0f,
			NO, fitTiles, kMosaicMaxItems, &fitTotal);

	TGMosaicTile fillTiles[kMosaicMaxItems];
	CGSize fillTotal = CGSizeZero;
	NSUInteger fillLaid = TGMosaicLayoutTiles(sizes, 3, CGSizeMake(300, 380), 2.0f,
			YES, fillTiles, kMosaicMaxItems, &fillTotal);

	TGTestExpectEqualLongLong(&outcome, fillLaid, 3,
			"fillWidth must not change how many tiles are laid out");
	TGTestExpectEqualDouble(&outcome, fillTiles[1].frame.size.width, 150, 0.01,
			"fillWidth on a narrow-first triple must stretch the right column to exactly half the mosaic width");
	TGTestExpectEqualDouble(&outcome, fillTiles[2].frame.size.width, 150, 0.01,
			"fillWidth must give both right-column tiles the same stretched width");
	TGTestExpectEqualDouble(&outcome, fillTiles[0].frame.size.width, 148, 0.01,
			"the left column must shrink to absorb exactly what the right column gained from fillWidth");
	TGTestExpectTrue(&outcome,
			fillTiles[1].frame.size.width != fitTiles[1].frame.size.width,
			"fillWidth must actually change the right column's width compared to the unstretched layout");
	TGTestExpectEqualDouble(&outcome,
			fillTiles[0].frame.size.width + 2.0f + fillTiles[1].frame.size.width, 300, 0.01,
			"fillWidth's two columns plus the spacing between them must still add up to the mosaic width");

	return outcome;
}

TGTestOutcome TGMosaicLayoutTestCountThreeGeneralLayoutStacksTwoUnderOne(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGSize sizes[3] = {{1200, 900}, {900, 1200}, {900, 1200}};
	TGMosaicTile tiles[kMosaicMaxItems];
	CGSize total = CGSizeZero;
	NSUInteger laid = TGMosaicLayoutTiles(sizes, 3, CGSizeMake(300, 380), 2.0f,
			NO, tiles, kMosaicMaxItems, &total);

	TGTestExpectEqualLongLong(&outcome, laid, 3,
			"a three-photo album must always lay out exactly three tiles");
	TGTestExpectEqualDouble(&outcome, tiles[0].frame.size.width, 300, 0.01,
			"a landscape first photo becomes a full-width header row");
	TGTestExpectEqualDouble(&outcome, tiles[0].frame.size.height, 225, 0.01,
			"the header row's height is driven by the first photo's own aspect ratio");
	TGTestExpectEqualDouble(&outcome, tiles[1].frame.origin.y, 227, 0.01,
			"the bottom row must start right below the header plus spacing");
	TGTestExpectEqualDouble(&outcome, tiles[1].frame.size.width, tiles[2].frame.size.width, 0.01,
			"the two bottom-row tiles must split the width evenly");
	TGTestExpectEqualLongLong(&outcome, tiles[1].position,
			TGMosaicPositionBottom | TGMosaicPositionLeft,
			"the bottom-left tile of this layout only touches the bottom and left edges");
	TGTestExpectEqualLongLong(&outcome, tiles[2].position,
			TGMosaicPositionBottom | TGMosaicPositionRight,
			"the bottom-right tile of this layout only touches the bottom and right edges");

	return outcome;
}

TGTestOutcome TGMosaicLayoutTestCountFourWideFirstImageMakesFullWidthHeader(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGSize sizes[4] = {{1600, 900}, {900, 1200}, {1200, 900}, {900, 1200}};
	TGMosaicTile tiles[kMosaicMaxItems];
	CGSize total = CGSizeZero;
	NSUInteger laid = TGMosaicLayoutTiles(sizes, 4, CGSizeMake(300, 380), 2.0f,
			NO, tiles, kMosaicMaxItems, &total);

	TGTestExpectEqualLongLong(&outcome, laid, 4,
			"a four-photo album must always lay out exactly four tiles");
	TGTestExpectEqualDouble(&outcome, tiles[0].frame.size.width, 300, 0.01,
			"a wide first photo in a four-up album becomes a full-width header row");
	TGTestExpectEqualLongLong(&outcome, tiles[0].position,
			TGMosaicPositionTop | TGMosaicPositionLeft | TGMosaicPositionRight,
			"the header row touches the top, left and right edges");
	TGTestExpectEqualLongLong(&outcome, tiles[2].position, TGMosaicPositionBottom,
			"the middle tile of the bottom row only touches the bottom edge, never left or right");
	TGTestExpectEqualDouble(&outcome,
			tiles[1].frame.size.width + tiles[2].frame.size.width + tiles[3].frame.size.width + 2 * 2.0f,
			300, 0.01,
			"the three bottom-row tiles plus their spacing must add up to the mosaic width");
	TGTestExpectEqualDouble(&outcome, tiles[1].frame.size.height, tiles[3].frame.size.height, 0.01,
			"all three bottom-row tiles must share one row height");

	return outcome;
}

TGTestOutcome TGMosaicLayoutTestCountFourNarrowFirstImageMakesTallLeftColumn(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGSize sizes[4] = {{900, 1600}, {1200, 900}, {900, 1200}, {1200, 900}};
	TGMosaicTile tiles[kMosaicMaxItems];
	CGSize total = CGSizeZero;
	NSUInteger laid = TGMosaicLayoutTiles(sizes, 4, CGSizeMake(300, 380), 2.0f,
			NO, tiles, kMosaicMaxItems, &total);

	TGTestExpectEqualLongLong(&outcome, laid, 4,
			"a four-photo album must always lay out exactly four tiles");
	TGTestExpectEqualDouble(&outcome, tiles[0].frame.size.height, 380, 0.01,
			"a narrow first photo in a four-up album becomes a full-height left column");
	TGTestExpectEqualLongLong(&outcome, tiles[0].position,
			TGMosaicPositionTop | TGMosaicPositionLeft | TGMosaicPositionBottom,
			"the tall left column touches the top, left and bottom edges");
	TGTestExpectEqualLongLong(&outcome, tiles[2].position, TGMosaicPositionRight,
			"the middle tile of the right column only touches the right edge, never top or bottom");
	TGTestExpectEqualDouble(&outcome,
			tiles[1].frame.size.height + tiles[2].frame.size.height + tiles[3].frame.size.height + 2 * 2.0f,
			380, 0.01,
			"the three right-column tiles plus their spacing must add up to the mosaic height");
	TGTestExpectEqualDouble(&outcome, tiles[1].frame.size.width, tiles[3].frame.size.width, 0.01,
			"all three right-column tiles must share one column width");

	return outcome;
}

TGTestOutcome TGMosaicLayoutTestCountFiveUsesGeneralSolver(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGSize sizes[5];
	for (NSUInteger i = 0; i < 5; i++)
		sizes[i] = CGSizeMake(1200, 900);
	TGMosaicTile tiles[kMosaicMaxItems];
	CGSize total = CGSizeZero;
	NSUInteger laid = TGMosaicLayoutTiles(sizes, 5, CGSizeMake(300, 380), 2.0f,
			NO, tiles, kMosaicMaxItems, &total);

	TGTestExpectEqualLongLong(&outcome, laid, 5,
			"a five-photo album must fall through to the general row solver and lay out five tiles");
	TGTestExpectEqualDouble(&outcome, tiles[0].frame.size.width, 302, 0.01,
			"the general solver's header row for five equal-ratio photos spans the mosaic width");
	TGTestExpectEqualLongLong(&outcome, tiles[1].position, TGMosaicPositionInside,
			"a middle-row tile that touches neither an outer edge nor the last row is flagged Inside");
	TGTestExpectEqualDouble(&outcome, tiles[3].frame.size.width, tiles[4].frame.size.width, 0.01,
			"the two tiles of the general solver's final row must split its width evenly");
	TGTestExpectEqualLongLong(&outcome, tiles[3].position,
			TGMosaicPositionBottom | TGMosaicPositionLeft,
			"the bottom-left tile of the final row only touches the bottom and left edges");
	TGTestExpectEqualLongLong(&outcome, tiles[4].position,
			TGMosaicPositionBottom | TGMosaicPositionRight,
			"the bottom-right tile of the final row only touches the bottom and right edges");

	return outcome;
}

TGTestOutcome TGMosaicLayoutTestCountSixUsesGeneralSolver(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGSize sizes[6];
	for (NSUInteger i = 0; i < 6; i++)
		sizes[i] = CGSizeMake(1200, 900);
	TGMosaicTile tiles[kMosaicMaxItems];
	CGSize total = CGSizeZero;
	NSUInteger laid = TGMosaicLayoutTiles(sizes, 6, CGSizeMake(300, 380), 2.0f,
			NO, tiles, kMosaicMaxItems, &total);

	TGTestExpectEqualLongLong(&outcome, laid, 6,
			"a six-photo album must fall through to the general row solver and lay out six tiles");
	TGTestExpectEqualDouble(&outcome, total.height, 415, 0.01,
			"six equal-ratio photos must produce a taller mosaic than the five-photo case");
	TGTestExpectEqualDouble(&outcome, tiles[3].frame.size.width, tiles[4].frame.size.width, 0.01,
			"the three tiles of a six-photo final row must claim equal width shares");
	TGTestExpectEqualDouble(&outcome, tiles[4].frame.size.width, tiles[5].frame.size.width, 1.01,
			"the third tile of the final row must be within a pixel of the other two, after integer rounding");
	TGTestExpectEqualLongLong(&outcome, tiles[5].position,
			TGMosaicPositionBottom | TGMosaicPositionRight,
			"the last tile of the last row must touch both the bottom and the right edges");

	return outcome;
}

TGTestOutcome TGMosaicLayoutTestCountTenAtMosaicMaxItemsBoundary(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGSize sizes[kMosaicMaxItems];
	for (NSUInteger i = 0; i < kMosaicMaxItems; i++)
		sizes[i] = CGSizeMake(1200, 900);
	TGMosaicTile tiles[kMosaicMaxItems];
	CGSize total = CGSizeZero;
	NSUInteger laid = TGMosaicLayoutTiles(sizes, kMosaicMaxItems, CGSizeMake(300, 380), 2.0f,
			NO, tiles, kMosaicMaxItems, &total);

	TGTestExpectEqualLongLong(&outcome, laid, kMosaicMaxItems,
			"a ten-photo album, exactly at kMosaicMaxItems, must still lay out every tile");
	TGTestExpectEqualLongLong(&outcome, laid, 10,
			"kMosaicMaxItems must still be 10, matching the header's declared capacity");
	TGTestExpectEqualDouble(&outcome, tiles[9].frame.size.width, tiles[8].frame.size.width, 1.01,
			"the last tile of a ten-photo mosaic must be within a pixel of its row neighbour");
	TGTestExpectEqualLongLong(&outcome, tiles[9].position,
			TGMosaicPositionBottom | TGMosaicPositionRight,
			"the very last tile of a full ten-photo mosaic must sit in the bottom-right corner");
	TGTestExpectEqualLongLong(&outcome, tiles[0].position,
			TGMosaicPositionTop | TGMosaicPositionLeft,
			"the very first tile of a full ten-photo mosaic must sit in the top-left corner");

	return outcome;
}

TGTestOutcome TGMosaicLayoutTestForceCalcTriggeredByExtremeWideRatioAtCountThree(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGSize sizes[3] = {{3000, 600}, {900, 1200}, {900, 1200}};
	TGMosaicTile tiles[kMosaicMaxItems];
	CGSize total = CGSizeZero;
	NSUInteger laid = TGMosaicLayoutTiles(sizes, 3, CGSizeMake(300, 380), 2.0f,
			NO, tiles, kMosaicMaxItems, &total);

	TGTestExpectEqualLongLong(&outcome, laid, 3,
			"an extreme aspect ratio must still lay out every photo, just via a different code path");
	TGTestExpectEqualLongLong(&outcome, tiles[2].position,
			TGMosaicPositionBottom | TGMosaicPositionLeft | TGMosaicPositionRight,
			"forceCalc's general solver puts the lone extreme-ratio photo alone in its own full-width row");
	TGTestExpectEqualDouble(&outcome, tiles[2].frame.size.width, 302, 0.01,
			"the forceCalc row holding the 5:1 photo must still span the mosaic width");
	TGTestExpectTrue(&outcome, total.height > 380,
			"an extreme single aspect ratio can push the mosaic taller than the requested bounding box");
	TGTestExpectTrue(&outcome, tiles[0].frame.size.width < tiles[2].frame.size.width,
			"the two upper photos must be narrower than the lone extreme-ratio photo's full-width row");

	return outcome;
}

TGTestOutcome TGMosaicLayoutTestForceCalcTriggeredForCountTwo(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGSize sizes[2] = {{3000, 600}, {900, 1200}};
	TGMosaicTile tiles[kMosaicMaxItems];
	CGSize total = CGSizeZero;
	NSUInteger laid = TGMosaicLayoutTiles(sizes, 2, CGSizeMake(300, 380), 2.0f,
			NO, tiles, kMosaicMaxItems, &total);

	TGTestExpectEqualLongLong(&outcome, laid, 2,
			"forceCalc must still lay out both photos even for the normally special-cased count of two");
	TGTestExpectTrue(&outcome, total.height > 380,
			"forceCalc for an extreme two-photo pair can also push the mosaic past the requested height");
	TGTestExpectTrue(&outcome, tiles[1].frame.size.height > tiles[0].frame.size.height,
			"the near-square second photo must end up taller than the extremely wide first photo's row");
	TGTestExpectEqualLongLong(&outcome, tiles[0].position,
			TGMosaicPositionTop | TGMosaicPositionLeft | TGMosaicPositionRight,
			"forceCalc's row layout for two photos still marks the first row as touching top, left and right");

	return outcome;
}

TGTestOutcome TGMosaicLayoutTestDegenerateCountOutsideValidRangeReturnsZero(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGSize sizes[kMosaicMaxItems + 1];
	for (NSUInteger i = 0; i < kMosaicMaxItems + 1; i++)
		sizes[i] = CGSizeMake(1200, 900);
	TGMosaicTile tiles[kMosaicMaxItems];

	CGSize totalZero = CGSizeMake(-1, -1);
	NSUInteger laidZero = TGMosaicLayoutTiles(sizes, 0, CGSizeMake(300, 380), 2.0f,
			NO, tiles, kMosaicMaxItems, &totalZero);
	TGTestExpectEqualLongLong(&outcome, laidZero, 0,
			"an album with zero photos must lay out zero tiles rather than reading past the array");
	TGTestExpectEqualDouble(&outcome, totalZero.width, 0, 0.01,
			"outTotal must be reset to zero even when the call is rejected outright");

	CGSize totalOne = CGSizeMake(-1, -1);
	NSUInteger laidOne = TGMosaicLayoutTiles(sizes, 1, CGSizeMake(300, 380), 2.0f,
			NO, tiles, kMosaicMaxItems, &totalOne);
	TGTestExpectEqualLongLong(&outcome, laidOne, 0,
			"a single photo is never a mosaic and must lay out zero tiles");

	CGSize totalEleven = CGSizeMake(-1, -1);
	NSUInteger laidEleven = TGMosaicLayoutTiles(sizes, kMosaicMaxItems + 1, CGSizeMake(300, 380), 2.0f,
			NO, tiles, kMosaicMaxItems, &totalEleven);
	TGTestExpectEqualLongLong(&outcome, laidEleven, 0,
			"an album with more photos than kMosaicMaxItems must be rejected, not truncated silently");

	CGSize totalOverCapacity = CGSizeMake(-1, -1);
	NSUInteger laidOverCapacity = TGMosaicLayoutTiles(sizes, 5, CGSizeMake(300, 380), 2.0f,
			NO, tiles, 3, &totalOverCapacity);
	TGTestExpectEqualLongLong(&outcome, laidOverCapacity, 0,
			"a count larger than the caller's own outTiles capacity must be rejected to avoid overflowing it");

	CGSize totalAtCapacity = CGSizeZero;
	NSUInteger laidAtCapacity = TGMosaicLayoutTiles(sizes, 3, CGSizeMake(300, 380), 2.0f,
			NO, tiles, 3, &totalAtCapacity);
	TGTestExpectEqualLongLong(&outcome, laidAtCapacity, 3,
			"a count exactly equal to the caller's capacity must still be accepted");

	return outcome;
}

TGTestOutcome TGMosaicLayoutTestDegenerateMaxSizeBelowOnePointReturnsZero(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGSize sizes[2] = {{1200, 675}, {1600, 900}};
	TGMosaicTile tiles[kMosaicMaxItems];

	CGSize totalNoWidth = CGSizeMake(-1, -1);
	NSUInteger laidNoWidth = TGMosaicLayoutTiles(sizes, 2, CGSizeMake(0, 380), 2.0f,
			NO, tiles, kMosaicMaxItems, &totalNoWidth);
	TGTestExpectEqualLongLong(&outcome, laidNoWidth, 0,
			"a bounding box with no width has nowhere to place a single pixel of any tile");
	TGTestExpectEqualDouble(&outcome, totalNoWidth.width, 0, 0.01,
			"outTotal must be reset to zero when the width guard rejects the call");

	CGSize totalNoHeight = CGSizeMake(-1, -1);
	NSUInteger laidNoHeight = TGMosaicLayoutTiles(sizes, 2, CGSizeMake(300, 0), 2.0f,
			NO, tiles, kMosaicMaxItems, &totalNoHeight);
	TGTestExpectEqualLongLong(&outcome, laidNoHeight, 0,
			"a bounding box with no height has nowhere to place a single pixel of any tile");

	CGSize totalNegativeHeight = CGSizeMake(-1, -1);
	NSUInteger laidNegativeHeight = TGMosaicLayoutTiles(sizes, 2, CGSizeMake(300, -50), 2.0f,
			NO, tiles, kMosaicMaxItems, &totalNegativeHeight);
	TGTestExpectEqualLongLong(&outcome, laidNegativeHeight, 0,
			"a negative height must be rejected exactly like a zero height, not treated as a magnitude");

	return outcome;
}

TGTestOutcome TGMosaicLayoutTestMinTileSizeClampAppliesInThreeAndFourUpBranches(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGSize threeSizes[3] = {{600, 3000}, {180, 900}, {180, 900}};
	TGMosaicTile threeTiles[kMosaicMaxItems];
	CGSize threeTotal = CGSizeZero;
	NSUInteger threeLaid = TGMosaicLayoutTiles(threeSizes, 3, CGSizeMake(300, 380), 2.0f,
			NO, threeTiles, kMosaicMaxItems, &threeTotal);

	TGTestExpectEqualLongLong(&outcome, threeLaid, 3,
			"an extremely narrow narrow-first triple must still lay out three tiles");
	TGTestExpectEqualDouble(&outcome, threeTiles[1].frame.size.width, 68, 0.01,
			"the right column of a narrow-first triple must never shrink below the 68pt minimum tile width");
	TGTestExpectEqualDouble(&outcome, threeTiles[2].frame.size.width, 68, 0.01,
			"both right-column tiles of a narrow-first triple share the same clamped minimum width");
	TGTestExpectTrue(&outcome, threeTotal.width < 300,
			"clamping the right column to the minimum width leaves the mosaic narrower than the bounding box");

	CGSize fourSizes[4] = {{600, 3000}, {180, 900}, {1200, 900}, {180, 900}};
	TGMosaicTile fourTiles[kMosaicMaxItems];
	CGSize fourTotal = CGSizeZero;
	NSUInteger fourLaid = TGMosaicLayoutTiles(fourSizes, 4, CGSizeMake(300, 380), 2.0f,
			NO, fourTiles, kMosaicMaxItems, &fourTotal);

	TGTestExpectEqualLongLong(&outcome, fourLaid, 4,
			"an extremely narrow narrow-first quad must still lay out four tiles");
	TGTestExpectEqualDouble(&outcome, fourTiles[1].frame.size.width, 68, 0.01,
			"the right column of a narrow-first quad must never shrink below the 68pt minimum tile width");
	TGTestExpectEqualDouble(&outcome, fourTiles[2].frame.size.width, 68, 0.01,
			"every tile in the clamped right column shares the same minimum width");
	TGTestExpectEqualDouble(&outcome, fourTiles[3].frame.size.width, 68, 0.01,
			"the last tile of the clamped right column is clamped exactly like the others");

	return outcome;
}

TGTestOutcome TGMosaicLayoutTestInvariantNoNegativeSizesAndTilesFitWithinReturnedTotal(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGSize landscapePair[2] = {{1200, 675}, {1600, 900}};
	TGMosaicTile landscapeTiles[kMosaicMaxItems];
	CGSize landscapeTotal = CGSizeZero;
	NSUInteger landscapeLaid = TGMosaicLayoutTiles(landscapePair, 2, CGSizeMake(300, 380), 2.0f,
			NO, landscapeTiles, kMosaicMaxItems, &landscapeTotal);
	TGMosaicCheckInvariants(&outcome, "count2-landscape", landscapeTiles, landscapeLaid, landscapeTotal);

	CGSize generalTriple[3] = {{1200, 900}, {900, 1200}, {900, 1200}};
	TGMosaicTile tripleTiles[kMosaicMaxItems];
	CGSize tripleTotal = CGSizeZero;
	NSUInteger tripleLaid = TGMosaicLayoutTiles(generalTriple, 3, CGSizeMake(300, 380), 2.0f,
			NO, tripleTiles, kMosaicMaxItems, &tripleTotal);
	TGMosaicCheckInvariants(&outcome, "count3-general", tripleTiles, tripleLaid, tripleTotal);

	CGSize wideFirstQuad[4] = {{1600, 900}, {900, 1200}, {1200, 900}, {900, 1200}};
	TGMosaicTile quadTiles[kMosaicMaxItems];
	CGSize quadTotal = CGSizeZero;
	NSUInteger quadLaid = TGMosaicLayoutTiles(wideFirstQuad, 4, CGSizeMake(300, 380), 2.0f,
			NO, quadTiles, kMosaicMaxItems, &quadTotal);
	TGMosaicCheckInvariants(&outcome, "count4-wide-first", quadTiles, quadLaid, quadTotal);

	CGSize fiveEqual[5];
	for (NSUInteger i = 0; i < 5; i++)
		fiveEqual[i] = CGSizeMake(1200, 900);
	TGMosaicTile fiveTiles[kMosaicMaxItems];
	CGSize fiveTotal = CGSizeZero;
	NSUInteger fiveLaid = TGMosaicLayoutTiles(fiveEqual, 5, CGSizeMake(300, 380), 2.0f,
			NO, fiveTiles, kMosaicMaxItems, &fiveTotal);
	TGMosaicCheckInvariants(&outcome, "count5-general", fiveTiles, fiveLaid, fiveTotal);

	CGSize tenEqual[kMosaicMaxItems];
	for (NSUInteger i = 0; i < kMosaicMaxItems; i++)
		tenEqual[i] = CGSizeMake(1200, 900);
	TGMosaicTile tenTiles[kMosaicMaxItems];
	CGSize tenTotal = CGSizeZero;
	NSUInteger tenLaid = TGMosaicLayoutTiles(tenEqual, kMosaicMaxItems, CGSizeMake(300, 380), 2.0f,
			NO, tenTiles, kMosaicMaxItems, &tenTotal);
	TGMosaicCheckInvariants(&outcome, "count10-general", tenTiles, tenLaid, tenTotal);

	CGSize forceCalcTriple[3] = {{3000, 600}, {900, 1200}, {900, 1200}};
	TGMosaicTile forceCalcTiles[kMosaicMaxItems];
	CGSize forceCalcTotal = CGSizeZero;
	NSUInteger forceCalcLaid = TGMosaicLayoutTiles(forceCalcTriple, 3, CGSizeMake(300, 380), 2.0f,
			NO, forceCalcTiles, kMosaicMaxItems, &forceCalcTotal);
	TGMosaicCheckInvariants(&outcome, "forceCalc-triple", forceCalcTiles, forceCalcLaid, forceCalcTotal);

	CGSize minClampTriple[3] = {{600, 3000}, {180, 900}, {180, 900}};
	TGMosaicTile minClampTiles[kMosaicMaxItems];
	CGSize minClampTotal = CGSizeZero;
	NSUInteger minClampLaid = TGMosaicLayoutTiles(minClampTriple, 3, CGSizeMake(300, 380), 2.0f,
			NO, minClampTiles, kMosaicMaxItems, &minClampTotal);
	TGMosaicCheckInvariants(&outcome, "min-clamp-triple", minClampTiles, minClampLaid, minClampTotal);

	return outcome;
}

#import "tg_pure_helpers_tests.h"
#import "../../src/Screens/Media/TGPlayerClock.h"
#import "../../src/Screens/Chat/TGLiveLocationFix.h"
#import "../../src/Screens/Chat/TGDiceEmoji.h"
#import "../../src/Theme/TGThemeGeometry.h"
#import "../../src/Screens/Settings/TGWebBrowserExceptionURL.h"

TGTestOutcome TGPlayerClockTestFormatsMinutesAndPadsSeconds(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPlayerClock(0, NO) isEqualToString:@"0:00"],
			"a track at its start reads 0:00, not 0:0");
	TGTestExpectTrue(&outcome, [TGPlayerClock(9, NO) isEqualToString:@"0:09"],
			"seconds below ten must be zero-padded");
	TGTestExpectTrue(&outcome, [TGPlayerClock(65, NO) isEqualToString:@"1:05"],
			"a minute and five seconds reads 1:05");
	TGTestExpectTrue(&outcome, [TGPlayerClock(3599, NO) isEqualToString:@"59:59"],
			"just under an hour stays in minutes:seconds, the way the player's labels are sized for");
	TGTestExpectTrue(&outcome, [TGPlayerClock(3600, NO) isEqualToString:@"1:00:00"],
			"an hour rolls into a third field, the way Telegram's own stringForDuration does; "
			"the player's clock labels are 70 points wide and hold it");

	return outcome;
}

TGTestOutcome TGPlayerClockTestRoundsToTheNearestSecond(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPlayerClock(1.4, NO) isEqualToString:@"0:01"],
			"a position just past a second must not round up early");
	TGTestExpectTrue(&outcome, [TGPlayerClock(1.5, NO) isEqualToString:@"0:02"],
			"a half second rounds up, so the label never sits a whole second behind the audio");
	TGTestExpectTrue(&outcome, [TGPlayerClock(59.6, NO) isEqualToString:@"1:00"],
			"rounding up across the minute boundary must carry into the minutes field");

	return outcome;
}

TGTestOutcome TGPlayerClockTestClampsNegativeNanAndAbsurdDurations(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPlayerClock(-5, NO) isEqualToString:@"0:00"],
			"a negative position (a seek that overshot) must clamp to zero");
	TGTestExpectTrue(&outcome, [TGPlayerClock(NAN, NO) isEqualToString:@"0:00"],
			"an unknown duration arrives as NaN from the player and must clamp, not print \"nan\"");
	TGTestExpectTrue(&outcome, [TGPlayerClock(1.0e9, NO) isEqualToString:@"0:00"],
			"a duration past the 359999-second ceiling is a bad value, not a 16000-hour track");

	return outcome;
}

TGTestOutcome TGPlayerClockTestNegativeFlagPrefixesTheRemainingTime(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGPlayerClock(65, YES) isEqualToString:@"-1:05"],
			"the remaining-time label counts down, so it carries a leading minus");
	TGTestExpectTrue(&outcome, [TGPlayerClock(0, YES) isEqualToString:@"-0:00"],
			"the countdown keeps its minus at zero, matching the -0:00 the player shows with no duration yet");

	return outcome;
}

TGTestOutcome TGLiveLocationFixTestHeadingReservesZeroForUnknown(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectEqualInteger(&outcome, TGLiveLocationHeadingFromCourse(-1), 0,
			"CoreLocation reports a negative course when it does not know the heading, and TDLib reads 0 as "
			"\"no heading\", so an unknown course must stay 0");
	TGTestExpectEqualInteger(&outcome, TGLiveLocationHeadingFromCourse(0), 360,
			"a real course of due north is 0 degrees, which TDLib would read as unknown: it must be sent as 360");

	return outcome;
}

TGTestOutcome TGLiveLocationFixTestHeadingRoundsAndClampsToThreeSixty(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectEqualInteger(&outcome, TGLiveLocationHeadingFromCourse(89.4), 89,
			"a course rounds to the nearest whole degree");
	TGTestExpectEqualInteger(&outcome, TGLiveLocationHeadingFromCourse(89.5), 90,
			"a half degree rounds up");
	TGTestExpectEqualInteger(&outcome, TGLiveLocationHeadingFromCourse(360), 360,
			"a full turn is the maximum TDLib accepts");
	TGTestExpectEqualInteger(&outcome, TGLiveLocationHeadingFromCourse(400), 360,
			"a course past a full turn must clamp rather than be rejected by the server");

	return outcome;
}

TGTestOutcome TGLiveLocationFixTestAccuracyClampsAnInvalidFix(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGLiveLocationAccuracyFromFix(-1) == 0.0,
			"CoreLocation reports a negative horizontal accuracy for an invalid fix; TDLib wants 0 for unknown");
	TGTestExpectTrue(&outcome, TGLiveLocationAccuracyFromFix(12.5) == 12.5,
			"a real accuracy passes through untouched");

	return outcome;
}

TGTestOutcome TGDiceEmojiTestAcceptsEveryDiceEmojiTelegramSends(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *dice = @[ @"\U0001F3B2", @"\U0001F3AF", @"\U0001F3C0", @"\U000026BD",
		@"\U000026BD\U0000FE0F", @"\U0001F3B0", @"\U0001F3B3" ];
	for (NSString *emoji in dice) {
		TGTestExpectTrue(&outcome, TGComposerTextIsSendableDiceEmoji(emoji),
				"each of the seven dice emoji Telegram animates must be recognised, including the football with "
				"its variation selector, or the composer sends it as plain text and no animation plays");
	}

	return outcome;
}

TGTestOutcome TGDiceEmojiTestRejectsPlainTextAndOtherEmoji(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, !TGComposerTextIsSendableDiceEmoji(@"hello"),
			"ordinary text is not a dice send");
	TGTestExpectTrue(&outcome, !TGComposerTextIsSendableDiceEmoji(@""),
			"an empty composer is not a dice send");
	TGTestExpectTrue(&outcome, !TGComposerTextIsSendableDiceEmoji(nil),
			"a nil text must answer NO rather than crash");
	TGTestExpectTrue(&outcome, !TGComposerTextIsSendableDiceEmoji(@"\U0001F642"),
			"an emoji Telegram does not animate as dice must send as an ordinary message");
	TGTestExpectTrue(&outcome, !TGComposerTextIsSendableDiceEmoji(@"\U0001F3B2\U0001F3B2"),
			"two dice emoji are text, not a dice send: only a lone one animates");

	return outcome;
}

TGTestOutcome TGThemeGeometryTestGradientPointsForCardinalRotations(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGSize size = CGSizeMake(100, 200);
	CGPoint start = CGPointZero;
	CGPoint end = CGPointZero;

	TGWallpaperGradientPoints(0, size, &start, &end);
	TGTestExpectTrue(&outcome, fabs(start.x - 50) < 0.01f && fabs(start.y - 0) < 0.01f,
			"an unrotated wallpaper gradient runs top to bottom, starting at the top centre");
	TGTestExpectTrue(&outcome, fabs(end.x - 50) < 0.01f && fabs(end.y - 200) < 0.01f,
			"and ending at the bottom centre");

	TGWallpaperGradientPoints(90, size, &start, &end);
	TGTestExpectTrue(&outcome, fabs(start.x - 0) < 0.01f && fabs(start.y - 100) < 0.01f,
			"a quarter turn runs left to right, starting at the left edge's middle");
	TGTestExpectTrue(&outcome, fabs(end.x - 100) < 0.01f && fabs(end.y - 100) < 0.01f,
			"and ending at the right edge's middle");

	TGWallpaperGradientPoints(180, size, &start, &end);
	TGTestExpectTrue(&outcome, fabs(start.y - 200) < 0.01f && fabs(end.y - 0) < 0.01f,
			"a half turn swaps the ends of the unrotated gradient");

	return outcome;
}

TGTestOutcome TGThemeGeometryTestGradientPointsAreSymmetricAboutTheCentre(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	CGSize size = CGSizeMake(320, 480);
	CGPoint start = CGPointZero;
	CGPoint end = CGPointZero;
	TGWallpaperGradientPoints(37, size, &start, &end);

	TGTestExpectTrue(&outcome, fabs((start.x + end.x) / 2 - 160) < 0.01f,
			"whatever the rotation, the two gradient points must straddle the centre horizontally");
	TGTestExpectTrue(&outcome, fabs((start.y + end.y) / 2 - 240) < 0.01f,
			"and vertically, or the gradient drifts off the wallpaper as it rotates");

	TGWallpaperGradientPoints(37, size, NULL, NULL);
	TGTestExpectTrue(&outcome, YES,
			"passing no out-pointers must be safe: callers that want only one end pass NULL for the other");

	return outcome;
}

TGTestOutcome TGThemeGeometryTestGroupedCommentInsetOnlyAppliesOnWideLayouts(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, TGGroupedCommentInset(320) == 0.0f,
			"a phone-width table gets no side inset");
	TGTestExpectTrue(&outcome, TGGroupedCommentInset(399) == 0.0f,
			"the inset starts at 400 points, so one point under it there is still none");
	TGTestExpectTrue(&outcome, TGGroupedCommentInset(400) == 0.0f,
			"between 400 and 678 points the text still spans the full width: the inset is the overflow past 678");
	TGTestExpectTrue(&outcome, TGGroupedCommentInset(768) == 45.0f,
			"an iPad-width table centres the 678-point column, insetting (768 - 678) / 2 on each side");
	TGTestExpectTrue(&outcome, TGGroupedCommentInset(769) == 45.0f,
			"the inset is truncated to whole points so the text never lands on a half pixel");

	return outcome;
}

TGTestOutcome TGWebBrowserExceptionURLTestPrependsHttpsOnlyWhenNoSchemeIsPresent(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
			[TGWebBrowserNormalizeExceptionURL(@"example.com") isEqualToString:@"https://example.com"],
			"a bare domain must gain a scheme, or TDLib cannot parse the exception");
	TGTestExpectTrue(&outcome,
			[TGWebBrowserNormalizeExceptionURL(@"  example.com  ") isEqualToString:@"https://example.com"],
			"surrounding whitespace from the alert's text field must be trimmed first");
	TGTestExpectTrue(&outcome,
			[TGWebBrowserNormalizeExceptionURL(@"http://example.com") isEqualToString:@"http://example.com"],
			"an explicit http scheme must be left alone rather than upgraded behind the user's back");
	TGTestExpectTrue(&outcome,
			[TGWebBrowserNormalizeExceptionURL(@"HTTPS://Example.com") isEqualToString:@"HTTPS://Example.com"],
			"the scheme check is case-insensitive but must not rewrite the casing the user typed");
	TGTestExpectTrue(&outcome, [TGWebBrowserNormalizeExceptionURL(@"   ") isEqualToString:@""],
			"a whitespace-only entry is not an exception: it must come back empty so the caller drops it");
	TGTestExpectTrue(&outcome, [TGWebBrowserNormalizeExceptionURL(nil) isEqualToString:@""],
			"a nil entry must come back empty rather than crash");

	return outcome;
}


#import "tg_preference_flags_tests.h"
#import "../../src/Utilities/TGPreferenceFlags.h"

static void TGPreferenceFlagsForget(NSString *key) {
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
}

TGTestOutcome TGPreferenceFlagsTestStickerFlagsDefaultOn(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGPreferenceFlagsForget(@"TGStickerLoopAnimated");
	TGTestExpectTrue(&outcome, [TGPreferenceFlags stickersLoopAnimatedEnabled],
			"animated stickers loop on a fresh install, as they do on every other Telegram");

	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"TGStickerLoopAnimated"];
	TGTestExpectTrue(&outcome, ![TGPreferenceFlags stickersLoopAnimatedEnabled],
			"turning the switch off is remembered");

	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"TGStickerLoopAnimated"];
	TGTestExpectTrue(&outcome, [TGPreferenceFlags stickersLoopAnimatedEnabled],
			"and turning it back on is remembered too");
	TGPreferenceFlagsForget(@"TGStickerLoopAnimated");

	TGPreferenceFlagsForget(@"TGStickerLargeEmoji");
	TGTestExpectTrue(&outcome, [TGPreferenceFlags stickersLargeEmojiEnabled],
			"large emoji is on by default, the flag this one was modelled on");

	return outcome;
}

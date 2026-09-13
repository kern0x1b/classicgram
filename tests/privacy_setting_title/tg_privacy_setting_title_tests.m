#import "tg_privacy_setting_title_tests.h"
#import "../../src/Utilities/TGPrivacySettingTitle.h"

TGTestOutcome TGPrivacySettingTitleTestEverySettingTheScreenListsHasATitle(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;
	NSArray *settings = @[
		@"ShowStatus", @"ShowProfilePhoto", @"ShowBio", @"ShowBirthdate", @"ShowPhoneNumber",
		@"ShowProfileAudio", @"ShowLinkInForwardedMessages", @"AllowChatInvites", @"AllowCalls",
		@"AllowPeerToPeerCalls", @"AllowPrivateVoiceAndVideoNoteMessages",
		@"AllowFindingByPhoneNumber", @"AutosaveGifts", @"AllowUnpaidMessages",
	];
	for (NSString *setting in settings) {
		NSString *title = TGPrivacySettingTitle(setting);
		TGTestExpectTrue(&outcome, title.length > 0 && ![title isEqualToString:setting],
				"every privacy setting the screen lists reads as a phrase, not as its TDLib name");
	}

	TGTestExpectTrue(&outcome, [TGPrivacySettingTitle(@"ShowStatus") isEqualToString:@"Last Seen"],
			"the last-seen row keeps the wording the screen has always shown");
	TGTestExpectTrue(&outcome, [TGPrivacySettingTitle(@"SomethingTelegramAddedLater")
			isEqualToString:@"SomethingTelegramAddedLater"],
			"a setting this build has never heard of shows its own name rather than an empty row");
	TGTestExpectTrue(&outcome, [TGPrivacySettingTitle(@"") isEqualToString:@""],
			"no setting at all is an empty title, never a crash");
	TGTestExpectTrue(&outcome, [TGPrivacySettingTitle(nil) isEqualToString:@""],
			"a missing setting is an empty title too");
	TGTestExpectTrue(&outcome, [TGPrivacySettingTitle((NSString *)@42) isEqualToString:@""],
			"a value that is not a string never reaches a string method");

	return outcome;
}

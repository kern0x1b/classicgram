#import "TGPrivacySettingTitle.h"
#import "TGLocalization.h"

NSString *TGPrivacySettingTitle(NSString *setting) {
	if (![setting isKindOfClass:[NSString class]] || !setting.length)
		return @"";
	NSDictionary *titles = @{
		@"ShowStatus" : TGL(@"Privacy.Setting.LastSeen", @"Last Seen"),
		@"ShowProfilePhoto" : TGL(@"Privacy.Setting.ProfilePhoto", @"Profile Photo"),
		@"ShowBio" : TGL(@"Privacy.Setting.Bio", @"Bio"),
		@"ShowBirthdate" : TGL(@"Privacy.Setting.Birthday", @"Birthday"),
		@"ShowPhoneNumber" : TGL(@"Privacy.Setting.PhoneNumber", @"Phone Number"),
		@"ShowProfileAudio" : TGL(@"Privacy.Setting.ProfileVoiceMusic", @"Profile Voice/Music"),
		@"ShowLinkInForwardedMessages" : TGL(@"Privacy.Setting.ForwardedMessages", @"Forwarded Messages"),
		@"AllowChatInvites" : TGL(@"Privacy.Setting.GroupsandChannels", @"Groups and Channels"),
		@"AllowCalls" : TGL(@"Privacy.Setting.Calls", @"Calls"),
		@"AllowPeerToPeerCalls" : TGL(@"Privacy.Setting.PeertoPeerCalls", @"Peer-to-Peer Calls"),
		@"AllowPrivateVoiceAndVideoNoteMessages" : TGL(@"Privacy.Setting.VoiceMessages", @"Voice Messages"),
		@"AllowFindingByPhoneNumber" : TGL(@"Privacy.Setting.FindMebyPhone", @"Find Me by Phone"),
		@"AutosaveGifts" : TGL(@"Privacy.Setting.SaveGiftstoMyProfile", @"Save Gifts to My Profile"),
		@"AllowUnpaidMessages" : TGL(@"Privacy.Setting.ChargeForMessages", @"Charge For Messages"),
	};
	return titles[setting] ?: setting;
}

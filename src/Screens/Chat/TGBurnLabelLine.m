#import "TGBurnLabelLine.h"
#import "TGLocalization.h"

NSString *TGBurnLabelLineForKind(NSString *kind, BOOL outgoing, NSInteger destructTimer) {
	NSString *noun = TGL(@"Message.Photo", @"Photo");
	if ([kind isEqualToString:@"messageVideo"])
		noun = TGL(@"Message.Video", @"Video");
	else if ([kind isEqualToString:@"messageVideoNote"])
		noun = TGL(@"Message.VideoMessage", @"Video Message");
	else if ([kind isEqualToString:@"messageVoiceNote"])
		noun = TGL(@"Message.VoiceMessage", @"Voice Message");

	if (destructTimer > 0)
		return [NSString stringWithFormat:TGL(@"Chat.BurnsOnOpeningTimerFormat", @"%@, %lds after opening"),
			noun, (long)destructTimer];
	if (outgoing)
		return [NSString stringWithFormat:TGL(@"Chat.BurnsOnOpeningOnceFormat", @"%@, can be opened once"), noun];
	return [NSString stringWithFormat:TGL(@"Chat.BurnsOnOpeningTapFormat", @"%@, tap to open once"), noun];
}

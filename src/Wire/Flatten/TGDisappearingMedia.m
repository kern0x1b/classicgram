#import "TGDisappearingMedia.h"

#import "TGLocalization.h"

BOOL TGMediaContentDisappears(NSDictionary *content) {
	if (![content isKindOfClass:NSDictionary.class])
		return NO;
	if ([content[@"is_secret"] boolValue])
		return YES;
	return [content[@"self_destruct_type"] isKindOfClass:NSDictionary.class];
}

BOOL TGMessageDisappears(NSDictionary *message) {
	if (![message isKindOfClass:NSDictionary.class])
		return NO;
	if ([message[@"self_destruct_type"] isKindOfClass:NSDictionary.class])
		return YES;
	return TGMediaContentDisappears(message[@"content"]);
}

NSString *TGDisappearingMediaLabel(NSString *contentType) {
	if (![contentType isKindOfClass:NSString.class])
		return nil;
	if ([contentType isEqualToString:@"messagePhoto"])
		return TGL(@"SecretImage.Title", @"Disappearing Photo");
	if ([contentType isEqualToString:@"messageVideo"])
		return TGL(@"SecretVideo.Title", @"Disappearing Video");
	if ([contentType isEqualToString:@"messageVoiceNote"])
		return TGL(@"SecretVoice.Title", @"Disappearing Voice Message");
	if ([contentType isEqualToString:@"messageVideoNote"])
		return TGL(@"SecretVideoMessage.Title", @"Disappearing Video Message");
	return nil;
}

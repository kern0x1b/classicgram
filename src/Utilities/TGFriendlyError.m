#import "TGFriendlyError.h"

#import "TGLocalization.h"
#import "TGFloodWaitText.h"
#import "TGFloodWaitMessage.h"

BOOL TGErrorMessageIsMachineCode(NSString *message) {
	if (![message isKindOfClass:NSString.class] || !message.length)
		return NO;
	NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
		@"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"];
	NSCharacterSet *unexpected = [allowed invertedSet];
	if ([message rangeOfCharacterFromSet:unexpected].location != NSNotFound)
		return NO;
	return [message rangeOfString:@"_"].location != NSNotFound || message.length >= 4;
}

static NSString *TGKnownErrorText(NSString *message) {
	NSString *wait = TGFloodWaitNoticeText(TGFloodWaitSecondsFromMessage(message));
	if (wait.length)
		return wait;
	if ([message hasPrefix:@"FLOOD_WAIT_"] || [message hasPrefix:@"SLOWMODE_WAIT_"])
		return TGL(@"Error.TooManyAttempts", @"Too many attempts. Please try again later.");
	if ([message isEqualToString:@"USER_PRIVACY_RESTRICTED"])
		return TGL(@"Error.PrivacyRestricted",
			@"This person's privacy settings do not allow that.");
	if ([message isEqualToString:@"CHAT_ADMIN_REQUIRED"] ||
		[message isEqualToString:@"CHAT_WRITE_FORBIDDEN"] ||
		[message isEqualToString:@"CHAT_SEND_MEDIA_FORBIDDEN"])
		return TGL(@"Error.NotAllowedHere", @"You are not allowed to do that here.");
	if ([message isEqualToString:@"USER_ALREADY_PARTICIPANT"])
		return TGL(@"Error.AlreadyAMember", @"That person is already a member.");
	if ([message isEqualToString:@"INVITE_HASH_EXPIRED"] ||
		[message isEqualToString:@"INVITE_HASH_INVALID"] ||
		[message isEqualToString:@"INVITE_REQUEST_SENT"])
		return TGL(@"Error.InviteLinkNoLongerValid", @"This invite link is no longer valid.");
	if ([message isEqualToString:@"CHANNELS_TOO_MUCH"])
		return TGL(@"Error.TooManyGroupsAndChannels",
			@"You are in too many groups and channels. Leave one first.");
	if ([message isEqualToString:@"PEER_ID_INVALID"] ||
		[message isEqualToString:@"USER_NOT_MUTUAL_CONTACT"])
		return TGL(@"Error.ChatNoLongerReachable", @"That chat could not be reached.");
	if ([message isEqualToString:@"FILTER_INCLUDE_EMPTY"])
		return TGL(@"Error.FolderNeedsAChat", @"A folder needs at least one chat in it.");
	if ([message isEqualToString:@"FILTER_TITLE_EMPTY"])
		return TGL(@"Error.FolderNeedsAName", @"A folder needs a name.");
	if ([message isEqualToString:@"FILTERS_TOO_MUCH"])
		return TGL(@"Error.TooManyFolders", @"You already have as many folders as Telegram allows.");
	if ([message isEqualToString:@"USERNAME_INVALID"])
		return TGL(@"Error.UsernameInvalid", @"That username is not valid.");
	if ([message isEqualToString:@"USERNAME_OCCUPIED"] ||
		[message isEqualToString:@"USERNAME_PURCHASE_AVAILABLE"])
		return TGL(@"Error.UsernameTaken", @"That username is already taken.");
	if ([message isEqualToString:@"USERNAMES_ACTIVE_TOO_MUCH"])
		return TGL(@"Username.TooManyActiveLinks",
			@"Sorry, you can't have that many active links. Turn off another link first.");
	if ([message isEqualToString:@"STICKERSET_INVALID"])
		return TGL(@"Error.StickerSetGone", @"That sticker set no longer exists.");
	if ([message isEqualToString:@"MESSAGE_TOO_LONG"])
		return TGL(@"Error.MessageTooLong", @"That message is too long to send.");
	if ([message isEqualToString:@"MEDIA_EMPTY"])
		return TGL(@"Error.MediaRejected", @"Telegram rejected that file.");
	if ([message isEqualToString:@"Chat not found"] ||
		[message isEqualToString:@"Invalid chat identifier specified"])
		return TGL(@"Error.ChatNoLongerReachable", @"That chat could not be reached.");
	if ([message isEqualToString:@"Message not found"] ||
		[message isEqualToString:@"MESSAGE_ID_INVALID"])
		return TGL(@"Error.MessageGone", @"That message is no longer there.");
	if ([message isEqualToString:@"User not found"] ||
		[message isEqualToString:@"USER_ID_INVALID"])
		return TGL(@"Error.PersonNotFound", @"That person could not be found.");
	if ([message isEqualToString:@"Have no rights to send a message"] ||
		[message isEqualToString:@"Not enough rights"] ||
		[message isEqualToString:@"Have no write access to the chat"])
		return TGL(@"Error.NotAllowedHere", @"You are not allowed to do that here.");
	if ([message isEqualToString:@"Request aborted"] ||
		[message isEqualToString:@"Connection closed"])
		return TGL(@"Error.RequestDidNotFinish",
			@"That did not finish. Check the connection and try again.");
	return nil;
}

NSString *TGFriendlyErrorText(NSString *message, NSString *fallback) {
	NSString *unknownFallback = fallback.length
		? fallback
		: TGL(@"Login.UnknownError", @"An error occurred, please try again later.");
	if (![message isKindOfClass:NSString.class] || !message.length)
		return unknownFallback;
	NSString *known = TGKnownErrorText(message);
	if (known.length)
		return known;
	if (TGErrorMessageIsMachineCode(message))
		return unknownFallback;
	return message;
}

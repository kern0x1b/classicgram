#import "TGFlattenMessage.h"
#import "TGDisappearingMedia.h"
#import "TGStringTruncation.h"
#import "TGDurationText.h"
#import "TGDateUtils.h"
#import "TGTDLibInt64.h"
#import "TGServiceSharedLine.h"
#import "TGMediaPreviewName.h"
#import "TGBase64.h"
#import "TGClient+MessageContent.h"
#import "TGFlattenMessages.h"
#import "TGFlattenPayments.h"
#import "TGFlattenTranslation.h"
#import "TGLocalization.h"

@implementation TGFlattenContext
@end

NSData *TGCliBase64(id value) {
	return TGBase64Decode(value);
}

NSTimeInterval TGDestructDeadlineFromRemaining(NSTimeInterval remainingSeconds, NSTimeInterval now) {
	return remainingSeconds > 0 ? now + remainingSeconds : 0;
}

NSTimeInterval TGRemainingSecondsUntilDestruct(NSTimeInterval deadline, NSTimeInterval now) {
	if (deadline <= 0)
		return 0;
	NSTimeInterval remaining = deadline - now;
	return remaining > 0 ? remaining : 0;
}

BOOL TGMessageIsScheduled(NSDictionary *message) {
	return [message[@"scheduling_state"] isKindOfClass:NSDictionary.class];
}

static NSArray *TGPhotoSizeList(NSArray *sizes) {
	NSMutableArray *out = [NSMutableArray arrayWithCapacity:sizes.count];
	for (NSDictionary *size in sizes) {
		NSNumber *fileId = size[@"photo"][@"id"];
		NSNumber *width = size[@"width"];
		NSNumber *height = size[@"height"];
		if (![fileId isKindOfClass:NSNumber.class] || [fileId longLongValue] == 0)
			continue;
		if ([width intValue] < 1 || [height intValue] < 1)
			continue;
		[out addObject:@{@"id" : fileId, @"w" : width, @"h" : height}];
	}
	[out sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
		int wa = [a[@"w"] intValue], wb = [b[@"w"] intValue];
		if (wa == wb)
			return NSOrderedSame;
		return wa < wb ? NSOrderedAscending : NSOrderedDescending;
	}];
	return out;
}

static NSString *TGDocumentExtension(NSString *fileName, NSString *mimeType) {
	NSString *extension = [fileName pathExtension];
	if (!extension.length && [mimeType isKindOfClass:NSString.class]) {
		NSRange slash = [mimeType rangeOfString:@"/" options:NSBackwardsSearch];
		if (slash.location != NSNotFound)
			extension = [mimeType substringFromIndex:slash.location + 1];
	}
	if (extension.length > 4)
		extension = TGSafeSubstringToIndex(extension, 4);
	return extension.uppercaseString ?: @"";
}

static NSString *TGUnsupportedMessageTextValue(void) {
	return TGL(@"Conversation.UnsupportedMediaPlaceholder",
		@"This message is not supported on your version of Telegram. Please update to the latest version."
		 "Please update to the latest version.");
}

static BOOL TGDrawableMessageKind(NSString *ctype) {
	static NSSet *drawable = nil;
	if (!drawable)
		drawable = [[NSSet alloc] initWithObjects:
				@"messageText", @"messagePhoto", @"messageVideo", @"messageVideoNote",
			@"messageAnimation", @"messageSticker", @"messageAnimatedEmoji",
			@"messageDocument", @"messageVoiceNote", @"messageAudio",
			@"messageContact", @"messageVenue", @"messageLocation",
			@"messageLiveLocation", @"messagePoll", @"messageChecklist",
			@"messageDice", @"messageGame", @"messageInvoice", @"messageStory",
			@"messagePaidMedia", @"messageCall", @"messageGroupCall",
			@"messageRichMessage",
			@"messageExpiredPhoto", @"messageExpiredVideo",
			@"messageExpiredVoiceNote", @"messageExpiredVideoNote",
			@"messageUnsupported", nil];
	return ctype.length && [drawable containsObject:ctype];
}

static NSString *TGServiceTitleForChat(TGFlattenContext *context, int64_t chatId) {
	if (!chatId)
		return nil;
	id title = context.chatsById[@(chatId)][@"title"];
	return ([title isKindOfClass:NSString.class] && [title length]) ? title : nil;
}

static NSString *TGServiceUserName(TGFlattenContext *context, int64_t userId) {
	if (!userId)
		return TGL(@"Premium.GiftedTitle.Someone", @"Someone");
	NSString *name = context.userName ? context.userName(userId) : nil;
	if (name.length)
		return name;
	name = TGServiceTitleForChat(context, userId);
	return name.length ? name : TGL(@"Premium.GiftedTitle.Someone", @"Someone");
}

static int64_t TGServiceSenderId(id sender) {
	if (![sender isKindOfClass:NSDictionary.class])
		return 0;
	int64_t user = TGTDLibInt64(((NSDictionary *)sender)[@"user_id"]);
	if (user)
		return user;
	return TGTDLibInt64(((NSDictionary *)sender)[@"chat_id"]);
}

static NSString *TGServiceSenderName(TGFlattenContext *context, id sender) {
	return TGServiceUserName(context, TGServiceSenderId(sender));
}

static NSString *TGServiceUserList(TGFlattenContext *context, id userIds) {
	if (![userIds isKindOfClass:NSArray.class])
		return TGL(@"Notification.UnknownUserListLowercase", @"someone");
	NSMutableArray *names = [NSMutableArray array];
	for (NSNumber *uid in (NSArray *)userIds)
		if ([uid isKindOfClass:NSNumber.class])
			[names addObject:TGServiceUserName(context, [uid longLongValue])];
	return names.count ? [names componentsJoinedByString:@", "]
					   : TGL(@"Notification.UnknownUserListLowercase", @"someone");
}

static NSString *TGServiceCountedWord(NSInteger count, NSString *singular) {
	if ([singular isEqualToString:@"second"])
		return TGLPlural(@"MessageTimer.Seconds", count, @"%ld second", @"%ld seconds");
	if ([singular isEqualToString:@"minute"])
		return TGLPlural(@"MessageTimer.Minutes", count, @"%ld minute", @"%ld minutes");
	if ([singular isEqualToString:@"hour"])
		return TGLPlural(@"MessageTimer.Hours", count, @"%ld hour", @"%ld hours");
	if ([singular isEqualToString:@"day"])
		return TGLPlural(@"MessageTimer.Days", count, @"%ld day", @"%ld days");
	if ([singular isEqualToString:@"week"])
		return TGLPlural(@"MessageTimer.Weeks", count, @"%ld week", @"%ld weeks");
	if ([singular isEqualToString:@"month"])
		return TGLPlural(@"MessageTimer.Months", count, @"%ld month", @"%ld months");
	if ([singular isEqualToString:@"task"])
		return TGLPlural(@"Notification.TodoTasks", count, @"%ld task", @"%ld tasks");
	if ([singular isEqualToString:@"winner"])
		return TGLPlural(@"Notification.GiveawayWinnersCount", count, @"%ld winner",
			@"%ld winners");
	return TGLPlural(@"Notification.PaidMessage.Messages", count, @"%ld message",
		@"%ld messages");
}

static NSString *TGServiceTimeWords(NSInteger seconds) {
	if (seconds < 1)
		return TGServiceCountedWord(0, @"second");
	if (seconds < 60)
		return TGServiceCountedWord(seconds, @"second");
	if (seconds < 3600)
		return TGServiceCountedWord(seconds / 60, @"minute");
	if (seconds < 86400)
		return TGServiceCountedWord(seconds / 3600, @"hour");
	if (seconds < 7 * 86400)
		return TGServiceCountedWord(seconds / 86400, @"day");
	if (seconds < 31 * 86400)
		return TGServiceCountedWord(seconds / (7 * 86400), @"week");
	return TGServiceCountedWord(seconds / (30 * 86400), @"month");
}

static NSString *TGServiceClockLength(NSInteger seconds) {
	return TGDurationText(seconds);
}

static NSString *TGServiceStars(long long count) {
	return TGLPlural(@"Notification.StarsCount", (NSInteger)count, @"%lld Star", @"%lld Stars");
}

static NSString *TGServiceAmount(id currency, long long amount) {
	NSString *code = [currency isKindOfClass:NSString.class] ? currency : @"";
	if ([code isEqualToString:@"XTR"])
		return TGServiceStars(amount);
	if (!code.length)
		return TGPayDecimalAmount(amount, code);
	return [NSString stringWithFormat:@"%@ %@", TGPayDecimalAmount(amount, code), code];
}

static NSString *TGServiceDateWords(NSTimeInterval stamp) {
	if (stamp < 1)
		return TGL(@"Notification.DateLater", @"later");
	return [TGDateUtils stringForDateAndTime:(int)stamp];
}

static NSString *TGServicePremiumLength(NSDictionary *content) {
	NSInteger months = [content[@"month_count"] integerValue];
	if (months > 0)
		return TGServiceCountedWord(months, @"month");
	NSInteger days = [content[@"day_count"] integerValue];
	if (days > 0)
		return TGServiceCountedWord(days, @"day");
	return TGL(@"Notification.PremiumGift.Title", @"Telegram Premium");
}

NSString *TGServiceCallTitle(NSDictionary *content, BOOL mine) {
	NSString *reason = content[@"discard_reason"][@"@type"];
	BOOL video = [content[@"is_video"] boolValue];
	BOOL missed = [reason isEqualToString:@"callDiscardReasonMissed"];
	BOOL declined = [reason isEqualToString:@"callDiscardReasonDeclined"];

	if (missed || declined)
		return mine ? (video ? TGL(@"Notification.VideoCallCanceled", @"Cancelled Video Call")
							 : TGL(@"Notification.CallCanceled", @"Cancelled Call"))
					: (video ? TGL(@"Notification.VideoCallMissed", @"Missed Video Call")
							 : TGL(@"Notification.CallMissed", @"Missed Call"));
	return mine ? (video ? TGL(@"Notification.VideoCallOutgoing", @"Outgoing Video Call")
						 : TGL(@"Notification.CallOutgoing", @"Outgoing Call"))
				: (video ? TGL(@"Notification.VideoCallIncoming", @"Incoming Video Call")
						 : TGL(@"Notification.CallIncoming", @"Incoming Call"));
}

static NSString *TGServiceCallLine(NSDictionary *content, BOOL mine) {
	NSString *reason = content[@"discard_reason"][@"@type"];
	NSInteger seconds = [content[@"duration"] integerValue];
	BOOL missed = [reason isEqualToString:@"callDiscardReasonMissed"] ||
		[reason isEqualToString:@"callDiscardReasonDeclined"];
	NSString *title = TGServiceCallTitle(content, mine);

	if (!missed && seconds > 0)
		return [NSString stringWithFormat:TGL(@"Notification.CallTimeFormat", @"%@ (%@)"),
			title, TGServiceTimeWords(seconds)];
	return title;
}

NSString *TGServiceGroupCallTitle(NSDictionary *content, BOOL mine) {
	if ([content[@"was_missed"] boolValue])
		return mine ? TGL(@"Chat.CallMessage.DeclinedGroupCall", @"Declined Group Call")
					: TGL(@"Chat.CallMessage.MissedGroupCall", @"Missed Group Call");
	return mine ? TGL(@"Chat.CallMessage.OutgoingGroupCall", @"Outgoing Group Call")
				: TGL(@"Chat.CallMessage.IncomingGroupCall", @"Incoming Group Call");
}

static NSString *TGServiceGroupCallLine(NSDictionary *content, BOOL mine) {
	NSInteger seconds = [content[@"duration"] integerValue];
	NSString *title = TGServiceGroupCallTitle(content, mine);
	if ([content[@"is_active"] boolValue] || [content[@"was_missed"] boolValue])
		return title;
	if (seconds > 0)
		return [NSString stringWithFormat:TGL(@"Notification.CallTimeFormat", @"%@ (%@)"),
			title, TGServiceTimeWords(seconds)];
	return title;
}

static NSString *TGServicePassportKinds(NSArray *types) {
	NSMutableArray *words = [NSMutableArray array];
	for (NSDictionary *entry in types) {
		NSString *kind = [entry isKindOfClass:NSDictionary.class]
			? entry[@"@type"]
			: nil;
		NSString *word = nil;
		if ([kind isEqualToString:@"passportElementTypePersonalDetails"])
			word = TGL(@"Notification.PassportValuePersonalDetails", @"personal details");
		else if ([kind isEqualToString:@"passportElementTypePassport"] ||
			[kind isEqualToString:@"passportElementTypeInternalPassport"] ||
			[kind isEqualToString:@"passportElementTypeDriverLicense"] ||
			[kind isEqualToString:@"passportElementTypeIdentityCard"])
			word = TGL(@"Notification.PassportValueProofOfIdentity", @"proof of identity");
		else if ([kind isEqualToString:@"passportElementTypeAddress"])
			word = TGL(@"Notification.PassportValueAddress", @"your address");
		else if ([kind isEqualToString:@"passportElementTypeBankStatement"] ||
			[kind isEqualToString:@"passportElementTypeUtilityBill"] ||
			[kind isEqualToString:@"passportElementTypeRentalAgreement"] ||
			[kind isEqualToString:@"passportElementTypePassportRegistration"] ||
			[kind isEqualToString:@"passportElementTypeTemporaryRegistration"])
			word = TGL(@"Notification.PassportValueProofOfAddress", @"proof of address");
		else if ([kind isEqualToString:@"passportElementTypePhoneNumber"])
			word = TGL(@"Notification.PassportValuePhone", @"phone number");
		else if ([kind isEqualToString:@"passportElementTypeEmailAddress"])
			word = TGL(@"Notification.PassportValueEmail", @"email address");
		if (word.length && ![words containsObject:word])
			[words addObject:word];
	}
	return words.count ? [words componentsJoinedByString:@", "]
					   : TGL(@"Notification.PassportValueDocuments", @"documents");
}

static NSString *TGServiceTopicLine(NSDictionary *content, NSString *ctype,
	NSString *actor, BOOL named) {
	if ([ctype isEqualToString:@"messageForumTopicCreated"])
		return TGL(@"Notification.ForumTopicCreated", @"Topic created");
	if ([ctype isEqualToString:@"messageForumTopicEdited"]) {
		NSString *name = content[@"name"];
		BOOL iconEdited = [content[@"edit_icon_custom_emoji_id"] boolValue];
		if (name.length && iconEdited)
			return named
				? [NSString stringWithFormat:
						  TGL(@"Notification.ForumTopicRenamedAndIconChangedAuthor",
							  @"%@ changed the topic title to \"%@\" and changed the icon"),
						  actor, name]
				: [NSString stringWithFormat:TGL(@"Notification.ForumTopicRenamed",
											@"Topic renamed to \"%@\""),
					  name];
		if (name.length)
			return named
				? [NSString stringWithFormat:TGL(@"Notification.ForumTopicRenamedAuthor",
											@"%@ changed the topic title to \"%@\""),
					  actor, name]
				: [NSString stringWithFormat:TGL(@"Notification.ForumTopicRenamed",
											@"Topic renamed to \"%@\""),
					  name];
		if (iconEdited)
			return named
				? [NSString stringWithFormat:
						  TGL(@"Notification.ForumTopicIconOnlyChangedAuthor",
							  @"%@ changed the topic icon"),
						  actor]
				: TGL(@"Notification.ForumTopicIconOnlyChanged", @"Topic icon changed");
		return nil;
	}
	if ([ctype isEqualToString:@"messageForumTopicIsClosedToggled"]) {
		BOOL closed = [content[@"is_closed"] boolValue];
		if (named)
			return closed
				? [NSString stringWithFormat:TGL(@"Notification.ForumTopicClosedAuthor",
											@"%@ closed topic"),
					  actor]
				: [NSString stringWithFormat:TGL(@"Notification.ForumTopicReopenedAuthor",
											@"%@ reopened topic"),
					  actor];
		return closed ? TGL(@"Notification.ForumTopicClosed", @"Topic closed")
					  : TGL(@"Notification.ForumTopicReopened", @"Topic reopened");
	}
	if ([ctype isEqualToString:@"messageForumTopicIsHiddenToggled"]) {
		BOOL hidden = [content[@"is_hidden"] boolValue];
		if (named)
			return hidden
				? [NSString stringWithFormat:TGL(@"Notification.ForumTopicHiddenAuthor",
											@"%@ hid the topic"),
					  actor]
				: [NSString stringWithFormat:TGL(@"Notification.ForumTopicUnhiddenAuthor",
											@"%@ unhid the topic"),
					  actor];
		return hidden ? TGL(@"Notification.ForumTopicHidden", @"Topic hidden")
					  : TGL(@"Notification.ForumTopicUnhidden", @"Topic unhidden");
	}
	return nil;
}

static NSString *TGServiceGiftLine(TGFlattenContext *context, NSDictionary *content,
	NSString *ctype, NSString *actor, BOOL mine) {
	if ([ctype isEqualToString:@"messageGiftedPremium"]) {
		NSString *length = TGServicePremiumLength(content);
		return mine
			? [NSString stringWithFormat:TGL(@"Notification.PremiumGift.SentYou",
										@"You sent a gift for %@"),
				  length]
			: [NSString stringWithFormat:TGL(@"Notification.PremiumGift.Sent",
										@"%@ sent you a gift for %@"),
				  actor, length];
	}
	if ([ctype isEqualToString:@"messagePremiumGiftCode"]) {
		if ([content[@"is_from_giveaway"] boolValue])
			return TGL(@"Notification.GiftLink", @"You received a gift");
		NSString *length = TGServicePremiumLength(content);
		return mine
			? [NSString stringWithFormat:TGL(@"Notification.PremiumGift.SentYou",
										@"You sent a gift for %@"),
				  length]
			: [NSString stringWithFormat:TGL(@"Notification.PremiumGift.Sent",
										@"%@ sent you a gift for %@"),
				  actor, length];
	}
	if ([ctype isEqualToString:@"messageGiftedStars"]) {
		NSString *stars = TGServiceStars([content[@"star_count"] longLongValue]);
		return mine
			? [NSString stringWithFormat:TGL(@"Notification.StarsGift.SentYou",
										@"You sent a gift for %@"),
				  stars]
			: [NSString stringWithFormat:TGL(@"Notification.StarsGift.Sent",
										@"%@ sent you a gift for %@"),
				  actor, stars];
	}
	if ([ctype isEqualToString:@"messageGiftedTon"]) {
		long long grams = [content[@"gram_amount"] longLongValue];
		NSString *amount = [NSString stringWithFormat:@"%.2f TON", grams / 1000000000.0];
		return mine
			? [NSString stringWithFormat:TGL(@"Notification.GiftedTon.SentYou",
										@"You sent a gift of %@"),
				  amount]
			: [NSString stringWithFormat:TGL(@"Notification.GiftedTon.Sent",
										@"%@ sent you a gift of %@"),
				  actor, amount];
	}
	if ([ctype isEqualToString:@"messageGiveawayPrizeStars"])
		return TGL(@"Notification.StarsPrize", @"You received a gift");
	if ([ctype isEqualToString:@"messageGift"]) {
		NSString *sender = TGServiceSenderName(context, content[@"sender_id"]);
		return mine
			? [NSString stringWithFormat:TGL(@"Notification.Gift.SentYou",
										@"You sent a gift to %@"),
				  TGServiceSenderName(context, content[@"receiver_id"])]
			: [NSString stringWithFormat:TGL(@"Notification.Gift.Sent",
										@"%@ sent you a gift"),
				  sender];
	}
	if ([ctype isEqualToString:@"messageUpgradedGift"])
		return mine
			? TGL(@"Notification.StarsGift.UpgradeSelf",
				  @"You turned a gift into a unique collectible")
			: [NSString stringWithFormat:TGL(@"Notification.StarsGift.Upgrade",
										@"%@ turned a gift into a unique collectible"),
				  actor];
	if ([ctype isEqualToString:@"messageRefundedUpgradedGift"])
		return TGL(@"Notification.GiftUpgradeRefunded", @"The gift upgrade was refunded");
	return nil;
}

NSString *TGPinnedDescriptorForContentKind(NSString *kind) {
	if ([kind isEqualToString:@"messagePhoto"])
		return TGL(@"Chat.PinnedDescriptor.Photo", @"a photo");
	if ([kind isEqualToString:@"messageVideo"])
		return TGL(@"Chat.PinnedDescriptor.Video", @"a video");
	if ([kind isEqualToString:@"messageVideoNote"])
		return TGL(@"Chat.PinnedDescriptor.VideoMessage", @"a video message");
	if ([kind isEqualToString:@"messageVoiceNote"])
		return TGL(@"Chat.PinnedDescriptor.VoiceMessage", @"a voice message");
	if ([kind isEqualToString:@"messageAudio"])
		return TGL(@"Chat.PinnedDescriptor.MusicFile", @"a music file");
	if ([kind isEqualToString:@"messageDocument"])
		return TGL(@"Chat.PinnedDescriptor.File", @"a file");
	if ([kind isEqualToString:@"messageAnimation"])
		return TGL(@"Chat.PinnedDescriptor.GIF", @"a GIF");
	if ([kind isEqualToString:@"messageSticker"] ||
		[kind isEqualToString:@"messageAnimatedEmoji"])
		return TGL(@"Chat.PinnedDescriptor.Sticker", @"a sticker");
	if ([kind isEqualToString:@"messageLocation"] ||
		[kind isEqualToString:@"messageLiveLocation"] ||
		[kind isEqualToString:@"messageVenue"])
		return TGL(@"Chat.PinnedDescriptor.Map", @"a map");
	if ([kind isEqualToString:@"messageContact"])
		return TGL(@"Chat.PinnedDescriptor.Contact", @"a contact");
	if ([kind isEqualToString:@"messageGame"])
		return TGL(@"Chat.PinnedDescriptor.Game", @"a game");
	if ([kind isEqualToString:@"messagePoll"])
		return TGL(@"Chat.PinnedDescriptor.Poll", @"a poll");
	if ([kind isEqualToString:@"messageChecklist"])
		return TGL(@"Chat.PinnedDescriptor.Checklist", @"a checklist");
	if ([kind isEqualToString:@"messageRichMessage"])
		return TGL(@"Chat.PinnedDescriptor.Article", @"an article");
	return nil;
}

NSString *TGComposePinnedNotice(NSString *actor, NSString *descriptor) {
	if (!descriptor.length)
		return nil;
	return [NSString stringWithFormat:TGL(@"Chat.PinnedNoticeFormat", @"%@ pinned %@"),
		actor, descriptor];
}

static NSDictionary *TGServiceAction(TGFlattenContext *context, NSDictionary *m,
	NSDictionary *content, NSString *ctype,
	NSString *actor, BOOL named, BOOL mine,
	BOOL isChannel, BOOL isSecretChat) {
	if (!ctype.length || TGDrawableMessageKind(ctype))
		return nil;

	NSString *line = nil;
	NSDictionary *photo = nil;
	NSNumber *pinnedId = nil;
	NSNumber *oldBackgroundMessageId = nil;
	NSNumber *onlyForSelf = nil;
	NSNumber *backgroundId = nil;

	if ([ctype isEqualToString:@"messageBasicGroupChatCreate"] ||
		[ctype isEqualToString:@"messageSupergroupChatCreate"]) {
		NSString *title = content[@"title"];
		if (isChannel)
			line = TGL(@"Notification.CreatedChannel", @"Channel created");
		else if (title.length && named)
			line = [NSString stringWithFormat:TGL(@"Notification.CreatedChatWithTitle",
										@"%@ created the group \"%@\""),
				actor, title];
		else if (named)
			line = [NSString stringWithFormat:TGL(@"Notification.CreatedChat",
										@"%@ created a group"),
				actor];
		else
			line = TGL(@"Notification.CreatedGroup", @"Group created");

	} else if ([ctype isEqualToString:@"messageChatChangeTitle"]) {
		NSString *title = content[@"title"] ?: @"";
		line = (named && !isChannel)
			? [NSString stringWithFormat:TGL(@"Notification.ChangedGroupName",
										@"%@ changed group name to \"%@\""),
				  actor, title]
			: [NSString stringWithFormat:TGL(@"Channel.MessageTitleUpdated",
										@"Channel renamed to \"%@\" "),
				  title];

	} else if ([ctype isEqualToString:@"messageChatChangePhoto"]) {
		NSDictionary *chatPhoto = [content[@"photo"] isKindOfClass:NSDictionary.class]
			? content[@"photo"]
			: nil;
		BOOL animated = [chatPhoto[@"animation"] isKindOfClass:NSDictionary.class];
		if (isChannel)
			line = animated ? TGL(@"Channel.MessageVideoUpdated", @"Channel video updated")
							: TGL(@"Channel.MessagePhotoUpdated", @"Channel photo updated");
		else if (named)
			line = animated
				? [NSString stringWithFormat:TGL(@"Notification.ChangedGroupVideo",
											@"%@ changed group video"),
					  actor]
				: [NSString stringWithFormat:TGL(@"Notification.ChangedGroupPhoto",
											@"%@ changed group photo"),
					  actor];
		else
			line = animated ? TGL(@"Group.MessageVideoUpdated", @"Group video updated")
							: TGL(@"Group.MessagePhotoUpdated", @"Group photo updated");
		photo = chatPhoto;

	} else if ([ctype isEqualToString:@"messageChatDeletePhoto"]) {
		if (isChannel)
			line = TGL(@"Channel.MessagePhotoRemoved", @"Channel photo removed");
		else if (named)
			line = [NSString stringWithFormat:TGL(@"Notification.RemovedGroupPhoto",
										@"%@ removed group photo"),
				actor];
		else
			line = TGL(@"Group.MessagePhotoRemoved", @"Group photo removed");

	} else if ([ctype isEqualToString:@"messageChatAddMembers"]) {
		NSArray *added = content[@"member_user_ids"];
		int64_t actorId = TGServiceSenderId(m[@"sender_id"]);
		if (added.count == 1 && [added[0] longLongValue] == actorId)
			line = isChannel
				? [NSString stringWithFormat:TGL(@"Notification.JoinedChannel",
											@"%@ joined the channel"),
					  actor]
				: [NSString stringWithFormat:TGL(@"Notification.JoinedChat",
											@"%@ joined the group"),
					  actor];
		else
			line = [NSString stringWithFormat:TGL(@"Notification.Invited",
										@"%@ invited %@"),
				actor, TGServiceUserList(context, added)];

	} else if ([ctype isEqualToString:@"messageChatDeleteMember"]) {
		int64_t goneId = [content[@"user_id"] longLongValue];
		int64_t actorId = TGServiceSenderId(m[@"sender_id"]);
		if (goneId == actorId)
			line = isChannel
				? [NSString stringWithFormat:TGL(@"Notification.LeftChannel",
											@"%@ left the channel"),
					  actor]
				: [NSString stringWithFormat:TGL(@"Notification.LeftChat",
											@"%@ left the group"),
					  actor];
		else
			line = [NSString stringWithFormat:TGL(@"Notification.Kicked",
										@"%@ removed %@"),
				actor, TGServiceUserName(context, goneId)];

	} else if ([ctype isEqualToString:@"messageChatJoinByLink"]) {
		line = mine
			? TGL(@"Notification.JoinedGroupByLinkYou",
				  @"You joined the group via invite link")
			: [NSString stringWithFormat:TGL(@"Notification.JoinedGroupByLink",
										@"%@ joined the group via invite link"),
				  actor];

	} else if ([ctype isEqualToString:@"messageChatJoinByRequest"]) {
		if (mine)
			line = isChannel
				? TGL(@"Notification.JoinedChannelByRequestYou",
					  @"Your request to join the channel was approved")
				: TGL(@"Notification.JoinedGroupByRequestYou",
					  @"Your request to join the group was approved");
		else
			line = [NSString stringWithFormat:TGL(@"Notification.JoinedGroupByRequest",
										@"%@ was accepted to the group chat"),
				  actor];

	} else if ([ctype isEqualToString:@"messageChatUpgradeTo"] ||
		[ctype isEqualToString:@"messageChatUpgradeFrom"]) {
		line = nil;

	} else if ([ctype isEqualToString:@"messageChatOwnerLeft"]) {
		NSString *heir = TGServiceUserName(context,
			[content[@"new_owner_user_id"] longLongValue]);
		line = [NSString stringWithFormat:
				TGL(@"Notification.GroupCreatorChangePending",
					@"%2$@ will become the new main admin in 7 days if %1$@ does not return."),
			actor, heir];

	} else if ([ctype isEqualToString:@"messageChatOwnerChanged"]) {
		line = [NSString stringWithFormat:
				TGL(@"Notification.GroupCreatorChangeApplied",
					@"%@ has transferred ownership of the group to %@."),
			actor,
			TGServiceUserName(context, [content[@"new_owner_user_id"] longLongValue])];

	} else if ([ctype isEqualToString:@"messageChatHasProtectedContentToggled"]) {
		BOOL protectionOn = [content[@"new_has_protected_content"] boolValue];
		if (protectionOn)
			line = mine
				? TGL(@"Notification.CopyProtection.EnabledYou",
					  @"You disabled sharing in this chat")
				: [NSString stringWithFormat:TGL(@"Notification.CopyProtection.Enabled",
											@"%1$@ disabled sharing in this chat"),
					  actor];
		else
			line = mine
				? TGL(@"Notification.CopyProtection.DisabledYou",
					  @"You enabled sharing in this chat")
				: [NSString stringWithFormat:TGL(@"Notification.CopyProtection.Disabled",
											@"%1$@ enabled sharing in this chat"),
					  actor];

	} else if ([ctype isEqualToString:@"messageChatHasProtectedContentDisableRequested"]) {
		line = mine
			? TGL(@"Notification.CopyProtection.RequestYou",
				  @"You suggested enabling sharing in this chat")
			: [NSString stringWithFormat:TGL(@"Notification.CopyProtection.Request",
										@"%@ would like to enable sharing in this chat"),
				  actor];

	} else if ([ctype isEqualToString:@"messageChatAddedToCommunity"]) {
		NSString *title = TGServiceTitleForChat(context,
			[content[@"community_id"] longLongValue]);
		if (title.length) {
			if (isChannel)
				line = [NSString stringWithFormat:TGL(@"Notification.CommunityAddedChannel",
											@"The channel was added to %1$@ community"),
					  title];
			else if (mine)
				line = [NSString stringWithFormat:TGL(@"Notification.CommunityAddedGroupYou",
											@"You added this group to %1$@ community"),
					  title];
			else
				line = [NSString stringWithFormat:TGL(@"Notification.CommunityAddedGroup",
											@"%1$@ added this group to %2$@ community"),
					  actor, title];
		}

	} else if ([ctype isEqualToString:@"messageChatRemovedFromCommunity"]) {
		if (isChannel)
			line = TGL(@"Notification.CommunityRemovedChannel",
				@"The channel was removed from a community");
		else
			line = mine
				? TGL(@"Notification.CommunityRemovedGroupYou",
					  @"You removed this group from a community")
				: [NSString stringWithFormat:TGL(@"Notification.CommunityRemovedGroup",
											@"%1$@ removed this group from a community"),
					  actor];

	} else if ([ctype isEqualToString:@"messagePinMessage"]) {
		line = [NSString stringWithFormat:TGL(@"Message.PinnedGenericMessage",
									@"%@ pinned a message"),
			actor];
		NSNumber *target = content[@"message_id"];
		if ([target isKindOfClass:NSNumber.class] && [target longLongValue])
			pinnedId = target;

	} else if ([ctype isEqualToString:@"messageScreenshotTaken"]) {
		if (isSecretChat && context.secretServiceText)
			line = context.secretServiceText(m);
		if (!line.length)
			line = mine
				? TGL(@"Notification.SecretChatMessageScreenshotSelf",
					  @"You took a screenshot!")
				: [NSString stringWithFormat:TGL(@"Notification.SecretChatMessageScreenshot",
											@"%@ took a screenshot!"),
					  actor];

	} else if ([ctype isEqualToString:@"messageChatSetTheme"]) {
		NSString *theme = content[@"theme_name"];
		if (!theme.length)
			line = mine
				? TGL(@"Notification.YouDisabledTheme", @"You disabled chat theme")
				: [NSString stringWithFormat:TGL(@"Notification.DisabledTheme",
											@"%@ disabled chat theme"),
					  actor];
		else
			line = mine
				? [NSString stringWithFormat:TGL(@"Notification.YouChangedTheme",
											@"You changed chat theme to %@"),
					  theme]
				: [NSString stringWithFormat:TGL(@"Notification.ChangedTheme",
											@"%@ changed chat theme to %@"),
					  actor, theme];

	} else if ([ctype isEqualToString:@"messageChatSetBackground"]) {
		if (isChannel)
			line = TGL(@"Notification.ChannelChangedWallpaper", @"Channel set a new wallpaper");
		else if (mine)
			line = TGL(@"Notification.YouChangedWallpaper",
				@"You set a new wallpaper for this chat");
		else
			line = [NSString stringWithFormat:TGL(@"Notification.ChangedWallpaper",
										@"%@ set a new wallpaper for this chat"),
				actor];
		NSNumber *oldBackground = content[@"old_background_message_id"];
		if ([oldBackground isKindOfClass:NSNumber.class] && [oldBackground longLongValue])
			oldBackgroundMessageId = oldBackground;
		onlyForSelf = @([content[@"only_for_self"] boolValue]);
		NSDictionary *chatBackground = [content[@"background"] isKindOfClass:NSDictionary.class]
			? content[@"background"]
			: nil;
		NSDictionary *newBackground = [chatBackground[@"background"] isKindOfClass:NSDictionary.class]
			? chatBackground[@"background"]
			: nil;
		if ([newBackground[@"id"] isKindOfClass:NSNumber.class])
			backgroundId = newBackground[@"id"];

	} else if ([ctype isEqualToString:@"messageChatSetMessageAutoDeleteTime"]) {
		if (isSecretChat && context.secretServiceText)
			line = context.secretServiceText(m);
		NSInteger seconds = [content[@"message_auto_delete_time"] integerValue];
		int64_t fromUser = [content[@"from_user_id"] longLongValue];
		if (!line.length && isChannel) {
			line = seconds > 0
				? [NSString stringWithFormat:
						  TGL(@"Conversation.AutoremoveTimerSetChannel",
							  @"Messages in this channel will be automatically deleted after %@"),
					  TGServiceTimeWords(seconds)]
				: TGL(@"Conversation.AutoremoveTimerRemovedChannel",
					  @"Messages in this channel will no longer be automatically deleted");
		} else if (!line.length && seconds > 0) {
			line = mine
				? [NSString stringWithFormat:
						  TGL(@"Conversation.AutoremoveTimerSetUserYou",
							  @"You set messages to automatically delete after %@"),
					  TGServiceTimeWords(seconds)]
				: [NSString stringWithFormat:
						  TGL(@"Conversation.AutoremoveTimerSetUser",
							  @"%@ set messages to automatically delete after %@"),
					  fromUser ? TGServiceUserName(context, fromUser) : actor,
					  TGServiceTimeWords(seconds)];
		} else if (!line.length) {
			line = mine
				? TGL(@"Conversation.AutoremoveTimerRemovedUserYou",
					  @"You disabled the auto-delete timer")
				: [NSString stringWithFormat:
						  TGL(@"Conversation.AutoremoveTimerRemovedUser",
							  @"%@ disabled the auto-delete timer"),
					  fromUser ? TGServiceUserName(context, fromUser) : actor];
		}

	} else if ([ctype isEqualToString:@"messageChatBoost"]) {
		NSInteger boosts = [content[@"boost_count"] integerValue];
		if (boosts > 1) {
			NSString *timesStr = TGLPlural(@"Notification.Boost.Times", boosts,
				@"%ld time", @"%ld times");
			line = mine
				? [NSString stringWithFormat:TGL(@"Notification.Boost.MultipleYou",
											@"You boosted the group %@"),
					  timesStr]
				: [NSString stringWithFormat:TGL(@"Notification.Boost.Multiple",
											@"%@ boosted the group %@"),
					  actor, timesStr];
		} else
			line = mine
				? TGL(@"Notification.Boost.SingleYou", @"You boosted the group")
				: [NSString stringWithFormat:TGL(@"Notification.Boost.Single",
											@"%@ boosted the group"),
					  actor];

	} else if ([ctype isEqualToString:@"messageVideoChatStarted"]) {
		line = isChannel
			? TGL(@"Notification.LiveStreamStarted", @"Live stream started")
			: (named
					  ? [NSString stringWithFormat:TGL(@"Notification.VoiceChatStarted",
												  @"%@ started a voice chat"),
							actor]
					  : TGL(@"Notification.VoiceChatStartedChannel", @"Voice chat started"));

	} else if ([ctype isEqualToString:@"messageVideoChatEnded"]) {
		NSString *length = TGServiceClockLength(
			[content[@"duration"] integerValue]);
		if (isChannel)
			line = [NSString stringWithFormat:TGL(@"Notification.LiveStreamEnded",
										@"Live stream ended (%@)"),
				length];
		else if (named)
			line = [NSString stringWithFormat:TGL(@"Notification.VoiceChatEndedGroup",
										@"%@ ended the voice chat (%@)"),
				actor, length];
		else
			line = [NSString stringWithFormat:TGL(@"Notification.VoiceChatEnded",
										@"Voice chat ended (%@)"),
				length];

	} else if ([ctype isEqualToString:@"messageVideoChatScheduled"]) {
		NSString *when = TGServiceDateWords(
			[content[@"start_date"] doubleValue]);
		if (isChannel)
			line = [NSString stringWithFormat:TGL(@"Notification.LiveStreamScheduled",
										@"Live stream scheduled for %@"),
				when];
		else if (named)
			line = [NSString stringWithFormat:TGL(@"Notification.VoiceChatScheduled",
										@"%@ scheduled a voice chat for %@"),
				actor, when];
		else
			line = [NSString stringWithFormat:TGL(@"Notification.VoiceChatScheduledChannel",
										@"Voice chat scheduled for %@"),
				when];

	} else if ([ctype isEqualToString:@"messageInviteVideoChatParticipants"]) {
		NSArray *invited = content[@"user_ids"];
		BOOL invitedMe = NO;
		for (NSNumber *uid in invited)
			if ([uid longLongValue] == context.myUserId)
				invitedMe = YES;
		line = invitedMe
			? [NSString stringWithFormat:TGL(@"Notification.VoiceChatInvitationForYou",
										@"%@ invited you to the voice chat"),
				  actor]
			: [NSString stringWithFormat:TGL(@"Notification.VoiceChatInvitation",
										@"%@ invited %@ to the voice chat"),
				  actor, TGServiceUserList(context, invited)];

	} else if ([ctype isEqualToString:@"messageContactRegistered"]) {
		line = [NSString stringWithFormat:TGL(@"Notification.Joined", @"%@ joined Telegram"),
			actor];

	} else if ([ctype isEqualToString:@"messageCustomServiceAction"]) {
		line = content[@"text"];

	} else if ([ctype isEqualToString:@"messageGameScore"]) {
		NSInteger score = [content[@"score"] integerValue];
		line = mine
			? [NSString stringWithFormat:TGL(@"Notification.GameScoreYou", @"You scored %ld"),
				  (long)score]
			: [NSString stringWithFormat:TGL(@"Notification.GameScore", @"%@ scored %ld"),
				  actor, (long)score];

	} else if ([ctype isEqualToString:@"messageManagedBotCreated"]) {
		line = [NSString stringWithFormat:TGL(@"Notification.ManagedBotCreated",
									@"%@ was added as a business bot"),
			TGServiceUserName(context, [content[@"bot_user_id"] longLongValue])];

	} else if ([ctype isEqualToString:@"messagePaymentSuccessful"] ||
		[ctype isEqualToString:@"messagePaymentSuccessfulBot"]) {
		NSString *amount = TGServiceAmount(content[@"currency"],
			[content[@"total_amount"] longLongValue]);
		NSString *who = [ctype isEqualToString:@"messagePaymentSuccessful"]
			? (TGServiceTitleForChat(context, [content[@"invoice_chat_id"] longLongValue])
					  ?: actor)
			: actor;
		line = [NSString stringWithFormat:
				TGL(@"Notification.PaymentSentNoTitle",
					@"You have just successfully transferred %@ to %@"),
			amount, who];

	} else if ([ctype isEqualToString:@"messagePaymentRefunded"]) {
		line = [NSString stringWithFormat:TGL(@"Notification.PaidMessageRefund",
									@"%@ refunded you %@"),
			TGServiceSenderName(context, content[@"owner_id"]),
			TGServiceAmount(content[@"currency"],
				[content[@"total_amount"] longLongValue])];

	} else if ([ctype isEqualToString:@"messagePaidMessagesRefunded"]) {
		line = [NSString stringWithFormat:TGL(@"Notification.PaidMessageRefund",
									@"%@ refunded you %@"),
			actor, TGServiceStars([content[@"star_count"] longLongValue])];

	} else if ([ctype isEqualToString:@"messagePaidMessagePriceChanged"]) {
		long long price = [content[@"paid_message_star_count"] longLongValue];
		line = mine
			? [NSString stringWithFormat:TGL(@"Notification.PaidMessagePriceChangedYou",
										@"You changed price to %1$@ per message"),
				  TGServiceStars(price)]
			: [NSString stringWithFormat:TGL(@"Notification.PaidMessagePriceChanged",
										@"%1$@ changed price to %2$@ per message"),
				  actor, TGServiceStars(price)];

	} else if ([ctype isEqualToString:@"messageDirectMessagePriceChanged"]) {
		if (![content[@"is_enabled"] boolValue])
			line = [NSString stringWithFormat:TGL(@"Notification.ChannelMessageDisabled",
										@"%@ no longer accepts private messages"),
				actor];
		else {
			long long price = [content[@"paid_message_star_count"] longLongValue];
			if (price > 0) {
				NSString *format = TGLPlural(@"Notification.ChannelMessagePriceChangedAndEnabledChannelMessage",
					(NSInteger)price, @"{name} now accepts private messages for %d star",
					@"{name} now accepts private messages for %d stars");
				line = [format stringByReplacingOccurrencesOfString:@"{name}"
									withString:actor];
			} else
				line = [NSString stringWithFormat:
						  TGL(@"Notification.ChannelMessagePriceZeroChangedAndEnabledChannelMessage",
							  @"%@ now accepts private messages"),
					  actor];
		}

	} else if ([ctype isEqualToString:@"messageGiveawayCreated"]) {
		long long stars = [content[@"star_count"] longLongValue];
		if (stars > 0)
			line = isChannel
				? [NSString stringWithFormat:
						  TGL(@"Notification.GiveawayStartedStars",
							  @"%1$@ just started a giveaway of %2$@ Telegram Stars for its followers."
							   "for its followers."),
						  actor, @(stars)]
				: [NSString stringWithFormat:
						  TGL(@"Notification.GiveawayStartedStarsGroup",
							  @"%1$@ just started a giveaway of %2$@ Telegram Stars for its members."
							   "for its members."),
						  actor, @(stars)];
		else
			line = isChannel
				? [NSString stringWithFormat:
						  TGL(@"Notification.GiveawayStarted",
							  @"%@ just started a giveaway of Telegram Premium subscriptions for its followers."
							   "for its followers."),
						  actor]
				: [NSString stringWithFormat:
						  TGL(@"Notification.GiveawayStartedGroup",
							  @"%@ just started a giveaway of Telegram Premium subscriptions for its members."
							   "for its members."),
						  actor];

	} else if ([ctype isEqualToString:@"messageGiveawayCompleted"]) {
		NSInteger winners = [content[@"winner_count"] integerValue];
		NSInteger unclaimed = [content[@"unclaimed_prize_count"] integerValue];
		if (winners < 1)
			line = TGL(@"Notification.GiveawayCompletedNoWinners",
				@"Due to the giveaway terms, no winners could be selected.");
		else if (unclaimed > 0)
			line = [NSString stringWithFormat:
					TGL(@"Notification.GiveawayCompletedPartial",
						@"%@ of the giveaway were selected, %ld prizes went unclaimed."),
				TGServiceCountedWord(winners, @"winner"), (long)unclaimed];
		else
			line = [NSString stringWithFormat:
					TGL(@"Notification.GiveawayCompletedAllClaimed",
						@"%@ of the giveaway were randomly selected by Telegram."),
				TGServiceCountedWord(winners, @"winner")];

	} else if ([ctype isEqualToString:@"messageProximityAlertTriggered"]) {
		NSInteger metres = [content[@"distance"] integerValue];
		NSString *span = metres >= 1000
			? [NSString stringWithFormat:@"%.1f km", metres / 1000.0]
			: [NSString stringWithFormat:@"%ld m", (long)metres];
		line = [NSString stringWithFormat:TGL(@"Notification.ProximityReached",
									@"%@ is now within %@ from %@"),
			TGServiceSenderName(context, content[@"traveler_id"]), span,
			TGServiceSenderName(context, content[@"watcher_id"])];

	} else if ([ctype isEqualToString:@"messageSuggestProfilePhoto"]) {
		line = TGL(@"Notification.SuggestedProfilePhoto", @"Suggested Profile Photo");
		photo = [content[@"photo"] isKindOfClass:NSDictionary.class]
			? content[@"photo"]
			: nil;

	} else if ([ctype isEqualToString:@"messageSuggestBirthdate"]) {
		line = TGL(@"Notification.SuggestBirthdate", @"Suggested Date of Birth");

	} else if ([ctype isEqualToString:@"messagePassportDataSent"]) {
		NSString *recipient = TGServiceTitleForChat(context,
			[m[@"chat_id"] longLongValue]) ?: actor;
		line = [NSString stringWithFormat:TGL(@"Notification.PassportValuesSentMessage",
									@"%1$@ received the following documents: %2$@"),
			recipient, TGServicePassportKinds(content[@"types"])];

	} else if ([ctype isEqualToString:@"messagePassportDataReceived"]) {
		line = nil;

	} else if ([ctype isEqualToString:@"messagePollOptionAdded"] ||
		[ctype isEqualToString:@"messagePollOptionDeleted"]) {
		NSString *option = content[@"text"][@"text"] ?: content[@"text"];
		BOOL added = [ctype isEqualToString:@"messagePollOptionAdded"];
		if ([option isKindOfClass:NSString.class] && [option length])
			line = added
				? [NSString stringWithFormat:TGL(@"Notification.PollAddedOption",
											@"%@ added the poll option \"%@\""),
					  actor, option]
				: [NSString stringWithFormat:TGL(@"Notification.PollDeletedOption",
											@"%@ removed the poll option \"%@\""),
					  actor, option];

	} else if ([ctype isEqualToString:@"messageChecklistTasksDone"]) {
		NSInteger done = [content[@"marked_as_done_task_ids"] count];
		NSInteger undone = [content[@"marked_as_not_done_task_ids"] count];
		if (done)
			line = [NSString stringWithFormat:TGL(@"Notification.TodoMultipleCompleted",
										@"%@ marked %@ as done."),
				actor, TGServiceCountedWord(done, @"task")];
		else if (undone)
			line = [NSString stringWithFormat:TGL(@"Notification.TodoMultipleIncompleted",
										@"%@ marked %@ as undone."),
				actor, TGServiceCountedWord(undone, @"task")];

	} else if ([ctype isEqualToString:@"messageChecklistTasksAdded"]) {
		line = [NSString stringWithFormat:TGL(@"Notification.ChecklistTasksAdded",
									@"%@ added %@ to the checklist"),
			actor, TGServiceCountedWord([content[@"tasks"] count], @"task")];

	} else if ([ctype isEqualToString:@"messageSuggestedPostApproved"]) {
		line = mine ? TGL(@"Chat.PostApproval.Status.UserApproved", @"Your message was approved")
					: TGL(@"Chat.PostApproval.Status.AdminApproved", @"The message was approved");

	} else if ([ctype isEqualToString:@"messageSuggestedPostDeclined"]) {
		NSString *declineComment = [content[@"comment"] isKindOfClass:NSString.class]
			? content[@"comment"]
			: @"";
		NSString *declineBase = mine ? TGL(@"Chat.PostApproval.Status.UserRejected", @"Your message was rejected")
									  : TGL(@"Chat.PostApproval.Status.AdminRejected", @"The message was rejected");
		line = declineComment.length
			? [NSString stringWithFormat:@"%@\n%@", declineBase, declineComment]
			: declineBase;

	} else if ([ctype isEqualToString:@"messageSuggestedPostApprovalFailed"]) {
		NSDictionary *failedPrice = [content[@"price"] isKindOfClass:NSDictionary.class]
			? content[@"price"]
			: nil;
		NSString *failedPriceType = [failedPrice[@"@type"] isKindOfClass:NSString.class]
			? failedPrice[@"@type"]
			: @"";
		NSString *failedAmount = [failedPriceType isEqualToString:@"suggestedPostPriceStar"]
			? TGServiceStars([failedPrice[@"star_count"] longLongValue])
			: [NSString stringWithFormat:@"%.2f TON",
				[failedPrice[@"gram_cent_count"] doubleValue] / 100.0];
		line = mine
			? [NSString stringWithFormat:
				TGL(@"Chat.PostApproval.DetailStatus.UserApprovalFailed",
					@"Your post wasn't approved because you didn't have enough funds to pay %@"),
				failedAmount]
			: [NSString stringWithFormat:
				TGL(@"Chat.PostApproval.DetailStatus.AdminApprovalFailed",
					@"The post wasn't approved because the sender didn't have enough funds to pay %@"),
				failedAmount];

	} else if ([ctype isEqualToString:@"messageSuggestedPostPaid"]) {
		NSString *channelName = TGServiceTitleForChat(context, [m[@"chat_id"] longLongValue])
			?: TGL(@"ChatList.UnnamedChat", @"Chat");
		long long stars = TGPayStars(content[@"star_amount"]);
		NSString *amount = stars > 0
			? TGServiceStars(stars)
			: [NSString stringWithFormat:@"%.2f TON", [content[@"gram_amount"] longLongValue] / 1000000000.0];
		line = [NSString stringWithFormat:
					TGL(@"Chat.PostApproval.DetailStatus.PostedPaid",
						@"%1$@ received %2$@ for publishing this post"),
			channelName, amount];

	} else if ([ctype isEqualToString:@"messageSuggestedPostRefunded"]) {
		NSString *reason = content[@"reason"][@"@type"];
		if ([reason isEqualToString:@"suggestedPostRefundReasonPostDeleted"])
			line = TGL(@"Chat.PostApproval.DetailStatus.FailedDeleted",
				@"Suggested post was refunded because the message was deleted");
		else
			line = TGL(@"Chat.PostApproval.DetailStatus.PaymentRefunded",
				@"Suggested post was refunded because the payment for it was refunded");
	}

	if (!line.length)
		line = TGServiceSharedLine(content, ctype, isChannel ? nil : actor);
	if (!line.length)
		line = TGServiceTopicLine(content, ctype, actor, named);
	if (!line.length)
		line = TGServiceGiftLine(context, content, ctype, actor, mine);
	if (!line.length)
		line = context.botServiceText ? context.botServiceText(m) : nil;
	if (!line.length)
		return nil;

	NSMutableDictionary *out = [NSMutableDictionary dictionaryWithCapacity:3];
	out[@"line"] = line;
	if (photo)
		out[@"photo"] = photo;
	if (pinnedId)
		out[@"pinnedId"] = pinnedId;
	if (oldBackgroundMessageId)
		out[@"oldBackgroundMessageId"] = oldBackgroundMessageId;
	if (onlyForSelf)
		out[@"onlyForSelf"] = onlyForSelf;
	if (backgroundId)
		out[@"backgroundId"] = backgroundId;
	return out;
}

static NSArray *TGReactionChips(TGFlattenContext *context, NSDictionary *m) {
	int64_t chatId = [m[@"chat_id"] longLongValue];
	return context.reactionChips ? context.reactionChips(m[@"interaction_info"], chatId) : @[];
}

static NSDictionary *TGCommentInfo(NSDictionary *m) {
	NSDictionary *interaction = m[@"interaction_info"];
	NSDictionary *replyInfo = [interaction isKindOfClass:NSDictionary.class]
		? interaction[@"reply_info"]
		: nil;
	if (![replyInfo isKindOfClass:NSDictionary.class])
		return nil;

	NSInteger count = [replyInfo[@"reply_count"] integerValue];

	NSMutableArray *repliers = [NSMutableArray array];
	for (NSDictionary *sender in replyInfo[@"recent_replier_ids"]) {
		if (![sender isKindOfClass:NSDictionary.class])
			continue;
		if (![sender[@"@type"] isEqualToString:@"messageSenderUser"])
			continue;
		[repliers addObject:sender[@"user_id"] ?: @0];
	}

	return @{
		@"count" : @(count),
		@"lastMessageId" : replyInfo[@"last_message_id"] ?: @0,
		@"replierIds" : repliers,
	};
}

static NSString *TGEntityKindName(id typeName) {
	NSString *name = [typeName isKindOfClass:NSString.class] ? typeName : @"";
	return [name hasPrefix:@"textEntityType"] ? [name substringFromIndex:14] : name;
}

NSArray *TGFlattenEntities(id raw) {
	if (![raw isKindOfClass:NSArray.class])
		return @[];
	NSMutableArray *out = [NSMutableArray array];
	for (id item in (NSArray *)raw) {
		if (![item isKindOfClass:NSDictionary.class])
			continue;
		NSDictionary *entity = item;
		NSDictionary *type = [entity[@"type"] isKindOfClass:NSDictionary.class]
			? entity[@"type"]
			: nil;
		NSString *kind = TGEntityKindName(type[@"@type"]);
		if (!kind.length)
			continue;
		[out addObject:@{
			@"kind" : kind,
			@"offset" : entity[@"offset"] ?: @0,
			@"length" : entity[@"length"] ?: @0,
			@"url" : [type[@"url"] isKindOfClass:NSString.class]
				? type[@"url"]
				: @"",
			@"userId" : type[@"user_id"] ?: @0,
			@"language" : [type[@"language"] isKindOfClass:NSString.class]
				? type[@"language"]
				: @"",
			@"timestamp" : type[@"media_timestamp"] ?: type[@"unix_time"] ?: @0,
			@"customEmojiId" : @([type[@"custom_emoji_id"] longLongValue]),
		}];
	}
	return out;
}

NSNumber *TGPollQuizCorrectOptionId(id rawCorrectOptionIds) {
	if (![rawCorrectOptionIds isKindOfClass:NSArray.class])
		return @(-1);
	NSArray *ids = rawCorrectOptionIds;
	if (ids.count == 0)
		return @(-1);
	id first = ids[0];
	return [first isKindOfClass:NSNumber.class] ? first : @(-1);
}

NSDictionary *TGFlattenPollFields(NSDictionary *poll, NSDictionary *content) {
	if (![poll isKindOfClass:NSDictionary.class])
		return @{};

	NSArray *rawOptions = [poll[@"options"] isKindOfClass:NSArray.class] ? poll[@"options"] : @[];
	NSMutableArray *options = [NSMutableArray arrayWithCapacity:rawOptions.count];
	for (NSDictionary *option in rawOptions) {
		if (![option isKindOfClass:NSDictionary.class])
			continue;
		id optionText = option[@"text"];
		if ([optionText isKindOfClass:NSDictionary.class])
			optionText = @{@"text" : optionText[@"text"] ?: @""};
		[options addObject:@{
			@"id" : option[@"id"] ?: @"",
			@"text" : optionText ?: @"",
			@"vote_percentage" : option[@"vote_percentage"] ?: @0,
			@"voter_count" : option[@"voter_count"] ?: @0,
			@"is_chosen" : option[@"is_chosen"] ?: @NO,
		}];
	}

	NSDictionary *pollType = [poll[@"type"] isKindOfClass:NSDictionary.class] ? poll[@"type"] : nil;
	BOOL isQuiz = [pollType[@"@type"] isEqualToString:@"pollTypeQuiz"];
	NSNumber *correctOptionId = isQuiz
		? TGPollQuizCorrectOptionId(pollType[@"correct_option_ids"])
		: @(-1);
	id explanation = pollType[@"explanation"];
	NSString *explanationText = [explanation isKindOfClass:NSDictionary.class]
		? (explanation[@"text"] ?: @"")
		: @"";
	NSArray *explanationEntities = [explanation isKindOfClass:NSDictionary.class]
		? TGFlattenEntities(explanation[@"entities"])
		: @[];

	id pollQuestionText = poll[@"question"][@"text"] ?: poll[@"question"];
	id pollQuestion = pollQuestionText ?: TGL(@"Watch.Message.Poll", @"Poll");

	return @{
		@"pollId" : @(TGTDLibInt64(poll[@"id"])),
		@"pollOptions" : options,
		@"pollQuestion" : pollQuestion,
		@"pollTotal" : poll[@"total_voter_count"] ?: @0,
		@"pollClosed" : poll[@"is_closed"] ?: @NO,
		@"pollAnonymous" : poll[@"is_anonymous"] ?: @YES,
		@"pollCanGetVoters" : poll[@"can_get_voters"] ?: @NO,
		@"pollCanAddOption" : content[@"can_add_option"] ?: @NO,
		@"pollIsQuiz" : @(isQuiz),
		@"pollAllowsMultipleAnswers" : poll[@"allows_multiple_answers"] ?: @NO,
		@"pollAllowsRevoting" : poll[@"allows_revoting"] ?: @NO,
		@"pollCorrectOptionId" : correctOptionId,
		@"pollExplanation" : explanationText,
		@"pollExplanationEntities" : explanationEntities,
	};
}

NSString *TGMessageContentKindLabel(NSDictionary *content) {
	NSString *kind = [content[@"@type"] isKindOfClass:NSString.class]
		? content[@"@type"]
		: @"";
	if (TGMediaContentDisappears(content)) {
		NSString *disappearing = TGDisappearingMediaLabel(kind);
		if (disappearing)
			return disappearing;
	}
	if ([kind isEqualToString:@"messagePhoto"])
		return TGL(@"Message.Photo", @"Photo");
	if ([kind isEqualToString:@"messageVideo"])
		return TGL(@"Message.Video", @"Video");
	if ([kind isEqualToString:@"messageAnimation"])
		return TGL(@"Message.Animation", @"GIF");
	if ([kind isEqualToString:@"messageVoiceNote"])
		return TGL(@"Message.Audio", @"Voice message");
	if ([kind isEqualToString:@"messageVideoNote"])
		return TGL(@"Message.VideoMessage", @"Video Message");
	if ([kind isEqualToString:@"messageContact"])
		return TGL(@"Message.Contact", @"Contact");
	if ([kind isEqualToString:@"messagePoll"]) {
		NSDictionary *poll = content[@"poll"];
		id questionText = poll[@"question"][@"text"] ?: poll[@"question"];
		return [questionText isKindOfClass:NSString.class] && [questionText length]
			? questionText
			: TGL(@"Watch.Message.Poll", @"Poll");
	}
	if ([kind isEqualToString:@"messageLocation"] || [kind isEqualToString:@"messageVenue"])
		return TGL(@"Message.Location", @"Location");
	if ([kind isEqualToString:@"messageLiveLocation"])
		return TGL(@"Message.LiveLocation", @"Live location");
	if ([kind isEqualToString:@"messageChecklist"])
		return TGL(@"Attachment.Todo", @"Checklist");
	if ([kind isEqualToString:@"messageCall"])
		return TGServiceCallTitle(content, NO);
	if ([kind isEqualToString:@"messageGroupCall"])
		return TGServiceGroupCallTitle(content, NO);
	if ([kind isEqualToString:@"messageStory"])
		return TGL(@"Message.Story", @"Story");
	if ([kind isEqualToString:@"messageGame"])
		return TGL(@"Message.Game", @"Game");
	if ([kind isEqualToString:@"messageInvoice"]) {
		id productTitle = content[@"product_info"][@"title"] ?: content[@"title"];
		return [productTitle isKindOfClass:NSString.class] && [productTitle length]
			? productTitle
			: TGL(@"Watch.Message.Invoice", @"Invoice");
	}
	if ([kind isEqualToString:@"messageDice"])
		return content[@"emoji"] ?: TGL(@"Message.Dice", @"Dice");
	if ([kind isEqualToString:@"messageRichMessage"])
		return TGL(@"Attachment.Article", @"Article");
	if ([kind isEqualToString:@"messageExpiredPhoto"])
		return TGL(@"Message.ImageExpired", @"Photo has expired");
	if ([kind isEqualToString:@"messageExpiredVideo"])
		return TGL(@"Message.VideoExpired", @"Video has expired");
	if ([kind isEqualToString:@"messageExpiredVoiceNote"])
		return TGL(@"Message.VoiceMessageExpired", @"Expired voice message");
	if ([kind isEqualToString:@"messageExpiredVideoNote"])
		return TGL(@"Message.VideoMessageExpired", @"Expired video message");
	if ([kind isEqualToString:@"messageDocument"] || [kind isEqualToString:@"messageAudio"])
		return TGMediaPreviewName(content) ?: TGL(@"Message.File", @"File");
	if ([kind isEqualToString:@"messageSticker"] ||
		[kind isEqualToString:@"messageAnimatedEmoji"]) {
		NSString *emoji = [kind isEqualToString:@"messageSticker"]
			? content[@"sticker"][@"emoji"]
			: content[@"emoji"];
		if ([emoji isKindOfClass:NSString.class] && emoji.length)
			return [NSString stringWithFormat:TGL(@"Message.StickerText", @"Sticker %@"),
				emoji];
		return TGL(@"Message.Sticker", @"Sticker");
	}
	if ([kind isEqualToString:@"messagePaidMedia"])
		return TGL(@"Message.PaidMedia", @"Paid media");
	if ([kind isEqualToString:@"messageUnsupported"])
		return TGUnsupportedMessageTextValue();
	return nil;
}

NSString *TGMessageKindLabel(NSString *kind) {
	if (![kind isKindOfClass:NSString.class] || !kind.length)
		return nil;
	return TGMessageContentKindLabel(@{@"@type" : kind});
}

static NSString *TGReplyOriginName(TGFlattenContext *context, NSDictionary *origin) {
	NSString *kind = [origin[@"@type"] isKindOfClass:NSString.class]
		? origin[@"@type"]
		: @"";
	if ([kind isEqualToString:@"messageOriginUser"])
		return context.userName
			? context.userName([origin[@"sender_user_id"] longLongValue])
			: nil;
	if ([kind isEqualToString:@"messageOriginHiddenUser"])
		return [origin[@"sender_name"] isKindOfClass:NSString.class]
			? origin[@"sender_name"]
			: nil;
	if ([kind isEqualToString:@"messageOriginChannel"] ||
		[kind isEqualToString:@"messageOriginChat"]) {
		NSString *signature = origin[@"author_signature"];
		return [signature isKindOfClass:NSString.class] && signature.length
			? signature
			: nil;
	}
	return nil;
}

static NSString *TGRichBlockPlainText(NSDictionary *block) {
	NSString *text = block[@"text"];
	if ([text isKindOfClass:NSString.class] && text.length)
		return text;
	NSArray *nested = block[@"blocks"];
	if (![nested isKindOfClass:NSArray.class])
		return @"";
	NSMutableString *joined = [NSMutableString string];
	for (NSDictionary *inner in nested) {
		if (![inner isKindOfClass:NSDictionary.class])
			continue;
		NSString *innerText = TGRichBlockPlainText(inner);
		if (innerText.length) {
			if (joined.length)
				[joined appendString:@" "];
			[joined appendString:innerText];
		}
	}
	return joined;
}

static NSDictionary *TGRichMessageSummary(NSArray *blocks) {
	NSString *kicker = nil, *title = nil, *subtitle = nil;
	NSMutableString *snippet = [NSMutableString string];
	NSNumber *coverFileId = nil, *coverW = nil, *coverH = nil;

	for (NSDictionary *block in blocks) {
		if (![block isKindOfClass:NSDictionary.class])
			continue;
		NSString *kind = block[@"kind"];

		if (!coverFileId && ([kind isEqualToString:@"photo"] || [kind isEqualToString:@"cover"])) {
			NSNumber *fileId = block[@"photoFileId"];
			if ([fileId isKindOfClass:NSNumber.class] && fileId.longLongValue != 0) {
				coverFileId = fileId;
				coverW = block[@"width"];
				coverH = block[@"height"];
			}
			for (NSDictionary *nested in block[@"blocks"]) {
				NSNumber *nestedFileId = nested[@"photoFileId"];
				if (!coverFileId && [nestedFileId isKindOfClass:NSNumber.class] &&
					nestedFileId.longLongValue != 0) {
					coverFileId = nestedFileId;
					coverW = nested[@"width"];
					coverH = nested[@"height"];
				}
			}
			continue;
		}
		if (![kicker length] && [kind isEqualToString:@"kicker"]) {
			kicker = TGRichBlockPlainText(block);
			continue;
		}
		if (![title length] && [kind isEqualToString:@"title"]) {
			title = TGRichBlockPlainText(block);
			continue;
		}
		if (![subtitle length] && [kind isEqualToString:@"subtitle"]) {
			subtitle = TGRichBlockPlainText(block);
			continue;
		}
		if (snippet.length < 240 &&
			([kind isEqualToString:@"paragraph"] || [kind isEqualToString:@"header"] ||
				[kind isEqualToString:@"subheader"] || [kind isEqualToString:@"blockQuote"] ||
				[kind isEqualToString:@"pullQuote"] || [kind isEqualToString:@"footer"])) {
			NSString *text = TGRichBlockPlainText(block);
			if (text.length) {
				if (snippet.length)
					[snippet appendString:@"  "];
				[snippet appendString:text];
			}
		}
	}

	return @{
		@"kicker" : kicker ?: @"",
		@"title" : title ?: @"",
		@"subtitle" : subtitle ?: @"",
		@"snippet" : snippet,
		@"coverFileId" : coverFileId ?: (id)[NSNull null],
		@"coverW" : coverW ?: (id)[NSNull null],
		@"coverH" : coverH ?: (id)[NSNull null],
	};
}

NSString *TGMessagePreview(NSDictionary *message, TGFlattenContext *context) {
	NSDictionary *content = message[@"content"];
	NSString *ctype = content[@"@type"];

	NSDictionary *previewRestrictionInfo = [message[@"restriction_info"] isKindOfClass:NSDictionary.class]
		? message[@"restriction_info"]
		: nil;
	NSString *previewRestrictionReason = [previewRestrictionInfo[@"restriction_reason"] isKindOfClass:NSString.class]
		? previewRestrictionInfo[@"restriction_reason"]
		: @"";
	if (previewRestrictionReason.length)
		return previewRestrictionReason;

	if ([ctype isEqualToString:@"messageText"])
		return content[@"text"][@"text"] ?: @"";

	NSString *disappearingLabel = TGMediaContentDisappears(content)
		? TGDisappearingMediaLabel(ctype)
		: nil;
	if (disappearingLabel)
		return disappearingLabel;

	NSString *caption = content[@"caption"][@"text"];
	if ([caption isKindOfClass:NSString.class] && caption.length)
		return caption;

	if ([ctype isEqualToString:@"messagePhoto"])
		return TGL(@"Message.Photo", @"Photo");
	if ([ctype isEqualToString:@"messageVideo"])
		return TGL(@"Message.Video", @"Video");
	if ([ctype isEqualToString:@"messageVoiceNote"])
		return TGL(@"Message.Audio", @"Voice message");
	if ([ctype isEqualToString:@"messageVideoNote"])
		return TGL(@"Message.VideoMessage", @"Video Message");
	if ([ctype isEqualToString:@"messageSticker"])
		return TGL(@"Message.Sticker", @"Sticker");
	if ([ctype isEqualToString:@"messageDocument"]) {
		NSString *name = content[@"document"][@"file_name"];
		return ([name isKindOfClass:NSString.class] && name.length)
			? name
			: TGL(@"Message.File", @"File");
	}
	if ([ctype isEqualToString:@"messageAudio"]) {
		NSString *title = content[@"audio"][@"title"];
		return ([title isKindOfClass:NSString.class] && title.length)
			? title
			: TGL(@"SharedMedia.CategoryOther", @"Audio");
	}
	if ([ctype isEqualToString:@"messageAnimation"])
		return TGL(@"Message.Animation", @"GIF");
	if ([ctype isEqualToString:@"messagePaidMedia"])
		return TGL(@"Message.PaidMedia", @"Paid media");
	if ([ctype isEqualToString:@"messageUnsupported"])
		return TGUnsupportedMessageTextValue();
	if ([ctype isEqualToString:@"messageAnimatedEmoji"])
		return content[@"emoji"] ?: TGL(@"Message.Emoji", @"Emoji");
	if ([ctype isEqualToString:@"messageContact"])
		return TGL(@"Message.Contact", @"Contact");
	if ([ctype isEqualToString:@"messageVenue"])
		return TGL(@"Message.Location", @"Location");
	if ([ctype isEqualToString:@"messageLocation"])
		return TGL(@"Message.Location", @"Location");
	if ([ctype isEqualToString:@"messageLiveLocation"])
		return TGL(@"Message.LiveLocation", @"Live location");
	if ([ctype isEqualToString:@"messageCall"])
		return TGServiceCallLine(content, [message[@"is_outgoing"] boolValue]);
	if ([ctype isEqualToString:@"messageGroupCall"])
		return TGServiceGroupCallLine(content, [message[@"is_outgoing"] boolValue]);
	if ([ctype isEqualToString:@"messagePoll"]) {
		NSDictionary *poll = content[@"poll"];
		id questionText = poll[@"question"][@"text"] ?: poll[@"question"];
		return [questionText isKindOfClass:NSString.class] && [questionText length]
			? questionText
			: TGL(@"Watch.Message.Poll", @"Poll");
	}
	if ([ctype isEqualToString:@"messageRichMessage"])
		return TGL(@"Attachment.Article", @"Article");
	if ([ctype isEqualToString:@"messageDice"]) {
		NSString *emoji = content[@"emoji"];
		return [emoji isKindOfClass:NSString.class] && emoji.length
			? emoji
			: TGL(@"Message.Dice", @"Dice");
	}
	if ([ctype isEqualToString:@"messageGame"]) {
		NSString *title = content[@"game"][@"title"];
		return [title isKindOfClass:NSString.class] && title.length
			? title
			: TGL(@"Message.Game", @"Game");
	}
	if ([ctype isEqualToString:@"messageInvoice"]) {
		id productTitle = content[@"product_info"][@"title"] ?: content[@"title"];
		return [productTitle isKindOfClass:NSString.class] && [productTitle length]
			? productTitle
			: TGL(@"Watch.Message.Invoice", @"Invoice");
	}
	if ([ctype isEqualToString:@"messageStory"])
		return TGL(@"Message.Story", @"Story");
	if ([ctype isEqualToString:@"messagePaidMedia"])
		return TGL(@"Message.PaidMedia", @"Paid media");
	if ([ctype isEqualToString:@"messageChecklist"]) {
		NSString *title = content[@"list"][@"title"][@"text"];
		return [title isKindOfClass:NSString.class] && title.length
			? title
			: TGL(@"Attachment.Todo", @"Checklist");
	}
	if ([ctype isEqualToString:@"messageExpiredPhoto"] ||
		[ctype isEqualToString:@"messageExpiredVideo"] ||
		[ctype isEqualToString:@"messageExpiredVoiceNote"] ||
		[ctype isEqualToString:@"messageExpiredVideoNote"])
		return [[TGClient shared] placeholderTextForContentKind:ctype];

	int64_t previewActorId = TGServiceSenderId(message[@"sender_id"]);
	NSString *previewActor = previewActorId
		? (context.userName ? context.userName(previewActorId) : nil)
		: nil;
	if (!previewActor.length)
		previewActor = TGServiceTitleForChat(context, previewActorId);
	NSDictionary *previewChat = context.chatsById[message[@"chat_id"]];
	NSDictionary *action = TGServiceAction(context, message, content, ctype,
		previewActor.length ? previewActor : TGL(@"Premium.GiftedTitle.Someone", @"Someone"),
		previewActor.length > 0, [message[@"is_outgoing"] boolValue],
		[previewChat[@"isChannel"] boolValue], [previewChat[@"isSecretChat"] boolValue]);
	if (action[@"line"])
		return action[@"line"];

	return ctype.length ? TGUnsupportedMessageTextValue() : @"";
}

NSDictionary *TGFlattenMessage(NSDictionary *m, TGFlattenContext *context) {
	NSDictionary *content = m[@"content"];
	NSString *ctype = content[@"@type"];
	NSDictionary *restrictionInfo = [m[@"restriction_info"] isKindOfClass:NSDictionary.class]
		? m[@"restriction_info"]
		: nil;
	NSString *restrictionReason = [restrictionInfo[@"restriction_reason"] isKindOfClass:NSString.class]
		? restrictionInfo[@"restriction_reason"]
		: @"";
	NSDictionary *mainFile = nil;
	NSString *docMime = nil;
	BOOL supportsStreaming = NO;
	NSDictionary *contactInfo = nil;
	NSString *venueTitle = nil, *venueAddress = nil;
	NSInteger livePeriod = 0, liveExpiresIn = 0, liveHeading = 0;
	NSTimeInterval liveExpiresAt = 0;
	NSNumber *photoFileId = nil;
	NSNumber *docFileId = nil;
	NSString *docName = nil;
	NSString *extra = nil;
	NSNumber *latitude = nil, *longitude = nil;
	NSNumber *duration = nil;
	NSData *waveform = nil;
	NSDictionary *transcript = nil;
	BOOL isService = NO;
	BOOL invoicePaid = NO;
	NSNumber *invoiceReceiptMessageId = @0;
	BOOL paidMediaUnlocked = NO;
	NSNumber *paidMediaStarCount = @0;
	BOOL serviceNamesAuthor = NO;
	NSString *callState = nil;
	NSString *callTitle = nil;
	NSInteger callSeconds = 0;
	BOOL isVideoCall = NO;
	NSString *audioTitle = nil, *audioPerformer = nil;
	NSNumber *albumCoverId = nil;
	NSNumber *audioSize = nil;
	BOOL audioIsLocal = NO;
	NSNumber *photoW = nil, *photoH = nil;
	NSArray *photoSizes = nil;
	NSDictionary *minithumb = nil;
	int64_t stickerSetId = 0;
	NSArray *richBlocks = nil;
	NSString *richKicker = nil, *richTitle = nil, *richSubtitle = nil, *richSnippet = nil;
	NSNumber *richCoverFileId = nil, *richCoverW = nil, *richCoverH = nil;
	BOOL richIsFull = YES, richIsRtl = NO;

	int64_t actorId = TGServiceSenderId(m[@"sender_id"]);
	NSString *knownActor = actorId
		? (context.userName ? context.userName(actorId) : nil)
		: nil;
	if (!knownActor.length)
		knownActor = TGServiceTitleForChat(context, actorId);
	BOOL namedActor = knownActor.length > 0;
	NSString *actorName = namedActor ? knownActor : @"Someone";

	NSDictionary *chatInfo = context.chatsById[m[@"chat_id"]];
	BOOL isChannelChat = [chatInfo[@"isChannel"] boolValue];
	BOOL isSecretChat = [chatInfo[@"isSecretChat"] boolValue];
	NSNumber *pinnedTargetId = nil;
	NSNumber *oldBackgroundMessageIdTarget = nil;
	NSNumber *onlyForSelfTarget = nil;
	NSNumber *backgroundIdTarget = nil;

	NSDictionary *serviceAction = TGServiceAction(context, m, content, ctype, actorName,
		namedActor, [m[@"is_outgoing"] boolValue], isChannelChat, isSecretChat);

	if (serviceAction) {
		extra = serviceAction[@"line"];
		isService = YES;
		serviceNamesAuthor = YES;
		pinnedTargetId = serviceAction[@"pinnedId"];
		oldBackgroundMessageIdTarget = serviceAction[@"oldBackgroundMessageId"];
		onlyForSelfTarget = serviceAction[@"onlyForSelf"];
		backgroundIdTarget = serviceAction[@"backgroundId"];

		NSDictionary *servicePhoto = serviceAction[@"photo"];
		NSArray *serviceSizes = servicePhoto[@"sizes"];
		if ([serviceSizes isKindOfClass:NSArray.class] && serviceSizes.count) {
			photoFileId = [serviceSizes lastObject][@"photo"][@"id"];
			photoW = [serviceSizes lastObject][@"width"];
			photoH = [serviceSizes lastObject][@"height"];
			photoSizes = TGPhotoSizeList(serviceSizes);
			minithumb = servicePhoto[@"minithumbnail"];
		}

	} else if ([ctype isEqualToString:@"messagePhoto"]) {
		NSArray *sizes = content[@"photo"][@"sizes"];
		if (sizes.count) {
			photoFileId = [sizes lastObject][@"photo"][@"id"];
			photoW = [sizes lastObject][@"width"];
			photoH = [sizes lastObject][@"height"];
			photoSizes = TGPhotoSizeList(sizes);
		}
		minithumb = content[@"photo"][@"minithumbnail"];

	} else if ([ctype isEqualToString:@"messageVideo"]) {
		photoFileId = content[@"video"][@"thumbnail"][@"file"][@"id"];
		docFileId = content[@"video"][@"video"][@"id"];
		docName = content[@"video"][@"file_name"];
		photoW = content[@"video"][@"width"];
		photoH = content[@"video"][@"height"];
		duration = content[@"video"][@"duration"];
		minithumb = content[@"video"][@"minithumbnail"];
		mainFile = content[@"video"][@"video"];
		docMime = content[@"video"][@"mime_type"];
		supportsStreaming = [content[@"video"][@"supports_streaming"] boolValue];

	} else if ([ctype isEqualToString:@"messageVideoNote"]) {
		photoFileId = content[@"video_note"][@"thumbnail"][@"file"][@"id"];
		docFileId = content[@"video_note"][@"video"][@"id"];
		duration = content[@"video_note"][@"duration"];
		minithumb = content[@"video_note"][@"minithumbnail"];
		transcript = TGTrTranscript(content[@"video_note"][@"speech_recognition_result"]);

	} else if ([ctype isEqualToString:@"messageAnimation"]) {
		photoFileId = content[@"animation"][@"thumbnail"][@"file"][@"id"];
		docFileId = content[@"animation"][@"animation"][@"id"];
		docName = content[@"animation"][@"file_name"];
		photoW = content[@"animation"][@"width"];
		photoH = content[@"animation"][@"height"];
		minithumb = content[@"animation"][@"minithumbnail"];
		duration = content[@"animation"][@"duration"];
		mainFile = content[@"animation"][@"animation"];
		docMime = content[@"animation"][@"mime_type"];

	} else if ([ctype isEqualToString:@"messageSticker"] ||
		[ctype isEqualToString:@"messageAnimatedEmoji"]) {
		NSDictionary *sticker = [ctype isEqualToString:@"messageSticker"]
			? content[@"sticker"]
			: content[@"animated_emoji"][@"sticker"];
		NSString *format = sticker[@"format"][@"@type"];

		if ([format isEqualToString:@"stickerFormatTgs"]) {
			docFileId = sticker[@"sticker"][@"id"];
			photoFileId = sticker[@"thumbnail"][@"file"][@"id"];
			docName = @"tgs";
		} else if ([format isEqualToString:@"stickerFormatWebp"]) {
			photoFileId = sticker[@"sticker"][@"id"];
		} else {
			photoFileId = sticker[@"thumbnail"][@"file"][@"id"];
		}

		photoW = sticker[@"width"];
		photoH = sticker[@"height"];
		stickerSetId = [sticker[@"set_id"] longLongValue];

		extra = content[@"emoji"] ?: sticker[@"emoji"];

	} else if ([ctype isEqualToString:@"messageDocument"]) {
		photoFileId = content[@"document"][@"thumbnail"][@"file"][@"id"];
		docFileId = content[@"document"][@"document"][@"id"];
		docName = content[@"document"][@"file_name"];
		mainFile = content[@"document"][@"document"];
		docMime = content[@"document"][@"mime_type"];
		minithumb = content[@"document"][@"minithumbnail"];
		extra = docName.length ? docName : @"Document";

	} else if ([ctype isEqualToString:@"messageVoiceNote"]) {
		docFileId = content[@"voice_note"][@"voice"][@"id"];
		mainFile = content[@"voice_note"][@"voice"];
		duration = content[@"voice_note"][@"duration"];

		waveform = TGCliBase64(content[@"voice_note"][@"waveform"]);
		transcript = TGTrTranscript(content[@"voice_note"][@"speech_recognition_result"]);
		extra = @"";

	} else if ([ctype isEqualToString:@"messageAudio"]) {
		docFileId = content[@"audio"][@"audio"][@"id"];
		docName = content[@"audio"][@"file_name"];
		mainFile = content[@"audio"][@"audio"];
		docMime = content[@"audio"][@"mime_type"];
		albumCoverId = content[@"audio"][@"album_cover_thumbnail"][@"file"][@"id"];
		if (![albumCoverId isKindOfClass:NSNumber.class])
			albumCoverId = nil;
		duration = content[@"audio"][@"duration"];
		NSNumber *rawSize = content[@"audio"][@"audio"][@"size"];
		if (![rawSize isKindOfClass:NSNumber.class])
			rawSize = content[@"audio"][@"audio"][@"expected_size"];
		audioSize = [rawSize isKindOfClass:NSNumber.class] ? rawSize : nil;
		audioIsLocal = [content[@"audio"][@"audio"][@"local"]
							   [@"is_downloading_completed"] boolValue];
		NSString *title = content[@"audio"][@"title"];
		NSString *performer = content[@"audio"][@"performer"];
		audioTitle = [title isKindOfClass:NSString.class] ? title : nil;
		audioPerformer = [performer isKindOfClass:NSString.class] ? performer : nil;
		NSString *shownTitle = audioTitle.length
			? audioTitle
			: (docName.length ? docName.lastPathComponent
							  : (context.localizedFallback
										? context.localizedFallback(@"SharedMedia.CategoryOther", @"Audio")
										: @"Audio"));
		NSInteger seconds = [duration integerValue];
		NSMutableString *lines = [NSMutableString stringWithString:shownTitle];
		if (audioPerformer.length)
			[lines appendFormat:@"\n%@", audioPerformer];
		if (seconds > 0)
			[lines appendFormat:@"%@%@", audioPerformer.length ? @", " : @"\n",
				TGDurationText(seconds)];
		extra = lines;

	} else if ([ctype isEqualToString:@"messageContact"]) {
		NSDictionary *c = content[@"contact"];
		NSString *name = [[NSString stringWithFormat:@"%@ %@",
			c[@"first_name"] ?: @"", c[@"last_name"] ?: @""]
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		extra = [NSString stringWithFormat:@"%@\n%@", name, c[@"phone_number"] ?: @""];
		contactInfo = [c isKindOfClass:NSDictionary.class] ? c : nil;

	} else if ([ctype isEqualToString:@"messageVenue"]) {
		NSDictionary *v = content[@"venue"];
		venueTitle = [v[@"title"] isKindOfClass:NSString.class] ? v[@"title"] : @"";
		venueAddress = [v[@"address"] isKindOfClass:NSString.class] ? v[@"address"] : @"";
		extra = [NSString stringWithFormat:@"%@\n%@", venueTitle, venueAddress];
		latitude = v[@"location"][@"latitude"];
		longitude = v[@"location"][@"longitude"];

	} else if ([ctype isEqualToString:@"messageCall"]) {
		NSString *reason = content[@"discard_reason"][@"@type"];
		BOOL declined = [reason isEqualToString:@"callDiscardReasonDeclined"];
		BOOL missed = [reason isEqualToString:@"callDiscardReasonMissed"] || declined;

		extra = TGServiceCallLine(content, [m[@"is_outgoing"] boolValue]);
		callTitle = TGServiceCallTitle(content, [m[@"is_outgoing"] boolValue]);
		callSeconds = missed ? 0 : [content[@"duration"] integerValue];
		callState = declined ? @"declined" : (missed ? @"missed" : @"answered");
		isVideoCall = [content[@"is_video"] boolValue];
		isService = NO;

	} else if ([ctype isEqualToString:@"messageGroupCall"]) {
		extra = TGServiceGroupCallLine(content, [m[@"is_outgoing"] boolValue]);
		callTitle = TGServiceGroupCallTitle(content, [m[@"is_outgoing"] boolValue]);
		callSeconds = [content[@"was_missed"] boolValue] || [content[@"is_active"] boolValue]
			? 0
			: [content[@"duration"] integerValue];
		callState = [content[@"was_missed"] boolValue] ? @"missed" : @"answered";
		isService = NO;

	} else if ([ctype isEqualToString:@"messageDice"]) {
		NSDictionary *finalState = content[@"final_state"];
		NSString *finalStateType = finalState[@"@type"];
		NSDictionary *diceSticker = nil;
		if ([finalStateType isEqualToString:@"diceStickersRegular"])
			diceSticker = finalState[@"sticker"];
		else if ([finalStateType isEqualToString:@"diceStickersSlotMachine"])
			diceSticker = finalState[@"center_reel"];
		if (diceSticker) {
			NSString *format = diceSticker[@"format"][@"@type"];
			if ([format isEqualToString:@"stickerFormatTgs"]) {
				docFileId = diceSticker[@"sticker"][@"id"];
				photoFileId = diceSticker[@"thumbnail"][@"file"][@"id"];
				docName = @"tgs";
			} else if ([format isEqualToString:@"stickerFormatWebp"]) {
				photoFileId = diceSticker[@"sticker"][@"id"];
			} else {
				photoFileId = diceSticker[@"thumbnail"][@"file"][@"id"];
			}
			photoW = diceSticker[@"width"];
			photoH = diceSticker[@"height"];
			stickerSetId = [diceSticker[@"set_id"] longLongValue];
		}
		extra = [NSString stringWithFormat:@"%@  %@",
			content[@"emoji"] ?: TGL(@"Message.Dice", @"Dice"), content[@"value"] ?: @""];

	} else if ([ctype isEqualToString:@"messageGame"]) {
		extra = [NSString stringWithFormat:TGL(@"Message.GameWithTitle", @"Game: %@"),
			content[@"game"][@"title"] ?: @""];

	} else if ([ctype isEqualToString:@"messageUnsupported"]) {
		extra = TGUnsupportedMessageTextValue();
		isService = NO;

	} else if ([ctype isEqualToString:@"messageExpiredPhoto"] ||
		[ctype isEqualToString:@"messageExpiredVideo"] ||
		[ctype isEqualToString:@"messageExpiredVoiceNote"] ||
		[ctype isEqualToString:@"messageExpiredVideoNote"]) {
		extra = [[TGClient shared] placeholderTextForContentKind:ctype];
		isService = NO;

	} else if ([ctype isEqualToString:@"messagePoll"]) {
		NSDictionary *poll = content[@"poll"];
		id questionText = poll[@"question"][@"text"] ?: poll[@"question"];
		id question = questionText ?: TGL(@"Watch.Message.Poll", @"Poll");
		NSMutableString *lines = [NSMutableString stringWithFormat:@"%@\n", question];
		NSInteger total = [poll[@"total_voter_count"] integerValue];
		for (NSDictionary *option in poll[@"options"]) {
			id rawOptionText = option[@"text"][@"text"] ?: option[@"text"];
			id optionText = rawOptionText ?: @"";
			[lines appendFormat:@"%@  %@  %ld%%\n",
				[option[@"is_chosen"] boolValue] ? @"◉" : @"○",
				optionText,
				(long)[option[@"vote_percentage"] integerValue]];
		}
		[lines appendString:TGLPlural(@"MessagePoll.VotedCount", total, @"%ld voted", @"%ld voted")];
		extra = lines;
		isService = NO;

	} else if ([ctype isEqualToString:@"messageLocation"]) {
		NSDictionary *loc = content[@"location"];
		latitude = loc[@"latitude"];
		longitude = loc[@"longitude"];

	} else if ([ctype isEqualToString:@"messageLiveLocation"]) {
		NSDictionary *live = content[@"location"];
		NSDictionary *loc = [live[@"location"] isKindOfClass:NSDictionary.class]
			? live[@"location"]
			: live;
		extra = TGL(@"Message.LiveLocation", @"Live location");
		latitude = loc[@"latitude"];
		longitude = loc[@"longitude"];
		livePeriod = [live[@"live_period"] integerValue];
		liveHeading = [live[@"heading"] integerValue];
		liveExpiresIn = [content[@"expires_in"] integerValue];
		liveExpiresAt = TGDestructDeadlineFromRemaining(liveExpiresIn,
			[NSDate timeIntervalSinceReferenceDate]);

	} else if ([ctype isEqualToString:@"messageInvoice"]) {
		NSInteger amount = [content[@"total_amount"] integerValue];
		NSString *currency = content[@"currency"] ?: @"";
		invoiceReceiptMessageId = content[@"receipt_message_id"] ?: @0;
		invoicePaid = [invoiceReceiptMessageId longLongValue] != 0;
		id productTitle = content[@"product_info"][@"title"] ?: content[@"title"];
		NSString *invoiceTitle = productTitle ?: TGL(@"Watch.Message.Invoice", @"Invoice");
		NSString *amountLine = amount > 0
			? [NSString stringWithFormat:@"%.2f %@", amount / 100.0, currency]
			: nil;
		extra = amountLine.length
			? [NSString stringWithFormat:@"%@\n%@%@", invoiceTitle, amountLine,
				  invoicePaid ? TGL(@"Message.InvoicePaidSuffix", @" - Paid") : @""]
			: invoiceTitle;

	} else if ([ctype isEqualToString:@"messageStory"]) {
		extra = TGL(@"Message.Story", @"Story");

	} else if ([ctype isEqualToString:@"messagePaidMedia"]) {
		paidMediaStarCount = content[@"star_count"] ?: @0;
		NSArray *paidItems = content[@"media"];
		paidMediaUnlocked = NO;
		if ([paidItems isKindOfClass:[NSArray class]]) {
			for (NSDictionary *paidItem in paidItems) {
				NSString *paidType = [paidItem isKindOfClass:[NSDictionary class]]
					? paidItem[@"@type"]
					: nil;
				if (paidType.length && ![paidType isEqualToString:@"paidMediaPreview"]) {
					paidMediaUnlocked = YES;
					break;
				}
			}
		}
		extra = [NSString stringWithFormat:TGL(@"Message.PaidMediaSummary",
									@"Paid media, %@ stars%@"),
			paidMediaStarCount,
			paidMediaUnlocked ? TGL(@"Message.PaidMediaUnlockedSuffix", @" - Unlocked") : @""];

	} else if ([ctype isEqualToString:@"messageRichMessage"]) {
		NSDictionary *rich = [content[@"message"] isKindOfClass:NSDictionary.class]
			? content[@"message"]
			: nil;
		richBlocks = context.flattenedPageBlocks
			? context.flattenedPageBlocks(rich[@"blocks"])
			: @[];
		richIsFull = [rich[@"is_full"] boolValue] || !richBlocks.count;
		richIsRtl = [rich[@"is_rtl"] boolValue];
		NSDictionary *summary = TGRichMessageSummary(richBlocks);
		richKicker = [summary[@"kicker"] length] ? summary[@"kicker"] : nil;
		richTitle = [summary[@"title"] length] ? summary[@"title"] : nil;
		richSubtitle = [summary[@"subtitle"] length] ? summary[@"subtitle"] : nil;
		richSnippet = [summary[@"snippet"] length] ? summary[@"snippet"] : nil;
		richCoverFileId = [summary[@"coverFileId"] isKindOfClass:NSNumber.class]
			? summary[@"coverFileId"]
			: nil;
		richCoverW = [summary[@"coverW"] isKindOfClass:NSNumber.class]
			? summary[@"coverW"]
			: nil;
		richCoverH = [summary[@"coverH"] isKindOfClass:NSNumber.class]
			? summary[@"coverH"]
			: nil;
		extra = richTitle.length ? richTitle : (context.localizedFallback ? context.localizedFallback(@"Attachment.Article", @"Article") : @"Article");

	} else if ([ctype isEqualToString:@"messageChecklist"]) {
		NSDictionary *list = content[@"list"];
		NSMutableString *lines = [NSMutableString stringWithFormat:@"%@\n",
			list[@"title"][@"text"] ?: TGL(@"Attachment.Todo", @"Checklist")];
		for (NSDictionary *task in list[@"tasks"])
			[lines appendFormat:@"%@ %@\n",
				[task[@"completed_by"] isKindOfClass:NSDictionary.class] ? @"☑" : @"☐",
				task[@"text"][@"text"] ?: @""];
		extra = [lines stringByTrimmingCharactersInSet:
				[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	}

	NSString *disappearingText = TGMessageDisappears(m)
		? TGDisappearingMediaLabel(ctype)
		: nil;
	NSString *caption = disappearingText ? @"" : content[@"caption"][@"text"];
	NSString *text;
	if (disappearingText)
		text = disappearingText;
	else if (caption.length)
		text = caption;
	else if (extra.length)
		text = extra;
	else if (photoFileId || [ctype isEqualToString:@"messageVoiceNote"])
		text = @"";
	else
		text = TGMessagePreview(m, context);

	if (!isService && !photoFileId && !docFileId && !latitude &&
		!TGDrawableMessageKind(ctype)) {
		text = TGUnsupportedMessageTextValue();
		isService = NO;
	}

	if (!text.length && !photoFileId && !docFileId && !latitude &&
		![ctype isEqualToString:@"messageText"]) {
		text = TGUnsupportedMessageTextValue();
		isService = NO;
	}

	if (restrictionReason.length) {
		text = restrictionReason;
		caption = @"";
		isService = NO;
	}

	NSDictionary *formatted = [content[@"text"] isKindOfClass:NSDictionary.class]
		? content[@"text"]
		: ([content[@"caption"] isKindOfClass:NSDictionary.class]
				  ? content[@"caption"]
				  : nil);
	NSString *formattedBody = [formatted[@"text"] isKindOfClass:NSString.class]
		? formatted[@"text"]
		: nil;
	NSArray *entities = (formattedBody.length && [text isEqualToString:formattedBody])
		? TGFlattenEntities(formatted[@"entities"])
		: @[];

	NSDictionary *replyTo = m[@"reply_to"];
	NSNumber *replyId = nil;
	int64_t replyChatId = 0;
	NSString *replyText = nil;
	NSArray *replyEntities = @[];
	NSString *replyKindLabel = nil;
	NSString *replyAuthor = nil;
	BOOL replyIsFragment = NO;
	if ([replyTo[@"@type"] isEqualToString:@"messageReplyToMessage"]) {
		replyId = replyTo[@"message_id"];
		replyChatId = [replyTo[@"chat_id"] longLongValue];

		NSDictionary *quote = [replyTo[@"quote"] isKindOfClass:NSDictionary.class]
			? replyTo[@"quote"]
			: nil;
		NSDictionary *quoted = [quote[@"text"] isKindOfClass:NSDictionary.class]
			? quote[@"text"]
			: nil;
		replyText = [quoted[@"text"] isKindOfClass:NSString.class]
			? quoted[@"text"]
			: ([quote[@"text"] isKindOfClass:NSString.class] ? quote[@"text"] : nil);
		if (replyText.length) {
			replyEntities = TGFlattenEntities(quoted[@"entities"]);
			replyIsFragment = [quote[@"is_manual"] boolValue];
		}

		NSDictionary *replyContent = [replyTo[@"content"] isKindOfClass:NSDictionary.class]
			? replyTo[@"content"]
			: nil;
		if (replyContent) {
			replyKindLabel = TGMessageContentKindLabel(replyContent);
			if (!replyText.length && !TGMediaContentDisappears(replyContent)) {
				NSDictionary *replyFormatted =
					[replyContent[@"text"] isKindOfClass:NSDictionary.class]
					? replyContent[@"text"]
					: ([replyContent[@"caption"] isKindOfClass:NSDictionary.class]
							  ? replyContent[@"caption"]
							  : nil);
				NSString *replyBody = [replyFormatted[@"text"] isKindOfClass:NSString.class]
					? replyFormatted[@"text"]
					: nil;
				if (replyBody.length) {
					replyText = replyBody;
					replyEntities = TGFlattenEntities(replyFormatted[@"entities"]);
				}
			}
		}
		replyAuthor = TGReplyOriginName(context,
			[replyTo[@"origin"] isKindOfClass:NSDictionary.class]
				? replyTo[@"origin"]
				: nil);
	} else if ([replyTo[@"@type"] isEqualToString:@"messageReplyToStory"]) {
		replyId = [replyTo[@"story_id"] isKindOfClass:NSNumber.class]
			? replyTo[@"story_id"]
			: nil;
		replyKindLabel = TGL(@"Message.ReplyToStory", @"Reply to Story");
		replyText = replyKindLabel;
		replyAuthor = TGServiceTitleForChat(context,
			[replyTo[@"story_poster_chat_id"] longLongValue]);
	}

	NSString *forwardFrom = nil;
	NSDictionary *forwardInfo = m[@"forward_info"];
	NSDictionary *origin = forwardInfo[@"origin"];
	NSString *originType = origin[@"@type"];
	int64_t forwardUserId = 0;
	int64_t forwardChatId = 0;
	int64_t forwardMessageId = 0;
	BOOL forwardIsChannel = NO;
	BOOL forwardIsHiddenUser = NO;
	if ([originType isEqualToString:@"messageOriginUser"]) {
		forwardUserId = [origin[@"sender_user_id"] longLongValue];
		forwardFrom = (context.userName ? context.userName(forwardUserId) : nil)
			?: TGL(@"Notification.ForwardFromUnknownUser", @"a user");
	} else if ([originType isEqualToString:@"messageOriginHiddenUser"]) {
		forwardFrom = origin[@"sender_name"];
		forwardIsHiddenUser = YES;
	} else if ([originType isEqualToString:@"messageOriginChannel"]) {
		NSString *signature = origin[@"author_signature"];
		forwardFrom = signature.length
			? signature
			: TGL(@"Notification.ForwardFromUnknownChannel", @"a channel");
		forwardChatId = [origin[@"chat_id"] longLongValue];
		forwardMessageId = [origin[@"message_id"] longLongValue];
		forwardIsChannel = YES;
	} else if ([originType isEqualToString:@"messageOriginChat"]) {
		forwardFrom = origin[@"author_signature"]
			?: TGL(@"Notification.ForwardFromUnknownChat", @"a chat");
		forwardChatId = [origin[@"sender_chat_id"] longLongValue];
	}

	NSDictionary *forwardSource = forwardInfo[@"source"];
	if ([forwardSource isKindOfClass:NSDictionary.class] && !forwardMessageId) {
		int64_t sourceChat = [forwardSource[@"chat_id"] longLongValue];
		int64_t sourceMessage = [forwardSource[@"message_id"] longLongValue];
		if (sourceChat && sourceMessage &&
			(!forwardChatId || forwardChatId == sourceChat)) {
			forwardChatId = sourceChat;
			forwardMessageId = sourceMessage;
		}
	}

	long long docSize = 0, docDownloaded = 0;
	BOOL docIsLocal = NO, docIsDownloading = NO;
	NSString *docPath = nil;
	if ([mainFile isKindOfClass:NSDictionary.class]) {
		if (context.rememberFileState)
			context.rememberFileState(mainFile);
		NSDictionary *fileState = context.fileState ? context.fileState(mainFile) : nil;
		docSize = [fileState[@"size"] longLongValue];
		docDownloaded = [fileState[@"downloaded"] longLongValue];
		docIsLocal = [fileState[@"complete"] boolValue];
		docIsDownloading = [fileState[@"active"] boolValue];
		docPath = fileState[@"path"];
	}

	static NSData *emptyWaveform = nil;
	if (!emptyWaveform)
		emptyWaveform = [NSData data];

	NSArray *reactionChips = TGReactionChips(context, m);
	NSDictionary *commentInfo = TGCommentInfo(m);

	NSDictionary *sending = [m[@"sending_state"] isKindOfClass:NSDictionary.class]
		? m[@"sending_state"]
		: nil;
	NSString *sendingType = [sending[@"@type"] isKindOfClass:NSString.class]
		? sending[@"@type"]
		: nil;
	NSString *sendState = @"sent";
	if ([sendingType isEqualToString:@"messageSendingStatePending"])
		sendState = @"pending";
	else if ([sendingType isEqualToString:@"messageSendingStateFailed"])
		sendState = @"failed";

	NSDictionary *destructType = [m[@"self_destruct_type"] isKindOfClass:NSDictionary.class]
		? m[@"self_destruct_type"]
		: nil;
	BOOL viewOnce = [destructType[@"@type"]
		isEqualToString:@"messageSelfDestructTypeImmediately"];
	NSInteger destructTimer = [destructType[@"@type"]
								  isEqualToString:@"messageSelfDestructTypeTimer"]
		? [destructType[@"self_destruct_time"] integerValue]
		: 0;
	NSTimeInterval destructInRaw = [m[@"self_destruct_in"] doubleValue];
	NSTimeInterval destructAt = TGDestructDeadlineFromRemaining(destructInRaw,
		[NSDate timeIntervalSinceReferenceDate]);

	NSDictionary *suggestedPost = [m[@"suggested_post_info"] isKindOfClass:NSDictionary.class]
		? m[@"suggested_post_info"]
		: nil;
	NSString *suggestedPostPrice = @"";
	NSString *suggestedPostState = @"";
	long long suggestedPostSendDate = 0;
	if (suggestedPost) {
		suggestedPostSendDate = [suggestedPost[@"send_date"] longLongValue];
		NSDictionary *price = [suggestedPost[@"price"] isKindOfClass:NSDictionary.class]
			? suggestedPost[@"price"]
			: nil;
		NSString *priceType = [price[@"@type"] isKindOfClass:NSString.class]
			? price[@"@type"]
			: @"";
		if ([priceType isEqualToString:@"suggestedPostPriceStar"])
			suggestedPostPrice = [NSString stringWithFormat:@"%@ stars",
				price[@"star_count"] ?: @0];
		else if ([priceType isEqualToString:@"suggestedPostPriceGram"])
			suggestedPostPrice = [NSString stringWithFormat:@"%.2f TON",
				[price[@"gram_cent_count"] doubleValue] / 100.0];
		NSString *stateType = [suggestedPost[@"state"][@"@type"] isKindOfClass:NSString.class]
			? suggestedPost[@"state"][@"@type"]
			: @"";
		if ([stateType isEqualToString:@"suggestedPostStatePending"])
			suggestedPostState = @"pending";
		else if ([stateType isEqualToString:@"suggestedPostStateApproved"])
			suggestedPostState = @"approved";
		else if ([stateType isEqualToString:@"suggestedPostStateDeclined"])
			suggestedPostState = @"declined";
	}

	BOOL hasSensitiveContent = [restrictionInfo[@"has_sensitive_content"] boolValue] &&
		!context.ignoresSensitiveContentRestrictions;
	BOOL hasSpoiler = [content[@"has_spoiler"] boolValue] || hasSensitiveContent;

	NSDictionary *factCheck = [m[@"fact_check"] isKindOfClass:NSDictionary.class]
		? m[@"fact_check"]
		: nil;
	NSDictionary *factCheckBody = [factCheck[@"text"] isKindOfClass:NSDictionary.class]
		? factCheck[@"text"]
		: nil;
	NSString *factCheckText = [factCheckBody[@"text"] isKindOfClass:NSString.class]
		? factCheckBody[@"text"]
		: @"";
	NSArray *factCheckEntities = TGFlattenEntities(factCheckBody[@"entities"]);

	NSDictionary *senderIdInfo = [m[@"sender_id"] isKindOfClass:NSDictionary.class]
		? m[@"sender_id"]
		: nil;
	BOOL senderIsChat = [senderIdInfo[@"@type"] isEqualToString:@"messageSenderChat"];
	int64_t senderChatId = senderIsChat ? [senderIdInfo[@"chat_id"] longLongValue] : 0;
	NSNumber *senderId = senderIsChat ? @(0) : (senderIdInfo[@"user_id"] ?: @(0));

	BOOL slowModeActiveForChat =
		[context.chatsById[m[@"chat_id"]][@"slowModeDelay"] integerValue] > 0;

	NSDictionary *flat = @{
		@"sendState" : sendState,
		@"sendErrorMessage" : TGSendFailureMessage(sending, slowModeActiveForChat) ?: @"",
		@"viewOnce" : @(viewOnce),
		@"destructTimer" : @(destructTimer),
		@"destructIn" : @(destructInRaw),
		@"destructAt" : @(destructAt),
		@"secretMedia" : @([content[@"is_secret"] boolValue]),
		@"hasSpoiler" : @(hasSpoiler),
		@"restrictionReason" : restrictionReason ?: @"",
		@"captionAboveMedia" : @([content[@"show_caption_above_media"] boolValue]),
		@"linkPreviewOptions" : ([content[@"link_preview_options"] isKindOfClass:NSDictionary.class]
				? content[@"link_preview_options"]
				: (id)[NSNull null]),
		@"replyMarkup" : ([m[@"reply_markup"] isKindOfClass:NSDictionary.class]
				? m[@"reply_markup"]
				: (id)[NSNull null]),
		@"canRetry" : sending[@"can_retry"] ?: @NO,
		@"needAnotherReplyQuote" : sending[@"need_another_reply_quote"] ?: @NO,
		@"needDropReply" : sending[@"need_drop_reply"] ?: @NO,
		@"requiredPaidMessageStarCount" : @([sending[@"required_paid_message_star_count"] longLongValue]),
		@"canBeEdited" : @([m[@"can_be_edited"] boolValue]),
		@"id" : m[@"id"] ?: @(0),
		@"text" : text,
		@"entities" : entities,
		@"captionText" : ((!disappearingText &&
							  [content[@"caption"][@"text"] isKindOfClass:NSString.class])
				? content[@"caption"][@"text"]
				: @""),
		@"replyId" : replyId ?: [NSNull null],
		@"replyChatId" : [NSNumber numberWithLongLong:replyChatId],
		@"replyText" : replyText ?: @"",
		@"replyEntities" : replyEntities,
		@"replyKindLabel" : replyKindLabel ?: @"",
		@"replyAuthor" : replyAuthor ?: @"",
		@"replyIsFragment" : @(replyIsFragment),
		@"forward" : forwardFrom ?: @"",
		@"forwardUserId" : [NSNumber numberWithLongLong:forwardUserId],
		@"forwardChatId" : [NSNumber numberWithLongLong:forwardChatId],
		@"forwardMessageId" : [NSNumber numberWithLongLong:forwardMessageId],
		@"forwardIsChannel" : @(forwardIsChannel),
		@"forwardIsHiddenUser" : @(forwardIsHiddenUser),
		@"viaBotId" : [NSNumber numberWithLongLong:[m[@"via_bot_user_id"] longLongValue]],
		@"edited" : @([m[@"edit_date"] doubleValue] > 0),
		@"kind" : ctype ?: @"",
		@"giftCode" : ([content[@"code"] isKindOfClass:NSString.class] ? content[@"code"] : @""),
		@"date" : m[@"date"] ?: @(0),
		@"outgoing" : m[@"is_outgoing"] ?: @NO,
		@"scheduled" : @(TGMessageIsScheduled(m)),
		@"photoId" : photoFileId ?: [NSNull null],
		@"photoWidth" : photoW ?: [NSNull null],
		@"photoHeight" : photoH ?: [NSNull null],
		@"photoSizes" : photoSizes ?: @[],
		@"minithumbnail" : ([minithumb isKindOfClass:NSDictionary.class]
				? minithumb
				: (id)[NSNull null]),
		@"docId" : docFileId ?: [NSNull null],
		@"docName" : docName ?: @"",
		@"stickerSetId" : [NSNumber numberWithLongLong:stickerSetId],
		@"docMime" : docMime ?: @"",
		@"caption" : caption ?: @"",
		@"docExtension" : TGDocumentExtension(docName, docMime),
		@"docSize" : @(docSize),
		@"docDownloadedSize" : @(docDownloaded),
		@"docLocal" : @(docIsLocal),
		@"docDownloading" : @(docIsDownloading),
		@"docPath" : docPath ?: @"",
		@"supportsStreaming" : @(supportsStreaming),
		@"contactFirstName" : contactInfo[@"first_name"] ?: @"",
		@"contactLastName" : contactInfo[@"last_name"] ?: @"",
		@"contactPhone" : contactInfo[@"phone_number"] ?: @"",
		@"contactVcard" : [contactInfo[@"vcard"] isKindOfClass:NSString.class] ? contactInfo[@"vcard"] : @"",
		@"contactUserId" : contactInfo[@"user_id"] ?: @0,
		@"venueTitle" : venueTitle ?: @"",
		@"venueAddress" : venueAddress ?: @"",
		@"livePeriod" : @(livePeriod),
		@"liveExpiresIn" : @(liveExpiresIn),
		@"liveExpiresAt" : @(liveExpiresAt),
		@"liveHeading" : @(liveHeading),
		@"audioTitle" : audioTitle ?: @"",
		@"audioPerformer" : audioPerformer ?: @"",
		@"albumCoverId" : albumCoverId ?: [NSNull null],
		@"audioSize" : audioSize ?: @0,
		@"audioIsLocal" : @(audioIsLocal),
		@"service" : @(isService),
		@"serviceNamesAuthor" : @(serviceNamesAuthor),
		@"serviceActor" : (isService ? actorName : @""),
		@"pinnedId" : pinnedTargetId ?: [NSNull null],
		@"oldBackgroundMessageId" : oldBackgroundMessageIdTarget ?: [NSNull null],
		@"onlyForSelf" : onlyForSelfTarget ?: @NO,
		@"backgroundId" : backgroundIdTarget ?: [NSNull null],

		@"albumId" : m[@"media_album_id"] ?: @"",
		@"reactionChips" : reactionChips,
		@"reactions" : context.reactionSummary ? (context.reactionSummary(reactionChips) ?: @"") : @"",
		@"duration" : duration ?: @0,
		@"waveform" : waveform ?: emptyWaveform,
		@"transcript" : transcript ?: [NSNull null],
		@"senderId" : senderId,
		@"senderChatId" : [NSNumber numberWithLongLong:senderChatId],
		@"channelPost" : m[@"is_channel_post"] ?: @NO,
		@"effectId" : m[@"effect_id"] ?: @0,
		@"signature" : ([m[@"author_signature"] isKindOfClass:NSString.class]
				? m[@"author_signature"]
				: @""),
		@"views" : m[@"interaction_info"][@"view_count"] ?: @(0),
		@"commentCount" : commentInfo[@"count"] ?: @0,
		@"commentLastMessageId" : commentInfo[@"lastMessageId"] ?: @0,
		@"commentReplierIds" : commentInfo[@"replierIds"] ?: @[],
		@"hasCommentThread" : @(commentInfo != nil),
		@"lat" : latitude ?: [NSNull null],
		@"lon" : longitude ?: [NSNull null],
		@"callState" : callState ?: @"",
		@"callTitle" : callTitle ?: @"",
		@"callDuration" : @(callSeconds),
		@"isVideoCall" : @(isVideoCall),
		@"factCheckText" : factCheckText,
		@"factCheckEntities" : factCheckEntities,
		@"invoicePaid" : @(invoicePaid),
		@"invoiceReceiptMessageId" : invoiceReceiptMessageId,
		@"paidMediaUnlocked" : @(paidMediaUnlocked),
		@"paidMediaStarCount" : paidMediaStarCount,
		@"suggestedPostPrice" : suggestedPostPrice,
		@"suggestedPostState" : suggestedPostState,
		@"suggestedPostSendDate" : @(suggestedPostSendDate),
		@"isPaidStarSuggestedPost" : @([m[@"is_paid_star_suggested_post"] boolValue]),
		@"isPaidGramSuggestedPost" : @([m[@"is_paid_gram_suggested_post"] boolValue]),

		@"richMessageBlocks" : richBlocks ?: @[],
		@"richMessageIsFull" : @(richIsFull),
		@"richMessageIsRtl" : @(richIsRtl),
		@"richKicker" : richKicker ?: @"",
		@"richTitle" : richTitle ?: @"",
		@"richSubtitle" : richSubtitle ?: @"",
		@"richSnippet" : richSnippet ?: @"",
		@"richCoverFileId" : richCoverFileId ?: (id)[NSNull null],
		@"richCoverW" : richCoverW ?: (id)[NSNull null],
		@"richCoverH" : richCoverH ?: (id)[NSNull null],
	};

	NSDictionary *checklist = content[@"list"];
	if ([checklist isKindOfClass:NSDictionary.class]) {
		NSArray *rawTasks = checklist[@"tasks"];
		NSMutableArray *tasks = [NSMutableArray arrayWithCapacity:rawTasks.count];
		for (NSDictionary *task in rawTasks) {
			if (![task isKindOfClass:NSDictionary.class])
				continue;
			BOOL done = [task[@"completed_by"] isKindOfClass:NSDictionary.class];
			[tasks addObject:@{
				@"id" : task[@"id"] ?: @0,
				@"text" : task[@"text"][@"text"] ?: @"",
				@"done" : @(done),
				@"completedByName" : (done ? TGServiceSenderName(context, task[@"completed_by"]) : nil) ?: @"",
			}];
		}
		NSMutableDictionary *withChecklist = [flat mutableCopy];
		withChecklist[@"checklistTitle"] = checklist[@"title"][@"text"]
			?: TGL(@"Attachment.Todo", @"Checklist");
		withChecklist[@"checklistTasks"] = tasks;
		withChecklist[@"checklistCanAdd"] = checklist[@"can_add_tasks"] ?: @NO;
		withChecklist[@"checklistCanMark"] = checklist[@"can_mark_tasks_as_done"] ?: @NO;
		withChecklist[@"checklistOthersCanAdd"] = checklist[@"others_can_add_tasks"] ?: @NO;
		withChecklist[@"checklistOthersCanMark"] = checklist[@"others_can_mark_tasks_as_done"] ?: @NO;
		return [withChecklist copy];
	}

	NSDictionary *poll = content[@"poll"];
	if (![poll isKindOfClass:NSDictionary.class])
		return flat;

	NSMutableDictionary *withPoll = [flat mutableCopy];
	[withPoll addEntriesFromDictionary:TGFlattenPollFields(poll, content)];
	return [withPoll copy];
}

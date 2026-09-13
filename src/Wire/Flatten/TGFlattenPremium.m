#import "TGFlattenPremium.h"
#import "TGStringTruncation.h"
#import "TGLocalization.h"

NSString *TGPremiumHumanize(NSString *tag) {
	if (![tag isKindOfClass:[NSString class]] || !tag.length)
		return @"";
	NSMutableString *out = [NSMutableString stringWithCapacity:tag.length + 8];
	NSInteger i = 0;
	for (i = 0; i < tag.length; i++) {
		unichar c = [tag characterAtIndex:i];
		if (c >= 'A' && c <= 'Z') {
			if (out.length)
				[out appendString:@" "];
			[out appendFormat:@"%C", (unichar)(out.length ? c + 32 : c)];
		} else {
			if (!out.length && c >= 'a' && c <= 'z')
				c = (unichar)(c - 32);
			[out appendFormat:@"%C", c];
		}
	}
	return out;
}

NSString *TGPremiumTag(NSDictionary *object, NSString *prefix) {
	if (![object isKindOfClass:[NSDictionary class]])
		return @"";
	NSString *type = object[@"@type"];
	if (![type isKindOfClass:[NSString class]])
		return @"";
	if (prefix.length && type.length > prefix.length && [type hasPrefix:prefix]) {
		NSString *rest = [type substringFromIndex:prefix.length];
		if (!rest.length)
			return @"";
		return TGStringWithFirstCharacterLowercased(rest);
	}
	return type;
}

NSString *TGPremiumFullType(NSString *tag, NSString *prefix) {
	if (![tag isKindOfClass:[NSString class]] || !tag.length)
		return nil;
	if ([tag hasPrefix:prefix])
		return tag;
	return [prefix stringByAppendingString:TGStringWithFirstCharacterUppercased(tag)];
}

BOOL TGPremiumFeatureSupported(NSString *tag) {
	static NSSet *unsupported = nil;
	if (!unsupported)
		unsupported = [[NSSet alloc] initWithObjects:
				@"customEmoji", @"animatedProfilePhoto",
			@"forumTopicIcon", @"appIcons", @"uniqueStickers",
			@"uniqueReactions", @"upgradedStories", @"accentColor",
			@"backgroundForBoth", @"messageEffects", @"checklists",
			@"realTimeChatTranslation", @"richMessages",
			@"textComposition", @"disabledAds", nil];
	return ![unsupported containsObject:tag];
}

NSString *TGPremiumFeatureTitle(NSString *tag) {
	static NSDictionary *table = nil;
	if (!table)
		table = [[NSDictionary alloc] initWithObjectsAndKeys:
				@[ @"Premium.Feature.IncreasedLimits.Title", @"Doubled Limits" ], @"increasedLimits",
			@[ @"Premium.Feature.IncreasedUploadFileSize.Title", @"4 GB Uploads" ], @"increasedUploadFileSize",
			@[ @"Premium.Feature.ImprovedDownloadSpeed.Title", @"Faster Download Speed" ], @"improvedDownloadSpeed",
			@[ @"Premium.Feature.VoiceRecognition.Title", @"Voice-to-Text Conversion" ], @"voiceRecognition",
			@[ @"Premium.Feature.UniqueReactions.Title", @"Unique Reactions" ], @"uniqueReactions",
			@[ @"Premium.Feature.UniqueStickers.Title", @"Premium Stickers" ], @"uniqueStickers",
			@[ @"Premium.Feature.CustomEmoji.Title", @"Custom Emoji" ], @"customEmoji",
			@[ @"Premium.Feature.AdvancedChatManagement.Title", @"Advanced Chat Management" ], @"advancedChatManagement",
			@[ @"Premium.Feature.ProfileBadge.Title", @"Profile Badge" ], @"profileBadge",
			@[ @"Premium.Feature.EmojiStatus.Title", @"Emoji Status" ], @"emojiStatus",
			@[ @"Premium.Feature.AnimatedProfilePhoto.Title", @"Animated Profile Photo" ], @"animatedProfilePhoto",
			@[ @"Premium.Feature.ForumTopicIcon.Title", @"Custom Topic Icons" ], @"forumTopicIcon",
			@[ @"Premium.Feature.AppIcons.Title", @"Telegram App Icon" ], @"appIcons",
			@[ @"Premium.Feature.RealTimeChatTranslation.Title", @"Real-Time Translation" ], @"realTimeChatTranslation",
			@[ @"Premium.Feature.UpgradedStories.Title", @"Upgraded Stories" ], @"upgradedStories",
			@[ @"Premium.Feature.ChatBoost.Title", @"Chat Boost" ], @"chatBoost",
			@[ @"Premium.Feature.AccentColor.Title", @"Name Colour" ], @"accentColor",
			@[ @"Premium.Feature.BackgroundForBoth.Title", @"Wallpaper for Both Sides" ], @"backgroundForBoth",
			@[ @"Premium.Feature.SavedMessagesTags.Title", @"Saved Message Tags" ], @"savedMessagesTags",
			@[ @"Premium.Feature.MessagePrivacy.Title", @"Message Privacy" ], @"messagePrivacy",
			@[ @"Premium.Feature.LastSeenTimes.Title", @"Last Seen Times" ], @"lastSeenTimes",
			@[ @"Premium.Feature.Business.Title", @"Telegram Business" ], @"business",
			@[ @"Premium.Feature.MessageEffects.Title", @"Message Effects" ], @"messageEffects",
			@[ @"Premium.Feature.Checklists.Title", @"Checklists" ], @"checklists",
			@[ @"Premium.Feature.PaidMessages.Title", @"Paid Messages" ], @"paidMessages",
			@[ @"Premium.Feature.ProtectPrivateChatContent.Title", @"Restrict Saving Content" ], @"protectPrivateChatContent",
			@[ @"Premium.Feature.DisabledAds.Title", @"No Ads" ], @"disabledAds",
			@[ @"Premium.Feature.TextComposition.Title", @"Text Composition" ], @"textComposition",
			@[ @"Premium.Feature.RichMessages.Title", @"Rich Messages" ], @"richMessages",
			@[ @"Premium.Feature.PromotionAnimation.Title", @"Telegram Premium" ], @"promotionAnimation",
			nil];
	NSArray *entry = [table objectForKey:tag];
	if (!entry)
		return TGPremiumHumanize(tag);
	return TGL(entry[0], entry[1]);
}

NSString *TGPremiumBusinessTitle(NSString *tag) {
	static NSDictionary *table = nil;
	if (!table)
		table = [[NSDictionary alloc] initWithObjectsAndKeys:
				@[ @"Premium.Business.Feature.Location.Title", @"Location" ], @"location",
			@[ @"Premium.Business.Feature.OpeningHours.Title", @"Opening Hours" ], @"openingHours",
			@[ @"Premium.Business.Feature.QuickReplies.Title", @"Quick Replies" ], @"quickReplies",
			@[ @"Premium.Business.Feature.GreetingMessage.Title", @"Greeting Message" ], @"greetingMessage",
			@[ @"Premium.Business.Feature.AwayMessage.Title", @"Away Message" ], @"awayMessage",
			@[ @"Premium.Business.Feature.AccountLinks.Title", @"Links to Chat" ], @"accountLinks",
			@[ @"Premium.Business.Feature.StartPage.Title", @"Chat Intro" ], @"startPage",
			@[ @"Premium.Business.Feature.Bots.Title", @"Chatbots" ], @"bots",
			@[ @"Premium.Business.Feature.EmojiStatus.Title", @"Emoji Status" ], @"emojiStatus",
			@[ @"Premium.Business.Feature.ChatFolderTags.Title", @"Folder Tags" ], @"chatFolderTags",
			@[ @"Premium.Business.Feature.UpgradedStories.Title", @"Upgraded Stories" ], @"upgradedStories",
			@[ @"Premium.Business.Feature.PromotionAnimation.Title", @"Telegram Business" ], @"promotionAnimation",
			nil];
	NSArray *entry = [table objectForKey:tag];
	if (!entry)
		return TGPremiumHumanize(tag);
	return TGL(entry[0], entry[1]);
}

NSString *TGPremiumLimitTitle(NSString *tag) {
	static NSDictionary *table = nil;
	if (!table)
		table = [[NSDictionary alloc] initWithObjectsAndKeys:
				@[ @"Premium.Limit.SupergroupCount.Title", @"Groups and Channels" ], @"supergroupCount",
			@[ @"Premium.Limit.PinnedChatCount.Title", @"Pinned Chats" ], @"pinnedChatCount",
			@[ @"Premium.Limit.CreatedPublicChatCount.Title", @"Public Links" ], @"createdPublicChatCount",
			@[ @"Premium.Limit.SavedAnimationCount.Title", @"Saved GIFs" ], @"savedAnimationCount",
			@[ @"Premium.Limit.FavoriteStickerCount.Title", @"Favourite Stickers" ], @"favoriteStickerCount",
			@[ @"Premium.Limit.ChatFolderCount.Title", @"Folders" ], @"chatFolderCount",
			@[ @"Premium.Limit.ChatFolderChosenChatCount.Title", @"Chats per Folder" ], @"chatFolderChosenChatCount",
			@[ @"Premium.Limit.PinnedArchivedChatCount.Title", @"Pinned Archived Chats" ], @"pinnedArchivedChatCount",
			@[ @"Premium.Limit.PinnedSavedMessagesTopicCount.Title", @"Pinned Saved Topics" ], @"pinnedSavedMessagesTopicCount",
			@[ @"Premium.Limit.MessageTextLength.Title", @"Message Length" ], @"messageTextLength",
			@[ @"Premium.Limit.CaptionLength.Title", @"Captions" ], @"captionLength",
			@[ @"Premium.Limit.BioLength.Title", @"Bio Length" ], @"bioLength",
			@[ @"Premium.Limit.ChatFolderInviteLinkCount.Title", @"Folder Invite Links" ], @"chatFolderInviteLinkCount",
			@[ @"Premium.Limit.ShareableChatFolderCount.Title", @"Shareable Folders" ], @"shareableChatFolderCount",
			@[ @"Premium.Limit.ActiveStoryCount.Title", @"Active Stories" ], @"activeStoryCount",
			@[ @"Premium.Limit.WeeklyPostedStoryCount.Title", @"Stories per Week" ], @"weeklyPostedStoryCount",
			@[ @"Premium.Limit.MonthlyPostedStoryCount.Title", @"Stories per Month" ], @"monthlyPostedStoryCount",
			@[ @"Premium.Limit.StoryCaptionLength.Title", @"Story Caption Length" ], @"storyCaptionLength",
			@[ @"Premium.Limit.StorySuggestedReactionAreaCount.Title", @"Story Reaction Areas" ], @"storySuggestedReactionAreaCount",
			@[ @"Premium.Limit.SimilarChatCount.Title", @"Similar Channels" ], @"similarChatCount",
			@[ @"Premium.Limit.OwnedBotCount.Title", @"Bots You Own" ], @"ownedBotCount",
			@[ @"Premium.Limit.CustomTextCompositionStyleCount.Title", @"Text Composition Styles" ], @"customTextCompositionStyleCount",
			nil];
	NSArray *entry = [table objectForKey:tag];
	if (!entry)
		return TGPremiumHumanize(tag);
	return TGL(entry[0], entry[1]);
}

NSString *TGPremiumFeatureSubtitle(NSString *tag) {
	static NSDictionary *table = nil;
	if (!table)
		table = [[NSDictionary alloc] initWithObjectsAndKeys:
				@[ @"Premium.Feature.IncreasedLimits.Subtitle", @"Double the limits on folders, pinned chats and more" ], @"increasedLimits",
			@[ @"Premium.Feature.IncreasedUploadFileSize.Subtitle", @"Send files of up to 4 GB" ], @"increasedUploadFileSize",
			@[ @"Premium.Feature.ImprovedDownloadSpeed.Subtitle", @"Download media at the fastest possible speed" ], @"improvedDownloadSpeed",
			@[ @"Premium.Feature.VoiceRecognition.Subtitle", @"Turn voice messages into text" ], @"voiceRecognition",
			@[ @"Premium.Feature.UniqueReactions.Subtitle", @"React with a much larger set of emoji" ], @"uniqueReactions",
			@[ @"Premium.Feature.UniqueStickers.Subtitle", @"Unlock exclusive sticker packs" ], @"uniqueStickers",
			@[ @"Premium.Feature.CustomEmoji.Subtitle", @"Use custom emoji anywhere in your messages" ], @"customEmoji",
			@[ @"Premium.Feature.AdvancedChatManagement.Subtitle", @"Auto-archive and restrict who can message you" ], @"advancedChatManagement",
			@[ @"Premium.Feature.ProfileBadge.Subtitle", @"A star badge next to your name everywhere" ], @"profileBadge",
			@[ @"Premium.Feature.EmojiStatus.Subtitle", @"Show an emoji next to your name" ], @"emojiStatus",
			@[ @"Premium.Feature.AnimatedProfilePhoto.Subtitle", @"Set a looping video as your profile photo" ], @"animatedProfilePhoto",
			@[ @"Premium.Feature.ForumTopicIcon.Subtitle", @"Use any custom emoji as a topic icon" ], @"forumTopicIcon",
			@[ @"Premium.Feature.AppIcons.Subtitle", @"Change the app icon on your home screen" ], @"appIcons",
			@[ @"Premium.Feature.RealTimeChatTranslation.Subtitle", @"Translate whole chats as you read them" ], @"realTimeChatTranslation",
			@[ @"Premium.Feature.UpgradedStories.Subtitle", @"Longer stories, more of them, and priority order" ], @"upgradedStories",
			@[ @"Premium.Feature.ChatBoost.Subtitle", @"Boost channels so they can post stories" ], @"chatBoost",
			@[ @"Premium.Feature.AccentColor.Subtitle", @"Pick your own name and profile colours" ], @"accentColor",
			@[ @"Premium.Feature.BackgroundForBoth.Subtitle", @"Set a wallpaper for both sides of a chat" ], @"backgroundForBoth",
			@[ @"Premium.Feature.SavedMessagesTags.Subtitle", @"Tag your saved messages by topic" ], @"savedMessagesTags",
			@[ @"Premium.Feature.MessagePrivacy.Subtitle", @"Hide your forwarded-message link and phone number" ], @"messagePrivacy",
			@[ @"Premium.Feature.LastSeenTimes.Subtitle", @"See when contacts were last online" ], @"lastSeenTimes",
			@[ @"Premium.Feature.Business.Subtitle", @"Opening hours, away messages and quick replies" ], @"business",
			@[ @"Premium.Feature.MessageEffects.Subtitle", @"Send animated effects with a message" ], @"messageEffects",
			@[ @"Premium.Feature.Checklists.Subtitle", @"Send interactive checklists" ], @"checklists",
			@[ @"Premium.Feature.PaidMessages.Subtitle", @"Charge stars for messages sent to you" ], @"paidMessages",
			@[ @"Premium.Feature.ProtectPrivateChatContent.Subtitle", @"Stop others saving media from your private chats" ], @"protectPrivateChatContent",
			@[ @"Premium.Feature.DisabledAds.Subtitle", @"No more ads in the channels you read" ], @"disabledAds",
			@[ @"Premium.Feature.TextComposition.Subtitle", @"Compose and rewrite messages with AI" ], @"textComposition",
			@[ @"Premium.Feature.RichMessages.Subtitle", @"Send messages with richer formatting" ], @"richMessages",
			nil];
	NSArray *entry = [table objectForKey:tag];
	if (!entry)
		return @"";
	return TGL(entry[0], entry[1]);
}

NSString *TGPremiumBusinessSubtitle(NSString *tag) {
	static NSDictionary *table = nil;
	if (!table)
		table = [[NSDictionary alloc] initWithObjectsAndKeys:
				@[ @"Premium.Business.Feature.Location.Subtitle", @"Show your address on your profile" ], @"location",
			@[ @"Premium.Business.Feature.OpeningHours.Subtitle", @"Tell customers when you are open" ], @"openingHours",
			@[ @"Premium.Business.Feature.QuickReplies.Subtitle", @"Save and reuse frequent answers" ], @"quickReplies",
			@[ @"Premium.Business.Feature.GreetingMessage.Subtitle", @"Greet new customers automatically" ], @"greetingMessage",
			@[ @"Premium.Business.Feature.AwayMessage.Subtitle", @"Reply automatically while you are away" ], @"awayMessage",
			@[ @"Premium.Business.Feature.AccountLinks.Subtitle", @"Link your other accounts from your profile" ], @"accountLinks",
			@[ @"Premium.Business.Feature.StartPage.Subtitle", @"A custom intro on your empty chat screen" ], @"startPage",
			@[ @"Premium.Business.Feature.Bots.Subtitle", @"Let a bot answer for you" ], @"bots",
			@[ @"Premium.Business.Feature.EmojiStatus.Subtitle", @"Show an emoji next to your name" ], @"emojiStatus",
			@[ @"Premium.Business.Feature.ChatFolderTags.Subtitle", @"Colour-tag your chat folders" ], @"chatFolderTags",
			@[ @"Premium.Business.Feature.UpgradedStories.Subtitle", @"Longer stories and more of them" ], @"upgradedStories",
			nil];
	NSArray *entry = [table objectForKey:tag];
	if (!entry)
		return @"";
	return TGL(entry[0], entry[1]);
}

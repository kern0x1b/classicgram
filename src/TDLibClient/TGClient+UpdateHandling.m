#import "TGFloodWaitNotice.h"
#import "TGCacheTrim.h"
#import "TGUserDisplayName.h"
#import "TGRequestExpiry.h"
#import "TGClient+Private.h"
#import "TGAuthErrorMessage.h"
#import "TGFlattenAccount.h"
#import "TGServiceNotificationAlert.h"
#import "TGClient+Storage.h"
#import "TGClient+ChatState.h"
#import "TGClient+ChatManagement.h"
#import "TGFlattenChatState.h"
#import "TGLocalization.h"
#import "TGChatActionPhraseComposer.h"
#import "TGClient+Network.h"
#import "TGClient+ChatList.h"
#import "TGFlattenChatList.h"
#import "TGClient+Notifications.h"
#import "TGClient+Stories.h"
#import "TGClient+Reactions.h"
#import "TGClient+Payments.h"
#import "TGClient+Bots.h"
#import "TGClient+Contacts.h"
#import "TGClient+Forums.h"
#import "TGClient+AppSettings.h"
#import "TGClient+UserStatus.h"
#import "TGClient+Account.h"
#import "TGClient+Privacy.h"
#import "TGClient+Messages.h"
#import "TGClient+DirectMessages.h"
#import "TGClient+WebLinks.h"
#import "TGClient+AiWriting.h"
#import "TGClient+SecretChats.h"
#import "TGClient+Premium.h"
#import "TGDownloadsUpdate.h"
#import "TGFlattenMessage.h"
#import "TGCall.h"
#import "TGBackgroundSession.h"
#import "TGDiskCache.h"
#import "TGDatabaseEncryptionKey.h"
#import "TGAccountManager.h"
#import "TGRemoteImageView.h"
#import "AppDelegate.h"
#import "TGFlattenAppSettings.h"
#import "TGTheme.h"
#import <UIKit/UIKit.h>
#import "TGBase64.h"
#include "api_id.h"

static const NSTimeInterval kRequestSweepInterval = 30.0;

static void TGPostChatAction(TGClient *client, int64_t chatId, int64_t topicId, NSString *action) {
	NSMutableDictionary *info = [NSMutableDictionary dictionary];
	info[TGChatActionChatIdKey] = @(chatId);
	info[TGChatActionTopicIdKey] = @(topicId);
	if (action)
		info[TGChatActionTextKey] = action;
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGChatActionDidChangeNotification
					  object:client
					userInfo:info];
}

static void TGPostForumTopicChange(TGClient *client, int64_t chatId, int32_t topicId) {
	NSDictionary *info = @{
		TGForumTopicChatIdKey : @(chatId),
		TGForumTopicTopicIdKey : @(topicId),
	};
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGForumTopicDidChangeNotification
					  object:client
					userInfo:info];
}

static int64_t TGChatActionSenderId(NSDictionary *sender) {
	if (![sender isKindOfClass:NSDictionary.class])
		return 0;
	if ([sender[@"@type"] isEqualToString:@"messageSenderChat"])
		return [sender[@"chat_id"] longLongValue];
	return [sender[@"user_id"] longLongValue];
}

static BOOL TGChatActionSenderIsChat(NSDictionary *sender) {
	return [sender isKindOfClass:NSDictionary.class] &&
		[sender[@"@type"] isEqualToString:@"messageSenderChat"];
}

static int64_t TGChatActionTopicId(NSDictionary *topic) {
	if (![topic isKindOfClass:NSDictionary.class])
		return 0;
	NSString *type = topic[@"@type"];
	if ([type isEqualToString:@"messageTopicForum"])
		return [topic[@"forum_topic_id"] longLongValue];
	if ([type isEqualToString:@"messageTopicThread"])
		return [topic[@"message_thread_id"] longLongValue];
	if ([type isEqualToString:@"messageTopicDirectMessages"])
		return [topic[@"direct_messages_chat_topic_id"] longLongValue];
	if ([type isEqualToString:@"messageTopicSavedMessages"])
		return [topic[@"saved_messages_topic_id"] longLongValue];
	return 0;
}

static NSString *TGChatActionBarePhraseForKind(NSString *kind) {
	if ([kind isEqualToString:@"chatActionTyping"])
		return TGChatActionTypingVerb();
	if ([kind isEqualToString:@"chatActionRecordingVoiceNote"])
		return TGL(@"Chat.RecordingAudioVerb", @"recording audio...");
	if ([kind isEqualToString:@"chatActionRecordingVideoNote"] ||
		[kind isEqualToString:@"chatActionRecordingVideo"])
		return TGL(@"Chat.RecordingVideoVerb", @"recording video...");
	if ([kind isEqualToString:@"chatActionUploadingPhoto"])
		return TGL(@"Chat.UploadingPhotoVerb", @"sending a photo...");
	if ([kind hasPrefix:@"chatActionUploading"])
		return TGL(@"Chat.UploadingFileVerb", @"sending a file...");
	if ([kind isEqualToString:@"chatActionChoosingSticker"])
		return TGL(@"Chat.ChoosingStickerVerb", @"choosing a sticker...");
	if ([kind isEqualToString:@"chatActionChoosingLocation"])
		return TGL(@"Chat.ChoosingLocationVerb", @"choosing a location...");
	if ([kind isEqualToString:@"chatActionChoosingContact"])
		return TGL(@"Chat.ChoosingContactVerb", @"choosing a contact...");
	if ([kind isEqualToString:@"chatActionStartPlayingGame"])
		return TGL(@"Chat.PlayingGameVerb", @"playing a game...");
	if ([kind isEqualToString:@"chatActionWatchingAnimations"])
		return TGL(@"Chat.WatchingAnimationsVerb", @"watching animations...");
	return nil;
}

static NSArray *TGChatActionSortedSenderKeys(NSDictionary *actionsBySender) {
	return [actionsBySender.allKeys sortedArrayUsingComparator:
		^NSComparisonResult(NSNumber *a, NSNumber *b) {
			double ta = [actionsBySender[a][@"timestamp"] doubleValue];
			double tb = [actionsBySender[b][@"timestamp"] doubleValue];
			if (ta != tb)
				return ta < tb ? NSOrderedAscending : NSOrderedDescending;
			return [a compare:b];
		}];
}

static NSDictionary *TGChatActionFlattenTopics(NSDictionary *actionsByTopic) {
	if (!actionsByTopic.count)
		return nil;
	NSMutableDictionary *flat = [NSMutableDictionary dictionary];
	for (NSDictionary *topicActions in actionsByTopic.allValues) {
		for (NSNumber *senderKey in topicActions) {
			NSDictionary *entry = topicActions[senderKey];
			NSDictionary *existing = flat[senderKey];
			double timestamp = [entry[@"timestamp"] doubleValue];
			double existingTimestamp = [existing[@"timestamp"] doubleValue];
			if (!existing || timestamp >= existingTimestamp)
				flat[senderKey] = entry;
		}
	}
	return flat;
}

static NSString *TGChatActionSenderName(TGClient *client, int64_t senderId, BOOL isChat) {
	if (isChat) {
		NSString *title = client.chatsById[@(senderId)][@"title"];
		return [title isKindOfClass:NSString.class] ? title : @"";
	}
	return [client nameForUserId:senderId] ?: @"";
}

static NSString *TGChatActionDisplayPhrase(TGClient *client, NSMutableDictionary *chatInfo, NSDictionary *actionsBySender) {
	if (!actionsBySender.count)
		return @"";

	NSArray *senderKeys = TGChatActionSortedSenderKeys(actionsBySender);
	NSDictionary *firstEntry = actionsBySender[senderKeys.firstObject];

	if (![chatInfo[@"isGroup"] boolValue])
		return firstEntry[@"phrase"] ?: @"";

	NSUInteger neededNames = MIN(senderKeys.count, (NSUInteger)2);
	NSMutableArray *displayNames = [NSMutableArray arrayWithCapacity:neededNames];
	for (NSUInteger i = 0; i < neededNames; i++) {
		NSNumber *key = senderKeys[i];
		NSDictionary *entry = actionsBySender[key];
		int64_t senderId = [key longLongValue];
		BOOL isChat = [entry[@"isChat"] boolValue];
		NSString *name = TGChatActionSenderName(client, senderId, isChat);
		if (name.length) {
			[displayNames addObject:name];
			continue;
		}
		if (!isChat) {
			__weak TGClient *weakClient = client;
			[client ensureUserName:senderId completion:^{
				[weakClient rebuildChats];
			}];
		}
		if (senderKeys.count == 1)
			return firstEntry[@"phrase"] ?: @"";
		return TGLPlural(@"Chat.TypingMultipleUsers", (NSInteger)senderKeys.count,
			@"%d person is typing...", @"%d people are typing...");
	}

	NSMutableArray *allPhrases = [NSMutableArray arrayWithCapacity:senderKeys.count];
	for (NSNumber *key in senderKeys)
		[allPhrases addObject:actionsBySender[key][@"phrase"] ?: @""];

	return TGComposeChatActionDisplayPhrase(displayNames, allPhrases);
}

static void TGPostMessageChange(TGClient *client, int64_t chatId, NSDictionary *message, int64_t deletedId) {
	NSMutableDictionary *info = [NSMutableDictionary dictionary];
	info[TGMessageChatIdKey] = @(chatId);
	if (message)
		info[TGMessageDataKey] = message;
	if (deletedId)
		info[TGMessageDeletedIdKey] = @(deletedId);
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGMessageDidChangeNotification
					  object:client
					userInfo:info];
}

@implementation TGClient (UpdateHandling)

#pragma mark - updates

- (void)failPendingRequests:(NSString *)reason {
	if (!self.pendingRequests.count)
		return;
	NSArray *entries = [self.pendingRequests allValues];
	[self.pendingRequests removeAllObjects];
	NSDictionary *error = @{@"@type" : @"error",
		@"code" : @(500),
		@"message" : reason ?: @"request abandoned"};
	for (NSDictionary *entry in entries) {
		void (^completion)(NSDictionary *) = entry[@"block"];
		if (completion)
			completion(error);
	}
}

- (void)startPendingSweepTimer {
	if (![NSThread isMainThread]) {
		__weak typeof(self) weakSelf = self;
		dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf startPendingSweepTimer]; });
		return;
	}
	if (self.pendingSweepTimer)
		return;
	self.pendingSweepTimer = [NSTimer scheduledTimerWithTimeInterval:kRequestSweepInterval
															 target:self
														   selector:@selector(sweepPendingRequestsOnTimer)
														   userInfo:nil
															repeats:YES];
}

- (void)sweepPendingRequestsOnTimer {
	if (!self.pendingRequests.count) {
		[self.pendingSweepTimer invalidate];
		self.pendingSweepTimer = nil;
		return;
	}
	self.lastPendingSweep = 0;
	[self sweepPendingRequests];
}

- (void)sweepPendingRequests {
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	if (now - self.lastPendingSweep < kRequestSweepInterval)
		return;
	self.lastPendingSweep = now;
	if (!self.pendingRequests.count)
		return;

	NSMutableArray *expired = [NSMutableArray array];
	for (NSString *key in TGExpiredRequestKeys(self.pendingRequests, now)) {
		NSDictionary *entry = self.pendingRequests[key];
		if (entry)
			[expired addObject:entry];
		[self.pendingRequests removeObjectForKey:key];
	}
	if (!expired.count)
		return;

	NSDictionary *error = @{@"@type" : @"error",
		@"code" : @(500),
		@"message" : @"request timed out"};
	for (NSDictionary *entry in expired) {
		void (^completion)(NSDictionary *) = entry[@"block"];
		if (completion)
			completion(error);
	}
}

- (void)handleUpdate:(NSDictionary *)obj {
	[self sweepPendingRequests];

	if (TGPerfLogging()) {
		NSString *rtype = [obj[@"@type"] isKindOfClass:NSString.class] ? obj[@"@type"] : @"?";
		BOOL isResponse = [obj[@"@extra"] isKindOfClass:NSString.class];
		NSString *key = isResponse ? [rtype stringByAppendingString:@" (response)"] : rtype;
		[self.bridgeCountsLock lock];
		NSNumber *n = self.bridgeRecvCounts[key];
		self.bridgeRecvCounts[key] = @(n.unsignedIntegerValue + 1);
		[self.bridgeCountsLock unlock];
	}

	NSString *extra = obj[@"@extra"];
	if ([extra isKindOfClass:NSString.class]) {
		NSDictionary *entry = self.pendingRequests[extra];
		void (^completion)(NSDictionary *) = entry[@"block"];
		if (completion) {
			[self.pendingRequests removeObjectForKey:extra];
			[self announceFloodWaitIn:obj];
			completion(obj);
			return;
		}
	}
	NSString *type = obj[@"@type"];

	static NSMutableSet *seen = nil;
	if (!seen)
		seen = [NSMutableSet set];
	if (type && ![seen containsObject:type]) {
		[seen addObject:type];
		NSLog(@"TGClient: first %@", type);
	}

	if ([type hasPrefix:@"updateNotification"] ||
		[type isEqualToString:@"updateActiveNotifications"] ||
		[type isEqualToString:@"updateHavePendingNotifications"] ||
		[type isEqualToString:@"updateChatNotificationSettings"] ||
		[type isEqualToString:@"updateScopeNotificationSettings"] ||
		[type isEqualToString:@"updateChatReadInbox"] ||
		[type isEqualToString:@"updateUnreadMessageCount"]) {
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGNotificationUpdateNotification
						  object:obj];
	}

	if ([type isEqualToString:@"updateServiceNotification"]) {
		NSDictionary *alert = TGServiceNotificationAlert(obj);
		if (alert)
			[[NSNotificationCenter defaultCenter]
				postNotificationName:TGServiceNotificationDidArriveNotification
							  object:nil
							userInfo:alert];
		return;
	}

	if ([type isEqualToString:@"updateAuthorizationState"]) {
		[self handleAuthState:obj[@"authorization_state"]];
		return;
	}

	if ([type isEqualToString:@"updateScopeNotificationSettings"]) {
		[self applyScopeNotificationSettingsUpdate:obj];
		return;
	}

	if ([type isEqualToString:@"updateReactionNotificationSettings"]) {
		[self applyReactionNotificationSettingsUpdate:obj];
		return;
	}

	if ([type isEqualToString:@"updateAutosaveSettings"]) {
		[self applyAutosaveSettingsUpdate:obj];
		return;
	}

	if ([type isEqualToString:@"user"] && obj[@"phone_number"]) {
		[self handleMeUser:obj];
		return;
	}
	if ([type isEqualToString:@"updateUser"]) {
		[self handleUpdateUser:obj];
		return;
	}
	if ([type isEqualToString:@"updateUserFullInfo"]) {
		[self handleUpdateUserFullInfo:obj];
		return;
	}
	if ([type isEqualToString:@"updateContactCloseBirthdays"]) {
		[self handleUpdateContactCloseBirthdays:obj];
		return;
	}

	if ([type isEqualToString:@"updateNewMessage"]) {
		[self handleUpdateNewMessage:obj];
		return;
	}
	if ([type isEqualToString:@"updateMessageContent"] ||
		[type isEqualToString:@"updateMessageEdited"] ||
		[type isEqualToString:@"updateMessageFactCheck"] ||
		[type isEqualToString:@"updateMessageSuggestedPostInfo"] ||
		[type isEqualToString:@"updateMessageContentOpened"]) {
		[self handleUpdateMessageContent:obj];
		return;
	}
	if ([type isEqualToString:@"updateMessageSendSucceeded"] ||
		[type isEqualToString:@"updateMessageSendFailed"]) {
		[self handleUpdateMessageSent:obj];
		return;
	}
	if ([type isEqualToString:@"updateDeleteMessages"]) {
		[self handleUpdateDeleteMessages:obj];
		return;
	}
	if ([type isEqualToString:@"updateNewChat"]) {
		[self mergeChat:obj[@"chat"]];
		return;
	}
	if ([type isEqualToString:@"updateChatLastMessage"] ||
		[type isEqualToString:@"updateChatPosition"] ||
		[type isEqualToString:@"updateChatTitle"] ||
		[type isEqualToString:@"updateChatPhoto"] ||
		[type isEqualToString:@"updateChatReadInbox"] ||
		[type isEqualToString:@"updateChatReadOutbox"] ||
		[type isEqualToString:@"updateChatDraftMessage"] ||
		[type isEqualToString:@"updateChatIsMarkedAsUnread"] ||
		[type isEqualToString:@"updateChatIsTranslatable"] ||
		[type isEqualToString:@"updateChatNotificationSettings"] ||
		[type isEqualToString:@"updateChatVideoChat"] ||
		[type isEqualToString:@"updateChatEmojiStatus"]) {
		[self applyChatUpdate:obj];
		return;
	}
	if ([type isEqualToString:@"updatePoll"]) {
		[self handleUpdatePoll:obj];
		return;
	}
	if ([type isEqualToString:@"updateMessageInteractionInfo"]) {
		[self handleUpdateMessageInteractionInfo:obj];
		return;
	}
	if ([type isEqualToString:@"updateMessageIsPinned"]) {
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGChatPinnedMessagesDidChangeNotification
						  object:obj[@"chat_id"]];
		return;
	}
	if ([type isEqualToString:@"updateMessageMentionRead"] ||
		[type isEqualToString:@"updateChatUnreadMentionCount"]) {
		NSMutableDictionary *info = self.chatsById[obj[@"chat_id"]];
		if (info)
			info[@"unreadMentionCount"] = obj[@"unread_mention_count"] ?: @(0);
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGChatUnreadMentionsDidChangeNotification
						  object:obj[@"chat_id"]];
		return;
	}
	if ([type isEqualToString:@"updateMessageUnreadReactions"] ||
		[type isEqualToString:@"updateChatUnreadReactionCount"]) {
		NSMutableDictionary *info = self.chatsById[obj[@"chat_id"]];
		if (info && obj[@"unread_reaction_count"])
			info[@"unreadReactionCount"] = obj[@"unread_reaction_count"];
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGChatUnreadReactionsDidChangeNotification
						  object:obj[@"chat_id"]];
		return;
	}
	if ([type isEqualToString:@"updateChatMessageAutoDeleteTime"]) {
		NSMutableDictionary *info = self.chatsById[obj[@"chat_id"]];
		if (info)
			info[@"autoDeleteSeconds"] = obj[@"message_auto_delete_time"] ?: @(0);
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGChatMessageAutoDeleteTimeDidChangeNotification
						  object:obj[@"chat_id"]];
		return;
	}
	if ([type isEqualToString:@"updateChatOnlineMemberCount"]) {
		NSMutableDictionary *info = self.chatsById[obj[@"chat_id"]];
		if (info)
			info[@"onlineMemberCount"] = obj[@"online_member_count"] ?: @(0);
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGChatOnlineMemberCountDidChangeNotification
						  object:obj[@"chat_id"]
						userInfo:@{TGChatOnlineMemberCountKey : obj[@"online_member_count"] ?: @(0)}];
		return;
	}
	if ([type isEqualToString:@"updateChatPendingJoinRequests"]) {
		NSDictionary *info = [obj[@"pending_join_requests"] isKindOfClass:NSDictionary.class]
			? obj[@"pending_join_requests"]
			: nil;
		NSNumber *count = [info[@"total_count"] isKindOfClass:NSNumber.class] ? info[@"total_count"] : @(0);
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGChatPendingJoinRequestsDidChangeNotification
						  object:obj[@"chat_id"]
						userInfo:@{TGChatPendingJoinRequestsCountKey : count}];
		return;
	}
	if ([type isEqualToString:@"updateChatBlockList"]) {
		[self handleUpdateChatBlockList:obj];
		return;
	}
	if ([type isEqualToString:@"updateChatBackground"]) {
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGChatBackgroundDidChangeNotification
						  object:obj[@"chat_id"]];
		return;
	}
	if ([type isEqualToString:@"updateDefaultBackground"]) {
		BOOL forDarkTheme = [obj[@"for_dark_theme"] boolValue];
		NSDictionary *backgroundRow = TGASBackgroundRow(obj[@"background"]);
		if (!forDarkTheme) {
			BOOL isPhoto = backgroundRow && [backgroundRow[@"kind"] isEqualToString:@"wallpaper"];
			[TGTheme shared].defaultBackgroundId = isPhoto ? backgroundRow[@"id"] : nil;
		}
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGChatBackgroundDidChangeNotification
						  object:nil
						userInfo:backgroundRow ? @{TGDefaultBackgroundRowKey : backgroundRow} : nil];
		return;
	}
	if ([type isEqualToString:@"updateChatTheme"]) {
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGChatThemeDidChangeNotification
						  object:obj[@"chat_id"]];
		return;
	}
	if ([type isEqualToString:@"updateChatMessageSender"]) {
		NSNumber *senderChatId = obj[@"chat_id"];
		int64_t senderId = 0;
		BOOL isChat = NO;
		[self parseMessageSender:obj[@"message_sender_id"] senderId:&senderId isChat:&isChat];
		if (senderChatId)
			[[NSNotificationCenter defaultCenter]
				postNotificationName:TGChatMessageSenderDidChangeNotification
							  object:senderChatId
							userInfo:@{TGChatMessageSenderIdKey : @(senderId),
									   TGChatMessageSenderIsChatKey : @(isChat)}];
		return;
	}
	if ([type isEqualToString:@"updateChatHasScheduledMessages"]) {
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGChatHasScheduledMessagesDidChangeNotification
						  object:obj[@"chat_id"]];
		return;
	}
	if ([type isEqualToString:@"updateInstalledStickerSets"]) {
		NSString *stickerType = obj[@"sticker_type"][@"@type"];
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGInstalledStickerSetsDidChangeNotification
						  object:nil
						userInfo:@{TGInstalledStickerSetsTypeKey : stickerType ?: @""}];
		return;
	}
	if ([type isEqualToString:@"updateTrendingStickerSets"]) {
		NSString *stickerType = obj[@"sticker_type"][@"@type"];
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGTrendingStickerSetsDidChangeNotification
						  object:nil
						userInfo:@{TGTrendingStickerSetsTypeKey : stickerType ?: @""}];
		return;
	}
	if ([type isEqualToString:@"updateRecentStickers"]) {
		if ([obj[@"is_attached"] boolValue])
			return;
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGRecentStickersDidChangeNotification
						  object:nil];
		return;
	}
	if ([type isEqualToString:@"updateFavoriteStickers"]) {
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGFavoriteStickersDidChangeNotification
						  object:nil];
		return;
	}
	if ([type isEqualToString:@"updateSavedAnimations"]) {
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGSavedAnimationsDidChangeNotification
						  object:nil];
		return;
	}
	if ([type isEqualToString:@"updateSecretChat"]) {
		NSDictionary *secretChat = [obj[@"secret_chat"] isKindOfClass:NSDictionary.class]
			? obj[@"secret_chat"]
			: nil;
		NSNumber *secretId = [secretChat[@"id"] isKindOfClass:NSNumber.class] ? secretChat[@"id"] : nil;
		if (secretId)
			[[NSNotificationCenter defaultCenter]
				postNotificationName:TGSecretChatStateDidChangeNotification
							  object:secretId];
		return;
	}
	if ([type isEqualToString:@"updateAvailableMessageEffects"]) {
		NSArray *reactionIds = obj[@"reaction_effect_ids"];
		NSArray *stickerIds = obj[@"sticker_effect_ids"];
		self.availableEffectReactionIds =
			[reactionIds isKindOfClass:NSArray.class] ? reactionIds : @[];
		self.availableEffectStickerIds =
			[stickerIds isKindOfClass:NSArray.class] ? stickerIds : @[];
		return;
	}
	if ([type isEqualToString:@"updateDefaultReactionType"]) {
		[self applyServerDefaultReactionType:obj[@"reaction_type"]];
		return;
	}
	if ([type isEqualToString:@"updateDefaultPaidReactionType"]) {
		[self applyServerDefaultPaidReactionType:obj[@"type"]];
		return;
	}
	if ([type isEqualToString:@"updateTextCompositionStyles"]) {
		NSMutableArray *styles = [NSMutableArray array];
		for (NSDictionary *raw in obj[@"styles"]) {
			if (![raw isKindOfClass:NSDictionary.class])
				continue;
			NSString *name = [raw[@"name"] isKindOfClass:NSString.class] ? raw[@"name"] : @"";
			if (!name.length)
				continue;
			NSString *title = [raw[@"title"] isKindOfClass:NSString.class] ? raw[@"title"] : name;
			[styles addObject:@{@"name" : name, @"title" : title}];
		}
		self.textCompositionStyles = styles;
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGAiWritingStylesDidChangeNotification
						  object:nil];
		return;
	}
	if ([type isEqualToString:@"updateChatMember"]) {
		NSNumber *memberChatId = obj[@"chat_id"];
		int64_t affectedUserId = [obj[@"new_chat_member"][@"member_id"][@"user_id"] longLongValue];
		if (memberChatId && affectedUserId)
			[[NSNotificationCenter defaultCenter]
				postNotificationName:TGChatMemberDidChangeNotification
							  object:memberChatId
							userInfo:@{TGChatMemberUserIdKey : @(affectedUserId)}];
		return;
	}
	if ([type isEqualToString:@"updateChatPermissions"]) {
		NSNumber *permsChatId = obj[@"chat_id"];
		NSMutableDictionary *permsInfo = permsChatId ? self.chatsById[permsChatId] : nil;
		if (permsInfo)
			permsInfo[@"permissions"] = obj[@"permissions"];
		if (permsChatId)
			[[NSNotificationCenter defaultCenter]
				postNotificationName:TGChatPermissionsDidChangeNotification
							  object:permsChatId];
		return;
	}
	if ([type isEqualToString:@"updateSupergroup"] ||
		[type isEqualToString:@"updateBasicGroup"]) {
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGChatPermissionsDidChangeNotification
						  object:nil];
	}
	if ([type isEqualToString:@"updateForumTopicInfo"]) {
		NSDictionary *topicInfo = [obj[@"info"] isKindOfClass:NSDictionary.class] ? obj[@"info"] : nil;
		TGPostForumTopicChange(self, [topicInfo[@"chat_id"] longLongValue],
			(int32_t)[topicInfo[@"forum_topic_id"] longLongValue]);
		return;
	}
	if ([type isEqualToString:@"updateForumTopic"]) {
		int64_t topicChatId = [obj[@"chat_id"] longLongValue];
		int32_t topicId = (int32_t)[obj[@"forum_topic_id"] longLongValue];
		NSDictionary *topicSettings = [obj[@"notification_settings"] isKindOfClass:NSDictionary.class]
			? obj[@"notification_settings"]
			: nil;
		[self cacheForumTopicNotificationSettingsForChat:topicChatId
													topic:topicId
											   useDefault:[topicSettings[@"use_default_mute_for"] boolValue]
												  muteFor:[topicSettings[@"mute_for"] longLongValue]];
		TGPostForumTopicChange(self, topicChatId, topicId);
		return;
	}
	if ([type isEqualToString:@"updateChatActionBar"]) {
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGChatActionBarDidChangeNotification
						  object:obj[@"chat_id"]
						userInfo:@{@"action_bar" : TGChatActionBarInfo(obj[@"action_bar"])}];
		return;
	}
	if ([type isEqualToString:@"updateConnectionState"]) {
		[self handleUpdateConnectionState:obj];
		return;
	}
	if ([type isEqualToString:@"updateNewCallSignalingData"]) {
		int32_t callId = [obj[@"call_id"] intValue];
		if (callId != [TGCall shared].callId)
			return;
		NSData *data = TGCliBase64(obj[@"data"]);
		[[TGCall shared] handleSignalingData:data];
		return;
	}

	if ([type isEqualToString:@"updateCall"]) {
		[[TGCall shared] handleUpdate:obj[@"call"]];
		return;
	}

	if ([type isEqualToString:@"updateGroupCall"]) {
		NSDictionary *groupCall = [obj[@"group_call"] isKindOfClass:NSDictionary.class] ? obj[@"group_call"] : nil;
		int32_t groupCallId = [groupCall[@"id"] intValue];
		if (groupCallId)
			[[NSNotificationCenter defaultCenter]
				postNotificationName:TGGroupCallDidChangeNotification
							  object:@(groupCallId)];
		return;
	}

	if ([type isEqualToString:@"updateGroupCallParticipant"]) {
		int32_t groupCallId = [obj[@"group_call_id"] intValue];
		if (groupCallId)
			[[NSNotificationCenter defaultCenter]
				postNotificationName:TGGroupCallDidChangeNotification
							  object:@(groupCallId)];
		return;
	}

	if ([type isEqualToString:@"updateFileDownloads"] ||
		[type isEqualToString:@"updateFileAddedToDownloads"] ||
		[type isEqualToString:@"updateFileRemovedFromDownloads"]) {
		[self handleUpdateDownloads:obj];
		return;
	}

	if ([type isEqualToString:@"updateFile"]) {
		[self handleUpdateFile:obj];
		return;
	}

	if ([type hasPrefix:@"updateStory"] ||
		[type isEqualToString:@"updateChatActiveStories"]) {
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGStoryUpdateNotification
						  object:obj];
		return;
	}

	if ([type isEqualToString:@"updateChatAction"]) {
		[self handleUpdateChatAction:obj];
		return;
	}

	if ([type isEqualToString:@"updateSupergroup"]) {
		[self handleUpdateSupergroup:obj];
		return;
	}

	if ([type isEqualToString:@"updateSupergroupFullInfo"]) {
		[self handleUpdateSupergroupFullInfo:obj];
		return;
	}

	if ([type isEqualToString:@"updateUserStatus"]) {
		[self handleUpdateUserStatus:obj];
		return;
	}

	if ([type isEqualToString:@"updateChatFolders"]) {
		[self handleUpdateChatFolders:obj];
		return;
	}
	if ([type isEqualToString:@"updateEmojiChatThemes"]) {
		[self handleUpdateEmojiChatThemes:obj];
		return;
	}
	if ([type isEqualToString:@"updateAccentColors"]) {
		[self handleUpdateAccentColors:obj];
		return;
	}
	if ([type isEqualToString:@"updateProfileAccentColors"]) {
		[self handleUpdateProfileAccentColors:obj];
		return;
	}
	if ([type isEqualToString:@"updateWebBrowserSettings"]) {
		[self handleUpdateWebBrowserSettings:obj];
		return;
	}
	if ([type isEqualToString:@"updateFreezeState"]) {
		[self handleUpdateFreezeState:obj];
		return;
	}
	if ([type isEqualToString:@"updateAgeVerificationParameters"]) {
		[self handleUpdateAgeVerificationParameters:obj];
		return;
	}
	if ([type isEqualToString:@"updateSpeechRecognitionTrial"]) {
		[self handleUpdateSpeechRecognitionTrial:obj];
		return;
	}
	if ([type isEqualToString:@"updateUnconfirmedSession"]) {
		[self handleUpdateUnconfirmedSession:obj];
		return;
	}
	if ([type isEqualToString:@"updateTermsOfService"]) {
		[self handleUpdateTermsOfService:obj];
		return;
	}
	if ([type isEqualToString:@"updateOption"] &&
		[obj[@"name"] isEqualToString:@"ignore_sensitive_content_restrictions"]) {
		NSDictionary *value = [obj[@"value"] isKindOfClass:NSDictionary.class] ? obj[@"value"] : nil;
		self.ignoresSensitiveContentRestrictions = [value[@"value"] boolValue];
		return;
	}
	if ([type isEqualToString:@"updateOption"] &&
		[obj[@"name"] isEqualToString:@"can_ignore_sensitive_content_restrictions"]) {
		NSDictionary *value = [obj[@"value"] isKindOfClass:NSDictionary.class] ? obj[@"value"] : nil;
		self.canIgnoreSensitiveContentRestrictions = [value[@"value"] boolValue];
		return;
	}
	if ([type isEqualToString:@"updateOption"] &&
		[obj[@"name"] isEqualToString:@"pinned_forum_topic_count_max"]) {
		NSDictionary *value = [obj[@"value"] isKindOfClass:NSDictionary.class] ? obj[@"value"] : nil;
		NSInteger max = [value[@"value"] integerValue];
		if (max > 0)
			self.pinnedForumTopicCountMax = max;
		return;
	}
	if ([type isEqualToString:@"updateOption"] &&
		[obj[@"name"] isEqualToString:@"pinned_chat_count_max"]) {
		NSDictionary *value = [obj[@"value"] isKindOfClass:NSDictionary.class] ? obj[@"value"] : nil;
		NSInteger max = [value[@"value"] integerValue];
		if (max > 0)
			self.pinnedChatCountMax = max;
		return;
	}
	if ([type isEqualToString:@"updateOption"] &&
		[obj[@"name"] isEqualToString:@"pinned_archived_chat_count_max"]) {
		NSDictionary *value = [obj[@"value"] isKindOfClass:NSDictionary.class] ? obj[@"value"] : nil;
		NSInteger max = [value[@"value"] integerValue];
		if (max > 0)
			self.pinnedArchivedChatCountMax = max;
		return;
	}
	if ([type isEqualToString:@"updateChatHasProtectedContent"]) {
		int64_t protectedChatId = [obj[@"chat_id"] longLongValue];
		BOOL nowProtected = [obj[@"has_protected_content"] boolValue];
		NSMutableDictionary *knownChat = [self.chatsById[@(protectedChatId)] mutableCopy];
		if (knownChat) {
			knownChat[@"hasProtectedContent"] = @(nowProtected);
			self.chatsById[@(protectedChatId)] = knownChat;
		}
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGChatProtectedContentDidChangeNotification
						  object:self
						userInfo:@{
							@"chatId" : @(protectedChatId),
							@"hasProtectedContent" : @(nowProtected)
						}];
		return;
	}

	if ([type isEqualToString:@"updateUnreadChatCount"]) {
		TGChatListId chatCountListId = TGChatListIdFromObject(obj[@"chat_list"]);
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGUnreadChatCountDidChangeNotification
						  object:self
						userInfo:@{
							@"listId" : @(chatCountListId),
							@"unreadChats" : @(TGUnreadChatCountFromUpdate(obj, YES)),
							@"unmutedUnreadChats" : @(TGUnreadChatCountFromUpdate(obj, NO))
						}];
		return;
	}
	if ([type isEqualToString:@"updateUnreadMessageCount"]) {
		NSNumber *unread = [obj[@"unread_count"] isKindOfClass:NSNumber.class] ? obj[@"unread_count"] : nil;
		NSNumber *unmutedUnread = [obj[@"unread_unmuted_count"] isKindOfClass:NSNumber.class]
			? obj[@"unread_unmuted_count"] : nil;
		if (unread && unmutedUnread) {
			TGChatListId listId = TGChatListIdFromObject(obj[@"chat_list"]);
			[[NSNotificationCenter defaultCenter]
				postNotificationName:TGUnreadMessageCountDidChangeNotification
							  object:self
							userInfo:@{
								@"listId" : @(listId),
								@"unreadCount" : unread,
								@"unmutedUnreadCount" : unmutedUnread
							}];
		}
		return;
	}
	if ([type hasPrefix:@"updateQuickReplyShortcut"]) {
		[self handleQuickReplyUpdate:obj type:type];
		return;
	}
	if ([type isEqualToString:@"updateDirectMessagesChatTopic"]) {
		[self handleDirectMessagesTopicUpdate:obj];
		return;
	}
	if ([type isEqualToString:@"error"]) {
		[self handleErrorObject:obj];
		return;
	}
}

- (void)handleMeUser:(NSDictionary *)obj {
	self.me = @{
		@"id" : obj[@"id"] ?: @(0),
		@"first_name" : obj[@"first_name"] ?: @"",
		@"last_name" : obj[@"last_name"] ?: @"",
		@"username" : TGActiveUsername(obj) ?: (obj[@"username"] ?: @""),
		@"phone" : obj[@"phone_number"] ?: @"",
		@"is_premium" : obj[@"is_premium"] ?: @NO,
	};
	NSLog(@"TGClient: signed in as user %@", self.me[@"id"]);
	[[TGAccountManager shared] rememberCurrentAccount];

	int64_t ownId = [self savedMessagesChatId];
	if (ownId != 0) {
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setObject:@(ownId) forKey:TGSavedMessagesChatIdKey()];
		NSMutableDictionary *own = self.chatsById[@(ownId)];
		if (own) {
			[self applySavedMessagesIdentityTo:own];
			[self rebuildChats];
		}
	}
}

- (void)announceFloodWaitIn:(NSDictionary *)result {
	NSInteger seconds = TGResultFloodWaitSeconds(result);
	if (seconds <= 0)
		return;
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGClientFloodWaitNotification
					  object:self
					userInfo:@{TGClientFloodWaitSecondsKey : @(seconds)}];
}

- (void)handleUpdateChatBlockList:(NSDictionary *)obj {
	int64_t chatId = [obj[@"chat_id"] longLongValue];
	if (!chatId)
		return;

	NSDictionary *info = self.chatsById[@(chatId)];
	if (info) {
		int64_t peerUserId = 0;
		if ([info[@"isPrivate"] boolValue])
			peerUserId = chatId;
		else if ([info[@"isSecretChat"] boolValue])
			peerUserId = [self secretChatUserIdForChat:chatId];
		if (peerUserId) {
			[[NSNotificationCenter defaultCenter]
				postNotificationName:TGUserBlockedStateDidChangeNotification
							  object:@(peerUserId)];
		} else if ([info[@"isGroup"] boolValue]) {
			[[NSNotificationCenter defaultCenter]
				postNotificationName:TGUserBlockedStateDidChangeNotification
							  object:@(chatId)];
		}
		return;
	}

	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)} completion:^(NSDictionary *chat) {
		NSString *kind = chat[@"type"][@"@type"];
		if ([kind isEqualToString:@"chatTypeSupergroup"]) {
			[[NSNotificationCenter defaultCenter]
				postNotificationName:TGUserBlockedStateDidChangeNotification
							  object:@(chatId)];
			return;
		}
		if (![kind isEqualToString:@"chatTypePrivate"] && ![kind isEqualToString:@"chatTypeSecret"])
			return;
		int64_t peerUserId = [chat[@"type"][@"user_id"] longLongValue];
		if (!peerUserId)
			return;
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGUserBlockedStateDidChangeNotification
						  object:@(peerUserId)];
	}];
}

- (void)handleUpdateUser:(NSDictionary *)obj {
	NSDictionary *u = obj[@"user"];
	NSString *name = TGUserDisplayName(u);
	BOOL contactStatusChanged = NO;
	if (u[@"id"]) {
		[self capUserRegistriesIfNeeded];
		if (name.length)
			self.usersById[u[@"id"]] = name;
		NSDictionary *previous = self.userRecordsById[u[@"id"]];
		if (previous &&
			([previous[@"is_contact"] boolValue] != [u[@"is_contact"] boolValue] ||
				[previous[@"is_mutual_contact"] boolValue] !=
					[u[@"is_mutual_contact"] boolValue]))
			contactStatusChanged = YES;
		self.userRecordsById[u[@"id"]] = u;
		if (self.me[@"id"] && [self.me[@"id"] isEqual:u[@"id"]])
			[self handleMeUser:u];
	}
	[self cacheProfilePhoto:u];

	if (u[@"id"]) {
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGUserProfileDidChangeNotification
						  object:self
						userInfo:@{@"userId" : u[@"id"]}];
	}
	if (contactStatusChanged)
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGContactsDidChangeNotification
						  object:nil];
}

- (void)handleUpdateUserFullInfo:(NSDictionary *)obj {
	NSNumber *userId = obj[@"user_id"];
	if (![userId isKindOfClass:NSNumber.class])
		return;
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGUserProfileDidChangeNotification
					  object:self
					userInfo:@{@"userId" : userId}];
}

- (void)handleUpdateMessageInteractionInfo:(NSDictionary *)obj {
	NSDictionary *info = [obj[@"interaction_info"] isKindOfClass:NSDictionary.class]
		? obj[@"interaction_info"]
		: nil;
	int64_t chatId = [obj[@"chat_id"] longLongValue];
	NSArray *chips = [TGClient reactionChipsFromInteractionInfo:info chatId:chatId];
	NSDictionary *replyInfo = [info[@"reply_info"] isKindOfClass:NSDictionary.class]
		? info[@"reply_info"]
		: nil;
	NSDictionary *payload = @{
		@"chatId" : obj[@"chat_id"] ?: @(0),
		@"messageId" : obj[@"message_id"] ?: @(0),
		@"chips" : chips,
		@"reactions" : [TGClient reactionSummaryFromChips:chips],
		@"views" : info[@"view_count"] ?: @(0),
		@"commentCount" : replyInfo[@"reply_count"] ?: @(0),
	};
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGMessageInteractionInfoDidChangeNotification
					  object:payload];
}

- (void)handleUpdateNewMessage:(NSDictionary *)obj {
	NSDictionary *m = obj[@"message"];
	if (m)
		TGPostMessageChange(self, [m[@"chat_id"] longLongValue], TGFlattenMessage(m, TGCurrentFlattenContext()), 0);
}

- (void)handleUpdateMessageSent:(NSDictionary *)obj {
	NSDictionary *m = obj[@"message"];
	int64_t oldId = [obj[@"old_message_id"] longLongValue];
	if (!m)
		return;
	TGPostMessageChange(self, [m[@"chat_id"] longLongValue], TGFlattenMessage(m, TGCurrentFlattenContext()), oldId);
}

- (void)handleUpdateMessageContent:(NSDictionary *)obj {
	int64_t chatId = [obj[@"chat_id"] longLongValue];
	int64_t messageId = [obj[@"message_id"] longLongValue];
	if (messageId == 0) {
		TGPostMessageChange(self, chatId, nil, 0);
		return;
	}

	__weak typeof(self) weakSelf = self;
	[self messageWithId:messageId inChat:chatId completion:^(NSDictionary *flat) {
		TGClient *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!flat) {
			TGPostMessageChange(strongSelf, chatId, nil, 0);
			return;
		}
		TGPostMessageChange(strongSelf, chatId, flat, messageId);
	}];
}

- (void)handleUpdatePoll:(NSDictionary *)obj {
	NSDictionary *fields = TGFlattenPollFields(obj[@"poll"], nil);
	if (![fields[@"pollId"] longLongValue])
		return;
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGPollDidChangeNotification
					  object:self
					userInfo:@{TGPollDataKey : fields}];
}

- (void)handleUpdateDeleteMessages:(NSDictionary *)obj {
	if ([obj[@"is_permanent"] boolValue]) {
		int64_t chatId = [obj[@"chat_id"] longLongValue];
		for (NSNumber *mid in obj[@"message_ids"])
			TGPostMessageChange(self, chatId, nil, [mid longLongValue]);
	}
}

- (void)handleUpdateConnectionState:(NSDictionary *)obj {
	NSString *st = obj[@"state"][@"@type"];
	NSLog(@"TGClient: connection %@", st);

	TGConnectionState state = TGConnectionStateUnknown;
	if ([st isEqualToString:@"connectionStateWaitingForNetwork"]) {
		state = TGConnectionStateWaitingForNetwork;
	} else if ([st isEqualToString:@"connectionStateConnecting"]) {
		state = TGConnectionStateConnecting;
	} else if ([st isEqualToString:@"connectionStateConnectingToProxy"]) {
		state = TGConnectionStateConnectingToProxy;
	} else if ([st isEqualToString:@"connectionStateUpdating"]) {
		state = TGConnectionStateUpdating;
	} else if ([st isEqualToString:@"connectionStateReady"]) {
		state = TGConnectionStateReady;
	}

	self.connectionState = state;
	if (state == TGConnectionStateReady)
		[[TGBackgroundSession shared] noteConnectionReady];

	NSMutableDictionary *info = [NSMutableDictionary dictionary];
	[info setObject:[NSNumber numberWithInteger:(NSInteger)state] forKey:TGConnectionStateKey];
	NSString *broadcastTitle = [self connectionStateTitleForState:state];
	if (broadcastTitle)
		[info setObject:broadcastTitle forKey:TGConnectionStateTitleKey];
	NSNotificationCenter *centre = [NSNotificationCenter defaultCenter];
	[centre postNotificationName:TGConnectionStateDidChangeNotification
						  object:self
						userInfo:info];
}

- (NSDictionary *)knownStateOfFile:(long long)fileId {
	if (fileId <= 0)
		return nil;
	return self.fileStates[@(fileId)];
}

- (void)rememberStateOfFileObject:(NSDictionary *)file notify:(BOOL)notify {
	NSDictionary *state = TGFlattenFileObjectState(file);
	long long fileId = [state[@"fileId"] longLongValue];
	if (fileId <= 0)
		return;
	NSNumber *key = @(fileId);
	if (!self.fileStates[key])
		[self.fileStatesOrder addObject:key];
	NSArray *stale = TGCacheTrimKeys(self.fileStatesOrder, 600, 450);
	if (stale.count) {
		[self.fileStates removeObjectsForKeys:stale];
		[self.fileStatesOrder removeObjectsInArray:stale];
	}
	NSDictionary *previous = self.fileStates[key];
	self.fileStates[key] = state;
	if (!notify || (previous && [previous isEqualToDictionary:state]))
		return;
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGFileStateDidChangeNotification
					  object:nil
					userInfo:@{TGFileStateFileIdKey : @(fileId)}];
}

- (void)handleUpdateDownloads:(NSDictionary *)obj {
	NSDictionary *summary = TGDownloadsSummaryFromUpdate(obj);
	NSDictionary *info = summary ? @{TGDownloadsSummaryKey : summary} : nil;
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGDownloadsDidChangeNotification
					  object:self
					userInfo:info];
}

- (void)handleUpdateFile:(NSDictionary *)obj {
	NSDictionary *file = obj[@"file"];
	NSDictionary *local = file[@"local"];
	[self rememberStateOfFileObject:file notify:YES];
	if ([local[@"is_downloading_active"] boolValue]) {
		double expected = [file[@"expected_size"] doubleValue];
		double got = [local[@"downloaded_size"] doubleValue];
		if (expected > 0)
			[[NSNotificationCenter defaultCenter]
				postNotificationName:TGFileProgressDidChangeNotification
							  object:self
							userInfo:@{
								TGFileProgressFileIdKey : @([file[@"id"] longLongValue]),
								TGFileProgressValueKey : @((float)(got / expected)),
							}];
	}
	NSDictionary *remote = file[@"remote"];
	if ([remote[@"is_uploading_active"] boolValue] ||
		[remote[@"is_uploading_completed"] boolValue]) {
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGStoryUpdateNotification
						  object:obj];
	}
}

- (void)handleUpdateChatAction:(NSDictionary *)obj {
	NSString *kind = obj[@"action"][@"@type"];
	NSString *phrase = TGChatActionBarePhraseForKind(kind);

	int64_t actingChat = [obj[@"chat_id"] longLongValue];
	int64_t topicId = TGChatActionTopicId(obj[@"topic_id"]);
	int64_t senderId = TGChatActionSenderId(obj[@"sender_id"]);
	BOOL senderIsChat = TGChatActionSenderIsChat(obj[@"sender_id"]);
	NSNumber *chatKey = @(actingChat);
	NSNumber *topicKey = @(topicId);
	NSNumber *senderKey = @(senderId);

	NSMutableDictionary *chatTimers = self.chatActionTimers[chatKey];
	NSMutableDictionary *topicTimers = chatTimers[topicKey];
	[(NSTimer *)topicTimers[senderKey] invalidate];
	[topicTimers removeObjectForKey:senderKey];
	if (!topicTimers.count)
		[chatTimers removeObjectForKey:topicKey];

	NSMutableDictionary *acting = self.chatsById[chatKey];
	NSMutableDictionary *actionsByTopic = acting[@"actionsByTopic"];
	NSMutableDictionary *topicActions = actionsByTopic[topicKey];
	if (phrase.length) {
		if (!actionsByTopic) {
			actionsByTopic = [NSMutableDictionary dictionary];
			acting[@"actionsByTopic"] = actionsByTopic;
		}
		if (!topicActions) {
			topicActions = [NSMutableDictionary dictionary];
			actionsByTopic[topicKey] = topicActions;
		}
		topicActions[senderKey] = @{
			@"phrase" : phrase,
			@"timestamp" : @([NSDate timeIntervalSinceReferenceDate]),
			@"isChat" : @(senderIsChat),
		};
	} else if (topicActions) {
		[topicActions removeObjectForKey:senderKey];
		if (!topicActions.count) {
			[actionsByTopic removeObjectForKey:topicKey];
			if (!actionsByTopic.count)
				[acting removeObjectForKey:@"actionsByTopic"];
		}
	}

	NSString *displayPhrase = phrase;
	if (acting) {
		displayPhrase = TGChatActionDisplayPhrase(self, acting, acting[@"actionsByTopic"][topicKey]);
		acting[@"action"] = TGChatActionDisplayPhrase(self, acting, TGChatActionFlattenTopics(acting[@"actionsByTopic"]));
		[self rebuildChats];
	}
	TGPostChatAction(self, actingChat, topicId, displayPhrase.length ? displayPhrase : nil);

	if (phrase.length) {
		if (!chatTimers) {
			chatTimers = [NSMutableDictionary dictionary];
			self.chatActionTimers[chatKey] = chatTimers;
		}
		if (!topicTimers) {
			topicTimers = [NSMutableDictionary dictionary];
			chatTimers[topicKey] = topicTimers;
		}
		NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:6.0
														  target:self
														selector:@selector(expireChatActionTimer:)
														userInfo:@{@"chatKey" : chatKey, @"topicKey" : topicKey, @"senderKey" : senderKey}
														 repeats:NO];
		topicTimers[senderKey] = timer;
	}
}

- (void)invalidateAllChatActionTimers {
	for (NSMutableDictionary *chatTimers in self.chatActionTimers.allValues)
		for (NSMutableDictionary *topicTimers in chatTimers.allValues)
			for (NSTimer *timer in topicTimers.allValues)
				[timer invalidate];
	[self.chatActionTimers removeAllObjects];
}

- (void)expireChatActionTimer:(NSTimer *)timer {
	NSDictionary *timerInfo = timer.userInfo;
	NSNumber *chatKey = timerInfo[@"chatKey"];
	NSNumber *topicKey = timerInfo[@"topicKey"];
	NSNumber *senderKey = timerInfo[@"senderKey"];

	NSMutableDictionary *chatTimers = self.chatActionTimers[chatKey];
	NSMutableDictionary *topicTimers = chatTimers[topicKey];
	[topicTimers removeObjectForKey:senderKey];
	if (!topicTimers.count)
		[chatTimers removeObjectForKey:topicKey];
	if (!chatTimers.count)
		[self.chatActionTimers removeObjectForKey:chatKey];

	NSMutableDictionary *acting = self.chatsById[chatKey];
	NSMutableDictionary *actionsByTopic = acting[@"actionsByTopic"];
	NSMutableDictionary *topicActions = actionsByTopic[topicKey];
	[topicActions removeObjectForKey:senderKey];
	if (!topicActions.count) {
		[actionsByTopic removeObjectForKey:topicKey];
		if (!actionsByTopic.count)
			[acting removeObjectForKey:@"actionsByTopic"];
	}

	NSString *displayPhrase = @"";
	if (acting) {
		displayPhrase = TGChatActionDisplayPhrase(self, acting, acting[@"actionsByTopic"][topicKey]);
		acting[@"action"] = TGChatActionDisplayPhrase(self, acting, TGChatActionFlattenTopics(acting[@"actionsByTopic"]));
		[self rebuildChats];
	}
	TGPostChatAction(self, [chatKey longLongValue], [topicKey longLongValue], displayPhrase.length ? displayPhrase : nil);
}

- (void)handleUpdateSupergroup:(NSDictionary *)obj {
	NSDictionary *group = obj[@"supergroup"];
	NSNumber *groupId = group[@"id"];
	if (!groupId)
		return;
	BOOL isForum = [group[@"is_forum"] boolValue];
	BOOL isAdministeredDirectMessagesGroup =
		[group[@"is_administered_direct_messages_group"] boolValue];
	NSDictionary *verification = [group[@"verification_status"] isKindOfClass:NSDictionary.class]
		? group[@"verification_status"]
		: nil;
	BOOL isVerified = [verification[@"is_verified"] boolValue];
	BOOL isScam = [verification[@"is_scam"] boolValue];
	BOOL isFake = [verification[@"is_fake"] boolValue];
	BOOL knownSame = self.forumSupergroups[groupId] &&
		[self.forumSupergroups[groupId] boolValue] == isForum &&
		self.directMessagesSupergroups[groupId] &&
		[self.directMessagesSupergroups[groupId] boolValue] ==
			isAdministeredDirectMessagesGroup;
	if (knownSame) {
		for (NSMutableDictionary *chat in self.chatsById.allValues) {
			if (![chat[@"supergroupId"] isEqual:groupId])
				continue;
			if ([chat[@"isVerified"] boolValue] != isVerified ||
				[chat[@"isScam"] boolValue] != isScam ||
				[chat[@"isFake"] boolValue] != isFake)
				knownSame = NO;
			break;
		}
	}
	if (knownSame)
		return;
	[self capSupergroupFlagRegistriesIfNeeded];
	self.forumSupergroups[groupId] = @(isForum);
	self.directMessagesSupergroups[groupId] = @(isAdministeredDirectMessagesGroup);

	BOOL changed = NO;
	for (NSMutableDictionary *chat in self.chatsById.allValues) {
		if (![chat[@"supergroupId"] isEqual:groupId])
			continue;
		chat[@"isForum"] = @(isForum);
		chat[@"isAdministeredDirectMessagesGroup"] = @(isAdministeredDirectMessagesGroup);
		chat[@"isVerified"] = @(isVerified);
		chat[@"isScam"] = @(isScam);
		chat[@"isFake"] = @(isFake);
		changed = YES;
	}
	if (changed)
		[self rebuildChats];
}

- (void)handleUpdateSupergroupFullInfo:(NSDictionary *)obj {
	NSNumber *supergroupId = obj[@"supergroup_id"];
	NSDictionary *fullInfo = [obj[@"supergroup_full_info"] isKindOfClass:NSDictionary.class]
		? obj[@"supergroup_full_info"]
		: nil;
	if (![supergroupId isKindOfClass:NSNumber.class] || !fullInfo)
		return;
	NSNumber *slowModeDelay = [fullInfo[@"slow_mode_delay"] isKindOfClass:NSNumber.class]
		? fullInfo[@"slow_mode_delay"]
		: @0;
	for (NSNumber *chatId in self.chatsById.allKeys) {
		NSDictionary *chat = self.chatsById[chatId];
		if (![chat[@"supergroupId"] isEqual:supergroupId])
			continue;
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGChatSlowModeDelayDidChangeNotification
						  object:chatId
						userInfo:@{TGChatSlowModeDelayKey : slowModeDelay}];
	}
}

- (void)handleUpdateUserStatus:(NSDictionary *)obj {
	NSDictionary *status = TGUserStatusInfo(obj[@"status"]);

	NSDictionary *record = obj[@"user_id"] ? self.userRecordsById[obj[@"user_id"]] : nil;
	if (record && obj[@"status"]) {
		NSMutableDictionary *fresh = [record mutableCopy];
		fresh[@"status"] = obj[@"status"];
		self.userRecordsById[obj[@"user_id"]] = fresh;
	}

	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGUserStatusDidChangeNotification
					  object:self
					userInfo:@{@"userId" : obj[@"user_id"] ?: @(0), @"status" : status}];

	NSMutableDictionary *chat = self.chatsById[obj[@"user_id"]];
	if (!chat)
		return;
	BOOL online = [status[@"isOnline"] boolValue];
	if ([chat[@"isOnline"] boolValue] == online)
		return;
	chat[@"isOnline"] = @(online);
	[self rebuildChats];
}

- (void)handleUpdateChatFolders:(NSDictionary *)obj {
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *f in obj[@"chat_folders"]) {
		id nameText = f[@"name"][@"text"][@"text"];
		[out addObject:@{@"id" : f[@"id"] ?: @(0),
			@"title" : [nameText isKindOfClass:[NSString class]] ? nameText : @""}];
	}
	self.folders = out;
	self.folderTagsEnabled = [obj[@"are_tags_enabled"] boolValue];
	self.mainChatListPosition = [obj[@"main_chat_list_position"] integerValue];
	NSLog(@"TGClient: %lu folders", (unsigned long)out.count);
	[self saveCachedFolders];
	[self refreshFolderTagDefinitions];
}

- (void)handleErrorObject:(NSDictionary *)obj {
	NSString *msg = obj[@"message"] ?: @"unknown error";
	NSLog(@"TGClient: ERROR code=%@ msg=%@", obj[@"code"], msg);
	if ([obj[@"code"] intValue] == 404)
		return;
	NSLog(@"TGClient: error: %@", obj);
	if (self.authState != TGAuthStateWaitPhoneNumber &&
		self.authState != TGAuthStateWaitCode &&
		self.authState != TGAuthStateWaitPassword &&
		self.authState != TGAuthStateWaitRegistration)
		return;
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGClientErrorNotification
					  object:self
					userInfo:@{TGClientErrorMessageKey : TGAuthErrorMessage(msg)}];
}

- (void)handleAuthState:(NSDictionary *)state {
	NSString *type = state[@"@type"];
	NSLog(@"TGClient: auth state %@", type);

	TGAuthState s = TGAuthStateUnknown;

	if ([type isEqualToString:@"authorizationStateWaitTdlibParameters"]) {
		[self sendTdlibParameters];
		[self flushPreInitRequests];
		return;
	} else if ([type isEqualToString:@"authorizationStateWaitPremiumPurchase"]) {
		NSString *supportEmail = [state[@"support_email_address"] isKindOfClass:NSString.class]
			? state[@"support_email_address"]
			: @"";
		NSString *message = supportEmail.length
			? [NSString stringWithFormat:TGL(@"Login.PremiumPurchaseRequiredWithEmail",
				@"This phone number requires buying Telegram Premium to register, which this client cannot do. Contact %@ for help."), supportEmail]
			: TGL(@"Login.PremiumPurchaseRequired",
				@"This phone number requires buying Telegram Premium to register, which this client cannot do.");
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGClientErrorNotification
						  object:self
						userInfo:@{TGClientErrorMessageKey : message}];
		[self logOutWithCompletion:nil];
		return;
	} else if ([type isEqualToString:@"authorizationStateWaitPhoneNumber"]) {
		s = TGAuthStateWaitPhoneNumber;
	} else if ([type isEqualToString:@"authorizationStateWaitCode"]) {
		s = TGAuthStateWaitCode;
		NSDictionary *waitCodeInfo = TGAccountCodeInfoDict(state[@"code_info"]);
		NSLog(@"TGClient: code info type=%@ length=%@ timeout=%@",
			waitCodeInfo[@"type"], waitCodeInfo[@"length"], waitCodeInfo[@"timeout"]);
	} else if ([type isEqualToString:@"authorizationStateWaitEmailAddress"]) {
		s = TGAuthStateWaitEmailAddress;
	} else if ([type isEqualToString:@"authorizationStateWaitEmailCode"]) {
		s = TGAuthStateWaitEmailCode;
		NSDictionary *codeInfo = state[@"code_info"];
		NSString *pattern = [codeInfo[@"email_address_pattern"] isKindOfClass:NSString.class]
			? codeInfo[@"email_address_pattern"]
			: @"";
		self.pendingEmailAddressPattern = pattern;
	} else if ([type isEqualToString:@"authorizationStateWaitPassword"]) {
		s = TGAuthStateWaitPassword;
		NSString *hint = [state[@"password_hint"] isKindOfClass:NSString.class]
			? state[@"password_hint"]
			: @"";
		self.pendingPasswordHint = hint;
		self.pendingHasRecoveryEmail = [state[@"has_recovery_email_address"] boolValue];
		NSString *recoveryPattern = [state[@"recovery_email_address_pattern"] isKindOfClass:NSString.class]
			? state[@"recovery_email_address_pattern"]
			: @"";
		self.pendingRecoveryEmailPattern = recoveryPattern;
	} else if ([type isEqualToString:@"authorizationStateWaitRegistration"]) {
		s = TGAuthStateWaitRegistration;
	} else if ([type isEqualToString:@"authorizationStateReady"]) {
		s = TGAuthStateReady;
		if (self.openChatId != 0)
			[self openChat:self.openChatId];
	} else if ([type isEqualToString:@"authorizationStateLoggingOut"]) {
		s = TGAuthStateLoggingOut;
	} else if ([type isEqualToString:@"authorizationStateClosed"]) {
		[self failPendingRequests:@"client closed"];
		if (self.suspending)
			return;
		s = TGAuthStateClosed;
	} else {
		return;
	}

	self.authState = s;
	if (s == TGAuthStateReady) {
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"tgWasSignedIn"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		[self send:@{@"@type" : @"getMe"}];
		[self loadChats];
		[self loadNotificationScopeDefaults];
		[self loadAutosaveSettingsDefaults];
		[self applyPersistedCachePolicyIfDueWithCompletion:nil];
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGContactsDidChangeNotification
						  object:nil];
	}
	if (s == TGAuthStateWaitPhoneNumber || s == TGAuthStateLoggingOut ||
		s == TGAuthStateWaitRegistration) {
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"tgWasSignedIn"];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:TGSavedMessagesChatIdKey()];
		[[NSUserDefaults standardUserDefaults] synchronize];
		self.me = nil;
		[self clearCachedChats];
		if (![TGAccountManager shared].addingAccount)
			[TGDiskCache clearImages];
		[TGRemoteImageView tgPurgeMemoryCache];
		[self invalidateAllChatActionTimers];
		[self.chatsById removeAllObjects];
		[self.chatsConfirmedByServer removeAllObjects];
		[self rebuildChats];
	}
	if (s == TGAuthStateWaitPhoneNumber)
		[self flushPendingPhoneNumber];
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGAuthStateDidChangeNotification
					  object:self
					userInfo:@{TGAuthStateKey : @(s)}];
}

- (void)flushPreInitRequests {
	NSArray *held = self.preInitRequests;
	self.preInitRequests = nil;
	for (NSDictionary *request in held)
		[self send:request];
}

- (void)sendTdlibParameters {
	NSString *scope = [TGAccountManager scopeForSlot:[TGAccountManager shared].currentSlot];
	NSString *db = [TGDiskCache databaseDirectory];

	int SETUP_API_ID(apiId) char *SETUP_API_HASH(apiHash)

		UIDevice *dev = [UIDevice currentDevice];

	self.parametersSent = YES;
	BOOL cachesEnabled = !self.diskCachesDisabledForBackgroundLaunch;
	NSData *encryptionKey = [TGDatabaseEncryptionKey obtainKeyForDatabaseDirectory:db scope:scope];
	NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
	parameters[@"@type"] = @"setTdlibParameters";
	parameters[@"database_directory"] = db;
	parameters[@"files_directory"] = [db stringByAppendingPathComponent:@"files"];
	if (encryptionKey.length)
		parameters[@"database_encryption_key"] = TGBase64Encode(encryptionKey);
	self.parametersUsedDiskCaches = cachesEnabled;
	parameters[@"use_file_database"] = @(cachesEnabled);
	parameters[@"use_chat_info_database"] = @(cachesEnabled);
	parameters[@"use_message_database"] = @(cachesEnabled);
	parameters[@"use_secret_chats"] = @YES;
	parameters[@"api_id"] = @(apiId);
	parameters[@"api_hash"] = [NSString stringWithUTF8String:apiHash];
	parameters[@"system_language_code"] = @"en";
	parameters[@"device_model"] = dev.model ?: @"iPhone";
	parameters[@"system_version"] = dev.systemVersion ?: @"7.1.2";
	parameters[@"application_version"] = @"1.16.48";
	[self sendUnguarded:parameters];
	[self sendUnguarded:@{
		@"@type" : @"setOption",
		@"name" : @"localization_target",
		@"value" : @{@"@type" : @"optionValueString", @"value" : @"ios"},
	}];
}

@end

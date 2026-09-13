#import "TGClient+ChatState.h"
#import "TGClient+ChatList.h"
#import "TGClient+Private.h"
#import "TGClient+SecretChats.h"
#import "TGFlattenChatList.h"
#import "TGLocalization.h"

static NSArray *TGNumberArray(id value) {
	if (![value isKindOfClass:NSArray.class])
		return @[];
	NSMutableArray *out = [NSMutableArray array];
	for (id item in value) {
		if ([item isKindOfClass:NSNumber.class])
			[out addObject:item];
	}
	return out;
}

NSString *const TGChatFoldersDidChangeNotification = @"TGChatFoldersDidChangeNotification";
NSString *const TGUnreadMessageCountDidChangeNotification = @"TGUnreadMessageCountDidChangeNotification";
NSString *const TGUnreadChatCountDidChangeNotification = @"TGUnreadChatCountDidChangeNotification";

static NSMutableSet *TGMarkedUnreadChatIds(void) {
	static NSMutableSet *set = nil;
	if (!set)
		set = [[NSMutableSet alloc] init];
	return set;
}

static void TGSetMarkedUnread(TGClient *client, int64_t chatId, BOOL marked) {
	NSNumber *key = @(chatId);
	if (marked)
		[TGMarkedUnreadChatIds() addObject:key];
	else
		[TGMarkedUnreadChatIds() removeObject:key];
	NSMutableDictionary *info = client.chatsById[key];
	if ([info isKindOfClass:NSMutableDictionary.class])
		info[@"markedUnread"] = @(marked);
}

static NSCache *TGChatTitleCache(void) {
	static NSCache *titles = nil;
	if (!titles) {
		titles = [[NSCache alloc] init];
		titles.countLimit = 200;
	}
	return titles;
}

@interface TGChatListFolderWatcher : NSObject
+ (instancetype)shared;
@end

@implementation TGChatListFolderWatcher

+ (instancetype)shared {
	static TGChatListFolderWatcher *watcher = nil;
	if (!watcher) {
		watcher = [[TGChatListFolderWatcher alloc] init];
		[[TGClient shared] addObserver:watcher
							forKeyPath:@"folders"
							   options:0
							   context:NULL];
	}
	return watcher;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
						change:(NSDictionary *)change
					   context:(void *)context {
	if (![keyPath isEqualToString:@"folders"])
		return;
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGChatFoldersDidChangeNotification
						  object:nil];
	});
}

@end

@implementation TGClient (ChatList)

- (BOOL)chatListsAreLoaded {
	return self.chatListComplete;
}

#pragma mark - shared helpers

- (NSArray *)tgcl_rowsForChatIds:(NSArray *)chatIds {
	NSMutableArray *out = [NSMutableArray array];
	for (NSNumber *chatId in TGNumberArray(chatIds)) {
		NSDictionary *info = self.chatsById[chatId];
		if (info) {
			NSMutableDictionary *row = [info mutableCopy];
			if (![row[@"markedUnread"] isKindOfClass:NSNumber.class])
				row[@"markedUnread"] = @([TGMarkedUnreadChatIds() containsObject:chatId]);
			[out addObject:row];
		} else {
			[out addObject:@{@"id" : chatId, @"title" : @"", @"unread" : @(0)}];
		}
	}
	return out;
}

- (void)tgcl_chatRowsFrom:(NSDictionary *)request completion:(void (^)(NSArray *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:request completion:^(NSDictionary *result) {
		if (!completion)
			return;
		TGClient *strongSelf = weakSelf;
		if (!strongSelf || TGResultIsError(result)) {
			completion(@[]);
			return;
		}
		completion([strongSelf tgcl_rowsForChatIds:result[@"chat_ids"]]);
	}];
}

- (NSDictionary *)tgcl_folderFromTdFolder:(NSDictionary *)folder id:(NSNumber *)folderId {
	if (![folder isKindOfClass:NSDictionary.class])
		return nil;
	NSMutableDictionary *out = [NSMutableDictionary dictionary];
	if (folderId)
		out[@"id"] = folderId;
	out[@"title"] = TGPlainText(folder[@"name"]);
	if ([folder[@"name"] isKindOfClass:NSDictionary.class])
		out[@"wireName"] = folder[@"name"];
	NSString *icon = @"";
	if ([folder[@"icon"] isKindOfClass:NSDictionary.class] &&
		[folder[@"icon"][@"name"] isKindOfClass:NSString.class])
		icon = folder[@"icon"][@"name"];
	out[@"icon"] = icon;
	out[@"colorId"] = folder[@"color_id"] ?: @(-1);
	out[@"isShareable"] = @([folder[@"is_shareable"] boolValue]);
	out[@"pinnedChatIds"] = TGNumberArray(folder[@"pinned_chat_ids"]);
	out[@"includedChatIds"] = TGNumberArray(folder[@"included_chat_ids"]);
	out[@"excludedChatIds"] = TGNumberArray(folder[@"excluded_chat_ids"]);
	out[@"excludeMuted"] = @([folder[@"exclude_muted"] boolValue]);
	out[@"excludeRead"] = @([folder[@"exclude_read"] boolValue]);
	out[@"excludeArchived"] = @([folder[@"exclude_archived"] boolValue]);
	out[@"includeContacts"] = @([folder[@"include_contacts"] boolValue]);
	out[@"includeNonContacts"] = @([folder[@"include_non_contacts"] boolValue]);
	out[@"includeBots"] = @([folder[@"include_bots"] boolValue]);
	out[@"includeGroups"] = @([folder[@"include_groups"] boolValue]);
	out[@"includeChannels"] = @([folder[@"include_channels"] boolValue]);
	return out;
}

- (NSDictionary *)tgcl_tdFolderFrom:(NSDictionary *)folder {
	if (![folder isKindOfClass:NSDictionary.class])
		folder = @{};
	NSString *title = [folder[@"title"] isKindOfClass:NSString.class] ? folder[@"title"] : @"";
	NSString *icon = [folder[@"icon"] isKindOfClass:NSString.class] ? folder[@"icon"] : @"";
	NSNumber *colorId = [folder[@"colorId"] isKindOfClass:NSNumber.class] ? folder[@"colorId"] : @(-1);
	return @{
		@"@type" : @"chatFolder",
		@"name" : TGChatFolderNamePayload(folder[@"wireName"], title),
		@"icon" : @{@"@type" : @"chatFolderIcon", @"name" : icon},
		@"color_id" : colorId,
		@"is_shareable" : @([folder[@"isShareable"] boolValue]),
		@"pinned_chat_ids" : TGNumberArray(folder[@"pinnedChatIds"]),
		@"included_chat_ids" : TGNumberArray(folder[@"includedChatIds"]),
		@"excluded_chat_ids" : TGNumberArray(folder[@"excludedChatIds"]),
		@"exclude_muted" : @([folder[@"excludeMuted"] boolValue]),
		@"exclude_read" : @([folder[@"excludeRead"] boolValue]),
		@"exclude_archived" : @([folder[@"excludeArchived"] boolValue]),
		@"include_contacts" : @([folder[@"includeContacts"] boolValue]),
		@"include_non_contacts" : @([folder[@"includeNonContacts"] boolValue]),
		@"include_bots" : @([folder[@"includeBots"] boolValue]),
		@"include_groups" : @([folder[@"includeGroups"] boolValue]),
		@"include_channels" : @([folder[@"includeChannels"] boolValue]),
	};
}

- (NSString *)tgcl_titleForList:(TGChatListId)list {
	if (list == TGChatListMain)
		return TGL(@"ChatList.Tabs.AllChats", @"All Chats");
	if (list == TGChatListArchive)
		return TGL(@"ChatListFolder.CategoryArchived", @"Archived");
	for (NSDictionary *folder in self.folders) {
		if (![folder isKindOfClass:NSDictionary.class])
			continue;
		if ([folder[@"id"] integerValue] == list)
			return folder[@"title"] ?: @"";
	}
	return @"";
}

#pragma mark - lists

- (void)chatsInList:(TGChatListId)list
			  limit:(NSInteger)limit
		 completion:(void (^)(NSArray *))completion {
	if (limit <= 0)
		limit = 100;
	[self tgcl_chatRowsFrom:@{@"@type" : @"getChats",
		@"chat_list" : TGChatListObject(list),
		@"limit" : @((int)limit)}
				 completion:completion];
}

- (void)loadMoreChatsInList:(TGChatListId)list limit:(NSInteger)limit {
	if (limit <= 0)
		limit = 50;
	[self send:@{@"@type" : @"loadChats",
		@"chat_list" : TGChatListObject(list),
		@"limit" : @((int)limit)}];
}

- (void)markListAsRead:(TGChatListId)list {
	[self send:@{@"@type" : @"readChatList",
		@"chat_list" : TGChatListObject(list)}];
}

- (NSDictionary *)unreadSummaryForList:(TGChatListId)list {
	NSArray *rows = (list == TGChatListArchive) ? self.archivedChats : self.chats;
	NSInteger chats = 0, unmutedChats = 0, messages = 0, unmutedMessages = 0;
	for (NSDictionary *row in rows) {
		if (![row isKindOfClass:NSDictionary.class])
			continue;
		NSInteger unread = [row[@"unread"] integerValue];
		BOOL marked = [row[@"markedUnread"] boolValue];
		BOOL muted = [row[@"isMuted"] boolValue];
		if (unread <= 0 && !marked)
			continue;
		NSInteger contribution = TGUnreadContributionForChatRow(row);
		chats++;
		messages += contribution;
		if (!muted) {
			unmutedChats++;
			unmutedMessages += contribution;
		}
	}
	return @{@"chats" : @(chats),
		@"unmutedChats" : @(unmutedChats),
		@"messages" : @(messages),
		@"unmutedMessages" : @(unmutedMessages)};
}

- (void)setChat:(int64_t)chatId markedAsUnread:(BOOL)marked completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"toggleChatIsMarkedAsUnread",
		@"chat_id" : @(chatId),
		@"is_marked_as_unread" : @(marked)}
		completion:^(NSDictionary *result) {
			BOOL success = !TGResultIsError(result);
			if (success)
				TGSetMarkedUnread(self, chatId, marked);
			if (completion)
				completion(success);
		}];
}

- (void)clearAllDraftMessagesExcludingSecretChats:(BOOL)excludeSecretChats
									   completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"clearAllDraftMessages",
		@"exclude_secret_chats" : @(excludeSecretChats)}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

#pragma mark - pinning

- (void)setChat:(int64_t)chatId pinned:(BOOL)pinned inList:(TGChatListId)list completion:(void (^)(BOOL success))completion {
	[self request:@{@"@type" : @"toggleChatIsPinned",
		@"chat_list" : TGChatListObject(list),
		@"chat_id" : @(chatId),
		@"is_pinned" : @(pinned)}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)setPinnedChats:(NSArray *)chatIds inList:(TGChatListId)list completion:(void (^)(BOOL success))completion {
	[self request:@{@"@type" : @"setPinnedChats",
		@"chat_list" : TGChatListObject(list),
		@"chat_ids" : TGNumberArray(chatIds)}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

#pragma mark - membership of lists

- (void)addChat:(int64_t)chatId toList:(TGChatListId)list completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"addChatToList",
		@"chat_id" : @(chatId),
		@"chat_list" : TGChatListObject(list)}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)listsToAddChat:(int64_t)chatId completion:(void (^)(NSArray *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChatListsToAddChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			TGClient *strongSelf = weakSelf;
			if (!strongSelf || TGResultIsError(result)) {
				completion(@[]);
				return;
			}
			NSMutableArray *out = [NSMutableArray array];
			id lists = result[@"chat_lists"];
			if ([lists isKindOfClass:NSArray.class]) {
				for (id entry in lists) {
					TGChatListId list = TGChatListIdFromObject(entry);
					[out addObject:@{@"list" : @(list),
						@"title" : [strongSelf tgcl_titleForList:list]}];
				}
			}
			completion(out);
		}];
}

#pragma mark - folders

- (void)folderWithId:(NSInteger)folderId completion:(void (^)(NSDictionary *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChatFolder", @"chat_folder_id" : @((int)folderId)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			TGClient *strongSelf = weakSelf;
			if (!strongSelf || TGResultIsError(result)) {
				completion(nil);
				return;
			}
			completion([strongSelf tgcl_folderFromTdFolder:result id:@(folderId)]);
		}];
}

- (void)toggleFolderTagsEnabled:(BOOL)enabled completion:(void (^)(BOOL))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"toggleChatFolderTags", @"are_tags_enabled" : @(enabled)}
		completion:^(NSDictionary *result) {
			TGClient *strongSelf = weakSelf;
			BOOL ok = strongSelf && !TGResultIsError(result);
			if (ok)
				strongSelf.folderTagsEnabled = enabled;
			if (completion)
				completion(ok);
		}];
}

- (void)refreshFolderTagDefinitions {
	NSMutableSet *validIds = [NSMutableSet set];
	for (NSDictionary *summary in self.folders) {
		if (![summary isKindOfClass:NSDictionary.class])
			continue;
		NSNumber *folderId = summary[@"id"];
		if (![folderId isKindOfClass:NSNumber.class])
			continue;
		[validIds addObject:folderId];

		__weak typeof(self) weakSelf = self;
		[self folderWithId:folderId.integerValue completion:^(NSDictionary *definition) {
			TGClient *strongSelf = weakSelf;
			if (!strongSelf || !definition)
				return;
			strongSelf.folderDefinitionsById[folderId] = definition;
			[strongSelf rebuildChats];
		}];
	}
	for (NSNumber *key in [self.folderDefinitionsById.allKeys copy])
		if (![validIds containsObject:key])
			[self.folderDefinitionsById removeObjectForKey:key];
}

- (BOOL)tgcl_chat:(NSDictionary *)chat matchesFolderDefinition:(NSDictionary *)folder
					 chatId:(int64_t)chatId {
	NSNumber *cid = @(chatId);
	NSArray *excluded = folder[@"excludedChatIds"];
	if ([excluded isKindOfClass:NSArray.class] && [excluded containsObject:cid])
		return NO;

	NSArray *included = folder[@"includedChatIds"];
	NSArray *pinned = folder[@"pinnedChatIds"];
	if (([included isKindOfClass:NSArray.class] && [included containsObject:cid]) ||
		([pinned isKindOfClass:NSArray.class] && [pinned containsObject:cid]))
		return YES;

	BOOL isChannel = [chat[@"isChannel"] boolValue];
	BOOL isGroup = [chat[@"isGroup"] boolValue] && !isChannel;
	BOOL isPrivate = [chat[@"isPrivate"] boolValue];
	BOOL isSecret = !isChannel && !isGroup && !isPrivate;

	int64_t peerUserId = isPrivate ? chatId : (isSecret ? [self secretChatUserIdForChat:chatId] : 0);
	NSDictionary *peerUser = peerUserId ? self.userRecordsById[@(peerUserId)] : nil;
	BOOL peerIsBot = [peerUser[@"type"][@"@type"] isEqualToString:@"userTypeBot"];
	BOOL peerIsContact = [peerUser[@"is_contact"] boolValue];

	BOOL matchesKind = ([folder[@"includeGroups"] boolValue] && isGroup) ||
		([folder[@"includeChannels"] boolValue] && isChannel) ||
		(peerUser != nil && peerIsBot && [folder[@"includeBots"] boolValue]) ||
		(peerUser != nil && !peerIsBot && peerIsContact && [folder[@"includeContacts"] boolValue]) ||
		(peerUser != nil && !peerIsBot && !peerIsContact && [folder[@"includeNonContacts"] boolValue]);
	if (!matchesKind)
		return NO;

	return TGChatFolderExclusionAllowsChat(folder, chat);
}

- (NSDictionary *)primaryFolderTagForChatId:(int64_t)chatId {
	if (!self.folderTagsEnabled)
		return nil;
	NSDictionary *chat = self.chatsById[@(chatId)];
	if (![chat isKindOfClass:NSDictionary.class])
		return nil;

	for (NSDictionary *summary in self.folders) {
		if (![summary isKindOfClass:NSDictionary.class])
			continue;
		NSNumber *folderId = summary[@"id"];
		NSDictionary *definition = self.folderDefinitionsById[folderId];
		if (![definition isKindOfClass:NSDictionary.class])
			continue;
		NSInteger colourId = [definition[@"colorId"] integerValue];
		if (colourId < 0 || colourId > 6)
			continue;
		if ([self tgcl_chat:chat matchesFolderDefinition:definition chatId:chatId])
			return @{@"title" : definition[@"title"] ?: @"", @"colorId" : @(colourId)};
	}
	return nil;
}

- (void)saveFolder:(NSDictionary *)folder completion:(void (^)(NSInteger, NSString *))completion {
	NSDictionary *td = [self tgcl_tdFolderFrom:folder];
	NSNumber *existing = [folder isKindOfClass:NSDictionary.class] ? folder[@"id"] : nil;
	NSDictionary *request;
	if ([existing isKindOfClass:NSNumber.class] && [existing integerValue] != 0) {
		request = @{@"@type" : @"editChatFolder",
			@"chat_folder_id" : @([existing intValue]),
			@"folder" : td};
	} else {
		request = @{@"@type" : @"createChatFolder", @"folder" : td};
	}
	[self request:request completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			NSString *message = [result[@"message"] isKindOfClass:NSString.class]
					? result[@"message"] : nil;
			completion(0, message);
			return;
		}
		completion([result[@"id"] integerValue], nil);
	}];
}

- (void)deleteFolder:(NSInteger)folderId
		leavingChats:(NSArray *)chatIds
		  completion:(void (^)(BOOL success, NSString *errorMessage))completion {
	[self request:@{@"@type" : @"deleteChatFolder",
		@"chat_folder_id" : @((int)folderId),
		@"leave_chat_ids" : TGNumberArray(chatIds)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(NO, TGResultErrorMessage(result));
				return;
			}
			completion(YES, nil);
		}];
}

- (void)chatsToLeaveWhenDeletingFolder:(NSInteger)folderId completion:(void (^)(NSArray *))completion {
	[self tgcl_chatRowsFrom:@{@"@type" : @"getChatFolderChatsToLeave",
		@"chat_folder_id" : @((int)folderId)}
				 completion:completion];
}

- (void)chatCountForFolder:(NSDictionary *)folder completion:(void (^)(NSInteger))completion {
	[self request:@{@"@type" : @"getChatFolderChatCount",
		@"folder" : [self tgcl_tdFolderFrom:folder]}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			completion(TGResultIsError(result) ? 0 : [result[@"count"] integerValue]);
		}];
}

- (void)defaultIconNameForFolder:(NSDictionary *)folder completion:(void (^)(NSString *))completion {
	[self request:@{@"@type" : @"getChatFolderDefaultIconName",
		@"folder" : [self tgcl_tdFolderFrom:folder]}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result) || ![result[@"name"] isKindOfClass:NSString.class]) {
				completion(nil);
				return;
			}
			completion(result[@"name"]);
		}];
}

- (NSArray *)folderIconNames {
	return @[ @"All", @"Unread", @"Unmuted", @"Bots", @"Channels", @"Groups",
		@"Private", @"Custom", @"Setup", @"Cat", @"Crown", @"Favorite",
		@"Flower", @"Game", @"Home", @"Love", @"Mask", @"Party",
		@"Sport", @"Study", @"Trade", @"Travel", @"Work", @"Airplane",
		@"Book", @"Light", @"Like", @"Money", @"Note", @"Palette" ];
}

- (void)reorderFolders:(NSArray *)folderIds
	   mainListPosition:(NSInteger)position
			 completion:(void (^)(BOOL, NSString *))completion {
	NSMutableArray *ids = [NSMutableArray array];
	for (NSNumber *folderId in TGNumberArray(folderIds))
		[ids addObject:@([folderId intValue])];
	[self request:@{@"@type" : @"reorderChatFolders",
		@"chat_folder_ids" : ids,
		@"main_chat_list_position" : @((int)position)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(NO, TGResultErrorMessage(result));
				return;
			}
			completion(YES, nil);
		}];
}

- (void)recommendedFoldersWithCompletion:(void (^)(NSArray *, BOOL))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getRecommendedChatFolders"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			TGClient *strongSelf = weakSelf;
			if (!strongSelf || TGResultIsError(result)) {
				completion(@[], YES);
				return;
			}
			NSMutableArray *out = [NSMutableArray array];
			id entries = result[@"chat_folders"];
			if ([entries isKindOfClass:NSArray.class]) {
				for (id entry in entries) {
					if (![entry isKindOfClass:NSDictionary.class])
						continue;
					NSDictionary *folder = [strongSelf tgcl_folderFromTdFolder:entry[@"folder"] id:nil];
					if (!folder)
						continue;
					NSString *text = [entry[@"description"] isKindOfClass:NSString.class] ? entry[@"description"] : @"";
					[out addObject:@{@"title" : folder[@"title"] ?: @"",
						@"icon" : folder[@"icon"] ?: @"",
						@"description" : text,
						@"folder" : folder}];
				}
			}
			completion(out, NO);
		}];
}

#pragma mark - shared folders

- (void)inviteLinksForFolder:(NSInteger)folderId completion:(void (^)(NSArray *, BOOL))completion {
	[self request:@{@"@type" : @"getChatFolderInviteLinks",
		@"chat_folder_id" : @((int)folderId)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(@[], YES);
				return;
			}
			NSMutableArray *out = [NSMutableArray array];
			id links = result[@"invite_links"];
			if ([links isKindOfClass:NSArray.class]) {
				for (id link in links) {
					if (![link isKindOfClass:NSDictionary.class])
						continue;
					[out addObject:@{@"link" : link[@"invite_link"] ?: @"",
						@"name" : link[@"name"] ?: @"",
						@"chatIds" : TGNumberArray(link[@"chat_ids"])}];
				}
			}
			completion(out, NO);
		}];
}

- (void)shareableChatsInFolder:(NSInteger)folderId completion:(void (^)(NSArray *))completion {
	[self tgcl_chatRowsFrom:@{@"@type" : @"getChatsForChatFolderInviteLink",
		@"chat_folder_id" : @((int)folderId)}
				 completion:completion];
}

- (void)tgcl_inviteLinkRequest:(NSDictionary *)request completion:(void (^)(NSDictionary *))completion {
	[self request:request completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		completion(@{@"link" : result[@"invite_link"] ?: @"",
			@"name" : result[@"name"] ?: @"",
			@"chatIds" : TGNumberArray(result[@"chat_ids"])});
	}];
}

- (void)createInviteLinkForFolder:(NSInteger)folderId
							 name:(NSString *)name
						  chatIds:(NSArray *)chatIds
					   completion:(void (^)(NSDictionary *))completion {
	[self tgcl_inviteLinkRequest:@{@"@type" : @"createChatFolderInviteLink",
		@"chat_folder_id" : @((int)folderId),
		@"name" : name ?: @"",
		@"chat_ids" : TGNumberArray(chatIds)}
					  completion:completion];
}

- (void)editInviteLink:(NSString *)link
			 forFolder:(NSInteger)folderId
				  name:(NSString *)name
			   chatIds:(NSArray *)chatIds
			completion:(void (^)(NSDictionary *))completion {
	if (![link isKindOfClass:NSString.class] || link.length == 0) {
		if (completion)
			completion(nil);
		return;
	}
	[self tgcl_inviteLinkRequest:@{@"@type" : @"editChatFolderInviteLink",
		@"chat_folder_id" : @((int)folderId),
		@"invite_link" : link,
		@"name" : name ?: @"",
		@"chat_ids" : TGNumberArray(chatIds)}
					  completion:completion];
}

- (void)deleteInviteLink:(NSString *)link
				forFolder:(NSInteger)folderId
			   completion:(void (^)(BOOL success, NSString *errorMessage))completion {
	if (![link isKindOfClass:NSString.class] || link.length == 0) {
		if (completion)
			completion(NO, nil);
		return;
	}
	[self request:@{@"@type" : @"deleteChatFolderInviteLink",
		@"chat_folder_id" : @((int)folderId),
		@"invite_link" : link}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(NO, TGResultErrorMessage(result));
				return;
			}
			completion(YES, nil);
		}];
}

- (void)checkFolderInviteLink:(NSString *)link completion:(void (^)(NSDictionary *))completion {
	if (![link isKindOfClass:NSString.class] || link.length == 0) {
		if (completion)
			completion(nil);
		return;
	}
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"checkChatFolderInviteLink", @"invite_link" : link}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			TGClient *strongSelf = weakSelf;
			if (!strongSelf || TGResultIsError(result)) {
				completion(nil);
				return;
			}
			NSDictionary *info = result[@"chat_folder_info"];
			NSDictionary *folder = [strongSelf tgcl_folderFromTdFolder:info id:info[@"id"]];
			completion(@{@"title" : folder[@"title"] ?: @"",
				@"icon" : folder[@"icon"] ?: @"",
				@"folderId" : folder[@"id"] ?: @(0),
				@"missingChatIds" : TGNumberArray(result[@"missing_chat_ids"]),
				@"addedChatIds" : TGNumberArray(result[@"added_chat_ids"])});
		}];
}

- (void)chatFolderInviteLinkFromDeepLink:(NSString *)urlString
							   completion:(void (^)(NSString *))completion {
	if (![urlString isKindOfClass:NSString.class] || urlString.length == 0) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{@"@type" : @"getInternalLinkType", @"link" : urlString}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result) ||
				![result[@"@type"] isEqualToString:@"internalLinkTypeChatFolderInvite"]) {
				completion(nil);
				return;
			}
			id link = result[@"invite_link"];
			completion([link isKindOfClass:NSString.class] ? link : nil);
		}];
}

- (void)joinFolderByInviteLink:(NSString *)link
					   chatIds:(NSArray *)chatIds
					completion:(void (^)(BOOL))completion {
	if (![link isKindOfClass:NSString.class] || link.length == 0) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{@"@type" : @"addChatFolderByInviteLink",
		@"invite_link" : link,
		@"chat_ids" : TGNumberArray(chatIds)}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)newChatsInFolder:(NSInteger)folderId completion:(void (^)(NSArray *))completion {
	[self tgcl_chatRowsFrom:@{@"@type" : @"getChatFolderNewChats",
		@"chat_folder_id" : @((int)folderId)}
				 completion:completion];
}

- (void)addNewChats:(NSArray *)chatIds
		   toFolder:(NSInteger)folderId
		 completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{@"@type" : @"processChatFolderNewChats",
		@"chat_folder_id" : @((int)folderId),
		@"added_chat_ids" : TGNumberArray(chatIds)}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(NO, TGResultErrorMessage(result));
				return;
			}
			completion(YES, nil);
		}];
}

#pragma mark - archive settings

- (void)archiveSettingsWithCompletion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getArchiveChatListSettings"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil);
				return;
			}
			completion(@{@"archiveUnknownSenders" :
							 @([result[@"archive_and_mute_new_chats_from_unknown_users"] boolValue]),
				@"keepUnmutedArchived" :
					@([result[@"keep_unmuted_chats_archived"] boolValue]),
				@"keepFoldersArchived" :
					@([result[@"keep_chats_from_folders_archived"] boolValue])});
		}];
}

#pragma mark - search and recents

- (void)searchChatList:(NSString *)query completion:(void (^)(NSArray *, NSArray *))completion {
	if (![query isKindOfClass:NSString.class])
		query = @"";
	__block NSArray *local = nil;
	__block NSArray *global = nil;
	__block NSInteger done = 0;
	void (^finish)(void) = ^{
		done++;
		if (done == 2 && completion)
			completion(local ?: @[], global ?: @[]);
	};
	[self tgcl_chatRowsFrom:@{@"@type" : @"searchChats",
		@"query" : query,
		@"limit" : @(50)}
				 completion:^(NSArray *chats) {
					 local = chats;
					 finish();
				 }];
	[self tgcl_chatRowsFrom:@{@"@type" : @"searchPublicChats", @"query" : query}
				 completion:^(NSArray *chats) {
					 global = chats;
					 finish();
				 }];
}

- (void)topChatsWithCompletion:(void (^)(NSArray *))completion {
	[self tgcl_chatRowsFrom:@{@"@type" : @"getTopChats",
		@"category" : @{@"@type" : @"topChatCategoryUsers"},
		@"limit" : @(20)}
				 completion:completion];
}

- (void)removeTopChat:(int64_t)chatId {
	[self send:@{@"@type" : @"removeTopChat",
		@"category" : @{@"@type" : @"topChatCategoryUsers"},
		@"chat_id" : @(chatId)}];
}

- (void)recentlyOpenedChatsWithCompletion:(void (^)(NSArray *))completion {
	[self tgcl_chatRowsFrom:@{@"@type" : @"getRecentlyOpenedChats", @"limit" : @(20)}
				 completion:completion];
}

- (void)addRecentlyFoundChat:(int64_t)chatId {
	[self send:@{@"@type" : @"addRecentlyFoundChat", @"chat_id" : @(chatId)}];
}

- (void)removeRecentlyFoundChat:(int64_t)chatId {
	[self send:@{@"@type" : @"removeRecentlyFoundChat", @"chat_id" : @(chatId)}];
}

- (void)clearRecentlyFoundChats {
	[self send:@{@"@type" : @"clearRecentlyFoundChats"}];
}

#pragma mark - row rendering

- (void)rowDetailForChat:(int64_t)chatId completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *chat) {
			if (!completion)
				return;
			if (TGResultIsError(chat)) {
				completion(nil);
				return;
			}
			NSString *draft = @"";
			id draftMessage = chat[@"draft_message"];
			if ([draftMessage isKindOfClass:NSDictionary.class]) {
				id content = draftMessage[@"content"];
				if ([content isKindOfClass:NSDictionary.class])
					draft = TGPlainText(content[@"text"]);
			}

			NSString *source = @"";
			NSString *sourceText = @"";
			BOOL pinned = NO;
			id positions = chat[@"positions"];
			if ([positions isKindOfClass:NSArray.class]) {
				for (id position in positions) {
					if (![position isKindOfClass:NSDictionary.class])
						continue;
					if ([position[@"list"] isKindOfClass:NSDictionary.class] &&
						[position[@"list"][@"@type"] isEqualToString:@"chatListMain"])
						pinned = [position[@"is_pinned"] boolValue];
					id origin = position[@"source"];
					if (![origin isKindOfClass:NSDictionary.class])
						continue;
					NSString *type = origin[@"@type"];
					if ([type isEqualToString:@"chatSourcePublicServiceAnnouncement"]) {
						source = @"psa";
						if ([origin[@"text"] isKindOfClass:NSString.class])
							sourceText = origin[@"text"];
					} else if ([type isEqualToString:@"chatSourceMtprotoProxy"]) {
						source = @"proxy";
					}
				}
			}

			BOOL muted = NO;
			id settings = chat[@"notification_settings"];
			if ([settings isKindOfClass:NSDictionary.class])
				muted = [settings[@"mute_for"] integerValue] > 0;

			completion(@{@"draft" : draft,
				@"markedUnread" : @([chat[@"is_marked_as_unread"] boolValue]),
				@"unread" : chat[@"unread_count"] ?: @(0),
				@"isPinned" : @(pinned),
				@"isMuted" : @(muted),
				@"source" : source,
				@"sourceText" : sourceText});
		}];
}

#pragma mark - per-chat read state

- (void)markChatAsRead:(int64_t)chatId completion:(void (^)(BOOL ok))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *chat) {
			TGClient *strongSelf = weakSelf;
			if (!strongSelf || TGResultIsError(chat)) {
				if (completion)
					completion(NO);
				return;
			}
			NSNumber *lastMessageId = nil;
			id lastMessage = chat[@"last_message"];
			if ([lastMessage isKindOfClass:NSDictionary.class] &&
				[lastMessage[@"id"] isKindOfClass:NSNumber.class])
				lastMessageId = lastMessage[@"id"];
			if (!lastMessageId &&
				[chat[@"last_read_inbox_message_id"] isKindOfClass:NSNumber.class])
				lastMessageId = chat[@"last_read_inbox_message_id"];

			void (^finish)(BOOL) = ^(BOOL ok) {
				if (ok) {
					if ([chat[@"is_marked_as_unread"] boolValue])
						[strongSelf setChat:chatId markedAsUnread:NO completion:nil];
					else
						[TGMarkedUnreadChatIds() removeObject:@(chatId)];

					NSMutableDictionary *info = strongSelf.chatsById[@(chatId)];
					if ([info isKindOfClass:NSMutableDictionary.class]) {
						info[@"unread"] = @(0);
						info[@"markedUnread"] = @(NO);
						if (lastMessageId)
							info[@"lastReadInboxId"] = lastMessageId;
					}
				}
				if (completion)
					completion(ok);
			};

			if (lastMessageId && [lastMessageId longLongValue] != 0) {
				[strongSelf request:@{@"@type" : @"viewMessages",
					@"chat_id" : @(chatId),
					@"message_ids" : @[ lastMessageId ],
					@"source" : @{@"@type" : @"messageSourceChatList"},
					@"force_read" : @YES}
					completion:^(NSDictionary *result) {
						finish(!TGResultIsError(result));
					}];
			} else {
				finish(YES);
			}
		}];
}

- (void)markChatAsRead:(int64_t)chatId {
	[self markChatAsRead:chatId completion:nil];
}

- (BOOL)isChatMarkedAsUnread:(int64_t)chatId {
	NSDictionary *info = self.chatsById[@(chatId)];
	if ([info[@"markedUnread"] isKindOfClass:NSNumber.class])
		return [info[@"markedUnread"] boolValue];
	return [TGMarkedUnreadChatIds() containsObject:@(chatId)];
}

- (void)chatMarkedAsUnread:(int64_t)chatId completion:(void (^)(BOOL marked))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *chat) {
			TGClient *strongSelf = weakSelf;
			if (TGResultIsError(chat)) {
				if (completion)
					completion(strongSelf ? [strongSelf isChatMarkedAsUnread:chatId] : NO);
				return;
			}
			BOOL marked = [chat[@"is_marked_as_unread"] boolValue];
			if (strongSelf)
				TGSetMarkedUnread(strongSelf, chatId, marked);
			else if (marked)
				[TGMarkedUnreadChatIds() addObject:@(chatId)];
			else
				[TGMarkedUnreadChatIds() removeObject:@(chatId)];
			if (completion)
				completion(marked);
		}];
}

#pragma mark - chat titles

- (NSString *)cachedTitleForChatId:(int64_t)chatId {
	NSNumber *key = @(chatId);
	NSDictionary *info = self.chatsById[key];
	if ([info[@"title"] isKindOfClass:NSString.class] && [info[@"title"] length] > 0)
		return info[@"title"];
	for (NSDictionary *row in self.chats) {
		if ([row isKindOfClass:NSDictionary.class] &&
			[row[@"id"] longLongValue] == chatId &&
			[row[@"title"] isKindOfClass:NSString.class])
			return row[@"title"];
	}
	for (NSDictionary *row in self.archivedChats) {
		if ([row isKindOfClass:NSDictionary.class] &&
			[row[@"id"] longLongValue] == chatId &&
			[row[@"title"] isKindOfClass:NSString.class])
			return row[@"title"];
	}
	NSString *remembered = [TGChatTitleCache() objectForKey:key];
	return [remembered isKindOfClass:NSString.class] ? remembered : nil;
}

- (void)titleForChatId:(int64_t)chatId completion:(void (^)(NSString *title))completion {
	NSString *known = [self cachedTitleForChatId:chatId];
	if (known.length > 0) {
		if (completion)
			completion(known);
		return;
	}
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *chat) {
			NSString *title = @"";
			if (!TGResultIsError(chat) && [chat[@"title"] isKindOfClass:NSString.class])
				title = chat[@"title"];
			if (title.length > 0)
				[TGChatTitleCache() setObject:title forKey:@(chatId)];
			if (completion)
				completion(title);
		}];
}

- (void)titlesForChatIds:(NSArray *)chatIds completion:(void (^)(NSDictionary *titles))completion {
	NSArray *ids = TGNumberArray(chatIds);
	NSMutableDictionary *out = [NSMutableDictionary dictionary];
	NSMutableArray *pending = [NSMutableArray array];
	for (NSNumber *chatId in ids) {
		NSString *known = [self cachedTitleForChatId:[chatId longLongValue]];
		if (known.length > 0)
			out[chatId] = known;
		else
			[pending addObject:chatId];
	}
	if (!pending.count) {
		if (completion)
			completion(out);
		return;
	}
	__block NSInteger remaining = (NSInteger)pending.count;
	for (NSNumber *chatId in pending) {
		[self titleForChatId:[chatId longLongValue] completion:^(NSString *title) {
			if (title.length > 0)
				out[chatId] = title;
			remaining--;
			if (remaining <= 0 && completion)
				completion(out);
		}];
	}
}

#pragma mark - account switch

- (void)resetChatListCachesForAccountSwitch {
	[TGMarkedUnreadChatIds() removeAllObjects];
	[TGChatTitleCache() removeAllObjects];
}

#pragma mark - folder change notification

- (void)beginObservingFolderChanges {
	[TGChatListFolderWatcher shared];
}

- (NSString *)symbolForFolderIconName:(NSString *)iconName {
	static NSDictionary *symbols = nil;
	if (!symbols) {
		symbols = @{@"All" : @"\U0001F4AC", @"Unread" : @"\U0001F535", @"Unmuted" : @"\U0001F514", @"Bots" : @"\U0001F916", @"Channels" : @"\U0001F4E2", @"Groups" : @"\U0001F465", @"Private" : @"\U0001F464", @"Custom" : @"⚙", @"Setup" : @"⚙", @"Cat" : @"\U0001F431", @"Crown" : @"\U0001F451", @"Favorite" : @"⭐", @"Flower" : @"\U0001F337", @"Game" : @"\U0001F3AE", @"Home" : @"\U0001F3E0", @"Love" : @"❤", @"Mask" : @"\U0001F3AD", @"Party" : @"\U0001F389", @"Sport" : @"⚽", @"Study" : @"\U0001F393", @"Trade" : @"\U0001F4C8", @"Travel" : @"✈", @"Work" : @"\U0001F4BC", @"Airplane" : @"✈", @"Book" : @"\U0001F4D6", @"Light" : @"\U0001F4A1", @"Like" : @"\U0001F44D", @"Money" : @"\U0001F4B0", @"Note" : @"\U0001F4DD", @"Palette" : @"\U0001F3A8"};
	}
	NSString *symbol = nil;
	if ([iconName isKindOfClass:NSString.class])
		symbol = symbols[iconName];
	return symbol ?: @"\U0001F4C1";
}

@end

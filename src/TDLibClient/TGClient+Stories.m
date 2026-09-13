#import "TGClient+ChatState.h"
#import "TGClient+Private.h"
#import "TGClient+Notifications.h"
#import "TGClient+Stories.h"
#import "TGClient+Contacts.h"
#import "TGClient+Storage.h"
#import "TGAccountManager.h"
#import "TGFlattenStory.h"
#import "TGStoryComposer.h"
#import "TGLocalization.h"

static NSArray *TGStoryArray(id value) {
	return [value isKindOfClass:NSArray.class] ? value : @[];
}

static NSDictionary *TGStoryDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSString *TGStoryString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSNumber *TGStoryNumber(id value) {
	return [value isKindOfClass:NSNumber.class] ? value : nil;
}

static NSArray *TGStoryIdList(NSArray *ids) {
	NSMutableArray *out = [NSMutableArray array];
	for (id one in TGStoryArray(ids)) {
		NSNumber *n = TGStoryNumber(one);
		if (n)
			[out addObject:n];
	}
	return out;
}

static NSDictionary *TGStoryRepostContent(NSDictionary *source) {
	NSDictionary *story = TGStoryDict(source);
	if (!story)
		return nil;

	NSString *kind = TGStoryString(story[@"kind"]);
	if ([kind isEqualToString:@"video"]) {
		NSNumber *videoId = TGStoryNumber(story[@"videoId"]);
		if (!videoId)
			return nil;
		return @{
			@"@type" : @"inputStoryContentVideo",
			@"video" : @{@"@type" : @"inputFileId", @"id" : videoId},
			@"added_sticker_file_ids" : @[],
			@"duration" : TGStoryNumber(story[@"duration"]) ?: @(0),
			@"cover_frame_timestamp" : @(0.0),
			@"is_animation" : @NO,
		};
	}

	if ([kind isEqualToString:@"photo"]) {
		NSNumber *photoId = TGStoryNumber(story[@"photoId"]);
		if (!photoId)
			return nil;
		return @{
			@"@type" : @"inputStoryContentPhoto",
			@"photo" : @{@"@type" : @"inputFileId", @"id" : photoId},
			@"added_sticker_file_ids" : @[],
		};
	}

	return nil;
}

static NSString *TGStorySenderName(TGClient *client, int64_t senderId) {
	if (!client || senderId == 0)
		return @"";
	if (senderId > 0)
		return [client nameForUserId:senderId] ?: @"";
	NSDictionary *known = TGStoryDict(client.chatsById[@(senderId)]);
	NSString *title = TGStoryString(known[@"title"]);
	if (title.length)
		return title;
	for (NSDictionary *c in client.chats) {
		if ([TGStoryDict(c)[@"id"] longLongValue] == senderId)
			return TGStoryString(c[@"title"]);
	}
	for (NSDictionary *c in client.archivedChats) {
		if ([TGStoryDict(c)[@"id"] longLongValue] == senderId)
			return TGStoryString(c[@"title"]);
	}
	return @"";
}

NSString *const TGStoryUpdateNotification = @"TGStoryUpdateNotification";

static NSDictionary *TGStoryAutoDownloadFromMirror(NSDictionary *values) {
	NSDictionary *source = TGStoryDict(values);
	if (!source)
		return nil;
	return @{
		@"@type" : @"autoDownloadSettings",
		@"is_auto_download_enabled" : source[@"enabled"] ?: @NO,
		@"max_photo_file_size" : source[@"maxPhotoSize"] ?: @(1024 * 1024),
		@"max_video_file_size" : source[@"maxVideoSize"] ?: @(0),
		@"max_other_file_size" : source[@"maxOtherSize"] ?: @(0),
		@"video_upload_bitrate" : source[@"videoUploadBitrate"] ?: @(0),
		@"preload_large_videos" : source[@"preloadLargeVideos"] ?: @NO,
		@"preload_next_audio" : source[@"preloadNextAudio"] ?: @NO,
		@"preload_stories" : @NO,
		@"use_less_data_for_calls" : source[@"useLessDataForCalls"] ?: @YES,
	};
}

@interface TGStoryPostWatcher : NSObject

+ (void)watchChat:(int64_t)chatId
		  storyId:(NSInteger)storyId
			 path:(NSString *)path
		 progress:(void (^)(float fraction))progress
	   completion:(void (^)(NSDictionary *story, NSString *error))completion;

+ (void)cancelAllForAccountSwitch;

@end

static NSMutableArray *TGStoryPostWatchers(void) {
	static NSMutableArray *watchers = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ watchers = [[NSMutableArray alloc] init]; });
	return watchers;
}

@implementation TGStoryPostWatcher {
	int64_t _chatId;
	NSInteger _storyId;
	NSString *_path;
	void (^_progress)(float);
	void (^_completion)(NSDictionary *, NSString *);
	NSTimer *_deadline;
	BOOL _finished;
	id _storyUpdateObserverToken;
}

+ (void)watchChat:(int64_t)chatId
		  storyId:(NSInteger)storyId
			 path:(NSString *)path
		 progress:(void (^)(float))progress
	   completion:(void (^)(NSDictionary *, NSString *))completion {
	TGStoryPostWatcher *watcher = [[TGStoryPostWatcher alloc] init];
	watcher->_chatId = chatId;
	watcher->_storyId = storyId;
	watcher->_path = [path copy];
	watcher->_progress = [progress copy];
	watcher->_completion = [completion copy];
	[TGStoryPostWatchers() addObject:watcher];
	__weak TGStoryPostWatcher *weakWatcher = watcher;
	watcher->_storyUpdateObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGStoryUpdateNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong TGStoryPostWatcher *strongWatcher = weakWatcher;
					if (!strongWatcher)
						return;
					[strongWatcher handleStoryUpdate:note];
				}];
	[watcher armDeadline];
}

- (void)dealloc {
	[_deadline invalidate];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (_storyUpdateObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_storyUpdateObserverToken];
}

- (void)armDeadline {
	[_deadline invalidate];
	_deadline = [NSTimer scheduledTimerWithTimeInterval:180.0
												 target:self
											   selector:@selector(deadlinePassed)
											   userInfo:nil
												repeats:NO];
}

- (void)deadlinePassed {
	_deadline = nil;
	[self finishWithStory:nil
					error:TGL(@"Story.PostError.UploadStalled",
						@"The upload stopped making progress. Check the connection and try again.")];
}

- (void)finishWithStory:(NSDictionary *)story error:(NSString *)error {
	if (_finished)
		return;
	_finished = YES;
	[_deadline invalidate];
	_deadline = nil;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (_storyUpdateObserverToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:_storyUpdateObserverToken];
		_storyUpdateObserverToken = nil;
	}

	void (^completion)(NSDictionary *, NSString *) = _completion;
	_completion = nil;
	_progress = nil;
	if (completion)
		completion(story, error);
	[TGStoryPostWatchers() removeObject:self];
}

- (void)applyFileUpdate:(NSDictionary *)file {
	if (!_progress || !_path.length)
		return;
	NSString *local = TGStoryString(TGStoryDict(file[@"local"])[@"path"]);
	if (![local isEqualToString:_path] &&
		![local.lastPathComponent isEqualToString:_path.lastPathComponent])
		return;

	NSDictionary *remote = TGStoryDict(file[@"remote"]);
	double total = [TGStoryNumber(file[@"expected_size"]) doubleValue];
	if (total <= 0)
		total = [TGStoryNumber(file[@"size"]) doubleValue];
	double sent = [TGStoryNumber(remote[@"uploaded_size"]) doubleValue];

	float fraction = 0.0f;
	if ([remote[@"is_uploading_completed"] boolValue])
		fraction = 1.0f;
	else if (total > 0)
		fraction = (float)(sent / total);
	if (fraction < 0.0f)
		fraction = 0.0f;
	if (fraction > 1.0f)
		fraction = 1.0f;

	[self armDeadline];
	_progress(fraction);
}

- (void)handleStoryUpdate:(NSNotification *)note {
	NSDictionary *update = TGStoryDict(note.object);
	NSString *type = TGStoryString(update[@"@type"]);

	if ([type isEqualToString:@"updateFile"]) {
		[self applyFileUpdate:TGStoryDict(update[@"file"])];
		return;
	}

	if ([type isEqualToString:@"updateStoryPostSucceeded"]) {
		if ([TGStoryNumber(update[@"old_story_id"]) integerValue] != _storyId)
			return;
		if (_progress)
			_progress(1.0f);
		[self finishWithStory:TGStoryFlattened(update[@"story"]) error:nil];
		return;
	}

	if ([type isEqualToString:@"updateStoryPostFailed"]) {
		NSDictionary *story = TGStoryDict(update[@"story"]);
		if ([TGStoryNumber(story[@"id"]) integerValue] != _storyId)
			return;
		NSString *text = TGStoryErrorText(update[@"error"]);
		NSString *typed = TGStoryString(TGStoryDict(update[@"error_type"])[@"@type"]);
		if (typed.length && ![typed isEqualToString:@"canPostStoryResultOk"])
			text = TGStoryLimitReason(typed);
		[self finishWithStory:nil error:text];
		return;
	}

	if ([type isEqualToString:@"updateStoryDeleted"]) {
		if ([TGStoryNumber(update[@"story_id"]) integerValue] != _storyId ||
			[TGStoryNumber(update[@"story_poster_chat_id"]) longLongValue] != _chatId)
			return;
		[self finishWithStory:nil error:TGL(@"Story.PostError.Cancelled", @"Posting the story was cancelled.")];
		return;
	}

	if ([type isEqualToString:@"updateStory"]) {
		NSDictionary *story = TGStoryDict(update[@"story"]);
		if ([TGStoryNumber(story[@"id"]) integerValue] != _storyId ||
			[TGStoryNumber(story[@"poster_chat_id"]) longLongValue] != _chatId)
			return;
		if (![story[@"is_being_posted"] boolValue])
			[self finishWithStory:TGStoryFlattened(story) error:nil];
	}
}

+ (void)cancelAllForAccountSwitch {
	NSArray *watchers = [TGStoryPostWatchers() copy];
	for (TGStoryPostWatcher *watcher in watchers)
		[watcher finishWithStory:nil error:TGL(@"Story.PostError.AccountSwitched", @"Account switched")];
}

@end

@interface TGClient (StoriesInternal)
- (void)postStoryContent:(NSDictionary *)content
					path:(NSString *)path
				  asChat:(int64_t)chatId
				 caption:(NSString *)caption
				 privacy:(NSString *)privacy
				 userIds:(NSArray *)userIds
			activePeriod:(NSInteger)activePeriod
			   toProfile:(BOOL)toProfile
				progress:(void (^)(float fraction))progress
			  completion:(void (^)(NSDictionary *story, NSString *error))completion;
- (NSArray *)flattenedStoryInteractions:(NSArray *)interactions;
- (void)requestStoryAlbum:(NSDictionary *)request
			   completion:(void (^)(NSDictionary *album))completion;
- (void)handleFoundStories:(NSDictionary *)result
				completion:(void (^)(NSArray *stories, NSString *nextOffset, NSInteger total))completion;
@end

@implementation TGClient (Stories)

#pragma mark - active stories

- (void)loadActiveStoriesArchived:(BOOL)archived {
	[self send:@{
		@"@type" : @"loadActiveStories",
		@"story_list" : @{@"@type" : archived ? @"storyListArchive" : @"storyListMain"},
	}];
}

- (void)activeStoriesForChat:(int64_t)chatId
				  completion:(void (^)(NSDictionary *))completion {
	[self request:@{
		@"@type" : @"getChatActiveStories",
		@"chat_id" : @(chatId),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		NSArray *raw = TGStoryArray(result[@"stories"]);
		if (!raw.count) {
			completion(nil);
			return;
		}
		NSInteger maxRead = [TGStoryNumber(result[@"max_read_story_id"]) integerValue];
		BOOL unread = NO;
		NSMutableArray *stories = [NSMutableArray array];
		for (NSDictionary *info in raw) {
			NSNumber *storyId = TGStoryNumber(TGStoryDict(info)[@"story_id"]);
			if (!storyId)
				continue;
			if (storyId.integerValue > maxRead)
				unread = YES;
			[stories addObject:@{
				@"id" : storyId,
				@"date" : TGStoryNumber(info[@"date"]) ?: @(0),
				@"closeFriends" : @([info[@"is_for_close_friends"] boolValue]),
				@"isLive" : @([info[@"is_live"] boolValue]),
			}];
		}
		if (!stories.count) {
			completion(nil);
			return;
		}
		BOOL archived = [TGStoryDict(result[@"list"])[@"@type"]
			isEqualToString:@"storyListArchive"];
		completion(@{
			@"chatId" : TGStoryNumber(result[@"chat_id"]) ?: @(chatId),
			@"order" : TGStoryNumber(result[@"order"]) ?: @(0),
			@"canBeArchived" : @([result[@"can_be_archived"] boolValue]),
			@"maxReadStoryId" : @(maxRead),
			@"unread" : @(unread),
			@"archived" : @(archived),
			@"stories" : stories,
		});
	}];
}

- (void)setChat:(int64_t)chatId storiesArchived:(BOOL)archived {
	[self send:@{
		@"@type" : @"setChatActiveStoriesList",
		@"chat_id" : @(chatId),
		@"story_list" : @{@"@type" : archived ? @"storyListArchive" : @"storyListMain"},
	}];
}

#pragma mark - viewing

- (void)storyWithId:(NSInteger)storyId
			 inChat:(int64_t)chatId
		 completion:(void (^)(NSDictionary *))completion {
	[self request:@{
		@"@type" : @"getStory",
		@"story_poster_chat_id" : @(chatId),
		@"story_id" : @(storyId),
		@"only_local" : @NO,
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? nil : TGStoryFlattened(result));
	}];
}

- (void)openStory:(NSInteger)storyId inChat:(int64_t)chatId {
	[self send:@{
		@"@type" : @"openStory",
		@"story_poster_chat_id" : @(chatId),
		@"story_id" : @(storyId),
	}];
}

- (void)closeStory:(NSInteger)storyId inChat:(int64_t)chatId {
	[self send:@{
		@"@type" : @"closeStory",
		@"story_poster_chat_id" : @(chatId),
		@"story_id" : @(storyId),
	}];
}

- (void)markStoryRead:(NSInteger)storyId inChat:(int64_t)chatId {
	[self openStory:storyId inChat:chatId];
	[self closeStory:storyId inChat:chatId];
}

#pragma mark - interactions

- (void)storyReactionsWithLimit:(NSInteger)limit
					 completion:(void (^)(NSArray *))completion {
	NSInteger rowSize = limit > 0 && limit < 8 ? limit : 8;
	[self request:@{
		@"@type" : @"getStoryAvailableReactions",
		@"row_size" : @(rowSize),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(@[]);
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		NSArray *groups = @[ TGStoryArray(result[@"top_reactions"]),
			TGStoryArray(result[@"recent_reactions"]),
			TGStoryArray(result[@"popular_reactions"]) ];
		for (NSArray *group in groups) {
			for (NSDictionary *entry in group) {
				NSString *emoji = TGStoryReactionEmoji(TGStoryDict(entry)[@"type"]);
				if (!emoji.length || [out containsObject:emoji])
					continue;
				[out addObject:emoji];
				if (limit > 0 && (NSInteger)out.count >= limit) {
					completion(out);
					return;
				}
			}
		}
		completion(out);
	}];
}

- (void)reactToStory:(NSInteger)storyId
			  inChat:(int64_t)chatId
			   emoji:(NSString *)emoji {
	NSMutableDictionary *request = [@{
		@"@type" : @"setStoryReaction",
		@"story_poster_chat_id" : @(chatId),
		@"story_id" : @(storyId),
		@"update_recent_reactions" : @YES,
	} mutableCopy];
	if (emoji.length)
		request[@"reaction_type"] = @{@"@type" : @"reactionTypeEmoji", @"emoji" : emoji};
	[self send:request];
}

- (NSArray *)flattenedStoryInteractions:(NSArray *)interactions {
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *raw in TGStoryArray(interactions)) {
		NSDictionary *one = TGStoryDict(raw);
		if (!one)
			continue;
		int64_t actorId = TGStorySenderId(one[@"actor_id"]);
		NSDictionary *type = TGStoryDict(one[@"type"]);
		NSString *rawType = TGStoryString(type[@"@type"]);
		NSString *kind = @"view";
		if ([rawType isEqualToString:@"storyInteractionTypeForward"])
			kind = @"forward";
		else if ([rawType isEqualToString:@"storyInteractionTypeRepost"])
			kind = @"repost";
		BOOL blocked = [TGStoryDict(one[@"block_list"])[@"@type"] length] > 0;
		[out addObject:@{
			@"id" : @(actorId),
			@"name" : TGStorySenderName(self, actorId),
			@"date" : TGStoryNumber(one[@"interaction_date"]) ?: @(0),
			@"emoji" : TGStoryReactionEmoji(type[@"chosen_reaction_type"]),
			@"kind" : kind,
			@"blocked" : @(blocked),
		}];
	}
	return out;
}

- (void)viewersOfStory:(NSInteger)storyId
			  sortMode:(TGStoryViewerSortMode)sortMode
				offset:(NSString *)offset
				 limit:(NSInteger)limit
			completion:(void (^)(NSArray *, NSString *, NSInteger, BOOL))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type" : @"getStoryInteractions",
		@"story_id" : @(storyId),
		@"query" : @"",
		@"only_contacts" : @NO,
		@"prefer_forwards" : @(sortMode == TGStoryViewerSortReposts),
		@"prefer_with_reaction" : @(sortMode == TGStoryViewerSortReactions),
		@"offset" : offset ?: @"",
		@"limit" : @(limit > 0 ? limit : 20),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(@[], @"", 0, YES);
			return;
		}
		completion([weakSelf flattenedStoryInteractions:result[@"interactions"]],
			TGStoryString(result[@"next_offset"]),
			[TGStoryNumber(result[@"total_count"]) integerValue], NO);
	}];
}

- (void)viewersOfStory:(NSInteger)storyId
				inChat:(int64_t)chatId
			  sortMode:(TGStoryViewerSortMode)sortMode
				offset:(NSString *)offset
				 limit:(NSInteger)limit
			completion:(void (^)(NSArray *, NSString *, NSInteger, BOOL))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type" : @"getChatStoryInteractions",
		@"story_poster_chat_id" : @(chatId),
		@"story_id" : @(storyId),
		@"prefer_forwards" : @(sortMode == TGStoryViewerSortReposts),
		@"offset" : offset ?: @"",
		@"limit" : @(limit > 0 ? limit : 20),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(@[], @"", 0, YES);
			return;
		}
		completion([weakSelf flattenedStoryInteractions:result[@"interactions"]],
			TGStoryString(result[@"next_offset"]),
			[TGStoryNumber(result[@"total_count"]) integerValue], NO);
	}];
}

- (void)replyToStory:(NSInteger)storyId
			  inChat:(int64_t)chatId
				text:(NSString *)text {
	[self replyToStory:storyId inChat:chatId text:text completion:nil];
}

- (void)replyToStory:(NSInteger)storyId
			  inChat:(int64_t)chatId
				text:(NSString *)text
		  completion:(void (^)(BOOL ok))completion {
	if (!text.length) {
		if (completion)
			completion(NO);
		return;
	}
	[self request:@{
		@"@type" : @"sendMessage",
		@"chat_id" : @(chatId),
		@"reply_to" : @{
			@"@type" : @"inputMessageReplyToStory",
			@"story_poster_chat_id" : @(chatId),
			@"story_id" : @(storyId),
		},
		@"input_message_content" : @{
			@"@type" : @"inputMessageText",
			@"text" : @{@"@type" : @"formattedText", @"text" : text},
		},
	}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)publicForwardsOfStory:(NSInteger)storyId
					   inChat:(int64_t)chatId
					   offset:(NSString *)offset
						limit:(NSInteger)limit
				   completion:(void (^)(NSArray *, NSString *))completion {
	[self request:@{
		@"@type" : @"getStoryPublicForwards",
		@"story_poster_chat_id" : @(chatId),
		@"story_id" : @(storyId),
		@"offset" : offset ?: @"",
		@"limit" : @(limit > 0 ? limit : 20),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(@[], @"");
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *raw in TGStoryArray(result[@"forwards"])) {
			NSDictionary *one = TGStoryDict(raw);
			if (!one)
				continue;
			if ([one[@"@type"] isEqualToString:@"publicForwardStory"]) {
				NSDictionary *story = TGStoryFlattened(one[@"story"]);
				if (!story)
					continue;
				[out addObject:@{
					@"chatId" : story[@"chatId"],
					@"title" : @"",
					@"date" : story[@"date"],
					@"isStory" : @YES,
					@"storyId" : story[@"id"],
				}];
				continue;
			}
			NSDictionary *message = TGStoryDict(one[@"message"]);
			if (!message)
				continue;
			[out addObject:@{
				@"chatId" : TGStoryNumber(message[@"chat_id"]) ?: @(0),
				@"title" : @"",
				@"date" : TGStoryNumber(message[@"date"]) ?: @(0),
				@"isStory" : @NO,
			}];
		}
		completion(out, TGStoryString(result[@"next_offset"]));
	}];
}

#pragma mark - posting

- (void)canPostStoryAsChat:(int64_t)chatId
				completion:(void (^)(BOOL, NSString *))completion {
	[self request:@{
		@"@type" : @"canPostStory",
		@"chat_id" : @(chatId),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		NSString *type = TGStoryString(TGStoryDict(result)[@"@type"]);
		if ([type isEqualToString:@"canPostStoryResultOk"]) {
			completion(YES, nil);
			return;
		}
		completion(NO, TGStoryLimitReason(type));
	}];
}

- (void)chatsToPostStoriesWithCompletion:(void (^)(NSArray *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChatsToPostStories"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(@[]);
				return;
			}
			NSMutableArray *out = [NSMutableArray array];
			for (id one in TGStoryArray(result[@"chat_ids"])) {
				NSNumber *chatId = TGStoryNumber(one);
				if (!chatId)
					continue;
				NSString *title = TGStorySenderName(weakSelf, chatId.longLongValue);
				[out addObject:@{@"id" : chatId, @"title" : title}];
			}
			completion(out);
		}];
}

- (void)postStoryContent:(NSDictionary *)content
					path:(NSString *)path
				  asChat:(int64_t)chatId
				 caption:(NSString *)caption
				 privacy:(NSString *)privacy
				 userIds:(NSArray *)userIds
			activePeriod:(NSInteger)activePeriod
				   areas:(NSArray *)areas
			   toProfile:(BOOL)toProfile
				progress:(void (^)(float))progress
			  completion:(void (^)(NSDictionary *, NSString *))completion {
	if (!path.length || !content) {
		if (completion)
			completion(nil, TGL(@"Story.PostError.NothingToPost", @"There is nothing to post."));
		return;
	}
	if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
		if (completion)
			completion(nil, TGL(@"Story.PostError.FileMissing", @"The picked file went missing before it could be posted."));
		return;
	}

	NSInteger period = activePeriod;
	if (period != TGStoryPeriodSixHours && period != TGStoryPeriodTwelveHours &&
		period != TGStoryPeriodDay && period != TGStoryPeriodTwoDays)
		period = TGStoryPeriodDay;

	if (progress)
		progress(0.0f);

	[self request:@{
		@"@type" : @"postStory",
		@"chat_id" : @(chatId),
		@"content" : content,
		@"areas" : @{@"@type" : @"inputStoryAreas", @"areas" : TGStoryArray(areas)},
		@"caption" : @{@"@type" : @"formattedText", @"text" : caption ?: @""},
		@"privacy_settings" : TGStoryPrivacyRules(privacy, userIds),
		@"album_ids" : @[],
		@"active_period" : @(period),
		@"is_posted_to_chat_page" : @(toProfile),
		@"protect_content" : @NO,
	} completion:^(NSDictionary *result) {
		if (TGResultIsError(result)) {
			if (completion)
				completion(nil, TGStoryErrorText(result));
			return;
		}

		NSDictionary *temporary = TGStoryDict(result);
		NSNumber *storyId = TGStoryNumber(temporary[@"id"]);
		if (!storyId) {
			if (completion)
				completion(nil, TGL(@"Story.PostError.NotAccepted", @"Telegram did not accept the story."));
			return;
		}
		if (![temporary[@"is_being_posted"] boolValue]) {
			if (progress)
				progress(1.0f);
			if (completion)
				completion(TGStoryFlattened(temporary), nil);
			return;
		}
		[TGStoryPostWatcher watchChat:chatId
							  storyId:[storyId integerValue]
								 path:path
							 progress:progress
						   completion:completion];
	}];
}

- (void)postPhotoStoryAtPath:(NSString *)path
					  asChat:(int64_t)chatId
					 caption:(NSString *)caption
					 privacy:(NSString *)privacy
					 userIds:(NSArray *)userIds
				activePeriod:(NSInteger)activePeriod
					   areas:(NSArray *)areas
				   toProfile:(BOOL)toProfile
					progress:(void (^)(float))progress
				  completion:(void (^)(NSDictionary *, NSString *))completion {
	[self postStoryContent:@{
		@"@type" : @"inputStoryContentPhoto",
		@"photo" : @{@"@type" : @"inputFileLocal", @"path" : (path ?: @"")},
		@"added_sticker_file_ids" : @[],
	}
					  path:path
					asChat:chatId
				   caption:caption
				   privacy:privacy
				   userIds:userIds
			  activePeriod:activePeriod
					 areas:areas
				 toProfile:toProfile
				  progress:progress
				completion:completion];
}

- (void)postVideoStoryAtPath:(NSString *)path
					duration:(double)duration
					  asChat:(int64_t)chatId
					 caption:(NSString *)caption
					 privacy:(NSString *)privacy
					 userIds:(NSArray *)userIds
				activePeriod:(NSInteger)activePeriod
					   areas:(NSArray *)areas
				   toProfile:(BOOL)toProfile
					progress:(void (^)(float))progress
				  completion:(void (^)(NSDictionary *, NSString *))completion {
	[self postStoryContent:@{
		@"@type" : @"inputStoryContentVideo",
		@"video" : @{@"@type" : @"inputFileLocal", @"path" : (path ?: @"")},
		@"added_sticker_file_ids" : @[],
		@"duration" : @(duration > 0.0 ? duration : 0.0),
		@"cover_frame_timestamp" : @(0.0),
		@"is_animation" : @NO,
	}
					  path:path
					asChat:chatId
				   caption:caption
				   privacy:privacy
				   userIds:userIds
			  activePeriod:activePeriod
					 areas:areas
				 toProfile:toProfile
				  progress:progress
				completion:completion];
}

- (void)postPhotoStoryAtPath:(NSString *)path
					  asChat:(int64_t)chatId
					 caption:(NSString *)caption
					 privacy:(NSString *)privacy
					 userIds:(NSArray *)userIds
				   toProfile:(BOOL)toProfile
				  completion:(void (^)(NSDictionary *))completion {
	[self postPhotoStoryAtPath:path
						asChat:chatId
					   caption:caption
					   privacy:privacy
					   userIds:userIds
				  activePeriod:TGStoryPeriodDay
						 areas:nil
					 toProfile:toProfile
					  progress:nil
					completion:^(NSDictionary *story, NSString *error) {
						(void)error;
						if (completion)
							completion(story);
					}];
}

- (void)repostStory:(NSInteger)storyId
		   fromChat:(int64_t)fromChatId
			 asChat:(int64_t)chatId
			caption:(NSString *)caption
			privacy:(NSString *)privacy
		 completion:(void (^)(NSDictionary *, NSString *))completion {
	__weak typeof(self) weakSelf = self;
	[self storyWithId:storyId inChat:fromChatId completion:^(NSDictionary *source) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf) {
			if (completion)
				completion(nil, TGL(@"Stories.CouldNotRepostThisStory", @"Could not repost this story"));
			return;
		}
		NSDictionary *content = TGStoryRepostContent(source);
		if (!content) {
			if (completion)
				completion(nil, TGL(@"Story.PostError.RepostUnavailable", @"This story can no longer be reposted."));
			return;
		}
		[strongSelf request:@{
			@"@type" : @"postStory",
			@"chat_id" : @(chatId),
			@"content" : content,
			@"areas" : @{@"@type" : @"inputStoryAreas", @"areas" : @[]},
			@"caption" : @{@"@type" : @"formattedText", @"text" : caption ?: @""},
			@"privacy_settings" : TGStoryPrivacyRules(privacy, nil),
			@"album_ids" : @[],
			@"active_period" : @(86400),
			@"from_story_full_id" : @{
				@"@type" : @"storyFullId",
				@"poster_chat_id" : @(fromChatId),
				@"story_id" : @(storyId),
			},
			@"is_posted_to_chat_page" : @NO,
			@"protect_content" : @NO,
		} completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(nil, TGStoryErrorText(result));
				return;
			}
			completion(TGStoryFlattened(result), nil);
		}];
	}];
}

- (void)editStory:(NSInteger)storyId
		   inChat:(int64_t)chatId
		  caption:(NSString *)caption {
	[self editStory:storyId inChat:chatId caption:caption completion:nil];
}

- (void)editStory:(NSInteger)storyId
		   inChat:(int64_t)chatId
		  caption:(NSString *)caption
	   completion:(void (^)(BOOL ok))completion {
	[self request:@{
		@"@type" : @"editStory",
		@"story_poster_chat_id" : @(chatId),
		@"story_id" : @(storyId),
		@"caption" : @{@"@type" : @"formattedText", @"text" : caption ?: @""},
	}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)editStory:(NSInteger)storyId
		   inChat:(int64_t)chatId
		photoPath:(NSString *)path
		  caption:(NSString *)caption {
	[self editStory:storyId inChat:chatId photoPath:path caption:caption completion:nil];
}

- (void)editStory:(NSInteger)storyId
		   inChat:(int64_t)chatId
		photoPath:(NSString *)path
		  caption:(NSString *)caption
	   completion:(void (^)(BOOL ok))completion {
	if (!path.length) {
		[self editStory:storyId inChat:chatId caption:caption completion:completion];
		return;
	}
	[self request:@{
		@"@type" : @"editStory",
		@"story_poster_chat_id" : @(chatId),
		@"story_id" : @(storyId),
		@"content" : @{
			@"@type" : @"inputStoryContentPhoto",
			@"photo" : @{@"@type" : @"inputFileLocal", @"path" : path},
			@"added_sticker_file_ids" : @[],
		},
		@"caption" : @{@"@type" : @"formattedText", @"text" : caption ?: @""},
	}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)deleteStory:(NSInteger)storyId inChat:(int64_t)chatId {
	[self deleteStory:storyId inChat:chatId completion:nil];
}

- (void)deleteStory:(NSInteger)storyId
			 inChat:(int64_t)chatId
		 completion:(void (^)(BOOL ok))completion {
	[self request:@{
		@"@type" : @"deleteStory",
		@"story_poster_chat_id" : @(chatId),
		@"story_id" : @(storyId),
	}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

#pragma mark - area placement helpers

- (NSDictionary *)inputStoryAreaWithKind:(NSString *)kind
								xPercent:(double)xPercent
								yPercent:(double)yPercent
							widthPercent:(double)widthPercent
						   heightPercent:(double)heightPercent
								latitude:(double)latitude
							   longitude:(double)longitude
									 url:(NSString *)url
								  chatId:(int64_t)areaChatId
							   messageId:(int64_t)areaMessageId
							reactionEmoji:(NSString *)reactionEmoji {
	NSDictionary *position = @{
		@"@type" : @"storyAreaPosition",
		@"x_percentage" : @(xPercent),
		@"y_percentage" : @(yPercent),
		@"width_percentage" : @(widthPercent),
		@"height_percentage" : @(heightPercent),
		@"rotation_angle" : @(0.0),
		@"corner_radius_percentage" : @(0.0),
	};

	NSDictionary *type = nil;
	if ([kind isEqualToString:@"location"]) {
		type = @{
			@"@type" : @"inputStoryAreaTypeLocation",
			@"location" : @{@"@type" : @"location",
				@"latitude" : @(latitude),
				@"longitude" : @(longitude)},
			@"address" : @{@"@type" : @"locationAddress",
				@"country_code" : @"",
				@"state" : @"",
				@"city" : @"",
				@"street" : @""},
		};
	} else if ([kind isEqualToString:@"link"]) {
		type = @{
			@"@type" : @"inputStoryAreaTypeLink",
			@"url" : url ?: @"",
		};
	} else if ([kind isEqualToString:@"message"]) {
		type = @{
			@"@type" : @"inputStoryAreaTypeMessage",
			@"chat_id" : @(areaChatId),
			@"message_id" : @(areaMessageId),
		};
	} else if ([kind isEqualToString:@"reaction"]) {
		type = @{
			@"@type" : @"inputStoryAreaTypeSuggestedReaction",
			@"reaction_type" : @{@"@type" : @"reactionTypeEmoji", @"emoji" : reactionEmoji ?: @""},
			@"is_dark" : @NO,
			@"is_flipped" : @NO,
		};
	}
	if (!type)
		return nil;

	return @{
		@"@type" : @"inputStoryArea",
		@"position" : position,
		@"type" : type,
	};
}

- (void)storyLinkAreaCountMaxWithCompletion:(void (^)(NSInteger countMax))completion {
	if (!completion)
		return;
	[self request:@{@"@type" : @"getOption", @"name" : @"story_link_area_count_max"}
		completion:^(NSDictionary *result) {
			NSNumber *value = TGResultIsError(result) ? nil : result[@"value"];
			completion([value isKindOfClass:NSNumber.class] ? [value integerValue] : 0);
		}];
}

- (void)storyReactionAreaCountMaxWithCompletion:(void (^)(NSInteger countMax))completion {
	if (!completion)
		return;
	[self request:@{@"@type" : @"getOption", @"name" : @"story_suggested_reaction_area_count_max"}
		completion:^(NSDictionary *result) {
			NSNumber *value = TGResultIsError(result) ? nil : result[@"value"];
			completion([value isKindOfClass:NSNumber.class] ? [value integerValue] : 0);
		}];
}

- (void)messageCanBeSharedInStory:(int64_t)messageId
							inChat:(int64_t)chatId
						completion:(void (^)(BOOL canShare))completion {
	if (!completion)
		return;
	if (!chatId || !messageId) {
		completion(NO);
		return;
	}
	[self request:@{@"@type" : @"getMessageProperties",
		@"chat_id" : @(chatId),
		@"message_id" : @(messageId)}
		completion:^(NSDictionary *result) {
			completion(!TGResultIsError(result) && [TGStoryDict(result)[@"can_be_shared_in_story"] boolValue]);
		}];
}

#pragma mark - privacy

- (void)setStory:(NSInteger)storyId
		 privacy:(NSString *)privacy
		 userIds:(NSArray *)userIds {
	[self setStory:storyId privacy:privacy userIds:userIds completion:nil];
}

- (void)setStory:(NSInteger)storyId
		 privacy:(NSString *)privacy
		 userIds:(NSArray *)userIds
	  completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"setStoryPrivacySettings",
		@"story_id" : @(storyId),
		@"privacy_settings" : TGStoryPrivacyRules(privacy, userIds),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)closeFriendsWithCompletion:(void (^)(NSArray *, BOOL))completion {
	[self contactCloseFriendsWithCompletion:completion];
}

- (void)hiddenStoryPostersWithCompletion:(void (^)(NSArray *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type" : @"getBlockedMessageSenders",
		@"block_list" : @{@"@type" : @"blockListStories"},
		@"offset" : @(0),
		@"limit" : @(100),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *sender in TGStoryArray(result[@"senders"])) {
			int64_t senderId = TGStorySenderId(sender);
			if (!senderId)
				continue;
			BOOL isChat = [sender[@"@type"] isEqualToString:@"messageSenderChat"];
			[out addObject:@{
				@"id" : @(senderId),
				@"isChat" : @(isChat),
				@"name" : TGStorySenderName(weakSelf, senderId),
			}];
		}
		completion(out);
	}];
}

- (void)setUser:(int64_t)userId storiesHidden:(BOOL)hidden {
	[self setUser:userId storiesHidden:hidden completion:nil];
}

- (void)setUser:(int64_t)userId
	storiesHidden:(BOOL)hidden
	   completion:(void (^)(BOOL ok))completion {
	[self setStorySender:userId isChat:NO storiesHidden:hidden completion:completion];
}

- (void)setStorySender:(int64_t)senderId
				 isChat:(BOOL)isChat
		  storiesHidden:(BOOL)hidden
			 completion:(void (^)(BOOL ok))completion {
	[self request:@{
		@"@type" : @"setMessageSenderBlockList",
		@"sender_id" : isChat
			? @{@"@type" : @"messageSenderChat", @"chat_id" : @(senderId)}
			: @{@"@type" : @"messageSenderUser", @"user_id" : @(senderId)},
		@"block_list" : hidden ? (id) @{@"@type" : @"blockListStories"} : (id)[NSNull null],
	}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

#pragma mark - archive and profile

- (void)archivedStoriesInChat:(int64_t)chatId
				  fromStoryId:(NSInteger)fromStoryId
						limit:(NSInteger)limit
				   completion:(void (^)(NSArray *, NSInteger))completion {
	[self request:@{
		@"@type" : @"getChatArchivedStories",
		@"chat_id" : @(chatId),
		@"from_story_id" : @(fromStoryId),
		@"limit" : @(limit > 0 ? limit : 30),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(@[], 0);
			return;
		}
		completion(TGStoriesFlattened(result[@"stories"]),
			[TGStoryNumber(result[@"total_count"]) integerValue]);
	}];
}

- (void)profileStoriesInChat:(int64_t)chatId
				 fromStoryId:(NSInteger)fromStoryId
					   limit:(NSInteger)limit
				  completion:(void (^)(NSArray *, NSArray *, NSInteger))completion {
	[self request:@{
		@"@type" : @"getChatPostedToChatPageStories",
		@"chat_id" : @(chatId),
		@"from_story_id" : @(fromStoryId),
		@"limit" : @(limit > 0 ? limit : 30),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(@[], @[], 0);
			return;
		}
		completion(TGStoriesFlattened(result[@"stories"]),
			TGStoryIdList(result[@"pinned_story_ids"]),
			[TGStoryNumber(result[@"total_count"]) integerValue]);
	}];
}

- (void)setStory:(NSInteger)storyId inChat:(int64_t)chatId onProfile:(BOOL)onProfile {
	[self setStory:storyId inChat:chatId onProfile:onProfile completion:nil];
}

- (void)setStory:(NSInteger)storyId
		  inChat:(int64_t)chatId
	   onProfile:(BOOL)onProfile
	  completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"toggleStoryIsPostedToChatPage",
		@"story_poster_chat_id" : @(chatId),
		@"story_id" : @(storyId),
		@"is_posted_to_chat_page" : @(onProfile),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)setPinnedStories:(NSArray *)storyIds inChat:(int64_t)chatId {
	[self setPinnedStories:storyIds inChat:chatId completion:nil];
}

- (void)setPinnedStories:(NSArray *)storyIds
				   inChat:(int64_t)chatId
			   completion:(void (^)(BOOL ok))completion {
	[self request:@{
		@"@type" : @"setChatPinnedStories",
		@"chat_id" : @(chatId),
		@"story_ids" : TGStoryIdList(storyIds),
	}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

#pragma mark - albums

- (void)storyAlbumsInChat:(int64_t)chatId completion:(void (^)(NSArray *, BOOL))completion {
	[self request:@{
		@"@type" : @"getChatStoryAlbums",
		@"chat_id" : @(chatId),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(@[], YES);
			return;
		}
		NSMutableArray *out = [NSMutableArray array];
		for (NSDictionary *raw in TGStoryArray(result[@"albums"])) {
			NSDictionary *album = TGStoryAlbumFlattened(raw);
			if (album)
				[out addObject:album];
		}
		completion(out, NO);
	}];
}

- (void)requestStoryAlbum:(NSDictionary *)request
			   completion:(void (^)(NSDictionary *))completion {
	[self request:request completion:^(NSDictionary *result) {
		if (!completion)
			return;
		completion(TGResultIsError(result) ? nil : TGStoryAlbumFlattened(result));
	}];
}

- (void)createStoryAlbumInChat:(int64_t)chatId
						  name:(NSString *)name
					  storyIds:(NSArray *)storyIds
					completion:(void (^)(NSDictionary *))completion {
	[self requestStoryAlbum:@{
		@"@type" : @"createStoryAlbum",
		@"story_poster_chat_id" : @(chatId),
		@"name" : name ?: @"",
		@"story_ids" : TGStoryIdList(storyIds),
	}
				 completion:completion];
}

- (void)renameStoryAlbum:(NSInteger)albumId
				  inChat:(int64_t)chatId
					name:(NSString *)name
			  completion:(void (^)(NSDictionary *))completion {
	[self requestStoryAlbum:@{
		@"@type" : @"setStoryAlbumName",
		@"chat_id" : @(chatId),
		@"story_album_id" : @(albumId),
		@"name" : name ?: @"",
	}
				 completion:completion];
}

- (void)deleteStoryAlbum:(NSInteger)albumId inChat:(int64_t)chatId {
	[self deleteStoryAlbum:albumId inChat:chatId completion:nil];
}

- (void)deleteStoryAlbum:(NSInteger)albumId
				   inChat:(int64_t)chatId
			   completion:(void (^)(BOOL ok))completion {
	[self request:@{
		@"@type" : @"deleteStoryAlbum",
		@"chat_id" : @(chatId),
		@"story_album_id" : @(albumId),
	}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)reorderStoryAlbums:(NSArray *)albumIds inChat:(int64_t)chatId {
	[self reorderStoryAlbums:albumIds inChat:chatId completion:nil];
}

- (void)reorderStoryAlbums:(NSArray *)albumIds
					 inChat:(int64_t)chatId
				 completion:(void (^)(BOOL ok))completion {
	[self request:@{
		@"@type" : @"reorderStoryAlbums",
		@"chat_id" : @(chatId),
		@"story_album_ids" : TGStoryIdList(albumIds),
	}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)storiesInAlbum:(NSInteger)albumId
				inChat:(int64_t)chatId
				offset:(NSInteger)offset
				 limit:(NSInteger)limit
			completion:(void (^)(NSArray *, NSInteger))completion {
	[self request:@{
		@"@type" : @"getStoryAlbumStories",
		@"chat_id" : @(chatId),
		@"story_album_id" : @(albumId),
		@"offset" : @(offset),
		@"limit" : @(limit > 0 ? limit : 30),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(@[], 0);
			return;
		}
		completion(TGStoriesFlattened(result[@"stories"]),
			[TGStoryNumber(result[@"total_count"]) integerValue]);
	}];
}

- (void)addStories:(NSArray *)storyIds
		   toAlbum:(NSInteger)albumId
			inChat:(int64_t)chatId
		completion:(void (^)(NSDictionary *))completion {
	[self requestStoryAlbum:@{
		@"@type" : @"addStoryAlbumStories",
		@"chat_id" : @(chatId),
		@"story_album_id" : @(albumId),
		@"story_ids" : TGStoryIdList(storyIds),
	}
				 completion:completion];
}

- (void)removeStories:(NSArray *)storyIds
			fromAlbum:(NSInteger)albumId
			   inChat:(int64_t)chatId
		   completion:(void (^)(NSDictionary *))completion {
	[self requestStoryAlbum:@{
		@"@type" : @"removeStoryAlbumStories",
		@"chat_id" : @(chatId),
		@"story_album_id" : @(albumId),
		@"story_ids" : TGStoryIdList(storyIds),
	}
				 completion:completion];
}

- (void)reorderStories:(NSArray *)storyIds
			   inAlbum:(NSInteger)albumId
				inChat:(int64_t)chatId
			completion:(void (^)(NSDictionary *))completion {
	[self requestStoryAlbum:@{
		@"@type" : @"reorderStoryAlbumStories",
		@"chat_id" : @(chatId),
		@"story_album_id" : @(albumId),
		@"story_ids" : TGStoryIdList(storyIds),
	}
				 completion:completion];
}

#pragma mark - search and links

- (void)handleFoundStories:(NSDictionary *)result
				completion:(void (^)(NSArray *, NSString *, NSInteger))completion {
	if (!completion)
		return;
	if (TGResultIsError(result)) {
		completion(@[], @"", 0);
		return;
	}
	completion(TGStoriesFlattened(result[@"stories"]),
		TGStoryString(result[@"next_offset"]),
		[TGStoryNumber(result[@"total_count"]) integerValue]);
}

- (void)searchStoriesWithTag:(NSString *)tag
				posterChatId:(int64_t)posterChatId
					  offset:(NSString *)offset
					   limit:(NSInteger)limit
				  completion:(void (^)(NSArray *, NSString *, NSInteger))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type" : @"searchPublicStoriesByTag",
		@"story_poster_chat_id" : @(posterChatId),
		@"tag" : tag ?: @"",
		@"offset" : offset ?: @"",
		@"limit" : @(limit > 0 ? limit : 20),
	} completion:^(NSDictionary *result) {
		[weakSelf handleFoundStories:result completion:completion];
	}];
}

- (void)searchStoriesAtVenueProvider:(NSString *)provider
							 venueId:(NSString *)venueId
							  offset:(NSString *)offset
							   limit:(NSInteger)limit
						  completion:(void (^)(NSArray *, NSString *, NSInteger))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type" : @"searchPublicStoriesByVenue",
		@"venue_provider" : provider ?: @"",
		@"venue_id" : venueId ?: @"",
		@"offset" : offset ?: @"",
		@"limit" : @(limit > 0 ? limit : 20),
	} completion:^(NSDictionary *result) {
		[weakSelf handleFoundStories:result completion:completion];
	}];
}

- (void)searchStoriesAtCountryCode:(NSString *)countryCode
							 state:(NSString *)state
							  city:(NSString *)city
							street:(NSString *)street
							offset:(NSString *)offset
							 limit:(NSInteger)limit
						completion:(void (^)(NSArray *, NSString *, NSInteger))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type" : @"searchPublicStoriesByLocation",
		@"address" : @{
			@"@type" : @"locationAddress",
			@"country_code" : countryCode ?: @"",
			@"state" : state ?: @"",
			@"city" : city ?: @"",
			@"street" : street ?: @"",
		},
		@"offset" : offset ?: @"",
		@"limit" : @(limit > 0 ? limit : 20),
	} completion:^(NSDictionary *result) {
		[weakSelf handleFoundStories:result completion:completion];
	}];
}

- (void)resolveStoryLink:(NSString *)link
			  completion:(void (^)(int64_t, NSInteger))completion {
	if (!link.length) {
		if (completion)
			completion(0, 0);
		return;
	}
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type" : @"getInternalLinkType",
		@"link" : link,
	} completion:^(NSDictionary *result) {
		NSDictionary *type = TGStoryDict(result);
		if (![type[@"@type"] isEqualToString:@"internalLinkTypeStory"]) {
			if (completion)
				completion(0, 0);
			return;
		}
		NSInteger storyId = [TGStoryNumber(type[@"story_id"]) integerValue];
		NSString *username = TGStoryString(type[@"story_poster_username"]);
		[weakSelf request:@{
			@"@type" : @"searchPublicChat",
			@"username" : username,
		} completion:^(NSDictionary *chat) {
			if (!completion)
				return;
			if (TGResultIsError(chat)) {
				completion(0, 0);
				return;
			}
			completion([TGStoryNumber(chat[@"id"]) longLongValue], storyId);
		}];
	}];
}

#pragma mark - stealth mode and statistics

- (void)activateStoryStealthModeWithCompletion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"activateStoryStealthMode"} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

static NSDictionary *TGStoryGraph(NSString *key, NSString *title, id raw) {
	NSDictionary *g = TGStoryDict(raw);
	if (!g)
		return nil;
	NSString *type = TGStoryString(g[@"@type"]);
	if ([type isEqualToString:@"statisticalGraphData"]) {
		return @{
			@"key" : key,
			@"title" : title,
			@"json" : TGStoryString(g[@"json_data"]) ?: @"",
		};
	}
	if ([type isEqualToString:@"statisticalGraphAsync"]) {
		return @{
			@"key" : key,
			@"title" : title,
			@"token" : TGStoryString(g[@"token"]) ?: @"",
		};
	}
	return nil;
}

- (void)statisticsForStory:(NSInteger)storyId
					inChat:(int64_t)chatId
					isDark:(BOOL)isDark
				completion:(void (^)(NSArray *))completion {
	[self request:@{
		@"@type" : @"getStoryStatistics",
		@"chat_id" : @(chatId),
		@"story_id" : @((int)storyId),
		@"is_dark" : @(isDark),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(nil);
			return;
		}
		NSMutableArray *graphs = [NSMutableArray array];
		NSDictionary *interaction = TGStoryGraph(@"story_interaction_graph", TGL(@"Stats.ViewsAndShares", @"Views and Shares"),
			result[@"story_interaction_graph"]);
		if (interaction)
			[graphs addObject:interaction];
		NSDictionary *reaction = TGStoryGraph(@"story_reaction_graph", @"Reactions",
			result[@"story_reaction_graph"]);
		if (reaction)
			[graphs addObject:reaction];
		completion(graphs);
	}];
}

- (void)editStoryCover:(NSInteger)storyId
				 inChat:(int64_t)chatId
	coverFrameTimestamp:(double)timestamp
			 completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"editStoryCover",
		@"story_poster_chat_id" : @(chatId),
		@"story_id" : @((int)storyId),
		@"cover_frame_timestamp" : @(timestamp),
	} completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

#pragma mark - reporting and notifications

- (void)reportStory:(NSInteger)storyId
			 inChat:(int64_t)chatId
		   optionId:(NSString *)optionId
			   text:(NSString *)text
		 completion:(void (^)(NSDictionary *))completion {
	[self request:@{
		@"@type" : @"reportStory",
		@"story_poster_chat_id" : @(chatId),
		@"story_id" : @(storyId),
		@"option_id" : optionId ?: @"",
		@"text" : text ?: @"",
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		NSString *type = TGStoryString(TGStoryDict(result)[@"@type"]);
		if ([type isEqualToString:@"reportStoryResultOk"]) {
			completion(@{@"status" : @"ok"});
			return;
		}
		if ([type isEqualToString:@"reportStoryResultOptionRequired"]) {
			NSMutableArray *options = [NSMutableArray array];
			for (NSDictionary *raw in TGStoryArray(result[@"options"])) {
				NSDictionary *option = TGStoryDict(raw);
				if (!option)
					continue;
				[options addObject:@{
					@"id" : TGStoryString(option[@"id"]),
					@"text" : TGStoryString(option[@"text"]),
				}];
			}
			completion(@{
				@"status" : @"option",
				@"title" : TGStoryString(result[@"title"]),
				@"options" : options,
			});
			return;
		}
		if ([type isEqualToString:@"reportStoryResultTextRequired"]) {
			completion(@{
				@"status" : @"text",
				@"optionId" : TGStoryString(result[@"option_id"]),
				@"optional" : @([result[@"is_optional"] boolValue]),
			});
			return;
		}
		completion(@{@"status" : @"error"});
	}];
}

- (void)setChat:(int64_t)chatId storiesMuted:(BOOL)muted {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getChat", @"chat_id" : @(chatId)}
		completion:^(NSDictionary *chat) {
			if (TGResultIsError(chat))
				return;
			NSDictionary *current = TGStoryDict(chat[@"notification_settings"]);
			NSMutableDictionary *settings = current ? [current mutableCopy] : [@{@"@type" : @"chatNotificationSettings"} mutableCopy];
			settings[@"@type"] = @"chatNotificationSettings";
			settings[@"use_default_mute_stories"] = @NO;
			settings[@"mute_stories"] = @(muted);
			[weakSelf send:@{
				@"@type" : @"setChatNotificationSettings",
				@"chat_id" : @(chatId),
				@"notification_settings" : settings,
			}];
		}];
}

- (void)storyNotificationExceptionsWithCompletion:(void (^)(NSArray *, BOOL))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getStoryNotificationSettingsExceptions"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			if (TGResultIsError(result)) {
				completion(@[], YES);
				return;
			}
			NSMutableArray *out = [NSMutableArray array];
			for (id one in TGStoryArray(result[@"chat_ids"])) {
				NSNumber *chatId = TGStoryNumber(one);
				if (!chatId)
					continue;
				[out addObject:@{
					@"id" : chatId,
					@"title" : TGStorySenderName(weakSelf, chatId.longLongValue),
				}];
			}
			completion(out, NO);
		}];
}

- (void)setStoryReactionNotificationSource:(NSString *)source {
	[self setStoryReactionNotificationSource:source completion:nil];
}

- (void)setStoryReactionNotificationSource:(NSString *)source
								 completion:(void (^)(BOOL ok))completion {
	[self changeReactionNotificationSettings:@{@"storySource" : source ?: @"none"}
								  completion:completion];
}

- (void)setStoryPreloading:(BOOL)preload onNetwork:(NSString *)type {
	[self setStoryPreloading:preload onNetwork:type completion:nil];
}

- (void)setStoryPreloading:(BOOL)preload
				  onNetwork:(NSString *)type
				 completion:(void (^)(BOOL ok))completion {
	NSDictionary *current =
		TGStoryAutoDownloadFromMirror([self autoDownloadSettingsForNetworkType:type]);
	if (current) {
		NSMutableDictionary *settings = [current mutableCopy];
		settings[@"preload_stories"] = @(preload);
		[self request:@{
			@"@type" : @"setAutoDownloadSettings",
			@"settings" : settings,
			@"type" : @{@"@type" : TGStoryNetworkType(type)},
		}
			completion:^(NSDictionary *result) {
				if (completion)
					completion(!TGResultIsError(result));
			}];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getAutoDownloadSettingsPresets"}
		completion:^(NSDictionary *presets) {
			if (TGResultIsError(presets)) {
				if (completion)
					completion(NO);
				return;
			}
			NSDictionary *base = TGStoryDict(presets[@"low"]);
			if (!base) {
				if (completion)
					completion(NO);
				return;
			}
			NSMutableDictionary *settings = [base mutableCopy];
			settings[@"@type"] = @"autoDownloadSettings";
			settings[@"preload_stories"] = @(preload);
			[weakSelf request:@{
				@"@type" : @"setAutoDownloadSettings",
				@"settings" : settings,
				@"type" : @{@"@type" : TGStoryNetworkType(type)},
			}
				completion:^(NSDictionary *result) {
					if (completion)
						completion(!TGResultIsError(result));
				}];
		}];
}

#pragma mark - account switch

- (void)resetStoryPostCachesForAccountSwitch {
	[TGStoryPostWatcher cancelAllForAccountSwitch];
	[TGStoryComposer cancelAllForAccountSwitch];
}

@end

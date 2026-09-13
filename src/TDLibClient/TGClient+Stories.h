#import "TGClient.h"
#import "TGStoryPeriod.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const TGStoryUpdateNotification;

typedef NS_ENUM(NSInteger, TGStoryViewerSortMode) {
	TGStoryViewerSortRecent = 0,
	TGStoryViewerSortReactions,
	TGStoryViewerSortReposts,
};

@interface TGClient (Stories)

#pragma mark - active stories (the tray)

- (void)loadActiveStoriesArchived:(BOOL)archived;

- (void)activeStoriesForChat:(int64_t)chatId
				  completion:(void (^ _Nullable)(NSDictionary *active))completion;

- (void)setChat:(int64_t)chatId storiesArchived:(BOOL)archived;

#pragma mark - viewing

- (void)storyWithId:(NSInteger)storyId
			 inChat:(int64_t)chatId
		 completion:(void (^ _Nullable)(NSDictionary *story))completion;

- (void)openStory:(NSInteger)storyId inChat:(int64_t)chatId;

- (void)closeStory:(NSInteger)storyId inChat:(int64_t)chatId;

- (void)markStoryRead:(NSInteger)storyId inChat:(int64_t)chatId;

#pragma mark - interactions

- (void)storyReactionsWithLimit:(NSInteger)limit
					 completion:(void (^ _Nullable)(NSArray *emoji))completion;

- (void)reactToStory:(NSInteger)storyId
			  inChat:(int64_t)chatId
			   emoji:(NSString *)emoji;

- (void)viewersOfStory:(NSInteger)storyId
			  sortMode:(TGStoryViewerSortMode)sortMode
				offset:(NSString *)offset
				 limit:(NSInteger)limit
			completion:(void (^ _Nullable)(NSArray *viewers, NSString *nextOffset, NSInteger total,
				BOOL failed))completion;

- (void)viewersOfStory:(NSInteger)storyId
				inChat:(int64_t)chatId
			  sortMode:(TGStoryViewerSortMode)sortMode
				offset:(NSString *)offset
				 limit:(NSInteger)limit
			completion:(void (^ _Nullable)(NSArray *viewers, NSString *nextOffset, NSInteger total,
				BOOL failed))completion;

- (void)replyToStory:(NSInteger)storyId
			  inChat:(int64_t)chatId
				text:(NSString *)text;

- (void)replyToStory:(NSInteger)storyId
			  inChat:(int64_t)chatId
				text:(NSString *)text
		  completion:(nullable void (^)(BOOL ok))completion;

- (void)publicForwardsOfStory:(NSInteger)storyId
					   inChat:(int64_t)chatId
					   offset:(NSString *)offset
						limit:(NSInteger)limit
				   completion:(void (^ _Nullable)(NSArray *forwards, NSString *nextOffset))completion;

#pragma mark - posting

- (void)canPostStoryAsChat:(int64_t)chatId
				completion:(void (^ _Nullable)(BOOL canPost, NSString *reason))completion;

- (void)chatsToPostStoriesWithCompletion:(void (^ _Nullable)(NSArray *chats))completion;

- (void)postPhotoStoryAtPath:(NSString *)path
					  asChat:(int64_t)chatId
					 caption:(NSString *)caption
					 privacy:(NSString *)privacy
					 userIds:(NSArray *)userIds
				   toProfile:(BOOL)toProfile
				  completion:(void (^ _Nullable)(NSDictionary *story))completion;

- (void)postPhotoStoryAtPath:(NSString *)path
					  asChat:(int64_t)chatId
					 caption:(NSString *)caption
					 privacy:(NSString *)privacy
					 userIds:(NSArray *)userIds
				activePeriod:(NSInteger)activePeriod
					   areas:(NSArray * _Nullable)areas
				   toProfile:(BOOL)toProfile
					progress:(void (^ _Nullable)(float fraction))progress
				  completion:(void (^ _Nullable)(NSDictionary *story, NSString *error))completion;

- (void)postVideoStoryAtPath:(NSString *)path
					duration:(double)duration
					  asChat:(int64_t)chatId
					 caption:(NSString *)caption
					 privacy:(NSString *)privacy
					 userIds:(NSArray *)userIds
				activePeriod:(NSInteger)activePeriod
					   areas:(NSArray * _Nullable)areas
				   toProfile:(BOOL)toProfile
					progress:(void (^ _Nullable)(float fraction))progress
				  completion:(void (^ _Nullable)(NSDictionary *story, NSString *error))completion;

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
							reactionEmoji:(NSString *)reactionEmoji;

- (void)messageCanBeSharedInStory:(int64_t)messageId
							inChat:(int64_t)chatId
						completion:(void (^ _Nullable)(BOOL canShare))completion;

- (void)storyLinkAreaCountMaxWithCompletion:(void (^ _Nullable)(NSInteger countMax))completion;

- (void)storyReactionAreaCountMaxWithCompletion:(void (^ _Nullable)(NSInteger countMax))completion;

- (void)repostStory:(NSInteger)storyId
		   fromChat:(int64_t)fromChatId
			 asChat:(int64_t)chatId
			caption:(NSString *)caption
			privacy:(NSString *)privacy
		 completion:(nullable void (^)(NSDictionary *_Nullable story, NSString *_Nullable error))completion;

- (void)editStory:(NSInteger)storyId
		   inChat:(int64_t)chatId
		  caption:(NSString *)caption;

- (void)editStory:(NSInteger)storyId
		   inChat:(int64_t)chatId
		  caption:(NSString *)caption
	   completion:(nullable void (^)(BOOL ok))completion;

- (void)editStory:(NSInteger)storyId
		   inChat:(int64_t)chatId
		photoPath:(NSString *)path
		  caption:(NSString *)caption;

- (void)editStory:(NSInteger)storyId
		   inChat:(int64_t)chatId
		photoPath:(NSString *)path
		  caption:(NSString *)caption
	   completion:(nullable void (^)(BOOL ok))completion;

- (void)deleteStory:(NSInteger)storyId inChat:(int64_t)chatId;

- (void)deleteStory:(NSInteger)storyId
			 inChat:(int64_t)chatId
		 completion:(nullable void (^)(BOOL ok))completion;

#pragma mark - privacy

- (void)setStory:(NSInteger)storyId
		 privacy:(NSString *)privacy
		 userIds:(nullable NSArray *)userIds;

- (void)setStory:(NSInteger)storyId
		 privacy:(NSString *)privacy
		 userIds:(nullable NSArray *)userIds
	  completion:(nullable void (^)(BOOL ok))completion;

- (void)closeFriendsWithCompletion:(void (^ _Nullable)(NSArray *users, BOOL failed))completion;

- (void)hiddenStoryPostersWithCompletion:(void (^ _Nullable)(NSArray *users))completion;

- (void)setUser:(int64_t)userId storiesHidden:(BOOL)hidden;

- (void)setUser:(int64_t)userId
	storiesHidden:(BOOL)hidden
	   completion:(nullable void (^)(BOOL ok))completion;

- (void)setStorySender:(int64_t)senderId
				 isChat:(BOOL)isChat
		  storiesHidden:(BOOL)hidden
			 completion:(nullable void (^)(BOOL ok))completion;

#pragma mark - archive and profile

- (void)archivedStoriesInChat:(int64_t)chatId
				  fromStoryId:(NSInteger)fromStoryId
						limit:(NSInteger)limit
				   completion:(void (^ _Nullable)(NSArray *stories, NSInteger total))completion;

- (void)profileStoriesInChat:(int64_t)chatId
				 fromStoryId:(NSInteger)fromStoryId
					   limit:(NSInteger)limit
				  completion:(void (^ _Nullable)(NSArray *stories, NSArray *pinnedIds, NSInteger total))completion;

- (void)setStory:(NSInteger)storyId inChat:(int64_t)chatId onProfile:(BOOL)onProfile;

- (void)setStory:(NSInteger)storyId
		  inChat:(int64_t)chatId
	   onProfile:(BOOL)onProfile
	  completion:(nullable void (^)(BOOL ok))completion;

- (void)setPinnedStories:(NSArray *)storyIds inChat:(int64_t)chatId;

- (void)setPinnedStories:(NSArray *)storyIds
				   inChat:(int64_t)chatId
			   completion:(nullable void (^)(BOOL ok))completion;

#pragma mark - albums

- (void)storyAlbumsInChat:(int64_t)chatId completion:(void (^ _Nullable)(NSArray *albums, BOOL failed))completion;
- (void)createStoryAlbumInChat:(int64_t)chatId
						  name:(NSString *)name
					  storyIds:(NSArray *)storyIds
					completion:(void (^ _Nullable)(NSDictionary *album))completion;
- (void)renameStoryAlbum:(NSInteger)albumId
				  inChat:(int64_t)chatId
					name:(NSString *)name
			  completion:(void (^ _Nullable)(NSDictionary *album))completion;
- (void)deleteStoryAlbum:(NSInteger)albumId inChat:(int64_t)chatId;

- (void)deleteStoryAlbum:(NSInteger)albumId
				   inChat:(int64_t)chatId
			   completion:(nullable void (^)(BOOL ok))completion;

- (void)reorderStoryAlbums:(NSArray *)albumIds inChat:(int64_t)chatId;

- (void)reorderStoryAlbums:(NSArray *)albumIds
					 inChat:(int64_t)chatId
				 completion:(nullable void (^)(BOOL ok))completion;

- (void)storiesInAlbum:(NSInteger)albumId
				inChat:(int64_t)chatId
				offset:(NSInteger)offset
				 limit:(NSInteger)limit
			completion:(void (^ _Nullable)(NSArray *stories, NSInteger total))completion;

- (void)addStories:(NSArray *)storyIds
		   toAlbum:(NSInteger)albumId
			inChat:(int64_t)chatId
		completion:(void (^ _Nullable)(NSDictionary *album))completion;
- (void)removeStories:(NSArray *)storyIds
			fromAlbum:(NSInteger)albumId
			   inChat:(int64_t)chatId
		   completion:(void (^ _Nullable)(NSDictionary *album))completion;
- (void)reorderStories:(NSArray *)storyIds
			   inAlbum:(NSInteger)albumId
				inChat:(int64_t)chatId
			completion:(void (^ _Nullable)(NSDictionary *album))completion;

#pragma mark - search and links

- (void)searchStoriesWithTag:(NSString *)tag
				posterChatId:(int64_t)posterChatId
					  offset:(NSString *)offset
					   limit:(NSInteger)limit
				  completion:(void (^ _Nullable)(NSArray *stories, NSString *nextOffset, NSInteger total))completion;

- (void)searchStoriesAtVenueProvider:(NSString *)provider
							 venueId:(NSString *)venueId
							  offset:(NSString *)offset
							   limit:(NSInteger)limit
						  completion:(void (^ _Nullable)(NSArray *stories, NSString *nextOffset, NSInteger total))completion;

- (void)searchStoriesAtCountryCode:(NSString *)countryCode
							 state:(NSString *)state
							  city:(NSString *)city
							street:(NSString *)street
							offset:(NSString *)offset
							 limit:(NSInteger)limit
						completion:(void (^ _Nullable)(NSArray *stories, NSString *nextOffset, NSInteger total))completion;

- (void)resolveStoryLink:(NSString *)link
			  completion:(void (^ _Nullable)(int64_t chatId, NSInteger storyId))completion;

#pragma mark - stealth mode and statistics

- (void)activateStoryStealthModeWithCompletion:(void (^ _Nullable)(BOOL ok))completion;

- (void)statisticsForStory:(NSInteger)storyId
					inChat:(int64_t)chatId
					isDark:(BOOL)isDark
				completion:(void (^ _Nullable)(NSArray *graphs))completion;

- (void)editStoryCover:(NSInteger)storyId
				 inChat:(int64_t)chatId
	coverFrameTimestamp:(double)timestamp
			 completion:(nullable void (^)(BOOL ok))completion;

#pragma mark - reporting and notifications

- (void)reportStory:(NSInteger)storyId
			 inChat:(int64_t)chatId
		   optionId:(nullable NSString *)optionId
			   text:(NSString *)text
		 completion:(void (^ _Nullable)(NSDictionary *result))completion;

- (void)setChat:(int64_t)chatId storiesMuted:(BOOL)muted;

- (void)storyNotificationExceptionsWithCompletion:(void (^ _Nullable)(NSArray *chats, BOOL failed))completion;

- (void)setStoryReactionNotificationSource:(NSString *)source;

- (void)setStoryReactionNotificationSource:(NSString *)source
								 completion:(nullable void (^)(BOOL ok))completion;

- (void)setStoryPreloading:(BOOL)preload onNetwork:(NSString *)type;

- (void)setStoryPreloading:(BOOL)preload
				  onNetwork:(NSString *)type
				 completion:(nullable void (^)(BOOL ok))completion;

#pragma mark - account switch

- (void)resetStoryPostCachesForAccountSwitch;

@end

NS_ASSUME_NONNULL_END

#import <Foundation/Foundation.h>

@interface TGStoryService : NSObject

+ (NSArray *)chats;

+ (void)activeStoriesForChat:(int64_t)chatId
				  completion:(void (^)(NSDictionary *active))completion;

+ (void)storyWithId:(NSInteger)storyId
			 inChat:(int64_t)chatId
		 completion:(void (^)(NSDictionary *story))completion;

+ (void)openStory:(NSInteger)storyId inChat:(int64_t)chatId;

+ (void)closeStory:(NSInteger)storyId inChat:(int64_t)chatId;

+ (void)markStoryRead:(NSInteger)storyId inChat:(int64_t)chatId;

+ (void)canPostStoryAsChat:(int64_t)chatId
				completion:(void (^)(BOOL canPost, NSString *reason))completion;

+ (void)chatsToPostStoriesWithCompletion:(void (^)(NSArray *chats))completion;

+ (void)postPhotoStoryAtPath:(NSString *)path
					  asChat:(int64_t)chatId
					 caption:(NSString *)caption
					 privacy:(NSString *)privacy
					 userIds:(NSArray *)userIds
				activePeriod:(NSInteger)activePeriod
					   areas:(NSArray *)areas
				   toProfile:(BOOL)toProfile
					progress:(void (^)(float fraction))progress
				  completion:(void (^)(NSDictionary *story, NSString *error))completion;

+ (void)postVideoStoryAtPath:(NSString *)path
					duration:(double)duration
					  asChat:(int64_t)chatId
					 caption:(NSString *)caption
					 privacy:(NSString *)privacy
					 userIds:(NSArray *)userIds
				activePeriod:(NSInteger)activePeriod
					   areas:(NSArray *)areas
				   toProfile:(BOOL)toProfile
					progress:(void (^)(float fraction))progress
				  completion:(void (^)(NSDictionary *story, NSString *error))completion;

@end

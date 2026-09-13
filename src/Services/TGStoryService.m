#import "TGStoryService.h"
#import "TGClient+Stories.h"

@implementation TGStoryService

+ (NSArray *)chats {
	return [TGClient shared].chats;
}

+ (void)activeStoriesForChat:(int64_t)chatId
				  completion:(void (^)(NSDictionary *active))completion {
	[[TGClient shared] activeStoriesForChat:chatId completion:completion];
}

+ (void)storyWithId:(NSInteger)storyId
			 inChat:(int64_t)chatId
		 completion:(void (^)(NSDictionary *story))completion {
	[[TGClient shared] storyWithId:storyId inChat:chatId completion:completion];
}

+ (void)openStory:(NSInteger)storyId inChat:(int64_t)chatId {
	[[TGClient shared] openStory:storyId inChat:chatId];
}

+ (void)closeStory:(NSInteger)storyId inChat:(int64_t)chatId {
	[[TGClient shared] closeStory:storyId inChat:chatId];
}

+ (void)markStoryRead:(NSInteger)storyId inChat:(int64_t)chatId {
	[[TGClient shared] markStoryRead:storyId inChat:chatId];
}

+ (void)canPostStoryAsChat:(int64_t)chatId
				completion:(void (^)(BOOL canPost, NSString *reason))completion {
	[[TGClient shared] canPostStoryAsChat:chatId completion:completion];
}

+ (void)chatsToPostStoriesWithCompletion:(void (^)(NSArray *chats))completion {
	[[TGClient shared] chatsToPostStoriesWithCompletion:completion];
}

+ (void)postPhotoStoryAtPath:(NSString *)path
					  asChat:(int64_t)chatId
					 caption:(NSString *)caption
					 privacy:(NSString *)privacy
					 userIds:(NSArray *)userIds
				activePeriod:(NSInteger)activePeriod
					   areas:(NSArray *)areas
				   toProfile:(BOOL)toProfile
					progress:(void (^)(float fraction))progress
				  completion:(void (^)(NSDictionary *story, NSString *error))completion {
	[[TGClient shared] postPhotoStoryAtPath:path asChat:chatId caption:caption privacy:privacy
									userIds:userIds
							   activePeriod:activePeriod
									  areas:areas
								  toProfile:toProfile
								   progress:progress
								 completion:completion];
}

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
				  completion:(void (^)(NSDictionary *story, NSString *error))completion {
	[[TGClient shared] postVideoStoryAtPath:path duration:duration asChat:chatId caption:caption
									privacy:privacy
									userIds:userIds
							   activePeriod:activePeriod
									  areas:areas
								  toProfile:toProfile
								   progress:progress
								 completion:completion];
}

@end

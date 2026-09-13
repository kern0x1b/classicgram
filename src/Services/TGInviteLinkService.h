#import <Foundation/Foundation.h>

@interface TGInviteLinkService : NSObject

+ (void)canManageInviteLinksInChat:(int64_t)chatId
						completion:(void (^)(BOOL canManage))completion;

+ (void)primaryInviteLinkForChat:(int64_t)chatId
					  completion:(void (^)(NSString *link))completion;

+ (void)replacePrimaryInviteLinkForChat:(int64_t)chatId
							 completion:(void (^)(NSDictionary *link))completion;

+ (void)inviteLinksForChat:(int64_t)chatId revoked:(BOOL)revoked
				completion:(void (^)(NSArray *links))completion;

+ (void)createInviteLinkForChat:(int64_t)chatId
						   name:(NSString *)name
				 expirationDate:(NSInteger)expirationDate
					memberLimit:(NSInteger)memberLimit
			   requiresApproval:(BOOL)requiresApproval
					 completion:(void (^)(NSDictionary *link))completion;

+ (void)editInviteLink:(NSString *)link
				inChat:(int64_t)chatId
				  name:(NSString *)name
		expirationDate:(NSInteger)expirationDate
		   memberLimit:(NSInteger)memberLimit
	  requiresApproval:(BOOL)requiresApproval
			completion:(void (^)(NSDictionary *link))completion;

+ (void)createSubscriptionInviteLinkForChat:(int64_t)chatId
									   name:(NSString *)name
								  starCount:(int64_t)starCount
								 completion:(void (^)(NSDictionary *link))completion;

+ (void)editSubscriptionInviteLink:(NSString *)link
							inChat:(int64_t)chatId
							  name:(NSString *)name
						completion:(void (^)(NSDictionary *link))completion;

+ (void)revokeInviteLink:(NSString *)link inChat:(int64_t)chatId
			  completion:(void (^)(BOOL ok))completion;

+ (void)deleteRevokedInviteLink:(NSString *)link inChat:(int64_t)chatId
					 completion:(void (^)(BOOL ok))completion;

+ (void)deleteAllRevokedInviteLinksInChat:(int64_t)chatId
							   completion:(void (^)(BOOL ok))completion;

+ (void)joinRequestsForChat:(int64_t)chatId
				 inviteLink:(NSString *)inviteLink
					  query:(NSString *)query
			  offsetRequest:(NSDictionary *)offsetRequest
					  limit:(NSInteger)limit
				 completion:(void (^)(NSArray *requests, NSInteger total, NSDictionary *nextOffset))completion;

+ (void)processJoinRequestFromUser:(int64_t)userId
							inChat:(int64_t)chatId
						   approve:(BOOL)approve
						completion:(void (^)(BOOL ok))completion;

+ (void)processAllJoinRequestsInChat:(int64_t)chatId
						  inviteLink:(NSString *)inviteLink
							 approve:(BOOL)approve
						  completion:(void (^)(BOOL ok))completion;

+ (void)sendInviteLinkText:(NSString *)text
					toChat:(int64_t)chatId
				completion:(void (^)(BOOL ok))completion;

@end

#import "TGInviteLinkService.h"
#import "TGClient+ChatManagement.h"
#import "TGClient+Messages.h"

@implementation TGInviteLinkService

+ (void)canManageInviteLinksInChat:(int64_t)chatId
						completion:(void (^)(BOOL canManage))completion {
	[[TGClient shared] canManageInviteLinksInChat:chatId completion:completion];
}

+ (void)primaryInviteLinkForChat:(int64_t)chatId
					  completion:(void (^)(NSString *link))completion {
	[[TGClient shared] primaryInviteLinkForChat:chatId completion:completion];
}

+ (void)replacePrimaryInviteLinkForChat:(int64_t)chatId
							 completion:(void (^)(NSDictionary *link))completion {
	[[TGClient shared] replacePrimaryInviteLinkForChat:chatId completion:completion];
}

+ (void)inviteLinksForChat:(int64_t)chatId revoked:(BOOL)revoked
				completion:(void (^)(NSArray *links))completion {
	[[TGClient shared] inviteLinksForChat:chatId revoked:revoked completion:completion];
}

+ (void)createInviteLinkForChat:(int64_t)chatId
						   name:(NSString *)name
				 expirationDate:(NSInteger)expirationDate
					memberLimit:(NSInteger)memberLimit
			   requiresApproval:(BOOL)requiresApproval
					 completion:(void (^)(NSDictionary *link))completion {
	[[TGClient shared] createInviteLinkForChat:chatId name:name expirationDate:expirationDate
								   memberLimit:memberLimit
							  requiresApproval:requiresApproval
									completion:completion];
}

+ (void)editInviteLink:(NSString *)link
				inChat:(int64_t)chatId
				  name:(NSString *)name
		expirationDate:(NSInteger)expirationDate
		   memberLimit:(NSInteger)memberLimit
	  requiresApproval:(BOOL)requiresApproval
			completion:(void (^)(NSDictionary *link))completion {
	[[TGClient shared] editInviteLink:link inChat:chatId name:name expirationDate:expirationDate
						  memberLimit:memberLimit
					 requiresApproval:requiresApproval
						   completion:completion];
}

+ (void)createSubscriptionInviteLinkForChat:(int64_t)chatId
									   name:(NSString *)name
								  starCount:(int64_t)starCount
								 completion:(void (^)(NSDictionary *link))completion {
	[[TGClient shared] createSubscriptionInviteLinkForChat:chatId name:name starCount:starCount
												completion:completion];
}

+ (void)editSubscriptionInviteLink:(NSString *)link
							inChat:(int64_t)chatId
							  name:(NSString *)name
						completion:(void (^)(NSDictionary *link))completion {
	[[TGClient shared] editSubscriptionInviteLink:link inChat:chatId name:name completion:completion];
}

+ (void)revokeInviteLink:(NSString *)link inChat:(int64_t)chatId
			  completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] revokeInviteLink:link inChat:chatId completion:completion];
}

+ (void)deleteRevokedInviteLink:(NSString *)link inChat:(int64_t)chatId
					 completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] deleteRevokedInviteLink:link inChat:chatId completion:completion];
}

+ (void)deleteAllRevokedInviteLinksInChat:(int64_t)chatId
							   completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] deleteAllRevokedInviteLinksInChat:chatId completion:completion];
}

+ (void)joinRequestsForChat:(int64_t)chatId
				 inviteLink:(NSString *)inviteLink
					  query:(NSString *)query
			  offsetRequest:(NSDictionary *)offsetRequest
					  limit:(NSInteger)limit
				 completion:(void (^)(NSArray *requests, NSInteger total, NSDictionary *nextOffset))completion {
	[[TGClient shared] joinRequestsForChat:chatId inviteLink:inviteLink query:query
							  offsetRequest:offsetRequest
									 limit:limit
								completion:completion];
}

+ (void)processJoinRequestFromUser:(int64_t)userId
							inChat:(int64_t)chatId
						   approve:(BOOL)approve
						completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] processJoinRequestFromUser:userId inChat:chatId approve:approve
									   completion:completion];
}

+ (void)processAllJoinRequestsInChat:(int64_t)chatId
						  inviteLink:(NSString *)inviteLink
							 approve:(BOOL)approve
						  completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] processAllJoinRequestsInChat:chatId inviteLink:inviteLink approve:approve
										 completion:completion];
}

+ (void)sendInviteLinkText:(NSString *)text
					toChat:(int64_t)chatId
				completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] sendText:text
						 toChat:chatId
						 thread:0
					 savedTopic:0
						replyTo:0
						options:nil
					 completion:^(NSDictionary *message) {
		if (completion)
			completion(message.count > 0);
	}];
}

@end

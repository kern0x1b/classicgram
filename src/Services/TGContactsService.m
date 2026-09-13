#import "TGContactsService.h"
#import "TGClient+Contacts.h"
#import "TGClient+SecretChats.h"
#import "TGClient+UserStatus.h"
#import "TGClient+WebLinks.h"

@implementation TGContactsService

+ (NSDictionary *)me {
	return [TGClient shared].me;
}

+ (void)contactsWithCompletion:(void (^)(NSArray *users))completion {
	[[TGClient shared] contactsWithCompletion:completion];
}

+ (void)searchContacts:(NSString *)query
				 limit:(NSInteger)limit
			completion:(void (^)(NSArray *users, BOOL failed))completion {
	[[TGClient shared] searchContacts:query limit:limit completion:completion];
}

+ (void)addContactWithUserId:(int64_t)userId
					   phone:(NSString *)phone
				   firstName:(NSString *)firstName
					lastName:(NSString *)lastName
			sharePhoneNumber:(BOOL)share
				  completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] addContactWithUserId:userId
									  phone:phone
								  firstName:firstName
								   lastName:lastName
						   sharePhoneNumber:share
								 completion:completion];
}

+ (void)removeContacts:(NSArray *)userIds completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] removeContacts:userIds completion:completion];
}

+ (void)userForPhone:(NSString *)phone completion:(void (^)(NSDictionary *user))completion {
	[[TGClient shared] userForPhone:phone completion:completion];
}

+ (void)importContactWithPhone:(NSString *)phone
					 firstName:(NSString *)firstName
					  lastName:(NSString *)lastName
					completion:(void (^)(BOOL ok, int64_t userId))completion {
	[[TGClient shared] importContactWithPhone:phone firstName:firstName lastName:lastName completion:completion];
}

+ (void)sharePhoneNumberWithUser:(int64_t)userId completion:(void (^)(BOOL))completion {
	[[TGClient shared] sharePhoneNumberWithUser:userId completion:completion];
}

+ (void)userIdForUsername:(NSString *)username completion:(void (^)(int64_t userId, BOOL failed))completion {
	[[TGClient shared] userIdForUsername:username completion:completion];
}

+ (void)businessBotEligibilityForUserId:(int64_t)userId
							  completion:(void (^)(BOOL isBot, BOOL canConnectToBusiness))completion {
	[[TGClient shared] businessBotEligibilityForUserId:userId completion:completion];
}

+ (void)contactFlagsForUser:(int64_t)userId
				 completion:(void (^)(NSDictionary *flags))completion {
	[[TGClient shared] contactFlagsForUser:userId completion:completion];
}

+ (void)syncImportedContacts:(NSArray *)contacts
				  completion:(void (^)(NSArray *userIds))completion {
	[[TGClient shared] syncImportedContacts:contacts completion:completion];
}

+ (void)importContacts:(NSArray *)contacts
			completion:(void (^)(NSArray *userIds))completion {
	[[TGClient shared] importContacts:contacts completion:completion];
}

+ (void)importedContactCountWithCompletion:(void (^)(NSInteger count))completion {
	[[TGClient shared] importedContactCountWithCompletion:completion];
}

+ (void)clearImportedContactsWithCompletion:(void (^)(BOOL ok))completion {
	[[TGClient shared] clearImportedContactsWithCompletion:completion];
}

+ (void)userForToken:(NSString *)token
		  completion:(void (^)(NSDictionary *user))completion {
	[[TGClient shared] userForToken:token completion:completion];
}

+ (void)myContactLinkWithCompletion:(void (^)(NSString *url, NSInteger expiresIn))completion {
	[[TGClient shared] myContactLinkWithCompletion:completion];
}

+ (void)resolveContactQRCode:(NSString *)payload
				   completion:(void (^)(NSDictionary *user, BOOL recognizedCode))completion {
	if (!payload.length) {
		if (completion)
			completion(nil, NO);
		return;
	}
	[[TGClient shared] resolveLink:payload completion:^(NSDictionary *link) {
		NSString *kind = link[@"kind"];
		if ([kind isEqualToString:@"userToken"]) {
			NSString *token = link[@"token"];
			if (!token.length) {
				if (completion)
					completion(nil, NO);
				return;
			}
			[[TGClient shared] userForToken:token completion:^(NSDictionary *user) {
				if (completion)
					completion(user, YES);
			}];
			return;
		}
		if ([kind isEqualToString:@"publicChat"]) {
			NSString *username = link[@"username"];
			if (!username.length) {
				if (completion)
					completion(nil, NO);
				return;
			}
			[[TGClient shared] userForUsername:username completion:^(NSDictionary *user) {
				if (completion)
					completion(user, YES);
			}];
			return;
		}
		if (completion)
			completion(nil, NO);
	}];
}

+ (void)contactCloseFriendsWithCompletion:(void (^)(NSArray *users, BOOL failed))completion {
	[[TGClient shared] contactCloseFriendsWithCompletion:completion];
}

+ (void)setUser:(int64_t)userId closeFriend:(BOOL)closeFriend
	 completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setUser:userId closeFriend:closeFriend completion:completion];
}

+ (void)myUsernamesWithCompletion:(void (^)(NSDictionary *usernames))completion {
	[[TGClient shared] myUsernamesWithCompletion:completion];
}

+ (void)setMyBirthdateDay:(NSInteger)day
					month:(NSInteger)month
					 year:(NSInteger)year
			   completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setMyBirthdateDay:day month:month year:year completion:completion];
}

+ (void)suggestBirthdateToUser:(int64_t)userId
						   day:(NSInteger)day
						 month:(NSInteger)month
						  year:(NSInteger)year
					completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] suggestBirthdateToUser:userId day:day month:month year:year completion:completion];
}

+ (void)birthdateForUser:(int64_t)userId
			  completion:(void (^)(NSDictionary *birthdate))completion {
	[[TGClient shared] birthdateForUser:userId completion:completion];
}

+ (void)badgesForUser:(int64_t)userId
		   completion:(void (^)(NSDictionary *badges))completion {
	[[TGClient shared] badgesForUser:userId completion:completion];
}

+ (int)secretChatIdForChat:(int64_t)chatId {
	return [[TGClient shared] secretChatIdForChat:chatId];
}

+ (void)createSecretChatWithUser:(int64_t)userId
					  completion:(void (^)(NSDictionary *info))completion {
	[[TGClient shared] createSecretChatWithUser:userId completion:completion];
}

+ (void)openSecretChatId:(int)secretChatId
			  completion:(void (^)(int64_t chatId))completion {
	[[TGClient shared] openSecretChatId:secretChatId completion:completion];
}

+ (void)privateChatWithUser:(int64_t)userId completion:(void (^)(int64_t chatId))completion {
	[[TGClient shared] privateChatWithUser:userId completion:completion];
}

+ (BOOL)isSecretChat:(int64_t)chatId {
	return [[TGClient shared] isSecretChat:chatId];
}

+ (void)isUserBlocked:(int64_t)userId completion:(void (^)(BOOL blocked))completion {
	[[TGClient shared] isUserBlocked:userId completion:completion];
}

+ (void)noteForUser:(int64_t)userId completion:(void (^)(NSString *note))completion {
	[[TGClient shared] noteForUser:userId completion:completion];
}

+ (void)setNote:(NSString *)note forUser:(int64_t)userId completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setNote:note forUser:userId completion:completion];
}

+ (void)personalChatForUser:(int64_t)userId completion:(void (^)(int64_t chatId))completion {
	[[TGClient shared] personalChatForUser:userId completion:completion];
}

+ (void)giftEligibilityForUser:(int64_t)userId
					 completion:(void (^)(BOOL acceptsGifts, BOOL acceptsPremiumGift))completion {
	[[TGClient shared] giftEligibilityForUser:userId completion:completion];
}

+ (void)profilePhotosForUser:(int64_t)userId
					  offset:(NSInteger)offset
					   limit:(NSInteger)limit
				  completion:(void (^)(NSArray *photos, NSInteger total))completion {
	[[TGClient shared] profilePhotosForUser:userId offset:offset limit:limit completion:completion];
}

+ (void)groupsInCommonWithUser:(int64_t)userId
					completion:(void (^)(NSArray *chats))completion {
	[[TGClient shared] groupsInCommonWithUser:userId completion:completion];
}

+ (void)removePersonalPhotoForUser:(int64_t)userId completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] removePersonalPhotoForUser:userId completion:completion];
}

+ (void)setPersonalPhotoAtPath:(NSString *)path
					   forUser:(int64_t)userId
					   suggest:(BOOL)suggest
					completion:(void (^)(BOOL ok))completion {
	[[TGClient shared] setPersonalPhotoAtPath:path forUser:userId suggest:suggest completion:completion];
}

+ (void)emojiStatusForUser:(int64_t)userId
				completion:(void (^)(NSDictionary *status))completion {
	[[TGClient shared] emojiStatusForUser:userId completion:completion];
}

+ (void)emojiStatusForChat:(int64_t)chatId
				completion:(void (^)(NSDictionary *status))completion {
	[[TGClient shared] emojiStatusForChat:chatId completion:completion];
}

+ (void)botVerificationForUser:(int64_t)userId
					completion:(void (^)(NSDictionary *badge))completion {
	[[TGClient shared] botVerificationForUser:userId completion:completion];
}

+ (void)botVerificationForChat:(int64_t)chatId
					completion:(void (^)(NSDictionary *badge))completion {
	[[TGClient shared] botVerificationForChat:chatId completion:completion];
}

+ (void)badgesForChat:(int64_t)chatId
		   completion:(void (^)(NSDictionary *badges))completion {
	[[TGClient shared] badgesForChat:chatId completion:completion];
}

+ (void)statusInfoForUser:(int64_t)userId
			   completion:(void (^)(NSDictionary *info))completion {
	[[TGClient shared] statusInfoForUser:userId completion:completion];
}

+ (void)groupOnlineSummaryForChat:(int64_t)chatId
					   completion:(void (^)(NSString *text, NSInteger members,
									  NSInteger online))completion {
	[[TGClient shared] groupOnlineSummaryForChat:chatId completion:completion];
}

+ (NSString *)hiddenStatusHintForStatusInfo:(NSDictionary *)info {
	return [TGClient hiddenStatusHintForStatusInfo:info];
}

+ (NSString *)userStatusDidChangeNotificationName {
	return TGUserStatusDidChangeNotification;
}

+ (NSString *)contactsDidChangeNotificationName {
	return TGContactsDidChangeNotification;
}

@end

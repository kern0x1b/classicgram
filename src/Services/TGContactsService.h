#import <Foundation/Foundation.h>

@interface TGContactsService : NSObject

+ (NSDictionary *)me;

+ (void)contactsWithCompletion:(void (^)(NSArray *users))completion;

+ (void)searchContacts:(NSString *)query
				 limit:(NSInteger)limit
			completion:(void (^)(NSArray *users, BOOL failed))completion;

+ (void)addContactWithUserId:(int64_t)userId
					   phone:(NSString *)phone
				   firstName:(NSString *)firstName
					lastName:(NSString *)lastName
			sharePhoneNumber:(BOOL)share
				  completion:(void (^)(BOOL ok))completion;

+ (void)removeContacts:(NSArray *)userIds completion:(void (^)(BOOL ok))completion;

+ (void)userForPhone:(NSString *)phone completion:(void (^)(NSDictionary *user))completion;

+ (void)importContactWithPhone:(NSString *)phone
					 firstName:(NSString *)firstName
					  lastName:(NSString *)lastName
					completion:(void (^)(BOOL ok, int64_t userId))completion;

+ (void)sharePhoneNumberWithUser:(int64_t)userId completion:(void (^)(BOOL ok))completion;

+ (void)userIdForUsername:(NSString *)username completion:(void (^)(int64_t userId, BOOL failed))completion;

+ (void)businessBotEligibilityForUserId:(int64_t)userId
							  completion:(void (^)(BOOL isBot, BOOL canConnectToBusiness))completion;

+ (void)contactFlagsForUser:(int64_t)userId
				 completion:(void (^)(NSDictionary *flags))completion;

+ (void)syncImportedContacts:(NSArray *)contacts
				  completion:(void (^)(NSArray *userIds))completion;

+ (void)importContacts:(NSArray *)contacts
			completion:(void (^)(NSArray *userIds))completion;

+ (void)importedContactCountWithCompletion:(void (^)(NSInteger count))completion;

+ (void)clearImportedContactsWithCompletion:(void (^)(BOOL ok))completion;

+ (void)userForToken:(NSString *)token
		  completion:(void (^)(NSDictionary *user))completion;

+ (void)myContactLinkWithCompletion:(void (^)(NSString *url, NSInteger expiresIn))completion;
+ (void)resolveContactQRCode:(NSString *)payload
				   completion:(void (^)(NSDictionary *user, BOOL recognizedCode))completion;

+ (void)contactCloseFriendsWithCompletion:(void (^)(NSArray *users, BOOL failed))completion;

+ (void)setUser:(int64_t)userId closeFriend:(BOOL)closeFriend
	 completion:(void (^)(BOOL ok))completion;

+ (void)myUsernamesWithCompletion:(void (^)(NSDictionary *usernames))completion;

+ (void)setMyBirthdateDay:(NSInteger)day
					month:(NSInteger)month
					 year:(NSInteger)year
			   completion:(void (^)(BOOL ok))completion;

+ (void)suggestBirthdateToUser:(int64_t)userId
						   day:(NSInteger)day
						 month:(NSInteger)month
						  year:(NSInteger)year
					completion:(void (^)(BOOL ok))completion;

+ (void)birthdateForUser:(int64_t)userId
			  completion:(void (^)(NSDictionary *birthdate))completion;

+ (void)badgesForUser:(int64_t)userId
		   completion:(void (^)(NSDictionary *badges))completion;

+ (int)secretChatIdForChat:(int64_t)chatId;

+ (void)createSecretChatWithUser:(int64_t)userId
					  completion:(void (^)(NSDictionary *info))completion;

+ (void)openSecretChatId:(int)secretChatId
			  completion:(void (^)(int64_t chatId))completion;

+ (void)privateChatWithUser:(int64_t)userId completion:(void (^)(int64_t chatId))completion;

+ (BOOL)isSecretChat:(int64_t)chatId;

+ (void)isUserBlocked:(int64_t)userId completion:(void (^)(BOOL blocked))completion;

+ (void)noteForUser:(int64_t)userId completion:(void (^)(NSString *note))completion;

+ (void)setNote:(NSString *)note forUser:(int64_t)userId completion:(void (^)(BOOL ok))completion;

+ (void)personalChatForUser:(int64_t)userId completion:(void (^)(int64_t chatId))completion;

+ (void)giftEligibilityForUser:(int64_t)userId
					 completion:(void (^)(BOOL acceptsGifts, BOOL acceptsPremiumGift))completion;

+ (void)profilePhotosForUser:(int64_t)userId
					  offset:(NSInteger)offset
					   limit:(NSInteger)limit
				  completion:(void (^)(NSArray *photos, NSInteger total))completion;

+ (void)groupsInCommonWithUser:(int64_t)userId
					completion:(void (^)(NSArray *chats))completion;

+ (void)removePersonalPhotoForUser:(int64_t)userId completion:(void (^)(BOOL ok))completion;

+ (void)setPersonalPhotoAtPath:(NSString *)path
					   forUser:(int64_t)userId
					   suggest:(BOOL)suggest
					completion:(void (^)(BOOL ok))completion;

+ (void)emojiStatusForUser:(int64_t)userId
				completion:(void (^)(NSDictionary *status))completion;

+ (void)emojiStatusForChat:(int64_t)chatId
				completion:(void (^)(NSDictionary *status))completion;

+ (void)botVerificationForUser:(int64_t)userId
					completion:(void (^)(NSDictionary *badge))completion;

+ (void)botVerificationForChat:(int64_t)chatId
					completion:(void (^)(NSDictionary *badge))completion;

+ (void)badgesForChat:(int64_t)chatId
		   completion:(void (^)(NSDictionary *badges))completion;

+ (void)statusInfoForUser:(int64_t)userId
			   completion:(void (^)(NSDictionary *info))completion;

+ (void)groupOnlineSummaryForChat:(int64_t)chatId
					   completion:(void (^)(NSString *text, NSInteger members,
									  NSInteger online))completion;

+ (NSString *)hiddenStatusHintForStatusInfo:(NSDictionary *)info;

+ (NSString *)userStatusDidChangeNotificationName;

+ (NSString *)contactsDidChangeNotificationName;

@end

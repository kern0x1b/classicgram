#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const TGContactsDidChangeNotification;
extern NSString *const TGCloseBirthdaysDidChangeNotification;

@interface TGClient (Contacts)

#pragma mark - contact list

- (void)searchContacts:(NSString *)query
				 limit:(NSInteger)limit
			completion:(void (^ _Nullable)(NSArray *users, BOOL failed))completion;

- (void)addContactWithUserId:(int64_t)userId
					   phone:(NSString *)phone
				   firstName:(NSString *)firstName
					lastName:(NSString *)lastName
			sharePhoneNumber:(BOOL)share
				  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)importContactWithPhone:(NSString *)phone
					 firstName:(NSString *)firstName
					  lastName:(NSString *)lastName
					completion:(void (^ _Nullable)(BOOL ok, int64_t userId))completion;

- (void)removeContacts:(NSArray *)userIds completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)sharePhoneNumberWithUser:(int64_t)userId completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)contactFlagsForUser:(int64_t)userId
				 completion:(void (^ _Nullable)(NSDictionary *flags))completion;

#pragma mark - address book

- (void)syncImportedContacts:(NSArray *)contacts
				  completion:(void (^ _Nullable)(NSArray *userIds))completion;

- (void)importContacts:(NSArray *)contacts
			completion:(void (^ _Nullable)(NSArray *userIds))completion;

- (void)importedContactCountWithCompletion:(void (^ _Nullable)(NSInteger count))completion;

- (void)clearImportedContactsWithCompletion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - finding people

- (void)userForToken:(NSString *)token
		  completion:(void (^ _Nullable)(NSDictionary *user))completion;

- (void)userForUsername:(NSString *)username
			  completion:(void (^ _Nullable)(NSDictionary *user))completion;

- (void)userForPhoneNumber:(NSString *)phoneNumber
				 onlyLocal:(BOOL)onlyLocal
				completion:(void (^ _Nullable)(NSDictionary *user))completion;

- (void)userIdForUsername:(NSString *)username
			   completion:(void (^ _Nullable)(int64_t userId, BOOL failed))completion;

- (void)businessBotEligibilityForUserId:(int64_t)userId
							  completion:(void (^ _Nullable)(BOOL isBot, BOOL canConnectToBusiness))completion;

- (void)myContactLinkWithCompletion:(void (^ _Nullable)(NSString *url, NSInteger expiresIn))completion;

#pragma mark - close friends

- (void)contactCloseFriendsWithCompletion:(void (^ _Nullable)(NSArray *users, BOOL failed))completion;

- (void)setCloseFriends:(NSArray *)userIds completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setUser:(int64_t)userId closeFriend:(BOOL)closeFriend
	 completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - own usernames

- (void)myUsernamesWithCompletion:(void (^ _Nullable)(NSDictionary *usernames))completion;

- (void)checkUsernameAvailable:(NSString *)username
					completion:(void (^ _Nullable)(NSString *status))completion;

#pragma mark - profile photos

- (void)profilePhotosForUser:(int64_t)userId
					  offset:(NSInteger)offset
					   limit:(NSInteger)limit
				  completion:(void (^ _Nullable)(NSArray *photos, NSInteger total))completion;

- (void)setPersonalPhotoAtPath:(NSString *)path
					   forUser:(int64_t)userId
					   suggest:(BOOL)suggest
					completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)removePersonalPhotoForUser:(int64_t)userId completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - birthdays

- (void)setMyBirthdateDay:(NSInteger)day
					month:(NSInteger)month
					 year:(NSInteger)year
			   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)suggestBirthdateToUser:(int64_t)userId
						   day:(NSInteger)day
						 month:(NSInteger)month
						  year:(NSInteger)year
					completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)birthdateForUser:(int64_t)userId
			  completion:(void (^ _Nullable)(NSDictionary *birthdate))completion;

- (void)hideContactCloseBirthdays;
- (void)handleUpdateContactCloseBirthdays:(NSDictionary *)update;

#pragma mark - profile extras

- (void)noteForUser:(int64_t)userId completion:(void (^ _Nullable)(NSString *note))completion;
- (void)setNote:(NSString *)note forUser:(int64_t)userId completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)groupsInCommonWithUser:(int64_t)userId
					completion:(void (^ _Nullable)(NSArray *chats))completion;

- (void)suitablePersonalChatsWithCompletion:(void (^ _Nullable)(NSArray *chats, BOOL failed))completion;

- (void)personalChatForUser:(int64_t)userId completion:(void (^ _Nullable)(int64_t chatId))completion;

- (void)setMainProfileTab:(NSString *)tab completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)mainProfileTabForUser:(int64_t)userId completion:(void (^ _Nullable)(NSString *tab))completion;

- (void)giftEligibilityForUser:(int64_t)userId
					 completion:(void (^ _Nullable)(BOOL acceptsGifts, BOOL acceptsPremiumGift))completion;

#pragma mark - support

- (void)supportContactWithCompletion:(void (^ _Nullable)(NSDictionary *support))completion;

- (void)isUserBlocked:(int64_t)userId completion:(void (^ _Nullable)(BOOL blocked))completion;

- (void)contactsWithCompletion:(void (^ _Nullable)(NSArray *users))completion;
- (void)addContactWithPhone:(NSString *)phone
				  firstName:(NSString *)firstName
				   lastName:(NSString *)lastName
				 completion:(void (^ _Nullable)(BOOL ok))completion;
- (void)privateChatWithUser:(int64_t)userId completion:(void (^ _Nullable)(int64_t chatId))completion;
- (void)canSendMessageToUser:(int64_t)userId
				  completion:(void (^ _Nullable)(BOOL canSend, BOOL isPaid, NSInteger starCount, NSString *blockReason))completion;
- (void)userForPhone:(NSString *)phone completion:(void (^ _Nullable)(NSDictionary *user))completion;

@end

NS_ASSUME_NONNULL_END

#import "TGClient+ChatManagement.h"
#import "TGStringTruncation.h"
#import "TGClient+Private.h"
#import "TGClient+Contacts.h"
#import "TGPerfLogging.h"
#import "TGFlattenContacts.h"

static const NSTimeInterval kContactsFetchRetryAfter = 15.0;

NSString *const TGContactsDidChangeNotification = @"TGContactsDidChangeNotification";
NSString *const TGCloseBirthdaysDidChangeNotification = @"TGCloseBirthdaysDidChangeNotification";

static NSDictionary *TGDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSArray *TGArray(id value) {
	return [value isKindOfClass:NSArray.class] ? value : nil;
}

static NSString *TGString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

static long long TGInt64(id value) {
	if ([value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSString.class])
		return [value longLongValue];
	return 0;
}

static NSNumber *TGFileId(NSDictionary *file) {
	NSDictionary *f = TGDict(file);
	NSNumber *fid = [f[@"id"] isKindOfClass:NSNumber.class] ? f[@"id"] : nil;
	return fid;
}

@implementation TGClient (Contacts)

#pragma mark - shared plumbing

- (void)tg_fetchUsers:(NSArray *)ids completion:(void (^)(NSArray *))completion {
	NSMutableArray *wanted = [NSMutableArray array];
	for (id uid in TGArray(ids) ?: @[]) {
		if ([uid isKindOfClass:NSNumber.class] && [uid longLongValue] != 0)
			[wanted addObject:uid];
	}
	if (!wanted.count) {
		if (completion)
			completion(@[]);
		return;
	}
	NSMutableArray *slots = [NSMutableArray array];
	for (NSInteger i = 0; i < wanted.count; i++)
		[slots addObject:[NSNull null]];

	__block NSUInteger left = wanted.count;
	for (NSInteger i = 0; i < wanted.count; i++) {
		NSInteger index = i;
		[self request:@{@"@type" : @"getUser", @"user_id" : wanted[i]}
			completion:^(NSDictionary *u) {
				NSDictionary *flat = TGFlatUser(u);
				if (flat) {
					NSDictionary *status = TGUserStatusInfo(u[@"status"]);
					NSMutableDictionary *merged = [flat mutableCopy];
					merged[@"isOnline"] = status[@"isOnline"];
					merged[@"statusText"] = status[@"text"];
					merged[@"statusRank"] = status[@"rank"];
					flat = merged;
				}
				if (flat)
					[slots replaceObjectAtIndex:index withObject:flat];
				if (--left > 0)
					return;
				NSMutableArray *users = [NSMutableArray array];
				for (id slot in slots) {
					if ([slot isKindOfClass:NSDictionary.class])
						[users addObject:slot];
				}
				if (completion)
					completion(users);
			}];
	}
}

- (void)tg_fetchChats:(NSArray *)ids completion:(void (^)(NSArray *))completion {
	NSArray *chatIds = TGArray(ids);
	if (!chatIds.count) {
		if (completion)
			completion(@[]);
		return;
	}
	NSMutableArray *slots = [NSMutableArray array];
	for (NSInteger i = 0; i < chatIds.count; i++)
		[slots addObject:[NSNull null]];

	__block NSUInteger left = chatIds.count;
	for (NSInteger i = 0; i < chatIds.count; i++) {
		NSInteger index = i;
		[self request:@{@"@type" : @"getChat", @"chat_id" : chatIds[i]}
			completion:^(NSDictionary *chat) {
				if ([chat[@"@type"] isEqualToString:@"chat"]) {
					[slots replaceObjectAtIndex:index withObject:@{
						@"id" : chat[@"id"] ?: @(0),
						@"title" : TGString(chat[@"title"]),
					}];
				}
				if (--left > 0)
					return;
				NSMutableArray *out = [NSMutableArray array];
				for (id slot in slots) {
					if ([slot isKindOfClass:NSDictionary.class])
						[out addObject:slot];
				}
				if (completion)
					completion(out);
			}];
	}
}

- (void)tg_ok:(NSDictionary *)request completion:(void (^)(BOOL))completion {
	[self request:request completion:^(NSDictionary *result) {
		if (completion)
			completion(!TGResultIsError(result));
	}];
}

- (void)tg_userFull:(int64_t)userId completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getUserFullInfo", @"user_id" : @(userId)}
		completion:^(NSDictionary *full) {
			if (!completion)
				return;
			completion(TGResultIsError(full) ? nil : full);
		}];
}

- (NSArray *)tg_contactsWithNonEmptyPhone:(NSArray *)contacts {
	NSMutableArray *out = [NSMutableArray array];
	for (id entry in TGArray(contacts) ?: @[]) {
		NSDictionary *c = TGDict(entry);
		if (!c)
			continue;
		NSString *phone = TGString(c[@"phone"]);
		if (!phone.length)
			phone = TGString(c[@"phone_number"]);
		if (!phone.length)
			continue;
		[out addObject:c];
	}
	return out;
}

- (NSArray *)tg_importedContacts:(NSArray *)contacts {
	NSMutableArray *out = [NSMutableArray arrayWithCapacity:contacts.count];
	for (NSDictionary *c in contacts) {
		NSString *phone = TGString(c[@"phone"]);
		if (!phone.length)
			phone = TGString(c[@"phone_number"]);
		[out addObject:@{
			@"@type" : @"importedContact",
			@"phone_number" : phone,
			@"first_name" : TGString(c[@"first_name"]),
			@"last_name" : TGString(c[@"last_name"]),
		}];
	}
	return out;
}

- (void)tg_import:(NSString *)method contacts:(NSArray *)contacts
	   completion:(void (^)(NSArray *))completion {
	NSArray *validContacts = [self tg_contactsWithNonEmptyPhone:contacts];
	NSArray *payload = [self tg_importedContacts:validContacts];
	if (!payload.count) {
		if (completion)
			completion(@[]);
		return;
	}
	[self request:@{@"@type" : method, @"contacts" : payload}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			NSArray *ids = TGResultIsError(result) ? nil : TGArray(result[@"user_ids"]);
			completion(ids ?: @[]);
		}];
}

- (NSDictionary *)tg_inputPhotoAtPath:(NSString *)path {
	return @{
		@"@type" : @"inputChatPhotoStatic",
		@"photo" : @{@"@type" : @"inputFileLocal", @"path" : path ?: @""},
	};
}

#pragma mark - contact list

- (void)searchContacts:(NSString *)query limit:(NSInteger)limit
			completion:(void (^)(NSArray *, BOOL))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type" : @"searchContacts",
		@"query" : query ?: @"",
		@"limit" : @(limit > 0 ? limit : 50),
	} completion:^(NSDictionary *result) {
		if (TGResultIsError(result)) {
			if (completion)
				completion(@[], YES);
			return;
		}
		[weakSelf tg_fetchUsers:result[@"user_ids"] completion:^(NSArray *users) {
			if (completion)
				completion(users, NO);
		}];
	}];
}

- (void)addContactWithUserId:(int64_t)userId
					   phone:(NSString *)phone
				   firstName:(NSString *)firstName
					lastName:(NSString *)lastName
			sharePhoneNumber:(BOOL)share
				  completion:(void (^)(BOOL))completion {
	[self tg_ok:@{
		@"@type" : @"addContact",
		@"user_id" : @(userId),
		@"contact" : @{
			@"@type" : @"importedContact",
			@"phone_number" : phone ?: @"",
			@"first_name" : firstName ?: @"",
			@"last_name" : lastName ?: @"",
		},
		@"share_phone_number" : @(share),
	} completion:^(BOOL ok) {
		if (ok)
			[[NSNotificationCenter defaultCenter]
				postNotificationName:TGContactsDidChangeNotification
							  object:nil];
		if (completion)
			completion(ok);
	}];
}

- (void)importContactWithPhone:(NSString *)phone
					 firstName:(NSString *)firstName
					  lastName:(NSString *)lastName
					completion:(void (^)(BOOL, int64_t))completion {
	if (!phone.length) {
		if (completion)
			completion(NO, 0);
		return;
	}
	[self importContacts:@[ @{
		@"phone" : phone,
		@"first_name" : firstName ?: @"",
		@"last_name" : lastName ?: @"",
	} ] completion:^(NSArray *userIds) {
		if (!userIds.count) {
			if (completion)
				completion(NO, 0);
			return;
		}
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGContactsDidChangeNotification
						  object:nil];
		if (!completion)
			return;
		id first = [userIds objectAtIndex:0];
		completion(YES, [first respondsToSelector:@selector(longLongValue)]
				? [first longLongValue]
				: 0);
	}];
}

- (void)removeContacts:(NSArray *)userIds completion:(void (^)(BOOL))completion {
	NSArray *ids = TGArray(userIds);
	if (!ids.count) {
		if (completion)
			completion(YES);
		return;
	}
	[self tg_ok:@{@"@type" : @"removeContacts", @"user_ids" : ids}
		completion:^(BOOL ok) {
			if (ok)
				[[NSNotificationCenter defaultCenter]
					postNotificationName:TGContactsDidChangeNotification
								  object:nil];
			if (completion)
				completion(ok);
		}];
}

- (void)sharePhoneNumberWithUser:(int64_t)userId completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"sharePhoneNumber", @"user_id" : @(userId)}
		completion:^(NSDictionary *result) {
			if (completion)
				completion(!TGResultIsError(result));
		}];
}

- (void)contactFlagsForUser:(int64_t)userId
				 completion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getUser", @"user_id" : @(userId)}
		completion:^(NSDictionary *u) {
			if (!completion)
				return;
			if (![u[@"@type"] isEqualToString:@"user"]) {
				completion(nil);
				return;
			}
			completion(@{
				@"isContact" : @([u[@"is_contact"] boolValue]),
				@"isMutualContact" : @([u[@"is_mutual_contact"] boolValue]),
				@"isCloseFriend" : @([u[@"is_close_friend"] boolValue]),
				@"isPremium" : @([u[@"is_premium"] boolValue]),
				@"isSupport" : @([u[@"is_support"] boolValue]),
				@"isBot" : @([u[@"type"][@"@type"] isEqualToString:@"userTypeBot"]),
				@"restrictionReason" : TGString(TGDict(u[@"restriction_info"])[@"restriction_reason"]),
			});
		}];
}

#pragma mark - address book

- (void)syncImportedContacts:(NSArray *)contacts
				  completion:(void (^)(NSArray *))completion {
	[self tg_import:@"changeImportedContacts" contacts:contacts completion:completion];
}

- (void)importContacts:(NSArray *)contacts completion:(void (^)(NSArray *))completion {
	[self tg_import:@"importContacts" contacts:contacts completion:completion];
}

- (void)importedContactCountWithCompletion:(void (^)(NSInteger))completion {
	[self request:@{@"@type" : @"getImportedContactCount"}
		completion:^(NSDictionary *result) {
			if (!completion)
				return;
			completion(TGResultIsError(result) ? 0 : [result[@"count"] integerValue]);
		}];
}

- (void)clearImportedContactsWithCompletion:(void (^)(BOOL))completion {
	[self tg_ok:@{@"@type" : @"clearImportedContacts"} completion:completion];
}

#pragma mark - finding people

- (void)userForToken:(NSString *)token completion:(void (^)(NSDictionary *))completion {
	if (!token.length) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{@"@type" : @"searchUserByToken", @"token" : token}
		completion:^(NSDictionary *u) {
			if (completion)
				completion(TGFlatUser(u));
		}];
}

- (void)userForUsername:(NSString *)username completion:(void (^)(NSDictionary *))completion {
	[self userIdForUsername:username completion:^(int64_t userId, BOOL failed) {
		if (failed || !userId) {
			if (completion)
				completion(nil);
			return;
		}
		[self request:@{@"@type" : @"getUser", @"user_id" : @(userId)}
			completion:^(NSDictionary *u) {
				if (completion)
					completion(TGFlatUser(u));
			}];
	}];
}

- (void)userForPhoneNumber:(NSString *)phoneNumber
				 onlyLocal:(BOOL)onlyLocal
				completion:(void (^)(NSDictionary *))completion {
	if (!phoneNumber.length) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{@"@type" : @"searchUserByPhoneNumber",
		@"phone_number" : phoneNumber,
		@"only_local" : @(onlyLocal)}
		completion:^(NSDictionary *u) {
			if (completion)
				completion(TGResultIsError(u) ? nil : TGFlatUser(u));
		}];
}

- (void)userIdForUsername:(NSString *)username
			   completion:(void (^)(int64_t, BOOL))completion {
	NSString *name = username;
	while ([name hasPrefix:@"@"])
		name = [name substringFromIndex:1];
	if (!name.length) {
		if (completion)
			completion(0, NO);
		return;
	}
	[self request:@{@"@type" : @"searchPublicChat", @"username" : name}
		completion:^(NSDictionary *chat) {
			if (!completion)
				return;
			if (TGResultIsError(chat)) {
				completion(0, YES);
				return;
			}
			NSDictionary *type = TGDict(chat[@"type"]);
			if (![type[@"@type"] isEqualToString:@"chatTypePrivate"]) {
				completion(0, NO);
				return;
			}
			completion(TGInt64(type[@"user_id"]), NO);
		}];
}

- (void)businessBotEligibilityForUserId:(int64_t)userId
							  completion:(void (^)(BOOL isBot, BOOL canConnectToBusiness))completion {
	if (!userId) {
		if (completion)
			completion(NO, NO);
		return;
	}
	[self request:@{@"@type" : @"getUser", @"user_id" : @(userId)}
		completion:^(NSDictionary *u) {
			if (!completion)
				return;
			if (TGResultIsError(u)) {
				completion(NO, NO);
				return;
			}
			NSDictionary *type = TGDict(u[@"type"]);
			BOOL isBot = [type[@"@type"] isEqualToString:@"userTypeBot"];
			BOOL canConnect = isBot && [type[@"can_connect_to_business"] boolValue];
			completion(isBot, canConnect);
		}];
}

- (void)myContactLinkWithCompletion:(void (^)(NSString *, NSInteger))completion {
	[self request:@{@"@type" : @"getUserLink"} completion:^(NSDictionary *link) {
		if (!completion)
			return;
		if (TGResultIsError(link)) {
			completion(nil, 0);
			return;
		}
		NSString *url = TGString(link[@"url"]);
		completion(url.length ? url : nil, [link[@"expires_in"] integerValue]);
	}];
}

#pragma mark - close friends

- (void)contactCloseFriendsWithCompletion:(void (^)(NSArray *, BOOL))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getCloseFriends"} completion:^(NSDictionary *result) {
		if (TGResultIsError(result)) {
			if (completion)
				completion(@[], YES);
			return;
		}
		[weakSelf tg_fetchUsers:result[@"user_ids"] completion:^(NSArray *users) {
			if (completion)
				completion(users ?: @[], NO);
		}];
	}];
}

- (void)setCloseFriends:(NSArray *)userIds completion:(void (^)(BOOL))completion {
	[self tg_ok:@{
		@"@type" : @"setCloseFriends",
		@"user_ids" : TGArray(userIds) ?: @[],
	}
		completion:completion];
}

- (void)setUser:(int64_t)userId closeFriend:(BOOL)closeFriend
	 completion:(void (^)(BOOL))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getCloseFriends"} completion:^(NSDictionary *result) {
		if (TGResultIsError(result)) {
			if (completion)
				completion(NO);
			return;
		}
		NSMutableArray *ids = [NSMutableArray array];
		for (id uid in TGArray(result[@"user_ids"]) ?: @[]) {
			if ([uid isKindOfClass:NSNumber.class] && [uid longLongValue] != userId)
				[ids addObject:uid];
		}
		if (closeFriend)
			[ids addObject:@(userId)];
		[weakSelf setCloseFriends:ids completion:completion];
	}];
}

#pragma mark - own usernames

- (void)myUsernamesWithCompletion:(void (^)(NSDictionary *))completion {
	[self request:@{@"@type" : @"getMe"} completion:^(NSDictionary *u) {
		if (!completion)
			return;
		if (![u[@"@type"] isEqualToString:@"user"]) {
			completion(nil);
			return;
		}
		NSDictionary *names = TGDict(u[@"usernames"]);
		completion(@{
			@"active" : TGArray(names[@"active_usernames"]) ?: @[],
			@"disabled" : TGArray(names[@"disabled_usernames"]) ?: @[],
			@"editable" : TGString(names[@"editable_username"]),
		});
	}];
}

- (void)checkUsernameAvailable:(NSString *)username
					completion:(void (^)(NSString *))completion {
	if (!username.length) {
		if (completion)
			completion(@"invalid");
		return;
	}
	[self request:@{
		@"@type" : @"checkChatUsername",
		@"chat_id" : @([self savedMessagesChatId]),
		@"username" : username,
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		NSString *type = TGString(result[@"@type"]);
		if ([type isEqualToString:@"checkChatUsernameResultOk"])
			completion(@"ok");
		else if ([type isEqualToString:@"checkChatUsernameResultUsernameInvalid"])
			completion(@"invalid");
		else if ([type isEqualToString:@"checkChatUsernameResultUsernameOccupied"])
			completion(@"occupied");
		else if ([type isEqualToString:@"checkChatUsernameResultUsernamePurchasable"])
			completion(@"purchasable");
		else if ([type isEqualToString:@"checkChatUsernameResultPublicChatsTooMany"])
			completion(@"too_many");
		else if ([type isEqualToString:@"checkChatUsernameResultPublicGroupsUnavailable"])
			completion(@"unavailable");
		else
			completion(@"error");
	}];
}

#pragma mark - profile photos

- (void)profilePhotosForUser:(int64_t)userId
					  offset:(NSInteger)offset
					   limit:(NSInteger)limit
				  completion:(void (^)(NSArray *, NSInteger))completion {
	[self request:@{
		@"@type" : @"getUserProfilePhotos",
		@"user_id" : @(userId),
		@"offset" : @(offset > 0 ? offset : 0),
		@"limit" : @(limit > 0 ? limit : 20),
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		if (TGResultIsError(result)) {
			completion(@[], 0);
			return;
		}
		NSMutableArray *photos = [NSMutableArray array];
		for (id entry in TGArray(result[@"photos"]) ?: @[]) {
			NSDictionary *photo = TGDict(entry);
			NSArray *sizes = TGArray(photo[@"sizes"]);
			if (!sizes.count)
				continue;
			NSNumber *small = TGFileId(TGDict(sizes[0])[@"photo"]);
			NSNumber *big = TGFileId(TGDict(sizes.lastObject)[@"photo"]);
			if (!big)
				continue;
			[photos addObject:@{
				@"photoId" : @(TGInt64(photo[@"id"])),
				@"date" : photo[@"added_date"] ?: @(0),
				@"fileId" : big,
				@"smallFileId" : small ?: big,
			}];
		}
		completion(photos, [result[@"total_count"] integerValue]);
	}];
}

- (void)setPersonalPhotoAtPath:(NSString *)path
					   forUser:(int64_t)userId
					   suggest:(BOOL)suggest
					completion:(void (^)(BOOL))completion {
	if (!path.length) {
		if (completion)
			completion(NO);
		return;
	}
	[self tg_ok:@{
		@"@type" : suggest ? @"suggestUserProfilePhoto" : @"setUserPersonalProfilePhoto",
		@"user_id" : @(userId),
		@"photo" : [self tg_inputPhotoAtPath:path],
	}
		completion:completion];
}

- (void)removePersonalPhotoForUser:(int64_t)userId completion:(void (^)(BOOL))completion {
	[self tg_ok:@{
		@"@type" : @"setUserPersonalProfilePhoto",
		@"user_id" : @(userId),
		@"photo" : [NSNull null],
	}
		completion:completion];
}

#pragma mark - birthdays

- (void)setMyBirthdateDay:(NSInteger)day
					month:(NSInteger)month
					 year:(NSInteger)year
			   completion:(void (^)(BOOL))completion {
	NSDictionary *request = day > 0 && month > 0
		? @{@"@type" : @"setBirthdate",
			  @"birthdate" : @{@"@type" : @"birthdate",
				  @"day" : @(day),
				  @"month" : @(month),
				  @"year" : @(year)}}
		: @{@"@type" : @"setBirthdate", @"birthdate" : [NSNull null]};
	[self tg_ok:request completion:completion];
}

- (void)suggestBirthdateToUser:(int64_t)userId
						   day:(NSInteger)day
						 month:(NSInteger)month
						  year:(NSInteger)year
					completion:(void (^)(BOOL))completion {
	if (day < 1 || month < 1) {
		if (completion)
			completion(NO);
		return;
	}
	[self tg_ok:@{
		@"@type" : @"suggestUserBirthdate",
		@"user_id" : @(userId),
		@"birthdate" : @{@"@type" : @"birthdate",
			@"day" : @(day),
			@"month" : @(month),
			@"year" : @(year)},
	}
		completion:completion];
}

- (void)birthdateForUser:(int64_t)userId
			  completion:(void (^)(NSDictionary *))completion {
	[self tg_userFull:userId completion:^(NSDictionary *full) {
		if (completion)
			completion(TGBirthdateInfo(full[@"birthdate"]));
	}];
}

- (void)hideContactCloseBirthdays {
	[self send:@{@"@type" : @"hideContactCloseBirthdays"}];
	self.closeBirthdayUsers = @[];
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGCloseBirthdaysDidChangeNotification
					  object:nil];
}

- (void)handleUpdateContactCloseBirthdays:(NSDictionary *)update {
	NSArray *raw = TGArray(update[@"close_birthday_users"]);
	NSMutableArray *users = [NSMutableArray arrayWithCapacity:raw.count];
	for (id entry in raw) {
		NSDictionary *dict = TGDict(entry);
		int64_t userId = [dict[@"user_id"] longLongValue];
		if (!userId)
			continue;
		NSDictionary *birthdate = TGBirthdateInfo(dict[@"birthdate"]);
		[users addObject:birthdate
			? @{@"userId" : @(userId), @"birthdate" : birthdate}
			: @{@"userId" : @(userId)}];
	}
	self.closeBirthdayUsers = users;
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGCloseBirthdaysDidChangeNotification
					  object:nil];
}

#pragma mark - profile extras

- (void)noteForUser:(int64_t)userId completion:(void (^)(NSString *))completion {
	[self tg_userFull:userId completion:^(NSDictionary *full) {
		if (completion)
			completion(TGString(TGDict(full[@"note"])[@"text"]));
	}];
}

- (void)setNote:(NSString *)note forUser:(int64_t)userId
	 completion:(void (^)(BOOL))completion {
	[self tg_ok:@{
		@"@type" : @"setUserNote",
		@"user_id" : @(userId),
		@"note" : @{@"@type" : @"formattedText",
			@"text" : note ?: @"",
			@"entities" : @[]},
	}
		completion:completion];
}

- (void)groupsInCommonWithUser:(int64_t)userId
					completion:(void (^)(NSArray *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{
		@"@type" : @"getGroupsInCommon",
		@"user_id" : @(userId),
		@"offset_chat_id" : @(0),
		@"limit" : @(100),
	} completion:^(NSDictionary *result) {
		if (TGResultIsError(result)) {
			if (completion)
				completion(nil);
			return;
		}
		[weakSelf tg_fetchChats:result[@"chat_ids"] completion:completion];
	}];
}

- (void)suitablePersonalChatsWithCompletion:(void (^)(NSArray *, BOOL))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getSuitablePersonalChats"}
		completion:^(NSDictionary *result) {
			if (TGResultIsError(result)) {
				if (completion)
					completion(@[], YES);
				return;
			}
			[weakSelf tg_fetchChats:result[@"chat_ids"] completion:^(NSArray *chats) {
				if (completion)
					completion(chats ?: @[], NO);
			}];
		}];
}

- (void)personalChatForUser:(int64_t)userId completion:(void (^)(int64_t))completion {
	[self tg_userFull:userId completion:^(NSDictionary *full) {
		if (completion)
			completion([full[@"personal_chat_id"] longLongValue]);
	}];
}

- (void)setMainProfileTab:(NSString *)tab completion:(void (^)(BOOL))completion {
	NSArray *known = @[ @"posts", @"gifts", @"media", @"files",
		@"links", @"music", @"voice", @"gifs" ];
	NSString *name = [TGString(tab) lowercaseString];
	if (![known containsObject:name]) {
		if (completion)
			completion(NO);
		return;
	}
	NSString *type = [NSString stringWithFormat:@"profileTab%@",
		TGStringWithFirstCharacterUppercased(name)];
	[self tg_ok:@{
		@"@type" : @"setMainProfileTab",
		@"main_profile_tab" : @{@"@type" : type},
	}
		completion:completion];
}

- (void)mainProfileTabForUser:(int64_t)userId completion:(void (^)(NSString *))completion {
	[self tg_userFull:userId completion:^(NSDictionary *full) {
		if (completion)
			completion(TGProfileTabName(full[@"main_profile_tab"]));
	}];
}

- (void)giftEligibilityForUser:(int64_t)userId
					 completion:(void (^)(BOOL acceptsGifts, BOOL acceptsPremiumGift))completion {
	[self tg_userFull:userId completion:^(NSDictionary *full) {
		if (!completion)
			return;
		NSDictionary *settings = TGDict(full[@"gift_settings"]);
		NSDictionary *accepted = TGDict(settings[@"accepted_gift_types"]);
		if (!accepted) {
			completion(YES, YES);
			return;
		}
		BOOL acceptsGifts = [accepted[@"unlimited_gifts"] boolValue]
			|| [accepted[@"limited_gifts"] boolValue]
			|| [accepted[@"upgraded_gifts"] boolValue];
		BOOL acceptsPremiumGift = [accepted[@"premium_subscription"] boolValue];
		completion(acceptsGifts, acceptsPremiumGift);
	}];
}

#pragma mark - support

- (void)supportContactWithCompletion:(void (^)(NSDictionary *))completion {
	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getSupportUser"} completion:^(NSDictionary *u) {
		if (![u[@"@type"] isEqualToString:@"user"]) {
			if (completion)
				completion(nil);
			return;
		}
		int64_t userId = [u[@"id"] longLongValue];
		[weakSelf request:@{@"@type" : @"getSupportName"}
			   completion:^(NSDictionary *text) {
				   NSString *name = TGResultIsError(text) ? @"" : TGString(text[@"text"]);
				   [weakSelf request:@{
					   @"@type" : @"createPrivateChat",
					   @"user_id" : @(userId),
					   @"force" : @YES,
				   } completion:^(NSDictionary *chat) {
					   if (!completion)
						   return;
					   completion(@{
						   @"userId" : @(userId),
						   @"chatId" : @([chat[@"id"] longLongValue]),
						   @"name" : name,
					   });
				   }];
			   }];
	}];
}

- (void)isUserBlocked:(int64_t)userId completion:(void (^)(BOOL))completion {
	[self request:@{@"@type" : @"getUserFullInfo", @"user_id" : @(userId)}
		completion:^(NSDictionary *full) {
			if (completion)
				completion([TGDict(full[@"block_list"])[@"@type"] isEqualToString:@"blockListMain"]);
		}];
}

#pragma mark - moved from TGClient.m core

- (NSDictionary *)contactRowFromUser:(NSDictionary *)u {
	NSDictionary *status = TGUserStatusInfo(u[@"status"]);
	NSDictionary *photo = TGDict(TGDict(u[@"profile_photo"])[@"small"]);
	return @{
		@"id" : u[@"id"] ?: @(0),
		@"first_name" : u[@"first_name"] ?: @"",
		@"last_name" : u[@"last_name"] ?: @"",
		@"phone" : u[@"phone_number"] ?: @"",
		@"username" : TGActiveUsername(u) ?: @"",
		@"photoFileId" : photo[@"id"] ?: [NSNull null],
		@"photoUniqueId" : TGDict(photo[@"remote"])[@"unique_id"] ?: [NSNull null],
		@"isOnline" : status[@"isOnline"],
		@"statusText" : status[@"text"],
		@"statusRank" : status[@"rank"],
	};
}

- (void)deliverContacts:(NSArray *)users {
	if (self.contactsFetchStartedAt > 0) {
		NSLog(@"PERF contacts %lu rows to %lu callers in %.0f ms",
			(unsigned long)users.count, (unsigned long)self.contactWaiters.count,
			([NSDate timeIntervalSinceReferenceDate] - self.contactsFetchStartedAt) * 1000.0);
		self.contactsFetchStartedAt = 0;
	}
	self.contactsFetchInFlight = NO;
	self.contactsFetchIssuedAt = 0;
	NSArray *waiting = [self.contactWaiters copy];
	[self.contactWaiters removeAllObjects];
	for (void (^waiter)(NSArray *) in waiting)
		waiter(users);
}

- (void)contactsWithCompletion:(void (^)(NSArray *))completion {
	if (completion)
		[self.contactWaiters addObject:[completion copy]];
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	if (self.contactsFetchInFlight && now - self.contactsFetchIssuedAt < kContactsFetchRetryAfter)
		return;
	self.contactsFetchInFlight = YES;
	self.contactsFetchIssuedAt = now;
	self.contactsFetchStartedAt = TGPerfLogging()
		? [NSDate timeIntervalSinceReferenceDate]
		: 0;

	__weak typeof(self) weakSelf = self;
	[self request:@{@"@type" : @"getContacts"} completion:^(NSDictionary *result) {
		TGClient *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSArray *ids = result[@"user_ids"];
		if (![ids isKindOfClass:NSArray.class]) {
			[strongSelf deliverContacts:nil];
			return;
		}
		if (!ids.count) {
			[strongSelf deliverContacts:@[]];
			return;
		}

		NSTimeInterval startedAt = TGPerfLogging()
			? [NSDate timeIntervalSinceReferenceDate]
			: 0;
		NSMutableArray *users = [NSMutableArray arrayWithCapacity:ids.count];
		NSMutableArray *missing = [NSMutableArray array];
		for (NSNumber *uid in ids) {
			NSDictionary *known = strongSelf.userRecordsById[uid];
			if (known)
				[users addObject:[strongSelf contactRowFromUser:known]];
			else
				[missing addObject:uid];
		}
		if (startedAt > 0)
			NSLog(@"PERF contacts %lu cached, %lu to fetch, built in %.0f ms",
				(unsigned long)users.count, (unsigned long)missing.count,
				([NSDate timeIntervalSinceReferenceDate] - startedAt) * 1000.0);

		if (!missing.count) {
			[strongSelf deliverContacts:users];
			return;
		}

		__block NSUInteger left = missing.count;
		for (NSNumber *uid in missing) {
			[strongSelf request:@{@"@type" : @"getUser", @"user_id" : uid}
				completion:^(NSDictionary *u) {
					TGClient *innerSelf = weakSelf;
					if (innerSelf && [u[@"@type"] isEqualToString:@"user"]) {
						if (u[@"id"]) {
							[innerSelf capUserRegistriesIfNeeded];
							innerSelf.userRecordsById[u[@"id"]] = u;
						}
						[innerSelf cacheProfilePhoto:u];
						[users addObject:[innerSelf contactRowFromUser:u]];
					}
					if (--left == 0 && innerSelf)
						[innerSelf deliverContacts:users];
				}];
		}
	}];
}

- (void)addContactWithPhone:(NSString *)phone
				  firstName:(NSString *)firstName
				   lastName:(NSString *)lastName
				 completion:(void (^)(BOOL))completion {
	[self request:@{
		@"@type" : @"importContacts",
		@"contacts" : @[ @{
			@"@type" : @"importedContact",
			@"phone_number" : phone ?: @"",
			@"first_name" : firstName ?: @"",
			@"last_name" : lastName ?: @"",
		} ],
	} completion:^(NSDictionary *result) {
		BOOL ok = [result[@"@type"] isEqualToString:@"importedContacts"];
		if (completion)
			completion(ok);
	}];
}

- (void)privateChatWithUser:(int64_t)userId completion:(void (^)(int64_t))completion {
	[self request:@{
		@"@type" : @"createPrivateChat",
		@"user_id" : @(userId),
		@"force" : @NO,
	} completion:^(NSDictionary *chat) {
		if (completion)
			completion([chat[@"id"] longLongValue]);
	}];
}

- (void)canSendMessageToUser:(int64_t)userId
				  completion:(void (^)(BOOL canSend, BOOL isPaid, NSInteger starCount, NSString *blockReason))completion {
	if (userId == 0) {
		if (completion)
			completion(NO, NO, 0, @"deleted");
		return;
	}
	[self request:@{
		@"@type" : @"canSendMessageToUser",
		@"user_id" : @(userId),
		@"only_local" : @NO,
	} completion:^(NSDictionary *result) {
		if (!completion)
			return;
		NSString *type = result[@"@type"];
		if ([type isEqualToString:@"canSendMessageToUserResultOk"]) {
			completion(YES, NO, 0, nil);
		} else if ([type isEqualToString:@"canSendMessageToUserResultUserHasPaidMessages"]) {
			completion(YES, YES, [result[@"outgoing_paid_message_star_count"] integerValue], nil);
		} else if ([type isEqualToString:@"canSendMessageToUserResultUserIsDeleted"]) {
			completion(NO, NO, 0, @"deleted");
		} else if ([type isEqualToString:@"canSendMessageToUserResultUserRestrictsNewChats"]) {
			completion(NO, NO, 0, @"restricted");
		} else {
			completion(YES, NO, 0, nil);
		}
	}];
}

- (void)userForPhone:(NSString *)phone completion:(void (^)(NSDictionary *))completion {
	if (!phone.length) {
		if (completion)
			completion(nil);
		return;
	}
	[self request:@{
		@"@type" : @"searchUserByPhoneNumber",
		@"phone_number" : phone,
	} completion:^(NSDictionary *u) {
		if (![u[@"@type"] isEqualToString:@"user"]) {
			if (completion)
				completion(nil);
			return;
		}
		if (completion)
			completion(@{
				@"id" : u[@"id"] ?: @(0),
				@"first_name" : u[@"first_name"] ?: @"",
				@"last_name" : u[@"last_name"] ?: @"",
				@"phone" : u[@"phone_number"] ?: @"",
				@"username" : TGActiveUsername(u) ?: @"",
			});
	}];
}

@end

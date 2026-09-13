#import "TGAccountManager.h"
#import "TGClient+Private.h"
#import "TGClient+Account.h"
#import "TGDiskCache.h"
#import "TGDatabaseEncryptionKey.h"
#import "TGLocalization.h"

NSString *const TGAccountsDidChangeNotification = @"TGAccountsDidChange";
NSString *const TGAccountWillSwitchNotification = @"TGAccountWillSwitch";
NSString *const TGAccountDidSwitchNotification = @"TGAccountDidSwitch";
NSString *const TGAccountSignOutFailedNotification = @"TGAccountSignOutFailed";

const NSInteger kAccountSlotLimit = 3;

static NSString *const TGAccountRecordsKey = @"TGAccountRecords";
static NSString *const TGAccountCurrentSlotKey = @"TGAccountCurrentSlot";

@interface TGAccountManager ()
@property (nonatomic, strong) NSMutableArray *records;
@property (nonatomic, assign) NSInteger currentSlot;
@property (nonatomic, assign) BOOL switching;
@property (nonatomic, assign) BOOL addingAccount;
@property (nonatomic, assign) NSInteger slotBeforeAdding;
@property (nonatomic, assign) NSInteger slotAwaitingSignOut;
@property (nonatomic, assign) NSInteger slotToResumeAfterSignOut;
@property (nonatomic, copy) NSString *scopeToDiscardAfterSwitch;
@end

@implementation TGAccountManager

+ (instancetype)shared {
	static TGAccountManager *s = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		s = [[TGAccountManager alloc] init];
		[s load];
	});
	return s;
}

+ (NSString *)scopeForSlot:(NSInteger)slot {
	return slot <= 0 ? nil : [NSString stringWithFormat:@"%ld", (long)slot];
}

+ (NSString *)defaultsKey:(NSString *)base {
	NSInteger slot = [TGAccountManager shared].currentSlot;
	if (slot <= 0)
		return base;
	return [NSString stringWithFormat:@"%@.%ld", base, (long)slot];
}

#pragma mark - storage

- (void)load {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	self.slotBeforeAdding = -1;
	self.slotAwaitingSignOut = -1;
	self.slotToResumeAfterSignOut = -1;
	self.currentSlot = [defaults integerForKey:TGAccountCurrentSlotKey];
	if (self.currentSlot < 0 || self.currentSlot >= kAccountSlotLimit)
		self.currentSlot = 0;

	self.records = [NSMutableArray array];
	id stored = [defaults arrayForKey:TGAccountRecordsKey];
	if ([stored isKindOfClass:[NSArray class]]) {
		for (id entry in (NSArray *)stored) {
			if (![entry isKindOfClass:[NSDictionary class]])
				continue;
			NSInteger slot = [entry[@"slot"] integerValue];
			if (slot < 0 || slot >= kAccountSlotLimit)
				continue;
			if ([self indexOfSlot:slot] != NSNotFound)
				continue;
			[self.records addObject:[entry mutableCopy]];
		}
	}
	[self.records sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
		return [a[@"slot"] compare:b[@"slot"]];
	}];
}

- (void)saveWithoutFlush {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:[self.records copy] forKey:TGAccountRecordsKey];
	[defaults setInteger:self.currentSlot forKey:TGAccountCurrentSlotKey];
}

- (void)save {
	[self saveWithoutFlush];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSUInteger)indexOfSlot:(NSInteger)slot {
	for (NSInteger i = 0; i < self.records.count; i++)
		if ([self.records[i][@"slot"] integerValue] == slot)
			return i;
	return NSNotFound;
}

- (NSMutableDictionary *)recordForSlot:(NSInteger)slot create:(BOOL)create {
	NSInteger index = [self indexOfSlot:slot];
	if (index != NSNotFound)
		return self.records[index];
	if (!create)
		return nil;
	NSMutableDictionary *record = [NSMutableDictionary dictionaryWithObject:@(slot) forKey:@"slot"];
	[self.records addObject:record];
	[self.records sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
		return [a[@"slot"] compare:b[@"slot"]];
	}];
	return record;
}

#pragma mark - reading

- (NSArray *)accounts {
	NSMutableArray *out = [NSMutableArray arrayWithCapacity:self.records.count];
	for (NSDictionary *record in self.records)
		[out addObject:[record copy]];
	return out;
}

- (NSDictionary *)accountForSlot:(NSInteger)slot {
	NSMutableDictionary *record = [self recordForSlot:slot create:NO];
	return record ? [record copy] : nil;
}

- (NSDictionary *)currentAccount {
	return [self accountForSlot:self.currentSlot];
}

- (NSInteger)firstFreeSlot {
	for (NSInteger slot = 0; slot < kAccountSlotLimit; slot++)
		if ([self indexOfSlot:slot] == NSNotFound)
			return slot;
	return -1;
}

- (BOOL)canAddAccount {
	return [self firstFreeSlot] >= 0;
}

#pragma mark - launch

- (void)prepareForLaunch {
	[TGDiskCache setAccountScope:[TGAccountManager scopeForSlot:self.currentSlot]];
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"tgWasSignedIn"])
		[self recordForSlot:self.currentSlot create:YES];
	[self save];
	NSLog(@"TGAccountManager: launching on account slot %ld of %lu known",
		(long)self.currentSlot, (unsigned long)self.records.count);
}

#pragma mark - bookkeeping

- (NSInteger)unreadInList:(NSArray *)chats {
	NSInteger total = 0;
	for (id entry in chats ?: @[]) {
		if (![entry isKindOfClass:[NSDictionary class]])
			continue;
		if ([entry[@"isMuted"] boolValue])
			continue;
		total += [entry[@"unread"] integerValue];
	}
	return total;
}

- (void)rememberCurrentAccount {
	NSDictionary *me = [TGClient shared].me;
	if (![me isKindOfClass:[NSDictionary class]] || ![me[@"id"] longLongValue])
		return;

	NSMutableDictionary *record = [self recordForSlot:self.currentSlot create:YES];
	record[@"userId"] = @([me[@"id"] longLongValue]);

	NSMutableString *name = [NSMutableString string];
	if ([me[@"first_name"] isKindOfClass:[NSString class]])
		[name appendString:me[@"first_name"]];
	if ([me[@"last_name"] isKindOfClass:[NSString class]] && [me[@"last_name"] length]) {
		if (name.length)
			[name appendString:@" "];
		[name appendString:me[@"last_name"]];
	}
	if (name.length)
		record[@"name"] = [name copy];

	NSString *phone = [me[@"phone"] isKindOfClass:[NSString class]]
		? me[@"phone"]
		: me[@"phone_number"];
	if ([phone isKindOfClass:[NSString class]] && phone.length)
		record[@"phone"] = phone;
	if ([me[@"username"] isKindOfClass:[NSString class]] && [me[@"username"] length])
		record[@"username"] = me[@"username"];

	NSInteger unread = [self unreadInList:[TGClient shared].chats] + [self unreadInList:[TGClient shared].archivedChats];
	if (unread > 0 || [TGClient shared].authState == TGAuthStateReady)
		record[@"unread"] = @(MAX((NSInteger)0, unread));

	if (self.addingAccount && !self.switching) {
		self.addingAccount = NO;
		self.slotBeforeAdding = -1;
	}

	[self save];
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGAccountsDidChangeNotification
					  object:nil];
}

- (void)noteUnreadCount:(NSInteger)unread {
	NSMutableDictionary *record = [self recordForSlot:self.currentSlot create:NO];
	if (!record)
		return;
	if ([record[@"unread"] integerValue] == unread)
		return;
	record[@"unread"] = @(unread);
	[self saveWithoutFlush];
}

#pragma mark - switching

- (void)switchToSlot:(NSInteger)slot {
	if (slot < 0 || slot >= kAccountSlotLimit)
		return;
	if (self.switching)
		return;
	if (slot == self.currentSlot && !self.addingAccount)
		return;

	self.switching = YES;
	[self rememberCurrentAccount];
	[[TGClient shared] saveCachedChats];

	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGAccountWillSwitchNotification
					  object:nil];

	NSLog(@"TGAccountManager: switching from slot %ld to slot %ld",
		(long)self.currentSlot, (long)slot);

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] suspendForBackgroundWithCompletion:^{
		TGAccountManager *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[[TGClient shared] resetForAccountSwitch];
		NSString *discard = strongSelf.scopeToDiscardAfterSwitch;
		strongSelf.scopeToDiscardAfterSwitch = nil;
		if (discard.length) {
			[TGDiskCache discardDatabaseForScope:discard];
			[TGDatabaseEncryptionKey deleteKeyForScope:discard];
		}
		strongSelf.currentSlot = slot;
		[TGDiskCache setAccountScope:[TGAccountManager scopeForSlot:slot]];
		[strongSelf save];
		strongSelf.switching = NO;
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGAccountDidSwitchNotification
						  object:nil];
		[[NSNotificationCenter defaultCenter]
			postNotificationName:TGAccountsDidChangeNotification
						  object:nil];
		[[TGClient shared] resumeFromBackground];
		if (strongSelf.slotAwaitingSignOut == slot) {
			NSInteger resumeSlot = strongSelf.slotToResumeAfterSignOut;
			[[TGClient shared] logOutWithCompletion:^(BOOL ok) {
				TGAccountManager *innerSelf = weakSelf;
				if (!innerSelf || ok)
					return;
				innerSelf.slotAwaitingSignOut = -1;
				innerSelf.slotToResumeAfterSignOut = -1;
				[[NSNotificationCenter defaultCenter]
					postNotificationName:TGAccountSignOutFailedNotification
								  object:nil];
				if (resumeSlot >= 0 && resumeSlot != slot)
					[innerSelf switchToSlot:resumeSlot];
			}];
		}
	}];
}

- (void)switchToSlotAbandoningAdd:(NSInteger)slot {
	if (self.addingAccount && !self.switching && slot != self.currentSlot) {
		self.scopeToDiscardAfterSwitch =
			[TGAccountManager scopeForSlot:self.currentSlot];
		self.addingAccount = NO;
		self.slotBeforeAdding = -1;
	}
	[self switchToSlot:slot];
}

- (void)beginAddingAccount {
	NSInteger slot = [self firstFreeSlot];
	if (slot < 0 || self.switching)
		return;
	self.slotBeforeAdding = self.currentSlot;
	self.addingAccount = YES;
	[self switchToSlot:slot];
}

- (void)cancelAddingAccount {
	if (!self.addingAccount)
		return;
	NSInteger back = self.slotBeforeAdding;
	NSInteger abandoned = self.currentSlot;
	self.addingAccount = NO;
	self.slotBeforeAdding = -1;
	if (back < 0 || back == abandoned || [self indexOfSlot:back] == NSNotFound)
		return;
	self.scopeToDiscardAfterSwitch = [TGAccountManager scopeForSlot:abandoned];
	[self switchToSlot:back];
}

- (void)forgetRecordOfSlot:(NSInteger)slot {
	NSInteger index = [self indexOfSlot:slot];
	if (index == NSNotFound)
		return;
	[self.records removeObjectAtIndex:index];
	[self save];
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGAccountsDidChangeNotification
					  object:nil];
}

- (void)signOutOfSlot:(NSInteger)slot {
	if (slot == self.currentSlot)
		return;
	if (self.switching || self.addingAccount)
		return;
	if ([self indexOfSlot:slot] == NSNotFound)
		return;
	self.slotAwaitingSignOut = slot;
	self.slotToResumeAfterSignOut = self.currentSlot;
	NSLog(@"TGAccountManager: signing out slot %ld, returning to slot %ld",
		(long)slot, (long)self.currentSlot);
	[self switchToSlot:slot];
}

- (BOOL)handleLogOutOfCurrentAccount {
	if (self.switching || self.addingAccount)
		return NO;

	NSInteger gone = self.currentSlot;
	NSInteger preferred = self.slotToResumeAfterSignOut;
	self.slotAwaitingSignOut = -1;
	self.slotToResumeAfterSignOut = -1;

	[TGDatabaseEncryptionKey deleteKeyForScope:[TGAccountManager scopeForSlot:gone]];

	NSInteger next = -1;
	if (preferred >= 0 && preferred != gone &&
		[self indexOfSlot:preferred] != NSNotFound)
		next = preferred;

	for (NSDictionary *record in self.records) {
		if (next >= 0)
			break;
		NSInteger slot = [record[@"slot"] integerValue];
		if (slot != gone) {
			next = slot;
			break;
		}
	}
	if (next < 0) {
		[TGDiskCache discardDatabaseForScope:[TGAccountManager scopeForSlot:gone]];
		[self forgetRecordOfSlot:gone];
		return NO;
	}

	NSInteger index = [self indexOfSlot:gone];
	if (index != NSNotFound)
		[self.records removeObjectAtIndex:index];
	[self save];
	NSLog(@"TGAccountManager: slot %ld signed out, falling back to slot %ld",
		(long)gone, (long)next);
	self.scopeToDiscardAfterSwitch = [TGAccountManager scopeForSlot:gone];
	[self switchToSlot:next];
	return YES;
}

@end

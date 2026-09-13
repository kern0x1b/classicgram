#import "tg_account_manager_tests.h"
#import "../support/tg_account_manager_testing.h"
#import "../support/tg_client_test_double.h"
#import "TGDiskCache.h"
#import <Foundation/Foundation.h>

static TGAccountManager *TGTestFreshManager(void) {
	TGAccountManager *manager = [[TGAccountManager alloc] init];
	manager.records = [NSMutableArray array];
	manager.currentSlot = 0;
	manager.switching = NO;
	manager.addingAccount = NO;
	manager.slotBeforeAdding = -1;
	manager.slotAwaitingSignOut = -1;
	manager.slotToResumeAfterSignOut = -1;
	manager.scopeToDiscardAfterSwitch = nil;
	return manager;
}

static TGClient *TGTestInstallFakeClient(void) {
	TGClient *client = [[TGClient alloc] init];
	[TGClient setSharedInstanceForTesting:client];
	return client;
}

static NSMutableDictionary *TGTestRecordForSlot(NSInteger slot) {
	return [NSMutableDictionary dictionaryWithObject:@(slot) forKey:@"slot"];
}

static id TGTestObserveNotifications(NSMutableArray *names, NSArray *watchedNames) {
	return [[NSNotificationCenter defaultCenter]
		addObserverForName:nil
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					if ([watchedNames containsObject:note.name])
						[names addObject:note.name];
				}];
}

TGTestOutcome TGAccountManagerTestFreshManagerHasNoAccountsAndSlotZeroIsFree(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();

	TGTestExpectEqualInteger(&outcome, manager.accounts.count, 0, "a fresh manager must have no accounts");
	TGTestExpectEqualInteger(&outcome, [manager firstFreeSlot], 0, "slot zero must be the first free slot");
	TGTestExpectTrue(&outcome, [manager canAddAccount], "a fresh manager must be able to add an account");
	TGTestExpectTrue(&outcome, [manager accountForSlot:0] == nil, "no record exists yet for slot zero");
	TGTestExpectTrue(&outcome, [manager currentAccount] == nil, "no record exists yet for the current slot");

	return outcome;
}

TGTestOutcome TGAccountManagerTestFirstFreeSlotSkipsOccupiedSlots(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	[manager.records addObject:TGTestRecordForSlot(0)];
	[manager.records addObject:TGTestRecordForSlot(1)];

	TGTestExpectEqualInteger(&outcome, [manager firstFreeSlot], 2,
			"the first free slot must skip every already-occupied slot");

	return outcome;
}

TGTestOutcome TGAccountManagerTestCanAddAccountFalseWhenAllSlotsOccupied(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	[manager.records addObject:TGTestRecordForSlot(0)];
	[manager.records addObject:TGTestRecordForSlot(1)];
	[manager.records addObject:TGTestRecordForSlot(2)];

	TGTestExpectEqualInteger(&outcome, [manager firstFreeSlot], -1,
			"there must be no free slot once the account limit is reached");
	TGTestExpectTrue(&outcome, ![manager canAddAccount],
			"canAddAccount must be false once every slot is occupied");

	return outcome;
}

TGTestOutcome TGAccountManagerTestAccountsReturnsDefensiveCopies(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	[manager.records addObject:TGTestRecordForSlot(0)];
	NSArray *snapshot = [manager accounts];
	[manager.records removeAllObjects];

	TGTestExpectEqualInteger(&outcome, snapshot.count, 1,
			"a previously taken accounts snapshot must not be affected by later mutation of the manager");
	TGTestExpectEqualInteger(&outcome, manager.accounts.count, 0,
			"the manager's own live accounts view must reflect the mutation");

	return outcome;
}

TGTestOutcome TGAccountManagerTestAccountForSlotReturnsNilForUnknownSlot(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	[manager.records addObject:TGTestRecordForSlot(0)];

	TGTestExpectTrue(&outcome, [manager accountForSlot:1] == nil,
			"a slot with no record must return nil");

	return outcome;
}

TGTestOutcome TGAccountManagerTestCurrentAccountReflectsCurrentSlot(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	NSMutableDictionary *record = TGTestRecordForSlot(1);
	record[@"name"] = @"Second Slot";
	[manager.records addObject:record];
	manager.currentSlot = 1;

	TGTestExpectTrue(&outcome, [[manager currentAccount][@"name"] isEqualToString:@"Second Slot"],
			"currentAccount must resolve to the record for the manager's current slot");

	return outcome;
}

TGTestOutcome TGAccountManagerTestNoteUnreadCountUpdatesExistingRecord(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	[manager.records addObject:TGTestRecordForSlot(0)];
	manager.currentSlot = 0;
	[manager noteUnreadCount:5];

	TGTestExpectEqualInteger(&outcome, [[manager accountForSlot:0][@"unread"] integerValue], 5,
			"noteUnreadCount must update the current slot's record");

	return outcome;
}

TGTestOutcome TGAccountManagerTestNoteUnreadCountNoOpWhenNoRecordForCurrentSlot(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	manager.currentSlot = 0;
	[manager noteUnreadCount:5];

	TGTestExpectTrue(&outcome, [manager accountForSlot:0] == nil,
			"noteUnreadCount must never create a record for a slot that has none");

	return outcome;
}

TGTestOutcome TGAccountManagerTestRememberCurrentAccountNoOpWhenClientHasNoMe(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	TGTestInstallFakeClient();

	[manager rememberCurrentAccount];

	TGTestExpectEqualInteger(&outcome, manager.accounts.count, 0,
			"with no signed-in user, rememberCurrentAccount must not create a record");

	[TGClient setSharedInstanceForTesting:nil];
	return outcome;
}

TGTestOutcome TGAccountManagerTestRememberCurrentAccountCreatesRecordFromClientMe(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	TGClient *client = TGTestInstallFakeClient();
	client.me = @{
		@"id" : @42,
		@"first_name" : @"Ann",
		@"last_name" : @"Lee",
		@"phone" : @"5550123",
		@"username" : @"annlee",
	};
	client.chats = @[];
	client.archivedChats = @[];
	client.authState = TGAuthStateReady;

	NSMutableArray *seen = [NSMutableArray array];
	id token = TGTestObserveNotifications(seen, @[ TGAccountsDidChangeNotification ]);

	[manager rememberCurrentAccount];

	NSDictionary *record = [manager accountForSlot:0];
	TGTestExpectEqualLongLong(&outcome, [record[@"userId"] longLongValue], 42,
			"the record must carry the signed-in user's id");
	TGTestExpectTrue(&outcome, [record[@"name"] isEqualToString:@"Ann Lee"],
			"the record's name must join first and last name");
	TGTestExpectTrue(&outcome, [record[@"phone"] isEqualToString:@"5550123"],
			"the record must carry the phone number");
	TGTestExpectTrue(&outcome, [record[@"username"] isEqualToString:@"annlee"],
			"the record must carry the username");
	TGTestExpectEqualInteger(&outcome, [record[@"unread"] integerValue], 0,
			"with no unread chats the unread count must be zero, not absent");
	TGTestExpectTrue(&outcome, [seen containsObject:TGAccountsDidChangeNotification],
			"remembering the current account must announce that the accounts changed");

	[[NSNotificationCenter defaultCenter] removeObserver:token];
	[TGClient setSharedInstanceForTesting:nil];
	return outcome;
}

TGTestOutcome TGAccountManagerTestRememberCurrentAccountSumsUnreadExcludingMutedChats(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	TGClient *client = TGTestInstallFakeClient();
	client.me = @{@"id" : @7};
	client.chats = @[
		@{@"unread" : @3, @"isMuted" : @NO},
		@{@"unread" : @2, @"isMuted" : @YES},
	];
	client.archivedChats = @[
		@{@"unread" : @1, @"isMuted" : @NO},
	];
	client.authState = TGAuthStateReady;

	[manager rememberCurrentAccount];

	TGTestExpectEqualInteger(&outcome, [[manager accountForSlot:0][@"unread"] integerValue], 4,
			"unread must sum unmuted chats and archived chats but skip muted ones");

	[TGClient setSharedInstanceForTesting:nil];
	return outcome;
}

TGTestOutcome TGAccountManagerTestRememberCurrentAccountClearsAddingAccountWhenNotSwitching(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	manager.addingAccount = YES;
	manager.switching = NO;
	manager.slotBeforeAdding = 0;
	TGClient *client = TGTestInstallFakeClient();
	client.me = @{@"id" : @7};

	[manager rememberCurrentAccount];

	TGTestExpectTrue(&outcome, !manager.addingAccount,
			"once the new account finishes signing in outside of a switch, addingAccount must clear");
	TGTestExpectEqualInteger(&outcome, manager.slotBeforeAdding, -1,
			"slotBeforeAdding must reset once the add-account flow finishes");

	[TGClient setSharedInstanceForTesting:nil];
	return outcome;
}

TGTestOutcome TGAccountManagerTestRememberCurrentAccountKeepsAddingAccountWhileSwitching(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	manager.addingAccount = YES;
	manager.switching = YES;
	TGClient *client = TGTestInstallFakeClient();
	client.me = @{@"id" : @7};

	[manager rememberCurrentAccount];

	TGTestExpectTrue(&outcome, manager.addingAccount,
			"while a switch is still in flight, rememberCurrentAccount must not clear addingAccount");

	[TGClient setSharedInstanceForTesting:nil];
	return outcome;
}

TGTestOutcome TGAccountManagerTestSwitchToSlotUpdatesCurrentSlotAndDrivesClientLifecycle(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	TGClient *client = TGTestInstallFakeClient();

	NSMutableArray *seen = [NSMutableArray array];
	id token = TGTestObserveNotifications(seen, @[
		TGAccountWillSwitchNotification, TGAccountDidSwitchNotification, TGAccountsDidChangeNotification
	]);

	[manager switchToSlot:1];

	TGTestExpectEqualInteger(&outcome, manager.currentSlot, 1, "switchToSlot must update the current slot");
	TGTestExpectTrue(&outcome, !manager.switching, "switching must be false once the switch completes");
	TGTestExpectEqualInteger(&outcome, client.tgTestSaveCachedChatsCallCount, 1,
			"switching accounts must flush the outgoing account's cached chats");
	TGTestExpectEqualInteger(&outcome, client.tgTestResetForAccountSwitchCallCount, 1,
			"switching accounts must reset the client state for the new account");
	TGTestExpectEqualInteger(&outcome, client.tgTestResumeFromBackgroundCallCount, 1,
			"switching accounts must resume the client once the new account is ready");
	TGTestExpectEqualInteger(&outcome, seen.count, 3,
			"a full switch must announce will-switch, did-switch and accounts-changed exactly once each");

	[[NSNotificationCenter defaultCenter] removeObserver:token];
	[TGClient setSharedInstanceForTesting:nil];
	return outcome;
}

TGTestOutcome TGAccountManagerTestSwitchToSlotNoOpForInvalidSlot(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	TGClient *client = TGTestInstallFakeClient();

	[manager switchToSlot:-1];
	[manager switchToSlot:99];

	TGTestExpectEqualInteger(&outcome, manager.currentSlot, 0,
			"an out-of-range slot must never change the current slot");
	TGTestExpectEqualInteger(&outcome, client.tgTestSaveCachedChatsCallCount, 0,
			"an out-of-range slot must never touch the client");

	[TGClient setSharedInstanceForTesting:nil];
	return outcome;
}

TGTestOutcome TGAccountManagerTestSwitchToSlotNoOpWhenAlreadyOnSlotAndNotAddingAccount(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	TGClient *client = TGTestInstallFakeClient();

	[manager switchToSlot:0];

	TGTestExpectEqualInteger(&outcome, client.tgTestSaveCachedChatsCallCount, 0,
			"switching to the slot that is already current must be a no-op");

	[TGClient setSharedInstanceForTesting:nil];
	return outcome;
}

TGTestOutcome TGAccountManagerTestSwitchToSlotIsNoOpWhileAlreadySwitching(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	manager.switching = YES;
	TGClient *client = TGTestInstallFakeClient();

	[manager switchToSlot:1];

	TGTestExpectEqualInteger(&outcome, manager.currentSlot, 0,
			"a switch already in progress must block a second switch");
	TGTestExpectEqualInteger(&outcome, client.tgTestSaveCachedChatsCallCount, 0,
			"a blocked switch must never touch the client");

	[TGClient setSharedInstanceForTesting:nil];
	return outcome;
}

TGTestOutcome TGAccountManagerTestSwitchToSlotTriggersLogOutWhenAwaitingSignOutMatchesTarget(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	manager.slotAwaitingSignOut = 1;
	TGClient *client = TGTestInstallFakeClient();

	[manager switchToSlot:1];

	TGTestExpectEqualInteger(&outcome, client.tgTestLogOutCallCount, 1,
			"landing on the slot that is awaiting sign-out must log it out");

	[TGClient setSharedInstanceForTesting:nil];
	return outcome;
}

TGTestOutcome TGAccountManagerTestBeginAddingAccountSwitchesToFirstFreeSlotAndKeepsAddingFlag(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	[manager.records addObject:TGTestRecordForSlot(0)];
	manager.currentSlot = 0;
	TGTestInstallFakeClient();

	[manager beginAddingAccount];

	TGTestExpectEqualInteger(&outcome, manager.currentSlot, 1,
			"beginAddingAccount must switch to the first free slot");
	TGTestExpectEqualInteger(&outcome, manager.slotBeforeAdding, 0,
			"the slot to fall back to must be remembered");
	TGTestExpectTrue(&outcome, manager.addingAccount,
			"addingAccount must stay set until the new account signs in outside of the switch");

	[TGClient setSharedInstanceForTesting:nil];
	return outcome;
}

TGTestOutcome TGAccountManagerTestBeginAddingAccountNoOpWhenNoFreeSlot(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	[manager.records addObject:TGTestRecordForSlot(0)];
	[manager.records addObject:TGTestRecordForSlot(1)];
	[manager.records addObject:TGTestRecordForSlot(2)];
	TGClient *client = TGTestInstallFakeClient();

	[manager beginAddingAccount];

	TGTestExpectTrue(&outcome, !manager.addingAccount, "there is no free slot, so no add-account flow can start");
	TGTestExpectEqualInteger(&outcome, client.tgTestSaveCachedChatsCallCount, 0,
			"with no free slot the client must never be touched");

	[TGClient setSharedInstanceForTesting:nil];
	return outcome;
}

TGTestOutcome TGAccountManagerTestCancelAddingAccountReturnsToPreviousSlotWhenPossible(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	[manager.records addObject:TGTestRecordForSlot(0)];
	manager.currentSlot = 1;
	manager.addingAccount = YES;
	manager.slotBeforeAdding = 0;
	TGTestInstallFakeClient();

	[manager cancelAddingAccount];

	TGTestExpectTrue(&outcome, !manager.addingAccount, "cancelling must clear addingAccount");
	TGTestExpectEqualInteger(&outcome, manager.slotBeforeAdding, -1,
			"cancelling must reset slotBeforeAdding");
	TGTestExpectEqualInteger(&outcome, manager.currentSlot, 0,
			"cancelling must switch back to the slot that was active before adding started");

	[TGClient setSharedInstanceForTesting:nil];
	return outcome;
}

TGTestOutcome TGAccountManagerTestCancelAddingAccountNoOpWhenNotAddingAccount(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	manager.addingAccount = NO;
	TGClient *client = TGTestInstallFakeClient();

	[manager cancelAddingAccount];

	TGTestExpectEqualInteger(&outcome, client.tgTestSaveCachedChatsCallCount, 0,
			"cancelling when there is no add-account flow in progress must do nothing");

	[TGClient setSharedInstanceForTesting:nil];
	return outcome;
}

TGTestOutcome TGAccountManagerTestCancelAddingAccountDoesNotSwitchWhenNoValidPreviousSlot(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	manager.currentSlot = 1;
	manager.addingAccount = YES;
	manager.slotBeforeAdding = -1;
	TGClient *client = TGTestInstallFakeClient();

	[manager cancelAddingAccount];

	TGTestExpectTrue(&outcome, !manager.addingAccount, "addingAccount must still clear");
	TGTestExpectEqualInteger(&outcome, manager.currentSlot, 1,
			"with no valid previous slot to return to, the current slot must not change");
	TGTestExpectEqualInteger(&outcome, client.tgTestSaveCachedChatsCallCount, 0,
			"with no valid previous slot, the client must never be touched");

	[TGClient setSharedInstanceForTesting:nil];
	return outcome;
}

TGTestOutcome TGAccountManagerTestSignOutOfSlotNoOpForCurrentSlot(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	[manager.records addObject:TGTestRecordForSlot(0)];
	TGClient *client = TGTestInstallFakeClient();

	[manager signOutOfSlot:0];

	TGTestExpectEqualInteger(&outcome, manager.slotAwaitingSignOut, -1,
			"signing out of the currently active slot must be refused");
	TGTestExpectEqualInteger(&outcome, client.tgTestSaveCachedChatsCallCount, 0,
			"a refused sign-out must never touch the client");

	[TGClient setSharedInstanceForTesting:nil];
	return outcome;
}

TGTestOutcome TGAccountManagerTestSignOutOfSlotSwitchesToTargetAndLogsOut(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	[manager.records addObject:TGTestRecordForSlot(0)];
	[manager.records addObject:TGTestRecordForSlot(1)];
	manager.currentSlot = 0;
	TGClient *client = TGTestInstallFakeClient();

	[manager signOutOfSlot:1];

	TGTestExpectEqualInteger(&outcome, manager.currentSlot, 1,
			"signing out of another slot must switch onto it first");
	TGTestExpectEqualInteger(&outcome, manager.slotToResumeAfterSignOut, 0,
			"the slot to resume once the sign-out completes must be remembered");
	TGTestExpectEqualInteger(&outcome, client.tgTestLogOutCallCount, 1,
			"landing on the slot being signed out of must log it out");

	[TGClient setSharedInstanceForTesting:nil];
	return outcome;
}

TGTestOutcome TGAccountManagerTestHandleLogOutFallsBackToPreferredSlotWhenValid(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	[manager.records addObject:TGTestRecordForSlot(0)];
	[manager.records addObject:TGTestRecordForSlot(1)];
	manager.currentSlot = 1;
	manager.slotToResumeAfterSignOut = 0;
	manager.slotAwaitingSignOut = 1;
	TGTestInstallFakeClient();

	BOOL handled = [manager handleLogOutOfCurrentAccount];

	TGTestExpectTrue(&outcome, handled, "with another account available, logging out must be handled");
	TGTestExpectEqualInteger(&outcome, manager.slotAwaitingSignOut, -1,
			"handling the log-out must clear slotAwaitingSignOut");
	TGTestExpectEqualInteger(&outcome, manager.slotToResumeAfterSignOut, -1,
			"handling the log-out must clear slotToResumeAfterSignOut");
	TGTestExpectTrue(&outcome, [manager accountForSlot:1] == nil,
			"the record for the account that logged out must be forgotten");
	TGTestExpectEqualInteger(&outcome, manager.currentSlot, 0,
			"the manager must fall back to the preferred slot when it is still valid");

	[TGClient setSharedInstanceForTesting:nil];
	return outcome;
}

TGTestOutcome TGAccountManagerTestHandleLogOutForgetsRecordAndReturnsNoWhenNoOtherAccountsExist(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGAccountManager *manager = TGTestFreshManager();
	[manager.records addObject:TGTestRecordForSlot(0)];
	manager.currentSlot = 0;
	manager.slotToResumeAfterSignOut = -1;
	TGTestInstallFakeClient();

	BOOL handled = [manager handleLogOutOfCurrentAccount];

	TGTestExpectTrue(&outcome, !handled,
			"with no other account to fall back to, the log-out is not handled by switching");
	TGTestExpectEqualInteger(&outcome, manager.accounts.count, 0,
			"the only account's record must be forgotten once it logs out");

	[TGClient setSharedInstanceForTesting:nil];
	return outcome;
}

TGTestOutcome TGAccountManagerTestScopeForSlotIsNilForNonPositiveSlot(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome, [TGAccountManager scopeForSlot:0] == nil,
			"slot zero must map to the unscoped, primary account");
	TGTestExpectTrue(&outcome, [TGAccountManager scopeForSlot:-1] == nil,
			"a negative slot must map to no scope");
	TGTestExpectTrue(&outcome, [[TGAccountManager scopeForSlot:2] isEqualToString:@"2"],
			"a positive slot must map to its own scope string");

	return outcome;
}

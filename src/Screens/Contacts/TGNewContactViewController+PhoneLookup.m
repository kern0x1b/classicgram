#import "TGNewContactViewControllerInternal.h"
#import "TGContactsService.h"
#import "TGLocalization.h"

@implementation TGNewContactViewController (PhoneLookup)

- (NSString *)phoneStatusText {
	if ([self hasKnownPeer]) {
		if (self.prefillPhone.length || self.editingExistingContact)
			return nil;
		return TGL(@"NewContact.PhoneOnlySharedWhenMutual", @"This person's phone number will only be shared with you once you become mutual contacts.");
	}
	if (self.resolving)
		return TGL(@"NewContact.PhoneCheckingNumber", @"Checking this number...");
	if (!self.resolveFinished)
		return nil;
	if (self.resolvedUserId) {
		if (self.resolvedName.length)
			return [NSString stringWithFormat:TGL(@"NewContact.PhoneIsOnTelegram", @"%@ is on Telegram."),
				self.resolvedName];
		return TGL(@"NewContact.PhoneIsOnTelegramUnknownName", @"This number is on Telegram.");
	}
	return TGL(@"NewContact.PhoneNotOnTelegramYet", @"This number is not on Telegram yet. The contact will be saved anyway.");
}

- (void)resetPhoneLookup {
	self.resolving = NO;
	self.resolveFinished = NO;
	self.resolvedUserId = 0;
	self.resolvedName = nil;
	self.resolvedForPhone = nil;
}

- (void)schedulePhoneLookup {
	if ([self hasKnownPeer])
		return;
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(runPhoneLookup)
											   object:nil];
	NSString *phone = [self primaryPhone];
	if ([phone isEqualToString:self.resolvedForPhone])
		return;
	if (self.resolveFinished || self.resolving || self.resolvedForPhone) {
		[self resetPhoneLookup];
		[self refreshPhoneFooter];
	}
	if ([self digitsOf:phone].length < 5)
		return;
	[self performSelector:@selector(runPhoneLookup) withObject:nil afterDelay:1.0];
}

- (void)runPhoneLookup {
	NSString *phone = [self primaryPhone];
	if ([self digitsOf:phone].length < 5)
		return;
	self.resolving = YES;
	self.resolveFinished = NO;
	self.resolvedUserId = 0;
	self.resolvedName = nil;
	[self refreshPhoneFooter];

	__weak typeof(self) weakSelf = self;
	[TGContactsService userForPhone:phone completion:^(NSDictionary *user) {
		TGNewContactViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (![[strongSelf primaryPhone] isEqualToString:phone])
			return;
		strongSelf.resolving = NO;
		strongSelf.resolveFinished = YES;
		strongSelf.resolvedForPhone = phone;
		strongSelf.resolvedUserId = [user[@"id"] longLongValue];
		NSString *first = user[@"first_name"] ?: @"";
		NSString *last = user[@"last_name"] ?: @"";
		NSString *name = [[NSString stringWithFormat:@"%@ %@", first, last]
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		strongSelf.resolvedName = name.length ? name : nil;
		[strongSelf refreshPhoneFooter];
	}];
}

- (void)refreshPhoneFooter {
	NSString *text = [self phoneStatusText];
	self.phoneFooterLabel.text = text ?: @"";
	[self.tableView beginUpdates];
	[self.tableView endUpdates];
	[self.tableView reloadSections:[NSIndexSet indexSetWithIndex:2]
				  withRowAnimation:UITableViewRowAnimationNone];
}

@end

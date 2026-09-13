#import "TGContactsViewController.h"
#import "TGActionSheetIndexBuilder.h"
#import "TGContactsViewControllerInternal.h"
#import "TGContactsProgressWindow.h"
#import "TGFlatActionCell.h"
#import "TGContactRowCell.h"
#import "TGInviteFriendsViewController.h"
#import "TGContactsService.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGImageDecode.h"
#import "TGNewContactViewController.h"
#import "RootViewController.h"
#import "UIView+SafeTint.h"
#import "TGEmoji.h"
#import <QuartzCore/QuartzCore.h>
#import <AddressBook/AddressBook.h>
#import <dlfcn.h>
#import "TGAlertView.h"
#import "TGPreferenceFlags.h"

@implementation TGContactsViewController (Import)

- (void)reloadImportedCount {
	__weak typeof(self) weakSelf = self;
	[TGContactsService importedContactCountWithCompletion:^(NSInteger count) {
		TGContactsViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.importedCount = count;
		strongSelf.importedCountKnown = YES;
		[strongSelf reloadTableSoon];
	}];
}

- (NSString *)normalisedPhone:(NSString *)phone {
	NSMutableString *digits = [NSMutableString string];
	for (NSInteger i = 0; i < phone.length; i++) {
		unichar c = [phone characterAtIndex:i];
		if (c >= '0' && c <= '9')
			[digits appendFormat:@"%C", c];
	}
	return digits;
}

- (NSArray *)addressBookEntriesFrom:(ABAddressBookRef)book {
	NSMutableArray *entries = [NSMutableArray array];
	CFArrayRef people = ABAddressBookCopyArrayOfAllPeople(book);
	if (!people)
		return entries;
	CFIndex count = CFArrayGetCount(people);
	for (CFIndex i = 0; i < count; i++) {
		ABRecordRef person = CFArrayGetValueAtIndex(people, i);
		ABRecordID recordId = ABRecordGetRecordID(person);
		NSString *first = (__bridge_transfer NSString *)
			ABRecordCopyValue(person, kABPersonFirstNameProperty);
		NSString *last = (__bridge_transfer NSString *)
			ABRecordCopyValue(person, kABPersonLastNameProperty);
		ABMultiValueRef phones = ABRecordCopyValue(person, kABPersonPhoneProperty);
		if (!phones)
			continue;
		CFIndex phoneCount = ABMultiValueGetCount(phones);
		for (CFIndex j = 0; j < phoneCount; j++) {
			NSString *raw = (__bridge_transfer NSString *)
				ABMultiValueCopyValueAtIndex(phones, j);
			NSString *phone = [self normalisedPhone:raw ?: @""];
			if (phone.length < 5)
				continue;
			[entries addObject:@{
				@"phone" : phone,
				@"first_name" : first.length ? first : @"",
				@"last_name" : last.length ? last : @"",
				@"record_id" : @(recordId),
			}];
		}
		CFRelease(phones);
	}
	CFRelease(people);
	return entries;
}

- (void)finishImportWithResult:(NSArray *)userIds total:(NSInteger)total {
	(void)userIds;
	(void)total;
	self.importing = NO;
	[self reloadImportedCount];
	[self reloadContacts];
}

- (void)startAddressBookImport {
	if (self.importing)
		return;
	if (![TGPreferenceFlags syncContactsEnabled])
		return;
	if ([self phonebookAccessDenied])
		return;

	ABAddressBookRef book = ABAddressBookCreateWithOptions(NULL, NULL);
	if (!book)
		return;
	self.importing = YES;

	__weak typeof(self) weakSelf = self;
	ABAddressBookRequestAccessWithCompletion(book, ^(bool granted, CFErrorRef error) {
		dispatch_async(dispatch_get_main_queue(), ^{
			TGContactsViewController *strongSelf = weakSelf;
			if (!strongSelf) {
				CFRelease(book);
				return;
			}
			if (!granted) {
				CFRelease(book);
				strongSelf.importing = NO;
				[strongSelf updatePhonebookAccess];
				return;
			}
			NSArray *entries = [strongSelf addressBookEntriesFrom:book];
			CFRelease(book);
			if (!entries.count) {
				strongSelf.importing = NO;
				return;
			}
			NSInteger total = (NSInteger)entries.count;
			[TGContactsService importContacts:entries completion:^(NSArray *userIds) {
				TGContactsViewController *innerSelf = weakSelf;
				if (!innerSelf)
					return;
				[innerSelf finishImportWithResult:userIds total:total];
			}];
		});
	});
}

- (NSString *)inviteMessageText {
	NSString *link = [self shareableLink];
	if (!link.length) {
		link = nil;
		NSDictionary *me = [TGContactsService me];
		NSDictionary *usernameBox = [me isKindOfClass:NSDictionary.class] ? me[@"usernames"] : nil;
		NSArray *usernames = [usernameBox isKindOfClass:NSDictionary.class]
			? usernameBox[@"active_usernames"]
			: nil;
		NSString *username = ([usernames isKindOfClass:NSArray.class] && usernames.count)
			? usernames[0]
			: nil;
		if ([username isKindOfClass:NSString.class] && username.length)
			link = [NSString stringWithFormat:@"https://t.me/%@", username];
	}
	if (!link)
		link = @"https://telegram.org";
	return [NSString stringWithFormat:
			TGL(@"Contacts.InviteMessageText", @"Hey, I'm using Telegram to chat. You can join me here: %@"), link];
}

- (NSArray *)dedupedInviteEntries:(NSArray *)entries {
	NSMutableSet *seen = [NSMutableSet set];
	NSMutableArray *out = [NSMutableArray array];
	for (NSDictionary *entry in entries) {
		NSString *first = TGContactString(entry, @"first_name");
		NSString *last = TGContactString(entry, @"last_name");
		NSString *phone = TGContactString(entry, @"phone");
		if (!phone.length)
			continue;
		id recordId = entry[@"record_id"];
		id key;
		if ([recordId isKindOfClass:NSNumber.class])
			key = recordId;
		else if (first.length || last.length)
			key = [[NSString stringWithFormat:@"%@|%@", first, last] lowercaseString];
		else
			key = [@"#" stringByAppendingString:phone];
		if ([seen containsObject:key])
			continue;
		[seen addObject:key];
		[out addObject:entry];
	}
	return [out sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
		NSString *nameA = [[NSString stringWithFormat:@"%@ %@",
			TGContactString(a, @"first_name"), TGContactString(a, @"last_name")]
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		NSString *nameB = [[NSString stringWithFormat:@"%@ %@",
			TGContactString(b, @"first_name"), TGContactString(b, @"last_name")]
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		if (!nameA.length)
			nameA = TGContactString(a, @"phone");
		if (!nameB.length)
			nameB = TGContactString(b, @"phone");
		return [nameA localizedCaseInsensitiveCompare:nameB];
	}];
}

- (void)finishInviteListWithEntries:(NSArray *)entries userIds:(NSArray *)userIds {
	self.buildingInviteList = NO;
	[self.progress dismiss];
	self.progress = nil;

	NSMutableArray *missing = [NSMutableArray array];
	BOOL haveIds = ([userIds isKindOfClass:NSArray.class] && userIds.count == entries.count);
	for (NSInteger i = 0; i < entries.count; i++) {
		if (haveIds) {
			NSNumber *userId = userIds[i];
			if ([userId isKindOfClass:NSNumber.class] && userId.longLongValue != 0)
				continue;
		}
		[missing addObject:entries[i]];
	}
	NSArray *list = [self dedupedInviteEntries:missing];
	TGInviteFriendsViewController *vc = [[TGInviteFriendsViewController alloc] init];
	vc.entries = list;
	vc.inviteText = [self inviteMessageText];
	[self.navigationController pushViewController:vc animated:YES];
	[self reloadImportedCount];
}

- (void)shareInviteLinkDirectly {
	UIActivityViewController *sheet = [[UIActivityViewController alloc]
		initWithActivityItems:@[ [self inviteMessageText] ]
		applicationActivities:nil];
	[self presentViewController:sheet animated:YES completion:nil];
}

- (void)inviteFriendsTapped {
	if (self.buildingInviteList || self.importing)
		return;

	if (![TGPreferenceFlags syncContactsEnabled]) {
		[self shareInviteLinkDirectly];
		return;
	}
	ABAddressBookRef book = ABAddressBookCreateWithOptions(NULL, NULL);
	if (!book) {
		[self shareInviteLinkDirectly];
		return;
	}
	self.buildingInviteList = YES;
	self.progress = [[TGContactsProgressWindow alloc] init];
	[self.progress show];

	__weak typeof(self) weakSelf = self;
	ABAddressBookRequestAccessWithCompletion(book, ^(bool granted, CFErrorRef error) {
		dispatch_async(dispatch_get_main_queue(), ^{
			TGContactsViewController *strongSelf = weakSelf;
			if (!strongSelf) {
				CFRelease(book);
				return;
			}
			if (!granted) {
				CFRelease(book);
				strongSelf.buildingInviteList = NO;
				[strongSelf.progress dismiss];
				strongSelf.progress = nil;
				[strongSelf shareInviteLinkDirectly];
				return;
			}
			NSArray *entries = [strongSelf addressBookEntriesFrom:book];
			CFRelease(book);
			if (!entries.count) {
				strongSelf.buildingInviteList = NO;
				[strongSelf.progress dismiss];
				strongSelf.progress = nil;
				[strongSelf shareInviteLinkDirectly];
				return;
			}
			[TGContactsService importContacts:entries completion:^(NSArray *userIds) {
				TGContactsViewController *innerSelf = weakSelf;
				if (!innerSelf)
					return;
				[innerSelf finishInviteListWithEntries:entries userIds:userIds];
			}];
		});
	});
}

@end

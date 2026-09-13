#import "TGContactsViewController.h"
#import "TGStringTruncation.h"
#import "TGContactsViewControllerInternal.h"
#import "TGFlatActionCell.h"
#import "TGContactRowCell.h"
#import "TGInviteFriendsViewController.h"
#import "TGSecretChatViewController.h"
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

const NSUInteger kContactPhotoCacheCount = 80;
const NSUInteger kContactPhotoCacheBytes = 2 * 1024 * 1024;

NSUInteger TGContactPhotoCost(UIImage *image) {
	CGImageRef bitmap = image.CGImage;
	if (!bitmap)
		return (NSUInteger)(image.size.width * image.size.height * 4);
	return (NSUInteger)(CGImageGetWidth(bitmap) * CGImageGetHeight(bitmap) * 4);
}

NSString *const TGContactsSortByLastSeenKey = @"TGContactsSortByLastSeen";
NSString *const TGContactActionInvite = @"invite";
NSString *const TGContactActionNewGroup = @"newGroup";
NSString *const TGContactActionNewChannel = @"newChannel";
NSString *const TGContactActionLink = @"link";

BOOL TGContactsTabletLayout(void) {
	return [RootViewController isSplitLayoutActive];
}

BOOL TGContactsShowInDetailPane(UIViewController *sender,
	UIViewController *target) {
	(void)sender;
	if (!target || !TGContactsTabletLayout())
		return NO;
	return [RootViewController pushInDetail:target];
}

CGFloat TGContactsScreenWidth(void) {
	return [UIScreen mainScreen].bounds.size.width;
}

UIImage *TGContactsScaledImage(NSString *name, CGFloat side) {
	static NSMutableDictionary *cache = nil;
	if (!cache)
		cache = [NSMutableDictionary dictionary];
	NSString *key = [NSString stringWithFormat:@"%@-%d", name, (int)side];
	UIImage *cached = cache[key];
	if (cached)
		return cached;
	UIImage *source = [UIImage imageNamed:name];
	if (!source)
		return nil;
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0.0f);
	[source drawInRect:CGRectMake(0, 0, side, side)];
	UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	if (scaled)
		cache[key] = scaled;
	return scaled;
}

NSString *TGContactsSortedByPresenceTitle(void) {
	return TGL(@"Contacts.SortedByLastSeenTime", @"Sorted by Last Seen Time");
}

@implementation TGContactsViewController

+ (UIViewController *)secretChatInfoForChat:(int64_t)chatId
									 userId:(int64_t)userId
									   name:(NSString *)name {
	TGSecretChatViewController *info = [[TGSecretChatViewController alloc] init];
	info.chatId = chatId;
	info.secretChatId = [TGContactsService secretChatIdForChat:chatId];
	info.userId = userId;
	info.peerName = name;
	return info;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (self.userStatusChangedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.userStatusChangedObserverToken];
	if (self.addressBookOrderMayHaveChangedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.addressBookOrderMayHaveChangedObserverToken];
	if (self.contactsDidChangeObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.contactsDidChangeObserverToken];
	[self stopObservingAddressBookExternalChanges];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
}

NSString *TGContactSortKey(NSDictionary *u, BOOL byFirstName) {
	NSString *primary = TGContactString(u, byFirstName ? @"first_name" : @"last_name");
	if (primary.length)
		return primary;
	NSString *secondary = TGContactString(u, byFirstName ? @"last_name" : @"first_name");
	if (secondary.length)
		return secondary;
	return TGContactName(u);
}

NSString *TGContactSectionLetter(NSDictionary *u, BOOL byFirstName) {
	NSString *key = TGContactSortKey(u, byFirstName);
	if (!key.length)
		return @"#";
	NSString *letter = [TGSafeFirstCharacter(key) uppercaseString];
	unichar c = [letter characterAtIndex:0];
	if ((c >= '0' && c <= '9') || [[NSCharacterSet symbolCharacterSet] characterIsMember:c] || ![[NSCharacterSet alphanumericCharacterSet] characterIsMember:c])
		return @"#";
	return letter;
}

- (void)updateContactSortOrder {
	self.sortByFirstName = (ABPersonGetSortOrdering() != kABPersonSortByLastName);
	self.displayFirstNameFirst =
		(ABPersonGetCompositeNameFormat() != kABPersonCompositeNameFormatLastNameFirst);
}

- (void)addressBookOrderMayHaveChanged {
	BOOL sortByFirst = self.sortByFirstName;
	BOOL displayFirst = self.displayFirstNameFirst;
	[self updateContactSortOrder];
	if (sortByFirst == self.sortByFirstName && displayFirst == self.displayFirstNameFirst)
		return;
	[self refreshTable];
}

- (void)sortUsers {
	BOOL byFirstName = self.sortByFirstName;
	if (self.sortByLastSeen && !self.pickerMode) {
		self.users = [self.users sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
			long long rankA = [[a objectForKey:@"statusRank"] longLongValue];
			long long rankB = [[b objectForKey:@"statusRank"] longLongValue];
			if (rankA != rankB)
				return rankA > rankB ? NSOrderedAscending : NSOrderedDescending;
			return [TGContactSortKey(a, byFirstName)
				localizedCaseInsensitiveCompare:TGContactSortKey(b, byFirstName)];
		}];
		return;
	}
	self.users = [self.users sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
		NSString *letterA = TGContactSectionLetter(a, byFirstName);
		NSString *letterB = TGContactSectionLetter(b, byFirstName);
		BOOL hashA = [letterA isEqualToString:@"#"];
		BOOL hashB = [letterB isEqualToString:@"#"];
		if (hashA != hashB)
			return hashA ? NSOrderedDescending : NSOrderedAscending;
		if (!hashA) {
			NSComparisonResult byLetter = [letterA compare:letterB];
			if (byLetter != NSOrderedSame)
				return byLetter;
		}
		NSComparisonResult result = [TGContactSortKey(a, byFirstName)
			localizedCaseInsensitiveCompare:TGContactSortKey(b, byFirstName)];
		if (result != NSOrderedSame)
			return result;
		NSString *otherA = TGContactString(a, byFirstName ? @"last_name" : @"first_name");
		NSString *otherB = TGContactString(b, byFirstName ? @"last_name" : @"first_name");
		if (!otherA.length || !otherB.length)
			return NSOrderedSame;
		return [otherA localizedCaseInsensitiveCompare:otherB];
	}];
}

- (BOOL)isCloseFriend:(NSDictionary *)u {
	NSNumber *userId = [u[@"id"] isKindOfClass:NSNumber.class] ? u[@"id"] : nil;
	return userId && [self.closeFriendIds containsObject:@(userId.longLongValue)];
}

- (void)reloadCloseFriends {
	__weak typeof(self) weakSelf = self;
	[TGContactsService contactCloseFriendsWithCompletion:^(NSArray *users, BOOL failed) {
		TGContactsViewController *strongSelf = weakSelf;
		if (!strongSelf || failed)
			return;
		NSMutableSet *ids = [NSMutableSet set];
		if ([users isKindOfClass:NSArray.class]) {
			for (NSDictionary *u in users) {
				if (![u isKindOfClass:NSDictionary.class])
					continue;
				NSNumber *userId = [u[@"id"] isKindOfClass:NSNumber.class] ? u[@"id"] : nil;
				if (userId)
					[ids addObject:@(userId.longLongValue)];
			}
		}
		strongSelf.closeFriendIds = ids;
		[strongSelf reloadTableSoon];
	}];
}

@end

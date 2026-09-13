#import "TGContactsViewController.h"
#import "TGContactsViewControllerInternal.h"
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

@implementation TGContactsViewController (Filtering)

- (BOOL)matchesQuery:(NSDictionary *)u query:(NSString *)query {
	if ([TGContactName(u) rangeOfString:query options:NSCaseInsensitiveSearch].length)
		return YES;
	if ([TGContactString(u, @"username") rangeOfString:query
											   options:NSCaseInsensitiveSearch]
			.length)
		return YES;
	if ([TGContactString(u, @"phone") rangeOfString:query
											options:NSCaseInsensitiveSearch]
			.length)
		return YES;
	return NO;
}

- (void)applyFilter {
	NSString *query = [self.searchQuery
		stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!query.length) {
		self.filteredUsers = nil;
		return;
	}
	NSMutableArray *out = [NSMutableArray array];
	NSMutableSet *seen = [NSMutableSet set];
	for (NSDictionary *u in self.users) {
		if (![self matchesQuery:u query:query])
			continue;
		[out addObject:u];
		[seen addObject:@([u[@"id"] longLongValue])];
	}
	if ([self.serverQuery isEqualToString:query]) {
		for (NSDictionary *u in self.serverUsers) {
			if (![u isKindOfClass:NSDictionary.class])
				continue;
			NSNumber *key = @([u[@"id"] longLongValue]);
			if (key.longLongValue == 0 || [seen containsObject:key])
				continue;
			[seen addObject:key];
			[out addObject:u];
		}
	}
	self.filteredUsers = out;
}

- (void)runServerContactSearch {
	NSString *query = [self.searchQuery
		stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (query.length < 2)
		return;
	__weak typeof(self) weakSelf = self;
	[TGContactsService searchContacts:query limit:30 completion:^(NSArray *users, BOOL failed) {
		TGContactsViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSString *current = [strongSelf.searchQuery
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if (![current isEqualToString:query])
			return;
		if (failed)
			return;
		strongSelf.serverQuery = query;
		strongSelf.serverUsers = [users isKindOfClass:NSArray.class] ? users : @[];
		[strongSelf applyFilter];
		[strongSelf rebuildSections];
		[strongSelf.tableView reloadData];
		[strongSelf updateEmptyState];
	}];
}

- (NSArray *)actionRowIdentifiers {
	if (self.pickerMode || self.filteredUsers)
		return nil;
	NSMutableArray *rows = [NSMutableArray arrayWithObjects:
			TGContactActionInvite, TGContactActionNewGroup, TGContactActionNewChannel, nil];
	if ([self shareableLink].length)
		[rows addObject:TGContactActionLink];
	return rows;
}

- (void)rebuildSections {
	if (self.filteredUsers) {
		self.sectionTitles = nil;
		self.sections = nil;
		return;
	}
	NSMutableArray *titles = [NSMutableArray array];
	NSMutableArray *groups = [NSMutableArray array];
	if (self.sortByLastSeen && !self.pickerMode) {
		if (self.users.count) {
			[titles addObject:TGContactsSortedByPresenceTitle()];
			[groups addObject:[self.users mutableCopy]];
		}
	} else {
		NSMutableDictionary *indexForLetter = [NSMutableDictionary dictionary];
		for (NSDictionary *u in self.users) {
			NSString *letter = TGContactSectionLetter(u, self.sortByFirstName);
			NSNumber *existing = [indexForLetter objectForKey:letter];
			if (!existing) {
				existing = [NSNumber numberWithUnsignedInteger:titles.count];
				[indexForLetter setObject:existing forKey:letter];
				[titles addObject:letter];
				[groups addObject:[NSMutableArray array]];
			}
			[[groups objectAtIndex:existing.unsignedIntegerValue] addObject:u];
		}
	}

	if (!self.pickerMode) {
		NSArray *actions = [self actionRowIdentifiers];
		if (actions.count) {
			[titles insertObject:[NSNull null] atIndex:0];
			[groups insertObject:actions atIndex:0];
		}
	}

	self.sectionTitles = titles;
	self.sections = groups;
}

- (NSString *)letterForSection:(NSInteger)section {
	if (!self.sectionTitles || section < 0 || section >= (NSInteger)self.sectionTitles.count)
		return nil;
	id title = self.sectionTitles[section];
	return [title isKindOfClass:NSString.class] ? title : nil;
}

- (NSString *)actionIdentifierAtIndexPath:(NSIndexPath *)indexPath {
	NSArray *rows = [self rowsForSection:indexPath.section];
	if (indexPath.row < 0 || indexPath.row >= (NSInteger)rows.count)
		return nil;
	id row = rows[indexPath.row];
	return [row isKindOfClass:NSString.class] ? row : nil;
}

- (void)userStatusChanged:(NSNotification *)note {
	int64_t userId = [note.userInfo[@"userId"] longLongValue];
	NSDictionary *status = note.userInfo[@"status"];
	if (![status isKindOfClass:NSDictionary.class])
		return;
	NSMutableArray *updated = [self.users mutableCopy];
	for (NSInteger i = 0; i < updated.count; i++) {
		NSDictionary *u = updated[i];
		if ([u[@"id"] longLongValue] != userId)
			continue;
		NSMutableDictionary *next = [u mutableCopy];
		next[@"isOnline"] = status[@"isOnline"] ?: @(NO);
		next[@"statusText"] = status[@"text"] ?: @"";
		next[@"statusRank"] = status[@"rank"] ?: @(0);
		updated[i] = next;
		break;
	}
	self.users = updated;
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(applyPendingStatusChanges)
											   object:nil];
	[self performSelector:@selector(applyPendingStatusChanges) withObject:nil afterDelay:0];
}

- (void)applyPendingStatusChanges {
	[self refreshTable];
}

- (void)refreshTable {
	[self sortUsers];
	[self applyFilter];
	[self rebuildSections];
	[self.tableView reloadData];
	[self updateEmptyState];
	[self updatePhonebookAccess];
}

- (void)reloadTableSoon {
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(reloadTableNow)
											   object:nil];
	[self performSelector:@selector(reloadTableNow) withObject:nil afterDelay:0.15f];
}

- (void)reloadTableNow {
	[self.tableView reloadData];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)query {
	self.searchQuery = query;
	[self applyFilter];
	[self rebuildSections];
	[self.tableView reloadData];
	[self updateEmptyState];
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(runServerContactSearch)
											   object:nil];
	[self performSelector:@selector(runServerContactSearch) withObject:nil afterDelay:0.35f];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
	[searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
	[searchBar setShowsCancelButton:NO animated:YES];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	searchBar.text = @"";
	self.searchQuery = nil;
	self.filteredUsers = nil;
	self.serverUsers = nil;
	self.serverQuery = nil;
	[self rebuildSections];
	[self.tableView reloadData];
	[self updateEmptyState];
	[searchBar resignFirstResponder];
}

@end

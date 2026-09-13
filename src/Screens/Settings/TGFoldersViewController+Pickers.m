#import "TGFoldersViewController.h"
#import "TGStringTruncation.h"
#import "TGFoldersInternal.h"
#import "TGLocalization.h"
#import "TGClient+ChatList.h"
#import "TGTheme.h"
#import "TGIcons.h"

@implementation TGFoldersViewController (Pickers)

#pragma mark - chat picker

- (void)pushPickerForKey:(NSString *)key title:(NSString *)title {
	TGFoldersViewController *picker = [[TGFoldersViewController alloc] init];
	picker.page = TGFoldersPageChatPicker;
	picker.title = title;
	NSMutableSet *selection = [NSMutableSet set];
	for (NSNumber *identifier in self.draft[key])
		[selection addObject:identifier];
	picker.pickerSelection = selection;
	picker.pickerLimit = self.chosenChatLimit;
	__weak typeof(self) weakSelf = self;
	picker.pickerCompletion = ^(NSArray *chatIds) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.draft[key] = [chatIds mutableCopy];
		[strongSelf.tableView reloadData];
		[strongSelf refreshDefaultIcon];
	};
	[self.navigationController pushViewController:picker animated:YES];
}

- (void)pushChatPickerWithFixedChats:(NSArray *)chats
							 selected:(NSArray *)selectedChatIds
								title:(NSString *)title
						   completion:(void (^)(NSArray *chatIds))completion {
	TGFoldersViewController *picker = [[TGFoldersViewController alloc] init];
	picker.page = TGFoldersPageChatPicker;
	picker.title = title;
	picker.pickerFixedChats = chats;
	NSMutableSet *selection = [NSMutableSet set];
	for (NSNumber *identifier in selectedChatIds)
		[selection addObject:identifier];
	picker.pickerSelection = selection;
	picker.pickerCompletion = completion;
	[self.navigationController pushViewController:picker animated:YES];
}

- (void)loadPickerChats {
	if (!self.pickerSelection)
		self.pickerSelection = [NSMutableSet set];
	self.pickerMainLimit = 200;
	self.pickerArchiveLimit = 100;
	self.pickerMainExhausted = NO;
	self.pickerArchiveExhausted = NO;
	[self showStatus:TGL(@"Channel.NotificationLoading", @"Loading…")];
	[self refreshPickerChats];
}

- (void)adoptFixedPickerChats {
	if (!self.pickerSelection)
		self.pickerSelection = [NSMutableSet set];
	self.pickerMainExhausted = YES;
	self.pickerArchiveExhausted = YES;
	[self appendPickerChats:self.pickerFixedChats];
	[self finishPickerLoad];
}

- (void)refreshPickerChats {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] chatsInList:TGChatListMain limit:self.pickerMainLimit completion:^(NSArray *chats) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.pickerMainExhausted = (NSInteger)chats.count < strongSelf.pickerMainLimit;
		[[TGClient shared] chatsInList:TGChatListArchive limit:strongSelf.pickerArchiveLimit
							completion:^(NSArray *archived) {
								typeof(self) innerSelf = weakSelf;
								if (!innerSelf)
									return;
								innerSelf.pickerArchiveExhausted =
										(NSInteger)archived.count < innerSelf.pickerArchiveLimit;
								[innerSelf appendPickerChats:chats];
								[innerSelf appendPickerChats:archived];
								[innerSelf finishPickerLoad];
							}];
	}];
}

- (void)loadMorePickerChatsIfNeeded {
	if (self.page != TGFoldersPageChatPicker || self.pickerFixedChats)
		return;
	if (!self.pickerLoaded || self.pickerLoadingMore)
		return;
	if (self.pickerMainExhausted && self.pickerArchiveExhausted)
		return;

	UITableView *table = self.tableView;
	CGFloat bottom = table.contentOffset.y + table.bounds.size.height;
	if (table.contentSize.height <= 0 || bottom < table.contentSize.height - kRowHeight * 2)
		return;

	self.pickerLoadingMore = YES;
	if (!self.pickerMainExhausted) {
		self.pickerMainLimit += 200;
		[[TGClient shared] loadMoreChatsInList:TGChatListMain limit:200];
	}
	if (!self.pickerArchiveExhausted) {
		self.pickerArchiveLimit += 100;
		[[TGClient shared] loadMoreChatsInList:TGChatListArchive limit:100];
	}
	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			[weakSelf refreshPickerChats];
		});
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	[self loadMorePickerChatsIfNeeded];
}

- (void)appendPickerChats:(NSArray *)chats {
	if (![chats isKindOfClass:[NSArray class]])
		return;
	NSMutableSet *seen = [NSMutableSet set];
	for (NSDictionary *row in self.pickerChats)
		[seen addObject:row[@"id"]];
	for (NSDictionary *row in chats) {
		if (![row isKindOfClass:[NSDictionary class]])
			continue;
		NSNumber *identifier = row[@"id"];
		if (![identifier isKindOfClass:[NSNumber class]] || [seen containsObject:identifier])
			continue;
		[seen addObject:identifier];
		[self.pickerChats addObject:row];
	}
}

- (void)finishPickerLoad {
	self.pickerLoaded = YES;
	self.pickerLoadingMore = NO;
	if (self.pickerChats.count == 0)
		[self showStatus:TGL(@"FoldersPicker.NoChatsToChooseFrom", @"No chats to choose from.")];
	else
		[self showStatus:nil];
	[self.tableView reloadData];
}

- (void)finishPicking {
	NSMutableArray *ordered = [NSMutableArray array];
	for (NSDictionary *row in self.pickerChats) {
		NSNumber *identifier = row[@"id"];
		if ([self.pickerSelection containsObject:identifier])
			[ordered addObject:identifier];
	}
	for (NSNumber *identifier in self.pickerSelection) {
		if (![ordered containsObject:identifier])
			[ordered addObject:identifier];
	}
	if (self.pickerCompletion)
		self.pickerCompletion(ordered);
	[self.navigationController popViewControllerAnimated:YES];
}

- (NSString *)titleForChatId:(NSNumber *)identifier {
	NSArray *pools = @[ [TGClient shared].chats ?: @[], [TGClient shared].archivedChats ?: @[] ];
	for (NSArray *pool in pools) {
		if (![pool isKindOfClass:[NSArray class]])
			continue;
		for (NSDictionary *row in pool) {
			if (![row isKindOfClass:[NSDictionary class]])
				continue;
			if ([row[@"id"] isEqual:identifier]) {
				NSString *title = row[@"title"];
				if ([title isKindOfClass:[NSString class]] && title.length)
					return title;
			}
		}
	}
	return TGL(@"ChatList.UnnamedChat", @"Chat");
}

- (NSString *)initialsForTitle:(NSString *)title {
	if (!title.length)
		return @"#";
	return [TGSafeFirstCharacter(title) uppercaseString];
}

#pragma mark - icon picker

- (void)pushIconPicker {
	TGFoldersViewController *picker = [[TGFoldersViewController alloc] init];
	picker.page = TGFoldersPageIconPicker;
	NSString *icon = self.draft[@"icon"];
	picker.currentIcon = [icon isKindOfClass:[NSString class]] ? icon : @"";
	__weak typeof(self) weakSelf = self;
	picker.iconCompletion = ^(NSString *iconName) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.draft[@"icon"] = iconName ?: @"";
		[strongSelf.tableView reloadData];
	};
	[self.navigationController pushViewController:picker animated:YES];
}

#pragma mark - tag colour

- (NSInteger)draftColourId {
	NSNumber *value = self.draft[@"colorId"];
	if (![value isKindOfClass:[NSNumber class]])
		return -1;
	NSInteger colourId = value.integerValue;
	return (colourId >= 0 && colourId < 7) ? colourId : -1;
}

- (void)selectDraftColourId:(NSInteger)colourId {
	self.draft[@"colorId"] = @(colourId);
	[self.tableView reloadRowsAtIndexPaths:
			@[ [NSIndexPath indexPathForRow:2 inSection:0] ]
						   withRowAnimation:UITableViewRowAnimationNone];
}

@end

#import "TGClient+ChatManagement.h"
#import "TGDateUtils.h"
#import "TGClient+ChatState.h"
#import "TGSearchViewController.h"
#import "TGSearchViewControllerInternal.h"
#import "TGSearchAuthorLine.h"
#import "TGSearchCalendarViewController.h"
#import "TGSearchResultCell.h"
#import "TGSearchMessageCell.h"
#import "AppDelegate.h"
#import "TGImageDecode.h"
#import "TGClient+Search.h"
#import "TGClient+ChatList.h"
#import "TGClient+SecretChats.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+SafeTint.h"
#import "TGStringTruncation.h"
#import "TGAccountManager.h"

@implementation TGSearchViewController (Searching)

#pragma mark - recents

- (void)loadRecents {
	NSArray *stored = [[NSUserDefaults standardUserDefaults]
		arrayForKey:[TGAccountManager defaultsKey:kSearchRecentsKey]];
	NSMutableArray *clean = [NSMutableArray array];
	for (id entry in stored) {
		if (![entry isKindOfClass:NSDictionary.class])
			continue;
		NSDictionary *row = entry;
		if (![row[@"chatId"] isKindOfClass:NSNumber.class] || [row[@"chatId"] longLongValue] == 0)
			continue;
		if (![row[@"title"] isKindOfClass:NSString.class])
			continue;
		[clean addObject:row];
	}
	self.recents = clean;
}

- (void)rememberRecent:(NSDictionary *)row {
	if ([row[@"chatId"] longLongValue] == 0)
		return;
	NSMutableArray *updated = [NSMutableArray array];
	[updated addObject:@{@"chatId" : row[@"chatId"] ?: @0,
		@"title" : row[@"title"] ?: @"",
		@"isGroup" : @([row[@"isGroup"] boolValue])}];
	for (NSDictionary *old in self.recents) {
		if ([old[@"chatId"] longLongValue] == [row[@"chatId"] longLongValue])
			continue;
		if (updated.count >= kSearchRecentsLimit)
			break;
		[updated addObject:old];
	}
	self.recents = updated;
	[[NSUserDefaults standardUserDefaults] setObject:updated
		forKey:[TGAccountManager defaultsKey:kSearchRecentsKey]];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[TGClient shared] addRecentlyFoundChat:[row[@"chatId"] longLongValue]];
}

- (void)forgetRecentChat:(int64_t)chatId {
	if (!chatId)
		return;
	NSMutableArray *kept = [NSMutableArray array];
	for (NSDictionary *old in self.recents) {
		if ([old[@"chatId"] longLongValue] == chatId)
			continue;
		[kept addObject:old];
	}
	self.recents = kept;
	[[NSUserDefaults standardUserDefaults] setObject:kept
		forKey:[TGAccountManager defaultsKey:kSearchRecentsKey]];
	[[NSUserDefaults standardUserDefaults] synchronize];

	NSMutableArray *keptRemote = [NSMutableArray array];
	for (NSDictionary *old in self.remoteRecents) {
		if (![old isKindOfClass:NSDictionary.class] || [old[@"id"] longLongValue] == chatId)
			continue;
		[keptRemote addObject:old];
	}
	self.remoteRecents = keptRemote;
	[[TGClient shared] removeRecentlyFoundChat:chatId];
	[self rebuildSections];
}

- (void)forgetTopPeer:(int64_t)chatId {
	if (!chatId)
		return;
	NSMutableArray *kept = [NSMutableArray array];
	for (NSDictionary *old in self.topPeers) {
		if ([old[@"chatId"] longLongValue] == chatId)
			continue;
		[kept addObject:old];
	}
	self.topPeers = kept;
	[[TGClient shared] removeTopChat:chatId];
	[self rebuildSections];
}

- (void)clearRecentTags {
	[[TGClient shared] clearSearchedForTagsIncludingCashtags:NO];
	[[TGClient shared] clearSearchedForTagsIncludingCashtags:YES];
	self.recentTags = @[];
	[self rebuildSections];
}

- (void)clearRecents {
	self.recents = @[];
	self.remoteRecents = @[];
	[[TGClient shared] clearRecentlyFoundChats];
	[[NSUserDefaults standardUserDefaults]
		removeObjectForKey:[TGAccountManager defaultsKey:kSearchRecentsKey]];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[self rebuildSections];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if (!_searchFieldStyled) {
		_searchFieldStyled = YES;
		[self.bar layoutIfNeeded];
		[self styleSearchInputField:self.bar];
	}
}

- (void)styleSearchInputField:(UIView *)view {
	if ([view isKindOfClass:[UITextField class]]) {
		UITextField *field = (UITextField *)view;
		field.borderStyle = UITextBorderStyleNone;
		field.background = nil;
		field.font = [UIFont systemFontOfSize:14];
		field.clipsToBounds = NO;
		field.textColor = [UIColor blackColor];

		self.searchField = field;
		[self applyPlaceholderColour];

		UIView *leftView = field.leftView;
		if ([leftView isKindOfClass:[UIImageView class]]) {
			UIImage *icon = [UIImage imageNamed:@"SearchBarIcon.png"];
			if (icon) {
				((UIImageView *)leftView).image = icon;
				[leftView sizeToFit];
			}
		}

		UIImage *inputImage = [UIImage imageNamed:@"SearchInputField.png"];
		if (inputImage) {
			int leftCapWidth = (int)(inputImage.size.width / 2);
			inputImage = [inputImage stretchableImageWithLeftCapWidth:leftCapWidth topCapHeight:0];
			UIImageView *inputImageView = [[UIImageView alloc] initWithFrame:
					CGRectMake(0, 0.5f, field.frame.size.width, inputImage.size.height)];
			inputImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
			inputImageView.image = inputImage;
			[field insertSubview:inputImageView atIndex:0];
		}

		SEL clearButtonSelector = NSSelectorFromString([[NSString alloc]
			initWithFormat:@"%sBu%s", "clear", "tton"]);
		if ([field respondsToSelector:clearButtonSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
			UIButton *clearButton = [field performSelector:clearButtonSelector];
#pragma clang diagnostic pop
			if ([clearButton isKindOfClass:[UIButton class]]) {
				UIImage *clear = [UIImage imageNamed:@"ClearInput.png"];
				UIImage *clearPressed = [UIImage imageNamed:@"ClearInput_Pressed.png"];
				if (clear)
					[clearButton setImage:clear forState:UIControlStateNormal];
				if (clearPressed)
					[clearButton setImage:clearPressed forState:UIControlStateHighlighted];
			}
		}
		return;
	}

	for (UIView *child in view.subviews)
		[self styleSearchInputField:child];
}

- (void)cancel {
	[self.bar resignFirstResponder];
	[self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - searching

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)query {
	NSString *trimmed = [(query ?: @"") stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([trimmed isEqualToString:_query])
		return;

	_query = trimmed;
	_generation++;
	_pending = 0;
	_loadingMore = NO;
	_messagesOffset = @"";
	_messagesFromId = 0;
	_dateAnchored = NO;
	_anchorLabel = nil;
	_debouncing = [self hasActiveQuery];

	self.messageHits = @[];
	self.globalHits = @[];
	self.hashtagHits = @[];
	self.recentMatches = @[];
	[self runLocalSearch];
	[self matchRecentsForQuery:_query generation:_generation];

	if (!_debouncing)
		return;

	NSInteger generation = _generation;
	NSString *query_ = _query;
	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			TGSearchViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (generation == strongSelf->_generation)
				strongSelf->_debouncing = NO;
			[strongSelf runServerSearch:query_ generation:generation];
		});
}

- (void)rebuildContactKeys {
	NSMutableArray *keys = [NSMutableArray arrayWithCapacity:self.contacts.count];
	for (NSDictionary *u in self.contacts) {
		if (![u isKindOfClass:NSDictionary.class])
			continue;
		NSString *first = [u[@"first_name"] isKindOfClass:NSString.class] ? u[@"first_name"] : @"";
		NSString *last = [u[@"last_name"] isKindOfClass:NSString.class] ? u[@"last_name"] : @"";
		NSString *username = [u[@"username"] isKindOfClass:NSString.class] ? u[@"username"] : @"";
		NSString *name = [[first stringByAppendingString:
				(last.length ? [@" " stringByAppendingString:last] : @"")]
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		if (!name.length)
			name = username;
		if (!name.length)
			continue;
		int64_t userId = [u[@"id"] longLongValue];
		if (!userId)
			continue;
		[keys addObject:@{@"name" : name,
			@"folded" : [name lowercaseString],
			@"foldedUsername" : [username lowercaseString],
			@"firstName" : (first.length ? first : last),
			@"lastName" : (first.length ? last : @""),
			@"userId" : @(userId)}];
	}
	_contactKeys = keys;
}

- (void)rebuildChatKeys {
	NSArray *chats = [TGClient shared].chats;
	if (_chatKeys && chats == _chatKeysBuiltFrom)
		return;
	NSMutableArray *keys = [NSMutableArray arrayWithCapacity:chats.count];
	for (NSDictionary *c in chats) {
		NSString *title = [c[@"title"] isKindOfClass:NSString.class] ? c[@"title"] : nil;
		if (!title.length)
			continue;
		[keys addObject:@{@"title" : title,
			@"folded" : [title lowercaseString],
			@"chatId" : (c[@"id"] ?: @0),
			@"isGroup" : @([c[@"isGroup"] boolValue]),
			@"fileId" : (c[@"photoFileId"] ?: [NSNull null])}];
	}
	_chatKeys = keys;
	_chatKeysBuiltFrom = chats;
}

- (void)setContacts:(NSArray *)contacts {
	_contacts = contacts;
	[self rebuildContactKeys];
}

- (void)runLocalSearch {
	if (!_query.length || _scope != 0 || _scopedChatId ||
		[[self class] isTagQuery:_query]) {
		self.chatHits = @[];
		self.contactHits = @[];
		[self rebuildSections];
		return;
	}

	NSTimeInterval startedAt = TGPerfLogging()
		? [NSDate timeIntervalSinceReferenceDate]
		: 0;
	NSString *needle = [_query lowercaseString];
	[self rebuildChatKeys];

	NSMutableArray *titles = [NSMutableArray array];
	for (NSDictionary *c in _chatKeys) {
		if ([c[@"folded"] rangeOfString:needle].location == NSNotFound)
			continue;
		[titles addObject:@{@"title" : c[@"title"],
			@"subtitle" : @"",
			@"chatId" : c[@"chatId"],
			@"isGroup" : c[@"isGroup"],
			@"fileId" : c[@"fileId"]}];
	}
	self.chatHits = titles;

	NSMutableArray *people = [NSMutableArray array];
	for (NSDictionary *u in _contactKeys) {
		NSString *foldedUsername = u[@"foldedUsername"];
		if ([u[@"folded"] rangeOfString:needle].location == NSNotFound &&
			!(foldedUsername.length &&
				[foldedUsername rangeOfString:needle].location != NSNotFound))
			continue;
		int64_t userId = [u[@"userId"] longLongValue];
		[people addObject:@{@"title" : u[@"name"],
			@"subtitle" : @"",
			@"firstName" : u[@"firstName"],
			@"lastName" : u[@"lastName"],
			@"userId" : u[@"userId"],
			@"chatId" : @0,
			@"isGroup" : @NO,
			@"fileId" : ([[TGClient shared] photoFileIdForUserId:userId] ?: [NSNull null])}];
	}
	self.contactHits = people;
	if (startedAt > 0)
		NSLog(@"PERF local search \"%@\" over %lu chats and %lu contacts in %.1f ms",
			_query, (unsigned long)_chatKeys.count, (unsigned long)_contactKeys.count,
			([NSDate timeIntervalSinceReferenceDate] - startedAt) * 1000.0);

	[self rebuildSections];
}

- (NSArray *)recentRows {
	NSMutableArray *rows = [NSMutableArray array];
	NSMutableSet *seen = [NSMutableSet set];
	for (NSDictionary *r in self.recents) {
		int64_t chatId = [r[@"chatId"] longLongValue];
		NSString *title = [r[@"title"] isKindOfClass:NSString.class] ? r[@"title"] : @"";
		if (!chatId || !title.length || [seen containsObject:@(chatId)])
			continue;
		[seen addObject:@(chatId)];
		[rows addObject:@{@"title" : title,
			@"subtitle" : @"",
			@"chatId" : @(chatId),
			@"isGroup" : @([r[@"isGroup"] boolValue]),
			@"fileId" : ([[TGClient shared] photoFileIdForChat:chatId]
					?: [NSNull null])}];
	}
	for (NSDictionary *r in self.remoteRecents) {
		if (![r isKindOfClass:NSDictionary.class])
			continue;
		int64_t chatId = [r[@"id"] longLongValue];
		NSString *title = [r[@"title"] isKindOfClass:NSString.class] ? r[@"title"] : @"";
		if (!chatId || !title.length || [seen containsObject:@(chatId)])
			continue;
		[seen addObject:@(chatId)];
		[rows addObject:@{@"title" : title,
			@"subtitle" : @"",
			@"chatId" : @(chatId),
			@"isGroup" : @NO,
			@"unknownType" : @YES,
			@"fileId" : ([r[@"photoFileId"] isKindOfClass:NSNumber.class]
					? r[@"photoFileId"]
					: ([[TGClient shared] photoFileIdForChat:chatId]
							  ?: [NSNull null]))}];
	}
	return rows;
}

- (void)matchRecentsForQuery:(NSString *)query generation:(NSUInteger)generation {
	if (!query.length || _scopedChatId || [[self class] isTagQuery:query]) {
		self.recentMatches = @[];
		return;
	}
	NSArray *rows = [self recentRows];
	if (!rows.count) {
		self.recentMatches = @[];
		return;
	}
	NSMutableArray *titles = [NSMutableArray array];
	for (NSDictionary *row in rows)
		[titles addObject:row[@"title"]];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] indexesOfStrings:titles
						 matchingPrefix:query
								  limit:6
							 completion:^(NSArray *indexes) {
								 TGSearchViewController *strongSelf = weakSelf;
								 if (!strongSelf || generation != strongSelf->_generation)
									 return;
								 NSMutableArray *matched = [NSMutableArray array];
								 for (NSNumber *index in indexes) {
									 if (![index isKindOfClass:NSNumber.class])
										 continue;
									 NSInteger i = [index integerValue];
									 if (i < 0 || i >= (NSInteger)rows.count)
										 continue;
									 [matched addObject:rows[i]];
								 }
								 strongSelf.recentMatches = matched;
								 [strongSelf rebuildSections];
							 }];
}

- (NSString *)shortDateFor:(NSNumber *)stamp {
	if (![stamp isKindOfClass:NSNumber.class] || [stamp doubleValue] < 1)
		return @"";
	NSDate *date = [NSDate dateWithTimeIntervalSince1970:[stamp doubleValue]];
	BOOL today = fabs([date timeIntervalSinceNow]) < 12 * 3600;
	int seconds = (int)[stamp doubleValue];
	return today ? [TGDateUtils stringForShortTime:seconds]
				 : [TGDateUtils stringForDayOfMonth:seconds dayOfMonth:NULL];
}

- (NSArray *)rowsForMessages:(NSArray *)messages inChat:(BOOL)inChat {
	NSMutableArray *rows = [NSMutableArray array];
	for (NSDictionary *m in messages) {
		if (![m isKindOfClass:NSDictionary.class])
			continue;
		int64_t chatId = [m[@"chatId"] longLongValue];
		if (!chatId)
			continue;
		NSString *chatTitle = [m[@"chatTitle"] isKindOfClass:NSString.class] ? m[@"chatTitle"] : @"";
		NSString *sender = [m[@"senderName"] isKindOfClass:NSString.class] ? m[@"senderName"] : @"";
		NSString *text = [m[@"text"] isKindOfClass:NSString.class] ? m[@"text"] : @"";
		NSString *title = inChat
			? (sender.length ? sender : (chatTitle.length ? chatTitle : TGL(@"Watch.MessageView.Title", @"Message")))
			: (chatTitle.length ? chatTitle : (sender.length ? sender : TGL(@"ChatList.UnnamedChat", @"Chat")));
		BOOL outgoing = [m[@"outgoing"] boolValue];
		NSString *author = TGSearchResultShowsAuthorLine(chatTitle, sender, outgoing, inChat)
			? (outgoing ? TGL(@"DialogList.You", @"You") : sender)
			: @"";
		[rows addObject:@{@"title" : title,
			@"subtitle" : text,
			@"author" : author,
			@"date" : [self shortDateFor:m[@"date"]],
			@"chatId" : @(chatId),
			@"messageId" : @([m[@"id"] longLongValue]),
			@"isGroup" : @([m[@"isGroup"] boolValue]),
			@"unknownType" : @(m[@"isGroup"] == nil),
			@"fileId" : ([[TGClient shared] photoFileIdForChat:chatId] ?: [NSNull null])}];
	}
	return rows;
}

- (void)appendMessageRows:(NSArray *)rows {
	if (!rows.count)
		return;
	NSInteger start = self.messageHits.count;
	NSMutableArray *all = [NSMutableArray arrayWithArray:self.messageHits];
	[all addObjectsFromArray:rows];
	self.messageHits = all;
	[self centreSnippetsFrom:start generation:_generation];
}

- (void)centreSnippetsFrom:(NSUInteger)start generation:(NSUInteger)generation {
	if (_query.length < 2 || [[self class] isTagQuery:_query])
		return;
	NSInteger end = start + 6;
	if (end > self.messageHits.count)
		end = self.messageHits.count;

	for (NSInteger i = start; i < end; i++) {
		NSDictionary *row = self.messageHits[i];
		NSString *text = [row[@"subtitle"] isKindOfClass:NSString.class] ? row[@"subtitle"] : @"";
		if (text.length < 80)
			continue;
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] positionOfQuote:_query
									inText:text
								completion:^(NSInteger position) {
									TGSearchViewController *strongSelf = weakSelf;
									if (!strongSelf || generation != strongSelf->_generation || position < 40)
										return;
									if (i >= strongSelf.messageHits.count || strongSelf.messageHits[i] != row)
										return;
									NSInteger from = (NSUInteger)position - 20;
									NSString *tail = TGSafeSubstringFromIndex(text, (NSUInteger)from);
									if (tail.length > 140)
										tail = TGSafeSubstringToIndex(tail, 140);
									NSMutableDictionary *updated = [NSMutableDictionary dictionaryWithDictionary:row];
									updated[@"subtitle"] = [@"..." stringByAppendingString:tail];
									NSMutableArray *all = [NSMutableArray arrayWithArray:strongSelf.messageHits];
									all[i] = updated;
									strongSelf.messageHits = all;
									[strongSelf rebuildSections];
								}];
	}
}

- (void)runServerSearch:(NSString *)query generation:(NSUInteger)generation {
	if (generation != _generation)
		return;
	if (![self hasActiveQuery])
		return;

	if (_scopedChatId) {
		_pending = 1;
		[self rebuildSections];
		if ((_tagEmoji.length || _tagCustomEmojiId) && [self scopeIsSavedMessages])
			[self loadTaggedSavedMessagesPage:query generation:generation];
		else
			[self loadChatMessagesPage:query generation:generation];
		return;
	}

	if ([[self class] isTagQuery:query]) {
		_pending = 2;
		[self rebuildSections];
		[self loadTagMessagesPage:query generation:generation];
		[self loadHashtagSuggestions:query generation:generation];
		return;
	}

	if (_scope != 0) {
		_pending = 1;
		[self rebuildSections];
		[self loadGlobalMessagesPage:query generation:generation];
		return;
	}

	BOOL alsoSearchOwnChats = [self localChatListIsShort];
	_pending = alsoSearchOwnChats ? 3 : 2;
	_chatSearchPending = alsoSearchOwnChats ? 2 : 1;
	[self rebuildSections];
	[self loadGlobalMessagesPage:query generation:generation];
	[self searchPublicChats:query generation:generation];
	if (alsoSearchOwnChats)
		[self searchChatsOnServer:query generation:generation];
}

- (void)loadGlobalMessagesPage:(NSString *)query generation:(NSUInteger)generation {
	NSString *offset = _messagesOffset ?: @"";
	__weak typeof(self) weakSelf = self;
	void (^handler)(NSArray *, NSString *) = ^(NSArray *messages, NSString *nextOffset) {
		TGSearchViewController *strongSelf = weakSelf;
		if (!strongSelf || generation != strongSelf->_generation)
			return;
		[strongSelf appendMessageRows:[strongSelf rowsForMessages:messages inChat:NO]];
		strongSelf->_messagesOffset = [nextOffset isKindOfClass:NSString.class] ? nextOffset : @"";
		strongSelf->_loadingMore = NO;
		if (strongSelf->_pending > 0)
			strongSelf->_pending--;
		[strongSelf rebuildSections];
	};

	NSString *chatType = [[self class] chatTypeForIndex:_chatTypeIndex];
	NSInteger minDate = 0;
	if (chatType || minDate || self.archiveOnly) {
		[[TGClient shared] searchMessagesWithQuery:query
											filter:[[self class] filterForScope:_scope]
										  chatType:chatType
										   minDate:minDate
										   maxDate:0
									   archiveOnly:self.archiveOnly
											offset:offset
											 limit:40
										completion:handler];
		return;
	}
	[[TGClient shared] searchMessagesWithQuery:query
										filter:[[self class] filterForScope:_scope]
										offset:offset
									completion:handler];
}

- (void)loadChatMessagesPage:(NSString *)query generation:(NSUInteger)generation {
	int64_t chatId = _scopedChatId;
	__weak typeof(self) weakSelf = self;

	if (query.length && [[TGClient shared] isSecretChat:chatId]) {
		NSString *offset = _messagesOffset ?: @"";
		[[TGClient shared] searchSecretMessagesInChat:chatId
												 query:query
												filter:[[self class] filterForScope:_scope]
												offset:offset
												 limit:40
											completion:^(NSArray *messages, NSString *nextOffset,
												NSInteger totalCount) {
											TGSearchViewController *strongSelf = weakSelf;
											if (!strongSelf || generation != strongSelf->_generation)
												return;
											[strongSelf appendMessageRows:[strongSelf rowsForMessages:messages inChat:YES]];
											strongSelf->_messagesOffset = [nextOffset isKindOfClass:NSString.class]
												? nextOffset
												: @"";
											strongSelf->_messagesFromId = strongSelf->_messagesOffset.length ? 1 : 0;
											strongSelf->_loadingMore = NO;
											if (strongSelf->_pending > 0)
												strongSelf->_pending--;
											[strongSelf rebuildSections];
										}];
		return;
	}

	[[TGClient shared] searchMessagesInChat:chatId
									  query:query
							   senderUserId:_senderUserId
									 filter:[[self class] filterForScope:_scope]
							  fromMessageId:_messagesFromId
									  limit:40
								 completion:^(NSArray *messages, int64_t nextFromMessageId,
									 NSInteger totalCount) {
									 TGSearchViewController *strongSelf = weakSelf;
									 if (!strongSelf || generation != strongSelf->_generation)
										 return;
									 [strongSelf appendMessageRows:[strongSelf rowsForMessages:messages inChat:YES]];
									 strongSelf->_messagesFromId = nextFromMessageId;
									 strongSelf->_loadingMore = NO;
									 if (strongSelf->_pending > 0)
										 strongSelf->_pending--;
									 [strongSelf rebuildSections];
								 }];
}

- (void)loadTagMessagesPage:(NSString *)tag generation:(NSUInteger)generation {
	NSString *offset = _messagesOffset ?: @"";
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] searchPublicMessagesWithTag:tag
											offset:offset
											 limit:40
										completion:^(NSArray *messages, NSString *nextOffset) {
											TGSearchViewController *strongSelf = weakSelf;
											if (!strongSelf || generation != strongSelf->_generation)
												return;
											[strongSelf appendMessageRows:[strongSelf rowsForMessages:messages inChat:NO]];
											strongSelf->_messagesOffset = [nextOffset isKindOfClass:NSString.class] ? nextOffset : @"";
											strongSelf->_loadingMore = NO;
											if (strongSelf->_pending > 0)
												strongSelf->_pending--;
											[strongSelf rebuildSections];
										}];
}

- (void)loadHashtagSuggestions:(NSString *)tag generation:(NSUInteger)generation {
	NSString *prefix = [tag substringFromIndex:1];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] searchHashtagsWithPrefix:prefix limit:10 completion:^(NSArray *hashtags) {
		TGSearchViewController *strongSelf = weakSelf;
		if (!strongSelf || generation != strongSelf->_generation)
			return;
		NSMutableArray *rows = [NSMutableArray array];
		for (id entry in hashtags) {
			NSString *entryString = [entry isKindOfClass:NSString.class] ? entry : nil;
			if (!entryString.length)
				continue;
			[rows addObject:@{@"title" : [@"#" stringByAppendingString:entryString],
				@"subtitle" : @"",
				@"hashtag" : [@"#" stringByAppendingString:entryString],
				@"chatId" : @0,
				@"isGroup" : @NO,
				@"fileId" : [NSNull null]}];
		}
		strongSelf.hashtagHits = rows;
		if (strongSelf->_pending > 0)
			strongSelf->_pending--;
		[strongSelf rebuildSections];
	}];
}

- (void)loadMoreIfPossible {
	if (_loadingMore || _pending > 0 || ![self hasActiveQuery])
		return;
	NSInteger generation = _generation;
	if (_scopedChatId) {
		if (!_messagesFromId)
			return;
		_loadingMore = YES;
		if ((_tagEmoji.length || _tagCustomEmojiId) && [self scopeIsSavedMessages])
			[self loadTaggedSavedMessagesPage:_query generation:generation];
		else
			[self loadChatMessagesPage:_query generation:generation];
		return;
	}
	if (!_messagesOffset.length)
		return;
	_loadingMore = YES;
	if ([[self class] isTagQuery:_query])
		[self loadTagMessagesPage:_query generation:generation];
	else
		[self loadGlobalMessagesPage:_query generation:generation];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell
	forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section >= (NSInteger)self.sections.count)
		return;
	NSDictionary *info = self.sections[indexPath.section];
	if (![info[@"paged"] boolValue])
		return;
	NSArray *rows = info[@"rows"];
	if (indexPath.row >= (NSInteger)rows.count - 3)
		[self loadMoreIfPossible];
}

- (void)searchPublicChats:(NSString *)query generation:(NSUInteger)generation {
	__weak typeof(self) weakSelf = self;
	NSString *type = nil;
	if (_chatTypeIndex == 3)
		type = @"channel";
	TGClient *client = [TGClient shared];
	[client searchPublicChatsWithQuery:query
								  type:type
							completion:^(NSArray *chats) {
								TGSearchViewController *strongSelf = weakSelf;
								if (!strongSelf || generation != strongSelf->_generation)
									return;

								NSMutableSet *known = [NSMutableSet set];
								for (NSDictionary *row in strongSelf.chatHits)
									[known addObject:@([row[@"chatId"] longLongValue])];

								NSMutableArray *rows = [NSMutableArray array];
								for (NSDictionary *chat in chats) {
									if (![chat isKindOfClass:NSDictionary.class])
										continue;
									int64_t chatId = [chat[@"id"] longLongValue];
									NSString *title = [chat[@"title"] isKindOfClass:NSString.class] ? chat[@"title"] : @"";
									if (!chatId || !title.length || [known containsObject:@(chatId)])
										continue;
									if (strongSelf->_chatTypeIndex == 1 && ![chat[@"isPrivate"] boolValue])
										continue;
									if (strongSelf->_chatTypeIndex == 2 && ![chat[@"isGroup"] boolValue])
										continue;
									if (strongSelf->_chatTypeIndex == 3 && ![chat[@"isChannel"] boolValue])
										continue;
									[known addObject:@(chatId)];

									NSString *username = [chat[@"username"] isKindOfClass:NSString.class]
										? chat[@"username"]
										: @"";
									NSInteger members = [chat[@"memberCount"] integerValue];
									NSString *subtitle = username.length
										? [@"@" stringByAppendingString:username]
										: @"";
									if (members > 0) {
										BOOL isChannel = [chat[@"isChannel"] boolValue];
										NSString *count = isChannel
											? TGLPlural(@"Conversation.StatusSubscribers", members,
													@"1 subscriber", @"%d subscribers")
											: TGLPlural(@"Conversation.StatusMembers", members,
													@"1 member", @"%@ members");
										subtitle = subtitle.length
											? [NSString stringWithFormat:@"%@, %@", subtitle, count]
											: count;
									}

									id fileId = [chat[@"photoFileId"] isKindOfClass:NSNumber.class]
										? chat[@"photoFileId"]
										: ([client photoFileIdForChat:chatId] ?: [NSNull null]);
									[rows addObject:@{@"title" : title,
										@"subtitle" : subtitle,
										@"chatId" : @(chatId),
										@"isGroup" : @([chat[@"isGroup"] boolValue] ||
											[chat[@"isChannel"] boolValue]),
										@"fileId" : fileId}];
									if (rows.count >= 8)
										break;
								}

								strongSelf.globalHits = rows;
								if (strongSelf->_chatSearchPending > 0)
									strongSelf->_chatSearchPending--;
								if (strongSelf->_chatSearchPending == 0)
									[strongSelf dedupeGlobalHitsAgainstChatHitsIfBothSearchesFinished];
								if (strongSelf->_pending > 0)
									strongSelf->_pending--;
								[strongSelf rebuildSections];
							}];
}

- (BOOL)localChatListIsShort {
	return [TGClient shared].chats.count < 50;
}

- (void)searchChatsOnServer:(NSString *)query generation:(NSUInteger)generation {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] searchChatsOnServerWithQuery:query limit:20 completion:^(NSArray *chats) {
		TGSearchViewController *strongSelf = weakSelf;
		if (!strongSelf || generation != strongSelf->_generation)
			return;

		NSMutableSet *known = [NSMutableSet set];
		for (NSDictionary *row in strongSelf.chatHits)
			[known addObject:@([row[@"chatId"] longLongValue])];

		NSMutableArray *extra = [NSMutableArray array];
		for (NSDictionary *chat in chats) {
			if (![chat isKindOfClass:NSDictionary.class])
				continue;
			int64_t chatId = [chat[@"id"] longLongValue];
			NSString *title = [chat[@"title"] isKindOfClass:NSString.class] ? chat[@"title"] : @"";
			if (!chatId || !title.length || [known containsObject:@(chatId)])
				continue;
			[known addObject:@(chatId)];
			[extra addObject:@{@"title" : title,
				@"subtitle" : @"",
				@"chatId" : @(chatId),
				@"isGroup" : @([chat[@"isGroup"] boolValue] ||
					[chat[@"isChannel"] boolValue]),
				@"fileId" : ([chat[@"photoFileId"] isKindOfClass:NSNumber.class]
						? chat[@"photoFileId"]
						: [NSNull null])}];
		}
		if (extra.count)
			strongSelf.chatHits = [strongSelf.chatHits arrayByAddingObjectsFromArray:extra];
		if (strongSelf->_chatSearchPending > 0)
			strongSelf->_chatSearchPending--;
		if (strongSelf->_chatSearchPending == 0)
			[strongSelf dedupeGlobalHitsAgainstChatHitsIfBothSearchesFinished];
		if (strongSelf->_pending > 0)
			strongSelf->_pending--;
		[strongSelf rebuildSections];
	}];
}

- (void)dedupeGlobalHitsAgainstChatHitsIfBothSearchesFinished {
	if (!self.globalHits.count || !self.chatHits.count)
		return;
	NSMutableSet *chatHitIds = [NSMutableSet set];
	for (NSDictionary *row in self.chatHits)
		[chatHitIds addObject:@([row[@"chatId"] longLongValue])];
	NSMutableArray *filtered = [NSMutableArray array];
	for (NSDictionary *row in self.globalHits) {
		if ([chatHitIds containsObject:@([row[@"chatId"] longLongValue])])
			continue;
		[filtered addObject:row];
	}
	if (filtered.count != self.globalHits.count)
		self.globalHits = filtered;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	[self cancel];
}

@end

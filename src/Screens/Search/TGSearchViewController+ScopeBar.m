#import "TGTextFieldStyle.h"
#import "TGClient+ChatManagement.h"
#import "TGDateUtils.h"
#import "TGSearchViewController.h"
#import "TGSearchViewControllerInternal.h"
#import "TGActionSheet.h"
#import "TGActionSheetIndexBuilder.h"
#import "TGSearchCalendarViewController.h"
#import "TGSearchResultCell.h"
#import "TGSearchMessageCell.h"
#import "AppDelegate.h"
#import "TGImageDecode.h"
#import "TGClient+Search.h"
#import "TGClient+SavedMessages.h"
#import "TGClient+Groups.h"
#import "TGCustomEmojiCache.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+SafeTint.h"
#import "UIButton+TGScopeButtonStyle.h"
#import "TGFlattenSavedMessages.h"

@implementation TGSearchViewController (ScopeBar)

#pragma mark - scope bar

- (void)buildScopeBar {
	CGFloat width = self.view.bounds.size.width;
	if (width < 1)
		width = [UIScreen mainScreen].applicationFrame.size.width;

	self.scopeBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, kSearchScopeHeight)];
	self.scopeBar.clipsToBounds = YES;
	UIColor *plate = [UIColor colorWithRed:0xc3 / 255.0f green:0xcb / 255.0f blue:0xd4 / 255.0f alpha:1.0f];
	self.scopeBar.backgroundColor = plate;

	UIImage *background = [UIImage imageNamed:@"SearchBarScopeBarBackground.png"];
	if (!background)
		background = [UIImage imageNamed:@"SearchBarBackground.png"];
	if (background) {
		UIImageView *backgroundView = [[UIImageView alloc] initWithImage:background];
		backgroundView.frame = CGRectMake(0, 0, width, kSearchScopeHeight);
		backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[self.scopeBar addSubview:backgroundView];
	}

	self.scopeButtons = [NSMutableArray array];
	NSArray *titles = [[self class] scopeTitles];
	for (NSInteger i = 0; i < titles.count; i++) {
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.tag = (NSInteger)i;
		button.titleLabel.font = [UIFont boldSystemFontOfSize:12];
		[button setTitle:titles[i] forState:UIControlStateNormal];
		[button tg_styleAsScopeButtonSelected:(i == 0)];
		[button addTarget:self action:@selector(scopeTapped:)
			forControlEvents:UIControlEventTouchDown];
		[self.scopeBar addSubview:button];
		[self.scopeButtons addObject:button];
	}

	self.scopeDividers = [NSMutableArray array];
	UIImage *dividerLeft = [UIImage imageNamed:@"SearchScopeBarScopeDividerLeft.png"];
	UIImage *dividerRight = [UIImage imageNamed:@"SearchScopeBarScopeDividerRight.png"];
	if (dividerLeft && dividerRight && titles.count > 1) {
		for (NSInteger i = 0; i + 1 < titles.count; i++) {
			UIImageView *divider = [[UIImageView alloc] initWithImage:dividerLeft];
			divider.hidden = YES;
			[self.scopeBar addSubview:divider];
			[self.scopeDividers addObject:divider];
		}
	}

	self.scopeChatButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.scopeChatButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
	self.scopeChatButton.hidden = YES;
	[self.scopeChatButton tg_styleAsScopeButtonSelected:YES];
	[self.scopeChatButton addTarget:self action:@selector(leaveChatScope)
				   forControlEvents:UIControlEventTouchDown];
	[self.scopeBar addSubview:self.scopeChatButton];

	self.scopeSenderButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.scopeSenderButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
	self.scopeSenderButton.hidden = YES;
	[self.scopeSenderButton setTitle:TGL(@"Search.SenderAnyoneButton", @"From: Anyone") forState:UIControlStateNormal];
	[self.scopeSenderButton tg_styleAsScopeButtonSelected:NO];
	[self.scopeSenderButton addTarget:self action:@selector(showSenderSheet)
					 forControlEvents:UIControlEventTouchDown];
	[self.scopeBar addSubview:self.scopeSenderButton];

	self.tagButtons = [NSMutableArray array];
	self.tagStrip = [[UIScrollView alloc] initWithFrame:
			CGRectMake(0, kSearchScopeHeight, width, kSearchTagStripHeight)];
	self.tagStrip.backgroundColor = [UIColor clearColor];
	self.tagStrip.showsHorizontalScrollIndicator = NO;
	self.tagStrip.showsVerticalScrollIndicator = NO;
	self.tagStrip.hidden = YES;
	[self.scopeBar addSubview:self.tagStrip];

	self.chatTypeButtons = [NSMutableArray array];
	self.chatTypeStrip = [[UIScrollView alloc] initWithFrame:
			CGRectMake(0, kSearchScopeHeight, width, kSearchTagStripHeight)];
	self.chatTypeStrip.backgroundColor = [UIColor clearColor];
	self.chatTypeStrip.showsHorizontalScrollIndicator = NO;
	self.chatTypeStrip.showsVerticalScrollIndicator = NO;
	[self.scopeBar addSubview:self.chatTypeStrip];

	CGFloat chatTypeX = 6;
	NSArray *chatTypeTitles = [[self class] chatTypeTitles];
	for (NSInteger i = 0; i < chatTypeTitles.count; i++) {
		NSString *chatTypeTitle = chatTypeTitles[i];
		UIButton *chatTypeButton = [UIButton buttonWithType:UIButtonTypeCustom];
		chatTypeButton.tag = (NSInteger)i;
		chatTypeButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
		[chatTypeButton setTitle:chatTypeTitle forState:UIControlStateNormal];
		[chatTypeButton tg_styleAsScopeButtonSelected:(i == (NSUInteger)_chatTypeIndex)];
		[chatTypeButton addTarget:self action:@selector(chatTypeTapped:)
				  forControlEvents:UIControlEventTouchUpInside];
		CGSize chatTypeSize = [chatTypeTitle sizeWithFont:chatTypeButton.titleLabel.font];
		CGFloat chatTypeButtonWidth = (CGFloat)(int)chatTypeSize.width + 22;
		chatTypeButton.frame = CGRectMake(chatTypeX, 2, chatTypeButtonWidth, 28);
		[self.chatTypeStrip addSubview:chatTypeButton];
		[self.chatTypeButtons addObject:chatTypeButton];
		chatTypeX += chatTypeButtonWidth + 6;
	}
	self.chatTypeStrip.contentSize = CGSizeMake(chatTypeX, kSearchTagStripHeight);

	self.scopeBar.layer.zPosition = 1;
	[self.tableView addSubview:self.scopeBar];
	[self applyScopeInset];
	[self layoutScopeBar];

	__weak typeof(self) weakSelf = self;
	self.savedTagsObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGSavedMessagesTagsDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf loadSavedTagsIfNeeded];
				}];
	self.savedTagImagesObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGCustomEmojiImagesDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf rebuildTagStrip];
				}];
}

- (void)dealloc {
	if (self.savedTagsObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.savedTagsObserverToken];
	if (self.savedTagImagesObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.savedTagImagesObserverToken];
}

- (CGFloat)scopeBarHeight {
	CGFloat height = kSearchScopeHeight;
	if (!self.tagStrip.hidden)
		height += kSearchTagStripHeight;
	if (!self.chatTypeStrip.hidden)
		height += kSearchTagStripHeight;
	return height;
}

- (void)applyScopeInset {
	CGFloat height = [self scopeBarHeight];
	UIEdgeInsets inset = self.tableView.contentInset;
	if ((int)inset.top == (int)height)
		return;
	BOOL atTop = self.tableView.contentOffset.y <= -inset.top + 1;
	inset.top = height;
	self.tableView.contentInset = inset;
	UIEdgeInsets indicator = self.tableView.scrollIndicatorInsets;
	indicator.top = height;
	self.tableView.scrollIndicatorInsets = indicator;
	if (atTop)
		self.tableView.contentOffset = CGPointMake(0, -height);
}

- (void)positionFloatingViews {
	CGFloat top = self.tableView.contentOffset.y + self.tableView.contentInset.top - [self scopeBarHeight];
	CGRect frame = self.scopeBar.frame;
	frame.origin.y = top;
	frame.size.height = [self scopeBarHeight];
	self.scopeBar.frame = frame;
	if (self.scopeBar.superview == self.tableView &&
		[self.tableView.subviews lastObject] != self.scopeBar)
		[self.tableView bringSubviewToFront:self.scopeBar];

	CGSize size = self.view.bounds.size;
	self.statusLabel.frame = CGRectMake(0,
		self.tableView.contentOffset.y + (CGFloat)(int)(size.height / 3), size.width, 40);
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	[self positionFloatingViews];
}

- (void)layoutScopeBar {
	if (!self.scopeBar)
		return;
	CGFloat width = self.view.bounds.size.width;
	if (width < 1)
		return;

	CGRect barFrame = self.scopeBar.frame;
	if ((int)barFrame.size.width != (int)width) {
		barFrame.size.width = width;
		self.scopeBar.frame = barFrame;
	}
	self.tagStrip.frame = CGRectMake(0, kSearchScopeHeight, width, kSearchTagStripHeight);
	self.chatTypeStrip.frame = CGRectMake(0, kSearchScopeHeight, width, kSearchTagStripHeight);
	self.chatTypeStrip.hidden = (_scopedChatId != 0);
	[self applyScopeInset];
	[self positionFloatingViews];

	if (_scopedChatId) {
		for (UIButton *button in self.scopeButtons)
			button.hidden = YES;
		for (UIImageView *divider in self.scopeDividers)
			divider.hidden = YES;
		self.scopeChatButton.hidden = NO;
		if (_scopedIsGroup) {
			CGFloat half = (CGFloat)(int)((width - 18) / 2);
			self.scopeChatButton.frame = CGRectMake(6, kSearchScopeButtonTop, half,
				kSearchScopeButtonHeight);
			self.scopeSenderButton.hidden = NO;
			self.scopeSenderButton.frame = CGRectMake(6 + half + 6, kSearchScopeButtonTop,
				width - 12 - half - 6, kSearchScopeButtonHeight);
		} else {
			self.scopeSenderButton.hidden = YES;
			self.scopeChatButton.frame = CGRectMake(6, kSearchScopeButtonTop, width - 12,
				kSearchScopeButtonHeight);
		}
		return;
	}

	self.scopeChatButton.hidden = YES;
	self.scopeSenderButton.hidden = YES;
	NSInteger count = self.scopeButtons.count;
	if (!count)
		return;
	CGFloat available = width - 12;
	CGFloat each = (CGFloat)(int)(available / count);
	for (NSInteger i = 0; i < count; i++) {
		UIButton *button = self.scopeButtons[i];
		button.hidden = NO;
		CGFloat buttonWidth = (i == count - 1) ? (available - each * (count - 1)) : each;
		button.frame = CGRectMake(6 + each * i, kSearchScopeButtonTop, buttonWidth,
			kSearchScopeButtonHeight);
	}
	[self updateScopeDividers];
}

- (void)updateScopeDividers {
	if (!self.scopeDividers.count)
		return;
	UIImage *dividerLeft = [UIImage imageNamed:@"SearchScopeBarScopeDividerLeft.png"];
	UIImage *dividerRight = [UIImage imageNamed:@"SearchScopeBarScopeDividerRight.png"];
	for (NSInteger i = 0; i < self.scopeDividers.count; i++) {
		UIImageView *divider = self.scopeDividers[i];
		if (_scopedChatId || i + 1 >= self.scopeButtons.count) {
			divider.hidden = YES;
			continue;
		}
		UIImage *art = nil;
		if (_scope == (NSInteger)i)
			art = dividerLeft;
		else if (_scope == (NSInteger)(i + 1))
			art = dividerRight;
		if (!art) {
			divider.hidden = YES;
			continue;
		}
		UIButton *right = self.scopeButtons[i + 1];
		divider.image = art;
		divider.hidden = NO;
		divider.frame = CGRectMake(right.frame.origin.x - (CGFloat)(int)(art.size.width / 2),
			kSearchScopeButtonTop, art.size.width, kSearchScopeButtonHeight);
		[self.scopeBar bringSubviewToFront:divider];
	}
}

- (void)scopeTapped:(UIButton *)button {
	if (button.tag == _scope)
		return;
	_scope = button.tag;
	for (UIButton *other in self.scopeButtons)
		[other tg_styleAsScopeButtonSelected:(other.tag == _scope)];
	[self updateScopeDividers];
	[self layoutScopeBar];
	[self restartSearch];
}

- (void)chatTypeTapped:(UIButton *)button {
	if (button.tag == _chatTypeIndex)
		return;
	_chatTypeIndex = button.tag;
	for (UIButton *other in self.chatTypeButtons)
		[other tg_styleAsScopeButtonSelected:(other.tag == _chatTypeIndex)];
	[self restartSearch];
}

- (UIActionSheet *)sheetWithTitle:(NSString *)title
						  options:(NSArray *)options
							 kind:(NSInteger)kind {
	_sheetKind = kind;
	NSInteger destructiveButtonIndex, cancelButtonIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:title
					  delegate:self
				   otherTitles:options
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:&destructiveButtonIndex
			 cancelButtonIndex:&cancelButtonIndex];
	[self.bar resignFirstResponder];
	[sheet tg_showFromRect:self.scopeSenderButton.bounds inView:self.scopeSenderButton];
	return sheet;
}

- (void)showSenderSheet {
	if (!_scopedChatId || !_scopedIsGroup)
		return;
	if (self.senderCandidates.count) {
		[self presentSenderSheet];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] membersInGroup:_scopedChatId
							   filter:@"recent"
							   offset:0
								limit:20
						   completion:^(NSArray *members, NSInteger totalCount) {
							   TGSearchViewController *strongSelf = weakSelf;
							   if (!strongSelf)
								   return;
							   NSMutableArray *people = [NSMutableArray array];
							   for (NSDictionary *member in members) {
								   if (![member isKindOfClass:NSDictionary.class])
									   continue;
								   int64_t userId = [member[@"id"] longLongValue];
								   NSString *name = [member[@"name"] isKindOfClass:NSString.class]
									   ? member[@"name"]
									   : @"";
								   if (!userId || !name.length)
									   continue;
								   [people addObject:@{@"userId" : @(userId),
									   @"name" : name}];
								   if (people.count >= 12)
									   break;
							   }
							   strongSelf.senderCandidates = people;
							   [strongSelf presentSenderSheet];
						   }];
}

- (void)presentSenderSheet {
	if (!self.senderCandidates.count)
		return;
	NSMutableArray *options = [NSMutableArray arrayWithObject:TGL(@"Search.SenderAnyone", @"Anyone")];
	for (NSDictionary *person in self.senderCandidates)
		[options addObject:person[@"name"]];
	[self sheetWithTitle:TGL(@"Search.SenderSheetTitle", @"From") options:options kind:kSheetSender];
}

- (void)applySender:(int64_t)userId name:(NSString *)name {
	_senderUserId = userId;
	_senderName = userId ? name : nil;
	[self.scopeSenderButton setTitle:(userId
											 ? [TGL(@"Conversation.SearchByName.Prefix", @"From: ") stringByAppendingString:(name ?: @"")]
											 : TGL(@"Search.SenderAnyoneButton", @"From: Anyone"))
							forState:UIControlStateNormal];
	[self.scopeSenderButton tg_styleAsScopeButtonSelected:(userId != 0)];
	[self restartSearch];
}

- (void)updatePlaceholder:(NSString *)placeholder {
	self.bar.placeholder = placeholder;
	[self applyPlaceholderColour];
}

- (void)applyPlaceholderColour {
	TGStyleSearchField(self.searchField);
}

- (void)enterChatScope:(int64_t)chatId title:(NSString *)title isGroup:(BOOL)isGroup {
	_scopedChatId = chatId;
	_scopedChatTitle = title.length ? title : TGL(@"ChatList.UnnamedChat", @"Chat");
	_scopedIsGroup = isGroup;
	_scope = 0;
	for (UIButton *other in self.scopeButtons)
		[other tg_styleAsScopeButtonSelected:(other.tag == _scope)];
	[self updateScopeDividers];
	_tagEmoji = nil;
	_tagCustomEmojiId = 0;
	_senderUserId = 0;
	_senderName = nil;
	self.senderCandidates = @[];
	[self.scopeSenderButton setTitle:TGL(@"Search.SenderAnyoneButton", @"From: Anyone") forState:UIControlStateNormal];
	[self.scopeSenderButton tg_styleAsScopeButtonSelected:NO];
	[self.scopeChatButton setTitle:[TGL(@"Search.ScopeChatPrefix", @"In: ") stringByAppendingString:_scopedChatTitle]
						  forState:UIControlStateNormal];
	[self updatePlaceholder:[TGL(@"Search.SearchInPrefix", @"Search in ") stringByAppendingString:_scopedChatTitle]];
	[self loadSavedTagsIfNeeded];
	[self loadLiveLocations];
	[self layoutScopeBar];
	[self.bar becomeFirstResponder];
	[self restartSearch];
}

- (void)leaveChatScope {
	if (!_scopedChatId)
		return;
	_scopedChatId = 0;
	_scopedChatTitle = nil;
	_scopedIsGroup = NO;
	_tagEmoji = nil;
	_tagCustomEmojiId = 0;
	_senderUserId = 0;
	_senderName = nil;
	self.senderCandidates = @[];
	self.savedTags = nil;
	self.liveLocations = @[];
	[self rebuildTagStrip];
	[self updatePlaceholder:TGL(@"Common.Search", @"Search")];
	[self layoutScopeBar];
	[self restartSearch];
}

- (void)loadLiveLocations {
	self.liveLocations = @[];
	int64_t chatId = _scopedChatId;
	if (!chatId)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] recentLocationMessagesInChat:chatId
											  limit:10
										 completion:^(NSArray *messages) {
											 TGSearchViewController *strongSelf = weakSelf;
											 if (!strongSelf || strongSelf->_scopedChatId != chatId)
												 return;
											 strongSelf.liveLocations = [strongSelf rowsForMessages:messages inChat:YES];
											 if (![strongSelf hasActiveQuery])
												 [strongSelf rebuildSections];
										 }];
}

#pragma mark - jumping to a day

- (void)openCalendarForChat:(int64_t)chatId title:(NSString *)title isGroup:(BOOL)isGroup {
	if (!chatId)
		return;
	TGSearchCalendarViewController *calendar =
		[[TGSearchCalendarViewController alloc] initWithStyle:UITableViewStylePlain];
	calendar.chatId = chatId;
	calendar.chatTitle = title;
	calendar.filterName = (_scopedChatId == chatId)
		? [[self class] filterForScope:_scope]
		: nil;

	NSString *name = title ?: @"";
	__weak typeof(self) weakSelf = self;
	calendar.onPickDate = ^(NSInteger date) {
		TGSearchViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf jumpToDate:date chat:chatId title:name isGroup:isGroup];
	};
	[self.bar resignFirstResponder];
	[self.navigationController pushViewController:calendar animated:YES];
}

- (void)jumpToDate:(NSInteger)date chat:(int64_t)chatId title:(NSString *)title
		   isGroup:(BOOL)isGroup {
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	void (^jump)(int64_t) = ^(int64_t messageId) {
		TGSearchViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf.navigationController popToViewController:strongSelf animated:YES];
		if (!messageId)
			return;
		NSString *label = [TGDateUtils stringForFullDate:(int)date];
		[strongSelf anchorChat:chatId title:title isGroup:isGroup atMessage:messageId label:label];
	};
	[client messageInChat:chatId closestToDate:(date + 86399) completion:jump];
}

- (void)anchorChat:(int64_t)chatId title:(NSString *)title isGroup:(BOOL)isGroup
		 atMessage:(int64_t)messageId
			 label:(NSString *)label {
	if (_scopedChatId != chatId)
		[self enterChatScope:chatId title:title isGroup:isGroup];

	_generation++;
	_pending = 1;
	_debouncing = NO;
	_loadingMore = NO;
	_query = @"";
	self.bar.text = @"";
	self.messageHits = @[];
	self.globalHits = @[];
	self.hashtagHits = @[];
	_messagesOffset = @"";
	_messagesFromId = messageId;
	_dateAnchored = YES;
	_anchorLabel = label;
	[self.bar resignFirstResponder];
	[self rebuildSections];
	[self loadChatMessagesPage:@"" generation:_generation];
}

- (void)restartSearch {
	_generation++;
	_pending = 0;
	_debouncing = NO;
	_loadingMore = NO;
	_dateAnchored = NO;
	_anchorLabel = nil;
	_messagesOffset = @"";
	_messagesFromId = 0;
	self.messageHits = @[];
	self.globalHits = @[];
	self.hashtagHits = @[];
	[self runLocalSearch];
	if (![self hasActiveQuery])
		return;
	[self runServerSearch:_query generation:_generation];
}

#pragma mark - saved messages tags

- (BOOL)scopeIsSavedMessages {
	int64_t saved = [[TGClient shared] savedMessagesChatId];
	return saved != 0 && _scopedChatId == saved;
}

- (void)loadSavedTagsIfNeeded {
	if (![self scopeIsSavedMessages]) {
		self.savedTags = nil;
		[self rebuildTagStrip];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] savedMessagesTagsForTopic:0 completion:^(NSArray *tags) {
		TGSearchViewController *strongSelf = weakSelf;
		if (!strongSelf || ![strongSelf scopeIsSavedMessages])
			return;
		NSMutableArray *clean = [NSMutableArray array];
		for (NSDictionary *entry in tags) {
			if (![entry isKindOfClass:NSDictionary.class])
				continue;
			NSDictionary *tag = [entry[@"tag"] isKindOfClass:NSDictionary.class] ? entry[@"tag"] : nil;
			NSString *emoji = [tag[@"emoji"] isKindOfClass:NSString.class] ? tag[@"emoji"] : nil;
			NSNumber *customEmojiId = emoji.length ? nil : TGSavedTagCustomEmojiId(tag);
			if (!emoji.length && !customEmojiId)
				continue;
			NSString *label = [entry[@"label"] isKindOfClass:NSString.class] ? entry[@"label"] : @"";
			NSNumber *count = [entry[@"count"] isKindOfClass:NSNumber.class] ? entry[@"count"] : @0;
			NSMutableDictionary *cleanEntry = [NSMutableDictionary dictionaryWithDictionary:
					@{@"label" : label, @"count" : count}];
			if (customEmojiId)
				cleanEntry[@"customEmojiId"] = customEmojiId;
			else
				cleanEntry[@"emoji"] = emoji;
			[clean addObject:cleanEntry];
		}
		strongSelf.savedTags = clean;
		[strongSelf rebuildTagStrip];
		[strongSelf layoutScopeBar];
	}];
}

- (void)rebuildTagStrip {
	for (UIButton *button in self.tagButtons)
		[button removeFromSuperview];
	[self.tagButtons removeAllObjects];

	if (!self.savedTags.count) {
		self.tagStrip.hidden = YES;
		[self applyScopeInset];
		[self positionFloatingViews];
		return;
	}

	self.tagStrip.hidden = NO;
	CGFloat x = 6;
	for (NSInteger i = 0; i < self.savedTags.count; i++) {
		NSDictionary *tag = self.savedTags[i];
		NSString *emoji = [tag[@"emoji"] isKindOfClass:NSString.class] ? tag[@"emoji"] : nil;
		NSNumber *customEmojiId = [tag[@"customEmojiId"] isKindOfClass:NSNumber.class] ? tag[@"customEmojiId"] : nil;
		NSString *label = [tag[@"label"] isKindOfClass:NSString.class] ? tag[@"label"] : @"";
		NSString *title = customEmojiId
			? label
			: (label.length ? [NSString stringWithFormat:@"%@ %@", emoji, label] : emoji);
		if ([tag[@"count"] integerValue] > 0)
			title = title.length
				? [NSString stringWithFormat:@"%@ %@", title, tag[@"count"]]
				: [tag[@"count"] stringValue];

		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.tag = (NSInteger)i;
		button.titleLabel.font = [UIFont boldSystemFontOfSize:12];
		[button setTitle:title forState:UIControlStateNormal];
		CGFloat iconWidth = 0;
		if (customEmojiId) {
			UIImage *customImage = TGCustomEmojiCachedImage([customEmojiId longLongValue]);
			if (!customImage)
				TGCustomEmojiRequestImage([customEmojiId longLongValue]);
			[button setImage:customImage forState:UIControlStateNormal];
			iconWidth = customImage ? 20 : 0;
		}
		[button tg_styleAsScopeButtonSelected:[self tagIsSelected:tag]];
		[button addTarget:self action:@selector(tagTapped:)
			forControlEvents:UIControlEventTouchUpInside];
		CGSize size = [title sizeWithFont:button.titleLabel.font];
		CGFloat width = (CGFloat)(int)size.width + 22 + iconWidth;
		button.frame = CGRectMake(x, 2, width, 28);
		[self.tagStrip addSubview:button];
		[self.tagButtons addObject:button];
		x += width + 6;
	}
	self.tagStrip.contentSize = CGSizeMake(x, kSearchTagStripHeight);
	[self applyScopeInset];
	[self positionFloatingViews];
}

- (BOOL)tagIsSelected:(NSDictionary *)tag {
	NSNumber *customEmojiId = [tag[@"customEmojiId"] isKindOfClass:NSNumber.class] ? tag[@"customEmojiId"] : nil;
	if (customEmojiId)
		return _tagCustomEmojiId == [customEmojiId longLongValue];
	return [_tagEmoji isEqualToString:tag[@"emoji"]];
}

- (void)tagTapped:(UIButton *)button {
	if (button.tag >= (NSInteger)self.savedTags.count)
		return;
	NSDictionary *tag = self.savedTags[button.tag];
	NSNumber *customEmojiId = [tag[@"customEmojiId"] isKindOfClass:NSNumber.class] ? tag[@"customEmojiId"] : nil;
	if (customEmojiId) {
		_tagCustomEmojiId = (_tagCustomEmojiId == [customEmojiId longLongValue]) ? 0 : [customEmojiId longLongValue];
		_tagEmoji = nil;
	} else {
		NSString *emoji = tag[@"emoji"];
		_tagEmoji = [_tagEmoji isEqualToString:emoji] ? nil : emoji;
		_tagCustomEmojiId = 0;
	}
	for (UIButton *other in self.tagButtons) {
		NSDictionary *otherTag = self.savedTags[other.tag];
		[other tg_styleAsScopeButtonSelected:[self tagIsSelected:otherTag]];
	}
	[self restartSearch];
}

- (NSArray *)flattenSavedMessages:(NSArray *)messages {
	NSMutableArray *rows = [NSMutableArray array];
	for (NSDictionary *m in messages) {
		if (![m isKindOfClass:NSDictionary.class])
			continue;
		NSString *text = TGSavedPreview(m);
		int64_t chatId = [m[@"chat_id"] longLongValue];
		if (!chatId)
			chatId = _scopedChatId;
		[rows addObject:@{@"chatId" : @(chatId),
			@"chatTitle" : (_scopedChatTitle ?: @""),
			@"senderName" : @"",
			@"text" : text,
			@"date" : (m[@"date"] ?: @0)}];
	}
	return rows;
}

- (void)loadTaggedSavedMessagesPage:(NSString *)query generation:(NSUInteger)generation {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] searchSavedMessagesWithQuery:query
										   tagEmoji:_tagEmoji
								   tagCustomEmojiId:_tagCustomEmojiId
											topicId:0
									  fromMessageId:_messagesFromId
											  limit:40
										 completion:^(NSArray *messages, int64_t nextFromMessageId) {
											 TGSearchViewController *strongSelf = weakSelf;
											 if (!strongSelf || generation != strongSelf->_generation)
												 return;
											 [strongSelf appendMessageRows:[strongSelf rowsForMessages:[strongSelf flattenSavedMessages:messages] inChat:YES]];
											 strongSelf->_messagesFromId = nextFromMessageId;
											 if (messages.count < 40)
												 strongSelf->_messagesFromId = 0;
											 strongSelf->_loadingMore = NO;
											 if (strongSelf->_pending > 0)
												 strongSelf->_pending--;
											 [strongSelf rebuildSections];
										 }];
}

@end

#import "TGClient+Contacts.h"
#import "TGStringTruncation.h"
#import "TGReactionListViewController.h"
#import "TGReactionPickerViewInternal.h"
#import "TGReactionListCell.h"
#import "TGReactionService.h"
#import "TGFileDownloadService.h"
#import "TGUserDisplayNameStore.h"
#import "TGSettingsService.h"
#import "TGProfileService.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGActionSheet.h"
#import "TGSnackbar.h"

@interface TGReactionListViewController () <UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate> {
	int64_t _chatId;
	int64_t _messageId;
	NSArray *_filters;
	NSMutableArray *_rows;
	NSMutableDictionary *_photos;
	NSMutableSet *_photosRequested;
	NSMutableArray *_groupButtons;
	NSMutableArray *_groupSeparators;
	NSString *_nextOffset;
	NSInteger _totalCount;
	NSInteger _selectedFilter;
	NSInteger _generation;
	BOOL _loading;
	BOOL _exhausted;
	BOOL _canDelete;
	BOOL _canReport;
	int64_t _actionSenderId;
	NSString *_actionName;
	UIView *_filterBar;
	UITableView *_tableView;
	UILabel *_statusLabel;
	UIActivityIndicatorView *_spinner;
	id _customEmojiObserverToken;
}

@end

@implementation TGReactionListViewController

- (id)initWithMessage:(int64_t)messageId chatId:(int64_t)chatId chips:(NSArray *)chips {
	self = [super init];
	if (self == nil)
		return nil;

	_messageId = messageId;
	_chatId = chatId;
	_rows = [[NSMutableArray alloc] init];
	_photos = [[NSMutableDictionary alloc] init];
	_photosRequested = [[NSMutableSet alloc] init];
	_nextOffset = nil;
	_selectedFilter = 0;

	NSMutableArray *filters = [[NSMutableArray alloc] init];
	[filters addObject:@""];
	for (id raw in chips) {
		if (![raw isKindOfClass:[NSDictionary class]])
			continue;
		if ([[(NSDictionary *)raw objectForKey:@"custom"] boolValue])
			continue;
		NSString *emoji = [(NSDictionary *)raw objectForKey:@"emoji"];
		if ([emoji isKindOfClass:[NSString class]] && emoji.length > 0 &&
			![filters containsObject:emoji])
			[filters addObject:emoji];
	}
	_filters = filters;

	return self;
}

- (void)dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	if (_customEmojiObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_customEmojiObserverToken];
}

- (void)viewDidLoad {
	[super viewDidLoad];

	__weak typeof(self) weakSelf = self;
	_customEmojiObserverToken = [TGReactionService addCustomEmojiResolvedObserver:^{
		TGReactionListViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		[strongSelf customEmojiResolved];
	}];

	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	self.title = TGL(@"PeerInfo.AllowedReactions.Title", @"Reactions");
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];

	UIButton *done = [TGIcons headerButtonWithTitle:TGL(@"Common.Done", @"Done") bold:YES
											 target:self
											 action:@selector(closePressed)];
	UIBarButtonItem *rightItem = nil;
	if (done != nil)
		rightItem = [[UIBarButtonItem alloc] initWithCustomView:done];
	else
		rightItem = [[UIBarButtonItem alloc]
			initWithBarButtonSystemItem:UIBarButtonSystemItemDone
								 target:self
								 action:@selector(closePressed)];
	self.navigationItem.rightBarButtonItem = rightItem;

	CGRect bounds = self.view.bounds;
	CGFloat top = 0;

	if (_filters.count > 2) {
		_filterBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, kListBarHeight)];
		_filterBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		UIImage *plate = TGReactionStretch(@"Footer.png", 1);
		if (plate != nil)
			_filterBar.backgroundColor = [UIColor colorWithPatternImage:plate];
		else
			_filterBar.backgroundColor = [[TGTheme shared] inputBarColour];
		[self.view addSubview:_filterBar];

		UIView *hairline = [[UIView alloc] initWithFrame:
				CGRectMake(0, kListBarHeight - 1, bounds.size.width, 1)];
		hairline.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		hairline.backgroundColor = [[TGTheme shared] separatorColour];
		[_filterBar addSubview:hairline];

		[self buildFilterButtons];
		top = kListBarHeight;
	}

	_tableView = [[UITableView alloc] initWithFrame:
			CGRectMake(0, top, bounds.size.width, bounds.size.height - top)
											  style:UITableViewStylePlain];
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_tableView.dataSource = self;
	_tableView.delegate = self;
	_tableView.rowHeight = kListRowHeight;
	_tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	_tableView.separatorColor = [[TGTheme shared] separatorColour];
	_tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	[self.view addSubview:_tableView];

	UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(longPressed:)];
	longPress.minimumPressDuration = 0.4;
	[_tableView addGestureRecognizer:longPress];

	_statusLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(0, top + 60, bounds.size.width, 20)];
	_statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_statusLabel.backgroundColor = [UIColor clearColor];
	_statusLabel.textAlignment = NSTextAlignmentCenter;
	_statusLabel.font = [UIFont systemFontOfSize:14];
	_statusLabel.textColor = [[TGTheme shared] secondaryTextColour];
	_statusLabel.hidden = YES;
	[self.view addSubview:_statusLabel];

	_spinner = [[UIActivityIndicatorView alloc]
		initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	_spinner.center = CGPointMake(bounds.size.width / 2, top + 60);
	_spinner.autoresizingMask =
		UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	[self.view addSubview:_spinner];

	[self loadPermissions];
	[self reload];
}

- (void)closePressed {
	if ([self respondsToSelector:@selector(dismissViewControllerAnimated:completion:)])
		[self dismissViewControllerAnimated:YES completion:nil];
	else
		[self dismissModalViewControllerAnimated:YES];
}

#pragma mark filters

- (NSString *)currentFilter {
	if (_selectedFilter <= 0 || _selectedFilter >= (NSInteger)_filters.count)
		return nil;
	NSString *emoji = [_filters objectAtIndex:(NSUInteger)_selectedFilter];
	return emoji.length > 0 ? emoji : nil;
}

- (void)buildFilterButtons {
	_groupButtons = [[NSMutableArray alloc] init];
	_groupSeparators = [[NSMutableArray alloc] init];

	CGFloat width = self.view.bounds.size.width - kListGroupInset * 2;
	CGFloat originY = floorf((kListBarHeight - kListGroupHeight) / 2);

	UIView *group = [[UIView alloc] initWithFrame:
			CGRectMake(kListGroupInset, originY, width, kListGroupHeight)];
	group.autoresizingMask = UIViewAutoresizingFlexibleWidth;

	NSInteger count = (NSInteger)_filters.count;
	CGFloat usable = width - kListSeparatorWidth * (count - 1);
	CGFloat buttonWidth = floorf(usable / MAX(1, count));

	UIColor *shadowColour = [UIColor colorWithRed:0x0e / 255.0f green:0x28 / 255.0f
											 blue:0x4d / 255.0f
											alpha:0.4f];

	CGFloat currentX = 0;
	for (NSInteger i = 0; i < count; i++) {
		CGFloat thisWidth = (i == count - 1) ? (width - currentX) : buttonWidth;
		NSString *value = [_filters objectAtIndex:(NSUInteger)i];

		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.exclusiveTouch = YES;
		button.frame = CGRectMake(currentX, 0, thisWidth, kListGroupHeight);
		button.tag = i;
		[button setTitle:(value.length > 0 ? value : TGL(@"ChatList.Tabs.All", @"All")) forState:UIControlStateNormal];
		button.titleLabel.font = [UIFont boldSystemFontOfSize:12];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
		[button setTitleShadowColor:shadowColour forState:UIControlStateNormal];
		button.titleLabel.shadowOffset = CGSizeMake(0, -1);
		button.adjustsImageWhenHighlighted = NO;
		button.adjustsImageWhenDisabled = NO;
		[button addTarget:self action:@selector(filterPressed:)
			forControlEvents:UIControlEventTouchDown];
		[group addSubview:button];
		[_groupButtons addObject:button];

		currentX += thisWidth;

		if (i + 1 < count) {
			UIView *separator = [[UIView alloc] initWithFrame:
					CGRectMake(currentX, 0, kListSeparatorWidth, kListGroupHeight)];
			UIImage *art = TGReactionStretch(@"ButtonGroupDivider.png", 6);
			if (art != nil) {
				UIImageView *layer = [[UIImageView alloc] initWithImage:art];
				layer.frame = separator.bounds;
				[separator addSubview:layer];
			}
			[group addSubview:separator];
			[_groupSeparators addObject:separator];
			currentX += kListSeparatorWidth;
		}
	}

	[_filterBar addSubview:group];
	[self updateFilterButtons];
}

- (void)updateFilterButtons {
	NSInteger count = _groupButtons.count;
	for (NSInteger i = 0; i < count; i++) {
		UIButton *button = [_groupButtons objectAtIndex:i];
		NSString *normalName = @"ButtonGroupCenter.png";
		NSString *highlightedName = @"ButtonGroupCenter_Highlighted.png";
		int leftCap = 1;
		if (i == 0) {
			normalName = @"ButtonGroupLeft.png";
			highlightedName = @"ButtonGroupLeft_Highlighted.png";
			leftCap = 8;
		} else if (i == count - 1) {
			normalName = @"ButtonGroupRight.png";
			highlightedName = @"ButtonGroupRight_Highlighted.png";
		}

		UIImage *normal = TGReactionStretch(normalName, leftCap);
		UIImage *highlighted = TGReactionStretch(highlightedName, leftCap);
		UIImage *shown = ((NSInteger)i == _selectedFilter) ? highlighted : normal;
		[button setBackgroundImage:shown forState:UIControlStateNormal];
		[button setBackgroundImage:shown forState:UIControlStateHighlighted];
		if (normal == nil)
			button.backgroundColor = ((NSInteger)i == _selectedFilter)
				? [[TGTheme shared] accentColour]
				: [UIColor colorWithWhite:0.62f alpha:1.0f];
	}
}

- (void)filterPressed:(UIButton *)button {
	if (button.tag == _selectedFilter)
		return;
	_selectedFilter = button.tag;
	[self updateFilterButtons];
	[self reload];
}

#pragma mark loading

- (void)loadPermissions {
	__weak TGReactionListViewController *weakSelf = self;
	void (^apply)(BOOL, BOOL) = ^(BOOL canDelete, BOOL canReport) {
		TGReactionListViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		strongSelf->_canDelete = canDelete;
		strongSelf->_canReport = canReport;
	};
	[TGReactionService reactionPermissionsForMessage:_messageId inChat:_chatId completion:apply];
}

- (void)reload {
	_generation++;
	[_rows removeAllObjects];
	_nextOffset = nil;
	_exhausted = NO;
	_totalCount = 0;
	[_tableView reloadData];
	[self loadMore];
}

- (void)customEmojiResolved {
	NSArray *resolved = [TGReactionService resolvedReactorRows:_rows];
	if (resolved == _rows)
		return;
	[_rows setArray:resolved];
	[_tableView reloadData];
}

- (void)loadMore {
	if (_loading || _exhausted)
		return;
	_loading = YES;

	if (_rows.count == 0) {
		_statusLabel.hidden = YES;
		[_spinner startAnimating];
	}

	NSInteger generation = _generation;
	__weak TGReactionListViewController *weakSelf = self;
	[TGReactionService addedReactionsForMessage:_messageId
										 inChat:_chatId
										  emoji:[self currentFilter]
										 offset:_nextOffset
										  limit:kListPageSize
									 completion:^(NSArray *reactors,
										 NSString *nextOffset,
										 NSInteger totalCount) {
										 TGReactionListViewController *strongSelf = weakSelf;
										 if (strongSelf == nil || strongSelf->_generation != generation)
											 return;

										 strongSelf->_loading = NO;
										 [strongSelf->_spinner stopAnimating];

										 for (id raw in reactors) {
											 if ([raw isKindOfClass:[NSDictionary class]])
												 [strongSelf->_rows addObject:raw];
										 }
										 if (totalCount > 0)
											 strongSelf->_totalCount = totalCount;

										 strongSelf->_nextOffset = [nextOffset isKindOfClass:[NSString class]] ? nextOffset : nil;
										 if (strongSelf->_nextOffset.length == 0 || reactors.count == 0)
											 strongSelf->_exhausted = YES;

										 [strongSelf updateTitle];
										 [strongSelf->_tableView reloadData];
										 [strongSelf updateStatus];
										 [strongSelf fetchPhotos];
									 }];
}

- (void)updateTitle {
	NSInteger shown = _totalCount > 0 ? _totalCount : (NSInteger)_rows.count;
	self.title = shown > 0
		? TGLPlural(@"Chat.ContextReactionCount", shown, @"1 reaction", @"%@ reactions")
		: TGL(@"PeerInfo.AllowedReactions.Title", @"Reactions");
}

- (void)updateStatus {
	if (_rows.count > 0) {
		_statusLabel.hidden = YES;
		return;
	}
	_statusLabel.text = TGL(@"ReactionPicker.NobodyHasReactedYet", @"Nobody has reacted yet");
	_statusLabel.hidden = NO;
}

- (void)fetchPhotos {
	__weak TGReactionListViewController *weakSelf = self;
	for (NSDictionary *row in [_rows copy]) {
		int64_t senderId = [[row objectForKey:@"senderId"] longLongValue];
		if (senderId == 0)
			continue;
		NSNumber *key = [NSNumber numberWithLongLong:senderId];
		if ([_photos objectForKey:key] != nil || [_photosRequested containsObject:key])
			continue;

		NSNumber *fileId = senderId > 0
			? [TGSettingsService photoFileIdForUserId:senderId]
			: [TGProfileService photoFileIdForChat:senderId];
		if (![fileId isKindOfClass:[NSNumber class]])
			continue;
		[_photosRequested addObject:key];

		[TGFileDownloadService downloadFile:[fileId longLongValue] completion:^(NSString *path) {
			if (path.length == 0) {
				TGReactionListViewController *strongSelf = weakSelf;
				if (strongSelf != nil)
					[strongSelf->_photosRequested removeObject:key];
				return;
			}
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
				UIImage *thumb = TGDecodeSquareThumbnail(path, kListAvatarSide);
				dispatch_async(dispatch_get_main_queue(), ^{
					TGReactionListViewController *strongSelf = weakSelf;
					if (strongSelf == nil || thumb == nil)
						return;
					[strongSelf->_photos setObject:thumb forKey:key];
					[strongSelf reloadSoon];
				});
			});
		}];
	}
}

- (void)reloadSoon {
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(reloadNow)
											   object:nil];
	[self performSelector:@selector(reloadNow) withObject:nil afterDelay:0.15f];
}

- (void)reloadNow {
	[_tableView reloadData];
}

#pragma mark table

- (NSDictionary *)rowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row < 0 || indexPath.row >= (NSInteger)_rows.count)
		return nil;
	return [_rows objectAtIndex:(NSUInteger)indexPath.row];
}

- (NSString *)nameForRow:(NSDictionary *)row {
	NSString *name = [row objectForKey:@"name"];
	if ([name isKindOfClass:[NSString class]] && name.length > 0)
		return name;

	int64_t senderId = [[row objectForKey:@"senderId"] longLongValue];
	if (senderId > 0) {
		NSString *known = [TGUserDisplayNameStore nameForUserId:senderId];
		if (known.length > 0)
			return known;
	}
	return TGL(@"Reactions.UnknownReactor", @"Unknown");
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)_rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *identifier = @"TGReactionListCell";
	TGReactionListCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
	if (cell == nil)
		cell = [[TGReactionListCell alloc] initWithStyle:UITableViewCellStyleDefault
										 reuseIdentifier:identifier];

	NSDictionary *row = [self rowAtIndexPath:indexPath];
	NSString *name = [self nameForRow:row];
	cell.nameLabel.text = name;

	NSString *emoji = [row objectForKey:@"emoji"];
	cell.emojiLabel.text = [emoji isKindOfClass:[NSString class]] ? emoji : @"";

	int64_t senderId = [[row objectForKey:@"senderId"] longLongValue];
	NSNumber *key = [NSNumber numberWithLongLong:senderId];
	UIImage *photo = [_photos objectForKey:key];
	if (photo == nil)
		photo = [TGIcons avatarWithInitials:[TGSafeFirstCharacter(name) uppercaseString]
									   size:kListAvatarSide
								   colourId:senderId];
	cell.avatarView.image = photo;
	[cell setNeedsLayout];

	if (indexPath.row + 5 >= (NSInteger)_rows.count)
		[self loadMore];

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (!self.onOpenProfile)
		return;
	NSDictionary *row = [self rowAtIndexPath:indexPath];
	if (row == nil)
		return;
	int64_t senderId = [[row objectForKey:@"senderId"] longLongValue];
	if (senderId == 0)
		return;
	NSString *name = [self nameForRow:row];
	UINavigationController *nav = self.navigationController;

	if (senderId < 0) {
		self.onOpenProfile(senderId, 0, name, nav);
		return;
	}

	TGReactionOpenProfileBlock onOpenProfile = self.onOpenProfile;
	[[TGClient shared] privateChatWithUser:senderId completion:^(int64_t chatId) {
		onOpenProfile(chatId, senderId, name, nav);
	}];
}

- (void)longPressed:(UILongPressGestureRecognizer *)recognizer {
	if (recognizer.state != UIGestureRecognizerStateBegan)
		return;
	if (!_canDelete && !_canReport)
		return;

	CGPoint point = [recognizer locationInView:_tableView];
	NSIndexPath *indexPath = [_tableView indexPathForRowAtPoint:point];
	NSDictionary *row = [self rowAtIndexPath:indexPath];
	if (row == nil)
		return;

	int64_t senderId = [[row objectForKey:@"senderId"] longLongValue];
	if (senderId == 0)
		return;

	_actionSenderId = senderId;
	_actionName = [self nameForRow:row];

	NSMutableArray *actions = [[NSMutableArray alloc] init];
	if (_canDelete) {
		[actions addObject:[[TGActionSheetAction alloc]
							   initWithTitle:TGL(@"Chat.AdminActionSheet.DeleteAllReactions", @"Delete Reactions")
									  action:@"delete"
										type:TGActionSheetActionTypeDestructive]];
		[actions addObject:[[TGActionSheetAction alloc]
							   initWithTitle:[NSString stringWithFormat:TGL(@"Chat.AdminActionSheet.DeleteAllSingle", @"Delete All from %@"), _actionName]
									  action:@"deleteAll"
										type:TGActionSheetActionTypeDestructive]];
	}
	if (_canReport) {
		[actions addObject:[[TGActionSheetAction alloc]
							   initWithTitle:TGL(@"ReportPeer.Report", @"Report")
									  action:@"report"]];
	}
	[actions addObject:[[TGActionSheetAction alloc]
						   initWithTitle:TGL(@"Common.Cancel", @"Cancel")
								  action:@"cancel"
									type:TGActionSheetActionTypeCancel]];

	__weak TGReactionListViewController *weakSelf = self;
	void (^handler)(id, NSString *) = ^(id target, NSString *action) {
		TGReactionListViewController *strongSelf = weakSelf;
		if (strongSelf != nil)
			[strongSelf performModerationAction:action];
	};
	TGActionSheet *sheet = [[TGActionSheet alloc]
		initWithTitle:_actionName
			  actions:actions
		  actionBlock:handler
			   target:self];
	[sheet tg_showFromRect:[_tableView cellForRowAtIndexPath:indexPath].frame inView:_tableView];
}

- (void)performModerationAction:(NSString *)action {
	int64_t senderId = _actionSenderId;
	if (senderId == 0)
		return;

	__weak typeof(self) weakSelf = self;
	void (^onModerationResult)(BOOL) = ^(BOOL ok) {
		TGReactionListViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[strongSelf reload];
			[TGSnackbar showInView:strongSelf.view
							   text:TGL(@"Toast.CouldNotModerateReactions", @"Could not complete this action")
							seconds:2
						   onCommit:nil];
			return;
		}
		[strongSelf removeRowsFromSender:senderId];
	};

	if ([action isEqualToString:@"delete"]) {
		[TGReactionService deleteReactionsFromSender:senderId
										   onMessage:_messageId
											  inChat:_chatId
										  completion:onModerationResult];
	} else if ([action isEqualToString:@"deleteAll"]) {
		[TGReactionService deleteAllRecentReactionsFromSender:senderId
														inChat:_chatId
													completion:onModerationResult];
	} else if ([action isEqualToString:@"report"]) {
		[TGReactionService reportReactionsFromSender:senderId
										   onMessage:_messageId
											  inChat:_chatId
										  completion:onModerationResult];
	}
}

- (void)removeRowsFromSender:(int64_t)senderId {
	NSMutableArray *kept = [[NSMutableArray alloc] init];
	for (NSDictionary *row in _rows) {
		if ([[row objectForKey:@"senderId"] longLongValue] != senderId)
			[kept addObject:row];
	}
	NSInteger removed = (NSInteger)_rows.count - (NSInteger)kept.count;
	[_rows setArray:kept];
	if (_totalCount >= removed)
		_totalCount -= removed;
	[self updateTitle];
	[_tableView reloadData];
	[self updateStatus];
}

@end

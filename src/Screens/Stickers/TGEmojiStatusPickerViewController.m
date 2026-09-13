#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGTableReloadCoalescer.h"
#import "TGFriendlyError.h"
#import "TGEmojiStatusPickerViewController.h"
#import "TGClient+Files.h"
#import "TGLocalization.h"
#import "TGClient+Account.h"
#import "TGClient+UserStatus.h"
#import "TGTheme.h"
#import "TGImageDecode.h"
#import "TGPopupMenu.h"

static const CGFloat kThumbSide = 28.0f;

static void TGEmojiStatusComplain(NSString *message) {
	UIAlertView *alert = [UIAlertView alloc];
	alert = [alert initWithTitle:nil
						 message:message
						delegate:nil
			   cancelButtonTitle:TGL(@"Common.OK", @"OK")
			   otherButtonTitles:nil];
	[alert show];
}

@interface TGEmojiStatusPickerViewController ()
@property (nonatomic, strong) TGTableReloadCoalescer *thumbnailReload;
@property (nonatomic, strong) NSArray *icons;
@property (nonatomic, assign) int64_t currentCustomEmojiId;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, strong) NSMutableDictionary *thumbnails;
@property (nonatomic, strong) NSMutableSet *thumbnailsRequested;
@property (nonatomic, assign) CGPoint menuPoint;
@property (nonatomic, strong) id userProfileObserverToken;
@property (nonatomic, assign) BOOL applyingStatus;
@end

@implementation TGEmojiStatusPickerViewController

- (instancetype)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		_icons = [NSArray array];
		_thumbnails = [NSMutableDictionary dictionary];
		_thumbnailsRequested = [NSMutableSet set];
	}
	return self;
}

- (instancetype)initForChat:(int64_t)chatId {
	self = [self init];
	if (self)
		_chatId = chatId;
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"Premium.EmojiStatus", @"Emoji Status");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.rowHeight = 44;
	[self reload];

	__weak typeof(self) weakSelf = self;
	self.userProfileObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGUserProfileDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					TGEmojiStatusPickerViewController *strongSelf = weakSelf;
					if (!strongSelf || strongSelf.chatId)
						return;
					int64_t myUserId = [[TGClient shared].me[@"id"] longLongValue];
					if (!myUserId || [note.userInfo[@"userId"] longLongValue] != myUserId)
						return;
					[strongSelf reload];
				}];
}

- (void)dealloc {
	if (_userProfileObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_userProfileObserverToken];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)applyCurrent:(NSDictionary *)current {
	self.currentCustomEmojiId = [current[@"customEmojiId"] longLongValue];
	__weak typeof(self) weakSelf = self;
	void (^onIcons)(NSArray *) = ^(NSArray *icons) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.icons = [icons isKindOfClass:[NSArray class]] ? icons : @[];
		strongSelf.loaded = YES;
		[strongSelf.tableView reloadData];
	};
	if (self.chatId)
		[[TGClient shared] pickableChatEmojiStatusIconsForChat:self.chatId completion:onIcons];
	else
		[[TGClient shared] pickableEmojiStatusIconsWithCompletion:onIcons];
}

- (void)reload {
	if (self.chatId) {
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] emojiStatusForChat:self.chatId completion:^(NSDictionary *current) {
			__strong typeof(weakSelf) strongSelf = weakSelf;
			if (strongSelf)
				[strongSelf applyCurrent:current];
		}];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] accountInfoWithCompletion:^(NSDictionary *account) {
		int64_t myUserId = [account[@"id"] longLongValue];
		[[TGClient shared] emojiStatusForUser:myUserId completion:^(NSDictionary *current) {
			__strong typeof(weakSelf) strongSelf = weakSelf;
			if (strongSelf)
				[strongSelf applyCurrent:current];
		}];
	}];
}

- (void)fetchThumbnailForIcon:(NSDictionary *)icon {
	NSNumber *thumb = [icon[@"thumbFileId"] isKindOfClass:[NSNumber class]]
		? icon[@"thumbFileId"]
		: nil;
	if (!thumb)
		thumb = [icon[@"stickerFileId"] isKindOfClass:[NSNumber class]]
			? icon[@"stickerFileId"]
			: nil;
	long long fileId = [thumb longLongValue];
	if (fileId <= 0)
		return;
	NSNumber *key = @(fileId);
	if (self.thumbnails[key] || [self.thumbnailsRequested containsObject:key])
		return;
	[self.thumbnailsRequested addObject:key];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] downloadFile:fileId completion:^(NSString *path) {
		if (!path.length)
			return;
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			UIImage *image = TGDecodeSquareThumbnail(path, kThumbSide);
			if (!image)
				return;
			dispatch_async(dispatch_get_main_queue(), ^{
				__strong typeof(weakSelf) strongSelf = weakSelf;
				if (!strongSelf)
					return;
				strongSelf.thumbnails[key] = image;
				if (!strongSelf.thumbnailReload)
					strongSelf.thumbnailReload = [[TGTableReloadCoalescer alloc]
						initWithTableView:strongSelf.tableView];
				[strongSelf.thumbnailReload setNeedsReload];
			});
		});
	}];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return section == 0 ? 1 : (NSInteger)self.icons.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section != 1)
		return nil;
	if (self.chatId)
		return TGL(@"EmojiStatusPicker.ChatFooterBoost",
			@"An emoji status shows beside the chat's name. Setting one needs a high enough boost level.");
	return TGL(@"EmojiStatusPicker.MyFooterPremium",
		@"An emoji status shows beside your name instead of Telegram Premium's usual badge. Setting one needs Telegram Premium.");
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	CGFloat measured = [[TGTheme shared] groupedCommentHeightForText:caption width:tableView.bounds.size.width];
	return TGGroupedFooterHeight(caption, measured);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	if (!caption.length)
		return nil;
	return [[TGTheme shared] groupedCommentViewWithText:caption width:tableView.bounds.size.width];
}

- (void)mark:(BOOL)checked on:(UITableViewCell *)cell {
	cell.textLabel.textColor = checked ? [[TGTheme shared] groupedInfoColour]
									   : [[TGTheme shared] groupedTitleColour];
	cell.accessoryType = checked ? UITableViewCellAccessoryCheckmark
								 : UITableViewCellAccessoryNone;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"status"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"status"];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleDefault;

	cell.imageView.image = nil;

	if (indexPath.section == 0) {
		cell.textLabel.text = TGL(@"EmojiStatusPicker.NoStatus", @"No Status");
		cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
		[self mark:self.currentCustomEmojiId == 0 on:cell];
		return cell;
	}

	NSDictionary *icon = (NSUInteger)indexPath.row < self.icons.count
		? self.icons[(NSUInteger)indexPath.row]
		: nil;
	NSString *glyph = [icon[@"emoji"] isKindOfClass:[NSString class]] ? icon[@"emoji"] : @"";
	cell.textLabel.text = glyph.length ? glyph : @"?";
	cell.textLabel.font = [UIFont systemFontOfSize:28];

	NSNumber *thumb = [icon[@"thumbFileId"] isKindOfClass:[NSNumber class]]
		? icon[@"thumbFileId"]
		: nil;
	if (!thumb)
		thumb = [icon[@"stickerFileId"] isKindOfClass:[NSNumber class]]
			? icon[@"stickerFileId"]
			: nil;
	UIImage *thumbImage = thumb ? self.thumbnails[@([thumb integerValue])] : nil;
	if (thumbImage) {
		cell.imageView.image = thumbImage;
		cell.textLabel.text = @"";
	} else {
		[self fetchThumbnailForIcon:icon];
	}

	int64_t emojiId = [icon[@"customEmojiId"] longLongValue];
	[self mark:emojiId != 0 && emojiId == self.currentCustomEmojiId on:cell];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (!self.loaded || self.applyingStatus)
		return;

	int64_t emojiId = 0;
	if (indexPath.section == 1) {
		NSDictionary *icon = (NSUInteger)indexPath.row < self.icons.count
			? self.icons[(NSUInteger)indexPath.row]
			: nil;
		emojiId = [icon[@"customEmojiId"] longLongValue];
		if (!emojiId)
			return;

		CGRect rect = [tableView rectForRowAtIndexPath:indexPath];
		self.menuPoint = [tableView convertPoint:
				CGPointMake(CGRectGetWidth(rect) / 2, CGRectGetMaxY(rect) - 10)
										  toView:self.navigationController.view];
		[self askExpirationForEmojiId:emojiId];
		return;
	}

	[self applyEmojiId:0 expirationDate:0];
}

- (void)askExpirationForEmojiId:(int64_t)emojiId {
	NSArray *items = @[
		@{@"title" : TGL(@"MessageTimer.Forever", @"Forever")},
		@{@"title" : TGLPlural(@"MessageTimer.Hours", 1, @"%@ hour", @"%@ hours")},
		@{@"title" : TGLPlural(@"MessageTimer.Hours", 2, @"%@ hour", @"%@ hours")},
		@{@"title" : TGLPlural(@"MessageTimer.Hours", 8, @"%@ hour", @"%@ hours")},
		@{@"title" : TGLPlural(@"MessageTimer.Days", 2, @"%@ day", @"%@ days")},
	];
	NSArray *seconds = @[ @0, @(3600), @(2 * 3600), @(8 * 3600), @(2 * 24 * 3600) ];

	__weak typeof(self) weakSelf = self;
	[TGPopupMenu showItems:items atPoint:self.menuPoint inView:self.navigationController.view
				  onChoice:^(NSInteger choice, NSString *title) {
					  TGEmojiStatusPickerViewController *strongSelf = weakSelf;
					  if (!strongSelf || choice < 0 || choice >= (NSInteger)seconds.count)
						  return;
					  NSInteger duration = [seconds[choice] integerValue];
					  int32_t expirationDate = duration > 0
						  ? (int32_t)([[NSDate date] timeIntervalSince1970] + duration)
						  : 0;
					  [strongSelf applyEmojiId:emojiId expirationDate:expirationDate];
				  }];
}

- (void)applyEmojiId:(int64_t)emojiId expirationDate:(int32_t)expirationDate {
	if (self.applyingStatus)
		return;
	self.applyingStatus = YES;
	int64_t previous = self.currentCustomEmojiId;
	self.currentCustomEmojiId = emojiId;
	[self.tableView reloadData];

	__weak typeof(self) weakSelf = self;
	void (^done)(BOOL, NSString *) = ^(BOOL ok, NSString *error) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.applyingStatus = NO;
		if (ok)
			return;
		strongSelf.currentCustomEmojiId = previous;
		[strongSelf.tableView reloadData];
		NSString *fallback = strongSelf.chatId
			? TGL(@"EmojiStatusPicker.ChatRejectedBoost",
				@"Telegram would not take that status. The chat needs a higher boost level.")
			: TGL(@"EmojiStatusPicker.MyRejectedPremium",
				@"Telegram would not take that status. Setting one needs Telegram Premium.");
		TGEmojiStatusComplain(TGFriendlyErrorText(error, fallback));
	};
	TGClient *client = [TGClient shared];
	if (self.chatId)
		[client setChatEmojiStatusCustomEmojiId:emojiId
								 expirationDate:expirationDate
										forChat:self.chatId
									 completion:done];
	else
		[client setMyEmojiStatusCustomEmojiId:emojiId expirationDate:expirationDate completion:done];
}

@end

#import "TGClient+ChatManagement.h"
#import "TGClient+ChatList.h"
#import "TGStringTruncation.h"
#import "TGClient+Contacts.h"
#import "TGForwardPicker.h"
#import "TGHexColour.h"
#import "TGClient+Files.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGAlertView.h"
#import "TGImageDecode.h"
#import "UIView+SafeTint.h"
#import <QuartzCore/QuartzCore.h>

static const CGFloat kChatRowHeight = 73.0f;
static const CGFloat kContactRowHeight = 51.0f;
static const CGFloat kChatAvatar = 56.0f;
static const CGFloat kContactAvatar = 40.0f;
static const CGFloat kToolbarHeight = 44.0f;
static const CGFloat kGroupButtonWidth = 80.0f;
static const CGFloat kGroupSeparatorWidth = 2.0f;
static const CGFloat kGroupButtonHeight = 30.0f;

static NSString *TGForwardWeekdayShort(int wday) {
	if (wday < 0)
		wday = 0;
	if (wday > 6)
		wday = 6;
	if (wday == 0)
		wday = 6;
	else
		wday--;
	NSArray *names = @[
		TGL(@"Weekday.ShortMonday", @"Mon"),
		TGL(@"Weekday.ShortTuesday", @"Tue"),
		TGL(@"Weekday.ShortWednesday", @"Wed"),
		TGL(@"Weekday.ShortThursday", @"Thu"),
		TGL(@"Weekday.ShortFriday", @"Fri"),
		TGL(@"Weekday.ShortSaturday", @"Sat"),
		TGL(@"Weekday.ShortSunday", @"Sun"),
	];
	return names[(NSUInteger)wday];
}

static NSString *TGForwardDateString(NSTimeInterval unix) {
	if (unix <= 0)
		return @"";

	time_t t = (time_t)unix;
	struct tm timeinfo;
	localtime_r(&t, &timeinfo);

	time_t now;
	time(&now);
	struct tm nowinfo;
	localtime_r(&now, &nowinfo);

	if (timeinfo.tm_year != nowinfo.tm_year)
		return [NSString stringWithFormat:@"%d.%02d.%02d", timeinfo.tm_mday,
			timeinfo.tm_mon + 1, timeinfo.tm_year - 100];

	NSInteger dayDiff = timeinfo.tm_yday - nowinfo.tm_yday;
	if (dayDiff == 0)
		return [NSString stringWithFormat:@"%02d:%02d", timeinfo.tm_hour, timeinfo.tm_min];
	if (dayDiff > -7 && dayDiff <= -1)
		return TGForwardWeekdayShort(timeinfo.tm_wday);
	return [NSString stringWithFormat:@"%d.%02d.%02d", timeinfo.tm_mday,
		timeinfo.tm_mon + 1, timeinfo.tm_year - 100];
}

static UIImage *TGForwardStretchImage(NSString *name, int leftCap) {
	UIImage *raw = [UIImage imageNamed:name];
	return [raw stretchableImageWithLeftCapWidth:leftCap topCapHeight:0];
}

static const NSUInteger kFrequentRowLimit = 5;

@interface TGForwardPickerCell : UITableViewCell
@property (nonatomic, strong) UIImageView *avatar;
@property (nonatomic, strong) UILabel *title;
@property (nonatomic, strong) UILabel *titleSecond;
@property (nonatomic, strong) UILabel *preview;
@property (nonatomic, strong) UILabel *date;
@property (nonatomic, strong) UIImageView *groupIcon;
@property (nonatomic, assign) BOOL compact;
@end

@implementation TGForwardPickerCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	_avatar = [[UIImageView alloc] init];
	_avatar.backgroundColor = [UIColor clearColor];
	_avatar.contentMode = UIViewContentModeScaleAspectFill;
	_avatar.clipsToBounds = YES;
	[self.contentView addSubview:_avatar];

	_title = [[TGEmojiLabel alloc] init];
	_title.backgroundColor = [UIColor clearColor];
	_title.textColor = [[TGTheme shared] primaryTextColour];
	_title.highlightedTextColor = [UIColor whiteColor];
	[self.contentView addSubview:_title];

	_titleSecond = [[TGEmojiLabel alloc] init];
	_titleSecond.backgroundColor = [UIColor clearColor];
	_titleSecond.textColor = _title.textColor;
	_titleSecond.highlightedTextColor = [UIColor whiteColor];
	[self.contentView addSubview:_titleSecond];

	_groupIcon = [[UIImageView alloc] init];
	_groupIcon.backgroundColor = [UIColor clearColor];
	_groupIcon.hidden = YES;
	[self.contentView addSubview:_groupIcon];

	_preview = [[TGEmojiLabel alloc] init];
	_preview.backgroundColor = [UIColor clearColor];
	_preview.textColor = [[TGTheme shared] secondaryTextColour];
	_preview.highlightedTextColor = [UIColor whiteColor];
	_preview.lineBreakMode = NSLineBreakByTruncatingTail;
	[self.contentView addSubview:_preview];

	_date = [[UILabel alloc] init];
	_date.backgroundColor = [UIColor clearColor];
	_date.font = [UIFont systemFontOfSize:13];
	_date.textAlignment = NSTextAlignmentRight;
	_date.textColor = [UIColor colorWithRed:0x33 / 255.0f green:0x7a / 255.0f
									   blue:0xcc / 255.0f
									  alpha:1.0f];
	_date.highlightedTextColor = [UIColor whiteColor];
	[self.contentView addSubview:_date];

	self.backgroundView = [[UIImageView alloc] init];
	self.selectedBackgroundView = [[UIImageView alloc] init];

	self.accessoryType = UITableViewCellAccessoryNone;
	self.selectionStyle = UITableViewCellSelectionStyleBlue;
	[self applyStyle];
	return self;
}

- (void)setCompact:(BOOL)compact {
	if (_compact == compact)
		return;
	_compact = compact;
	[self applyStyle];
}

- (void)applyStyle {
	CGFloat retinaPixel = ([UIScreen mainScreen].scale > 1.0f) ? 0.5f : 0.0f;
	if (_compact) {
		self.title.font = [UIFont systemFontOfSize:19];
		self.titleSecond.font = [UIFont boldSystemFontOfSize:19];
		self.title.textColor = [UIColor blackColor];
		self.titleSecond.textColor = [UIColor blackColor];
		self.preview.font = [UIFont systemFontOfSize:13 + retinaPixel];
		self.preview.numberOfLines = 1;
	} else {
		self.title.font = [UIFont boldSystemFontOfSize:16];
		self.titleSecond.font = self.title.font;
		self.title.textColor = [[TGTheme shared] primaryTextColour];
		self.titleSecond.textColor = self.title.textColor;
		self.preview.font = [UIFont systemFontOfSize:14];
		self.preview.numberOfLines = 2;
	}
	self.date.hidden = _compact;

	UIImage *plate = TGForwardStretchImage(_compact ? @"Cell102.png" : @"DialogListCell.png", 1);
	UIImage *platePressed = TGForwardStretchImage(
		_compact ? @"CellHighlighted102.png" : @"DialogListCellHighlighted.png", 1);
	if ([self.backgroundView isKindOfClass:UIImageView.class])
		((UIImageView *)self.backgroundView).image = plate;
	if ([self.selectedBackgroundView isKindOfClass:UIImageView.class])
		((UIImageView *)self.selectedBackgroundView).image = platePressed;
	[self setNeedsLayout];
}

- (void)layoutSubviews {
	[super layoutSubviews];

	CGFloat w = self.contentView.bounds.size.width;
	CGFloat h = self.contentView.bounds.size.height;

	CGRect selected = self.selectedBackgroundView.frame;
	selected.origin.y = -1;
	selected.size.height = self.bounds.size.height + 1;
	self.selectedBackgroundView.frame = selected;

	CGFloat side = _compact ? kContactAvatar : kChatAvatar;
	CGFloat inset = _compact ? 5 : 8;
	_avatar.frame = CGRectMake(inset, inset, side, side);
	_avatar.layer.cornerRadius = _compact ? 4 : 5;

	CGFloat left = _compact ? 54 : 73;
	CGFloat right = _compact ? 5 : 10;
	CGFloat width = w - left - right;
	if (width < 0)
		width = 0;

	if (_compact) {
		_groupIcon.hidden = YES;
		_date.frame = CGRectZero;

		CGFloat titleHeight = _title.font.lineHeight;
		CGFloat subtitleHeight = _preview.font.lineHeight;
		CGFloat titleY;
		if (_preview.text.length == 0) {
			titleY = (CGFloat)(int)((CGFloat)(int)((h - titleHeight) / 2) - 1);
			_preview.frame = CGRectZero;
		} else {
			CGFloat retinaPixel = ([UIScreen mainScreen].scale > 1.0f) ? 0.5f : 0.0f;
			titleY = (CGFloat)(int)((h - titleHeight - subtitleHeight - 1) / 2);
			_preview.frame = CGRectMake(left + 1, titleY + titleHeight + retinaPixel,
				width, subtitleHeight);
		}

		CGFloat firstWidth = width;
		if (_titleSecond.text.length) {
			CGFloat cap = w - left - 5 - 14;
			if (cap < 0)
				cap = 0;
			firstWidth = [_title.text sizeWithFont:_title.font].width;
			if (firstWidth > cap)
				firstWidth = cap;
			CGFloat secondX = left + firstWidth + 4;
			CGFloat secondWidth = w - secondX;
			if (secondWidth < 0)
				secondWidth = 0;
			_titleSecond.frame = CGRectMake(secondX, titleY, secondWidth, titleHeight);
		} else {
			_titleSecond.frame = CGRectZero;
		}
		_title.frame = CGRectMake(left, titleY, firstWidth, titleHeight);
		return;
	}

	_titleSecond.frame = CGRectZero;

	CGFloat dateWidth = (CGFloat)(int)[_date.text sizeWithFont:_date.font].width;
	CGFloat dateX = w - dateWidth - 9;
	_date.frame = CGRectMake(dateX, 9, dateWidth, 15);

	CGFloat iconWidth = 0;
	if (_groupIcon.image) {
		iconWidth = 21;
		_groupIcon.hidden = NO;
		CGSize iconSize = _groupIcon.image.size;
		_groupIcon.frame = CGRectMake(left, 6 + 4, iconSize.width, iconSize.height);
	} else {
		_groupIcon.hidden = YES;
	}

	CGFloat titleWidth = (CGFloat)(int)(dateX - 4 - 73 - 18) - iconWidth;
	if (titleWidth < 0)
		titleWidth = 0;
	_title.frame = CGRectMake(left + iconWidth, 6, titleWidth, 20);

	CGFloat previewWidth = w - 73 - 10 - 16;
	if (previewWidth < 0)
		previewWidth = 0;
	_preview.frame = CGRectMake(left, 29, previewWidth, 40);
}

@end

@interface TGForwardPicker () <UIAlertViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) NSArray *chats;
@property (nonatomic, strong) NSArray *contacts;
@property (nonatomic, strong) NSArray *visibleRows;
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) NSArray *sectionIndices;
@property (nonatomic, strong) NSArray *frequentChatIds;
@property (nonatomic, copy) NSString *chatsQuery;
@property (nonatomic, copy) NSString *contactsQuery;
@property (nonatomic, assign) CGFloat chatsOffset;
@property (nonatomic, assign) CGFloat contactsOffset;
@property (nonatomic, assign) NSInteger mode;
@property (nonatomic, assign) BOOL contactsLoaded;
@property (nonatomic, assign) BOOL picking;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, copy) NSString *query;
@property (nonatomic, strong) NSMutableDictionary *avatars;
@property (nonatomic, strong) NSMutableSet *avatarsRequested;
@property (nonatomic, strong) UIView *emptyContainer;
@property (nonatomic, strong) UIImageView *emptyIcon;
@property (nonatomic, strong) UILabel *emptyTitle;
@property (nonatomic, strong) UILabel *emptyText;
@property (nonatomic, strong) UIView *toolbarContainerView;
@property (nonatomic, strong) NSMutableArray *groupButtons;
@property (nonatomic, strong) NSMutableArray *groupSeparators;
@property (nonatomic, strong) NSMutableArray *pickedChatIds;
@property (nonatomic, strong) NSMutableArray *pickedUserIds;
@property (nonatomic, strong) UIButton *doneButton;

- (NSDictionary *)rowAtIndexPath:(NSIndexPath *)indexPath;
@end

@implementation TGForwardPicker

- (void)viewDidLoad {
	[super viewDidLoad];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	self.title = TGL(@"Conversation.ForwardTitle", @"Forward");
	self.chats = [self orderedChats];
	self.contacts = [NSArray array];
	self.mode = [self.requiredKind isEqualToString:@"user"] ? 1 : 0;
	self.visibleRows = (self.mode == 0) ? self.chats : self.contacts;
	self.query = @"";
	self.chatsQuery = @"";
	self.contactsQuery = @"";
	self.sections = [NSArray array];
	self.frequentChatIds = [NSArray array];
	self.avatars = [[NSMutableDictionary alloc] init];
	self.avatarsRequested = [[NSMutableSet alloc] init];
	self.pickedChatIds = [[NSMutableArray alloc] init];
	self.pickedUserIds = [[NSMutableArray alloc] init];

	__weak typeof(self) weakPicker = self;
	[[TGClient shared] topChatsWithCompletion:^(NSArray *chats) {
		TGForwardPicker *strongSelf = weakPicker;
		if (!strongSelf)
			return;
		NSMutableArray *ids = [NSMutableArray array];
		for (id chat in chats ?: @[]) {
			if (![chat isKindOfClass:NSDictionary.class])
				continue;
			id chatId = ((NSDictionary *)chat)[@"id"];
			if ([chatId isKindOfClass:NSNumber.class] && ids.count < kFrequentRowLimit)
				[ids addObject:chatId];
		}
		strongSelf.frequentChatIds = ids;
		[strongSelf rebuildSections];
		[strongSelf.tableView reloadData];
	}];

	self.tableView.rowHeight = kChatRowHeight;
	self.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	self.tableView.contentInset = UIEdgeInsetsMake(0, 0, kToolbarHeight, 0);
	self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	UIButton *cancel = [TGIcons headerButtonWithTitle:TGL(@"Common.Cancel", @"Cancel") bold:NO
											   target:self
											   action:@selector(cancel)];
	CGRect cancelFrame = cancel.frame;
	if (cancelFrame.size.width < 59)
		cancelFrame.size.width = 59;
	cancel.frame = cancelFrame;
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cancel];

	[self updateDoneButton];

	self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
	self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.searchBar.delegate = self;
	self.searchBar.placeholder = TGL(@"Common.Search", @"Search");
	UIImage *searchBackground = [UIImage imageNamed:@"SearchBarBackground.png"];
	if (searchBackground && [self.searchBar respondsToSelector:@selector(setBackgroundImage:)])
		[self.searchBar setBackgroundImage:searchBackground];
	else
		[self.searchBar tg_setTintColor:[UIColor colorWithWhite:0.68f alpha:1.0f]];
	[self dressSearchField:self.searchBar];
	[self hideStripe:self.searchBar];
	self.tableView.tableHeaderView = self.searchBar;
	self.tableView.tableFooterView = [[UIView alloc] init];

	UIView *background = [[UIView alloc] initWithFrame:self.tableView.bounds];
	background.backgroundColor = [[TGTheme shared] listBackgroundColour];
	background.autoresizingMask =
		UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.tableView.backgroundView = background;

	UIView *overscroll = [[UIView alloc] initWithFrame:
			CGRectMake(0, -480, self.tableView.bounds.size.width, 480)];
	overscroll.backgroundColor = [UIColor colorWithRed:0xe4 / 255.0f green:0xe9 / 255.0f blue:0xf0 / 255.0f alpha:1.0f];
	overscroll.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.tableView addSubview:overscroll];

	[self buildEmptyContainer];

	[self buildToolbar];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] contactsWithCompletion:^(NSArray *users) {
		TGForwardPicker *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.contactsLoaded = YES;
		strongSelf.contacts = [strongSelf sortedContacts:users];
		if (strongSelf.mode == 1)
			[strongSelf refreshRows];
	}];

	if ([TGClient shared].chats.count == 0)
		[[TGClient shared] loadChats];

	[self refreshRows];
}

- (void)hideStripe:(UIView *)view {
	if ([view isKindOfClass:UIImageView.class] && view.frame.size.height == 1)
		view.hidden = YES;
	for (UIView *child in view.subviews)
		[self hideStripe:child];
}

- (void)dressSearchField:(UIView *)view {
	if ([view isKindOfClass:UITextField.class]) {
		UITextField *field = (UITextField *)view;
		[field setBackground:nil];
		field.clipsToBounds = NO;

		UIImage *inputImage = [UIImage imageNamed:@"SearchInputField.png"];
		if (inputImage) {
			int leftCap = (int)(inputImage.size.width / 2);
			inputImage = [inputImage stretchableImageWithLeftCapWidth:leftCap topCapHeight:0];
			UIImageView *inputView = [[UIImageView alloc] initWithFrame:
					CGRectMake(0, ([UIScreen mainScreen].scale > 1.0f) ? 0.5f : 0.0f,
						field.frame.size.width, inputImage.size.height)];
			inputView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
			inputView.image = inputImage;
			[field addSubview:inputView];
			[field sendSubviewToBack:inputView];
		}

		UIImage *icon = [UIImage imageNamed:@"SearchBarIcon.png"];
		if ([field.leftView isKindOfClass:UIImageView.class] && icon) {
			UIImageView *iconView = (UIImageView *)field.leftView;
			iconView.image = icon;
			[iconView sizeToFit];
		}

		SEL clearSelector = NSSelectorFromString([NSString stringWithFormat:@"%sBu%s",
			"clear", "tton"]);
		if ([field respondsToSelector:clearSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
			UIButton *clear = [field performSelector:clearSelector];
#pragma clang diagnostic pop
			if ([clear isKindOfClass:UIButton.class]) {
				[clear setImage:[UIImage imageNamed:@"ClearInput.png"]
					   forState:UIControlStateNormal];
				[clear setImage:[UIImage imageNamed:@"ClearInput_Pressed.png"]
					   forState:UIControlStateHighlighted];
			}
		}
		return;
	}
	for (UIView *child in view.subviews)
		[self dressSearchField:child];
}

- (void)buildEmptyContainer {
	UIView *background = self.tableView.backgroundView;
	if (!background)
		return;

	UIColor *grey = [UIColor colorWithRed:0x8b / 255.0f green:0x97 / 255.0f
									 blue:0xa5 / 255.0f
									alpha:1.0f];

	self.emptyContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 250, 0)];
	self.emptyContainer.backgroundColor = [UIColor clearColor];
	self.emptyContainer.hidden = YES;
	self.emptyContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;

	self.emptyIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"NoMessages.png"]];
	self.emptyIcon.hidden = YES;
	[self.emptyContainer addSubview:self.emptyIcon];

	self.emptyTitle = [[UILabel alloc] init];
	self.emptyTitle.backgroundColor = [UIColor clearColor];
	self.emptyTitle.textColor = grey;
	self.emptyTitle.font = [UIFont boldSystemFontOfSize:15];
	[self.emptyContainer addSubview:self.emptyTitle];

	self.emptyText = [[UILabel alloc] init];
	self.emptyText.backgroundColor = [UIColor clearColor];
	self.emptyText.textColor = grey;
	self.emptyText.font = [UIFont systemFontOfSize:14];
	self.emptyText.textAlignment = NSTextAlignmentCenter;
	self.emptyText.lineBreakMode = NSLineBreakByWordWrapping;
	self.emptyText.numberOfLines = 0;
	[self.emptyContainer addSubview:self.emptyText];

	[background addSubview:self.emptyContainer];
}

- (void)showEmptyTitle:(NSString *)title text:(NSString *)text icon:(BOOL)icon {
	if (!self.emptyContainer)
		return;

	CGFloat titleTop = 0;
	self.emptyIcon.hidden = !(icon && self.emptyIcon.image);
	if (!self.emptyIcon.hidden) {
		CGSize iconSize = self.emptyIcon.image.size;
		self.emptyIcon.frame = CGRectMake((CGFloat)(int)((250 - iconSize.width) / 2), 0,
			iconSize.width, iconSize.height);
		titleTop = iconSize.height + 21;
	}

	self.emptyTitle.text = title;
	[self.emptyTitle sizeToFit];
	CGRect titleFrame = self.emptyTitle.frame;
	titleFrame.origin = CGPointMake((CGFloat)(int)((250 - titleFrame.size.width) / 2), titleTop);
	self.emptyTitle.frame = titleFrame;

	self.emptyText.text = text ?: @"";
	CGSize textSize = [self.emptyText sizeThatFits:CGSizeMake(232, 1000)];
	self.emptyText.frame = CGRectMake((CGFloat)(int)((250 - textSize.width) / 2),
		titleFrame.origin.y + titleFrame.size.height + (text.length ? 8 : 0),
		textSize.width, text.length ? textSize.height : 0);

	CGFloat height = self.emptyText.frame.origin.y + self.emptyText.frame.size.height;
	CGRect bounds = self.tableView.backgroundView.bounds;
	self.emptyContainer.frame = CGRectMake((CGFloat)(int)((bounds.size.width - 250) / 2),
		(CGFloat)(int)((bounds.size.height - height) / 2), 250, height);
	self.emptyContainer.hidden = NO;
}

- (NSArray *)orderedChats {
	NSArray *source = [TGClient shared].chats;
	if (![source isKindOfClass:NSArray.class])
		return [NSArray array];

	NSMutableArray *result = [NSMutableArray arrayWithCapacity:source.count + 1];
	NSMutableArray *saved = [NSMutableArray array];
	int64_t savedId = [[TGClient shared] savedMessagesChatId];
	BOOL groupsOnly = [self.requiredKind isEqualToString:@"group"];
	BOOL channelsOnly = [self.requiredKind isEqualToString:@"channel"];
	for (NSDictionary *chat in source) {
		if (![chat isKindOfClass:NSDictionary.class])
			continue;
		if (groupsOnly && (![chat[@"isGroup"] boolValue] || [chat[@"isChannel"] boolValue]))
			continue;
		if (channelsOnly && ![chat[@"isChannel"] boolValue])
			continue;
		if (savedId != 0 && [chat[@"id"] longLongValue] == savedId)
			[saved addObject:chat];
		else
			[result addObject:chat];
	}
	if (!groupsOnly && saved.count == 0 && savedId != 0)
		[saved addObject:[NSDictionary dictionaryWithObjectsAndKeys:
								 [NSNumber numberWithLongLong:savedId], @"id",
							 TGSavedMessagesTitle(), @"title",
							 [NSNumber numberWithBool:YES], @"isSaved", nil]];
	[result replaceObjectsInRange:NSMakeRange(0, 0)
			 withObjectsFromArray:saved];
	return result;
}

- (NSArray *)sortedContacts:(NSArray *)users {
	if (![users isKindOfClass:NSArray.class])
		return [NSArray array];

	NSMutableArray *clean = [NSMutableArray arrayWithCapacity:users.count];
	for (NSDictionary *user in users) {
		if ([user isKindOfClass:NSDictionary.class] && [user[@"id"] longLongValue] != 0)
			[clean addObject:user];
	}
	[clean sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
		NSString *left = [self titleForContact:a];
		NSString *right = [self titleForContact:b];
		NSComparisonResult order = [left localizedCaseInsensitiveCompare:right];
		if (order != NSOrderedSame)
			return order;
		int64_t leftId = [a[@"id"] longLongValue];
		int64_t rightId = [b[@"id"] longLongValue];
		if (leftId == rightId)
			return NSOrderedSame;
		return (leftId < rightId) ? NSOrderedAscending : NSOrderedDescending;
	}];
	return clean;
}

- (BOOL)row:(NSDictionary *)row matchesQuery:(NSString *)query {
	if (query.length == 0)
		return YES;

	NSMutableArray *fields = [NSMutableArray array];
	[fields addObject:[self titleForRow:row]];
	if (self.mode == 1) {
		NSArray *keys = [NSArray arrayWithObjects:@"first_name", @"last_name",
			@"username", @"phone", nil];
		for (NSString *key in keys) {
			id value = row[key];
			if ([value isKindOfClass:NSString.class])
				[fields addObject:value];
		}
	}
	for (id field in fields) {
		if (![field isKindOfClass:NSString.class] || [field length] == 0)
			continue;
		if ([field rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound)
			return YES;
	}
	return NO;
}

- (void)refreshRows {
	if (self.mode == 0)
		self.chats = [self orderedChats];

	NSArray *source = (self.mode == 0) ? self.chats : self.contacts;
	NSString *query = [self.query stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (query.length == 0) {
		self.visibleRows = source;
	} else {
		NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:source.count];
		for (NSDictionary *row in source) {
			if ([self row:row matchesQuery:query])
				[filtered addObject:row];
		}
		self.visibleRows = filtered;
	}

	[self rebuildSections];

	if (self.visibleRows.count == 0) {
		if (query.length > 0)
			[self showEmptyTitle:TGL(@"ChatList.Search.NoResults", @"No Results") text:@"" icon:NO];
		else if (self.mode == 1)
			[self showEmptyTitle:self.contactsLoaded ? TGL(@"ForwardPicker.YouHaveNoContactsYet", @"You have no contacts yet") : TGL(@"Channel.NotificationLoading", @"Loading…")
							text:self.contactsLoaded
					? TGL(@"ForwardPicker.PeopleFromYourAddressBookWho", @"People from your address book who use Telegram show up here.")
					: @""
							icon:NO];
		else
			[self showEmptyTitle:TGL(@"DialogList.NoMessagesTitle", @"You have no conversations yet")
							text:TGL(@"DialogList.NoMessagesText", @"Start messaging by pressing the pencil button in the top right corner or go to the Contacts section.")
							icon:YES];
	} else {
		self.emptyContainer.hidden = YES;
	}

	[self.tableView reloadData];
	[self fetchMissingAvatars];
}

- (NSArray *)sectionsWithFrequentFirst:(NSArray *)rows {
	NSString *query = [self.query stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (query.length || !self.frequentChatIds.count)
		return [NSArray arrayWithObject:[NSDictionary dictionaryWithObject:rows forKey:@"rows"]];

	NSMutableArray *frequent = [NSMutableArray array];
	for (NSNumber *chatId in self.frequentChatIds) {
		for (NSDictionary *row in rows) {
			if ([row[@"id"] isEqual:chatId]) {
				[frequent addObject:row];
				break;
			}
		}
	}
	if (frequent.count < 2)
		return [NSArray arrayWithObject:[NSDictionary dictionaryWithObject:rows forKey:@"rows"]];

	NSMutableArray *rest = [NSMutableArray arrayWithCapacity:rows.count];
	for (NSDictionary *row in rows)
		if (![frequent containsObject:row])
			[rest addObject:row];

	NSMutableArray *sections = [NSMutableArray array];
	[sections addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			TGL(@"DialogList.SearchSectionRecent", @"Recent"), @"letter", frequent, @"rows", nil]];
	if (rest.count)
		[sections addObject:[NSDictionary dictionaryWithObject:rest forKey:@"rows"]];
	return sections;
}

- (void)rebuildSections {
	NSArray *rows = self.visibleRows ?: [NSArray array];
	if (self.mode == 0 || rows.count == 0) {
		self.sections = rows.count ? [self sectionsWithFrequentFirst:rows] : [NSArray array];
		self.sectionIndices = nil;
		return;
	}

	NSMutableArray *sections = [NSMutableArray array];
	NSMutableArray *indices = [NSMutableArray arrayWithObject:UITableViewIndexSearch];
	NSString *currentLetter = nil;
	NSMutableArray *current = nil;
	for (NSDictionary *row in rows) {
		NSString *name = [self titleForRow:row];
		NSString *letter = name.length
			? [TGSafeFirstCharacter(name) uppercaseString]
			: @"#";
		unichar first = [letter characterAtIndex:0];
		if (!((first >= 'A' && first <= 'Z') || (first >= 0x0410 && first <= 0x042f)))
			letter = @"#";
		if (!currentLetter || ![letter isEqualToString:currentLetter]) {
			currentLetter = letter;
			current = [NSMutableArray array];
			[sections addObject:[NSDictionary dictionaryWithObjectsAndKeys:
										letter, @"letter", current, @"rows", nil]];
			[indices addObject:letter];
		}
		[current addObject:row];
	}

	self.sections = sections;
	self.sectionIndices = indices;
}

- (void)applyArrivedAvatar:(UIImage *)image forFile:(NSNumber *)fileId {
	for (NSIndexPath *path in ([self.tableView indexPathsForVisibleRows] ?: @[])) {
		UITableViewCell *raw = [self.tableView cellForRowAtIndexPath:path];
		if (![raw isKindOfClass:[TGForwardPickerCell class]])
			continue;
		NSDictionary *row = [self rowAtIndexPath:path];
		if (![row[@"photoFileId"] isEqual:fileId])
			continue;
		((TGForwardPickerCell *)raw).avatar.image = image;
	}
}

- (void)fetchMissingAvatars {
	__weak typeof(self) weakSelf = self;
	CGFloat side = (self.mode == 0) ? kChatAvatar : kContactAvatar;
	for (NSDictionary *row in self.visibleRows) {
		NSNumber *fileId = row[@"photoFileId"];
		if (![fileId isKindOfClass:NSNumber.class])
			continue;
		if (self.avatars[fileId] || [self.avatarsRequested containsObject:fileId])
			continue;
		[self.avatarsRequested addObject:fileId];

		[[TGClient shared] downloadFile:[fileId longLongValue] completion:^(NSString *path) {
			TGForwardPicker *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!path) {
				[strongSelf.avatarsRequested removeObject:fileId];
				return;
			}
			dispatch_async(TGImageDecodeQueue(), ^{
				UIImage *image = TGDecodeSquareThumbnail(path, side);
				if (!image)
					image = [UIImage imageWithContentsOfFile:path];
				dispatch_async(dispatch_get_main_queue(), ^{
					TGForwardPicker *innerSelf = weakSelf;
					if (!innerSelf || !image)
						return;
					innerSelf.avatars[fileId] = image;
					[innerSelf applyArrivedAvatar:image forFile:fileId];
				});
			});
		}];
	}
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)text {
	self.query = text ?: @"";
	[self refreshRows];
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
	self.query = @"";
	[searchBar resignFirstResponder];
	[self refreshRows];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	[self.searchBar resignFirstResponder];
}

- (void)buildToolbar {
	CGRect bounds = self.view.bounds;
	_toolbarContainerView = [[UIView alloc] initWithFrame:
			CGRectMake(0, bounds.size.height - kToolbarHeight, bounds.size.width, kToolbarHeight)];
	_toolbarContainerView.autoresizingMask =
		UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

	UIImage *footer = [UIImage imageNamed:@"Footer.png"];
	if (footer)
		_toolbarContainerView.backgroundColor = [UIColor colorWithPatternImage:footer];
	else
		_toolbarContainerView.backgroundColor = [[TGTheme shared] inputBarColour];

	_groupButtons = [[NSMutableArray alloc] init];
	_groupSeparators = [[NSMutableArray alloc] init];

	NSArray *titles = [NSArray arrayWithObjects:
			TGL(@"Conversation.ForwardChats", @"Chats"),
			TGL(@"Conversation.ForwardContacts", @"Contacts"), nil];
	CGFloat overallWidth = kGroupButtonWidth * titles.count + kGroupSeparatorWidth * (titles.count - 1);
	CGFloat originX = (CGFloat)(int)((bounds.size.width - overallWidth) / 2);
	CGFloat originY = (CGFloat)(int)((kToolbarHeight - kGroupButtonHeight) / 2);

	UIView *group = [[UIView alloc] initWithFrame:
			CGRectMake(originX, originY, overallWidth, kGroupButtonHeight)];
	group.autoresizingMask =
		UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;

	UIColor *shadowColour = [UIColor colorWithRed:0x0e / 255.0f green:0x28 / 255.0f
											 blue:0x4d / 255.0f
											alpha:0.4f];

	CGFloat currentX = 0;
	for (NSInteger i = 0; i < titles.count; i++) {
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.exclusiveTouch = YES;
		button.frame = CGRectMake(currentX, 0, kGroupButtonWidth, kGroupButtonHeight);
		button.tag = (NSInteger)i;
		[button setTitle:[titles objectAtIndex:i] forState:UIControlStateNormal];
		button.titleLabel.font = [UIFont boldSystemFontOfSize:12];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
		[button setTitleShadowColor:shadowColour forState:UIControlStateNormal];
		[button setTitleShadowColor:shadowColour forState:UIControlStateHighlighted];
		[button setTitleShadowColor:shadowColour forState:UIControlStateSelected];
		button.titleLabel.shadowOffset = CGSizeMake(0, -1);
		button.adjustsImageWhenDisabled = NO;
		button.adjustsImageWhenHighlighted = NO;
		[button addTarget:self action:@selector(groupButtonPressed:)
			forControlEvents:UIControlEventTouchDown];
		[group addSubview:button];
		[_groupButtons addObject:button];

		currentX += kGroupButtonWidth;

		if (i + 1 < titles.count) {
			UIView *separator = [[UIView alloc] initWithFrame:
					CGRectMake(currentX, 0, kGroupSeparatorWidth, kGroupButtonHeight)];
			NSArray *names = [NSArray arrayWithObjects:@"ButtonGroupDivider.png",
				@"ButtonGroupDivider_LeftHighlighted.png",
				@"ButtonGroupDivider_RightHighlighted.png", nil];
			for (NSInteger j = 0; j < names.count; j++) {
				UIImageView *layer = [[UIImageView alloc] initWithImage:
						TGForwardStretchImage([names objectAtIndex:j], 6)];
				layer.tag = (NSInteger)(100 + j);
				layer.frame = separator.bounds;
				layer.alpha = (j == 0) ? 1.0f : 0.0f;
				layer.autoresizingMask =
					UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
				[separator addSubview:layer];
			}
			[group addSubview:separator];
			[_groupSeparators addObject:separator];
			currentX += kGroupSeparatorWidth;
		}
	}

	[_toolbarContainerView addSubview:group];
	[self updateGroupImages];
}

- (void)updateGroupImages {
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
			leftCap = 1;
		}

		UIImage *normal = TGForwardStretchImage(normalName, leftCap);
		UIImage *highlighted = TGForwardStretchImage(highlightedName, leftCap);
		UIImage *shown = ((NSInteger)i == self.mode) ? highlighted : normal;
		[button setBackgroundImage:shown forState:UIControlStateNormal];
		[button setBackgroundImage:shown forState:UIControlStateHighlighted];
	}

	for (NSInteger i = 0; i < _groupSeparators.count; i++) {
		UIView *separator = [_groupSeparators objectAtIndex:i];
		UIView *normal = [separator viewWithTag:100];
		UIView *leftLit = [separator viewWithTag:101];
		UIView *rightLit = [separator viewWithTag:102];
		UIView *shown = normal;
		if (self.mode == (NSInteger)i)
			shown = leftLit;
		else if (self.mode == (NSInteger)i + 1)
			shown = rightLit;
		shown.alpha = 1.0f;
		[separator bringSubviewToFront:shown];
		if (normal != shown)
			normal.alpha = 0.0f;
		if (leftLit != shown)
			leftLit.alpha = 0.0f;
		if (rightLit != shown)
			rightLit.alpha = 0.0f;
	}
}

- (void)groupButtonPressed:(UIButton *)button {
	if (self.mode == button.tag)
		return;

	if (self.mode == 0) {
		self.chatsQuery = self.query;
		self.chatsOffset = self.tableView.contentOffset.y;
	} else {
		self.contactsQuery = self.query;
		self.contactsOffset = self.tableView.contentOffset.y;
	}

	self.mode = button.tag;
	self.query = (self.mode == 0) ? self.chatsQuery : self.contactsQuery;
	self.searchBar.text = self.query;
	[self updateGroupImages];
	self.tableView.rowHeight = (self.mode == 0) ? kChatRowHeight : kContactRowHeight;
	[self refreshRows];
	CGFloat offset = (self.mode == 0) ? self.chatsOffset : self.contactsOffset;
	[self.tableView setContentOffset:CGPointMake(0, offset) animated:NO];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if (!self.requiredKind.length) {
		UIView *host = self.navigationController.view ?: self.view;
		CGRect frame = _toolbarContainerView.frame;
		frame.origin.y = host.bounds.size.height - kToolbarHeight;
		frame.size.width = host.bounds.size.width;
		_toolbarContainerView.frame = frame;
		[host addSubview:_toolbarContainerView];
	}
	[self refreshRows];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[_toolbarContainerView removeFromSuperview];
}

- (void)cancel {
	[self.searchBar resignFirstResponder];
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (NSArray *)rows {
	return self.visibleRows ?: [NSArray array];
}

- (NSArray *)rowsInSection:(NSInteger)section {
	if (section < 0 || section >= (NSInteger)self.sections.count)
		return [NSArray array];
	NSArray *rows = [[self.sections objectAtIndex:section] objectForKey:@"rows"];
	return [rows isKindOfClass:NSArray.class] ? rows : [NSArray array];
}

- (NSDictionary *)rowAtIndexPath:(NSIndexPath *)indexPath {
	NSArray *rows = [self rowsInSection:indexPath.section];
	if (indexPath.row < 0 || indexPath.row >= (NSInteger)rows.count)
		return nil;
	NSDictionary *row = [rows objectAtIndex:indexPath.row];
	return [row isKindOfClass:NSDictionary.class] ? row : nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)[self rowsInSection:section].count;
}

- (NSString *)letterForSection:(NSInteger)section {
	if (section < 0 || section >= (NSInteger)self.sections.count)
		return nil;
	NSString *letter = [[self.sections objectAtIndex:section] objectForKey:@"letter"];
	return [letter isKindOfClass:NSString.class] ? letter : nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return [self letterForSection:section] ? 25 : 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *letter = [self letterForSection:section];
	if (!letter)
		return nil;

	UIView *container = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, tableView.bounds.size.width, 25)];
	container.clipsToBounds = NO;
	container.backgroundColor = [UIColor clearColor];

	UIImageView *plate = [[UIImageView alloc] initWithFrame:
			CGRectMake(0, -1, container.bounds.size.width, 26)];
	plate.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	plate.image = [UIImage imageNamed:
			(section == 0) ? @"CategoryDividerFirst.png" : @"CategoryDivider.png"];
	[container addSubview:plate];

	UILabel *label = [[UILabel alloc] init];
	label.font = [UIFont boldSystemFontOfSize:15];
	label.backgroundColor = [UIColor clearColor];
	label.textColor = [UIColor whiteColor];
	label.shadowColor = [UIColor colorWithRed:0x88 / 255.0f green:0x92 / 255.0f
										 blue:0x9c / 255.0f
										alpha:1.0f];
	label.shadowOffset = CGSizeMake(0, -1);
	label.numberOfLines = 1;
	label.text = letter;
	[label sizeToFit];
	label.frame = CGRectOffset(label.frame, 10, 1);
	[container addSubview:label];

	return container;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
	return self.sectionIndices.count > 1 ? self.sectionIndices : nil;
}

- (NSInteger)tableView:(UITableView *)tableView
	sectionForSectionIndexTitle:(NSString *)title
						atIndex:(NSInteger)index {
	if (index == 0) {
		[tableView setContentOffset:CGPointMake(0, -tableView.contentInset.top) animated:NO];
		return -1;
	}
	NSInteger found = [self.sectionIndices indexOfObject:title];
	if (found == NSNotFound)
		return -1;
	return (NSInteger)found - 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return (self.mode == 0) ? kChatRowHeight : kContactRowHeight;
}

- (NSString *)titleForRow:(NSDictionary *)row {
	if (self.mode == 0) {
		int64_t savedId = [[TGClient shared] savedMessagesChatId];
		if (savedId != 0 && [row[@"id"] longLongValue] == savedId)
			return TGSavedMessagesTitle();
		NSString *title = row[@"title"];
		return [title isKindOfClass:NSString.class] && title.length ? title : TGL(@"ChatList.UnnamedChat", @"Chat");
	}
	return [self titleForContact:row];
}

- (NSString *)titleForContact:(NSDictionary *)row {
	NSString *first = [row[@"first_name"] isKindOfClass:NSString.class] ? row[@"first_name"] : @"";
	NSString *last = [row[@"last_name"] isKindOfClass:NSString.class] ? row[@"last_name"] : @"";
	if (first.length == 0 && last.length == 0) {
		NSString *username = row[@"username"];
		if ([username isKindOfClass:NSString.class] && username.length)
			return [NSString stringWithFormat:@"@%@", username];
		NSString *phone = row[@"phone"];
		if ([phone isKindOfClass:NSString.class] && phone.length)
			return phone;
		return TGL(@"Attachment.Contact", @"Contact");
	}
	if (last.length == 0)
		return first;
	if (first.length == 0)
		return last;
	return [NSString stringWithFormat:@"%@ %@", first, last];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *reuse = @"TGForwardCell";
	TGForwardPickerCell *cell = (TGForwardPickerCell *)[tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGForwardPickerCell alloc] initWithStyle:UITableViewCellStyleDefault
										  reuseIdentifier:reuse];

	NSDictionary *row = [self rowAtIndexPath:indexPath];
	NSString *title = row ? [self titleForRow:row] : @"";
	CGFloat side = (self.mode == 0) ? kChatAvatar : kContactAvatar;

	cell.compact = (self.mode == 1);
	cell.title.text = title;
	cell.titleSecond.text = @"";
	cell.date.text = @"";
	cell.groupIcon.image = nil;

	NSString *preview = @"";
	if (self.mode == 0) {
		NSString *text = row[@"text"];
		if ([text isKindOfClass:NSString.class])
			preview = text;
		cell.date.text = TGForwardDateString([row[@"date"] doubleValue]);
		if ([row[@"isGroup"] boolValue])
			cell.groupIcon.image = [UIImage imageNamed:@"DialogListGroupChatIcon.png"];
		cell.preview.textColor = [[TGTheme shared] secondaryTextColour];
	} else {
		NSString *first = [row[@"first_name"] isKindOfClass:NSString.class] ? row[@"first_name"] : @"";
		NSString *last = [row[@"last_name"] isKindOfClass:NSString.class] ? row[@"last_name"] : @"";
		if (first.length && last.length) {
			cell.title.text = first;
			cell.titleSecond.text = last;
		}
		NSString *status = row[@"statusText"];
		if ([status isKindOfClass:NSString.class])
			preview = status;
		BOOL online = [row[@"isOnline"] boolValue];
		cell.preview.textColor = online
			? [[TGTheme shared] accentColour]
			: TGColourFromHex(0x888888);
	}
	cell.preview.text = preview;

	UIImage *photo = nil;
	NSNumber *fileId = row[@"photoFileId"];
	if ([fileId isKindOfClass:NSNumber.class])
		photo = self.avatars[fileId];
	if (!photo && [row[@"isSaved"] boolValue])
		photo = [TGIcons savedMessagesAvatarOfSide:side];
	if (!photo) {
		NSString *initials = title.length ? TGSafeFirstCharacter(title) : @"?";
		photo = [TGIcons avatarWithInitials:initials.uppercaseString
									   size:side
								   colourId:[row[@"id"] longLongValue]];
	}
	cell.avatar.image = photo;
	cell.accessoryType = (self.allowsMultiplePicks && [self isRowPicked:row])
		? UITableViewCellAccessoryCheckmark
		: UITableViewCellAccessoryNone;
	[cell setNeedsLayout];
	return cell;
}

- (NSMutableArray *)pickedListForCurrentMode {
	return (self.mode == 1) ? self.pickedUserIds : self.pickedChatIds;
}

- (BOOL)isRowPicked:(NSDictionary *)row {
	NSNumber *rowId = [row[@"id"] isKindOfClass:NSNumber.class] ? row[@"id"] : nil;
	if (!rowId)
		return NO;
	return [[self pickedListForCurrentMode] containsObject:rowId];
}

- (NSUInteger)pickedCount {
	return self.pickedChatIds.count + self.pickedUserIds.count;
}

- (void)updateDoneButton {
	if (!self.allowsMultiplePicks)
		return;
	NSInteger count = [self pickedCount];
	NSString *title = count
		? [NSString stringWithFormat:
				  TGL(@"ForwardPicker.ForwardCount", @"Forward (%lu)"),
			  (unsigned long)count]
		: TGL(@"Conversation.ForwardTitle", @"Forward");
	self.doneButton = [TGIcons headerButtonWithTitle:title bold:YES
											  target:self
											  action:@selector(finishMultiplePicks)];
	self.doneButton.enabled = (count > 0);
	self.doneButton.alpha = count ? 1.0f : 0.45f;
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:self.doneButton];
}

- (void)togglePickOfRow:(NSDictionary *)row atIndexPath:(NSIndexPath *)indexPath {
	NSNumber *rowId = [row[@"id"] isKindOfClass:NSNumber.class] ? row[@"id"] : nil;
	if (!rowId)
		return;
	NSMutableArray *picked = [self pickedListForCurrentMode];
	if ([picked containsObject:rowId])
		[picked removeObject:rowId];
	else
		[picked addObject:rowId];
	[self updateDoneButton];
	[self.tableView reloadRowsAtIndexPaths:@[ indexPath ]
						  withRowAnimation:UITableViewRowAnimationNone];
}

- (void)finishMultiplePicks {
	if (self.picking || ![self pickedCount])
		return;
	self.picking = YES;
	NSMutableArray *chats = [self.pickedChatIds mutableCopy];
	NSMutableArray *users = [self.pickedUserIds mutableCopy];
	[self resolveContacts:users into:chats];
}

- (void)resolveContacts:(NSMutableArray *)users into:(NSMutableArray *)chats {
	if (!users.count) {
		[self checkSendableChats:chats from:0];
		return;
	}
	NSNumber *next = [users objectAtIndex:0];
	[users removeObjectAtIndex:0];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] privateChatWithUser:[next longLongValue] completion:^(int64_t chatId) {
		TGForwardPicker *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (chatId != 0 && ![chats containsObject:@(chatId)])
			[chats addObject:@(chatId)];
		[strongSelf resolveContacts:users into:chats];
	}];
}

- (NSString *)titleOfChatId:(int64_t)chatId {
	int64_t savedId = [[TGClient shared] savedMessagesChatId];
	if (savedId != 0 && chatId == savedId)
		return TGSavedMessagesTitle();
	for (NSDictionary *row in self.chats) {
		if (![row isKindOfClass:NSDictionary.class] ||
			[row[@"id"] longLongValue] != chatId)
			continue;
		NSString *title = row[@"title"];
		return [title isKindOfClass:NSString.class] ? title : nil;
	}
	return nil;
}

- (void)checkSendableChats:(NSMutableArray *)chats from:(NSUInteger)index {
	if (index >= chats.count) {
		self.picking = NO;
		if (!chats.count) {
			[self showFailure:TGL(@"ForwardPicker.CouldNotOpenChatWithContact",
					@"Could not open a chat with this contact.")];
			return;
		}
		[self finishWithChats:chats];
		return;
	}
	int64_t chatId = [[chats objectAtIndex:index] longLongValue];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] canSendInChat:chatId completion:^(BOOL canSend, BOOL isChannel, NSDictionary *permissions) {
		TGForwardPicker *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSInteger slowModeSecondsRemaining = [permissions[@"slowModeSecondsRemaining"] integerValue];
		if (canSend && slowModeSecondsRemaining <= 0) {
			[strongSelf checkSendableChats:chats from:index + 1];
			return;
		}
		strongSelf.picking = NO;
		NSString *name = [strongSelf titleOfChatId:chatId];
		NSString *where = name.length
			? [NSString stringWithFormat:@"\"%@\"", name]
			: (isChannel
				   ? TGL(@"ForwardPicker.ThatChannel", @"that channel")
				   : TGL(@"ForwardPicker.OneOfTheChatsYouPicked",
						 @"one of the chats you picked"));
		if (canSend && slowModeSecondsRemaining > 0) {
			NSInteger seconds = MAX(slowModeSecondsRemaining, (NSInteger)1);
			[strongSelf showFailure:[NSString stringWithFormat:
										TGL(@"ForwardPicker.SlowModeWaitInChatFormat",
											@"Slow mode is active in %@. Try again in %@"),
									where,
									TGLPlural(@"MessageTimer.Seconds", seconds, @"%ld second", @"%ld seconds")]];
			return;
		}
		[strongSelf showFailure:(isChannel
								? [NSString stringWithFormat:
										  TGL(@"ForwardPicker.CantPostIn",
											  @"You can't post in %@."),
									  where]
								: [NSString stringWithFormat:
										  TGL(@"ForwardPicker.CantSendMessagesIn",
											  @"You can't send messages in %@."),
									  where])];
	}];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	[self.searchBar resignFirstResponder];

	if (self.picking)
		return;

	NSDictionary *row = [self rowAtIndexPath:indexPath];
	if (!row)
		return;

	int64_t rowId = [row[@"id"] longLongValue];
	if (rowId == 0)
		return;

	if (self.allowsMultiplePicks) {
		[self togglePickOfRow:row atIndexPath:indexPath];
		return;
	}

	NSString *title = [self titleForRow:row];
	BOOL quoted = (self.mode == 0) && [row[@"isGroup"] boolValue];
	NSString *message = quoted
		? [NSString stringWithFormat:TGL(@"Chat.ForwardToQuoted", @"Forward to \"%@\"?"), title]
		: [NSString stringWithFormat:TGL(@"Chat.ForwardTo", @"Forward to %@?"), title];

	BOOL isContact = (self.mode == 1);
	__weak typeof(self) weakSelf = self;
	TGAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:nil message:message
			   cancelButtonTitle:TGL(@"Common.No", @"No")
				   okButtonTitle:TGL(@"Common.Yes", @"Yes")
				 completionBlock:^(bool okButtonPressed) {
					 TGForwardPicker *strongSelf = weakSelf;
					 if (!strongSelf || !okButtonPressed)
						 return;
					 if (isContact)
						 [strongSelf resolvePrivateChatForUser:rowId];
					 else
						 [strongSelf confirmSendableChat:rowId];
				 }];
	[alert show];
}

- (void)resolvePrivateChatForUser:(int64_t)userId {
	self.picking = YES;
	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			weakSelf.picking = NO;
		});
	[[TGClient shared] privateChatWithUser:userId completion:^(int64_t chatId) {
		TGForwardPicker *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.picking = NO;
		if (chatId == 0) {
			[strongSelf showFailure:TGL(@"ForwardPicker.CouldNotOpenChatWithContact",
								@"Could not open a chat with this contact.")];
			return;
		}
		[strongSelf finishWithChat:chatId];
	}];
}

- (void)confirmSendableChat:(int64_t)chatId {
	self.picking = YES;
	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			weakSelf.picking = NO;
		});
	[[TGClient shared] canSendInChat:chatId completion:^(BOOL canSend, BOOL isChannel, NSDictionary *permissions) {
		TGForwardPicker *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.picking = NO;
		if (!canSend) {
			[strongSelf showFailure:isChannel
					? TGL(@"ForwardPicker.CantPostInThisChannel",
						  @"You can't post in this channel.")
					: TGL(@"ForwardPicker.CantSendMessagesHere",
						  @"You can't send messages here.")];
			return;
		}
		[strongSelf finishWithChat:chatId];
	}];
}

- (void)finishWithChat:(int64_t)chatId {
	[self finishWithChats:@[ @(chatId) ]];
}

- (void)finishWithChats:(NSArray *)chatIds {
	void (^picked)(NSArray *) = self.onPicked;
	self.onPicked = nil;
	if (picked && chatIds.count)
		picked(chatIds);
	if (self.navigationController.topViewController == self &&
		self.navigationController.viewControllers.count > 1) {
		[self.navigationController popViewControllerAnimated:YES];
		return;
	}
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showFailure:(NSString *)message {
	TGAlertView *alert = [[TGAlertView alloc] initWithTitle:nil message:message
										  cancelButtonTitle:TGL(@"Common.OK", @"OK")
											  okButtonTitle:nil
											completionBlock:nil];
	[alert show];
}

@end

#import "TGTextFieldStyle.h"
#import "TGCacheTrim.h"
#import "TGStringTruncation.h"
#import "TGTopicsViewController.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGChatViewController.h"
#import "TGClient.h"
#import "TGClient+Forums.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGActionSheet.h"
#import "TGPopupMenu.h"
#import "TGDateUtils.h"
#import "TGDateLabel.h"
#import "UIView+SafeTint.h"
#import <QuartzCore/QuartzCore.h>
#import "TGAlertView.h"
#import "TGCustomEmojiCache.h"

#import "TGTopicsViewControllerInternal.h"
#import "TGHexColour.h"

const CGFloat kTopicRowHeight = 73.0f;
const CGFloat kTopicAvatar = 56.0f;
const CGFloat kTopicAvatarLeft = 8.0f;
const CGFloat kTopicTextLeft = 73.0f;
NSMutableDictionary *TGTopicAvatarCache = nil;
static NSMutableArray *TGTopicAvatarOrder = nil;

UIImage *TGTopicBadgeImage(void) {
	static UIImage *normal = nil;
	if (!normal) {
		UIImage *raw = [UIImage imageNamed:@"DialogListUnreadBadge.png"];
		normal = [raw stretchableImageWithLeftCapWidth:(int)(raw.size.width / 2)
										  topCapHeight:(int)(raw.size.height / 2)];
	}
	return normal;
}

UIImage *TGTopicBadgeHighlightedImage(void) {
	static UIImage *highlighted = nil;
	if (!highlighted) {
		UIImage *raw = [UIImage imageNamed:@"DialogListUnreadBadge_Highlighted.png"];
		highlighted = [raw stretchableImageWithLeftCapWidth:(int)(raw.size.width / 2)
											   topCapHeight:(int)(raw.size.height / 2)];
	}
	return highlighted;
}

NSString *TGTopicDate(NSTimeInterval unix) {
	if (unix <= 0)
		return @"";
	return [TGDateUtils stringForMessageListDate:(int)unix] ?: @"";
}

BOOL TGTopicFlag(NSDictionary *topic, NSString *key) {
	id value = [topic isKindOfClass:[NSDictionary class]] ? topic[key] : nil;
	return [value isKindOfClass:[NSNumber class]] && [value boolValue];
}

NSInteger TGTopicInteger(NSDictionary *topic, NSString *key) {
	id value = [topic isKindOfClass:[NSDictionary class]] ? topic[key] : nil;
	return [value isKindOfClass:[NSNumber class]] ? [value integerValue] : 0;
}

long long TGTopicLongLong(NSDictionary *topic, NSString *key) {
	id value = [topic isKindOfClass:[NSDictionary class]] ? topic[key] : nil;
	return [value isKindOfClass:[NSNumber class]] ? [value longLongValue] : 0;
}

double TGTopicDouble(NSDictionary *topic, NSString *key) {
	id value = [topic isKindOfClass:[NSDictionary class]] ? topic[key] : nil;
	return [value isKindOfClass:[NSNumber class]] ? [value doubleValue] : 0;
}

NSString *TGTopicString(NSDictionary *topic, NSString *key) {
	id value = [topic isKindOfClass:[NSDictionary class]] ? topic[key] : nil;
	return [value isKindOfClass:[NSString class]] ? value : @"";
}

NSString *TGTopicInitial(NSString *name) {
	if (!name.length)
		return @"?";
	return [TGSafeFirstCharacter(name) uppercaseString];
}

UIImage *TGTopicPlateImage(void) {
	static UIImage *plate = nil;
	if (!plate)
		plate = [[UIImage imageNamed:@"DialogListCell.png"] stretchableImageWithLeftCapWidth:1 topCapHeight:0];
	return plate;
}

CGFloat TGTopicAvatarCornerRadius(CGFloat side) {
	if (fabs(side - 70) < 0.5f)
		return 9;
	if (fabs(side - 56) < 0.5f)
		return 5;
	if (fabs(side - 40) < 0.5f)
		return 4;
	if (fabs(side - 30) < 0.5f)
		return 3;
	return roundf(side * 0.09f);
}

UIImage *TGTopicDrawAvatar(NSString *initials, CGFloat size, NSInteger rgb) {
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();

	CGRect shapeRect = CGRectMake(0, 0, size, size);
	CGFloat shapeRadius = TGTopicAvatarCornerRadius(size);
	UIBezierPath *shape = [UIBezierPath bezierPathWithRoundedRect:shapeRect cornerRadius:shapeRadius];
	CGContextSetRGBFillColor(ctx,
		((rgb >> 16) & 0xff) / 255.0f,
		((rgb >> 8) & 0xff) / 255.0f,
		(rgb & 0xff) / 255.0f, 1.0f);
	CGContextAddPath(ctx, shape.CGPath);
	CGContextFillPath(ctx);

	CGContextSaveGState(ctx);
	CGContextAddPath(ctx, shape.CGPath);
	CGContextClip(ctx);

	NSString *text = initials.length ? initials : @"?";
	UIFont *font = [UIFont boldSystemFontOfSize:size * 0.4f];
	CGSize textSize = [text sizeWithFont:font];
	[[UIColor whiteColor] set];
	[text drawAtPoint:CGPointMake((size - textSize.width) / 2,
						  (size - textSize.height) / 2)
			 withFont:font];
	CGContextRestoreGState(ctx);

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

void TGTopicFlushAvatarCache(void) {
	[TGTopicAvatarCache removeAllObjects];
	[TGTopicAvatarOrder removeAllObjects];
}

UIImage *TGTopicAvatarImage(NSString *initials, CGFloat size, NSInteger rgb) {
	if (!TGTopicAvatarCache)
		TGTopicAvatarCache = [[NSMutableDictionary alloc] init];
	if (!TGTopicAvatarOrder)
		TGTopicAvatarOrder = [[NSMutableArray alloc] init];

	NSString *letter = initials.length ? initials : @"?";
	NSString *key = [NSString stringWithFormat:@"%ld.%@.%d", (long)rgb, letter, (int)size];
	UIImage *cached = [TGTopicAvatarCache objectForKey:key];
	if (cached)
		return cached;

	UIImage *image = TGTopicDrawAvatar(initials, size, rgb);
	if (image) {
		if (!TGTopicAvatarCache[key])
			[TGTopicAvatarOrder addObject:key];
		NSArray *stale = TGCacheTrimKeys(TGTopicAvatarOrder, 48, 36);
		if (stale.count) {
			[TGTopicAvatarCache removeObjectsForKeys:stale];
			[TGTopicAvatarOrder removeObjectsInArray:stale];
		}
		[TGTopicAvatarCache setObject:image forKey:key];
	}
	return image;
}

const NSInteger kTopicNameAlertEdit = 92;
const NSInteger kTopicDeleteAlert = 93;
const NSInteger kTopicUnpinAllAlert = 94;

@implementation TGTopicsViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];

	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	self.title = TGL(@"ChatList.Search.FilterTopics", @"Topics");
	[self buildTitleView];
	self.topics = @[];
	self.tableView.rowHeight = kTopicRowHeight;
	self.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tableView.separatorColor = [[TGTheme shared] separatorColour];

	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

	[self buildBackgroundView];
	[self buildRefreshControl];
	[self buildSearchBar];

	self.canCreateTopics = YES;
	self.canManageTopics = YES;
	self.canDeleteTopics = YES;
	[self updateCreateButton];
	[self loadRights];

	UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(topicHeld:)];
	[self.tableView addGestureRecognizer:hold];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] forumTopicDefaultIconsWithCompletion:^(NSArray *icons) {
		weakSelf.iconChoices = [icons isKindOfClass:NSArray.class] ? icons : @[];
	}];

	self.themeChangedObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGThemeChangedNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf themeChanged];
				}];

	self.customEmojiObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGCustomEmojiImagesDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf.tableView reloadData];
				}];

	self.forumTopicObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGForumTopicDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf forumTopicChanged:note];
				}];

	[self reloadTopics];
}

- (void)buildBackgroundView {
	UIView *background = [[UIView alloc] initWithFrame:self.tableView.bounds];
	background.backgroundColor = [[TGTheme shared] listBackgroundColour];
	background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

	UIColor *ink = TGColourFromHex(0x8b97a5);

	self.emptyContainer = [[TGPlaceholderView alloc] initWithFrame:CGRectMake(0, 0, 250, 0)];
	self.emptyContainer.userInteractionEnabled = NO;
	self.emptyContainer.hidden = YES;
	[background addSubview:self.emptyContainer];

	self.emptyContainer.iconView.image = [UIImage imageNamed:@"NoMessages.png"];

	self.emptyContainer.titleLabel.font = [UIFont boldSystemFontOfSize:15];
	self.emptyContainer.titleLabel.textColor = ink;
	self.emptyContainer.titleLabel.text = TGL(@"ChatList.EmptyTopicsTitle", @"No Topics Yet");

	self.emptyContainer.bodyLabel.font = [UIFont systemFontOfSize:14];
	self.emptyContainer.bodyLabel.textColor = ink;
	self.emptyContainer.bodyLabel.text = TGL(@"ChatList.EmptyTopicsText", @"Topics keep separate conversations in one group.");

	self.spinner = [[UIActivityIndicatorView alloc]
		initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	self.spinner.center = CGPointMake(background.bounds.size.width / 2.0f, 120);
	self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	self.spinner.hidesWhenStopped = YES;
	[background addSubview:self.spinner];

	self.tableView.backgroundView = background;
}

- (void)buildRefreshControl {
	if ([self respondsToSelector:@selector(setRefreshControl:)] && NSClassFromString(@"UIRefreshControl")) {
		UIRefreshControl *refresh = [[NSClassFromString(@"UIRefreshControl") alloc] init];
		[refresh addTarget:self action:@selector(reloadTopics)
			forControlEvents:UIControlEventValueChanged];
		self.refreshControl = refresh;
	}
}

- (void)buildSearchBar {
	self.searchBar = [[UISearchBar alloc] initWithFrame:
			CGRectMake(0, 0, self.tableView.bounds.size.width, 44)];
	self.searchBar.delegate = self;
	self.searchBar.placeholder = TGL(@"Common.Search", @"Search");
	self.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
	self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self styleSearchBar];
	self.tableView.tableHeaderView = self.searchBar;
}

- (BOOL)usesPlainPlate {
	return YES;
}

- (void)styleSearchBar {
	TGTheme *theme = [TGTheme shared];
	self.searchBar.barStyle = UIBarStyleDefault;
	if ([self.searchBar respondsToSelector:@selector(setBackgroundImage:)]) {
		UIImage *background = [self usesPlainPlate] ? [UIImage imageNamed:@"SearchBarBackground.png"] : nil;
		[self.searchBar setBackgroundImage:background];
	}
	if ([self.searchBar respondsToSelector:@selector(setBarTintColor:)]) {
		self.searchBar.barTintColor = [theme listBackgroundColour];
		[self.searchBar tg_setTintColor:[theme accentColour]];
	} else {
		[self.searchBar tg_setTintColor:[UIColor colorWithWhite:0.68f alpha:1.0f]];
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

		TGStyleSearchField(field);

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
			int leftCap = (int)(inputImage.size.width / 2);
			inputImage = [inputImage stretchableImageWithLeftCapWidth:leftCap topCapHeight:0];
			CGRect inputRect = CGRectMake(0, 0.5f, field.frame.size.width, inputImage.size.height);
			UIImageView *inputImageView = [[UIImageView alloc] initWithFrame:inputRect];
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

- (void)dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (self.themeChangedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.themeChangedObserverToken];
	if (self.customEmojiObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.customEmojiObserverToken];
	if (self.forumTopicObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.forumTopicObserverToken];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	TGTopicFlushAvatarCache();
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if (!self.searchFieldStyled && [self usesPlainPlate]) {
		self.searchFieldStyled = YES;
		[self.searchBar layoutIfNeeded];
		[self styleSearchInputField:self.searchBar];
	}
	if (self.loadedOnce)
		[self reloadTopics];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	if (self.emptyContainer && !self.emptyContainer.hidden)
		[self layoutEmptyContent];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	UIActionSheet *actionSheet = self.currentActionSheet;
	[actionSheet dismissWithClickedButtonIndex:actionSheet.cancelButtonIndex
									  animated:NO];
	self.currentActionSheet = nil;
	[TGPopupMenu dismiss];
}

- (void)buildTitleView {
	TGTheme *theme = [TGTheme shared];
	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 44)];
	header.clipsToBounds = NO;

	UILabel *name = [[TGEmojiLabel alloc] initWithFrame:CGRectMake(0, -2, 200, 19)];
	name.text = self.chatTitle.length ? self.chatTitle : TGL(@"ChatList.Search.FilterTopics", @"Topics");
	name.font = [UIFont boldSystemFontOfSize:16];
	name.textColor = [theme barTitleColour];
	name.backgroundColor = [UIColor clearColor];
	name.textAlignment = NSTextAlignmentCenter;
	name.lineBreakMode = NSLineBreakByTruncatingTail;
	name.shadowColor = TGColourFromHex(0x3d5c81);
	name.shadowOffset = CGSizeMake(0, -1);
	[header addSubview:name];

	self.subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 26, 200, 15)];
	self.subtitleLabel.font = [UIFont boldSystemFontOfSize:12];
	self.subtitleLabel.textColor = TGColourFromHex(0xe0eefd);
	self.subtitleLabel.shadowColor = TGColourFromHex(0x3d5c81);
	self.subtitleLabel.shadowOffset = CGSizeMake(0, -1);
	self.subtitleLabel.backgroundColor = [UIColor clearColor];
	self.subtitleLabel.textAlignment = NSTextAlignmentCenter;
	[header addSubview:self.subtitleLabel];

	self.navigationItem.titleView = header;
}

- (void)updateSubtitle {
	NSInteger count = MAX(self.totalCount, (NSInteger)self.topics.count);
	if (count <= 0)
		self.subtitleLabel.text = @"";
	else if (count == 1)
		self.subtitleLabel.text = TGL(@"Topics.1Topic", @"1 topic");
	else
		self.subtitleLabel.text = [NSString stringWithFormat:TGL(@"Topics.LdTopics", @"%ld topics"), (long)count];
}

- (void)forumTopicChanged:(NSNotification *)note {
	int64_t chatId = [note.userInfo[TGForumTopicChatIdKey] longLongValue];
	if (chatId != self.chatId)
		return;
	[self reloadTopics];
}

- (void)themeChanged {
	TGTheme *theme = [TGTheme shared];
	TGTopicFlushAvatarCache();
	[theme styleNavigationBar:self.navigationController.navigationBar];
	self.tableView.backgroundColor = [theme listBackgroundColour];
	self.tableView.separatorColor = [theme separatorColour];
	self.tableView.backgroundView.backgroundColor = [theme listBackgroundColour];
	[self styleSearchBar];
	[self buildTitleView];
	[self updateSubtitle];
	[self updateEmptyState];
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	[self.tableView reloadData];
}

@end

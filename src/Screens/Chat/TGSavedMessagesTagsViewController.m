#import "TGClient+ChatManagement.h"
#import "TGSavedMessagesTagsViewController.h"
#import "TGLocalization.h"
#import "TGClient.h"
#import "TGClient+SavedMessages.h"
#import "TGClient+Premium.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGDateUtils.h"
#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "TGSnackbar.h"
#import "TGPlaceholderView.h"
#import "TGCustomEmojiCache.h"
#import "TGChatViewController.h"
#import "TGFlattenSavedMessages.h"
#import "TGHexColour.h"

static NSDictionary *TGTagsFlattenMessage(NSDictionary *m) {
	if (![m isKindOfClass:[NSDictionary class]])
		return nil;
	NSString *text = TGSavedPreview(m);
	return @{
		@"id" : m[@"id"] ?: @0,
		@"text" : text,
		@"date" : m[@"date"] ?: @0,
	};
}

static const CGFloat kTagsRowHeight = 51.0f;
static const CGFloat kTagsGlyphSide = 40.0f;
static const CGFloat kTagsTextOrigin = 49.0f;
static const CGFloat kTagsRightInset = 9.0f;
static const CGFloat kTagsBadgeHeight = 21.0f;
static const NSInteger kTagsMessagePageSize = 50;

static CGFloat TGTagsRetinaPixel(void) {
	return [UIScreen mainScreen].scale > 1.0f ? 0.5f : 0.0f;
}

static NSString *TGTagsCountString(NSInteger count) {
	if (count < 1000)
		return [NSString stringWithFormat:@"%d", (int)count];
	if (count < 1000000)
		return [NSString stringWithFormat:@"%dK", (int)(count / 1000)];
	return [NSString stringWithFormat:@"%dM", (int)(count / 1000000)];
}

static UIImage *TGTagsBadgeImage(void) {
	UIImage *image = [UIImage imageNamed:@"DialogListUnreadBadge.png"];
	if (!image)
		return nil;
	return [image stretchableImageWithLeftCapWidth:13 topCapHeight:10];
}

#pragma mark - the messages of one tag

@interface TGSavedMessagesTagFilterController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) NSMutableArray *messages;
@property (nonatomic, copy) NSString *tagTitle;
@property (nonatomic, copy) NSString *tagEmoji;
@property (nonatomic, assign) int64_t tagCustomEmojiId;
@property (nonatomic, assign) int64_t topicId;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, assign) BOOL loadingMore;
@property (nonatomic, assign) BOOL exhausted;
@property (nonatomic, assign) int64_t fromMessageId;

- (instancetype)initWithTagEmoji:(NSString *)emoji topicId:(int64_t)topicId title:(NSString *)title;

- (instancetype)initWithTagCustomEmojiId:(int64_t)customEmojiId topicId:(int64_t)topicId title:(NSString *)title;

@end

@implementation TGSavedMessagesTagFilterController

- (instancetype)initWithTagEmoji:(NSString *)emoji topicId:(int64_t)topicId title:(NSString *)title {
	self = [super initWithNibName:nil bundle:nil];
	if (self) {
		_messages = [NSMutableArray array];
		_tagEmoji = [emoji copy];
		_topicId = topicId;
		_tagTitle = [title copy];
	}
	return self;
}

- (instancetype)initWithTagCustomEmojiId:(int64_t)customEmojiId topicId:(int64_t)topicId title:(NSString *)title {
	self = [super initWithNibName:nil bundle:nil];
	if (self) {
		_messages = [NSMutableArray array];
		_tagCustomEmojiId = customEmojiId;
		_topicId = topicId;
		_tagTitle = [title copy];
	}
	return self;
}

- (void)fetchNextPage {
	if (self.loadingMore || self.exhausted)
		return;
	self.loadingMore = YES;
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client searchSavedMessagesWithQuery:@""
								tagEmoji:self.tagEmoji
						tagCustomEmojiId:self.tagCustomEmojiId
								 topicId:self.topicId
						   fromMessageId:self.fromMessageId
								   limit:kTagsMessagePageSize
							  completion:^(NSArray *messages, int64_t nextFromMessageId) {
								  typeof(self) strongSelf = weakSelf;
								  if (!strongSelf)
									  return;
								  strongSelf.loadingMore = NO;
								  for (NSDictionary *raw in messages) {
									  NSDictionary *flat = TGTagsFlattenMessage(raw);
									  if (flat)
										  [strongSelf.messages addObject:flat];
								  }
								  strongSelf.fromMessageId = nextFromMessageId;
								  if (messages.count < kTagsMessagePageSize || !strongSelf.fromMessageId)
									  strongSelf.exhausted = YES;
								  [strongSelf.tableView reloadData];
							  }];
}

- (void)dealloc {
	_tableView.delegate = nil;
	_tableView.dataSource = nil;
}

- (void)viewDidLoad {
	[super viewDidLoad];

	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];

	UITableView *table = [UITableView alloc];
	self.tableView = [table initWithFrame:self.view.bounds
									style:UITableViewStylePlain];
	self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	self.tableView.backgroundColor = self.view.backgroundColor;
	self.tableView.rowHeight = kTagsRowHeight;
	self.tableView.dataSource = self;
	self.tableView.delegate = self;
	[self.view addSubview:self.tableView];

	self.title = self.tagTitle.length ? self.tagTitle : TGL(@"VoiceOver.MessageSelectionButtonTag", @"Tag");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	[self fetchNextPage];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell
	forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row >= (NSInteger)self.messages.count - 5)
		[self fetchNextPage];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"tagMessage"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"tagMessage"];

	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	cell.accessoryType = UITableViewCellAccessoryNone;

	NSDictionary *message = nil;
	if (indexPath.row < (NSInteger)self.messages.count)
		message = self.messages[indexPath.row];

	NSString *text = message[@"text"];
	if (![text isKindOfClass:[NSString class]] || !text.length)
		text = @"Media";

	cell.textLabel.font = [UIFont systemFontOfSize:15];
	cell.textLabel.numberOfLines = 1;
	cell.textLabel.text = text;

	int date = [message[@"date"] intValue];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	cell.detailTextLabel.text = date ? [TGDateUtils stringForMessageListDate:date] : @"";
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (indexPath.row >= (NSInteger)self.messages.count)
		return;

	NSDictionary *message = self.messages[indexPath.row];
	int64_t messageId = [message[@"id"] longLongValue];
	int64_t chatId = [[TGClient shared] savedMessagesChatId];
	if (!messageId || !chatId)
		return;

	TGChatViewController *chat = [[TGChatViewController alloc] init];
	chat.chatId = chatId;
	chat.chatTitle = TGL(@"Settings.SavedMessages", @"Saved Messages");
	chat.focusMessageId = messageId;
	if (self.topicId != 0) {
		chat.savedTopicId = self.topicId;
		NSDictionary *topic = [[TGClient shared] cachedSavedMessagesTopic:self.topicId];
		chat.savedTopicOriginChatId = [topic[@"chatId"] longLongValue];
		if (self.tagTitle.length)
			chat.chatTitle = self.tagTitle;
	}
	[self.navigationController pushViewController:chat animated:YES];
}

@end

#pragma mark - the tag row

@interface TGSavedMessagesTagCell : UITableViewCell

@property (nonatomic, strong) UILabel *glyphLabel;
@property (nonatomic, strong) UIImageView *glyphImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIImageView *badgeView;
@property (nonatomic, strong) UILabel *badgeLabel;
@property (nonatomic, strong) UIView *hairline;

@end

@implementation TGSavedMessagesTagCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (self) {
		self.selectionStyle = UITableViewCellSelectionStyleBlue;

		_glyphLabel = [[UILabel alloc] initWithFrame:
				CGRectMake(5, 5, kTagsGlyphSide, kTagsGlyphSide)];
		_glyphLabel.backgroundColor = [UIColor clearColor];
		_glyphLabel.font = [UIFont systemFontOfSize:28];
		_glyphLabel.textAlignment = NSTextAlignmentCenter;
		[self.contentView addSubview:_glyphLabel];

		_glyphImageView = [[UIImageView alloc] initWithFrame:
				CGRectMake(5, 5, kTagsGlyphSide, kTagsGlyphSide)];
		_glyphImageView.contentMode = UIViewContentModeScaleAspectFit;
		_glyphImageView.hidden = YES;
		[self.contentView addSubview:_glyphImageView];

		_titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		_titleLabel.backgroundColor = [UIColor clearColor];
		_titleLabel.font = [UIFont systemFontOfSize:19];
		[self.contentView addSubview:_titleLabel];

		_subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		_subtitleLabel.backgroundColor = [UIColor clearColor];
		_subtitleLabel.font = [UIFont systemFontOfSize:13 + TGTagsRetinaPixel()];
		_subtitleLabel.textColor = TGColourFromHex(0x888888);
		[self.contentView addSubview:_subtitleLabel];

		_badgeView = [[UIImageView alloc] initWithFrame:CGRectZero];
		_badgeView.image = TGTagsBadgeImage();
		[self.contentView addSubview:_badgeView];

		_badgeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		_badgeLabel.backgroundColor = [UIColor clearColor];
		_badgeLabel.font = [UIFont boldSystemFontOfSize:14];
		_badgeLabel.textColor = [UIColor whiteColor];
		_badgeLabel.textAlignment = NSTextAlignmentCenter;
		_badgeLabel.shadowColor = TGColourFromHex(0x8091a6);
		_badgeLabel.shadowOffset = CGSizeMake(0, -1);
		[self.contentView addSubview:_badgeLabel];

		_hairline = [[UIView alloc] initWithFrame:CGRectZero];
		_hairline.backgroundColor = [[TGTheme shared] separatorColour];
		[self.contentView addSubview:_hairline];
	}
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];

	CGRect bounds = self.contentView.bounds;
	CGFloat width = bounds.size.width;

	self.glyphLabel.frame = CGRectMake(5, 5, kTagsGlyphSide, kTagsGlyphSide);
	self.glyphImageView.frame = self.glyphLabel.frame;

	CGFloat badgeWidth = 0;
	if (self.badgeLabel.text.length) {
		CGSize size = [self.badgeLabel.text sizeWithFont:self.badgeLabel.font];
		badgeWidth = floorf(size.width) + 10;
		if (badgeWidth < 27)
			badgeWidth = 27;
		CGFloat badgeY = floorf((bounds.size.height - kTagsBadgeHeight) / 2);
		CGRect badgeFrame = CGRectMake(width - kTagsRightInset - badgeWidth, badgeY,
			badgeWidth, kTagsBadgeHeight);
		self.badgeView.frame = badgeFrame;
		self.badgeLabel.frame = CGRectMake(badgeFrame.origin.x,
			badgeY + 2 + TGTagsRetinaPixel(), badgeWidth, 17);
		self.badgeView.hidden = self.badgeView.image == nil;
		self.badgeLabel.hidden = NO;
		badgeWidth += kTagsRightInset + 6;
	} else {
		self.badgeView.hidden = YES;
		self.badgeLabel.hidden = YES;
	}

	CGFloat textWidth = width - kTagsTextOrigin - kTagsRightInset - badgeWidth;
	if (textWidth < 40)
		textWidth = 40;

	if (self.subtitleLabel.text.length) {
		self.titleLabel.frame = CGRectMake(kTagsTextOrigin, 5, textWidth, 24);
		self.subtitleLabel.frame = CGRectMake(kTagsTextOrigin + 1,
			28 + TGTagsRetinaPixel(), textWidth, 18);
	} else {
		self.titleLabel.frame = CGRectMake(kTagsTextOrigin,
			floorf((bounds.size.height - 24) / 2), textWidth, 24);
		self.subtitleLabel.frame = CGRectZero;
	}

	CGFloat thickness = 1.0f / [UIScreen mainScreen].scale;
	self.hairline.frame = CGRectMake(kTagsTextOrigin, bounds.size.height - thickness,
		width - kTagsTextOrigin, thickness);
}

@end

#pragma mark - the screen

@interface TGSavedMessagesTagsViewController ()

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) TGPlaceholderView *messageView;

@property (nonatomic, strong) NSMutableArray *tags;
@property (nonatomic, strong) NSMutableDictionary *counts;
@property (nonatomic, strong) NSMutableDictionary *labels;
@property (nonatomic, strong) NSMutableDictionary *customEmojiIds;
@property (nonatomic, strong) TGActionSheet *currentActionSheet;
@property (nonatomic, copy) NSString *pendingRenameKey;
@property (nonatomic, strong) id savedTagsObserverToken;
@property (nonatomic, strong) id customEmojiObserverToken;

@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL failed;

@end

@implementation TGSavedMessagesTagsViewController

- (instancetype)initWithTopicId:(int64_t)topicId {
	self = [super initWithNibName:nil bundle:nil];
	if (self) {
		_topicId = topicId;
		[self commonSetup];
	}
	return self;
}

- (instancetype)initWithNibName:(NSString *)nibName bundle:(NSBundle *)bundle {
	self = [super initWithNibName:nibName bundle:bundle];
	if (self)
		[self commonSetup];
	return self;
}

- (void)commonSetup {
	_tags = [NSMutableArray array];
	_counts = [NSMutableDictionary dictionary];
	_labels = [NSMutableDictionary dictionary];
	_customEmojiIds = [NSMutableDictionary dictionary];
}

- (void)dealloc {
	_tableView.delegate = nil;
	_tableView.dataSource = nil;
	if (_savedTagsObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_savedTagsObserverToken];
	if (_customEmojiObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_customEmojiObserverToken];
}

#pragma mark - view

- (void)viewDidLoad {
	[super viewDidLoad];

	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];

	UITableView *table = [UITableView alloc];
	self.tableView = [table initWithFrame:self.view.bounds
									style:UITableViewStylePlain];
	self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	self.tableView.backgroundColor = self.view.backgroundColor;
	self.tableView.rowHeight = kTagsRowHeight;
	self.tableView.dataSource = self;
	self.tableView.delegate = self;
	[self.view addSubview:self.tableView];

	self.messageView = [[TGPlaceholderView alloc] initWithFrame:CGRectMake(0, 0, 250, 60)];
	self.messageView.hidden = YES;

	self.messageView.iconView.image = [TGIcons savedMessagesAvatarOfSide:70];

	self.messageView.titleLabel.font = [UIFont boldSystemFontOfSize:15];
	self.messageView.titleLabel.textColor = TGColourFromHex(0x8b97a5);

	self.messageView.bodyLabel.font = [UIFont systemFontOfSize:14];
	self.messageView.bodyLabel.textColor = TGColourFromHex(0x8b97a5);

	[self.view insertSubview:self.messageView belowSubview:self.tableView];

	self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:
			UIActivityIndicatorViewStyleGray];
	self.spinner.hidesWhenStopped = YES;
	[self.view addSubview:self.spinner];

	self.title = self.topicTitle.length ? self.topicTitle : TGL(@"SavedMessagesTags.Tags", @"Tags");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	NSString *reloadTitle = TGL(@"WebBrowser.Reload", @"Reload");
	UIButton *reloadButton = [TGIcons headerButtonWithTitle:reloadTitle bold:NO target:self action:@selector(reloadPressed)];
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:reloadButton];

	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];

	__weak typeof(self) weakSelf = self;
	self.savedTagsObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGSavedMessagesTagsDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					int64_t changedTopicId = [note.userInfo[TGSavedMessagesTagsTopicIdKey] longLongValue];
					if (changedTopicId != 0 && strongSelf.topicId != 0 && changedTopicId != strongSelf.topicId)
						return;
					[strongSelf reload];
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

	[self reload];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	if (self.currentActionSheet) {
		TGActionSheet *sheet = self.currentActionSheet;
		[sheet dismissWithClickedButtonIndex:sheet.cancelButtonIndex animated:NO];
		self.currentActionSheet = nil;
	}
}

- (void)viewDidLayoutSubviews {
	if ([[UIViewController class] instancesRespondToSelector:@selector(viewDidLayoutSubviews)])
		[super viewDidLayoutSubviews];
	[self layoutOverlays];
}

- (void)viewWillLayoutSubviews {
	if ([[UIViewController class] instancesRespondToSelector:@selector(viewWillLayoutSubviews)])
		[super viewWillLayoutSubviews];
	[self layoutOverlays];
}

- (void)layoutOverlays {
	CGRect bounds = self.view.bounds;
	self.spinner.center = CGPointMake(floorf(bounds.size.width / 2),
		floorf(bounds.size.height / 2));

	if (self.messageView.hidden)
		return;

	CGFloat width = 250;
	CGFloat height = [self.messageView layoutContentWidth:width];
	self.messageView.frame = CGRectMake(floorf((bounds.size.width - width) / 2),
		floorf((bounds.size.height - height) / 2), width, height);
}

#pragma mark - loading

- (void)reloadPressed {
	[self reload];
}

- (void)reload {
	if (self.loading)
		return;

	self.loaded = NO;
	self.failed = NO;
	[self.tags removeAllObjects];
	[self.counts removeAllObjects];
	[self.labels removeAllObjects];
	[self.customEmojiIds removeAllObjects];
	[self.tableView reloadData];
	[self showLoading];

	self.loading = YES;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] savedMessagesTagsForTopic:self.topicId completion:^(NSArray *tags) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		for (NSDictionary *entry in tags) {
			if (![entry isKindOfClass:[NSDictionary class]])
				continue;
			NSDictionary *tag = [entry[@"tag"] isKindOfClass:[NSDictionary class]] ? entry[@"tag"] : nil;
			NSString *emoji = [tag[@"emoji"] isKindOfClass:[NSString class]] ? tag[@"emoji"] : nil;
			NSNumber *customEmojiId = emoji.length ? nil : TGSavedTagCustomEmojiId(tag);
			if (!emoji.length && !customEmojiId)
				continue;
			NSString *key = emoji.length ? emoji
				: [NSString stringWithFormat:@"custom:%lld", [customEmojiId longLongValue]];
			NSInteger count = [entry[@"count"] integerValue];
			strongSelf.counts[key] = @(count);
			[strongSelf.tags addObject:key];
			if (customEmojiId)
				strongSelf.customEmojiIds[key] = customEmojiId;
			NSString *label = [entry[@"label"] isKindOfClass:[NSString class]] ? entry[@"label"] : nil;
			if (label.length)
				strongSelf.labels[key] = label;
		}

		NSMutableDictionary *counts = strongSelf.counts;
		[strongSelf.tags sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
			NSInteger countA = [counts[a] integerValue];
			NSInteger countB = [counts[b] integerValue];
			if (countA == countB)
				return [a compare:b];
			return countA > countB ? NSOrderedAscending : NSOrderedDescending;
		}];

		strongSelf.loading = NO;
		strongSelf.loaded = YES;
		strongSelf.failed = NO;
		[strongSelf.tableView reloadData];
		[strongSelf updateStates];
	}];
}

- (void)showLoading {
	self.messageView.hidden = YES;
	self.tableView.hidden = YES;
	[self.spinner startAnimating];
	[self layoutOverlays];
}

- (void)updateStates {
	[self.spinner stopAnimating];

	if (self.tags.count) {
		self.messageView.hidden = YES;
		self.tableView.hidden = NO;
		return;
	}

	self.tableView.hidden = YES;
	self.messageView.hidden = NO;
	self.messageView.titleLabel.text = TGL(@"SavedMessagesTags.NoTags", @"No tags");
	self.messageView.bodyLabel.text = TGL(@"SavedMessagesTags.TagASavedMessageWithA", @"Tag a saved message with a reaction and the tag shows up here, with the number of messages that carry it.");
	[self layoutOverlays];
}

#pragma mark - model helpers

- (NSString *)tagKeyAtIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)self.tags.count)
		return nil;
	return self.tags[index];
}

- (NSString *)titleForTagKey:(NSString *)key {
	NSString *label = self.labels[key];
	if ([label isKindOfClass:[NSString class]] && label.length)
		return label;
	if (self.customEmojiIds[key])
		return TGL(@"VoiceOver.MessageSelectionButtonTag", @"Tag");
	return key;
}

#pragma mark - table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.tags.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	TGSavedMessagesTagCell *cell = [tableView dequeueReusableCellWithIdentifier:@"tag"];
	if (!cell)
		cell = [[TGSavedMessagesTagCell alloc] initWithStyle:UITableViewCellStyleDefault
											 reuseIdentifier:@"tag"];

	[[TGTheme shared] styleCell:cell];

	NSString *key = [self tagKeyAtIndex:indexPath.row];
	NSInteger count = [self.counts[key] integerValue];
	NSNumber *customEmojiId = self.customEmojiIds[key];

	if (customEmojiId) {
		UIImage *customImage = TGCustomEmojiCachedImage([customEmojiId longLongValue]);
		if (!customImage)
			TGCustomEmojiRequestImage([customEmojiId longLongValue]);
		cell.glyphLabel.text = @"";
		cell.glyphImageView.image = customImage;
		cell.glyphImageView.hidden = NO;
	} else {
		cell.glyphLabel.text = key ? key : @"";
		cell.glyphImageView.hidden = YES;
	}
	cell.titleLabel.text = [self titleForTagKey:key];
	cell.titleLabel.textColor = [[TGTheme shared] primaryTextColour];
	cell.subtitleLabel.text = TGLPlural(@"ChatList.Search.Messages", count, @"%@ message", @"%@ messages");
	cell.badgeLabel.text = TGTagsCountString(count);
	[cell setNeedsLayout];
	return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return kTagsRowHeight;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	NSString *key = [self tagKeyAtIndex:indexPath.row];
	if (!key)
		return;

	NSArray *actions = [NSArray arrayWithObjects:
			[[TGActionSheetAction alloc] initWithTitle:TGL(@"Chat.ReactionContextMenu.FilterByTag", @"Show Messages") action:@"show"],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Chat.EditTagTitle.TitleEdit", @"Rename Tag") action:@"rename"],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Common.Cancel", @"Cancel") action:@"cancel"
											  type:TGActionSheetActionTypeCancel],
		nil];

	__weak typeof(self) weakSelf = self;
	NSString *chosen = key;
	TGActionSheet *sheet = [TGActionSheet alloc];
	sheet = [sheet initWithTitle:nil
						 actions:actions
					 actionBlock:^(id target, NSString *action) {
						 __strong typeof(weakSelf) strongSelf = weakSelf;
						 if (!strongSelf)
							 return;
						 strongSelf.currentActionSheet = nil;
						 if ([action isEqualToString:@"show"])
							 [strongSelf showMessagesForTagKey:chosen];
						 else if ([action isEqualToString:@"rename"])
							 [strongSelf askRenameForTagKey:chosen];
					 }
						  target:self];
	self.currentActionSheet = sheet;

	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	[self.currentActionSheet tg_showFromRect:cell.frame inView:tableView];
}

#pragma mark - actions

- (void)showMessagesForTagKey:(NSString *)key {
	NSString *title = [self titleForTagKey:key];
	NSNumber *customEmojiId = self.customEmojiIds[key];
	TGSavedMessagesTagFilterController *controller = [TGSavedMessagesTagFilterController alloc];
	if (customEmojiId)
		controller = [controller initWithTagCustomEmojiId:[customEmojiId longLongValue]
												   topicId:self.topicId
													 title:title];
	else
		controller = [controller initWithTagEmoji:key topicId:self.topicId title:title];
	[self.navigationController pushViewController:controller animated:YES];
}

- (void)askRenameForTagKey:(NSString *)key {
	if (![[TGClient shared] isPremiumAccount]) {
		UIAlertView *premiumAlert = [TGAlertView alloc];
		premiumAlert = [premiumAlert initWithTitle:nil
											message:TGL(@"Chat.RenameTagRequiresPremium", @"Subscribe to Telegram Premium to rename message tags.")
										   delegate:nil
								  cancelButtonTitle:TGL(@"Common.OK", @"OK")
								  otherButtonTitles:nil];
		[premiumAlert show];
		return;
	}

	self.pendingRenameKey = key;

	UIAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:nil
						 message:TGL(@"Chat.EditTagTitle.Text", @"Name for this tag")
						delegate:self
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			   otherButtonTitles:TGL(@"Common.Done", @"Done"), nil];
	if ([alert respondsToSelector:@selector(setAlertViewStyle:)]) {
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
		UITextField *field = [alert textFieldAtIndex:0];
		field.autocapitalizationType = UITextAutocapitalizationTypeSentences;
		field.delegate = self;
		NSString *label = self.labels[key];
		if ([label isKindOfClass:[NSString class]])
			field.text = label;
	}
	[alert show];
}

- (BOOL)textField:(UITextField *)textField
	shouldChangeCharactersInRange:(NSRange)range
				replacementString:(NSString *)string {
	NSString *current = textField.text ?: @"";
	if (range.location > current.length)
		return NO;
	NSString *next = [current stringByReplacingCharactersInRange:range withString:string];
	return next.length <= 12;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex == alertView.cancelButtonIndex) {
		self.pendingRenameKey = nil;
		return;
	}

	NSString *key = self.pendingRenameKey;
	self.pendingRenameKey = nil;
	if (!key.length)
		return;

	NSString *label = @"";
	if ([alertView respondsToSelector:@selector(textFieldAtIndex:)]) {
		UITextField *field = [alertView textFieldAtIndex:0];
		if (field.text)
			label = [field.text stringByTrimmingCharactersInSet:
					[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	}

	__weak typeof(self) weakSelf = self;
	NSString *chosen = key;
	NSString *newLabel = label;
	NSNumber *customEmojiId = self.customEmojiIds[key];
	void (^handleResult)(BOOL) = ^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			UIView *host = strongSelf.navigationController.view ? strongSelf.navigationController.view : strongSelf.view;
			[TGSnackbar showInView:host
							  text:TGL(@"Chat.CouldNotRenameTag", @"Could not rename the tag.")
						   seconds:2
						  onCommit:nil];
			return;
		}
		if (newLabel.length)
			strongSelf.labels[chosen] = newLabel;
		else
			[strongSelf.labels removeObjectForKey:chosen];
		[strongSelf.tableView reloadData];
	};

	if (customEmojiId)
		[[TGClient shared] setSavedMessagesTagLabel:newLabel
									forCustomEmojiId:[customEmojiId longLongValue]
										  completion:handleResult];
	else
		[[TGClient shared] setSavedMessagesTagLabel:newLabel forEmoji:chosen completion:handleResult];
}

@end

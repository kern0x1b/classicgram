#import "TGListBackground.h"
#import "TGClient+Contacts.h"
#import "TGClient+ChatState.h"
#import "TGProfileStatisticsController.h"
#import "TGProfileViewControllerInternal.h"
#import "TGProfileChartView.h"
#import "TGProfileViewController.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGPopupMenu.h"
#import "TGActionSheet.h"
#import "TGForwardPicker.h"
#import "UIView+SafeTint.h"
#import "TGImageDecode.h"
#import "TGClient+Channels.h"
#import "TGFlattenChannels.h"
#import "TGMessageStatisticsViewController.h"
#import "TGStoryStatisticsViewController.h"
#import "TGLazyFramework.h"
#import <AVFoundation/AVFoundation.h>
#import <AddressBook/AddressBook.h>
#import <ImageIO/ImageIO.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>
#import "TGEmoji.h"
#import "TGDateLabel.h"
#import "TGDateUtils.h"
#import "TGAlertView.h"
#import "TGHexColour.h"

@implementation TGProfileStatisticsController {
	UIView *_modeBar;
	NSMutableArray *_groupButtons;
	NSMutableArray *_groupSeparators;
	UILabel *_emptyLabel;
	NSMutableArray *_extraGraphs;
}

static const CGFloat kStatsModeBarHeight = 44.0f;
static const CGFloat kStatsGroupHeight = 30.0f;
static const CGFloat kStatsGroupInset = 10.0f;
static const CGFloat kStatsSeparatorWidth = 2.0f;
static const CGFloat kStatsChartHeight = 128.0f;
static const CGFloat kStatsRowHeight = 51.0f;
static const CGFloat kStatsPosterRowHeight = 49.0f;
static const CGFloat kStatsRecentRowHeight = 54.0f;

static UIImage *TGStatsStretch(NSString *name, int leftCap) {
	UIImage *raw = [UIImage imageNamed:name];
	if (!raw)
		return nil;
	return [raw stretchableImageWithLeftCapWidth:leftCap topCapHeight:0];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"Stats.Statistics", @"Statistics");
	self.values = @[];
	self.topSenders = @[];
	self.topAdmins = @[];
	self.topInviters = @[];
	self.graphs = @[];
	self.recentInteractions = @[];
	self.boosters = @[];
	_extraGraphs = [NSMutableArray array];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];

	CGRect bounds = self.view.bounds;
	[self buildStatsModeBar:bounds];
	[self buildStatsTable:bounds];
	[self buildStatsEmptyLabel:bounds];
	[self reload];
}

- (void)buildStatsModeBar:(CGRect)bounds {
	_modeBar = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, bounds.size.width, kStatsModeBarHeight)];
	_modeBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	UIImage *plate = TGStatsStretch(@"Footer.png", 1);
	if (plate)
		_modeBar.backgroundColor = [UIColor colorWithPatternImage:plate];
	else
		_modeBar.backgroundColor = [[TGTheme shared] inputBarColour];
	[self.view addSubview:_modeBar];

	UIView *hairline = [[UIView alloc] initWithFrame:
			CGRectMake(0, kStatsModeBarHeight - 1, bounds.size.width, 1)];
	hairline.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	hairline.backgroundColor = [[TGTheme shared] separatorColour];
	[_modeBar addSubview:hairline];

	[self buildModeButtons];
}

- (void)buildStatsTable:(CGRect)bounds {
	CGRect tableFrame = CGRectMake(0, kStatsModeBarHeight, bounds.size.width, bounds.size.height - kStatsModeBarHeight);
	self.tableView = [[UITableView alloc] initWithFrame:tableFrame style:UITableViewStylePlain];
	self.tableView.autoresizingMask =
		UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.tableView.dataSource = self;
	self.tableView.delegate = self;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	[self.view addSubview:self.tableView];

	self.chartView = [[TGProfileChartView alloc] initWithFrame:
			CGRectMake(0, 0, bounds.size.width, kStatsChartHeight)];
	self.chartView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
}

- (void)buildStatsEmptyLabel:(CGRect)bounds {
	_emptyLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(0, 60, bounds.size.width, 22)];
	_emptyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_emptyLabel.backgroundColor = [UIColor clearColor];
	_emptyLabel.textAlignment = NSTextAlignmentCenter;
	_emptyLabel.font = [UIFont systemFontOfSize:15];
	_emptyLabel.textColor = [[TGTheme shared] secondaryTextColour];
	_emptyLabel.text = TGL(@"Channel.NotificationLoading", @"Loading…");
	UIView *background = [[UIView alloc] initWithFrame:self.tableView.bounds];
	background.autoresizingMask =
		UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	background.backgroundColor = [UIColor clearColor];
	[background addSubview:_emptyLabel];
	self.tableView.backgroundView = background;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

#pragma mark - mode bar

- (NSArray *)modeTitles {
	if (self.channelChat)
		return @[ TGL(@"Stats.Growth", @"Growth"),
			TGL(@"Stats.Boosts", @"Boosts") ];
	return @[ TGL(@"Stats.Growth", @"Growth"),
		TGL(@"Stats.GroupMembers", @"Members"),
		TGL(@"Stats.Boosts", @"Boosts") ];
}

- (NSArray *)modeValues {
	if (self.channelChat)
		return @[ @0, @2 ];
	return @[ @0, @1, @2 ];
}

- (void)buildModeButtons {
	_groupButtons = [NSMutableArray array];
	_groupSeparators = [NSMutableArray array];

	NSArray *titles = [self modeTitles];
	NSArray *values = [self modeValues];
	CGFloat width = self.view.bounds.size.width - kStatsGroupInset * 2;
	CGFloat originY = (CGFloat)(int)((kStatsModeBarHeight - kStatsGroupHeight) / 2);

	UIView *group = [[UIView alloc] initWithFrame:
			CGRectMake(kStatsGroupInset, originY, width, kStatsGroupHeight)];
	group.autoresizingMask = UIViewAutoresizingFlexibleWidth;

	NSInteger count = (NSInteger)titles.count;
	CGFloat usable = width - kStatsSeparatorWidth * (count - 1);
	CGFloat buttonWidth = (CGFloat)(int)(usable / count);
	UIColor *shadowColour = [TGColourFromHex(0x0e284d) colorWithAlphaComponent:0.4f];

	CGFloat currentX = 0;
	for (NSInteger i = 0; i < count; i++) {
		CGFloat thisWidth = (i == count - 1) ? (width - currentX) : buttonWidth;

		CGRect buttonFrame = CGRectMake(currentX, 0, thisWidth, kStatsGroupHeight);
		NSInteger modeValue = [values[(NSUInteger)i] integerValue];
		UIButton *button = [self makeModeButtonWithTitle:titles[(NSUInteger)i] index:modeValue frame:buttonFrame shadowColour:shadowColour];
		[group addSubview:button];
		[_groupButtons addObject:button];

		currentX += thisWidth;

		if (i + 1 < count) {
			UIView *separator = [self makeModeSeparatorAtX:currentX];
			[group addSubview:separator];
			[_groupSeparators addObject:separator];
			currentX += kStatsSeparatorWidth;
		}
	}

	[_modeBar addSubview:group];
	[self updateModeButtons];
}

- (UIButton *)makeModeButtonWithTitle:(NSString *)title
								index:(NSInteger)index
								frame:(CGRect)frame
						 shadowColour:(UIColor *)shadowColour {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.exclusiveTouch = YES;
	button.frame = frame;
	button.tag = index;
	[button setTitle:title forState:UIControlStateNormal];
	button.titleLabel.font = [UIFont boldSystemFontOfSize:12];
	[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[button setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
	[button setTitleShadowColor:shadowColour forState:UIControlStateNormal];
	[button setTitleShadowColor:shadowColour forState:UIControlStateHighlighted];
	button.titleLabel.shadowOffset = CGSizeMake(0, -1);
	button.adjustsImageWhenDisabled = NO;
	button.adjustsImageWhenHighlighted = NO;
	[button addTarget:self action:@selector(modeButtonPressed:)
		forControlEvents:UIControlEventTouchDown];
	return button;
}

- (UIView *)makeModeSeparatorAtX:(CGFloat)x {
	UIView *separator = [[UIView alloc] initWithFrame:
			CGRectMake(x, 0, kStatsSeparatorWidth, kStatsGroupHeight)];
	NSArray *names = @[ @"ButtonGroupDivider.png",
		@"ButtonGroupDivider_LeftHighlighted.png",
		@"ButtonGroupDivider_RightHighlighted.png" ];
	for (NSInteger j = 0; j < names.count; j++) {
		UIImage *art = TGStatsStretch(names[j], 6);
		UIImageView *layer = [[UIImageView alloc] initWithImage:art];
		layer.tag = (NSInteger)(100 + j);
		layer.frame = separator.bounds;
		layer.alpha = (j == 0) ? 1.0f : 0.0f;
		[separator addSubview:layer];
	}
	return separator;
}

- (void)updateModeButtons {
	NSInteger count = _groupButtons.count;
	for (NSInteger i = 0; i < count; i++) {
		UIButton *button = _groupButtons[i];
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
		UIImage *normal = TGStatsStretch(normalName, leftCap);
		UIImage *highlighted = TGStatsStretch(highlightedName, leftCap);
		UIImage *shown = (button.tag == self.mode) ? highlighted : normal;
		[button setBackgroundImage:shown forState:UIControlStateNormal];
		[button setBackgroundImage:shown forState:UIControlStateHighlighted];
		if (!normal)
			button.backgroundColor = (button.tag == self.mode)
				? [[TGTheme shared] accentColour]
				: [UIColor colorWithWhite:0.62f alpha:1.0f];
	}

	for (NSInteger i = 0; i < _groupSeparators.count; i++) {
		UIView *separator = _groupSeparators[i];
		UIView *normal = [separator viewWithTag:100];
		UIView *leftLit = [separator viewWithTag:101];
		UIView *rightLit = [separator viewWithTag:102];
		UIView *shown = normal;
		NSInteger leftTag = ((UIButton *)_groupButtons[i]).tag;
		NSInteger rightTag = ((UIButton *)_groupButtons[i + 1]).tag;
		if (self.mode == leftTag)
			shown = leftLit;
		else if (self.mode == rightTag)
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

- (void)modeButtonPressed:(UIButton *)button {
	if (self.mode == button.tag)
		return;
	self.mode = button.tag;
	[self updateModeButtons];
	[self.tableView setContentOffset:CGPointZero animated:NO];
	[self applyMode];
}

- (void)applyMode {
	self.tableView.tableHeaderView =
		(self.mode == 0 && (self.chartView.points.count > 1 || self.chartView.errorText.length))
		? self.chartView
		: nil;
	[self.tableView reloadData];
	[self updateEmptyLabel];
}

- (void)updateEmptyLabel {
	if (!self.loaded) {
		_emptyLabel.text = TGL(@"Channel.NotificationLoading", @"Loading…");
		_emptyLabel.hidden = NO;
		return;
	}
	NSInteger rows = 0;
	for (NSInteger section = 0;
		section < [self numberOfSectionsInTableView:self.tableView]; section++)
		rows += [self tableView:self.tableView numberOfRowsInSection:section];
	if (rows > 0) {
		_emptyLabel.hidden = YES;
		return;
	}
	if (self.loadError.length) {
		_emptyLabel.hidden = NO;
		_emptyLabel.text = self.loadError;
		return;
	}
	if (self.mode == 2) {
		_emptyLabel.hidden = NO;
		_emptyLabel.text = TGL(@"Stats.Boosts.NoBoostersYet", @"Nobody has boosted this channel yet.");
		return;
	}
	_emptyLabel.hidden = YES;
}

#pragma mark - loading

- (void)reload {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] statisticsForChat:self.chatId
								  isDark:NO
							  completion:^(NSDictionary *stats, NSString *errorMessage) {
								  weakSelf.loaded = YES;
								  if ([stats isKindOfClass:[NSDictionary class]]) {
									  weakSelf.loadError = nil;
									  id values = stats[@"values"];
									  id senders = stats[@"top_senders"];
									  id graphs = stats[@"graphs"];
									  weakSelf.values = [values isKindOfClass:[NSArray class]] ? values : @[];
									  weakSelf.topSenders = [senders isKindOfClass:[NSArray class]] ? senders : @[];
									  weakSelf.graphs = [graphs isKindOfClass:[NSArray class]] ? graphs : @[];
									  id admins = stats[@"top_administrators"];
									  id inviters = stats[@"top_inviters"];
									  weakSelf.topAdmins = [admins isKindOfClass:[NSArray class]] ? admins : @[];
									  weakSelf.topInviters = [inviters isKindOfClass:[NSArray class]]
										  ? inviters
										  : @[];
									  id recentInteractions = stats[@"recent_interactions"];
									  weakSelf.recentInteractions =
										  [recentInteractions isKindOfClass:[NSArray class]]
										  ? recentInteractions
										  : @[];
								  } else {
									  weakSelf.loadError = errorMessage.length
										  ? errorMessage
										  : TGL(@"Stats.LoadFailed", @"Could not load statistics");
								  }
								  [weakSelf loadGraphs];
								  [weakSelf applyMode];
							  }];

	[[TGClient shared] boostStatusForChat:self.chatId completion:^(NSDictionary *status) {
		if ([status isKindOfClass:[NSDictionary class]])
			weakSelf.boostStatus = status;
		[weakSelf applyMode];
	}];
	[[TGClient shared] boostsForChat:self.chatId
					   onlyGiftCodes:NO
							  offset:@""
							   limit:20
						  completion:^(NSArray *boosts, NSString *nextOffset,
							  NSInteger totalCount) {
							  weakSelf.boosters = [boosts isKindOfClass:[NSArray class]] ? boosts : @[];
							  [weakSelf applyMode];
						  }];
}

- (void)loadGraphs {
	_extraGraphs = [NSMutableArray array];
	NSArray *graphs = self.graphs;
	for (NSInteger i = 0; i < (NSInteger)graphs.count; i++) {
		id entry = graphs[i];
		if ([entry isKindOfClass:[NSDictionary class]])
			[self resolveGraph:entry isPrimary:(i == 0)];
	}
}

- (void)resolveGraph:(NSDictionary *)graph isPrimary:(BOOL)isPrimary {
	NSString *title = TGProfileText(graph[@"title"]) ?: @"";
	NSString *error = TGProfileText(graph[@"error"]);
	if (error) {
		[self applyGraphPoints:nil error:error title:title isPrimary:isPrimary];
		return;
	}
	NSString *json = TGProfileText(graph[@"json"]);
	if (json) {
		[self applyGraphPoints:[self pointsFromGraphJson:json] error:nil title:title isPrimary:isPrimary];
		return;
	}
	NSString *token = TGProfileText(graph[@"token"]);
	if (!token)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] statisticalGraphForChat:self.chatId
										 token:token
									   zoomAtX:0
									completion:^(NSDictionary *loaded) {
										NSString *loadedError = [loaded isKindOfClass:[NSDictionary class]]
											? TGProfileText(loaded[@"error"])
											: nil;
										NSString *loadedJson = [loaded isKindOfClass:[NSDictionary class]]
											? TGProfileText(loaded[@"json"])
											: nil;
										NSDictionary *points = loadedJson
											? [weakSelf pointsFromGraphJson:loadedJson]
											: nil;
										NSString *finalError = loadedError
											?: (points ? nil : TGL(@"Stats.Graph.LoadFailed", @"Could not load graph"));
										[weakSelf applyGraphPoints:points error:finalError title:title isPrimary:isPrimary];
									}];
}

- (void)applyGraphPoints:(NSDictionary *)resolved error:(NSString *)error title:(NSString *)title isPrimary:(BOOL)isPrimary {
	if (resolved) {
		if (isPrimary) {
			self.chartView.errorText = nil;
			self.chartView.points = resolved[@"points"];
			self.chartView.leftDate = resolved[@"leftDate"];
			self.chartView.rightDate = resolved[@"rightDate"];
			[self applyMode];
			return;
		}
		[_extraGraphs addObject:@{
			@"title" : title,
			@"points" : resolved[@"points"],
			@"leftDate" : resolved[@"leftDate"] ?: @"",
			@"rightDate" : resolved[@"rightDate"] ?: @"",
		}];
		[self applyMode];
		return;
	}
	if (isPrimary) {
		self.chartView.points = @[];
		self.chartView.errorText = [NSString stringWithFormat:
				TGL(@"Stats.Graph.CouldNotLoad", @"Could not load: %@"),
				error ?: TGL(@"Stats.Graph.LoadFailed", @"Could not load graph")];
		[self applyMode];
		return;
	}
	[_extraGraphs addObject:@{
		@"title" : title,
		@"error" : error ?: TGL(@"Stats.Graph.LoadFailed", @"Could not load graph"),
	}];
	[self applyMode];
}

- (NSDictionary *)pointsFromGraphJson:(NSString *)json {
	NSDictionary *resolved = TGChPointsFromGraphJson(json, 30);
	if (!resolved)
		return nil;
	NSNumber *firstX = [resolved[@"firstX"] isKindOfClass:[NSNumber class]] ? resolved[@"firstX"] : nil;
	NSNumber *lastX = [resolved[@"lastX"] isKindOfClass:[NSNumber class]] ? resolved[@"lastX"] : nil;
	return @{
		@"points" : resolved[@"points"],
		@"leftDate" : firstX ? [self dayTextFor:firstX] : @"",
		@"rightDate" : lastX ? [self dayTextFor:lastX] : @"",
	};
}

- (NSDictionary *)extraGraphForSection:(NSInteger)section {
	NSInteger index = section - 1;
	return (index >= 0 && index < (NSInteger)_extraGraphs.count) ? _extraGraphs[index] : nil;
}

- (BOOL)hasRecentInteractionsSection {
	return self.channelChat && self.recentInteractions.count > 0;
}

- (NSInteger)recentInteractionsSectionIndex {
	return [self hasRecentInteractionsSection] ? 1 + (NSInteger)_extraGraphs.count : NSNotFound;
}

- (NSString *)dayTextFor:(id)milliseconds {
	if (![milliseconds isKindOfClass:[NSNumber class]])
		return @"";
	return [TGDateUtils stringForDayOfMonth:(int)([milliseconds doubleValue] / 1000.0)
								 dayOfMonth:NULL];
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if (self.mode == 2)
		return 2;
	if (self.mode == 1)
		return 3;
	return 1 + (NSInteger)_extraGraphs.count + ([self hasRecentInteractionsSection] ? 1 : 0);
}

- (NSArray *)peopleForSection:(NSInteger)section {
	if (section == 1)
		return self.topAdmins ?: @[];
	if (section == 2)
		return self.topInviters ?: @[];
	return self.topSenders ?: @[];
}

- (NSString *)peopleSummaryFor:(NSDictionary *)entry section:(NSInteger)section {
	NSMutableArray *parts = [NSMutableArray array];
	if (section == 1) {
		NSArray *keys = @[ @"deleted_message_count", @"banned_user_count",
			@"restricted_user_count" ];
		for (NSInteger i = 0; i < keys.count; i++) {
			id raw = [entry objectForKey:keys[i]];
			NSInteger value = [raw isKindOfClass:[NSNumber class]]
				? [raw integerValue]
				: 0;
			if (value <= 0)
				continue;
			NSString *text = nil;
			if (i == 0)
				text = TGLPlural(@"Stats.GroupTopAdminDeletions", value, @"%ld deletion", @"%ld deletions");
			else if (i == 1)
				text = TGLPlural(@"Stats.GroupTopAdminBans", value, @"%ld ban", @"%ld bans");
			else
				text = TGLPlural(@"Stats.GroupTopAdminRestrictions", value, @"%ld restriction", @"%ld restrictions");
			[parts addObject:text];
		}
	} else if (section == 2) {
		id raw = [entry objectForKey:@"added_member_count"];
		NSInteger value = [raw isKindOfClass:[NSNumber class]] ? [raw integerValue] : 0;
		if (value > 0)
			[parts addObject:TGLPlural(@"Stats.GroupTopInviterInvites", value, @"%ld invitation", @"%ld invitations")];
	}
	return parts.count ? [parts componentsJoinedByString:@", "] : nil;
}

- (NSArray *)boostSummaryRows {
	if (![self.boostStatus isKindOfClass:[NSDictionary class]])
		return @[];
	NSMutableArray *rows = [NSMutableArray array];
	NSInteger level = [self.boostStatus[@"level"] isKindOfClass:[NSNumber class]]
		? [self.boostStatus[@"level"] integerValue]
		: 0;
	NSInteger count = [self.boostStatus[@"boost_count"] isKindOfClass:[NSNumber class]]
		? [self.boostStatus[@"boost_count"] integerValue]
		: 0;
	NSInteger next = [self.boostStatus[@"next_level_boost_count"]
						 isKindOfClass:[NSNumber class]]
		? [self.boostStatus[@"next_level_boost_count"] integerValue]
		: 0;
	[rows addObject:@[ TGL(@"Stats.Boosts.Level", @"Level"), [NSString stringWithFormat:@"%ld", (long)level] ]];
	[rows addObject:@[ TGL(@"Stats.Boosts.ExistingBoosts", @"Existing Boosts"), [NSString stringWithFormat:@"%ld", (long)count] ]];
	if (next > count)
		[rows addObject:@[ TGL(@"Stats.Boosts.BoostsToLevelUp", @"Boosts to Level Up"),
			[NSString stringWithFormat:TGL(@"Stats.Boosts.MoreToNextLevel", @"%ld more"), (long)(next - count)] ]];
	return rows;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (self.mode == 0) {
		if (section == 0)
			return self.values.count;
		if (section == [self recentInteractionsSectionIndex])
			return self.recentInteractions.count;
		return 1;
	}
	if (self.mode == 1)
		return [self peopleForSection:section].count;
	return section == 0 ? [self boostSummaryRows].count : self.boosters.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.mode == 1)
		return indexPath.section == 0 ? kStatsPosterRowHeight : kStatsRowHeight;
	if (self.mode == 0 && indexPath.section == [self recentInteractionsSectionIndex])
		return kStatsRecentRowHeight;
	if (self.mode == 0 && indexPath.section > 0) {
		NSDictionary *entry = [self extraGraphForSection:indexPath.section];
		return [entry[@"points"] isKindOfClass:[NSArray class]] ? kStatsChartHeight : kStatsRowHeight;
	}
	return kStatsRowHeight;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (self.mode == 0) {
		if (section == 0)
			return self.values.count ? TGL(@"Stats.MessageOverview", @"Overview") : nil;
		if (section == [self recentInteractionsSectionIndex])
			return TGL(@"Stats.RecentPostsTitle", @"RECENT POSTS");
		return TGProfileText([self extraGraphForSection:section][@"title"]);
	}
	if (self.mode == 1 && [self peopleForSection:section].count) {
		if (section == 1)
			return TGL(@"Stats.GroupTopAdminsTitle", @"TOP ADMINS");
		if (section == 2)
			return TGL(@"Stats.GroupTopInvitersTitle", @"TOP INVITERS");
		return TGL(@"Stats.GroupTopPostersTitle", @"TOP MEMBERS");
	}
	if (self.mode == 2 && section == 1 && self.boosters.count)
		return TGL(@"Stats.BoostedBy", @"Boosted by");
	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return [[TGTheme shared] groupedHeaderHeightForTitle:
			[self tableView:tableView titleForHeaderInSection:section]];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (NSString *)valueTextFor:(NSDictionary *)entry {
	double value = [entry[@"value"] isKindOfClass:[NSNumber class]]
		? [entry[@"value"] doubleValue]
		: 0;
	return (value == floor(value))
		? [NSString stringWithFormat:@"%lld", (long long)value]
		: [NSString stringWithFormat:@"%.2f", value];
}

- (NSString *)growthTextFor:(NSDictionary *)entry {
	double growth = [entry[@"growth"] isKindOfClass:[NSNumber class]]
		? [entry[@"growth"] doubleValue]
		: 0;
	if (fabs(growth) < 0.005)
		return nil;
	return [NSString stringWithFormat:@"%@%.2f%%", (growth > 0 ? @"+" : @""), growth];
}

- (NSInteger)largestSenderCount {
	NSInteger largest = 0;
	for (id entry in self.topSenders) {
		if (![entry isKindOfClass:[NSDictionary class]])
			continue;
		id count = [entry objectForKey:@"sent_message_count"];
		NSInteger value = [count isKindOfClass:[NSNumber class]]
			? [count integerValue]
			: 0;
		if (value > largest)
			largest = value;
	}
	return largest;
}

- (UITableViewCell *)makePosterCell:(UITableView *)tableView {
	UITableViewCell *cell = [[UITableViewCell alloc]
		  initWithStyle:UITableViewCellStyleDefault
		reuseIdentifier:@"poster"];

	UIImageView *avatar = [[UIImageView alloc] initWithFrame:
			CGRectMake(5, 4, 40, 40)];
	avatar.tag = 21;
	avatar.layer.cornerRadius = 4;
	avatar.clipsToBounds = YES;
	[cell.contentView addSubview:avatar];

	UILabel *name = [[TGEmojiLabel alloc] initWithFrame:
			CGRectMake(54, 4, tableView.bounds.size.width - 118, 20)];
	name.tag = 22;
	name.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	name.backgroundColor = [UIColor clearColor];
	name.font = [UIFont systemFontOfSize:17];
	[cell.contentView addSubview:name];

	UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(54, 25, 0, 4)];
	bar.tag = 23;
	bar.backgroundColor = TGColourFromHex(0x337acc);
	[cell.contentView addSubview:bar];

	UILabel *subtitle = [[UILabel alloc] initWithFrame:
			CGRectMake(54, 30, tableView.bounds.size.width - 118, 16)];
	subtitle.tag = 24;
	subtitle.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	subtitle.backgroundColor = [UIColor clearColor];
	subtitle.font = [UIFont systemFontOfSize:13];
	subtitle.textColor = TGColourFromHex(0x888888);
	[cell.contentView addSubview:subtitle];

	UILabel *count = [[UILabel alloc] initWithFrame:
			CGRectMake(tableView.bounds.size.width - 64, 15, 54, 18)];
	count.tag = 25;
	count.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	count.backgroundColor = [UIColor clearColor];
	count.textAlignment = NSTextAlignmentRight;
	count.font = [UIFont boldSystemFontOfSize:13];
	count.textColor = TGColourFromHex(0x356596);
	[cell.contentView addSubview:count];
	return cell;
}

- (UITableViewCell *)posterCell:(UITableView *)tableView row:(NSInteger)row {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"poster"];
	if (!cell)
		cell = [self makePosterCell:tableView];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;

	id raw = row < (NSInteger)self.topSenders.count ? self.topSenders[row] : nil;
	NSDictionary *entry = [raw isKindOfClass:[NSDictionary class]] ? raw : @{};
	int64_t userId = TGProfileInt64(entry[@"user_id"]);
	NSString *clientName = TGProfileText([[TGClient shared] nameForUserId:userId]) ?: @"";
	NSString *name = TGProfileText(entry[@"name"]) ?: clientName;
	NSInteger messages = [entry[@"sent_message_count"] isKindOfClass:[NSNumber class]]
		? [entry[@"sent_message_count"] integerValue]
		: 0;
	NSInteger characters = [entry[@"average_character_count"]
							   isKindOfClass:[NSNumber class]]
		? [entry[@"average_character_count"] integerValue]
		: 0;

	UILabel *nameLabel = (UILabel *)[cell.contentView viewWithTag:22];
	nameLabel.text = name;
	nameLabel.textColor = [[TGTheme shared] primaryTextColour];

	UILabel *subtitle = (UILabel *)[cell.contentView viewWithTag:24];
	subtitle.text = characters > 0
		? TGLPlural(@"Stats.GroupTopPosterChars", characters, @"%ld symbol per message", @"%ld symbols per message")
		: nil;

	UILabel *count = (UILabel *)[cell.contentView viewWithTag:25];
	count.text = messages > 0 ? [NSString stringWithFormat:@"%ld", (long)messages] : @"";

	UIImageView *avatar = (UIImageView *)[cell.contentView viewWithTag:21];
	avatar.image = [TGIcons avatarWithInitials:TGProfileInitial(name)
										  size:40
									  colourId:userId];

	NSInteger largest = [self largestSenderCount];
	CGFloat available = cell.contentView.bounds.size.width - 54 - 70;
	CGFloat barWidth = (largest > 0 && messages > 0)
		? floorf(available * messages / (CGFloat)largest)
		: 0;
	UIView *bar = [cell.contentView viewWithTag:23];
	bar.frame = CGRectMake(54, 25, MAX(barWidth, messages > 0 ? 2 : 0), 4);
	return cell;
}

- (UITableViewCell *)makeChartCell:(UITableView *)tableView {
	UITableViewCell *cell = [[UITableViewCell alloc]
		  initWithStyle:UITableViewCellStyleDefault
		reuseIdentifier:@"chart"];

	TGProfileChartView *chart = [[TGProfileChartView alloc] initWithFrame:
			CGRectMake(0, 0, tableView.bounds.size.width, kStatsChartHeight)];
	chart.tag = 30;
	chart.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[cell.contentView addSubview:chart];

	UILabel *errorLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(15, 0, tableView.bounds.size.width - 30, kStatsRowHeight)];
	errorLabel.tag = 31;
	errorLabel.numberOfLines = 2;
	errorLabel.backgroundColor = [UIColor clearColor];
	errorLabel.font = [UIFont systemFontOfSize:14];
	errorLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[cell.contentView addSubview:errorLabel];
	return cell;
}

- (UITableViewCell *)extraGraphCell:(UITableView *)tableView atIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"chart"];
	if (!cell)
		cell = [self makeChartCell:tableView];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;

	NSDictionary *entry = [self extraGraphForSection:indexPath.section];
	TGProfileChartView *chart = (TGProfileChartView *)[cell.contentView viewWithTag:30];
	UILabel *errorLabel = (UILabel *)[cell.contentView viewWithTag:31];
	errorLabel.textColor = [[TGTheme shared] secondaryTextColour];

	NSArray *points = [entry[@"points"] isKindOfClass:[NSArray class]] ? entry[@"points"] : nil;
	if (points.count) {
		chart.hidden = NO;
		errorLabel.hidden = YES;
		chart.points = points;
		chart.leftDate = TGProfileText(entry[@"leftDate"]);
		chart.rightDate = TGProfileText(entry[@"rightDate"]);
	} else {
		chart.hidden = YES;
		errorLabel.hidden = NO;
		errorLabel.text = [NSString stringWithFormat:
				TGL(@"Stats.Graph.CouldNotLoad", @"Could not load: %@"),
				TGProfileText(entry[@"error"]) ?: @""];
	}
	return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.mode == 1 && indexPath.section == 0)
		return [self posterCell:tableView row:indexPath.row];
	if (self.mode == 0 && indexPath.section == [self recentInteractionsSectionIndex])
		return [self recentInteractionCell:tableView row:indexPath.row];
	if (self.mode == 0 && indexPath.section > 0)
		return [self extraGraphCell:tableView atIndexPath:indexPath];

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"stat"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:@"stat"];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.textLabel.font = [UIFont systemFontOfSize:17];
	cell.textLabel.textColor = [[TGTheme shared] groupedInfoColour];
	cell.detailTextLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];

	if (self.mode == 1) {
		[self fillPeopleCell:cell atIndexPath:indexPath];
		return cell;
	}

	if (self.mode == 2) {
		[self fillBoostCell:cell atIndexPath:indexPath];
		return cell;
	}

	id raw = indexPath.row < (NSInteger)self.values.count
		? self.values[indexPath.row]
		: nil;
	NSDictionary *entry = [raw isKindOfClass:[NSDictionary class]] ? raw : @{};
	cell.textLabel.text = TGProfileText(entry[@"title"])
		?: (TGProfileText(entry[@"key"]) ?: @"");
	NSString *growth = [self growthTextFor:entry];
	if (growth)
		cell.detailTextLabel.text = [NSString stringWithFormat:@"%@  %@",
			[self valueTextFor:entry], growth];
	else
		cell.detailTextLabel.text = [self valueTextFor:entry];
	return cell;
}

- (void)fillPeopleCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
	NSArray *people = [self peopleForSection:indexPath.section];
	id raw = indexPath.row < (NSInteger)people.count ? people[indexPath.row] : nil;
	NSDictionary *entry = [raw isKindOfClass:[NSDictionary class]] ? raw : @{};
	int64_t userId = TGProfileInt64(entry[@"user_id"]);
	NSString *clientName = TGProfileText([[TGClient shared] nameForUserId:userId]) ?: @"";
	NSString *name = TGProfileText(entry[@"name"]) ?: clientName;
	cell.selectionStyle = userId ? UITableViewCellSelectionStyleBlue
								 : UITableViewCellSelectionStyleNone;
	cell.textLabel.text = name;
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
	cell.detailTextLabel.text = [self peopleSummaryFor:entry
											   section:indexPath.section];
}

- (void)fillBoostCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 0) {
		NSArray *rows = [self boostSummaryRows];
		NSArray *pair = indexPath.row < (NSInteger)rows.count
			? rows[indexPath.row]
			: nil;
		cell.textLabel.text = pair.count ? pair[0] : @"";
		cell.detailTextLabel.text = pair.count > 1 ? pair[1] : nil;
		return;
	}
	id raw = indexPath.row < (NSInteger)self.boosters.count
		? self.boosters[indexPath.row]
		: nil;
	NSDictionary *entry = [raw isKindOfClass:[NSDictionary class]] ? raw : @{};
	BOOL unclaimed = [entry[@"is_unclaimed"] isKindOfClass:[NSNumber class]] && [entry[@"is_unclaimed"] boolValue];
	NSString *name = nil;
	if (!unclaimed) {
		name = TGProfileText(entry[@"name"]);
		if (!name) {
			int64_t userId = TGProfileInt64(entry[@"user_id"]);
			name = userId ? TGProfileText([[TGClient shared] nameForUserId:userId]) : nil;
		}
	}
	NSString *source = TGProfileText(entry[@"source"]);
	if (unclaimed)
		cell.textLabel.text = TGL(@"Stats.Boosts.Unclaimed", @"Unclaimed");
	else
		cell.textLabel.text = name ?: ([source isEqualToString:@"giveaway"] ? TGL(@"Message.Giveaway", @"Giveaway") : TGL(@"Stats.Boosts.Unclaimed", @"Unclaimed"));
	NSInteger count = [entry[@"count"] isKindOfClass:[NSNumber class]]
		? [entry[@"count"] integerValue]
		: 0;
	cell.detailTextLabel.text = count > 1
		? [NSString stringWithFormat:@"%ld", (long)count]
		: nil;
}

- (UITableViewCell *)recentInteractionCell:(UITableView *)tableView row:(NSInteger)row {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"recent"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"recent"];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	cell.textLabel.font = [UIFont systemFontOfSize:15];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];

	id raw = row < (NSInteger)self.recentInteractions.count ? self.recentInteractions[row] : nil;
	NSDictionary *entry = [raw isKindOfClass:[NSDictionary class]] ? raw : @{};
	long long messageId = [entry[@"message_id"] isKindOfClass:[NSNumber class]]
		? [entry[@"message_id"] longLongValue]
		: 0;
	long long storyId = [entry[@"story_id"] isKindOfClass:[NSNumber class]]
		? [entry[@"story_id"] longLongValue]
		: 0;
	cell.textLabel.text = storyId
		? [NSString stringWithFormat:TGL(@"Stats.RecentPostStory", @"Story #%lld"), storyId]
		: [NSString stringWithFormat:TGL(@"Stats.RecentPostMessage", @"Message #%lld"), messageId];
	cell.detailTextLabel.text = [self recentInteractionSummaryFor:entry];
	return cell;
}

- (NSString *)recentInteractionSummaryFor:(NSDictionary *)entry {
	NSMutableArray *parts = [NSMutableArray array];
	NSInteger views = [entry[@"view_count"] isKindOfClass:[NSNumber class]]
		? [entry[@"view_count"] integerValue]
		: 0;
	NSInteger shares = [entry[@"forward_count"] isKindOfClass:[NSNumber class]]
		? [entry[@"forward_count"] integerValue]
		: 0;
	NSInteger reactions = [entry[@"reaction_count"] isKindOfClass:[NSNumber class]]
		? [entry[@"reaction_count"] integerValue]
		: 0;
	if (views > 0)
		[parts addObject:TGLPlural(@"Stats.RecentPostViews", views, @"%ld view", @"%ld views")];
	if (shares > 0)
		[parts addObject:TGLPlural(@"Stats.RecentPostShares", shares, @"%ld share", @"%ld shares")];
	if (reactions > 0)
		[parts addObject:TGLPlural(@"Stats.RecentPostReactions", reactions, @"%ld reaction", @"%ld reactions")];
	return parts.count ? [parts componentsJoinedByString:@", "] : nil;
}

- (void)openRecentInteractionAtRow:(NSInteger)row {
	id raw = row < (NSInteger)self.recentInteractions.count ? self.recentInteractions[row] : nil;
	NSDictionary *entry = [raw isKindOfClass:[NSDictionary class]] ? raw : nil;
	if (!entry)
		return;
	UINavigationController *navigation = self.navigationController;
	if (!navigation)
		return;
	long long storyId = [entry[@"story_id"] isKindOfClass:[NSNumber class]]
		? [entry[@"story_id"] longLongValue]
		: 0;
	if (storyId) {
		TGStoryStatisticsViewController *stats = [[TGStoryStatisticsViewController alloc] init];
		stats.chatId = self.chatId;
		stats.storyId = (NSInteger)storyId;
		[navigation pushViewController:stats animated:YES];
		return;
	}
	long long messageId = [entry[@"message_id"] isKindOfClass:[NSNumber class]]
		? [entry[@"message_id"] longLongValue]
		: 0;
	if (!messageId)
		return;
	TGMessageStatisticsViewController *stats = [[TGMessageStatisticsViewController alloc] init];
	stats.chatId = self.chatId;
	stats.messageId = messageId;
	[navigation pushViewController:stats animated:YES];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (self.mode == 0 && indexPath.section == [self recentInteractionsSectionIndex]) {
		[self openRecentInteractionAtRow:indexPath.row];
		return;
	}
	if (self.mode != 1)
		return;
	NSArray *people = [self peopleForSection:indexPath.section];
	id raw = indexPath.row < (NSInteger)people.count ? people[indexPath.row] : nil;
	if (![raw isKindOfClass:[NSDictionary class]])
		return;
	int64_t userId = TGProfileInt64([raw objectForKey:@"user_id"]);
	if (!userId)
		return;
	NSString *clientName = TGProfileText([[TGClient shared] nameForUserId:userId]) ?: @"";
	NSString *name = TGProfileText([raw objectForKey:@"name"]) ?: clientName;
	UINavigationController *navigation = self.navigationController;
	if (!navigation)
		return;
	[[TGClient shared] privateChatWithUser:userId completion:^(int64_t chatId) {
		[TGProfileViewController showProfileForChatId:chatId
											   userId:userId
												title:name
										 inNavigation:navigation];
	}];
}

@end

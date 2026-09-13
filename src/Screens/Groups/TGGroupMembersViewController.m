#import "TGGroupMembersViewController.h"
#import "TGDateUtils.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGPopupMenu.h"
#import "TGAlertView.h"
#import "TGImageDecode.h"
#import "UIView+SafeTint.h"
#import <QuartzCore/QuartzCore.h>
#import "TGGroupMembersViewControllerInternal.h"
#import "TGMembersStatusText.h"
#import "TGMemberRightsViewController.h"
#import "TGGroupAddMembersViewController.h"
#import "TGGroupPublicLinkViewController.h"
#import "TGGroupMemberCell.h"

const CGFloat kGroupMemberRowHeight = 51.0f;
const CGFloat kMemberAvatarLeft = 5.0f;
const CGFloat kMemberAvatarTop = 5.0f;
const CGFloat kMemberTextLeft = 54.0f;
const CGFloat kSectionHeaderHeight = 25.0f;
const CGFloat kModeBarHeight = 44.0f;
const CGFloat kGroupButtonHeight = 30.0f;
const CGFloat kGroupSeparatorWidth = 2.0f;
const CGFloat kGroupSideInset = 8.0f;
const NSInteger kMemberPageSize = 50;
const NSInteger kMemberPhotoPrefetchRows = 10;
const NSInteger kMemberPhotoRetainRows = 30;
const NSInteger kMemberDurationDay = 86400;
const NSInteger kMemberDurationWeek = 604800;
const NSInteger kMemberDurationMonth = 2592000;

NSString *TGMembersDurationText(NSInteger untilDate) {
	if (untilDate <= 0)
		return TGL(@"MessageTimer.Forever", @"Forever");
	return [TGDateUtils stringForDateAndTime:(int)untilDate];
}

UIImage *TGMembersStretch(NSString *name, int leftCap) {
	UIImage *raw = [UIImage imageNamed:name];
	if (!raw)
		return nil;
	return [raw stretchableImageWithLeftCapWidth:leftCap topCapHeight:0];
}

@implementation TGGroupMembersViewController

- (void)dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[TGPopupMenu dismiss];
	if (_chatMemberObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_chatMemberObserverToken];
	if (_userStatusObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_userStatusObserverToken];
}

#pragma mark - modes

- (NSArray *)modeTitles {
	return [NSArray arrayWithObjects:TGL(@"Compose.ChannelMembers", @"Members"),
		TGL(@"Channel.Management.Title", @"Admins"),
		TGL(@"GroupMembers.ModeBanned", @"Banned"),
		TGL(@"GroupMembers.ModeRestricted", @"Restricted"), nil];
}

- (NSString *)listFilterForMode:(NSInteger)mode {
	switch (mode) {
		case 1:
			return @"administrators";
		case 2:
			return @"banned";
		case 3:
			return @"restricted";
		default:
			return @"recent";
	}
}

- (NSString *)searchFilterForMode:(NSInteger)mode {
	switch (mode) {
		case 1:
			return @"administrators";
		case 2:
			return @"banned";
		case 3:
			return @"restricted";
		default:
			return @"members";
	}
}

- (NSString *)emptyTextForMode:(NSInteger)mode {
	switch (mode) {
		case 1:
			return TGL(@"GroupMembers.EmptyAdmins", @"No administrators");
		case 2:
			return TGL(@"GroupMembers.EmptyBanned", @"No removed users");
		case 3:
			return TGL(@"GroupMembers.EmptyRestricted", @"No restricted users");
		default:
			return TGL(@"GroupMembers.EmptyMembers", @"No members");
	}
}

- (NSString *)emptyHelpForMode:(NSInteger)mode {
	switch (mode) {
		case 1:
			return TGL(@"GroupMembers.EmptyHelpAdmins", @"Nobody here has been promoted yet. Hold a member to give them admin rights.");
		case 2:
			return TGL(@"GroupMembers.EmptyHelpBanned", @"Nobody has been removed from this group.");
		case 3:
			return TGL(@"GroupMembers.EmptyHelpRestricted", @"Nobody here is restricted. Hold a member to limit what they may do.");
		default:
			return TGL(@"GroupMembers.EmptyHelpMembers", @"Nobody else is in this group yet.");
	}
}

- (BOOL)hasSearchQuery {
	return [[self.query stringByTrimmingCharactersInSet:
				   [NSCharacterSet whitespaceAndNewlineCharacterSet]] length] != 0;
}

- (NSString *)sectionCaptionForMode:(NSInteger)mode {
	if ([self hasSearchQuery])
		return TGL(@"GroupMembers.SectionSearchResults", @"SEARCH RESULTS");
	switch (mode) {
		case 1:
			return TGL(@"GroupMembers.SectionAdministrators", @"ADMINISTRATORS");
		case 2:
			return TGL(@"GroupRemoved.UsersSectionTitle", @"REMOVED USERS");
		case 3:
			return TGL(@"GroupMembers.SectionRestrictedUsers", @"RESTRICTED USERS");
		default:
			return TGL(@"GroupMembers.SectionMembers", @"MEMBERS");
	}
}

#pragma mark - lifecycle

- (void)viewDidLoad {
	[super viewDidLoad];

	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	self.title = TGL(@"Compose.ChannelMembers", @"Members");
	NSInteger modeCount = (NSInteger)[self modeTitles].count;
	self.mode = (self.initialMode >= 0 && self.initialMode < modeCount)
		? self.initialMode
		: 0;
	self.members = [NSArray array];
	[self setUpAvatarPrefetcher];
	_presenter = [[TGGroupMembersPresenter alloc] init];
	_rowBridge = [[TGGroupMembersRowBridge alloc] initWithPresenter:_presenter];
	_rowBridge.delegate = self;
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];

	CGRect bounds = self.view.bounds;

	_modeBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, kModeBarHeight)];
	_modeBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	UIImage *plate = TGMembersStretch(@"Footer.png", 1);
	if (plate)
		_modeBar.backgroundColor = [UIColor colorWithPatternImage:plate];
	else
		_modeBar.backgroundColor = [[TGTheme shared] inputBarColour];
	[self.view addSubview:_modeBar];

	UIView *hairline = [[UIView alloc] initWithFrame:
			CGRectMake(0, kModeBarHeight - 1, bounds.size.width, 1)];
	hairline.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	hairline.backgroundColor = [[TGTheme shared] separatorColour];
	[_modeBar addSubview:hairline];

	[self buildModeButtons];

	CGRect tableFrame = CGRectMake(0, kModeBarHeight, bounds.size.width, bounds.size.height - kModeBarHeight);
	self.tableView = [[UITableView alloc] initWithFrame:tableFrame style:UITableViewStylePlain];
	self.tableView.autoresizingMask =
		UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.tableView.dataSource = self;
	self.tableView.delegate = self;
	self.tableView.rowHeight = kGroupMemberRowHeight;
	self.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tableView.separatorColor = [[TGTheme shared] separatorColour];
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	[self.view addSubview:self.tableView];
	self.avatarPrefetcher.tableView = self.tableView;

	self.searchBar = [[UISearchBar alloc] initWithFrame:
			CGRectMake(0, 0, bounds.size.width, 44)];
	self.searchBar.delegate = self;
	self.searchBar.placeholder = TGL(@"Common.Search", @"Search");
	if ([self.searchBar respondsToSelector:@selector(setBarTintColor:)])
		self.searchBar.barTintColor = [[TGTheme shared] listBackgroundColour];
	else
		[self.searchBar tg_setTintColor:[UIColor colorWithWhite:0.68f alpha:1.0f]];
	self.tableView.tableHeaderView = self.searchBar;

	UIView *background = [[UIView alloc] initWithFrame:self.tableView.bounds];
	background.backgroundColor = [[TGTheme shared] listBackgroundColour];
	background.autoresizingMask =
		UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

	self.statusLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(0, 110, background.bounds.size.width, 22)];
	self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.statusLabel.backgroundColor = [UIColor clearColor];
	self.statusLabel.textAlignment = NSTextAlignmentCenter;
	self.statusLabel.font = [UIFont systemFontOfSize:15];
	self.statusLabel.textColor = [[TGTheme shared] secondaryTextColour];
	self.statusLabel.hidden = YES;
	[background addSubview:self.statusLabel];

	self.emptyPlaceholder = [[UIView alloc] initWithFrame:
			CGRectMake(0, (CGFloat)(int)((background.bounds.size.height - 70) / 2) - 40,
				background.bounds.size.width, 70)];
	self.emptyPlaceholder.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
	self.emptyPlaceholder.backgroundColor = [UIColor clearColor];
	self.emptyPlaceholder.hidden = YES;

	UIColor *placeholderColour =
		[UIColor colorWithRed:0x86 / 255.0f green:0x94 / 255.0f blue:0xa4 / 255.0f alpha:1.0f];

	self.emptyTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.emptyTitleLabel.backgroundColor = [UIColor clearColor];
	self.emptyTitleLabel.font = [UIFont boldSystemFontOfSize:14];
	self.emptyTitleLabel.textColor = placeholderColour;
	self.emptyTitleLabel.shadowColor = [UIColor colorWithWhite:1.0f alpha:0.5f];
	self.emptyTitleLabel.shadowOffset = CGSizeMake(0, 1);
	self.emptyTitleLabel.textAlignment = NSTextAlignmentCenter;
	[self.emptyPlaceholder addSubview:self.emptyTitleLabel];

	self.emptyHelpLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.emptyHelpLabel.backgroundColor = [UIColor clearColor];
	self.emptyHelpLabel.font = [UIFont systemFontOfSize:14];
	self.emptyHelpLabel.textColor = placeholderColour;
	self.emptyHelpLabel.shadowColor = [UIColor colorWithWhite:1.0f alpha:0.5f];
	self.emptyHelpLabel.shadowOffset = CGSizeMake(0, 1);
	self.emptyHelpLabel.textAlignment = NSTextAlignmentCenter;
	self.emptyHelpLabel.numberOfLines = 0;
	[self.emptyPlaceholder addSubview:self.emptyHelpLabel];

	[background addSubview:self.emptyPlaceholder];

	self.retryButton = [TGIcons headerButtonWithTitle:TGL(@"Conversation.MessageDialogRetry", @"Resend") bold:NO
											   target:self
											   action:@selector(reload)];
	self.retryButton.center = CGPointMake(background.bounds.size.width / 2, 150);
	self.retryButton.autoresizingMask =
		UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	self.retryButton.hidden = YES;
	[background addSubview:self.retryButton];

	self.spinner = [[UIActivityIndicatorView alloc]
		initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	self.spinner.center = CGPointMake(background.bounds.size.width / 2, 84);
	self.spinner.autoresizingMask =
		UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	self.spinner.hidesWhenStopped = YES;
	[background addSubview:self.spinner];

	self.tableView.backgroundView = background;

	UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(handleLongPress:)];
	hold.minimumPressDuration = 0.4f;
	[self.tableView addGestureRecognizer:hold];

	[self loadGroupInfo];
	[self reload];
	[self observeChatMemberUpdates];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[TGPopupMenu dismiss];
}

#pragma mark - mode button group

- (void)buildModeButtons {
	_groupButtons = [[NSMutableArray alloc] init];
	_groupSeparators = [[NSMutableArray alloc] init];

	NSArray *titles = [self modeTitles];
	CGFloat width = self.view.bounds.size.width - kGroupSideInset * 2;
	CGFloat originY = (CGFloat)(int)((kModeBarHeight - kGroupButtonHeight) / 2);

	UIView *group = [[UIView alloc] initWithFrame:
			CGRectMake(kGroupSideInset, originY, width, kGroupButtonHeight)];
	group.autoresizingMask = UIViewAutoresizingFlexibleWidth;

	NSInteger count = (NSInteger)titles.count;
	CGFloat usable = width - kGroupSeparatorWidth * (count - 1);
	CGFloat buttonWidth = (CGFloat)(int)(usable / count);

	UIColor *shadowColour = [UIColor colorWithRed:0x0e / 255.0f green:0x28 / 255.0f
											 blue:0x4d / 255.0f
											alpha:0.4f];

	CGFloat currentX = 0;
	for (NSInteger i = 0; i < count; i++) {
		CGFloat thisWidth = (i == count - 1) ? (width - currentX) : buttonWidth;

		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.exclusiveTouch = YES;
		button.frame = CGRectMake(currentX, 0, thisWidth, kGroupButtonHeight);
		button.tag = i;
		[button setTitle:[titles objectAtIndex:(NSUInteger)i] forState:UIControlStateNormal];
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
		[group addSubview:button];
		[_groupButtons addObject:button];

		currentX += thisWidth;

		if (i + 1 < count) {
			UIView *separator = [[UIView alloc] initWithFrame:
					CGRectMake(currentX, 0, kGroupSeparatorWidth, kGroupButtonHeight)];
			NSArray *names = [NSArray arrayWithObjects:@"ButtonGroupDivider.png",
				@"ButtonGroupDivider_LeftHighlighted.png",
				@"ButtonGroupDivider_RightHighlighted.png", nil];
			for (NSInteger j = 0; j < names.count; j++) {
				UIImage *art = TGMembersStretch([names objectAtIndex:j], 6);
				UIImageView *layer = [[UIImageView alloc] initWithImage:art];
				layer.tag = (NSInteger)(100 + j);
				layer.frame = separator.bounds;
				layer.alpha = (j == 0) ? 1.0f : 0.0f;
				[separator addSubview:layer];
			}
			[group addSubview:separator];
			[_groupSeparators addObject:separator];
			currentX += kGroupSeparatorWidth;
		}
	}

	[_modeBar addSubview:group];
	[self updateModeButtons];
}

- (void)updateModeButtons {
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

		UIImage *normal = TGMembersStretch(normalName, leftCap);
		UIImage *highlighted = TGMembersStretch(highlightedName, leftCap);
		UIImage *shown = ((NSInteger)i == self.mode) ? highlighted : normal;
		[button setBackgroundImage:shown forState:UIControlStateNormal];
		[button setBackgroundImage:shown forState:UIControlStateHighlighted];
		if (!normal)
			button.backgroundColor = ((NSInteger)i == self.mode)
				? [[TGTheme shared] accentColour]
				: [UIColor colorWithWhite:0.62f alpha:1.0f];
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

- (void)modeButtonPressed:(UIButton *)button {
	if (self.mode == button.tag)
		return;
	self.mode = button.tag;
	[self updateModeButtons];
	[self.tableView setContentOffset:CGPointZero animated:NO];
	[self reload];
}

@end

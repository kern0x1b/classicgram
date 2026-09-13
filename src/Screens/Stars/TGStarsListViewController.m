#import "TGListBackground.h"
#import "TGStarsListViewController.h"
#import "TGStarsViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGStarsListPresenter.h"
#import "TGStarsListRowBridge.h"
#import "TGStarsListBadgeSubtitleCell.h"
#import "TGHexColour.h"

static const CGFloat kStarsListTabBarHeight = 36;

@interface TGStarsListViewController ()
@property (nonatomic, strong) TGStarsListPresenter *rowPresenter;
@property (nonatomic, strong) TGStarsListRowBridge *rowBridge;
@property (nonatomic, strong) UIView *tabBar;
@property (nonatomic, strong) NSMutableArray *tabButtons;
@end

@implementation TGStarsListViewController

- (id)initWithTitle:(NSString *)title {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		self.title = title;
		self.rows = [NSMutableArray array];
		self.emptyText = TGL(@"Stars.NothingHere", @"Nothing Here");
		self.rowPresenter = [[TGStarsListPresenter alloc] init];
		self.rowBridge = [[TGStarsListRowBridge alloc] initWithPresenter:self.rowPresenter];
	}
	return self;
}

- (void)syncRowPresenter {
	[self.rowPresenter updateWithRows:self.rows
							  loading:self.loading
						moreAvailable:self.moreAvailable
							emptyText:self.emptyText];
}

- (void)loadView {
	if (!self.tabTitles.count) {
		[super loadView];
		return;
	}
	CGRect bounds = [UIScreen mainScreen].bounds;
	UIView *container = [[UIView alloc] initWithFrame:bounds];
	container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.view = container;
	UITableView *table = [[UITableView alloc] initWithFrame:bounds style:UITableViewStyleGrouped];
	table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	table.delegate = self;
	table.dataSource = self;
	self.tableView = table;
	[container addSubview:table];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	if (self.navigationController.navigationBar)
		[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	[self buildTabBarIfNeeded];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	if (!self.tabTitles.count)
		return;
	CGFloat width = self.view.bounds.size.width;
	self.tabBar.frame = CGRectMake(0, 0, width, kStarsListTabBarHeight);
	[self layoutTabBar];
	self.tableView.frame = CGRectMake(0, kStarsListTabBarHeight, width,
		self.view.bounds.size.height - kStarsListTabBarHeight);
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if ([self.tableView indexPathForSelectedRow])
		[self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow]
									  animated:animated];
}

- (void)buildTabBarIfNeeded {
	if (!self.tabTitles.count || self.tabBar)
		return;
	CGFloat width = self.view.bounds.size.width;
	if (width < 1)
		width = [UIScreen mainScreen].bounds.size.width;
	self.tabBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, kStarsListTabBarHeight)];
	self.tabBar.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tabBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.tabButtons = [NSMutableArray array];
	for (NSInteger i = 0; i < self.tabTitles.count; i++) {
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.tag = (NSInteger)i;
		button.titleLabel.font = [UIFont boldSystemFontOfSize:13];
		button.titleLabel.adjustsFontSizeToFitWidth = YES;
		button.titleLabel.minimumFontSize = 9;
		[button setTitle:self.tabTitles[i] forState:UIControlStateNormal];
		[button addTarget:self action:@selector(tabButtonTapped:)
			forControlEvents:UIControlEventTouchUpInside];
		[self styleTabButton:button selected:((NSInteger)i == self.selectedTabIndex)];
		[self.tabBar addSubview:button];
		[self.tabButtons addObject:button];
	}
	UIView *separator = [[UIView alloc] initWithFrame:
		CGRectMake(0, kStarsListTabBarHeight - 1, width, 1)];
	separator.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
	separator.backgroundColor = [[TGTheme shared] separatorColour];
	[self.tabBar addSubview:separator];
	[self.view addSubview:self.tabBar];
	[self layoutTabBar];
}

- (void)layoutTabBar {
	if (!self.tabBar)
		return;
	CGFloat width = self.view.bounds.size.width;
	if (width < 1)
		width = [UIScreen mainScreen].bounds.size.width;
	CGRect barFrame = self.tabBar.frame;
	barFrame.size.width = width;
	self.tabBar.frame = barFrame;
	NSInteger count = self.tabButtons.count;
	if (!count)
		return;
	CGFloat margin = 6;
	CGFloat available = width - margin * (count + 1);
	CGFloat each = (CGFloat)(int)(available / count);
	CGFloat x = margin;
	for (NSInteger i = 0; i < count; i++) {
		UIButton *button = self.tabButtons[i];
		CGFloat buttonWidth = (i == count - 1) ? (width - margin - x) : each;
		button.frame = CGRectMake(x, 4, buttonWidth, kStarsListTabBarHeight - 9);
		x += buttonWidth + margin;
	}
}

- (void)styleTabButton:(UIButton *)button selected:(BOOL)selected {
	if (selected) {
		button.backgroundColor = [[TGTheme shared] accentColour];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	} else {
		button.backgroundColor = [UIColor clearColor];
		[button setTitleColor:[[TGTheme shared] accentColour] forState:UIControlStateNormal];
	}
}

- (void)tabButtonTapped:(UIButton *)sender {
	if (sender.tag == self.selectedTabIndex)
		return;
	self.selectedTabIndex = sender.tag;
	for (UIButton *button in self.tabButtons)
		[self styleTabButton:button selected:(button.tag == self.selectedTabIndex)];
	if (self.onTabSelected)
		self.onTabSelected(self.selectedTabIndex);
}

- (void)appendRow:(NSDictionary *)row {
	if (row)
		[self.rows addObject:row];
}

- (void)finishLoadingWithMore:(BOOL)more {
	self.loading = NO;
	self.moreAvailable = more;
	[self.tableView reloadData];
	TGStarsListViewController *mirror = self.mirrorTarget;
	if (mirror && mirror != self) {
		mirror.loading = NO;
		mirror.moreAvailable = more;
		mirror.loadMoreBlock = self.loadMoreBlock;
		[mirror.tableView reloadData];
	}
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (!self.rows.count)
		return 1;
	return (NSInteger)self.rows.count + (self.moreAvailable ? 1 : 0);
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row < (NSInteger)self.rows.count && self.rows[indexPath.row][@"subtitle"])
		return 51;
	return 44;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return 8;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	if (!self.comment.length)
		return 8;
	return TGStarsCommentHeight(self.comment, tableView.bounds.size.width ?: [UIScreen mainScreen].bounds.size.width);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	return TGStarsCommentViewWithText(self.comment, tableView.bounds.size.width ?: [UIScreen mainScreen].bounds.size.width);
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	[self syncRowPresenter];
	if ([self.rowBridge ownsRowAtIndex:indexPath.row])
		return [self.rowBridge cellForRow:indexPath.row inTable:tableView];

	if (!self.rows.count || indexPath.row >= (NSInteger)self.rows.count) {
		static NSString *statusId = @"TGStarsListStatus";
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:statusId];
		if (!cell)
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
										  reuseIdentifier:statusId];
		BOOL isMore = self.rows.count > 0;
		cell.textLabel.textAlignment = isMore ? NSTextAlignmentLeft : NSTextAlignmentCenter;
		cell.textLabel.font = [UIFont boldSystemFontOfSize:isMore ? 17 : 14];
		if (self.loading) {
			cell.textLabel.text = TGL(@"Channel.NotificationLoading", @"Loading…");
			cell.textLabel.textColor = [[TGTheme shared] secondaryTextColour];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
		} else if (isMore) {
			cell.textLabel.text = TGL(@"Chat.RichText.ShowMore", @"Show more");
			cell.textLabel.textColor = [[TGTheme shared] groupedActionColour];
			cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		} else {
			cell.textLabel.text = self.emptyText;
			cell.textLabel.textColor = [[TGTheme shared] emptyStateColour];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
		}
		cell.accessoryType = UITableViewCellAccessoryNone;
		[[TGTheme shared] styleCell:cell];
		return cell;
	}

	NSDictionary *row = self.rows[indexPath.row];
	NSString *subtitle = row[@"subtitle"];
	NSString *badge = row[@"badge"];
	if (badge.length) {
		static NSString *badgeId = @"TGStarsListBadgeSubtitle";
		TGStarsListBadgeSubtitleCell *badgeCell = (TGStarsListBadgeSubtitleCell *)
			[tableView dequeueReusableCellWithIdentifier:badgeId];
		if (!badgeCell)
			badgeCell = [[TGStarsListBadgeSubtitleCell alloc] initWithStyle:UITableViewCellStyleDefault
															 reuseIdentifier:badgeId];
		BOOL badgeTappable = row[@"block"] != nil;
		[badgeCell applyTitle:row[@"title"]
					badgeText:badge
				   detailText:subtitle
				  destructive:[row[@"destructive"] boolValue]
					 tappable:badgeTappable];
		badgeCell.accessoryType = UITableViewCellAccessoryNone;
		return badgeCell;
	}
	NSString *reuseId = subtitle.length ? @"TGStarsListSubtitle" : @"TGStarsListValue";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseId];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:subtitle.length
				? UITableViewCellStyleSubtitle
				: UITableViewCellStyleValue1
									  reuseIdentifier:reuseId];
	cell.textLabel.text = row[@"title"];
	cell.textLabel.textAlignment = NSTextAlignmentLeft;
	cell.textLabel.font = [UIFont systemFontOfSize:16];
	cell.textLabel.textColor = [row[@"destructive"] boolValue]
		? [[TGTheme shared] groupedDestructiveColour]
		: [[TGTheme shared] primaryTextColour];
	cell.detailTextLabel.text = subtitle.length ? subtitle : row[@"value"];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:subtitle.length ? 13 : 16];
	cell.detailTextLabel.textColor = subtitle.length
		? TGColourFromHex(0x888888)
		: TGColourFromHex(0x356596);
	BOOL tappable = row[@"block"] != nil;
	cell.accessoryType = (tappable && !subtitle.length && !row[@"value"])
		? UITableViewCellAccessoryDisclosureIndicator
		: UITableViewCellAccessoryNone;
	cell.selectionStyle = tappable ? UITableViewCellSelectionStyleBlue
								   : UITableViewCellSelectionStyleNone;
	[[TGTheme shared] styleCell:cell];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (!self.rows.count)
		return;
	if (indexPath.row >= (NSInteger)self.rows.count) {
		if (self.loading || !self.loadMoreBlock)
			return;
		self.loading = YES;
		[tableView reloadData];
		self.loadMoreBlock();
		return;
	}
	void (^block)(void) = self.rows[indexPath.row][@"block"];
	if (block)
		block();
}

@end

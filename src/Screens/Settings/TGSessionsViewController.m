#import "TGGroupedCaption.h"
#import "TGIcons.h"
#import "TGListBackground.h"
#import "TGSessionsViewController.h"
#import "TGDateUtils.h"
#import "TGLocalization.h"
#import "TGClient+Privacy.h"
#import "TGClient+Account.h"
#import "TGTheme.h"
#import "TGActionSheet.h"
#import "TGQRViewController.h"
#import "TGSnackbar.h"
#import "TGAlertView.h"
#import "TGLoginLinkRecognition.h"
#import "TGHexColour.h"

@class TGSessionDetailViewController;

@protocol TGSessionDetailDelegate <NSObject>
- (void)sessionDetailDidChangeSessions:(TGSessionDetailViewController *)controller;
- (void)sessionDetail:(TGSessionDetailViewController *)controller didTerminateSession:(NSDictionary *)session;
@end

@interface TGSessionDetailViewController : UITableViewController
@property (nonatomic, weak) id<TGSessionDetailDelegate> detailDelegate;
- (instancetype)initWithSession:(NSDictionary *)session;
@end

static const NSInteger kSessionsHairlineTag = 7701;

static CGFloat TGSessionsRetinaPixel(void) {
	return [UIScreen mainScreen].scale > 1.0f ? 0.5f : 0.0f;
}

static void TGSessionsApplyBackground(UITableView *tableView) {
	tableView.backgroundView = nil;
	tableView.opaque = NO;
	tableView.backgroundColor = TGGroupedListBackground();
}

static UIView *TGSessionsHeaderView(NSString *title, CGFloat width) {
	return [[TGTheme shared] groupedHeaderViewWithTitle:title width:width];
}

static CGFloat TGSessionsCommentHeight(NSString *text, CGFloat width) {
	return [[TGTheme shared] groupedCommentHeightForText:text width:width];
}

static UIView *TGSessionsCommentView(NSString *text, CGFloat width) {
	return [[TGTheme shared] groupedCommentViewWithText:text width:width];
}

static UIView *TGSessionsDisclosureView(void) {
	UIImage *image = TGLocalizedDirectionalImage([UIImage imageNamed:@"MenuDisclosureIndicator.png"]);
	if (!image)
		return nil;
	UIImage *highlighted = TGLocalizedDirectionalImage([UIImage imageNamed:@"MenuDisclosureIndicator_Highlighted.png"]);
	UIImageView *view = [UIImageView alloc];
	view = [view initWithImage:image
			  highlightedImage:highlighted];
	view.frame = CGRectMake(0, 0, image.size.width, image.size.height);
	return view;
}

@interface TGSessionsViewController () <TGSessionDetailDelegate>
@property (nonatomic, strong) NSArray *sessions;
@property (nonatomic, strong) TGActionSheet *currentActionSheet;
@property (nonatomic, assign) long long pendingTermination;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL refreshing;
@property (nonatomic, assign) NSInteger ttlDays;
@property (nonatomic, weak) TGQRViewController *scanner;
@property (nonatomic, weak) UIView *loginToastView;
@property (nonatomic, assign) long long loginToastSessionId;
@property (nonatomic, strong) id unconfirmedSessionObserver;
@end

@implementation TGSessionsViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"Settings.Devices", @"Devices");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	TGSessionsApplyBackground(self.tableView);
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	TGApplyRTLTableMirroring(self.tableView);

	__weak typeof(self) weakSelf = self;
	self.unconfirmedSessionObserver = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGUnconfirmedSessionDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					[weakSelf refresh];
				}];

	[self refresh];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	if (self.currentActionSheet) {
		NSInteger cancelIndex = self.currentActionSheet.cancelButtonIndex;
		[self.currentActionSheet dismissWithClickedButtonIndex:cancelIndex animated:NO];
		self.currentActionSheet = nil;
	}
	[self dismissLoginToastAnimated:NO];
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(refresh)
											   object:nil];
}

- (void)dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	if (self.unconfirmedSessionObserver)
		[[NSNotificationCenter defaultCenter] removeObserver:self.unconfirmedSessionObserver];
}

- (void)refresh {
	if (self.refreshing)
		return;
	self.refreshing = YES;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] activeSessionsWithCompletion:^(NSArray *sessions, NSInteger inactiveTtlDays) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.refreshing = NO;
		strongSelf.loaded = YES;
		strongSelf.ttlDays = inactiveTtlDays;
		strongSelf.sessions = sessions ?: [NSArray array];
		[strongSelf.tableView reloadData];
	}];
}

- (NSString *)stringIn:(NSDictionary *)session forKey:(NSString *)key {
	id value = session[key];
	if (![value isKindOfClass:[NSString class]])
		return @"";
	return [value stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceCharacterSet]];
}

- (NSString *)titleForSession:(NSDictionary *)session {
	NSString *app = [self stringIn:session forKey:@"appName"];
	if (!app.length)
		app = [self stringIn:session forKey:@"name"];
	if (!app.length)
		app = TGL(@"AuthSessions.UnknownApplication", @"Unknown application");
	NSString *version = [self stringIn:session forKey:@"appVersion"];
	if (version.length)
		return [NSString stringWithFormat:@"%@ %@", app, version];
	return app;
}

- (NSString *)subtitleForSession:(NSDictionary *)session {
	NSString *device = [self stringIn:session forKey:@"deviceModel"];
	NSString *platform = [self stringIn:session forKey:@"platform"];
	NSString *ip = [self stringIn:session forKey:@"ip"];
	NSString *location = [self stringIn:session forKey:@"location"];

	NSMutableArray *first = [NSMutableArray array];
	if (device.length)
		[first addObject:device];
	if (platform.length)
		[first addObject:platform];

	NSMutableArray *second = [NSMutableArray array];
	if (ip.length)
		[second addObject:ip];
	if (location.length)
		[second addObject:location];

	if ([session[@"isCurrent"] boolValue]) {
		[second addObject:TGL(@"Presence.online", @"online")];
	} else if ([session[@"isUnconfirmed"] boolValue]) {
		[second addObject:TGL(@"AuthSessions.NotConfirmedBadge", @"Not confirmed")];
	} else {
		NSString *seen = [self lastActiveTextForSession:session];
		if (seen.length)
			[second addObject:seen];
	}

	NSMutableArray *lines = [NSMutableArray array];
	if (first.count)
		[lines addObject:[first componentsJoinedByString:@", "]];
	if (second.count)
		[lines addObject:[second componentsJoinedByString:@" - "]];
	return [lines componentsJoinedByString:@"\n"];
}

- (NSString *)lastActiveTextForSession:(NSDictionary *)session {
	long long stamp = [session[@"lastActive"] longLongValue];
	if (stamp <= 0)
		return nil;

	NSDate *date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)stamp];
	NSTimeInterval age = -[date timeIntervalSinceNow];
	if (age < 0)
		age = 0;

	if (age < 60)
		return TGL(@"Time.JustNow", @"just now");

	if (age < 60 * 60 * 12)
		return [TGDateUtils stringForShortTime:(int)stamp];
	return [TGDateUtils stringForShortDate:(int)stamp];
}

- (NSArray *)othersOnly {
	NSMutableArray *others = [NSMutableArray array];
	for (NSDictionary *session in self.sessions)
		if (![session[@"isCurrent"] boolValue])
			[others addObject:session];
	return others;
}

- (NSDictionary *)currentSession {
	for (NSDictionary *session in self.sessions)
		if ([session[@"isCurrent"] boolValue])
			return session;
	return nil;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	NSIndexPath *selected = [self.tableView indexPathForSelectedRow];
	if (selected)
		[self.tableView deselectRowAtIndexPath:selected animated:YES];
	if (self.loaded)
		[self refresh];
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 5;
}

- (NSString *)headerTitleForSection:(NSInteger)section {
	if (section == 1)
		return [self currentSession] ? TGL(@"AuthSessions.CurrentSession", @"This device") : nil;
	if (section == 2)
		return [self othersOnly].count
				   ? TGL(@"AuthSessions.OtherSessions", @"Active sessions")
				   : nil;
	if (section == 4)
		return self.loaded
				   ? TGL(@"AuthSessions.TerminateIfAwayTitle",
						 @"Automatically terminate old sessions")
				   : nil;
	return nil;
}

- (NSString *)footerTitleForSection:(NSInteger)section {
	if (section == 0)
		return TGL(@"AuthSessions.ScanFooter",
				   @"Scan the QR code shown by Telegram on a computer to log that computer in. You are asked to confirm before anything is sent."
					"in. You are asked to confirm before anything is sent.");
	if (section == 4) {
		if (!self.loaded)
			return nil;
		return TGL(@"AuthSessions.TerminateIfAwayFooter",
				   @"If you do not log in from another device for this period of time, that session ends by itself."
					"session ends by itself.");
	}
	if (section != 2)
		return nil;
	if (!self.loaded)
		return TGL(@"Channel.NotificationLoading", @"Loading…");
	if ([self othersOnly].count)
		return TGL(@"AuthSessions.TapToSeeDetails",
				   @"Tap a session to see its details, or swipe it away to terminate it.");
	return TGL(@"AuthSessions.NoOtherActiveSessions", @"You have no other active sessions.");
}

- (NSArray *)ttlOptions {
	return [NSArray arrayWithObjects:
			[NSNumber numberWithInteger:7],
		[NSNumber numberWithInteger:30],
		[NSNumber numberWithInteger:90],
		[NSNumber numberWithInteger:180], nil];
}

- (NSString *)ttlTitleForDays:(NSInteger)days {
	if (days <= 0)
		return TGL(@"AuthSessions.TerminateIfAwayNever", @"Never");
	if (days <= 7)
		return TGL(@"AuthSessions.TerminateIfAwayOneWeek", @"1 week");
	if (days <= 30)
		return TGL(@"AuthSessions.TerminateIfAwayOneMonth", @"1 month");
	if (days <= 90)
		return TGL(@"AuthSessions.TerminateIfAwayThreeMonths", @"3 months");
	return TGL(@"AuthSessions.TerminateIfAwaySixMonths", @"6 months");
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	NSString *title = [self headerTitleForSection:section];
	if (!title)
		return 14;
	return 46;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *title = [self headerTitleForSection:section];
	if (!title)
		return nil;
	UIView *header = TGSessionsHeaderView(title, tableView.bounds.size.width);
	TGApplyRTLHeaderMirroring(header);
	return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *title = [self footerTitleForSection:section];
	if (!title)
		return 1;
	return TGSessionsCommentHeight(title, tableView.bounds.size.width);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *title = [self footerTitleForSection:section];
	if (!title)
		return nil;
	UIView *footer = TGSessionsCommentView(title, tableView.bounds.size.width);
	TGApplyRTLHeaderMirroring(footer);
	return footer;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 0)
		return 44;
	if (indexPath.section == 3)
		return 45;
	if (indexPath.section == 4)
		return 44;
	return 58;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return 1;
	if (section == 1)
		return [self currentSession] ? 1 : 0;
	if (section == 2)
		return [self othersOnly].count;
	if (section == 4)
		return self.loaded ? 1 : 0;
	return [self othersOnly].count ? 1 : 0;
}

- (NSDictionary *)sessionAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 1)
		return [self currentSession];
	NSArray *others = [self othersOnly];
	if (indexPath.section == 2 && indexPath.row < (NSInteger)others.count)
		return others[indexPath.row];
	return nil;
}

- (UIImage *)redPlateHighlighted:(BOOL)highlighted {
	NSString *plate = highlighted ? @"MenuRedButton_Highlighted.png" : @"MenuRedButton.png";
	UIImage *image = [UIImage imageNamed:plate];
	if (!image)
		return nil;
	return [image stretchableImageWithLeftCapWidth:(int)(image.size.width / 2)
									  topCapHeight:(int)(image.size.height / 2)];
}

- (UITableViewCell *)terminateAllCellForTable:(UITableView *)tableView {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"action"];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"action"];
		cell.backgroundColor = [UIColor clearColor];
		cell.backgroundView = [[UIView alloc] init];
		cell.backgroundView.backgroundColor = [UIColor clearColor];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;

		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.tag = kSessionsHairlineTag + 1;
		button.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		UIImage *plate = [self redPlateHighlighted:NO];
		UIImage *platePressed = [self redPlateHighlighted:YES];
		if (plate)
			[button setBackgroundImage:plate forState:UIControlStateNormal];
		else
			button.backgroundColor = [[TGTheme shared] groupedDestructiveColour];
		if (platePressed)
			[button setBackgroundImage:platePressed forState:UIControlStateHighlighted];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
		UIColor *titleShadow = [UIColor colorWithRed:0xa1 / 255.0f
											   green:0x06 / 255.0f
												blue:0x03 / 255.0f
											   alpha:0.5f];
		[button setTitleShadowColor:titleShadow forState:UIControlStateNormal];
		[button setTitleShadowColor:titleShadow forState:UIControlStateHighlighted];
		button.titleLabel.font = [UIFont boldSystemFontOfSize:17];
		button.titleLabel.shadowOffset = CGSizeMake(0, -1);
		[button setTitle:TGL(@"AuthSessions.TerminateOtherSessions", @"Terminate All Other Sessions")
				forState:UIControlStateNormal];
		[button addTarget:self action:@selector(confirmTerminateAll)
			forControlEvents:UIControlEventTouchUpInside];
		[cell.contentView addSubview:button];
	}
	return cell;
}

- (UITableViewCell *)ttlCellForTable:(UITableView *)tableView {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ttl"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:@"ttl"];
	[[TGTheme shared] styleCell:cell];
	cell.textLabel.text = TGL(@"AuthSessions.TerminateIfAwayFor", @"If inactive for");
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.textLabel.highlightedTextColor = [UIColor whiteColor];
	cell.detailTextLabel.text = [self ttlTitleForDays:self.ttlDays];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	cell.detailTextLabel.highlightedTextColor = [UIColor whiteColor];
	UIView *disclosure = TGSessionsDisclosureView();
	if (disclosure) {
		cell.accessoryView = disclosure;
		cell.accessoryType = UITableViewCellAccessoryNone;
	} else {
		cell.accessoryView = nil;
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	return cell;
}

- (UITableViewCell *)linkDeviceCellForTable:(UITableView *)tableView {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"link"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"link"];
	[[TGTheme shared] styleCell:cell];
	cell.textLabel.text = TGL(@"AuthSessions.LinkDesktopDevice", @"Link Desktop Device");
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.textLabel.highlightedTextColor = [UIColor whiteColor];
	UIView *disclosure = TGSessionsDisclosureView();
	if (disclosure) {
		cell.accessoryView = disclosure;
		cell.accessoryType = UITableViewCellAccessoryNone;
	} else {
		cell.accessoryView = nil;
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 0)
		return [self linkDeviceCellForTable:tableView];
	if (indexPath.section == 3)
		return [self terminateAllCellForTable:tableView];
	if (indexPath.section == 4)
		return [self ttlCellForTable:tableView];

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"row"];
		UIView *hairline = [[UIView alloc] initWithFrame:CGRectZero];
		hairline.tag = kSessionsHairlineTag;
		hairline.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
		[cell.contentView addSubview:hairline];
	}

	NSDictionary *session = [self sessionAtIndexPath:indexPath];
	NSString *name = session ? [self titleForSession:session]
							 : TGL(@"AuthSessions.UnknownApplication", @"Unknown application");

	[[TGTheme shared] styleCell:cell];

	cell.textLabel.text = name;
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.textLabel.highlightedTextColor = [UIColor whiteColor];
	cell.detailTextLabel.text = session ? [self subtitleForSession:session] : @"";
	cell.detailTextLabel.numberOfLines = 2;
	cell.detailTextLabel.font = [UIFont systemFontOfSize:13 + TGSessionsRetinaPixel()];
	cell.detailTextLabel.textColor = [session[@"isUnconfirmed"] boolValue]
		? [[TGTheme shared] groupedDestructiveColour]
		: [[TGTheme shared] groupedDisabledColour];
	cell.selectionStyle = indexPath.section == 1
		? UITableViewCellSelectionStyleNone
		: UITableViewCellSelectionStyleBlue;
	UIView *disclosure = indexPath.section == 2 ? TGSessionsDisclosureView() : nil;
	cell.accessoryView = disclosure;
	cell.accessoryType = (indexPath.section == 2 && !disclosure)
		? UITableViewCellAccessoryDisclosureIndicator
		: UITableViewCellAccessoryNone;

	UIView *hairline = [cell.contentView viewWithTag:kSessionsHairlineTag];
	NSInteger rows = [self tableView:tableView numberOfRowsInSection:indexPath.section];
	hairline.backgroundColor = [[TGTheme shared] separatorColour];
	hairline.hidden = indexPath.row + 1 >= rows;
	return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell
	forRowAtIndexPath:(NSIndexPath *)indexPath {
	TGApplyRTLCellMirroring(cell);
	CGRect bounds = cell.contentView.bounds;
	if (indexPath.section == 3) {
		UIView *button = [cell.contentView viewWithTag:kSessionsHairlineTag + 1];
		button.frame = CGRectMake(9, 0, bounds.size.width - 18, 45);
		return;
	}
	UIView *hairline = [cell.contentView viewWithTag:kSessionsHairlineTag];
	CGFloat thickness = 1.0f / [UIScreen mainScreen].scale;
	hairline.frame = CGRectMake(10, bounds.size.height - thickness,
		bounds.size.width - 10, thickness);
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return indexPath.section == 2;
}

- (NSString *)tableView:(UITableView *)tableView
	titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
	return TGL(@"AuthSessions.Terminate", @"Terminate");
}

- (void)tableView:(UITableView *)tableView
	commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
	 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete)
		return;
	NSDictionary *session = [self sessionAtIndexPath:indexPath];
	if (!session)
		return;
	[self terminateSessions:[NSArray arrayWithObject:session]];
}

- (void)removeSessionsFromListLocally:(NSArray *)targets {
	if (!targets.count)
		return;

	NSMutableArray *remaining = [NSMutableArray arrayWithArray:self.sessions ?: [NSArray array]];
	for (NSDictionary *session in targets)
		[remaining removeObject:session];
	self.sessions = remaining;
	[self.tableView reloadData];

	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(refresh)
											   object:nil];
	[self performSelector:@selector(refresh) withObject:nil afterDelay:1.0];
}

- (void)terminateSessions:(NSArray *)targets {
	if (!targets.count)
		return;

	NSMutableArray *validTargets = [NSMutableArray array];
	__weak typeof(self) weakSelf = self;
	for (NSDictionary *session in targets) {
		long long sessionId = [session[@"id"] longLongValue];
		if (!sessionId)
			continue;
		[validTargets addObject:session];
		[[TGClient shared] terminateSession:sessionId completion:^(BOOL ok) {
			TGSessionsViewController *strongSelf = weakSelf;
			if (!ok) {
				[strongSelf refresh];
				if (strongSelf)
					[TGSnackbar showInView:[strongSelf sheetHostView]
									  text:TGL(@"AuthSessions.TerminateSessionFailed", @"That session could not be terminated.")
								   seconds:2
								  onCommit:nil];
			}
		}];
	}
	[self removeSessionsFromListLocally:validTargets];
}

#pragma mark - destructive confirmation

- (UIView *)sheetHostView {
	if (self.navigationController.view)
		return self.navigationController.view;
	return self.view;
}

- (void)performTerminateAll {
	NSDictionary *current = [self currentSession];
	self.sessions = current ? [NSArray arrayWithObject:current] : [NSArray array];
	[self.tableView reloadData];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] terminateAllOtherSessionsWithCompletion:^(BOOL ok) {
		TGSessionsViewController *strongSelf = weakSelf;
		[strongSelf refresh];
		if (!ok && strongSelf)
			[TGSnackbar showInView:[strongSelf sheetHostView]
							  text:TGL(@"AuthSessions.TerminateAllSessionsFailed", @"The other sessions could not be terminated.")
						   seconds:2
						  onCommit:nil];
	}];
}

- (void)confirmTerminateAll {
	if (![self othersOnly].count)
		return;
	self.pendingTermination = 0;

	__weak typeof(self) weakSelf = self;
	UIAlertView *confirm = [[TGAlertView alloc]
			initWithTitle:TGL(@"AuthSessions.TerminateOtherSessionsConfirmTitle", @"Terminate all other sessions?")
				  message:TGL(@"AuthSessions.TerminateOtherSessionsConfirmText", @"This will terminate all sessions except this one. All other devices will be signed out.")
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			okButtonTitle:TGL(@"AuthSessions.TerminateOtherSessions", @"Terminate All Other Sessions")
		  completionBlock:^(bool okButtonPressed) {
			  __strong typeof(weakSelf) strongSelf = weakSelf;
			  if (!strongSelf || !okButtonPressed)
				  return;
			  [strongSelf performTerminateAll];
		  }];
	[confirm show];
}

- (void)showTtlPicker {
	NSMutableArray *actions = [NSMutableArray array];
	for (NSNumber *option in [self ttlOptions]) {
		NSInteger days = [option integerValue];
		NSString *title = [self ttlTitleForDays:days];
		if (days == self.ttlDays)
			title = [NSString stringWithFormat:@"%@ ✓", title];
		[actions addObject:[[TGActionSheetAction alloc]
							   initWithTitle:title
									  action:[NSString stringWithFormat:@"ttl%d", (int)days]]];
	}
	[actions addObject:[[TGActionSheetAction alloc]
						   initWithTitle:TGL(@"Common.Cancel", @"Cancel")
								  action:@"cancel"
									type:TGActionSheetActionTypeCancel]];

	__weak typeof(self) weakSelf = self;
	self.currentActionSheet = [[TGActionSheet alloc]
		initWithTitle:TGL(@"AuthSessions.TerminateIfAwayFor", @"If inactive for")
			  actions:actions
		  actionBlock:^(__unused id target, NSString *action) {
			  __strong typeof(weakSelf) strongSelf = weakSelf;
			  strongSelf.currentActionSheet = nil;
			  if (![action hasPrefix:@"ttl"])
				  return;
			  NSInteger days = [[action substringFromIndex:3] integerValue];
			  if (days <= 0 || days == strongSelf.ttlDays)
				  return;
			  NSInteger previous = strongSelf.ttlDays;
			  strongSelf.ttlDays = days;
			  [strongSelf.tableView reloadData];
			  [[TGClient shared] setInactiveSessionTtlDays:days completion:^(BOOL ok) {
				  __strong typeof(weakSelf) innerSelf = weakSelf;
				  if (ok || !innerSelf)
					  return;
				  innerSelf.ttlDays = previous;
				  [innerSelf.tableView reloadData];
				  [TGSnackbar showInView:[innerSelf sheetHostView]
									text:TGL(@"Toast.CouldNotChangeSessionTimeout", @"Could not change the session timeout")
								 seconds:2
								onCommit:nil];
			  }];
		  }
			   target:self];
	UIView *hostView = [self sheetHostView];
	[self.currentActionSheet tg_showFromRect:CGRectMake(CGRectGetMidX(hostView.bounds), CGRectGetMidY(hostView.bounds), 1, 1)
									   inView:hostView];
}

- (BOOL)looksLikeLoginLink:(NSString *)payload {
	return TGTextIsLoginConfirmationLink(payload);
}

- (void)rejectNonLoginQrCode {
	[self.scanner resumeScanning];
	UIAlertView *notALoginCode = [[UIAlertView alloc]
			initWithTitle:nil
					  message:TGL(@"AuthSessions.AddDevice.NotALoginCode",
							  @"That wasn't a device login code. Point the camera at the QR code shown on the device you want to sign in.")
					 delegate:nil
			cancelButtonTitle:TGL(@"Common.OK", @"OK")
			otherButtonTitles:nil];
	[notALoginCode show];
}

- (void)confirmLoginLink:(NSString *)link {
	if (!link.length) {
		[self.scanner resumeScanning];
		return;
	}

	__weak typeof(self) weakSelf = self;
	UIAlertView *confirm = [[TGAlertView alloc]
			initWithTitle:TGL(@"AuthSessions.AddDevice.ConfirmTitle", @"Log in to this device?")
				  message:TGL(@"AuthSessions.AddDevice.ConfirmText", @"This will let the device that showed this QR code sign in to your Telegram account.")
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			okButtonTitle:TGL(@"AuthConfirmation.LogIn", @"Log in")
		  completionBlock:^(bool okButtonPressed) {
			  __strong typeof(weakSelf) strongSelf = weakSelf;
			  if (!strongSelf)
				  return;
			  if (!okButtonPressed) {
				  [strongSelf.scanner resumeScanning];
				  return;
			  }
			  [strongSelf performLoginLinkConfirmation:link];
		  }];
	[confirm show];
}

- (void)performLoginLinkConfirmation:(NSString *)link {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] confirmQrCodeLogin:link completion:^(NSDictionary *session) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!session) {
			[strongSelf.scanner resumeScanning];
			UIAlertView *stale = [[UIAlertView alloc]
					initWithTitle:nil
						  message:TGL(@"AuthSessions.AddDevice.InvalidQRCode", @"That QR code could not be used. It may have expired.")
						 delegate:nil
				cancelButtonTitle:TGL(@"Common.OK", @"OK")
				otherButtonTitles:nil];
			[stale show];
			return;
		}
		[strongSelf.navigationController popToViewController:strongSelf animated:YES];
		[strongSelf refresh];
		[strongSelf showLoginSuccessToastForSession:session];
	}];
}

- (void)showLoginSuccessToastForSession:(NSDictionary *)session {
	if (!self.isViewLoaded)
		return;
	[self dismissLoginToastAnimated:NO];

	UIView *host = [self sheetHostView];
	if (!host)
		return;

	NSString *appName = session[@"appName"];
	if (![appName isKindOfClass:[NSString class]] || !appName.length)
		appName = session[@"deviceModel"];
	if (![appName isKindOfClass:[NSString class]] || !appName.length)
		appName = TGL(@"Settings.Devices", @"Devices");
	BOOL passwordPending = [session[@"isPasswordPending"] boolValue];

	CGFloat width = host.bounds.size.width - 24;
	UIView *toast = [[UIView alloc] initWithFrame:CGRectZero];
	toast.bounds = CGRectMake(0, 0, width, 64);
	toast.center = CGPointMake(host.bounds.size.width / 2, host.bounds.size.height - 44);
	toast.autoresizingMask = UIViewAutoresizingFlexibleTopMargin |
		UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	toast.backgroundColor = [UIColor colorWithWhite:0 alpha:0.85f];
	toast.layer.cornerRadius = 10;
	toast.clipsToBounds = YES;
	toast.alpha = 0;

	UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(14, 9, width - 100, 20)];
	title.text = passwordPending
		? TGL(@"AuthSessions.PasswordPendingTitle", @"Password Needed")
		: TGL(@"AuthSessions.AddedDeviceTitle", @"Login Successful");
	title.font = [UIFont boldSystemFontOfSize:14];
	title.textColor = [UIColor whiteColor];
	title.backgroundColor = [UIColor clearColor];
	[toast addSubview:title];

	UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(14, 31, width - 100, 20)];
	subtitle.text = passwordPending
		? TGL(@"AuthSessions.PasswordPendingText", @"Enter it on the other device to finish.")
		: appName;
	subtitle.font = [UIFont systemFontOfSize:13];
	subtitle.textColor = [UIColor colorWithWhite:1 alpha:0.7f];
	subtitle.backgroundColor = [UIColor clearColor];
	[toast addSubview:subtitle];

	UIButton *terminate = [UIButton buttonWithType:UIButtonTypeCustom];
	terminate.frame = CGRectMake(width - 84, 0, 84, toast.bounds.size.height);
	terminate.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[terminate setTitle:TGL(@"AuthSessions.AddedDeviceTerminate", @"Terminate") forState:UIControlStateNormal];
	[terminate setTitleColor:[UIColor colorWithRed:1.0f green:0.27f blue:0.23f alpha:1.0f]
					 forState:UIControlStateNormal];
	terminate.titleLabel.font = [UIFont boldSystemFontOfSize:14];
	[terminate addTarget:self action:@selector(loginToastTerminateTapped)
		forControlEvents:UIControlEventTouchUpInside];
	[toast addSubview:terminate];

	[host addSubview:toast];
	self.loginToastView = toast;
	self.loginToastSessionId = [session[@"id"] longLongValue];

	[UIView animateWithDuration:0.2 animations:^{ toast.alpha = 1; }];
	[self performSelector:@selector(autoDismissLoginToast) withObject:nil afterDelay:5.0];
}

- (void)autoDismissLoginToast {
	[self dismissLoginToastAnimated:YES];
}

- (void)dismissLoginToastAnimated:(BOOL)animated {
	UIView *toast = self.loginToastView;
	if (!toast)
		return;
	self.loginToastView = nil;
	self.loginToastSessionId = 0;
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(autoDismissLoginToast)
											   object:nil];
	if (!animated) {
		[toast removeFromSuperview];
		return;
	}
	[UIView animateWithDuration:0.2
		animations:^{ toast.alpha = 0; }
		completion:^(BOOL done) { [toast removeFromSuperview]; }];
}

- (void)loginToastTerminateTapped {
	long long sessionId = self.loginToastSessionId;
	[self dismissLoginToastAnimated:YES];
	if (!sessionId)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] terminateSession:sessionId completion:^(__unused BOOL ok) {
		[weakSelf refresh];
	}];
}

- (void)scanLoginCode {
	TGQRViewController *scanner = [[TGQRViewController alloc] init];
	scanner.deviceLinkSubject = YES;
	__weak typeof(self) weakSelf = self;
	scanner.onCode = ^BOOL(NSString *payload) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return NO;
		if (![strongSelf looksLikeLoginLink:payload]) {
			[strongSelf rejectNonLoginQrCode];
			return YES;
		}
		[strongSelf confirmLoginLink:payload];
		return YES;
	};
	self.scanner = scanner;
	[self.navigationController pushViewController:scanner animated:YES];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (indexPath.section == 0) {
		[self scanLoginCode];
		return;
	}
	if (indexPath.section == 4) {
		[self showTtlPicker];
		return;
	}
	if (indexPath.section != 2)
		return;

	NSDictionary *session = [self sessionAtIndexPath:indexPath];
	if (!session)
		return;
	if (![session[@"id"] longLongValue])
		return;

	TGSessionDetailViewController *detail =
		[[TGSessionDetailViewController alloc] initWithSession:session];
	detail.detailDelegate = self;
	[self.navigationController pushViewController:detail animated:YES];
}

- (void)sessionDetailDidChangeSessions:(__unused TGSessionDetailViewController *)controller {
	[self refresh];
}

- (void)sessionDetail:(__unused TGSessionDetailViewController *)controller didTerminateSession:(NSDictionary *)session {
	[self removeSessionsFromListLocally:[NSArray arrayWithObject:session]];
}

@end

@interface TGSessionDetailViewController ()
@property (nonatomic, strong) NSDictionary *session;
@property (nonatomic, strong) NSArray *infoRows;
@property (nonatomic, strong) TGActionSheet *currentActionSheet;
@property (nonatomic, assign) BOOL acceptsCalls;
@property (nonatomic, assign) BOOL acceptsSecrets;
@property (nonatomic, assign) BOOL current;
@property (nonatomic, assign) BOOL unconfirmed;
@property (nonatomic, assign) long long sessionId;
@end

@implementation TGSessionDetailViewController

- (instancetype)initWithSession:(NSDictionary *)session {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		_session = session ?: [NSDictionary dictionary];
		_sessionId = [_session[@"id"] longLongValue];
		[self adoptSession:_session];
	}
	return self;
}

- (NSString *)stringIn:(NSDictionary *)session forKey:(NSString *)key {
	id value = session[key];
	if (![value isKindOfClass:[NSString class]])
		return @"";
	return [value stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceCharacterSet]];
}

- (NSString *)firstStringIn:(NSDictionary *)session keys:(NSArray *)keys {
	for (NSString *key in keys) {
		NSString *value = [self stringIn:session forKey:key];
		if (value.length)
			return value;
	}
	return @"";
}

- (NSString *)dateTextIn:(NSDictionary *)session keys:(NSArray *)keys {
	long long stamp = 0;
	for (NSString *key in keys) {
		stamp = [session[key] longLongValue];
		if (stamp > 0)
			break;
	}
	if (stamp <= 0)
		return @"";
	return [TGDateUtils stringForFullDateAndTime:(int)stamp];
}

- (void)adoptSession:(NSDictionary *)session {
	if (!session.count)
		return;
	self.session = session;
	self.acceptsCalls = [session[@"canAcceptCalls"] boolValue];
	self.acceptsSecrets = [session[@"canAcceptSecretChats"] boolValue];
	self.current = [session[@"isCurrent"] boolValue];
	self.unconfirmed = [session[@"isUnconfirmed"] boolValue];

	NSMutableArray *rows = [NSMutableArray array];
	NSString *app = [self firstStringIn:session keys:
			[NSArray arrayWithObjects:@"appName", @"name", nil]];
	NSString *version = [self stringIn:session forKey:@"appVersion"];
	if (app.length && version.length)
		app = [NSString stringWithFormat:@"%@ %@", app, version];
	if (app.length)
		[rows addObject:[NSArray arrayWithObjects:
				TGL(@"AuthSessions.View.Application", @"Application"), app, nil]];

	NSString *device = [self stringIn:session forKey:@"deviceModel"];
	if (device.length)
		[rows addObject:[NSArray arrayWithObjects:
				TGL(@"AuthSessions.View.Device", @"Device"), device, nil]];

	NSString *platform = [self firstStringIn:session keys:
			[NSArray arrayWithObjects:@"platform", @"systemVersion", nil]];
	if (platform.length)
		[rows addObject:[NSArray arrayWithObjects:
				TGL(@"AuthSessions.View.OS", @"Operating System"), platform, nil]];

	NSString *ip = [self firstStringIn:session keys:
			[NSArray arrayWithObjects:@"ipAddress", @"ip", nil]];
	if (ip.length)
		[rows addObject:[NSArray arrayWithObjects:TGL(@"AuthSessions.View.IP", @"IP Address"), ip, nil]];

	NSString *location = [self stringIn:session forKey:@"location"];
	if (location.length)
		[rows addObject:[NSArray arrayWithObjects:
				TGL(@"AuthSessions.View.Location", @"Location"), location, nil]];

	NSString *login = [self dateTextIn:session keys:
			[NSArray arrayWithObjects:@"loginDate", nil]];
	if (login.length)
		[rows addObject:[NSArray arrayWithObjects:
				TGL(@"AuthSessions.LoggedInAt", @"Logged in"), login, nil]];

	if (!self.current) {
		NSString *seen = [self dateTextIn:session keys:
				[NSArray arrayWithObjects:@"lastActiveDate", @"lastActive", nil]];
		if (seen.length)
			[rows addObject:[NSArray arrayWithObjects:
					TGL(@"AuthSessions.LastActiveAt", @"Last active"), seen, nil]];
	}
	self.infoRows = rows;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"AuthSessions.SessionDetailTitle", @"Session");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	TGSessionsApplyBackground(self.tableView);
	self.tableView.rowHeight = 44;

	UISwipeGestureRecognizer *back = [[UISwipeGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(performSwipeBack)];
	back.direction = UISwipeGestureRecognizerDirectionRight;
	[self.tableView addGestureRecognizer:back];

	[self reload];
}

- (void)performSwipeBack {
	if (self.navigationController.viewControllers.count > 1)
		[self.navigationController popViewControllerAnimated:YES];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	NSIndexPath *selected = [self.tableView indexPathForSelectedRow];
	if (selected)
		[self.tableView deselectRowAtIndexPath:selected animated:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	if (self.currentActionSheet) {
		NSInteger cancelIndex = self.currentActionSheet.cancelButtonIndex;
		[self.currentActionSheet dismissWithClickedButtonIndex:cancelIndex animated:NO];
		self.currentActionSheet = nil;
	}
}

- (void)reload {
	if (!self.sessionId)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] sessionInfoForId:self.sessionId
							 completion:^(NSDictionary *session) {
								 __strong typeof(weakSelf) strongSelf = weakSelf;
								 if (!strongSelf || !session.count)
									 return;
								 [strongSelf adoptSession:session];
								 [strongSelf.tableView reloadData];
							 }];
}

- (UIView *)sheetHostView {
	if (self.navigationController.view)
		return self.navigationController.view;
	return self.view;
}

- (BOOL)showsSwitches {
	return !self.current;
}

- (NSInteger)numberOfSectionsInTableView:(__unused UITableView *)tableView {
	return 3;
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return (NSInteger)self.infoRows.count;
	if (section == 1)
		return [self showsSwitches] ? 2 : 0;
	if (self.current)
		return 0;
	return self.unconfirmed ? 2 : 1;
}

- (NSString *)headerTitleForSection:(NSInteger)section {
	if (section == 1 && [self showsSwitches])
		return TGL(@"AuthSessions.View.AcceptTitle", @"Accept on This Device");
	return nil;
}

- (NSString *)footerTitleForSection:(NSInteger)section {
	if (section == 1 && [self showsSwitches])
		return TGL(@"AuthSessions.AcceptsFooter",
				   @"Calls and secret chats can be turned off for this session without ending it."
					"ending it.");
	if (section == 2 && self.unconfirmed)
		return TGL(@"AuthSessions.NotConfirmedYet", @"You have not confirmed this login yet.");
	return nil;
}

- (CGFloat)tableView:(__unused UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return [self headerTitleForSection:section] ? 46 : 14;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *title = [self headerTitleForSection:section];
	if (!title)
		return nil;
	return TGSessionsHeaderView(title, tableView.bounds.size.width);
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *title = [self footerTitleForSection:section];
	if (!title)
		return 1;
	return TGSessionsCommentHeight(title, tableView.bounds.size.width);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *title = [self footerTitleForSection:section];
	if (!title)
		return nil;
	return TGSessionsCommentView(title, tableView.bounds.size.width);
}

- (UITableViewCell *)infoCellForTable:(UITableView *)tableView
								  row:(NSInteger)row {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"info"];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:@"info"];
	}
	[[TGTheme shared] styleCell:cell];
	NSArray *pair = self.infoRows[row];
	cell.textLabel.text = pair[0];
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.detailTextLabel.text = pair[1];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	cell.detailTextLabel.highlightedTextColor = [UIColor whiteColor];
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	return cell;
}

- (UITableViewCell *)switchCellForTable:(UITableView *)tableView
									row:(NSInteger)row {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"toggle"];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"toggle"];
		UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectZero];
		[toggle addTarget:self action:@selector(toggleChanged:)
			forControlEvents:UIControlEventValueChanged];
		cell.accessoryView = toggle;
	}
	[[TGTheme shared] styleCell:cell];
	cell.textLabel.text = row == 0 ? TGL(@"AuthSessions.View.AcceptIncomingCalls", @"Incoming Calls")
								   : TGL(@"AuthSessions.View.AcceptSecretChats", @"New Secret Chats");
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;

	UISwitch *toggle = (UISwitch *)cell.accessoryView;
	toggle.tag = row;
	[toggle setOn:(row == 0 ? self.acceptsCalls : self.acceptsSecrets) animated:NO];
	return cell;
}

- (UITableViewCell *)actionCellForTable:(UITableView *)tableView
									row:(NSInteger)row {
	BOOL confirmRow = self.unconfirmed && row == 0;
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"action"];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"action"];
	}
	[TGIcons actionButtonInCell:cell
						  title:confirmRow ? TGL(@"ChatList.SessionReview.PanelConfirm", @"It's Me")
										   : TGL(@"AuthSessions.TerminateSession", @"Terminate Session")
						   kind:confirmRow ? TGActionButtonKindNeutral : TGActionButtonKindDestructive
						 target:self
						 action:confirmRow ? @selector(confirmSession) : @selector(confirmTerminate)];
	return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 2)
		return TGActionRowHeight();
	return 44;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 0)
		return [self infoCellForTable:tableView row:indexPath.row];
	if (indexPath.section == 1)
		return [self switchCellForTable:tableView row:indexPath.row];
	return [self actionCellForTable:tableView row:indexPath.row];
}

- (void)toggleChanged:(UISwitch *)sender {
	BOOL calls = self.acceptsCalls;
	BOOL secrets = self.acceptsSecrets;
	if (sender.tag == 0)
		calls = sender.on;
	else
		secrets = sender.on;

	BOOL previousCalls = self.acceptsCalls;
	BOOL previousSecrets = self.acceptsSecrets;
	self.acceptsCalls = calls;
	self.acceptsSecrets = secrets;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setSession:self.sessionId
				   canAcceptCalls:calls
				 canAcceptSecrets:secrets
					   completion:^(BOOL ok) {
						   __strong typeof(weakSelf) strongSelf = weakSelf;
						   if (ok || !strongSelf)
							   return;
						   strongSelf.acceptsCalls = previousCalls;
						   strongSelf.acceptsSecrets = previousSecrets;
						   [strongSelf.tableView reloadData];
						   [TGSnackbar showInView:[strongSelf sheetHostView]
											  text:TGL(@"Toast.CouldNotChangeSessionSettings", @"Could not change the session settings")
										   seconds:2
										  onCommit:nil];
					   }];
}

- (void)confirmSession {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] confirmSession:self.sessionId completion:^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (ok) {
			strongSelf.unconfirmed = NO;
			[strongSelf.tableView reloadData];
			[strongSelf.detailDelegate sessionDetailDidChangeSessions:strongSelf];
		} else {
			[TGSnackbar showInView:[strongSelf sheetHostView]
							  text:TGL(@"Toast.CouldNotConfirmSession", @"Could not confirm this session")
						   seconds:2
						  onCommit:nil];
		}
	}];
}

- (void)performTerminate {
	__weak typeof(self) weakSelf = self;
	id<TGSessionDetailDelegate> delegate = self.detailDelegate;
	NSDictionary *session = self.session;
	[[TGClient shared] terminateSession:self.sessionId completion:^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!ok) {
			if (strongSelf)
				[TGSnackbar showInView:[strongSelf sheetHostView]
								  text:TGL(@"AuthSessions.TerminateSessionFailed", @"That session could not be terminated.")
							   seconds:2
							  onCommit:nil];
			return;
		}
		[delegate sessionDetail:strongSelf didTerminateSession:session];
		[strongSelf.navigationController popViewControllerAnimated:YES];
	}];
}

- (void)confirmTerminate {
	TGActionSheetAction *terminate = [[TGActionSheetAction alloc]
		initWithTitle:TGL(@"AuthSessions.TerminateSession", @"Terminate Session")
			   action:@"terminate"
				 type:TGActionSheetActionTypeDestructive];
	TGActionSheetAction *cancel = [[TGActionSheetAction alloc]
		initWithTitle:TGL(@"Common.Cancel", @"Cancel")
			   action:@"cancel"
				 type:TGActionSheetActionTypeCancel];
	NSArray *actions = [NSArray arrayWithObjects:terminate, cancel, nil];

	__weak typeof(self) weakSelf = self;
	self.currentActionSheet = [[TGActionSheet alloc]
		initWithTitle:nil
			  actions:actions
		  actionBlock:^(__unused id target, NSString *action) {
			  __strong typeof(weakSelf) strongSelf = weakSelf;
			  strongSelf.currentActionSheet = nil;
			  if ([action isEqualToString:@"terminate"])
				  [strongSelf performTerminate];
		  }
			   target:self];
	UIView *hostView = [self sheetHostView];
	[self.currentActionSheet tg_showFromRect:CGRectMake(CGRectGetMidX(hostView.bounds), CGRectGetMidY(hostView.bounds), 1, 1)
									   inView:hostView];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end

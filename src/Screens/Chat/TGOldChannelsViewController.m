#import "TGListBackground.h"
#import "TGOldChannelsViewController.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGClient+ChatManagement.h"
#import "TGSnackbar.h"

@interface TGOldChannelsViewController () <UIAlertViewDelegate>
@property (nonatomic, strong) NSMutableSet *chosen;
@property (nonatomic, assign) BOOL leaving;
@end

@implementation TGOldChannelsViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"OldChannels.Title", @"Limit Reached");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	self.chosen = [NSMutableSet set];
	[self updateLeaveButton];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (NSString *)leaveButtonTitle {
	NSInteger count = (NSInteger)self.chosen.count;
	return TGLPlural(@"OldChannels.LeaveCommunities", count, @"Leave %@ Community", @"Leave %@ Communities");
}

- (void)updateLeaveButton {
	if (!self.chosen.count) {
		self.navigationItem.rightBarButtonItem = nil;
		return;
	}
	UIButton *leave = [TGIcons headerButtonWithTitle:[self leaveButtonTitle] bold:YES
											  target:self
											  action:@selector(leaveChosen)];
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:leave];
}

- (NSString *)inactivityTextForDate:(NSTimeInterval)date {
	if (date <= 0)
		return @"";
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDate *then = [NSDate dateWithTimeIntervalSince1970:date];
	NSDateComponents *thenParts = [calendar components:
			(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit)
											  fromDate:then];
	NSDateComponents *nowParts = [calendar components:
			(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit)
											 fromDate:[NSDate date]];

	if (nowParts.year == thenParts.year && nowParts.month == thenParts.month) {
		NSInteger weeks = (NSInteger)roundf((nowParts.day - thenParts.day) / 7.0f);
		return TGLPlural(@"OldChannels.InactiveWeek", weeks, @"inactive %@ week", @"inactive %@ weeks");
	}
	if (nowParts.year == thenParts.year) {
		NSInteger months = nowParts.month - thenParts.month;
		return TGLPlural(@"OldChannels.InactiveMonth", months, @"inactive %@ month", @"inactive %@ months");
	}
	NSInteger years = nowParts.year - thenParts.year;
	if (nowParts.month - thenParts.month > 6)
		years += 1;
	return TGLPlural(@"OldChannels.InactiveYear", years, @"inactive %@ year", @"inactive %@ years");
}

- (NSString *)subtitleForChat:(NSDictionary *)chat {
	NSString *inactivity = [self inactivityTextForDate:
			[chat[@"lastActivityDate"] doubleValue]];
	if ([chat[@"isChannel"] boolValue])
		return [TGL(@"OldChannels.ChannelFormat", @"channel, ") stringByAppendingString:inactivity];

	NSInteger members = [chat[@"memberCount"] integerValue];
	if (members <= 0)
		return [TGL(@"OldChannels.GroupEmptyFormat", @"group, ") stringByAppendingString:inactivity];

	NSString *count = TGLPlural(@"OldChannels.GroupFormat", members, @"%@ member ", @"%@ members ");
	return [NSString stringWithFormat:@"%@, %@", count, inactivity];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.chats.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return [[TGTheme shared] groupedHeaderHeightForTitle:
			TGL(@"OldChannels.ChannelsHeader", @"MOST INACTIVE")];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	return [[TGTheme shared] groupedHeaderViewWithTitle:
					TGL(@"OldChannels.ChannelsHeader", @"MOST INACTIVE")
												  width:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"row"];
	[[TGTheme shared] styleCell:cell];
	NSDictionary *chat = [self.chats objectAtIndex:(NSUInteger)indexPath.row];
	cell.textLabel.text = [chat[@"title"] isKindOfClass:NSString.class] ? chat[@"title"] : @"";
	cell.detailTextLabel.text = [self subtitleForChat:chat];
	cell.detailTextLabel.textColor = [[TGTheme shared] groupedDisabledColour];
	NSNumber *chatId = [chat[@"id"] isKindOfClass:NSNumber.class] ? chat[@"id"] : nil;
	cell.accessoryType = (chatId && [self.chosen containsObject:chatId])
		? UITableViewCellAccessoryCheckmark
		: UITableViewCellAccessoryNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSDictionary *chat = [self.chats objectAtIndex:(NSUInteger)indexPath.row];
	NSNumber *chatId = [chat[@"id"] isKindOfClass:NSNumber.class] ? chat[@"id"] : nil;
	if (!chatId)
		return;
	if ([self.chosen containsObject:chatId])
		[self.chosen removeObject:chatId];
	else
		[self.chosen addObject:chatId];
	[tableView reloadRowsAtIndexPaths:@[ indexPath ]
					 withRowAnimation:UITableViewRowAnimationNone];
	[self updateLeaveButton];
}

- (void)leaveChosen {
	if (self.leaving || !self.chosen.count)
		return;
	UIAlertView *confirm = [UIAlertView alloc];
	confirm = [confirm initWithTitle:[self leaveButtonTitle]
							 message:nil
							delegate:self
				   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
				   otherButtonTitles:TGL(@"PeerInfo.AlertLeaveAction", @"Leave"), nil];
	confirm.tag = 501;
	[confirm show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (alertView.tag != 501)
		return;
	if (buttonIndex == alertView.cancelButtonIndex)
		return;
	[self performLeaveChosen];
}

- (void)performLeaveChosen {
	if (self.leaving || !self.chosen.count)
		return;
	self.leaving = YES;
	__block NSInteger remaining = (NSInteger)self.chosen.count;
	__block BOOL anyFailed = NO;
	__weak typeof(self) weakSelf = self;
	for (NSNumber *chatId in [self.chosen allObjects]) {
		[[TGClient shared] leaveChatForJoinLimit:[chatId longLongValue]
									  completion:^(BOOL ok) {
										  TGOldChannelsViewController *strongSelf = weakSelf;
										  if (!ok)
											  anyFailed = YES;
										  remaining--;
										  if (remaining > 0 || !strongSelf)
											  return;
										  strongSelf.leaving = NO;
										  if (anyFailed) {
											  [TGSnackbar showInView:strongSelf.navigationController.view
																 text:TGL(@"Toast.CouldNotLeaveChats", @"Could not leave all of these chats")
															  seconds:2
															 onCommit:nil];
											  return;
										  }
										  if (strongSelf.onLeft)
											  strongSelf.onLeft();
										  [strongSelf.navigationController popViewControllerAnimated:YES];
									  }];
	}
}

@end

#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGChatEventsViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGClient.h"
#import "TGClient+ChatManagement.h"
#import "TGClient+Messages.h"
#import "TGChatViewController.h"
#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGDateUtils.h"
#import "UIView+SafeTint.h"
#import "TGHexColour.h"

@interface TGChatEventsSpamController : UITableViewController

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, strong) NSArray *entries;
@property (nonatomic, strong) NSMutableArray *selection;
@property (nonatomic, strong) UIButton *reportButton;
@property (nonatomic, copy) void (^completion)(NSArray *reportedMessageIds);

- (instancetype)initWithEntries:(NSArray *)entries chatId:(int64_t)chatId;

@end

@implementation TGChatEventsSpamController

- (instancetype)initWithEntries:(NSArray *)entries chatId:(int64_t)chatId {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		_chatId = chatId;
		_entries = [entries isKindOfClass:[NSArray class]] ? entries : [NSArray array];
		_selection = [NSMutableArray array];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"Group.AdminLog.AntiSpamTitle", @"Anti-Spam");
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

	self.reportButton = [TGIcons headerButtonWithTitle:TGL(@"ReportPeer.Report", @"Report") bold:YES
												target:self
												action:@selector(reportPressed)];
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:self.reportButton];
	[self updateReportButton];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)updateReportButton {
	BOOL enabled = self.selection.count != 0;
	self.reportButton.enabled = enabled;
	self.reportButton.alpha = enabled ? 1.0f : 0.4f;
}

- (NSDictionary *)entryAtRow:(NSInteger)row {
	if (row < 0 || row >= (NSInteger)self.entries.count)
		return nil;
	NSDictionary *entry = self.entries[row];
	return [entry isKindOfClass:[NSDictionary class]] ? entry : nil;
}

- (NSNumber *)messageIdAtRow:(NSInteger)row {
	NSNumber *messageId = TGEventsNumber([self entryAtRow:row], @"messageId");
	return [messageId longLongValue] != 0 ? messageId : nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.entries.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return TGL(@"ChatEvents.RemovedByTheFilter", @"Removed by the Filter");
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderHeightForTitle:title];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	return TGL(@"ChatEvents.ReportFalsePositivesFooter",
			   @"Pick the messages the filter should not have removed and report them together. Reporting teaches the filter and does not bring the messages back."
				"together. Reporting teaches the filter and does not bring the messages "
				"back.");
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

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 56;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"spam"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"spam"];
	[[TGTheme shared] styleCell:cell];
	cell.accessoryView = nil;
	cell.accessoryType = UITableViewCellAccessoryNone;

	NSDictionary *entry = [self entryAtRow:indexPath.row];
	NSString *name = TGEventsText(entry, @"name");
	cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.textLabel.text = name.length ? name : TGL(@"Premium.GiftedTitle.Someone", @"Someone");

	NSString *summary = TGEventsText(entry, @"text");
	cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@",
		[TGDateUtils stringForShortTime:TGEventsInt(entry, @"date")],
		summary.length ? summary : TGL(@"ChatEvents.MessageRemoved", @"Message removed")];

	NSNumber *messageId = [self messageIdAtRow:indexPath.row];
	if (messageId && [self.selection containsObject:messageId])
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSNumber *messageId = [self messageIdAtRow:indexPath.row];
	if (!messageId)
		return;
	if ([self.selection containsObject:messageId])
		[self.selection removeObject:messageId];
	else
		[self.selection addObject:messageId];
	[self updateReportButton];
	[tableView reloadRowsAtIndexPaths:@[ indexPath ]
					 withRowAnimation:UITableViewRowAnimationNone];
}

- (void)showAlertWithMessage:(NSString *)message {
	[[[TGAlertView alloc] initWithTitle:nil message:message cancelButtonTitle:TGL(@"Common.OK", @"OK")
						  okButtonTitle:nil
						completionBlock:nil] show];
}

- (void)reportPressed {
	if (!self.selection.count || self.chatId == 0)
		return;
	NSArray *messageIds = [NSArray arrayWithArray:self.selection];
	self.reportButton.enabled = NO;
	self.reportButton.alpha = 0.4f;

	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client reportNotSpamMessages:messageIds
						   inChat:self.chatId
					   completion:^(NSArray *succeededMessageIds) {
						   __strong typeof(weakSelf) strongSelf = weakSelf;
						   if (!strongSelf)
							   return;
						   if (succeededMessageIds.count) {
							   [strongSelf.selection removeObjectsInArray:succeededMessageIds];
							   if (strongSelf.completion)
								   strongSelf.completion(succeededMessageIds);
						   }
						   if (succeededMessageIds.count == messageIds.count) {
							   [strongSelf.navigationController popViewControllerAnimated:YES];
							   return;
						   }
						   [strongSelf updateReportButton];
						   [strongSelf.tableView reloadData];
						   [strongSelf showAlertWithMessage:
									succeededMessageIds.count
										? TGL(@"ChatEvents.SomeDeletionsCouldNotBeReported",
											  @"Some of these deletions could not be reported as false positives. The rest are still selected."
											   "false positives. The rest are still selected.")
										: TGL(@"ChatEvents.DeletionsCouldNotBeReported",
											  @"These deletions could not be reported as false positives."
											   "positives.")];
					   }];
}

@end

@implementation TGChatEventsViewController (Spam)

- (NSArray *)reportableEvents {
	NSMutableArray *reportable = [NSMutableArray array];
	for (NSDictionary *event in self.events) {
		if (![TGEventsNumber(event, @"canReportNotSpam") boolValue])
			continue;
		if (TGEventsLongLong(event, @"messageId") == 0)
			continue;
		[reportable addObject:event];
	}
	return reportable;
}

- (void)updateSpamBanner {
	NSInteger count = (NSInteger)[self reportableEvents].count;
	if (count == 0) {
		self.spamBanner.hidden = YES;
		[self layoutHeaderContainer];
		return;
	}

	self.spamBanner.hidden = NO;
	self.spamBanner.backgroundColor = TGColourFromHex(0xf3f6fa);
	[self.spamBanner setTitleColor:TGColourFromHex(0x345f8f)
						  forState:UIControlStateNormal];
	[self.spamBanner setTitle:TGLPlural(@"ChatEvents.AntiSpamReviewDRemoved", count,
										 @"Anti-Spam · review %d removed", @"Anti-Spam · review %d removed")
					 forState:UIControlStateNormal];
	[self layoutHeaderContainer];
}

- (void)spamBannerPressed {
	NSArray *reportable = [self reportableEvents];
	if (!reportable.count)
		return;

	TGChatEventsSpamController *controller = [[TGChatEventsSpamController alloc]
		initWithEntries:reportable
				 chatId:self.chatId];
	__weak typeof(self) weakSelf = self;
	controller.completion = ^(NSArray *reportedMessageIds) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf markReported:reportedMessageIds];
	};
	[self.navigationController pushViewController:controller animated:YES];
}

- (void)markReported:(NSArray *)messageIds {
	if (!messageIds.count)
		return;
	for (NSInteger index = 0; index < self.events.count; index++) {
		NSDictionary *event = self.events[index];
		NSNumber *messageId = TGEventsNumber(event, @"messageId");
		if (!messageId || ![messageIds containsObject:messageId])
			continue;
		NSMutableDictionary *updated = [NSMutableDictionary dictionaryWithDictionary:event];
		[updated setObject:[NSNumber numberWithBool:NO] forKey:@"canReportNotSpam"];
		[self.events replaceObjectAtIndex:index withObject:updated];
	}
	[self rebuildSections];
	[self updateSpamBanner];
	[self.tableView reloadData];
}

@end

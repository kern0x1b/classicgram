#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGPrepaidGiveawayViewController.h"
#import "TGIcons.h"
#import "TGFriendlyError.h"
#import "TGLocalization.h"
#import "TGClient+Premium.h"
#import "TGTheme.h"
#import "TGAlertView.h"
#import "TGSnackbar.h"

static NSString *TGPGTitleText(NSDictionary *giveaway) {
	NSInteger months = [giveaway[@"prizeMonths"] integerValue];
	long long stars = [giveaway[@"prizeStars"] longLongValue];
	NSInteger winners = [giveaway[@"winnerCount"] integerValue];
	if (months > 0)
		return TGLPlural(@"Stats.Boosts.PrepaidGiveawayCount", winners, @"%@ Telegram Premium", @"%@ Telegram Premiums");
	return TGLPlural(@"BoostGift.PrepaidGiveaway.StarsCount", (NSInteger)stars, @"%@ Star", @"%@ Stars");
}

static NSString *TGPGDetailText(NSDictionary *giveaway) {
	NSInteger months = [giveaway[@"prizeMonths"] integerValue];
	NSInteger winners = [giveaway[@"winnerCount"] integerValue];
	if (months > 0)
		return [NSString stringWithFormat:TGL(@"Stats.Boosts.PrepaidGiveawayMonths", @"%@-month subscriptions"), @(months)];
	return TGLPlural(@"BoostGift.PrepaidGiveaway.StarsWinners", winners, @"for %@ winner", @"among %@ winners");
}

@interface TGPrepaidGiveawayEditorViewController : UITableViewController

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, strong) NSDictionary *giveaway;
@property (nonatomic, assign) NSTimeInterval winnersDate;
@property (nonatomic, assign) BOOL onlyNewMembers;
@property (nonatomic, assign) BOOL publicWinners;
@property (nonatomic, strong) UIView *datePickerPanel;
@property (nonatomic, strong) UIDatePicker *datePicker;
@property (nonatomic, weak) TGPrepaidGiveawayViewController *listController;

@end

@interface TGPrepaidGiveawayViewController ()
- (void)removeGiveawayWithId:(long long)giveawayId;
@end

@implementation TGPrepaidGiveawayViewController {
	int64_t _chatId;
	NSArray *_giveaways;
}

- (instancetype)initWithChatId:(int64_t)chatId giveaways:(NSArray *)giveaways {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		_chatId = chatId;
		_giveaways = giveaways ?: @[];
		self.title = TGL(@"Stats.Boosts.PrepaidGiveawaysTitle", @"Prepaid Giveaways");
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	return TGL(@"Stats.Boosts.PrepaidGiveawaysInfo", @"Each of these was already paid for. Launch one to start the giveaway now.");
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

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)_giveaways.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"prepaid"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"prepaid"];
	[[TGTheme shared] styleCell:cell];
	NSDictionary *giveaway = _giveaways[(NSUInteger)indexPath.row];
	cell.textLabel.font = TGGroupedRowTitleFont();
	cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
	cell.textLabel.text = TGPGTitleText(giveaway);
	cell.detailTextLabel.text = TGPGDetailText(giveaway);
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSDictionary *giveaway = _giveaways[(NSUInteger)indexPath.row];
	TGPrepaidGiveawayEditorViewController *editor = [[TGPrepaidGiveawayEditorViewController alloc] initWithStyle:UITableViewStyleGrouped];
	editor.chatId = _chatId;
	editor.giveaway = giveaway;
	editor.listController = self;
	[self.navigationController pushViewController:editor animated:YES];
}

- (void)removeGiveawayWithId:(long long)giveawayId {
	NSMutableArray *remaining = [NSMutableArray arrayWithCapacity:_giveaways.count];
	for (NSDictionary *giveaway in _giveaways) {
		if ([giveaway[@"id"] longLongValue] != giveawayId)
			[remaining addObject:giveaway];
	}
	_giveaways = remaining;
	[self.tableView reloadData];
}

@end

@implementation TGPrepaidGiveawayEditorViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.title = TGL(@"BoostGift.StartGiveaway", @"Launch a Giveaway");
	self.winnersDate = [[NSDate dateWithTimeIntervalSinceNow:86400] timeIntervalSince1970];
	self.publicWinners = YES;
	self.navigationItem.rightBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"BoostGift.StartConfirmation.Start", @"Launch") bold:YES
									   target:self
									   action:@selector(launch)];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	switch (section) {
		case 0:
			return 1;
		case 1:
			return 1;
		case 2:
			return 1;
		case 3:
			return 1;
	}
	return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 0)
		return TGL(@"Stars.Transaction.Giveaway.Prize", @"Prize");
	if (section == 1)
		return TGL(@"Chat.Giveaway.Message.DateTitle", @"Winners will be chosen on");
	return nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderHeightForTitle:title];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section == 2)
		return TGL(@"BoostGift.Group.LimitMembersInfo", @"Choose if you want to limit the giveaway only to those who joined the group after the giveaway started.");
	if (section == 3)
		return TGL(@"BoostGift.WinnersInfo", @"Choose whether to make the list of winners public when the giveaway ends.");
	return nil;
}

- (UITableViewCell *)cellWithIdentifier:(NSString *)identifier style:(UITableViewCellStyle)style {
	UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:identifier];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:identifier];
	[[TGTheme shared] styleCell:cell];
	cell.textLabel.font = TGGroupedRowTitleFont();
	cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
	cell.accessoryView = nil;
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 0) {
		UITableViewCell *cell = [self cellWithIdentifier:@"prize" style:UITableViewCellStyleValue1];
		cell.textLabel.text = TGPGTitleText(self.giveaway);
		cell.detailTextLabel.text = TGPGDetailText(self.giveaway);
		cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		return cell;
	}
	if (indexPath.section == 1) {
		UITableViewCell *cell = [self cellWithIdentifier:@"date" style:UITableViewCellStyleValue1];
		cell.textLabel.text = TGL(@"Stars.Transaction.Date", @"Date");
		NSDate *date = [NSDate dateWithTimeIntervalSince1970:self.winnersDate];
		NSString *dateText = [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterShortStyle];
		cell.detailTextLabel.text = dateText;
		cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		return cell;
	}

	UITableViewCell *cell = [self cellWithIdentifier:@"toggle" style:UITableViewCellStyleDefault];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	UISwitch *toggle = [[UISwitch alloc] init];
	if (indexPath.section == 2) {
		cell.textLabel.text = TGL(@"BoostGift.Group.OnlyNewMembers", @"Only New Members");
		toggle.on = self.onlyNewMembers;
		toggle.tag = 0;
	} else {
		cell.textLabel.text = TGL(@"BoostGift.Winners", @"Show Winners Publicly");
		toggle.on = self.publicWinners;
		toggle.tag = 1;
	}
	[toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
	cell.accessoryView = toggle;
	return cell;
}

- (void)toggleChanged:(UISwitch *)toggle {
	if (toggle.tag == 0)
		self.onlyNewMembers = toggle.on;
	else
		self.publicWinners = toggle.on;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section == 1)
		[self openDatePicker];
}

- (void)openDatePicker {
	if (self.datePickerPanel)
		return;
	CGRect b = self.view.bounds;
	CGFloat panelHeight = 260;
	UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(0, b.size.height, b.size.width, panelHeight)];
	panel.backgroundColor = [UIColor colorWithWhite:0.85f alpha:1.0f];
	panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

	UIToolbar *bar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, b.size.width, 44)];
	bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	UIBarButtonItem *cancel = [UIBarButtonItem alloc];
	cancel = [cancel initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
										  target:self
										  action:@selector(dismissDatePicker)];
	UIBarButtonItem *space = [UIBarButtonItem alloc];
	space = [space initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
										target:nil
										action:nil];
	UIBarButtonItem *done = [UIBarButtonItem alloc];
	done = [done initWithBarButtonSystemItem:UIBarButtonSystemItemDone
									  target:self
									  action:@selector(commitDatePicker)];
	bar.items = @[ cancel, space, done ];
	[panel addSubview:bar];

	UIDatePicker *picker = [[UIDatePicker alloc] initWithFrame:CGRectMake(0, 44, b.size.width, panelHeight - 44)];
	picker.datePickerMode = UIDatePickerModeDateAndTime;
	picker.minuteInterval = 5;
	picker.minimumDate = [NSDate dateWithTimeIntervalSinceNow:3600];
	picker.date = [NSDate dateWithTimeIntervalSince1970:self.winnersDate];
	picker.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[panel addSubview:picker];

	self.datePicker = picker;
	self.datePickerPanel = panel;

	[self.view addSubview:panel];
	[UIView animateWithDuration:0.25 animations:^{
		panel.frame = CGRectMake(0, b.size.height - panelHeight, b.size.width, panelHeight);
	}];
}

- (void)dismissDatePicker {
	UIView *panel = self.datePickerPanel;
	if (!panel)
		return;
	self.datePickerPanel = nil;
	self.datePicker = nil;
	CGRect gone = panel.frame;
	gone.origin.y = self.view.bounds.size.height;
	[UIView animateWithDuration:0.25 animations:^{
		panel.frame = gone;
	} completion:^(BOOL finished) {
		[panel removeFromSuperview];
	}];
}

- (void)commitDatePicker {
	NSDate *when = self.datePicker.date;
	[self dismissDatePicker];
	if (!when)
		return;
	self.winnersDate = [when timeIntervalSince1970];
	[self.tableView reloadData];
}

- (void)launch {
	NSTimeInterval minWinnersDate = [[NSDate date] timeIntervalSince1970] + 60;
	if (self.winnersDate < minWinnersDate)
		self.winnersDate = minWinnersDate;

	NSInteger winnerCount = [self.giveaway[@"winnerCount"] integerValue];
	long long stars = [self.giveaway[@"prizeStars"] longLongValue];
	NSString *message = TGL(@"BoostGift.StartConfirmation.Text", @"Launch this giveaway now? This cannot be undone.");

	__weak typeof(self) weakSelf = self;
	TGAlertView *confirm = [TGAlertView alloc];
	confirm = [confirm initWithTitle:TGL(@"BoostGift.StartGiveaway", @"Launch a Giveaway")
							 message:message
				   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
					   okButtonTitle:TGL(@"BoostGift.StartConfirmation.Start", @"Launch")
					 completionBlock:^(bool okButtonPressed) {
						 __strong typeof(weakSelf) strongSelf = weakSelf;
						 if (!strongSelf || !okButtonPressed)
							 return;
						 [strongSelf commitLaunchWithWinnerCount:winnerCount stars:stars];
					 }];
	[confirm show];
}

- (void)commitLaunchWithWinnerCount:(NSInteger)winnerCount stars:(long long)stars {
	long long giveawayId = [self.giveaway[@"id"] longLongValue];
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client launchPrepaidGiveaway:giveawayId
						   inChat:self.chatId
					  winnerCount:winnerCount
					  winnersDate:self.winnersDate
				   onlyNewMembers:self.onlyNewMembers
				 hasPublicWinners:self.publicWinners
					 countryCodes:@[]
				 prizeDescription:@""
							stars:stars
					   completion:^(BOOL ok, NSString *error) {
						   __strong typeof(weakSelf) strongSelf = weakSelf;
						   if (!strongSelf)
							   return;
						   if (!ok) {
							   TGAlertView *failure = [TGAlertView alloc];
							   failure = [failure initWithTitle:TGL(@"BoostGift.StartGiveaway", @"Launch a Giveaway")
												   message:TGFriendlyErrorText(error, TGL(@"Login.UnknownError", @"An error occurred, please try again later."))
										 cancelButtonTitle:TGL(@"Common.OK", @"OK")
											 okButtonTitle:nil
										   completionBlock:nil];
							   [failure show];
							   return;
						   }
						   [strongSelf.listController removeGiveawayWithId:giveawayId];
						   [TGSnackbar showInView:strongSelf.navigationController.view
											 text:TGL(@"BoostGift.GiveawayCreated.Title", @"Giveaway launched")
										  seconds:2
										 onCommit:nil];
						   [strongSelf.navigationController popViewControllerAnimated:YES];
					   }];
}

@end

#import "TGFormSaveState.h"
#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGBusinessMessageViewController.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGBusinessService.h"
#import "TGTheme.h"
#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "TGSnackbar.h"
#import "TGQuickReplyListViewController.h"
#import "TGClient+Messages.h"

static NSString *TGBMDayText(NSInteger days) {
	return TGLPlural(@"MessageTimer.Days", days, @"%d day", @"%d days");
}

static NSString *TGBMScheduleText(NSString *schedule) {
	if ([schedule isEqualToString:@"outsideHours"])
		return TGL(@"BusinessMessageSetup.ScheduleOutsideBusinessHours", @"Outside of Opening Hours");
	if ([schedule isEqualToString:@"custom"])
		return TGL(@"BusinessMessageSetup.ScheduleCustom", @"Custom Time Span");
	return TGL(@"CallSettings.Always", @"Always");
}

@interface TGBusinessMessageViewController () <UIActionSheetDelegate>

@property (nonatomic, assign) TGBusinessMessageKind kind;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) NSInteger shortcutId;
@property (nonatomic, copy) NSString *shortcutName;
@property (nonatomic, copy) NSString *shortcutPreview;
@property (nonatomic, assign) BOOL recipientExistingChats;
@property (nonatomic, assign) BOOL recipientNewChats;
@property (nonatomic, assign) BOOL recipientContacts;
@property (nonatomic, assign) BOOL recipientNonContacts;
@property (nonatomic, copy) NSArray *recipientChatIds;
@property (nonatomic, copy) NSArray *recipientExcludedChatIds;
@property (nonatomic, assign) BOOL recipientExcludeSelected;
@property (nonatomic, assign) NSInteger inactivityDays;
@property (nonatomic, copy) NSString *schedule;
@property (nonatomic, assign) NSTimeInterval startDate;
@property (nonatomic, assign) NSTimeInterval endDate;
@property (nonatomic, assign) BOOL offlineOnly;
@property (nonatomic, assign) NSInteger editingDateField;
@property (nonatomic, strong) UIView *datePickerPanel;
@property (nonatomic, strong) UIDatePicker *datePicker;
@property (nonatomic, assign) BOOL shortcutsLoaded;
@property (nonatomic, strong) id shortcutsChangedObserverToken;

@end

@implementation TGBusinessMessageViewController

- (instancetype)initWithKind:(TGBusinessMessageKind)kind {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		_kind = kind;
		_inactivityDays = 7;
		_schedule = @"always";
		self.title = kind == TGBusinessMessageGreeting
			? TGL(@"QuickReply.TitleGreetingMessage", @"Greeting Message")
			: TGL(@"QuickReply.TitleAwayMessage", @"Away Message");
	}
	return self;
}

- (void)dealloc {
	if (self.shortcutsChangedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.shortcutsChangedObserverToken];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.navigationItem.rightBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"Common.Save", @"Save") bold:YES
									   target:self
									   action:@selector(save)];
	self.navigationItem.rightBarButtonItem.enabled = NO;
	__weak typeof(self) weakSelf = self;
	self.shortcutsChangedObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGQuickReplyShortcutsUpdatedNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					strongSelf.shortcutsLoaded = YES;
					[strongSelf resolveShortcutName];
				}];
	[self reload];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)reload {
	__weak typeof(self) weakSelf = self;
	[TGBusinessService businessSettingsWithCompletion:^(NSDictionary *settings, BOOL failed) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (failed) {
			strongSelf.navigationItem.rightBarButtonItem.enabled = TGFormCanSave(YES, YES, NO);
			[TGSnackbar showInView:strongSelf.navigationController.view
							  text:TGL(@"Toast.CouldNotLoadBusinessSettings", @"Could not read your business settings")
						   seconds:2
						  onCommit:nil];
			return;
		}
		NSDictionary *entry = strongSelf.kind == TGBusinessMessageGreeting
			? settings[@"greeting"]
			: settings[@"away"];
		if (![entry isKindOfClass:NSDictionary.class])
			entry = @{};
		strongSelf.enabled = [entry[@"enabled"] boolValue];
		strongSelf.shortcutId = [entry[@"shortcutId"] integerValue];
		NSDictionary *recipients = entry[@"recipients"];
		strongSelf.recipientExistingChats = [recipients[@"existingChats"] boolValue];
		strongSelf.recipientNewChats = [recipients[@"newChats"] boolValue];
		strongSelf.recipientContacts = [recipients[@"contacts"] boolValue];
		strongSelf.recipientNonContacts = [recipients[@"nonContacts"] boolValue];
		strongSelf.recipientChatIds = [recipients[@"chatIds"] isKindOfClass:NSArray.class] ? recipients[@"chatIds"] : @[];
		strongSelf.recipientExcludedChatIds = [recipients[@"excludedChatIds"] isKindOfClass:NSArray.class] ? recipients[@"excludedChatIds"] : @[];
		strongSelf.recipientExcludeSelected = [recipients[@"excludeSelected"] boolValue];
		if (strongSelf.kind == TGBusinessMessageGreeting) {
			NSInteger days = [entry[@"inactivityDays"] integerValue];
			strongSelf.inactivityDays = days ? days : 7;
		} else {
			strongSelf.schedule = [entry[@"schedule"] isKindOfClass:NSString.class]
				? entry[@"schedule"]
				: @"always";
			strongSelf.startDate = [entry[@"startDate"] doubleValue];
			strongSelf.endDate = [entry[@"endDate"] doubleValue];
			strongSelf.offlineOnly = [entry[@"offlineOnly"] boolValue];
		}
		[TGBusinessService loadQuickReplyShortcuts];
		strongSelf.navigationItem.rightBarButtonItem.enabled = YES;
		[strongSelf resolveShortcutName];
	}];
}

- (void)resolveShortcutName {
	NSArray *shortcuts = [TGBusinessService quickReplyShortcuts];
	NSString *name = nil;
	NSString *preview = nil;
	for (NSDictionary *shortcut in shortcuts) {
		if ([shortcut[@"id"] integerValue] == self.shortcutId) {
			name = shortcut[@"name"];
			preview = shortcut[@"preview"];
			break;
		}
	}
	self.shortcutName = name;
	self.shortcutPreview = preview.length ? preview : nil;
	self.loaded = YES;
	[self.tableView reloadData];
}

#pragma mark - save

- (void)save {
	if (!self.enabled) {
		[self commitWithSettings:nil];
		return;
	}
	if (!self.shortcutId) {
		[self showAlert:TGL(@"Business.ChooseAMessageFirst", @"Choose a message first.")];
		return;
	}
	if (!self.recipientExistingChats && !self.recipientNewChats && !self.recipientContacts && !self.recipientNonContacts) {
		[self showAlert:TGL(@"BusinessMessageSetup.Recipients.NoneSelected", @"Choose at least one recipient category.")];
		return;
	}
	if (self.kind != TGBusinessMessageGreeting && [self.schedule isEqualToString:@"custom"]) {
		if (self.startDate <= 0 || self.endDate <= 0 || self.endDate <= self.startDate) {
			[self showAlert:TGL(@"BusinessMessageSetup.ScheduleCustomRangeInvalid", @"Set a start and end date, with the end date after the start date.")];
			return;
		}
	}
	NSDictionary *recipients = @{
		@"existingChats" : @(self.recipientExistingChats),
		@"newChats" : @(self.recipientNewChats),
		@"contacts" : @(self.recipientContacts),
		@"nonContacts" : @(self.recipientNonContacts),
		@"chatIds" : self.recipientChatIds ?: @[],
		@"excludedChatIds" : self.recipientExcludedChatIds ?: @[],
		@"excludeSelected" : @(self.recipientExcludeSelected),
	};
	NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithDictionary:@{
		@"shortcutId" : @(self.shortcutId),
		@"recipients" : recipients,
	}];
	if (self.kind == TGBusinessMessageGreeting) {
		settings[@"inactivityDays"] = @(self.inactivityDays);
	} else {
		settings[@"schedule"] = self.schedule;
		settings[@"startDate"] = @((long long)self.startDate);
		settings[@"endDate"] = @((long long)self.endDate);
		settings[@"offlineOnly"] = @(self.offlineOnly);
	}
	[self commitWithSettings:settings];
}

- (void)commitWithSettings:(NSDictionary *)settings {
	__weak typeof(self) weakSelf = self;
	void (^completion)(BOOL) = ^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[TGSnackbar showInView:strongSelf.navigationController.view
							  text:TGL(@"Toast.CouldNotSaveBusinessMessage", @"Could not save the message settings")
						   seconds:2
						  onCommit:nil];
			return;
		}
		[TGSnackbar showInView:strongSelf.navigationController.view
						  text:TGL(@"PeerInfo.SavedMessagesTabTitle", @"Saved")
					   seconds:2
					  onCommit:nil];
		[strongSelf.navigationController popViewControllerAnimated:YES];
	};
	if (self.kind == TGBusinessMessageGreeting)
		[TGBusinessService setBusinessGreetingMessage:settings completion:completion];
	else
		[TGBusinessService setBusinessAwayMessage:settings completion:completion];
}

- (void)showAlert:(NSString *)message {
	TGAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:nil message:message
						delegate:nil
			   cancelButtonTitle:TGL(@"Common.OK", @"OK")
			   otherButtonTitles:nil];
	[alert show];
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	switch (section) {
		case 0:
			return 1;
		case 1:
			return self.shortcutPreview.length ? 2 : 1;
		case 2:
			return 4;
		case 3:
			return [self awayRowCount];
	}
	return 0;
}

- (NSInteger)awayRowCount {
	if (self.kind == TGBusinessMessageGreeting)
		return 1;
	return [self.schedule isEqualToString:@"custom"] ? 4 : 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	switch (section) {
		case 1:
			return self.kind == TGBusinessMessageGreeting
				? TGL(@"BusinessMessageSetup.GreetingMessageSectionHeader", @"Greeting Message")
				: TGL(@"BusinessMessageSetup.AwayMessageSectionHeader", @"Away Message");
		case 2:
			return TGL(@"BusinessMessageSetup.RecipientsSectionHeader", @"Recipients");
		case 3:
			return self.kind == TGBusinessMessageGreeting
				? TGL(@"BusinessMessageSetup.InactivitySectionHeader", @"Inactive Period")
				: TGL(@"BusinessMessageSetup.ScheduleSectionHeader", @"Schedule");
	}
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
	if (section == 0)
		return self.kind == TGBusinessMessageGreeting
			? TGL(@"BusinessMessageSetup.TextGreetingMessage", @"Sent once to a private chat that has been inactive for the chosen period.")
			: TGL(@"BusinessMessageSetup.TextAwayMessage", @"Sent automatically to private chats while you are away.");
	if (section == 2)
		return TGL(@"BusinessMessageSetup.Recipients.AwayMessageFooter", @"Choose which private chats can receive this message.");
	return nil;
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

- (UITableViewCell *)cellWithIdentifier:(NSString *)identifier style:(UITableViewCellStyle)style {
	UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:identifier];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:identifier];
	[[TGTheme shared] styleCell:cell];
	cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
	cell.accessoryView = nil;
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	return cell;
}

- (UISwitch *)switchWithTag:(NSInteger)tag on:(BOOL)on {
	UISwitch *toggle = [[UISwitch alloc] init];
	toggle.tag = tag;
	toggle.on = on;
	[toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
	return toggle;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 0) {
		UITableViewCell *cell = [self cellWithIdentifier:@"enabled" style:UITableViewCellStyleDefault];
		cell.textLabel.text = self.kind == TGBusinessMessageGreeting
			? TGL(@"BusinessMessageSetup.ToggleGreetingMessage", @"Send a Greeting Message")
			: TGL(@"BusinessMessageSetup.ToggleAwayMessage", @"Send an Away Message");
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.accessoryView = [self switchWithTag:0 on:self.enabled];
		return cell;
	}

	if (indexPath.section == 1 && indexPath.row == 0) {
		UITableViewCell *cell = [self cellWithIdentifier:@"message" style:UITableViewCellStyleValue1];
		cell.textLabel.text = TGL(@"Conversation.InputTextPlaceholder", @"Message");
		cell.detailTextLabel.text = self.shortcutName.length
			? [NSString stringWithFormat:@"/%@", self.shortcutName]
			: TGL(@"GroupInfo.SharedMediaNone", @"None");
		cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		return cell;
	}

	if (indexPath.section == 1 && indexPath.row == 1) {
		UITableViewCell *cell = [self cellWithIdentifier:@"messagePreview" style:UITableViewCellStyleDefault];
		cell.textLabel.text = self.shortcutPreview;
		cell.textLabel.textColor = [[TGTheme shared] secondaryTextColour];
		cell.textLabel.font = [UIFont systemFontOfSize:15];
		cell.textLabel.numberOfLines = 1;
		return cell;
	}

	if (indexPath.section == 2) {
		UITableViewCell *cell = [self cellWithIdentifier:@"recipient" style:UITableViewCellStyleDefault];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		switch (indexPath.row) {
			case 0:
				cell.textLabel.text = TGL(@"BusinessMessageSetup.Recipients.CategoryExistingChats", @"Existing Chats");
				cell.accessoryView = [self switchWithTag:10 on:self.recipientExistingChats];
				break;
			case 1:
				cell.textLabel.text = TGL(@"BusinessMessageSetup.Recipients.CategoryNewChats", @"New Chats");
				cell.accessoryView = [self switchWithTag:11 on:self.recipientNewChats];
				break;
			case 2:
				cell.textLabel.text = TGL(@"BusinessMessageSetup.Recipients.CategoryContacts", @"Contacts");
				cell.accessoryView = [self switchWithTag:12 on:self.recipientContacts];
				break;
			default:
				cell.textLabel.text = TGL(@"BusinessMessageSetup.Recipients.CategoryNonContacts", @"Non-Contacts");
				cell.accessoryView = [self switchWithTag:13 on:self.recipientNonContacts];
				break;
		}
		return cell;
	}

	if (self.kind == TGBusinessMessageGreeting) {
		UITableViewCell *cell = [self cellWithIdentifier:@"inactivity" style:UITableViewCellStyleValue1];
		cell.textLabel.text = TGL(@"Business.InactiveFor", @"Inactive For");
		cell.detailTextLabel.text = TGBMDayText(self.inactivityDays);
		cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		return cell;
	}

	BOOL custom = [self.schedule isEqualToString:@"custom"];
	if (indexPath.row == 0) {
		UITableViewCell *cell = [self cellWithIdentifier:@"schedule" style:UITableViewCellStyleValue1];
		cell.textLabel.text = TGL(@"BusinessMessageSetup.ScheduleSectionHeader", @"Schedule");
		cell.detailTextLabel.text = TGBMScheduleText(self.schedule);
		cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		return cell;
	}
	if (custom && indexPath.row == 1) {
		UITableViewCell *cell = [self cellWithIdentifier:@"start" style:UITableViewCellStyleValue1];
		cell.textLabel.text = TGL(@"BusinessMessageSetup.ScheduleStartTime", @"Starts");
		cell.detailTextLabel.text = [self dateText:self.startDate];
		cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		return cell;
	}
	if (custom && indexPath.row == 2) {
		UITableViewCell *cell = [self cellWithIdentifier:@"end" style:UITableViewCellStyleValue1];
		cell.textLabel.text = TGL(@"BoostGift.DateEnds", @"Ends");
		cell.detailTextLabel.text = [self dateText:self.endDate];
		cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		return cell;
	}
	UITableViewCell *cell = [self cellWithIdentifier:@"offline" style:UITableViewCellStyleDefault];
	cell.textLabel.text = TGL(@"BusinessMessageSetup.SendWhenOffline", @"Only When Offline");
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.accessoryView = [self switchWithTag:20 on:self.offlineOnly];
	return cell;
}

- (NSString *)dateText:(NSTimeInterval)stamp {
	if (stamp <= 0)
		return TGL(@"BusinessMessageSetup.ScheduleTimePlaceholder", @"Set");
	NSDate *date = [NSDate dateWithTimeIntervalSince1970:stamp];
	return [NSDateFormatter localizedStringFromDate:date
										  dateStyle:NSDateFormatterMediumStyle
										  timeStyle:NSDateFormatterShortStyle];
}

- (void)switchChanged:(UISwitch *)toggle {
	switch (toggle.tag) {
		case 0:
			self.enabled = toggle.on;
			break;
		case 10:
			self.recipientExistingChats = toggle.on;
			break;
		case 11:
			self.recipientNewChats = toggle.on;
			break;
		case 12:
			self.recipientContacts = toggle.on;
			break;
		case 13:
			self.recipientNonContacts = toggle.on;
			break;
		case 20:
			self.offlineOnly = toggle.on;
			break;
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section == 1) {
		[self openMessagePicker];
		return;
	}
	if (indexPath.section != 3)
		return;
	if (self.kind == TGBusinessMessageGreeting) {
		[self openInactivityPickerFromRowAtIndexPath:indexPath];
		return;
	}
	BOOL custom = [self.schedule isEqualToString:@"custom"];
	if (indexPath.row == 0) {
		[self openSchedulePickerFromRowAtIndexPath:indexPath];
	} else if (custom && indexPath.row == 1) {
		[self openDatePickerForField:0 current:self.startDate];
	} else if (custom && indexPath.row == 2) {
		[self openDatePickerForField:1 current:self.endDate];
	}
}

- (void)openMessagePicker {
	TGQuickReplyListViewController *list = [[TGQuickReplyListViewController alloc] initWithChatId:0];
	__weak typeof(self) weakSelf = self;
	list.onPicked = ^(NSInteger shortcutId, NSString *name) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.shortcutId = shortcutId;
		strongSelf.shortcutName = name;
		[strongSelf resolveShortcutName];
	};
	if (!self.shortcutId && self.shortcutsLoaded && [TGBusinessService quickReplyShortcuts].count == 0)
		[list beginCreatingShortcutWithText:@""];
	[self.navigationController pushViewController:list animated:YES];
}

- (void)openInactivityPickerFromRowAtIndexPath:(NSIndexPath *)indexPath {
	NSArray *options = @[ @7, @14, @21, @28 ];
	NSMutableArray *actions = [NSMutableArray array];
	for (NSNumber *days in options) {
		TGActionSheetAction *item = [TGActionSheetAction alloc];
		item = [item initWithTitle:TGBMDayText(days.integerValue) action:[days stringValue]];
		[actions addObject:item];
	}
	TGActionSheetAction *cancel = [TGActionSheetAction alloc];
	cancel = [cancel initWithTitle:TGL(@"Common.Cancel", @"Cancel")
							action:@"cancel"
							  type:TGActionSheetActionTypeCancel];
	[actions addObject:cancel];
	__weak typeof(self) weakSelf = self;
	TGActionSheet *sheet = [TGActionSheet alloc];
	sheet = [sheet initWithTitle:nil actions:actions
					 actionBlock:^(id target, NSString *action) {
						 __strong typeof(weakSelf) strongSelf = weakSelf;
						 if (!strongSelf || [action isEqualToString:@"cancel"])
							 return;
						 strongSelf.inactivityDays = [action integerValue];
						 [strongSelf.tableView reloadData];
					 }
						  target:self];
	UITableViewCell *rowCell = [self.tableView cellForRowAtIndexPath:indexPath];
	CGRect anchorRect = rowCell ? rowCell.frame
		: CGRectMake(CGRectGetMidX(self.tableView.bounds), CGRectGetMidY(self.tableView.bounds), 1, 1);
	[sheet tg_showFromRect:anchorRect inView:self.tableView];
}

- (void)openSchedulePickerFromRowAtIndexPath:(NSIndexPath *)indexPath {
	NSArray *actions = @[
		[[TGActionSheetAction alloc] initWithTitle:TGBMScheduleText(@"always") action:@"always"],
		[[TGActionSheetAction alloc] initWithTitle:TGBMScheduleText(@"outsideHours") action:@"outsideHours"],
		[[TGActionSheetAction alloc] initWithTitle:TGBMScheduleText(@"custom") action:@"custom"],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Common.Cancel", @"Cancel")
											action:@"cancel"
											  type:TGActionSheetActionTypeCancel],
	];
	__weak typeof(self) weakSelf = self;
	TGActionSheet *sheet = [TGActionSheet alloc];
	sheet = [sheet initWithTitle:nil actions:actions
					 actionBlock:^(id target, NSString *action) {
						 __strong typeof(weakSelf) strongSelf = weakSelf;
						 if (!strongSelf || [action isEqualToString:@"cancel"])
							 return;
						 strongSelf.schedule = action;
						 [strongSelf.tableView reloadData];
					 }
						  target:self];
	UITableViewCell *rowCell = [self.tableView cellForRowAtIndexPath:indexPath];
	CGRect anchorRect = rowCell ? rowCell.frame
		: CGRectMake(CGRectGetMidX(self.tableView.bounds), CGRectGetMidY(self.tableView.bounds), 1, 1);
	[sheet tg_showFromRect:anchorRect inView:self.tableView];
}

- (void)openDatePickerForField:(NSInteger)field current:(NSTimeInterval)current {
	if (self.datePickerPanel)
		return;
	self.editingDateField = field;

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
	picker.date = current > 0 ? [NSDate dateWithTimeIntervalSince1970:current]
							  : [NSDate dateWithTimeIntervalSinceNow:3600];
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
	NSInteger field = self.editingDateField;
	[self dismissDatePicker];
	if (!when)
		return;
	if (field == 0)
		self.startDate = [when timeIntervalSince1970];
	else
		self.endDate = [when timeIntervalSince1970];
	[self.tableView reloadData];
}

@end

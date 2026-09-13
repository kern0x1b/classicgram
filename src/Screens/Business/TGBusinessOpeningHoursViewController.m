#import "TGFormSaveState.h"
#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGBusinessOpeningHoursViewController.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGBusinessService.h"
#import "TGTheme.h"
#import "TGAlertView.h"
#import "TGSnackbar.h"
#import "TGTimeZonePickerViewController.h"

static NSString *TGOHDayName(NSInteger day) {
	static NSArray *names = nil;
	if (!names)
		names = @[
			TGL(@"Weekday.Monday", @"Monday"),
			TGL(@"Weekday.Tuesday", @"Tuesday"),
			TGL(@"Weekday.Wednesday", @"Wednesday"),
			TGL(@"Weekday.Thursday", @"Thursday"),
			TGL(@"Weekday.Friday", @"Friday"),
			TGL(@"Weekday.Saturday", @"Saturday"),
			TGL(@"Weekday.Sunday", @"Sunday"),
		];
	if (day < 0 || day >= (NSInteger)names.count)
		return @"";
	return names[(NSUInteger)day];
}

static NSString *TGOHTimeText(NSInteger minute) {
	NSInteger clamped = MAX(0, MIN(minute, 24 * 60));
	NSInteger hour = clamped / 60;
	NSInteger min = clamped % 60;
	return [NSString stringWithFormat:@"%02ld:%02ld", (long)hour, (long)min];
}

@interface TGBusinessOpeningHoursViewController ()

@property (nonatomic, strong) NSMutableArray *days;
@property (nonatomic, copy) NSString *timeZoneId;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL readOnly;
@property (nonatomic, assign) BOOL saving;
@property (nonatomic, assign) NSInteger editingDay;
@property (nonatomic, assign) NSInteger editingField;
@property (nonatomic, strong) UIView *pickerPanel;
@property (nonatomic, strong) UIDatePicker *picker;

@end

@implementation TGBusinessOpeningHoursViewController

- (instancetype)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		self.title = TGL(@"Business.OpeningHours", @"Opening Hours");
		_days = [NSMutableArray array];
		for (NSInteger i = 0; i < 7; i++)
			[_days addObject:[NSMutableDictionary dictionaryWithDictionary:@{
				@"open" : @NO,
				@"startMinute" : @(9 * 60),
				@"endMinute" : @(18 * 60),
			}]];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.navigationItem.rightBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"Common.Save", @"Save") bold:YES
									   target:self
									   action:@selector(save)];

	__weak typeof(self) weakSelf = self;
	[TGBusinessService businessSettingsWithCompletion:^(NSDictionary *settings, BOOL failed) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (failed) {
			strongSelf.navigationItem.rightBarButtonItem.enabled =
				TGFormCanSave(YES, YES, strongSelf.readOnly);
			[TGSnackbar showInView:strongSelf.navigationController.view
							  text:TGL(@"Toast.CouldNotLoadBusinessSettings", @"Could not read your business settings")
						   seconds:2
						  onCommit:nil];
			return;
		}
		NSDictionary *hours = settings[@"hours"];
		NSArray *loadedDays = hours[@"days"];
		if ([loadedDays isKindOfClass:NSArray.class] && loadedDays.count == 7)
			strongSelf.days = [loadedDays mutableCopy];
		strongSelf.timeZoneId = [hours[@"timeZoneId"] length] ? hours[@"timeZoneId"] : [[NSTimeZone localTimeZone] name];
		strongSelf.readOnly = [hours[@"hasComplexSchedule"] boolValue];
		strongSelf.loaded = YES;
		strongSelf.navigationItem.rightBarButtonItem.enabled =
			TGFormCanSave(YES, NO, strongSelf.readOnly);
		[strongSelf.tableView reloadData];
		if (strongSelf.readOnly)
			[strongSelf showAlert:TGL(@"BusinessHoursSetup.TooComplexToEdit", @"This business's hours are more complex than this app can edit. Open Settings on another device to change them.")];
	}];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return section == 0 ? 1 : 7;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section != 1)
		return nil;
	if (self.readOnly)
		return TGL(@"BusinessHoursSetup.TooComplexToEdit", @"This business's hours are more complex than this app can edit. Open Settings on another device to change them.");
	return TGL(@"Business.OpeningHoursInfo", @"Show to your customers when you are open for business.");
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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 0) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"timeZone"];
		if (!cell)
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"timeZone"];
		[[TGTheme shared] styleCell:cell];
		cell.textLabel.font = TGGroupedRowTitleFont();
		cell.textLabel.text = TGL(@"BusinessHoursSetup.TimeZone", @"Time Zone");
		cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
		cell.detailTextLabel.text = self.timeZoneId;
		cell.accessoryType = self.readOnly ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator;
		cell.selectionStyle = self.readOnly ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleBlue;
		return cell;
	}

	NSDictionary *day = self.days[(NSUInteger)indexPath.row];
	BOOL open = [day[@"open"] boolValue];
	NSInteger extraIntervals = [day[@"intervals"] isKindOfClass:NSArray.class]
		? (NSInteger)[day[@"intervals"] count] - 1
		: 0;

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"day"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"day"];
	[[TGTheme shared] styleCell:cell];
	cell.textLabel.font = TGGroupedRowTitleFont();
	cell.textLabel.text = TGOHDayName(indexPath.row);
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	NSString *rangeText = open
		? [NSString stringWithFormat:@"%@ – %@",
			  TGOHTimeText([day[@"startMinute"] integerValue]),
			  TGOHTimeText([day[@"endMinute"] integerValue])]
		: TGL(@"BusinessHoursSetup.DayClosed", @"Closed");
	cell.detailTextLabel.text = (open && extraIntervals > 0)
		? [NSString stringWithFormat:@"%@ (+%ld)", rangeText, (long)extraIntervals]
		: rangeText;
	BOOL interactive = open && !self.readOnly;
	cell.accessoryType = interactive ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
	cell.selectionStyle = interactive ? UITableViewCellSelectionStyleBlue : UITableViewCellSelectionStyleNone;

	UISwitch *toggle = [[UISwitch alloc] init];
	toggle.tag = indexPath.row;
	toggle.on = open;
	toggle.enabled = !self.readOnly;
	[toggle addTarget:self action:@selector(daySwitchChanged:) forControlEvents:UIControlEventValueChanged];
	cell.accessoryView = toggle;
	return cell;
}

- (void)daySwitchChanged:(UISwitch *)toggle {
	if (self.readOnly)
		return;
	NSMutableDictionary *day = self.days[(NSUInteger)toggle.tag];
	day[@"open"] = @(toggle.on);
	[self.tableView reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:toggle.tag inSection:1] ]
						  withRowAnimation:UITableViewRowAnimationNone];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (self.readOnly)
		return;
	if (indexPath.section == 0) {
		[self openTimeZonePicker];
		return;
	}
	NSDictionary *day = self.days[(NSUInteger)indexPath.row];
	if (![day[@"open"] boolValue])
		return;
	[self openTimePickerForDay:indexPath.row field:0];
}

- (void)openTimeZonePicker {
	TGTimeZonePickerViewController *picker = [[TGTimeZonePickerViewController alloc] init];
	picker.selectedTimeZoneId = self.timeZoneId;
	__weak typeof(self) weakSelf = self;
	picker.onPicked = ^(NSString *timeZoneId) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.timeZoneId = timeZoneId;
		[strongSelf.tableView reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:0 inSection:0] ]
									 withRowAnimation:UITableViewRowAnimationNone];
	};
	[self.navigationController pushViewController:picker animated:YES];
}

#pragma mark - time picker

- (void)openTimePickerForDay:(NSInteger)day field:(NSInteger)field {
	if (self.pickerPanel)
		return;
	self.editingDay = day;
	self.editingField = field;

	NSDictionary *entry = self.days[(NSUInteger)day];
	NSInteger minute = field == 0 ? [entry[@"startMinute"] integerValue] : [entry[@"endMinute"] integerValue];

	CGRect b = self.view.bounds;
	CGFloat panelHeight = 260;
	UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(0, b.size.height, b.size.width, panelHeight)];
	panel.backgroundColor = [UIColor colorWithWhite:0.85f alpha:1.0f];
	panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

	UIToolbar *bar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, b.size.width, 44)];
	bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	NSString *title = field == 0 ? TGL(@"BusinessHoursSetup.DayIntervalStart", @"Opens At") : TGL(@"BusinessHoursSetup.DayIntervalEnd", @"Closes At");
	UIBarButtonItem *label = [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStylePlain target:nil action:nil];
	UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	UIBarButtonItem *doneAlloc = [UIBarButtonItem alloc];
	UIBarButtonItem *done = [doneAlloc
		initWithBarButtonSystemItem:UIBarButtonSystemItemDone
							 target:self
							 action:@selector(commitTimePicker)];
	bar.items = @[ label, space, done ];
	[panel addSubview:bar];

	UIDatePicker *picker = [[UIDatePicker alloc] initWithFrame:CGRectMake(0, 44, b.size.width, panelHeight - 44)];
	picker.datePickerMode = UIDatePickerModeTime;
	picker.minuteInterval = 5;
	picker.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
	NSDate *base = [NSDate dateWithTimeIntervalSince1970:0];
	picker.date = [base dateByAddingTimeInterval:minute * 60];
	picker.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[panel addSubview:picker];

	self.picker = picker;
	self.pickerPanel = panel;
	[self.view addSubview:panel];
	[UIView animateWithDuration:0.25 animations:^{
		panel.frame = CGRectMake(0, b.size.height - panelHeight, b.size.width, panelHeight);
	}];
}

- (void)dismissTimePicker {
	UIView *panel = self.pickerPanel;
	if (!panel)
		return;
	self.pickerPanel = nil;
	self.picker = nil;
	CGRect gone = panel.frame;
	gone.origin.y = self.view.bounds.size.height;
	[UIView animateWithDuration:0.25 animations:^{
		panel.frame = gone;
	} completion:^(BOOL finished) {
		[panel removeFromSuperview];
	}];
}

- (void)commitTimePicker {
	NSDate *when = self.picker.date;
	NSInteger day = self.editingDay;
	NSInteger field = self.editingField;
	[self dismissTimePicker];
	if (!when)
		return;

	NSCalendar *calendar = [NSCalendar currentCalendar];
	calendar.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
	NSDateComponents *components = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute fromDate:when];
	NSInteger minute = components.hour * 60 + components.minute;

	NSMutableDictionary *entry = self.days[(NSUInteger)day];
	if (field == 0) {
		entry[@"startMinute"] = @(minute);
		if ([entry[@"endMinute"] integerValue] <= minute)
			entry[@"endMinute"] = @(MIN(minute + 60, 24 * 60));
		[self.tableView reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:day inSection:1] ]
							  withRowAnimation:UITableViewRowAnimationNone];
		[self openTimePickerForDay:day field:1];
		return;
	}
	NSInteger startMinute = [entry[@"startMinute"] integerValue];
	if (minute <= startMinute) {
		[self showAlert:TGL(@"BusinessHoursSetup.OvernightNotSupported", @"An overnight schedule for a single day can't be edited here. Choose a closing time later than the opening time.")];
		return;
	}
	entry[@"endMinute"] = @(minute);
	[self.tableView reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:day inSection:1] ]
						  withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - save

- (void)save {
	if (self.readOnly || self.saving)
		return;
	self.saving = YES;
	self.navigationItem.rightBarButtonItem.enabled = NO;
	__weak typeof(self) weakSelf = self;
	[TGBusinessService setBusinessOpeningHoursTimeZoneId:self.timeZoneId days:self.days completion:^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.saving = NO;
		if (!ok) {
			strongSelf.navigationItem.rightBarButtonItem.enabled = YES;
			[strongSelf showAlert:TGL(@"Toast.CouldNotSaveOpeningHours", @"Could not save opening hours")];
			return;
		}
		[TGSnackbar showInView:strongSelf.navigationController.view
						  text:TGL(@"Toast.OpeningHoursSaved", @"Saved")
					   seconds:2
					  onCommit:nil];
		[strongSelf.navigationController popViewControllerAnimated:YES];
	}];
}

- (void)showAlert:(NSString *)message {
	TGAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:nil
						 message:message
						delegate:nil
			   cancelButtonTitle:TGL(@"Common.OK", @"OK")
			   otherButtonTitles:nil];
	[alert show];
}

@end

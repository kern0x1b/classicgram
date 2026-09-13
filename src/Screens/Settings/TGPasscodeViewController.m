#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGActionSheet.h"
#import "TGPrivacyViewController.h"
#import "TGPrivacyViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGSessionsViewController.h"
#import "TGPasscodeLock.h"
#import "TGSecurityStepViewController.h"
#import "TGActionSheetIndexBuilder.h"

#pragma mark - passcode

@interface TGPasscodeViewController () <UIActionSheetDelegate>
@property (nonatomic, assign) BOOL locked;
@property (nonatomic, assign) BOOL simple;
@end

static BOOL TGPasscodeVerifyCurrentSubmit(TGSecurityStepViewController *sender, NSString *text) {
	NSTimeInterval remaining = [[TGPasscodeLock shared] lockoutRemainingSeconds];
	if (remaining > 0) {
		[sender refuseWithMessage:[NSString stringWithFormat:
				TGL(@"EnterPasscode.TryAgainInSecondsFormat", @"Try again in %d s"),
			(int)ceil(remaining)]];
		return NO;
	}
	if (![[TGPasscodeLock shared] attemptUnlock:text]) {
		[sender refuseWithMessage:TGL(@"Passcode.ThatPasscodeIsWrong", @"That passcode is wrong.")];
		return NO;
	}
	return YES;
}

@implementation TGPasscodeViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"PrivacySettings.Passcode", @"Passcode Lock");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.rowHeight = 44;
	[self readState];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	[self readState];
	[self.tableView reloadData];
}

- (void)readState {
	self.locked = [[TGPasscodeLock shared] isSet];
	self.simple = [[TGPasscodeLock shared] isSimple];
}

- (NSArray *)autoLockOptions {
	return [NSArray arrayWithObjects:
			[NSNumber numberWithInteger:0],
		[NSNumber numberWithInteger:60],
		[NSNumber numberWithInteger:5 * 60],
		[NSNumber numberWithInteger:60 * 60],
		[NSNumber numberWithInteger:5 * 60 * 60], nil];
}

- (NSString *)autoLockTitleForSeconds:(NSInteger)seconds {
	if (seconds <= 0)
		return TGL(@"Passcode.AutoLockImmediately", @"Immediately");
	if (seconds == 60)
		return TGL(@"PasscodeSettings.AutoLock.IfAwayFor_1minute", @"If away for 1 min");
	if (seconds == 5 * 60)
		return TGL(@"PasscodeSettings.AutoLock.IfAwayFor_5minutes", @"If away for 5 min");
	if (seconds == 60 * 60)
		return TGL(@"PasscodeSettings.AutoLock.IfAwayFor_1hour", @"If away for 1 hour");
	if (seconds == 5 * 60 * 60)
		return TGL(@"PasscodeSettings.AutoLock.IfAwayFor_5hours", @"If away for 5 hours");
	if (seconds < 60 * 60)
		return [NSString stringWithFormat:TGL(@"Passcode.AutoLockInMinutesFormat", @"in %d minutes"), (int)(seconds / 60)];
	return [NSString stringWithFormat:TGL(@"Passcode.AutoLockInHoursFormat", @"in %d hours"), (int)(seconds / 3600)];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return self.locked ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return 1;
	return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section == 0)
		return TGL(@"Passcode.OnFooter", @"When the passcode is on, Telegram asks for it before showing "
				   @"your chats again.");
	if (section == 1)
		return TGL(@"Passcode.AutoLockAndSimpleFooter",
				@"Auto-Lock is how long Telegram may stay open in the background "
				@"before it asks again. A simple passcode is four digits; turn it "
				@"off to use letters and numbers instead.");
	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	TGTheme *theme = [TGTheme shared];
	CGFloat measured = [theme groupedCommentHeightForText:caption width:tableView.bounds.size.width];
	return TGGroupedFooterHeight(caption, measured);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	TGTheme *theme = [TGTheme shared];
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	return [theme groupedCommentViewWithText:caption width:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 0) {
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
		cell.textLabel.text = TGL(@"PrivacySettings.Passcode", @"Passcode Lock");
		cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
		cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
		cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		[(UISwitch *)cell.accessoryView setOn:self.locked animated:NO];
		return cell;
	}

	if (indexPath.row == 0) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"autolock"];
		if (!cell)
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
										  reuseIdentifier:@"autolock"];
		[[TGTheme shared] styleCell:cell];
		cell.textLabel.text = TGL(@"PasscodeSettings.AutoLock", @"Auto-Lock");
		cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
		cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
		cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
		cell.detailTextLabel.text = [self autoLockTitleForSeconds:
				[[TGPasscodeLock shared] autoLockSeconds]];
		cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
		cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		return cell;
	}

	if (indexPath.row == 1) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"simple"];
		if (!cell) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
										  reuseIdentifier:@"simple"];
			UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectZero];
			[toggle addTarget:self action:@selector(simpleChanged:)
				forControlEvents:UIControlEventValueChanged];
			cell.accessoryView = toggle;
		}
		[[TGTheme shared] styleCell:cell];
		cell.textLabel.text = TGL(@"PasscodeSettings.SimplePasscode", @"Simple Passcode");
		cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
		cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
		cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		[(UISwitch *)cell.accessoryView setOn:self.simple animated:NO];
		return cell;
	}

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"change"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"change"];
	[[TGTheme shared] styleCell:cell];
	cell.textLabel.text = TGL(@"PasscodeSettings.ChangePasscode", @"Change Passcode");
	cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
	cell.textLabel.textColor = [[TGTheme shared] groupedActionColour];
	cell.textLabel.highlightedTextColor = [UIColor whiteColor];
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	return cell;
}

- (TGSecurityStepViewController *)passcodeStepWithTitle:(NSString *)title
												caption:(NSString *)caption
												 footer:(NSString *)footer
												 simple:(BOOL)simple {
	TGSecurityStepViewController *step = [[TGSecurityStepViewController alloc] init];
	step.stepTitle = title;
	step.stepCaption = caption;
	step.placeholder = TGL(@"PrivacySettings.Passcode", @"Passcode Lock");
	step.footerText = footer;
	step.secure = YES;
	step.numeric = simple;
	return step;
}

- (BOOL)passcodeIsAllDigits:(NSString *)passcode {
	NSCharacterSet *notDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
	return [passcode rangeOfCharacterFromSet:notDigits].location == NSNotFound;
}

- (void)toggleChanged:(UISwitch *)sender {
	if (sender.on) {
		[self startSetPasscodeSimple:YES];
		[sender setOn:NO animated:NO];
		return;
	}
	[sender setOn:YES animated:NO];
	[self startVerifyThen:^{
		[[TGPasscodeLock shared] removePasscode];
	}];
}

- (void)simpleChanged:(UISwitch *)sender {
	BOOL wanted = sender.on;
	[sender setOn:!wanted animated:NO];
	__weak typeof(self) weakSelf = self;
	[self startVerifyThenChange:^{
		[weakSelf startSetPasscodeSimple:wanted];
	}];
}

- (void)startVerifyThen:(dispatch_block_t)done {
	__weak typeof(self) weakSelf = self;
	NSString *title = TGL(@"PrivacySettings.Passcode", @"Passcode Lock");
	NSString *caption = TGL(@"EnterPasscode.EnterCurrentPasscode", @"Enter your current passcode");
	NSString *footer = TGL(@"Passcode.EnterCurrentPasscodeFooter", @"Enter the passcode you are using now.");
	TGSecurityStepViewController *step = [self passcodeStepWithTitle:title caption:caption footer:footer simple:self.simple];
	step.actionTitle = TGL(@"Common.Done", @"Done");
	step.onSubmit = ^(TGSecurityStepViewController *sender, NSString *text) {
		if (!TGPasscodeVerifyCurrentSubmit(sender, text))
			return;
		if (done)
			done();
		__strong typeof(weakSelf) strongSelf = weakSelf;
		[strongSelf readState];
		[strongSelf.navigationController popToViewController:strongSelf animated:YES];
		[strongSelf.tableView reloadData];
	};
	[self.navigationController pushViewController:step animated:YES];
}

- (void)startSetPasscodeSimple:(BOOL)simple {
	__weak typeof(self) weakSelf = self;
	NSString *title = TGL(@"PrivacySettings.Passcode", @"Passcode Lock");
	NSString *caption = nil;
	NSString *footer = simple
		? TGL(@"Passcode.EnterExactlyFourDigitsFooter", @"Enter a passcode of exactly four digits.")
		: TGL(@"Passcode.EnterAtLeastFourCharactersFooter", @"Enter a passcode of at least four letters or digits.");
	TGSecurityStepViewController *step = [self passcodeStepWithTitle:title caption:caption footer:footer simple:simple];
	step.onSubmit = ^(TGSecurityStepViewController *sender, NSString *text) {
		if (simple && (text.length != 4 || ![weakSelf passcodeIsAllDigits:text])) {
			[sender refuseWithMessage:TGL(@"Passcode.ASimplePasscodeIsExactlyFourDigits", @"A simple passcode is exactly four digits.")];
			return;
		}
		if (!simple && text.length < 4) {
			[sender refuseWithMessage:TGL(@"Passcode.PleaseEnterAtLeastFourCharacters", @"Please enter at least four characters.")];
			return;
		}
		[weakSelf askPasscodeAgain:text simple:simple];
	};
	[self.navigationController pushViewController:step animated:YES];
}

- (void)askPasscodeAgain:(NSString *)passcode simple:(BOOL)simple {
	__weak typeof(self) weakSelf = self;
	NSString *title = TGL(@"EnterPasscode.RepeatNewPasscode", @"Re-enter your new passcode");
	NSString *caption = nil;
	NSString *footer = nil;
	TGSecurityStepViewController *step = [self passcodeStepWithTitle:title caption:caption footer:footer simple:simple];
	step.actionTitle = TGL(@"Common.Done", @"Done");
	step.onSubmit = ^(TGSecurityStepViewController *sender, NSString *text) {
		if (![text isEqualToString:passcode]) {
			[sender refuseWithMessage:TGL(@"PasscodeSettings.DoNotMatch", @"Passcodes don't match. Please try again.")];
			return;
		}
		if (![[TGPasscodeLock shared] setPasscode:passcode simple:simple]) {
			[sender refuseWithMessage:TGL(@"Passcode.TheKeychainWouldNotKeepThePasscode", @"The keychain would not keep the passcode, so it has not been set.")];
			return;
		}
		__strong typeof(weakSelf) strongSelf = weakSelf;
		[strongSelf readState];
		[strongSelf.navigationController popToViewController:strongSelf animated:YES];
		[strongSelf.tableView reloadData];
	};
	[self.navigationController pushViewController:step animated:YES];
}

- (void)showAutoLockPicker {
	NSInteger current = [[TGPasscodeLock shared] autoLockSeconds];
	NSMutableArray *titles = [NSMutableArray array];
	for (NSNumber *option in [self autoLockOptions]) {
		NSString *title = [self autoLockTitleForSeconds:[option integerValue]];
		if ([option integerValue] == current)
			title = [title stringByAppendingString:@" ✓"];
		[titles addObject:title];
	}
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:TGL(@"PasscodeSettings.AutoLock", @"Auto-Lock")
					  delegate:self
				   otherTitles:titles
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 90;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.navigationController.view.bounds), CGRectGetMidY(self.navigationController.view.bounds), 1, 1)
					 inView:self.navigationController.view];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
	if (sheet.tag != 90 || index == sheet.cancelButtonIndex)
		return;
	NSArray *options = [self autoLockOptions];
	if (index < 0 || index >= (NSInteger)options.count)
		return;
	[[TGPasscodeLock shared] setAutoLockSeconds:
			[[options objectAtIndex:index] integerValue]];
	[self.tableView reloadData];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section != 1 || indexPath.row == 1)
		return;
	if (indexPath.row == 0) {
		[self showAutoLockPicker];
		return;
	}
	__weak typeof(self) weakSelf = self;
	BOOL simple = self.simple;
	[self startVerifyThenChange:^{
		[weakSelf startSetPasscodeSimple:simple];
	}];
}

- (void)startVerifyThenChange:(dispatch_block_t)next {
	__weak typeof(self) weakSelf = self;
	NSString *title = TGL(@"PrivacySettings.Passcode", @"Passcode Lock");
	NSString *caption = TGL(@"EnterPasscode.EnterCurrentPasscode", @"Enter your current passcode");
	NSString *footer = TGL(@"Passcode.EnterCurrentPasscodeFooter", @"Enter the passcode you are using now.");
	TGSecurityStepViewController *step = [self passcodeStepWithTitle:title caption:caption footer:footer simple:self.simple];
	step.onSubmit = ^(TGSecurityStepViewController *sender, NSString *text) {
		if (!TGPasscodeVerifyCurrentSubmit(sender, text))
			return;
		__strong typeof(weakSelf) strongSelf = weakSelf;
		[strongSelf.navigationController popToViewController:strongSelf animated:NO];
		if (next)
			next();
	};
	[self.navigationController pushViewController:step animated:YES];
}

@end

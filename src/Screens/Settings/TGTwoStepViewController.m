#import "TGPasswordCheckOutcome.h"
#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGPrivacyViewController.h"
#import "TGDateUtils.h"
#import "TGPrivacyViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGClient+Privacy.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGSessionsViewController.h"
#import "TGPasscodeLock.h"
#import "TGSecurityStepViewController.h"
#import "TGRecoveryEmailCodeConfirmation.h"

static const NSInteger kDisablePasswordAlertTag = 78;
static const NSInteger kStartPasswordResetAlertTag = 79;

#pragma mark - two-step verification

@interface TGTwoStepViewController () <UIAlertViewDelegate>
@property (nonatomic, strong) NSDictionary *state;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, strong, getter=pendingPassword) NSString *newPassword;
@property (nonatomic, strong) NSString *pendingHint;
@property (nonatomic, strong) NSString *pendingOldPassword;
@property (nonatomic, assign) BOOL resettingPassword;
@end

@implementation TGTwoStepViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"PrivacySettings.TwoStepAuth", @"Two-Step Verification");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.rowHeight = 44;
	[self reload];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	[self reload];
}

- (void)reload {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] passwordStateWithCompletion:^(NSDictionary *state) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.loaded = YES;
		if ([state isKindOfClass:[NSDictionary class]])
			strongSelf.state = state;
		[strongSelf.tableView reloadData];
	}];
}

- (BOOL)hasPassword {
	return [self.state[@"hasPassword"] boolValue];
}

- (NSString *)hint {
	id hint = self.state[@"hint"];
	return [hint isKindOfClass:[NSString class]] ? hint : @"";
}

- (NSString *)pendingEmailPattern {
	id pattern = self.state[@"recoveryEmailPattern"];
	if ([pattern isKindOfClass:[NSString class]] && [pattern length])
		return pattern;
	return nil;
}

- (BOOL)hasRecoveryEmail {
	return [self.state[@"hasRecoveryEmail"] boolValue];
}

- (NSInteger)pendingResetDate {
	id date = self.state[@"pendingResetDate"];
	return [date isKindOfClass:[NSNumber class]] ? [date integerValue] : 0;
}

- (BOOL)resetPasswordReady {
	NSInteger pending = [self pendingResetDate];
	return pending > 0 && pending <= (NSInteger)[[NSDate date] timeIntervalSince1970];
}

- (BOOL)showsResetRow {
	if (![self hasPassword])
		return NO;
	return [self pendingResetDate] > 0 || ![self hasRecoveryEmail];
}

- (NSString *)describeDate:(NSInteger)date {
	return [TGDateUtils stringForFullDateAndTime:(int)date];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if (!self.loaded)
		return 1;
	return [self hasPassword] ? 3 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (!self.loaded)
		return 0;
	if (![self hasPassword])
		return 1;
	if (section == 0)
		return [self hint].length ? 2 : 1;
	if (section == 1)
		return 2;
	return [self showsResetRow] ? 2 : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (!self.loaded)
		return TGL(@"TwoStepAuth.FooterLoading", @"Loading...");
	if (![self hasPassword])
		return TGL(@"TwoStepAuth.NoPasswordFooter", @"You can set a password that will be required when you log in on a new device, on top of the code you get by text message."
			   "on a new device, on top of the code you get by text message.");
	if (section == 0) {
		NSString *pending = [self pendingEmailPattern];
		if (pending)
			return [NSString stringWithFormat:
					TGL(@"TwoStepAuth.PendingEmailCodeFooterFormat", @"Please check your e-mail at %@ and enter the code we sent you."),
				pending];
		if (![self hasRecoveryEmail])
			return TGL(@"TwoStepAuth.NoRecoveryEmailFooter", @"Without a recovery e-mail address there is no way back into this account if you forget the password."
				   "this account if you forget the password.");
		return nil;
	}
	if (section == 2) {
		NSInteger pending = [self pendingResetDate];
		if (pending > 0)
			return [NSString stringWithFormat:
					TGL(@"TwoStepAuth.PendingResetFooterFormat", @"The password will be removed on %@ unless you call the reset off."),
				[self describeDate:pending]];
		if ([self showsResetRow])
			return TGL(@"TwoStepAuth.RemovePasswordWithRecoveryFooter", @"Turning the password off leaves only the text message code protecting this account. Without a recovery e-mail address you can ask for the password to be reset after a waiting period."
				   "protecting this account. Without a recovery e-mail address you "
				   "can ask for the password to be reset after a waiting period.");
		return TGL(@"TwoStepAuth.RemovePasswordFooter", @"Turning the password off leaves only the text message code protecting this account."
			   "protecting this account.");
	}
	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	TGTheme *theme = [TGTheme shared];
	CGFloat measured = [theme groupedCommentHeightForText:caption width:tableView.bounds.size.width];
	return TGGroupedFooterHeight(caption, measured);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	TGTheme *theme = [TGTheme shared];
	return [theme groupedCommentViewWithText:caption width:tableView.bounds.size.width];
}

- (UITableViewCell *)plainCellFor:(UITableView *)tableView identifier:(NSString *)identifier {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:identifier];
	[[TGTheme shared] styleCell:cell];
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.accessoryView = nil;
	cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.textLabel.highlightedTextColor = [UIColor whiteColor];
	cell.detailTextLabel.text = @"";
	cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	return cell;
}

- (void)configureSetPasswordCell:(UITableViewCell *)cell {
	cell.textLabel.text = TGL(@"TwoStepAuth.SetPassword", @"Set Additional Password");
	cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
	cell.textLabel.textColor = [[TGTheme shared] groupedActionColour];
	cell.textLabel.highlightedTextColor = [UIColor whiteColor];
}

- (void)configureStatusCell:(UITableViewCell *)cell atRow:(NSInteger)row {
	if (row == 0) {
		cell.textLabel.text = TGL(@"LoginPassword.PasswordPlaceholder", @"Password");
		cell.detailTextLabel.text = TGL(@"PrivacySettings.PasscodeOn", @"On");
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		return;
	}
	cell.textLabel.text = TGL(@"TwoStepAuth.HintPlaceholder", @"Hint");
	cell.detailTextLabel.text = [self hint];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
}

- (void)configureActionCell:(UITableViewCell *)cell atRow:(NSInteger)row {
	if (row == 0) {
		cell.textLabel.text = TGL(@"TwoStepAuth.ChangePassword", @"Change Password");
	} else {
		NSString *pending = [self pendingEmailPattern];
		if (pending)
			cell.textLabel.text = TGL(@"TwoStepAuth.EnterEmailCode", @"Enter E-Mail Code");
		else
			cell.textLabel.text = [self hasRecoveryEmail]
				? TGL(@"TwoStepAuth.ChangeEmail", @"Change Recovery E-Mail")
				: TGL(@"TwoStepAuth.SetupEmail", @"Set Recovery E-Mail");
	}
	cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
	cell.textLabel.textColor = [[TGTheme shared] groupedActionColour];
	cell.textLabel.highlightedTextColor = [UIColor whiteColor];
}

- (void)configureResetCell:(UITableViewCell *)cell {
	BOOL awaitingCancellableReset = [self pendingResetDate] > 0 && ![self resetPasswordReady];
	[TGIcons actionButtonInCell:cell
						  title:awaitingCancellableReset
								  ? TGL(@"TwoStepAuth.CancelResetTitle", @"Cancel Password Reset")
								  : TGL(@"TwoStepAuth.RecoveryUnavailableResetTitle", @"Reset Password")
						   kind:awaitingCancellableReset ? TGActionButtonKindNeutral
														 : TGActionButtonKindDestructive
						 target:self
						 action:@selector(resetRowPressed)];
}

- (void)resetRowPressed {
	NSInteger pending = [self pendingResetDate];
	if (pending > 0 && ![self resetPasswordReady])
		[self confirmCancellingReset];
	else if (pending > 0)
		[self startPasswordReset];
	else
		[self confirmStartingPasswordReset];
}

- (void)configureTurnOffCell:(UITableViewCell *)cell {
	[TGIcons actionButtonInCell:cell
						  title:TGL(@"TwoStepAuth.RemovePassword", @"Turn Password Off")
						   kind:TGActionButtonKindDestructive
						 target:self
						 action:@selector(confirmDisablingPassword)];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([self hasPassword] && indexPath.section == 2)
		return TGActionRowHeight();
	return 44;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [self plainCellFor:tableView identifier:@"row"];
	if (indexPath.section != 2 || ![self hasPassword])
		[TGIcons removeActionButtonFromCell:cell];

	if (![self hasPassword]) {
		[self configureSetPasswordCell:cell];
		return cell;
	}
	if (indexPath.section == 0) {
		[self configureStatusCell:cell atRow:indexPath.row];
		return cell;
	}
	if (indexPath.section == 1) {
		[self configureActionCell:cell atRow:indexPath.row];
		return cell;
	}
	if (indexPath.row == 1) {
		[self configureResetCell:cell];
		return cell;
	}
	[self configureTurnOffCell:cell];
	return cell;
}

- (TGSecurityStepViewController *)stepWithTitle:(NSString *)title
										caption:(NSString *)caption
									placeholder:(NSString *)placeholder
										 footer:(NSString *)footer {
	TGSecurityStepViewController *step = [[TGSecurityStepViewController alloc] init];
	step.stepTitle = title;
	step.stepCaption = caption;
	step.placeholder = placeholder;
	step.footerText = footer;
	return step;
}

- (void)popToSelfAnimated:(BOOL)animated {
	[self.navigationController popToViewController:self animated:animated];
	[self reload];
}

#pragma mark - setting a password

- (void)startSetPassword {
	__weak typeof(self) weakSelf = self;
	NSString *title = TGL(@"LoginPassword.PasswordPlaceholder", @"Password");
	NSString *caption = nil;
	NSString *placeholder = TGL(@"LoginPassword.PasswordPlaceholder", @"Password");
	NSString *footer = TGL(@"TwoStepAuth.SetPasswordHelp", @"Enter a password you will be asked for whenever you log in on a new device.");
	TGSecurityStepViewController *step = [self stepWithTitle:title caption:caption placeholder:placeholder footer:footer];
	step.onSubmit = ^(TGSecurityStepViewController *sender, NSString *text) {
		if (!text.length) {
			[sender refuseWithMessage:TGL(@"TwoStepAuth.PleaseEnterAPassword", @"Please enter a password.")];
			return;
		}
		[weakSelf askReenterOfPassword:text oldPassword:nil];
	};
	[self.navigationController pushViewController:step animated:YES];
}

- (void)askReenterOfPassword:(NSString *)password oldPassword:(NSString *)oldPassword {
	__weak typeof(self) weakSelf = self;
	NSString *title = TGL(@"TwoFactorSetup.Password.PlaceholderConfirmPassword", @"Re-enter Password");
	NSString *caption = nil;
	NSString *placeholder = TGL(@"LoginPassword.PasswordPlaceholder", @"Password");
	NSString *footer = TGL(@"TwoStepAuth.SetupPasswordConfirmPassword", @"Please re-enter your password:");
	TGSecurityStepViewController *step = [self stepWithTitle:title caption:caption placeholder:placeholder footer:footer];
	step.onSubmit = ^(TGSecurityStepViewController *sender, NSString *text) {
		if (![text isEqualToString:password]) {
			[sender refuseWithMessage:TGL(@"TwoStepAuth.SetupPasswordConfirmFailed", @"Passwords don't match. Please try again.")];
			return;
		}
		[weakSelf askHintForPassword:password oldPassword:oldPassword];
	};
	[self.navigationController pushViewController:step animated:YES];
}

- (void)askHintForPassword:(NSString *)password oldPassword:(NSString *)oldPassword {
	__weak typeof(self) weakSelf = self;
	NSString *title = TGL(@"TwoStepAuth.HintPlaceholder", @"Hint");
	NSString *caption = nil;
	NSString *placeholder = TGL(@"TwoStepAuth.HintPlaceholder", @"Hint");
	NSString *footer = TGL(@"TwoStepAuth.AddHintDescription", @"A short reminder shown when the password is asked for. Anyone who sees your log-in screen sees the hint, so keep it vague.");
	TGSecurityStepViewController *step = [self stepWithTitle:title caption:caption placeholder:placeholder footer:footer];
	step.secure = NO;
	step.skipTitle = TGL(@"TwoStepAuth.SkipThisStep", @"Skip This Step");
	BOOL isChangingPassword = oldPassword.length > 0;
	step.onSubmit = ^(TGSecurityStepViewController *sender, NSString *text) {
		if ([text isEqualToString:password]) {
			[sender refuseWithMessage:TGL(@"TwoStepAuth.TheHintCannotBeThePasswordItself", @"The hint cannot be the password itself.")];
			return;
		}
		if (isChangingPassword) {
			[weakSelf commitPassword:password hint:text email:nil
						 oldPassword:oldPassword
							fromStep:sender];
			return;
		}
		[weakSelf askEmailForPassword:password hint:text oldPassword:oldPassword];
	};
	__weak TGSecurityStepViewController *weakStep = step;
	step.onSkip = ^{
		if (isChangingPassword) {
			[weakSelf commitPassword:password hint:nil email:nil
						 oldPassword:oldPassword
							fromStep:weakStep];
			return;
		}
		[weakSelf askEmailForPassword:password hint:nil oldPassword:oldPassword];
	};
	[self.navigationController pushViewController:step animated:YES];
}

- (void)askEmailForPassword:(NSString *)password hint:(NSString *)hint
				oldPassword:(NSString *)oldPassword {
	__weak typeof(self) weakSelf = self;
	NSString *title = TGL(@"TwoStepAuth.EmailTitle", @"Recovery");
	NSString *caption = nil;
	NSString *placeholder = TGL(@"TwoStepAuth.Email", @"E-Mail");
	NSString *footer = TGL(@"TwoStepAuth.EmailHelp", @"This is the only way back into the account if you forget the password. Telegram sends a code to this address to confirm it.");
	TGSecurityStepViewController *step = [self stepWithTitle:title caption:caption placeholder:placeholder footer:footer];
	step.secure = NO;
	step.email = YES;
	step.skipTitle = TGL(@"TwoStepAuth.SkipThisStep", @"Skip This Step");
	step.onSubmit = ^(TGSecurityStepViewController *sender, NSString *text) {
		if ([text rangeOfString:@"@"].location == NSNotFound || text.length < 5) {
			[sender refuseWithMessage:TGL(@"TwoStepAuth.EmailInvalid", @"Invalid e-mail address. Please try again.")];
			return;
		}
		[weakSelf commitPassword:password hint:hint email:text
					 oldPassword:oldPassword
						fromStep:sender];
	};
	step.onSkip = ^{
		[weakSelf confirmSkippingRecoveryForPassword:password hint:hint
										 oldPassword:oldPassword];
	};
	[self.navigationController pushViewController:step animated:YES];
}

- (void)confirmSkippingRecoveryForPassword:(NSString *)password hint:(NSString *)hint
							   oldPassword:(NSString *)oldPassword {
	self.newPassword = password;
	self.pendingHint = hint;
	self.pendingOldPassword = oldPassword;
	NSString *message = TGL(@"TwoStepAuth.EmailSkipAlert", @"Without a recovery e-mail address you will lose the account if you forget the password. Continue anyway?");
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
													message:message
												   delegate:self
										  cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
										  otherButtonTitles:TGL(@"Login.CancelPhoneVerificationContinue", @"Continue"), nil];
	alert.tag = (NSInteger)(hint.length ? 1 : 2);
	[alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex == alertView.cancelButtonIndex) {
		if (alertView.tag != 77 && alertView.tag != kDisablePasswordAlertTag && alertView.tag != kStartPasswordResetAlertTag) {
			self.newPassword = nil;
			self.pendingHint = nil;
			self.pendingOldPassword = nil;
		}
		return;
	}
	if (alertView.tag == 77) {
		[self cancelPasswordReset];
		return;
	}
	if (alertView.tag == kDisablePasswordAlertTag) {
		[self startDisablePassword];
		return;
	}
	if (alertView.tag == kStartPasswordResetAlertTag) {
		[self startPasswordReset];
		return;
	}
	[self commitPassword:self.newPassword hint:self.pendingHint email:nil
			 oldPassword:self.pendingOldPassword
				fromStep:nil];
	self.newPassword = nil;
	self.pendingHint = nil;
	self.pendingOldPassword = nil;
}

- (void)commitPassword:(NSString *)password hint:(NSString *)hint email:(NSString *)email
		   oldPassword:(NSString *)oldPassword
			  fromStep:(TGSecurityStepViewController *)step {
	[step setBusy:YES];
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client setPasswordWithOldPassword:oldPassword
						   newPassword:password
								  hint:hint
						 recoveryEmail:email
							completion:^(NSDictionary *state) {
								__strong typeof(weakSelf) strongSelf = weakSelf;
								if (!strongSelf)
									return;
								if (![state isKindOfClass:[NSDictionary class]]) {
									if (step)
										[step refuseWithMessage:oldPassword.length
												? TGL(@"TwoStepAuth.ThatPasswordIsWrong", @"That password is wrong.")
												: TGL(@"TwoStepAuth.PasswordCouldNotBeSetMessage", @"The password could not be set.")];
									else
										TGPrivacyComplain(TGL(@"TwoStepAuth.PasswordCouldNotBeSetMessage", @"The password could not be set."));
									return;
								}
								strongSelf.state = state;
								strongSelf.loaded = YES;
								id pattern = state[@"recoveryEmailPattern"];
								if ([pattern isKindOfClass:[NSString class]] && [pattern length]) {
									[strongSelf.tableView reloadData];
									[step setBusy:NO];
									[strongSelf askRecoveryCodeForPattern:pattern replacingStep:step];
									return;
								}
								[strongSelf popToSelfAnimated:YES];
							}];
}

- (void)askRecoveryCodeForPattern:(NSString *)pattern
					replacingStep:(TGSecurityStepViewController *)step {
	__weak typeof(self) weakSelf = self;
	NSString *title = TGL(@"Login.Code", @"Code");
	NSString *caption = [NSString stringWithFormat:
			TGL(@"TwoStepAuth.ConfirmEmailDescription", @"Please enter the code we've just emailed at %1$@."),
		pattern];
	NSString *placeholder = TGL(@"Login.Code", @"Code");
	NSString *footer = [NSString stringWithFormat:
			TGL(@"TwoStepAuth.SwitchOnCodeFooterFormat", @"We have sent a code to %@. Enter it here to switch the password on."
			"password on."),
		pattern];
	TGSecurityStepViewController *code = [self stepWithTitle:title caption:caption placeholder:placeholder footer:footer];
	code.secure = NO;
	code.numeric = YES;
	code.actionTitle = TGL(@"Common.Done", @"Done");
	code.skipTitle = TGL(@"TwoStepAuth.ConfirmEmailResendCode", @"Resend Code");
	code.onSubmit = ^(TGSecurityStepViewController *sender, NSString *text) {
		if (!text.length) {
			[sender refuseWithMessage:TGL(@"PrivacySettings.PleaseEnterTheCode", @"Please enter the code.")];
			return;
		}
		[sender setBusy:YES];
		[[TGClient shared] checkRecoveryEmailCode:text completion:^(NSDictionary *state) {
			__strong typeof(weakSelf) strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!TGRecoveryEmailCodeWasConfirmed(state)) {
				[sender refuseWithMessage:TGL(@"TwoStepAuth.ThatCodeIsWrongOrHasExpired", @"That code is wrong or has expired.")];
				return;
			}
			strongSelf.state = state;
			[strongSelf popToSelfAnimated:YES];
		}];
	};
	__weak TGSecurityStepViewController *weakCode = code;
	code.onSkip = ^{
		__strong TGSecurityStepViewController *strongCode = weakCode;
		if (!strongCode)
			return;
		[strongCode setBusy:YES];
		[[TGClient shared] resendRecoveryEmailCodeWithCompletion:^(NSDictionary *state) {
			__strong TGSecurityStepViewController *innerCode = weakCode;
			if (innerCode)
				[innerCode setBusy:NO];
			TGPrivacyComplain(state ? TGL(@"TwoStepAuth.CodeSentAgainMessage", @"The code has been sent again.")
									: TGL(@"TwoStepAuth.CodeNotSentAgainMessage", @"The code could not be sent again."));
		}];
	};
	[self.navigationController pushViewController:code animated:YES];
}

#pragma mark - changing, disabling, recovery e-mail

- (void)startChangePassword {
	__weak typeof(self) weakSelf = self;
	NSString *title = TGL(@"LoginPassword.PasswordPlaceholder", @"Password");
	NSString *caption = TGL(@"TwoStepAuth.EnterPasswordPassword", @"Your current password");
	NSString *placeholder = TGL(@"LoginPassword.PasswordPlaceholder", @"Password");
	NSString *footer = [self hint].length
		? [NSString stringWithFormat:TGL(@"TwoStepAuth.HintFooterFormat", @"Hint: %@"), [self hint]]
		: TGL(@"TwoStepAuth.EnterCurrentPasswordFooter", @"Enter the password you are using now.");
	TGSecurityStepViewController *step = [self stepWithTitle:title caption:caption placeholder:placeholder footer:footer];
	step.skipTitle = TGL(@"TwoStepAuth.EnterPasswordForgot", @"Forgot Password?");
	step.onSubmit = ^(TGSecurityStepViewController *sender, NSString *text) {
		if (!text.length) {
			[sender refuseWithMessage:TGL(@"TwoStepAuth.PleaseEnterYourPassword", @"Please enter your password.")];
			return;
		}
		[sender setBusy:YES];
		[[TGClient shared] recoveryEmailWithPassword:text completion:^(NSString *email, NSString *errorMessage) {
			if (!email) {
				[sender refuseWithMessage:TGPasswordCheckOutcomeForError(errorMessage, NO) == TGPasswordCheckOutcomeWrongPassword
						? TGL(@"TwoStepAuth.ThatPasswordIsWrong", @"That password is wrong.")
						: TGL(@"TwoStepAuth.PasswordNotChecked", @"The password could not be checked. Try again in a moment.")];
				return;
			}
			[sender setBusy:NO];
			[weakSelf askNewPasswordWithOldPassword:text];
		}];
	};
	step.onSkip = ^{
		[weakSelf startPasswordRecovery];
	};
	[self.navigationController pushViewController:step animated:YES];
}

- (void)askNewPasswordWithOldPassword:(NSString *)oldPassword {
	__weak typeof(self) weakSelf = self;
	NSString *title = TGL(@"TwoFactorSetup.PasswordRecovery.PlaceholderPassword", @"New password");
	NSString *caption = nil;
	NSString *placeholder = TGL(@"LoginPassword.PasswordPlaceholder", @"Password");
	NSString *footer = TGL(@"TwoStepAuth.SetupPasswordEnterPasswordChange", @"Enter the new password.");
	TGSecurityStepViewController *step = [self stepWithTitle:title caption:caption placeholder:placeholder footer:footer];
	step.onSubmit = ^(TGSecurityStepViewController *sender, NSString *text) {
		if (!text.length) {
			[sender refuseWithMessage:TGL(@"TwoStepAuth.PleaseEnterAPassword", @"Please enter a password.")];
			return;
		}
		[weakSelf askReenterOfPassword:text oldPassword:oldPassword];
	};
	[self.navigationController pushViewController:step animated:YES];
}

- (void)startDisablePassword {
	__weak typeof(self) weakSelf = self;
	NSString *title = TGL(@"LoginPassword.PasswordPlaceholder", @"Password");
	NSString *caption = TGL(@"TwoStepAuth.EnterPasswordPassword", @"Your current password");
	NSString *placeholder = TGL(@"LoginPassword.PasswordPlaceholder", @"Password");
	NSString *footer = [self hint].length
		? [NSString stringWithFormat:TGL(@"TwoStepAuth.HintFooterFormat", @"Hint: %@"), [self hint]]
		: TGL(@"TwoStepAuth.ReEnterPasswordDescription", @"Enter your password to change the recovery e-mail address.");
	TGSecurityStepViewController *step = [self stepWithTitle:title caption:caption placeholder:placeholder footer:footer];
	step.actionTitle = TGL(@"Common.Done", @"Done");
	step.skipTitle = TGL(@"TwoStepAuth.EnterPasswordForgot", @"Forgot Password?");
	step.onSkip = ^{
		[weakSelf startPasswordRecovery];
	};
	step.onSubmit = ^(TGSecurityStepViewController *sender, NSString *text) {
		if (!text.length) {
			[sender refuseWithMessage:TGL(@"TwoStepAuth.PleaseEnterYourPassword", @"Please enter your password.")];
			return;
		}
		[sender setBusy:YES];
		[[TGClient shared] disablePasswordWithOldPassword:text completion:^(BOOL ok) {
			__strong typeof(weakSelf) strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!ok) {
				[sender refuseWithMessage:TGL(@"TwoStepAuth.ThatPasswordIsWrong", @"That password is wrong.")];
				return;
			}
			[strongSelf popToSelfAnimated:YES];
		}];
	};
	[self.navigationController pushViewController:step animated:YES];
}

- (void)startSetRecoveryEmail {
	__weak typeof(self) weakSelf = self;
	NSString *title = TGL(@"LoginPassword.PasswordPlaceholder", @"Password");
	NSString *caption = TGL(@"TwoStepAuth.EnterPasswordPassword", @"Your current password");
	NSString *placeholder = TGL(@"LoginPassword.PasswordPlaceholder", @"Password");
	NSString *footer = TGL(@"TwoStepAuth.ReEnterPasswordDescription", @"Enter your password to change the recovery e-mail address.");
	TGSecurityStepViewController *step = [self stepWithTitle:title caption:caption placeholder:placeholder footer:footer];
	step.onSubmit = ^(TGSecurityStepViewController *sender, NSString *text) {
		if (!text.length) {
			[sender refuseWithMessage:TGL(@"TwoStepAuth.PleaseEnterYourPassword", @"Please enter your password.")];
			return;
		}
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[sender setBusy:YES];
		[[TGClient shared] recoveryEmailWithPassword:text completion:^(NSString *email, NSString *errorMessage) {
			__strong typeof(weakSelf) innerSelf = weakSelf;
			if (!innerSelf)
				return;
			if (!email) {
				[sender refuseWithMessage:TGPasswordCheckOutcomeForError(errorMessage, NO) == TGPasswordCheckOutcomeWrongPassword
						? TGL(@"TwoStepAuth.ThatPasswordIsWrong", @"That password is wrong.")
						: TGL(@"TwoStepAuth.PasswordNotChecked", @"The password could not be checked. Try again in a moment.")];
				return;
			}
			[sender setBusy:NO];
			[innerSelf askRecoveryEmailWithPassword:text
										current:email.length ? email : nil];
		}];
	};
	[self.navigationController pushViewController:step animated:YES];
}

- (void)askRecoveryEmailWithPassword:(NSString *)password current:(NSString *)current {
	__weak typeof(self) weakSelf = self;
	NSString *footer = current.length
		? [NSString stringWithFormat:TGL(@"TwoStepAuth.RecoveryEmailCurrentFooterFormat", @"Recovery is going to %@ at the moment. Telegram sends a code to the new address to confirm it."
									 "sends a code to the new address to confirm it."),
			  current]
		: TGL(@"TwoStepAuth.RecoveryEmailSendsCodeFooter", @"Telegram sends a code to this address to confirm it.");
	NSString *title = TGL(@"TwoStepAuth.EmailTitle", @"Recovery");
	NSString *caption = TGL(@"TwoStepAuth.EmailTitle", @"Recovery");
	NSString *placeholder = TGL(@"TwoStepAuth.Email", @"E-Mail");
	TGSecurityStepViewController *step = [self stepWithTitle:title caption:caption placeholder:placeholder footer:footer];
	step.secure = NO;
	step.email = YES;
	step.onSubmit = ^(TGSecurityStepViewController *sender, NSString *text) {
		if ([text rangeOfString:@"@"].location == NSNotFound || text.length < 5) {
			[sender refuseWithMessage:TGL(@"TwoStepAuth.EmailInvalid", @"Invalid e-mail address. Please try again.")];
			return;
		}
		[sender setBusy:YES];
		[[TGClient shared] setRecoveryEmail:text password:password
								 completion:^(NSDictionary *state) {
									 __strong typeof(weakSelf) strongSelf = weakSelf;
									 if (!strongSelf)
										 return;
									 if (![state isKindOfClass:[NSDictionary class]]) {
										 [sender refuseWithMessage:TGL(@"TwoStepAuth.TheAddressCouldNotBeSaved", @"The address could not be saved.")];
										 return;
									 }
									 strongSelf.state = state;
									 id pattern = state[@"recoveryEmailPattern"];
									 if ([pattern isKindOfClass:[NSString class]] && [pattern length]) {
										 [strongSelf.tableView reloadData];
										 [sender setBusy:NO];
										 [strongSelf askRecoveryCodeForPattern:pattern replacingStep:sender];
										 return;
									 }
									 [strongSelf popToSelfAnimated:YES];
								 }];
	};
	[self.navigationController pushViewController:step animated:YES];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (!self.loaded)
		return;

	if (![self hasPassword]) {
		[self startSetPassword];
		return;
	}
	if (indexPath.section == 1) {
		if (indexPath.row == 0) {
			[self startChangePassword];
			return;
		}
		NSString *pending = [self pendingEmailPattern];
		if (pending)
			[self askRecoveryCodeForPattern:pending replacingStep:nil];
		else
			[self startSetRecoveryEmail];
		return;
	}
}

#pragma mark - forgotten password

- (void)startPasswordRecovery {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] requestPasswordRecoveryWithCompletion:
			^(NSString *emailPattern, NSInteger codeLength) {
				__strong typeof(weakSelf) strongSelf = weakSelf;
				if (!strongSelf)
					return;
				if (![emailPattern isKindOfClass:[NSString class]] || !emailPattern.length) {
					TGPrivacyComplain(TGL(@"TwoStepAuth.RecoveryCodeCouldNotBeSentMessage", @"No code could be sent. Without a recovery e-mail address the password can only be reset after a waiting period."
									  "the password can only be reset after a waiting period."));
					return;
				}
				[strongSelf askRecoveryCodeSentTo:emailPattern length:codeLength];
			}];
}

- (void)askRecoveryCodeSentTo:(NSString *)pattern length:(NSInteger)codeLength {
	__weak typeof(self) weakSelf = self;
	NSString *footer = [NSString stringWithFormat:TGL(@"Login.EnterCodeEmailText", @"Please enter the code we have sent to your email %@."), pattern];
	NSString *title = TGL(@"Login.Code", @"Code");
	NSString *caption = TGL(@"TwoStepAuth.RecoveryCode", @"Recovery code");
	NSString *placeholder = TGL(@"Login.Code", @"Code");
	TGSecurityStepViewController *step = [self stepWithTitle:title caption:caption placeholder:placeholder footer:footer];
	step.secure = NO;
	step.numeric = YES;
	step.onSubmit = ^(TGSecurityStepViewController *sender, NSString *text) {
		if (!text.length) {
			[sender refuseWithMessage:TGL(@"PrivacySettings.PleaseEnterTheCode", @"Please enter the code.")];
			return;
		}
		[sender setBusy:YES];
		[[TGClient shared] checkRecoveryCode:text completion:^(BOOL ok) {
			[sender setBusy:NO];
			if (!ok) {
				[sender refuseWithMessage:TGL(@"TwoStepAuth.ThatCodeIsWrongOrHasExpired", @"That code is wrong or has expired.")];
				return;
			}
			[weakSelf askRecoveredPasswordForCode:text];
		}];
	};
	[self.navigationController pushViewController:step animated:YES];
}

- (void)askRecoveredPasswordForCode:(NSString *)code {
	__weak typeof(self) weakSelf = self;
	NSString *title = TGL(@"TwoFactorSetup.PasswordRecovery.PlaceholderPassword", @"New password");
	NSString *caption = nil;
	NSString *placeholder = TGL(@"LoginPassword.PasswordPlaceholder", @"Password");
	NSString *footer = TGL(@"TwoStepAuth.SetupPasswordEnterPasswordNew", @"Enter the password you want from now on.");
	TGSecurityStepViewController *step = [self stepWithTitle:title caption:caption placeholder:placeholder footer:footer];
	step.onSubmit = ^(TGSecurityStepViewController *sender, NSString *text) {
		if (!text.length) {
			[sender refuseWithMessage:TGL(@"TwoStepAuth.PleaseEnterAPassword", @"Please enter a password.")];
			return;
		}
		[weakSelf askRecoveredPasswordAgain:text code:code];
	};
	[self.navigationController pushViewController:step animated:YES];
}

- (void)askRecoveredPasswordAgain:(NSString *)password code:(NSString *)code {
	__weak typeof(self) weakSelf = self;
	NSString *title = TGL(@"TwoFactorSetup.PasswordRecovery.PlaceholderConfirmPassword", @"Re-enter New Password");
	NSString *caption = nil;
	NSString *placeholder = TGL(@"LoginPassword.PasswordPlaceholder", @"Password");
	NSString *footer = nil;
	TGSecurityStepViewController *step = [self stepWithTitle:title caption:caption placeholder:placeholder footer:footer];
	step.onSubmit = ^(TGSecurityStepViewController *sender, NSString *text) {
		if (![text isEqualToString:password]) {
			[sender refuseWithMessage:TGL(@"TwoStepAuth.SetupPasswordConfirmFailed", @"Passwords don't match. Please try again.")];
			return;
		}
		[weakSelf askRecoveredHintForPassword:password code:code];
	};
	[self.navigationController pushViewController:step animated:YES];
}

- (void)askRecoveredHintForPassword:(NSString *)password code:(NSString *)code {
	__weak typeof(self) weakSelf = self;
	NSString *title = TGL(@"TwoStepAuth.HintPlaceholder", @"Hint");
	NSString *caption = nil;
	NSString *placeholder = TGL(@"TwoStepAuth.HintPlaceholder", @"Hint");
	NSString *footer = TGL(@"TwoStepAuth.AddHintDescription", @"A short reminder shown when the password is asked for. Anyone who sees your log-in screen sees the hint, so keep it vague.");
	TGSecurityStepViewController *step = [self stepWithTitle:title caption:caption placeholder:placeholder footer:footer];
	step.secure = NO;
	step.actionTitle = TGL(@"Common.Done", @"Done");
	step.skipTitle = TGL(@"TwoStepAuth.SkipThisStep", @"Skip This Step");
	step.onSubmit = ^(TGSecurityStepViewController *sender, NSString *text) {
		if ([text isEqualToString:password]) {
			[sender refuseWithMessage:TGL(@"TwoStepAuth.TheHintCannotBeThePasswordItself", @"The hint cannot be the password itself.")];
			return;
		}
		[weakSelf recoverPassword:password hint:text code:code fromStep:sender];
	};
	__weak TGSecurityStepViewController *weakStep = step;
	step.onSkip = ^{
		[weakSelf recoverPassword:password hint:nil code:code fromStep:weakStep];
	};
	[self.navigationController pushViewController:step animated:YES];
}

- (void)recoverPassword:(NSString *)password hint:(NSString *)hint code:(NSString *)code
			   fromStep:(TGSecurityStepViewController *)step {
	[step setBusy:YES];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] recoverPasswordWithCode:code newPassword:password hint:hint
									completion:^(BOOL ok) {
										__strong typeof(weakSelf) strongSelf = weakSelf;
										if (!strongSelf)
											return;
										if (!ok) {
											if (step)
												[step refuseWithMessage:TGL(@"TwoStepAuth.ThatCodeIsWrongOrHasExpired", @"That code is wrong or has expired.")];
											else
												TGPrivacyComplain(TGL(@"TwoStepAuth.ThatCodeIsWrongOrHasExpired", @"That code is wrong or has expired."));
											return;
										}
										[strongSelf popToSelfAnimated:YES];
									}];
}

- (void)startPasswordReset {
	if (self.resettingPassword)
		return;
	self.resettingPassword = YES;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] resetPasswordWithCompletion:^(NSString *result, NSInteger date) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.resettingPassword = NO;
		if ([result isEqualToString:@"ok"]) {
			TGPrivacyComplain(TGL(@"TwoStepAuth.PasswordHasBeenRemovedMessage", @"The password has been removed."));
			[strongSelf reload];
			[strongSelf startSetPassword];
			return;
		}
		if ([result isEqualToString:@"pending"]) {
			TGPrivacyComplain([NSString stringWithFormat:
					TGL(@"TwoStepAuth.PasswordWillBeRemovedOnFormat", @"The password will be removed on %@."),
				[strongSelf describeDate:date]]);
			[strongSelf reload];
			return;
		}
		if ([result isEqualToString:@"declined"]) {
			TGPrivacyComplain([NSString stringWithFormat:
					TGL(@"TwoStepAuth.ResetAskAgainOnFormat", @"A reset can be asked for again on %@."),
				[strongSelf describeDate:date]]);
			[strongSelf reload];
			return;
		}
		TGPrivacyComplain(TGL(@"TwoStepAuth.ResetCouldNotBeStartedMessage", @"The reset could not be started."));
	}];
}

- (void)confirmStartingPasswordReset {
	NSString *message = TGL(@"TwoStepAuth.RecoveryUnavailableResetText", @"Since you didn't provide a recovery email when setting up your password, your remaining options are either to remember your password or wait 7 days until your password is reset.");
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:TGL(@"TwoStepAuth.RecoveryUnavailableResetTitle", @"Reset Password")
													 message:message
													delegate:self
										   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
										   otherButtonTitles:TGL(@"TwoStepAuth.RecoveryUnavailableResetAction", @"Reset"), nil];
	alert.tag = kStartPasswordResetAlertTag;
	[alert show];
}

- (void)confirmDisablingPassword {
	NSString *message = TGL(@"TwoStepAuth.RemovePasswordConfirmText", @"Are you sure you want to turn off your password? This will remove Two-Step Verification protection from your account.");
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
													message:message
												   delegate:self
										  cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
										  otherButtonTitles:TGL(@"TwoStepAuth.RemovePasswordConfirmTurnOff", @"Turn Off"), nil];
	alert.tag = kDisablePasswordAlertTag;
	[alert show];
}

- (void)confirmCancellingReset {
	NSString *message = TGL(@"TwoStepAuth.CancelResetText", @"Call off the password reset and keep the password as it is?");
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
													message:message
												   delegate:self
										  cancelButtonTitle:TGL(@"Common.No", @"No")
										  otherButtonTitles:TGL(@"TwoStepAuth.CancelResetTitle", @"Cancel Password Reset"), nil];
	alert.tag = 77;
	[alert show];
}

- (void)cancelPasswordReset {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] cancelPasswordResetWithCompletion:^(BOOL ok) {
		if (!ok) {
			TGPrivacyComplain(TGL(@"TwoStepAuth.ResetCouldNotBeCalledOffMessage", @"The reset could not be called off."));
			return;
		}
		[weakSelf reload];
	}];
}

@end

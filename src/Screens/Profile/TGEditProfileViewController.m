#import "TGTextFieldStyle.h"
#import "TGListBackground.h"
#import "TGEditProfileViewController.h"
#import "TGLocalization.h"
#import "TGClient+Account.h"
#import "TGClient+Contacts.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGHexColour.h"

static const CGFloat kUsernameHintHeight = 18.0f;
static const NSTimeInterval kUsernameCheckDelay = 0.5;

static inline
@interface TGEditProfileViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *firstField;
@property (nonatomic, strong) UITextField *lastField;
@property (nonatomic, strong) UITextField *usernameField;
@property (nonatomic, strong) UITextField *bioField;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, copy) NSString *loadedBio;
@property (nonatomic, assign) BOOL saving;
@property (nonatomic, strong) UILabel *usernameHint;
@property (nonatomic, assign) BOOL checkingUsername;
@property (nonatomic, assign) NSInteger bioLengthMax;
@end

@implementation TGEditProfileViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"Settings.MyProfile", @"My Profile");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	self.tableView.rowHeight = 44;

	self.saveButton = [TGIcons headerButtonWithTitle:TGL(@"Conversation.LinkDialogSave", @"Save") bold:YES
											  target:self
											  action:@selector(save)];
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:self.saveButton];

	NSDictionary *me = [TGClient shared].me;
	if (![me isKindOfClass:NSDictionary.class])
		me = @{};

	self.firstField = [self fieldWithPlaceholder:TGL(@"Login.InfoFirstNamePlaceholder", @"First name") text:me[@"first_name"]];
	self.firstField.returnKeyType = UIReturnKeyNext;
	self.lastField = [self fieldWithPlaceholder:TGL(@"Login.InfoLastNamePlaceholder", @"Last name") text:me[@"last_name"]];
	self.lastField.returnKeyType = UIReturnKeyNext;
	self.usernameField = [self fieldWithPlaceholder:@"username" text:me[@"username"]];
	self.usernameField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	self.usernameField.autocorrectionType = UITextAutocorrectionTypeNo;
	self.usernameField.returnKeyType = UIReturnKeyNext;
	[self.usernameField removeTarget:self action:@selector(fieldChanged)
					forControlEvents:UIControlEventEditingChanged];
	[self.usernameField addTarget:self action:@selector(usernameFieldChanged)
				 forControlEvents:UIControlEventEditingChanged];

	self.usernameHint = [[UILabel alloc] initWithFrame:CGRectZero];
	self.usernameHint.font = [UIFont boldSystemFontOfSize:14];
	self.usernameHint.textAlignment = NSTextAlignmentCenter;
	self.usernameHint.backgroundColor = [UIColor clearColor];
	self.usernameHint.numberOfLines = 1;
	self.usernameHint.text = @"";

	self.bioField = [self fieldWithPlaceholder:TGL(@"Settings.About.PrivacyHelpEmpty", @"A few words about you") text:nil];
	self.loadedBio = @"";
	self.bioLengthMax = 70;

	[self updateSaveEnabled];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] bioForUser:[me[@"id"] longLongValue] completion:^(NSString *bio) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.loadedBio = bio;
		if (!strongSelf.bioField.isFirstResponder)
			strongSelf.bioField.text = bio;
	}];
	[[TGClient shared] bioLengthMaxWithCompletion:^(NSInteger lengthMax) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf || lengthMax <= 0)
			return;
		strongSelf.bioLengthMax = lengthMax;
	}];
}

- (void)dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (NSString *)stringFromBio:(id)bio {
	if ([bio isKindOfClass:NSString.class])
		return bio;
	if ([bio isKindOfClass:NSDictionary.class]) {
		id text = ((NSDictionary *)bio)[@"text"];
		if ([text isKindOfClass:NSString.class])
			return text;
	}
	return @"";
}

- (NSString *)trimmed:(NSString *)text {
	if (![text isKindOfClass:NSString.class])
		return @"";
	return [text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)updateSaveEnabled {
	BOOL enabled = !self.saving && [self trimmed:self.firstField.text].length > 0;
	self.saveButton.enabled = enabled;
	self.saveButton.alpha = enabled ? 1.0f : 0.5f;
}

- (void)fieldChanged {
	[self updateSaveEnabled];
}

- (void)usernameFieldChanged {
	[self updateSaveEnabled];
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(checkTypedUsername)
											   object:nil];
	NSString *typed = [self typedUsername];
	if (!typed.length || [typed isEqualToString:[self savedUsername]]) {
		self.checkingUsername = NO;
		[self showUsernameHint:nil available:NO];
		return;
	}
	NSString *problem = [self shortProblemWithUsername:typed];
	if (problem) {
		self.checkingUsername = NO;
		[self showUsernameHint:problem available:NO];
		return;
	}
	self.checkingUsername = YES;
	[self showUsernameHint:TGL(@"EditProfile.UsernameHintChecking", @"Checking...") available:NO];
	[self performSelector:@selector(checkTypedUsername) withObject:nil
			   afterDelay:kUsernameCheckDelay];
}

- (NSString *)typedUsername {
	return [[self trimmed:self.usernameField.text]
		stringByReplacingOccurrencesOfString:@"@"
								  withString:@""];
}

- (NSString *)savedUsername {
	NSDictionary *me = [TGClient shared].me;
	if (![me isKindOfClass:NSDictionary.class])
		return @"";
	return [me[@"username"] isKindOfClass:NSString.class] ? me[@"username"] : @"";
}

- (void)checkTypedUsername {
	NSString *typed = [self typedUsername];
	if (!typed.length || [self problemWithUsername:typed])
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] checkUsernameAvailable:typed completion:^(NSString *status) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (![[strongSelf typedUsername] isEqualToString:typed])
			return;
		[strongSelf applyUsernameStatus:status forUsername:typed];
	}];
}

- (void)applyUsernameStatus:(NSString *)status forUsername:(NSString *)username {
	self.checkingUsername = NO;
	if ([status isEqualToString:@"ok"]) {
		[self showUsernameHint:[NSString stringWithFormat:TGL(@"EditProfile.UsernameHintAvailableFormat", @"%@ is available."), username]
					 available:YES];
		return;
	}
	if ([status isEqualToString:@"occupied"]) {
		[self showUsernameHint:[NSString stringWithFormat:TGL(@"EditProfile.UsernameHintTakenFormat", @"%@ is already taken."), username]
					 available:NO];
		return;
	}
	if ([status isEqualToString:@"purchasable"]) {
		[self showUsernameHint:TGL(@"EditProfile.UsernameHintPurchasable", @"That username is only available for purchase.")
					 available:NO];
		return;
	}
	if ([status isEqualToString:@"too_many"]) {
		[self showUsernameHint:TGL(@"EditProfile.UsernameHintTooManyLinks", @"This account has too many public links.")
					 available:NO];
		return;
	}
	if ([status isEqualToString:@"invalid"]) {
		[self showUsernameHint:TGL(@"EditProfile.UsernameHintInvalid", @"That username is not valid.") available:NO];
		return;
	}
	if ([status isEqualToString:@"unavailable"]) {
		[self showUsernameHint:TGL(@"EditProfile.UsernameHintUnavailable", @"That username cannot be used.") available:NO];
		return;
	}
	[self showUsernameHint:TGL(@"EditProfile.UsernameHintCheckFailed", @"The username could not be checked.") available:NO];
}

- (NSString *)shortProblemWithUsername:(NSString *)username {
	if (username.length < 5)
		return TGL(@"EditProfile.UsernameShortAtLeast5", @"At least 5 characters.");
	if (username.length > 32)
		return TGL(@"EditProfile.UsernameShortAtMost32", @"At most 32 characters.");
	unichar first = [username characterAtIndex:0];
	if (!((first >= 'a' && first <= 'z') || (first >= 'A' && first <= 'Z')))
		return TGL(@"EditProfile.UsernameShortMustBeginWithLetter", @"Must begin with a letter.");
	for (NSInteger i = 0; i < username.length; i++) {
		unichar c = [username characterAtIndex:i];
		BOOL ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_';
		if (!ok)
			return TGL(@"EditProfile.UsernameShortLettersDigitsOnly", @"Letters, digits and _ only.");
	}
	return nil;
}

- (void)showUsernameHint:(NSString *)text available:(BOOL)available {
	self.usernameHint.text = text ?: @"";
	if (self.checkingUsername)
		self.usernameHint.textColor = [[TGTheme shared] secondaryTextColour];
	else if (available)
		self.usernameHint.textColor = TGColourFromHex(0x27a327);
	else
		self.usernameHint.textColor = TGColourFromHex(0xb82121);
}

- (NSString *)problemWithUsername:(NSString *)username {
	if (username.length < 5)
		return TGL(@"EditProfile.UsernameProblemTooShort", @"A username must be at least 5 characters long.");
	if (username.length > 32)
		return TGL(@"EditProfile.UsernameProblemTooLong", @"A username must be at most 32 characters long.");
	unichar first = [username characterAtIndex:0];
	if (!((first >= 'a' && first <= 'z') || (first >= 'A' && first <= 'Z')))
		return TGL(@"EditProfile.UsernameProblemMustBeginWithLetter", @"A username must begin with a letter.");
	for (NSInteger i = 0; i < username.length; i++) {
		unichar c = [username characterAtIndex:i];
		BOOL ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_';
		if (!ok)
			return TGL(@"EditProfile.UsernameProblemInvalidCharacters", @"A username may only contain letters, digits and underscores.");
	}
	return nil;
}

- (void)showMessage:(NSString *)message title:(NSString *)title {
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil
										  cancelButtonTitle:TGL(@"Common.OK", @"OK")
										  otherButtonTitles:nil];
	[alert show];
}

- (UITextField *)fieldWithPlaceholder:(NSString *)placeholder text:(NSString *)text {
	UITextField *field = [[UITextField alloc] initWithFrame:CGRectZero];
	field.placeholder = placeholder;
	field.text = [text isKindOfClass:NSString.class] ? text : @"";
	field.font = TGTextFieldFont();
	field.contentMode = UIViewContentModeLeft;
	field.backgroundColor = [UIColor clearColor];
	field.keyboardType = UIKeyboardTypeDefault;
	field.clearButtonMode = UITextFieldViewModeWhileEditing;
	field.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	field.delegate = self;
	field.returnKeyType = UIReturnKeyDone;
	field.textColor = [[TGTheme shared] primaryTextColour];
	TGStyleTextField(field);
	[field addTarget:self action:@selector(fieldChanged)
		forControlEvents:UIControlEventEditingChanged];
	return field;
}

- (void)save {
	if (self.saving)
		return;
	[self.view endEditing:YES];

	NSString *first = [self trimmed:self.firstField.text];
	NSString *last = [self trimmed:self.lastField.text];
	if (first.length == 0) {
		[self showMessage:TGL(@"EditProfile.FirstNameRequiredMessage", @"Please enter your first name.") title:TGL(@"EditProfile.NameAlertTitle", @"Name")];
		[self.firstField becomeFirstResponder];
		return;
	}

	NSString *username = [[self trimmed:self.usernameField.text]
		stringByReplacingOccurrencesOfString:@"@"
								  withString:@""];
	NSDictionary *me = [TGClient shared].me;
	if (![me isKindOfClass:NSDictionary.class])
		me = @{};
	NSString *currentFirst = [self trimmed:me[@"first_name"]];
	NSString *currentLast = [self trimmed:me[@"last_name"]];
	NSString *currentUsername = [me[@"username"] isKindOfClass:NSString.class]
		? me[@"username"]
		: @"";
	BOOL usernameChanged = ![username isEqualToString:currentUsername];

	if (usernameChanged && username.length > 0) {
		NSString *problem = [self problemWithUsername:username];
		if (problem) {
			[self showMessage:problem title:TGL(@"EditProfile.UsernameAlertTitle", @"Username")];
			[self.usernameField becomeFirstResponder];
			return;
		}
	}

	BOOL nameChanged = ![first isEqualToString:currentFirst] || ![last isEqualToString:currentLast];
	NSString *bio = [self trimmed:self.bioField.text];
	BOOL bioChanged = ![bio isEqualToString:self.loadedBio ?: @""];

	self.saving = YES;
	[self updateSaveEnabled];

	__weak typeof(self) weakSelf = self;
	__block BOOL nameOk = YES;
	__block BOOL bioOk = YES;
	__block NSInteger pending = (nameChanged ? 1 : 0) + (bioChanged ? 1 : 0);

	void (^continueSaving)(void) = ^{
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (pending > 0)
			return;
		if (!nameOk || !bioOk) {
			strongSelf.saving = NO;
			[strongSelf updateSaveEnabled];
			if (!nameOk)
				[strongSelf showMessage:TGL(@"Settings.TelegramWouldNotTakeThatName", @"Telegram would not take that name.")
								  title:TGL(@"EditProfile.NameAlertTitle", @"Name")];
			else
				[strongSelf showMessage:TGL(@"EditProfile.TelegramWouldNotTakeThatBio", @"Telegram would not take that bio.")
								  title:TGL(@"EditProfile.BioAlertTitle", @"Bio")];
			return;
		}
		if (bioChanged)
			strongSelf.loadedBio = bio;

		if (!usernameChanged) {
			strongSelf.saving = NO;
			[strongSelf updateSaveEnabled];
			[strongSelf.navigationController popViewControllerAnimated:YES];
			return;
		}

		[[TGClient shared] setUsername:username completion:^(BOOL ok) {
			typeof(self) innerSelf = weakSelf;
			if (!innerSelf)
				return;
			innerSelf.saving = NO;
			[innerSelf updateSaveEnabled];
			if (ok) {
				[innerSelf.navigationController popViewControllerAnimated:YES];
			} else {
				[innerSelf showMessage:TGL(@"EditProfile.UsernameNotAvailableMessage", @"That username is not available.")
								  title:TGL(@"EditProfile.UsernameAlertTitle", @"Username")];
				[innerSelf.usernameField becomeFirstResponder];
			}
		}];
	};

	if (nameChanged) {
		[[TGClient shared] setFirstName:first lastName:last completion:^(BOOL ok) {
			nameOk = ok;
			pending--;
			continueSaving();
		}];
	}
	if (bioChanged) {
		[[TGClient shared] setBio:bio completion:^(BOOL ok) {
			bioOk = ok;
			pending--;
			continueSaving();
		}];
	}
	if (pending == 0)
		continueSaving();
}

- (BOOL)textFieldShouldReturn:(UITextField *)field {
	if (field == self.firstField) {
		[self.lastField becomeFirstResponder];
		return NO;
	}
	if (field == self.lastField) {
		[self.usernameField becomeFirstResponder];
		return NO;
	}
	if (field == self.usernameField) {
		[self.bioField becomeFirstResponder];
		return NO;
	}
	[field resignFirstResponder];
	return NO;
}

- (BOOL)textField:(UITextField *)field
	shouldChangeCharactersInRange:(NSRange)range
				replacementString:(NSString *)string {
	NSInteger limit = 64;
	if (field == self.usernameField)
		limit = 32;
	else if (field == self.bioField)
		limit = self.bioLengthMax;

	NSString *current = field.text ?: @"";
	if (range.location > current.length)
		return NO;
	if (NSMaxRange(range) > current.length)
		return NO;
	NSInteger length = current.length - range.length + string.length;
	if (length > limit && string.length > 0)
		return NO;

	if (field == self.usernameField && string.length > 0) {
		for (NSInteger i = 0; i < string.length; i++) {
			unichar c = [string characterAtIndex:i];
			BOOL ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_';
			if (!ok)
				return NO;
		}
	}
	return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)field {
	[self updateSaveEnabled];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 3;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return 12;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	UIView *spacer = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, tableView.bounds.size.width, 12)];
	spacer.backgroundColor = [UIColor clearColor];
	return spacer;
}

- (NSString *)footerTextForSection:(NSInteger)section {
	if (section == 1)
		return TGL(@"EditProfile.UsernameFooter", @"You can choose a username on Telegram. Other people will be able to find you by this username and contact you without knowing your phone number.\n\nYou can use a-z, 0-9 and underscores. Minimum length is 5 characters."
				"find you by this username and contact you without knowing your phone "
				"number.\n\nYou can use a-z, 0-9 and underscores. Minimum length is 5 "
				"characters.");
	if (section == 2)
		return TGL(@"EditProfile.BioFooter", @"Any details such as age, occupation or city.");
	return nil;
}

- (CGFloat)footerTextHeightForSection:(NSInteger)section width:(CGFloat)width {
	NSString *text = [self footerTextForSection:section];
	if (text.length == 0)
		return 0;
	CGSize bounded = [text sizeWithFont:[UIFont systemFontOfSize:14]
					  constrainedToSize:CGSizeMake(width - 20, 400)
						  lineBreakMode:NSLineBreakByWordWrapping];
	return ceilf(bounded.height);
}

- (CGFloat)hintHeightForSection:(NSInteger)section {
	return section == 1 ? kUsernameHintHeight : 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	CGFloat height = [self footerTextHeightForSection:section
												width:tableView.bounds.size.width];
	if (height <= 0)
		return 12;
	return height + [self hintHeightForSection:section] + 14 + 12;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *text = [self footerTextForSection:section];
	if (text.length == 0)
		return nil;
	CGFloat width = tableView.bounds.size.width;
	CGFloat height = [self footerTextHeightForSection:section width:width];
	CGFloat hint = [self hintHeightForSection:section];
	UIView *container = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, width, height + hint + 14 + 12)];
	container.backgroundColor = [UIColor clearColor];

	if (hint > 0) {
		[self.usernameHint removeFromSuperview];
		self.usernameHint.frame = CGRectMake(10, 7, width - 20, hint);
		self.usernameHint.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[container addSubview:self.usernameHint];
	}

	UILabel *label = [[UILabel alloc] initWithFrame:
			CGRectMake(10, 7 + hint, width - 20, height)];
	label.text = text;
	label.font = [UIFont systemFontOfSize:14];
	label.textAlignment = NSTextAlignmentCenter;
	label.lineBreakMode = NSLineBreakByWordWrapping;
	label.numberOfLines = 0;
	label.backgroundColor = [UIColor clearColor];
	label.textColor = TGColourFromHex(0x697487);
	label.shadowColor = TGColourFromHex(0xdae0e8);
	label.shadowOffset = CGSizeMake(0, 1);
	[container addSubview:label];
	return container;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return section == 0 ? 2 : 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;

	UITextField *field = nil;
	if (indexPath.section == 0)
		field = indexPath.row == 0 ? self.firstField : self.lastField;
	else if (indexPath.section == 1)
		field = self.usernameField;
	else
		field = self.bioField;

	CGFloat contentWidth = tableView.bounds.size.width - 20;
	field.frame = CGRectMake(15, 12, contentWidth - 20, 22);
	[cell.contentView addSubview:field];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:NO];
	if (indexPath.section == 0)
		[(indexPath.row == 0 ? self.firstField : self.lastField) becomeFirstResponder];
	else if (indexPath.section == 1)
		[self.usernameField becomeFirstResponder];
	else
		[self.bioField becomeFirstResponder];
}

@end

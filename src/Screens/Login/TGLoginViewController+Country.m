#import "TGLoginViewController.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGCountryPickerViewController.h"
#import "TGPhoneFormat.h"
#import "TGLoginService.h"
#import "TGActionSheet.h"
#import "TGQRImage.h"
#import "TGAccountManager.h"
#import "TGBackspaceTextField.h"
#import "TGLoginToolbarButton.h"
#import <QuartzCore/QuartzCore.h>
#import "TGLoginViewControllerInternal.h"
#import "TGHexColour.h"

static inline NSDictionary *tgDialCodes(void) {
	static NSDictionary *codes = nil;
	if (codes == nil) {
		codes = @{@"US" : @"+1", @"CA" : @"+1", @"GB" : @"+44", @"UA" : @"+380", @"PL" : @"+48", @"DE" : @"+49", @"FR" : @"+33", @"IT" : @"+39", @"ES" : @"+34", @"NL" : @"+31", @"BE" : @"+32", @"CH" : @"+41", @"AT" : @"+43", @"SE" : @"+46", @"NO" : @"+47", @"DK" : @"+45", @"FI" : @"+358", @"PT" : @"+351", @"GR" : @"+30", @"IE" : @"+353", @"CZ" : @"+420", @"SK" : @"+421", @"HU" : @"+36", @"RO" : @"+40", @"BG" : @"+359", @"RS" : @"+381", @"HR" : @"+385", @"SI" : @"+386", @"LT" : @"+370", @"LV" : @"+371", @"EE" : @"+372", @"MD" : @"+373", @"RU" : @"+7", @"KZ" : @"+7", @"BY" : @"+375", @"GE" : @"+995", @"AM" : @"+374", @"AZ" : @"+994", @"TR" : @"+90", @"IL" : @"+972", @"AE" : @"+971", @"SA" : @"+966", @"EG" : @"+20", @"ZA" : @"+27", @"NG" : @"+234", @"KE" : @"+254", @"IN" : @"+91", @"PK" : @"+92", @"BD" : @"+880", @"CN" : @"+86", @"JP" : @"+81", @"KR" : @"+82", @"HK" : @"+852", @"SG" : @"+65", @"MY" : @"+60", @"TH" : @"+66", @"VN" : @"+84", @"ID" : @"+62", @"PH" : @"+63", @"AU" : @"+61", @"NZ" : @"+64", @"BR" : @"+55", @"AR" : @"+54", @"CL" : @"+56", @"CO" : @"+57", @"PE" : @"+51", @"MX" : @"+52", @"VE" : @"+58"};
	}
	return codes;
}

@implementation TGLoginViewController (Country)

#pragma mark - country

- (void)prefillGuessedCountry {
	if (self.didPrefillGuessedCountry || self.countryCodeEdited)
		return;
	self.didPrefillGuessedCountry = YES;

	__weak TGLoginViewController *weakSelf = self;
	[TGLoginService guessedCountryCodeWithCompletion:^(NSString *countryCode) {
		TGLoginViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		if (countryCode.length == 0) {
			strongSelf.didPrefillGuessedCountry = NO;
			return;
		}
		if (strongSelf.currentStep != TGLoginStepPhone || strongSelf.countryCodeEdited)
			return;
		if ([strongSelf digitsOnly:strongSelf.inputField.text].length > 0)
			return;

		NSString *dial = [tgDialCodes() objectForKey:[countryCode uppercaseString]];
		if (dial.length == 0)
			return;

		strongSelf.countryCodeField.text = dial;
		[strongSelf setMatchedCountryTitle:[strongSelf countryNameForId:[countryCode uppercaseString]]];
		[strongSelf updateNextEnabled];
	}];
}

- (void)phoneFieldsDidEndEditing {
	if (self.currentStep != TGLoginStepPhone)
		return;

	NSString *dialDigits = [self digitsOnly:self.countryCodeField.text];
	if (dialDigits.length == 0)
		return;

	NSString *prefix = [NSString stringWithFormat:@"+%@%@", dialDigits, [self digitsOnly:self.inputField.text]];
	if ([prefix isEqualToString:self.lastQueriedPhonePrefix])
		return;
	self.lastQueriedPhonePrefix = prefix;

	__weak TGLoginViewController *weakSelf = self;
	[TGLoginService phoneNumberInfo:prefix completion:^(NSDictionary *info) {
		TGLoginViewController *strongSelf = weakSelf;
		if (strongSelf == nil || strongSelf.currentStep != TGLoginStepPhone)
			return;
		if (![prefix isEqualToString:strongSelf.lastQueriedPhonePrefix])
			return;

		NSString *callingCode = [info objectForKey:@"callingCode"];
		if ([callingCode isKindOfClass:[NSString class]] && callingCode.length > 0 && ![callingCode isEqualToString:[strongSelf digitsOnly:strongSelf.countryCodeField.text]])
			return;

		NSString *countryName = [info objectForKey:@"countryName"];
		if ([countryName isKindOfClass:[NSString class]] && countryName.length > 0)
			[strongSelf setMatchedCountryTitle:countryName];
		else
			[strongSelf updateCountryNameForDialCode];
	}];
}

- (NSString *)currentCountryId {
	NSString *countryId = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
	return countryId != nil ? [countryId uppercaseString] : nil;
}

- (NSString *)countryNameForId:(NSString *)countryId {
	if (countryId.length == 0)
		return TGL(@"Login.SelectCountry.Title", @"Country");
	NSString *name = [[NSLocale currentLocale] displayNameForKey:NSLocaleCountryCode value:countryId];
	return name.length > 0 ? name : countryId;
}

- (NSString *)currentCountryName {
	return [self countryNameForId:[self currentCountryId]];
}

- (NSString *)defaultDialCode {
	NSString *countryId = [self currentCountryId];
	NSString *dial = countryId != nil ? [tgDialCodes() objectForKey:countryId] : nil;
	return dial != nil ? dial : @"+1";
}

- (void)setMatchedCountryTitle:(NSString *)title {
	[self.countryButton setTitleColor:TGColourFromHex(0xf0f0f0) forState:UIControlStateNormal];
	[self.countryButton setTitle:title forState:UIControlStateNormal];
}

- (void)setUnmatchedCountryTitle {
	[self.countryButton setTitleColor:tgRGBA(0xf0f0f0, 0.7f) forState:UIControlStateNormal];
	[self.countryButton setTitle:self.countryCodeField.text.length <= 1 ? TGL(@"Login.CountryCode", @"Country Code") : TGL(@"Login.InvalidCountryCode", @"Invalid Country Code")
						forState:UIControlStateNormal];
}

- (void)updateCountryNameForDialCode {
	NSString *dial = self.countryCodeField.text;
	if (dial.length < 2) {
		[self setUnmatchedCountryTitle];
		return;
	}

	NSString *currentId = [self currentCountryId];
	if (currentId != nil && [[tgDialCodes() objectForKey:currentId] isEqualToString:dial]) {
		[self setMatchedCountryTitle:[self countryNameForId:currentId]];
		return;
	}

	NSDictionary *codes = tgDialCodes();
	for (NSString *countryId in codes) {
		if ([[codes objectForKey:countryId] isEqualToString:dial]) {
			[self setMatchedCountryTitle:[self countryNameForId:countryId]];
			return;
		}
	}
	[self setUnmatchedCountryTitle];
}

- (void)countryButtonTapped {
	if (self.currentStep != TGLoginStepPhone)
		return;

	TGCountryPickerViewController *picker = [[TGCountryPickerViewController alloc] init];
	picker.title = TGL(@"Login.SelectCountry.Title", @"Country");
	__weak TGLoginViewController *weakSelf = self;
	picker.onPick = ^(NSString *name, NSString *flag, NSString *dialCode) {
		TGLoginViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		if (name.length > 0)
			[strongSelf setMatchedCountryTitle:name];
		if (dialCode.length > 0) {
			strongSelf.countryCodeField.text = dialCode;
			strongSelf.countryCodeEdited = YES;
			strongSelf.lastQueriedPhonePrefix = nil;
		}
		[strongSelf reformatPhoneField];
		[strongSelf updateNextEnabled];
		[strongSelf dismissViewControllerAnimated:YES completion:nil];
	};

	UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:picker];
	UINavigationBar *bar = navigationController.navigationBar;
	bar.barStyle = UIBarStyleBlackOpaque;
	UIImage *header = [UIImage imageNamed:@"LoginHeader.png"];
	if (header != nil && [bar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)])
		[bar setBackgroundImage:header forBarMetrics:UIBarMetricsDefault];
	if ([bar respondsToSelector:@selector(setTitleTextAttributes:)])
		bar.titleTextAttributes = @{UITextAttributeTextColor : [UIColor whiteColor],
			UITextAttributeTextShadowColor : TGColourFromHex(0x25272b),
			UITextAttributeTextShadowOffset : [NSValue valueWithUIOffset:UIOffsetMake(0, 1)]};

	UIButton *cancelButton = [self neutralLoginButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
	[self sizeLoginToolbarButton:cancelButton paddingLeft:7 paddingRight:7 minWidth:59];
	[cancelButton addTarget:self action:@selector(dismissCountryPicker) forControlEvents:UIControlEventTouchUpInside];
	picker.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cancelButton];

	[self presentViewController:navigationController animated:YES completion:nil];
}

- (void)dismissCountryPicker {
	[self dismissViewControllerAnimated:YES completion:^{
		[self.inputField becomeFirstResponder];
	}];
}

@end

#import "TGNewContactViewControllerInternal.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import <AddressBook/AddressBook.h>

@implementation TGNewContactViewController (PhoneEntries)

- (void)buildPhoneLabels {
	static NSArray *displayLabels = nil;
	static NSArray *identifiers = nil;
	if (!displayLabels) {
		NSMutableArray *display = [[NSMutableArray alloc] init];
		NSMutableArray *raw = [[NSMutableArray alloc] init];
		CFStringRef constants[] = {kABPersonPhoneMobileLabel, kABPersonPhoneIPhoneLabel,
			kABHomeLabel, kABWorkLabel, kABPersonPhoneMainLabel,
			kABPersonPhoneHomeFAXLabel, kABPersonPhoneWorkFAXLabel,
			kABPersonPhoneOtherFAXLabel, kABPersonPhonePagerLabel,
			kABOtherLabel};
		for (NSInteger i = 0; i < sizeof(constants) / sizeof(constants[0]); i++) {
			if (constants[i] == NULL)
				continue;
			NSString *identifier = (__bridge NSString *)constants[i];
			NSString *localized = (__bridge_transfer NSString *)ABAddressBookCopyLocalizedLabel(constants[i]);
			if (!localized.length || [display containsObject:localized])
				continue;
			[display addObject:localized];
			[raw addObject:identifier];
		}
		if (!display.count) {
			[display addObject:@"mobile"];
			[raw addObject:(__bridge NSString *)kABPersonPhoneMobileLabel];
		}
		displayLabels = display;
		identifiers = raw;
	}
	self.labelDisplayNames = displayLabels;
	self.labelIdentifiers = identifiers;
}

- (NSArray *)phoneLabels {
	if (!self.labelDisplayNames)
		[self buildPhoneLabels];
	return self.labelDisplayNames;
}

- (NSString *)addressBookLabelForDisplayLabel:(NSString *)display {
	if (!self.labelDisplayNames)
		[self buildPhoneLabels];
	NSInteger index = display ? [self.labelDisplayNames indexOfObject:display] : NSNotFound;
	if (index == NSNotFound)
		return display.length ? display : (__bridge NSString *)kABPersonPhoneMobileLabel;
	return [self.labelIdentifiers objectAtIndex:index];
}

- (NSString *)nextUnusedLabel {
	for (NSString *label in [self phoneLabels]) {
		BOOL used = NO;
		for (NSMutableDictionary *entry in self.phoneEntries) {
			if ([[entry objectForKey:@"label"] isEqualToString:label]) {
				used = YES;
				break;
			}
		}
		if (!used)
			return label;
	}
	return @"mobile";
}

- (NSMutableDictionary *)makePhoneEntry {
	UITextField *field = [self makeFieldWithPlaceholder:TGL(@"UserInfo.PhonePlaceholder", @"Phone") font:[UIFont boldSystemFontOfSize:15]];
	field.keyboardType = UIKeyboardTypePhonePad;
	NSMutableDictionary *entry = [[NSMutableDictionary alloc] init];
	[entry setObject:[self nextUnusedLabel] forKey:@"label"];
	[entry setObject:field forKey:@"field"];
	return entry;
}

- (NSMutableDictionary *)entryForField:(UITextField *)field {
	for (NSMutableDictionary *entry in self.phoneEntries) {
		if ([entry objectForKey:@"field"] == field)
			return entry;
	}
	return nil;
}

- (void)textChanged:(NSNotification *)note {
	id object = note.object;
	if (object == self.firstNameField || object == self.lastNameField) {
		[self updateDoneEnabled];
		return;
	}
	NSMutableDictionary *entry = [self entryForField:object];
	if (entry) {
		BOOL hasText = [self fieldHasNumber:object];
		BOOL hadText = [[entry objectForKey:@"hadText"] boolValue];
		[entry setObject:[NSNumber numberWithBool:hasText] forKey:@"hadText"];
		[self appendEmptyPhoneRowIfNeeded];
		NSInteger row = [self.phoneEntries indexOfObject:entry];
		if (row != NSNotFound) {
			id cell = [self.tableView cellForRowAtIndexPath:
					[NSIndexPath indexPathForRow:(NSInteger)row inSection:0]];
			if ([cell isKindOfClass:[TGNewContactPhoneCell class]])
				[(TGNewContactPhoneCell *)cell setShowsRemoveControl:hasText];
		}
		if (hasText != hadText) {
			[self.tableView beginUpdates];
			[self.tableView endUpdates];
		}
		[self updateDoneEnabled];
		[self schedulePhoneLookup];
	}
}

- (void)appendEmptyPhoneRowIfNeeded {
	NSMutableDictionary *last = [self.phoneEntries lastObject];
	if (![self fieldHasNumber:[last objectForKey:@"field"]])
		return;
	[self.phoneEntries addObject:[self makePhoneEntry]];
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:(NSInteger)self.phoneEntries.count - 1 inSection:0];
	[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
						  withRowAnimation:UITableViewRowAnimationFade];
	id previousCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:indexPath.row - 1 inSection:0]];
	if ([previousCell isKindOfClass:[TGNewContactPhoneCell class]]) {
		((TGNewContactPhoneCell *)previousCell).lastInGroup = NO;
		[previousCell setNeedsLayout];
	}
}

- (NSString *)trimmed:(NSString *)text {
	if (!text.length)
		return @"";
	return [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)digitsOf:(NSString *)text {
	NSMutableString *digits = [[NSMutableString alloc] init];
	for (NSInteger i = 0; i < text.length; i++) {
		unichar c = [text characterAtIndex:i];
		if (c >= '0' && c <= '9')
			[digits appendString:[NSString stringWithCharacters:&c length:1]];
	}
	return digits;
}

- (NSArray *)enteredPhones {
	NSMutableArray *result = [[NSMutableArray alloc] init];
	for (NSMutableDictionary *entry in self.phoneEntries) {
		NSString *phone = [self trimmed:((UITextField *)[entry objectForKey:@"field"]).text];
		if ([self digitsOf:phone].length) {
			NSMutableDictionary *item = [[NSMutableDictionary alloc] init];
			NSString *display = [entry objectForKey:@"label"];
			[item setObject:phone forKey:@"phone"];
			[item setObject:display forKey:@"label"];
			[item setObject:[self addressBookLabelForDisplayLabel:display] forKey:@"abLabel"];
			[result addObject:item];
		}
	}
	return result;
}

- (BOOL)isFormValid {
	if (![self trimmed:self.firstNameField.text].length)
		return NO;
	if ([self hasKnownPeer])
		return YES;
	return [self enteredPhones].count > 0;
}

- (void)updateDoneEnabled {
	BOOL enabled = !self.saving && [self isFormValid];
	self.doneButton.enabled = enabled;
	self.doneButton.alpha = enabled ? 1.0f : 0.5f;
}

- (BOOL)fieldHasNumber:(UITextField *)field {
	return [self digitsOf:(field.text ?: @"")].length > 0;
}

- (NSString *)primaryPhone {
	NSArray *phones = [self enteredPhones];
	if (phones.count)
		return [[phones objectAtIndex:0] objectForKey:@"phone"];
	return @"";
}

- (void)presentLabelPickerForRow:(NSInteger)row {
	if (row < 0 || row >= (NSInteger)self.phoneEntries.count)
		return;
	NSMutableDictionary *entry = [self.phoneEntries objectAtIndex:(NSUInteger)row];
	[self.view endEditing:YES];
	TGPhoneLabelPickerController *picker = [[TGPhoneLabelPickerController alloc] init];
	picker.labels = [self phoneLabels];
	picker.selectedLabel = [entry objectForKey:@"label"];
	__weak typeof(self) weakSelf = self;
	picker.onPick = ^(NSString *label) {
		TGNewContactViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (label.length)
			[entry setObject:label forKey:@"label"];
		[strongSelf.tableView reloadData];
		[strongSelf dismissViewControllerAnimated:YES completion:nil];
	};
	picker.onCancel = ^{
		TGNewContactViewController *strongSelf = weakSelf;
		[strongSelf dismissViewControllerAnimated:YES completion:nil];
	};
	UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:picker];
	[[TGTheme shared] styleNavigationBar:navigation.navigationBar];
	[self presentViewController:navigation animated:YES completion:nil];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
	if ([self entryForField:textField] && !textField.text.length)
		textField.text = @"+";
	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		[weakSelf pruneEmptyPhoneRowsAroundField:textField];
	});
}

- (void)pruneEmptyPhoneRowsAroundField:(UITextField *)textField {
	NSMutableDictionary *focused = [self entryForField:textField];
	if (!focused)
		return;
	NSInteger focusedIndex = [self.phoneEntries indexOfObject:focused];
	NSInteger lastIndex = self.phoneEntries.count - 1;
	NSMutableArray *removedPaths = [[NSMutableArray alloc] init];
	NSMutableArray *removedEntries = [[NSMutableArray alloc] init];
	for (NSInteger i = 0; i < self.phoneEntries.count; i++) {
		if (i == focusedIndex || i == lastIndex)
			continue;
		NSMutableDictionary *entry = [self.phoneEntries objectAtIndex:i];
		if (![self fieldHasNumber:[entry objectForKey:@"field"]]) {
			[removedPaths addObject:[NSIndexPath indexPathForRow:(NSInteger)i inSection:0]];
			[removedEntries addObject:entry];
		}
	}
	if (!removedPaths.count)
		return;
	for (NSMutableDictionary *entry in removedEntries) {
		UITextField *field = [entry objectForKey:@"field"];
		field.delegate = nil;
		[field removeFromSuperview];
		[self.phoneEntries removeObject:entry];
	}
	[self.tableView deleteRowsAtIndexPaths:removedPaths withRowAnimation:UITableViewRowAnimationFade];
	[self updateDoneEnabled];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	if (textField == self.firstNameField)
		[self.lastNameField becomeFirstResponder];
	else
		[textField resignFirstResponder];
	return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
	if (![self entryForField:textField] || !string.length)
		return YES;

	NSMutableString *accepted = [[NSMutableString alloc] initWithCapacity:string.length];
	for (NSInteger i = 0; i < string.length; i++) {
		unichar c = [string characterAtIndex:i];
		if ((c >= '0' && c <= '9') || (c == '+' && range.location == 0 && accepted.length == 0))
			[accepted appendString:[NSString stringWithCharacters:&c length:1]];
	}
	if ([accepted isEqualToString:string])
		return YES;
	if (!accepted.length)
		return NO;

	NSString *current = textField.text ? textField.text : @"";
	if (range.location + range.length > current.length)
		return NO;
	textField.text = [current stringByReplacingCharactersInRange:range withString:accepted];
	UITextPosition *start = textField.beginningOfDocument;
	NSInteger caretOffset = (NSInteger)(range.location + accepted.length);
	UITextPosition *caret = [textField positionFromPosition:start offset:caretOffset];
	if (caret)
		textField.selectedTextRange = [textField textRangeFromPosition:caret toPosition:caret];
	[[NSNotificationCenter defaultCenter] postNotificationName:UITextFieldTextDidChangeNotification object:textField];
	return NO;
}

- (BOOL)rowCarriesNumber:(NSIndexPath *)indexPath {
	if (indexPath.section != 0 || indexPath.row >= (NSInteger)self.phoneEntries.count)
		return NO;
	NSMutableDictionary *entry = [self.phoneEntries objectAtIndex:(NSUInteger)indexPath.row];
	return [self fieldHasNumber:[entry objectForKey:@"field"]];
}

@end

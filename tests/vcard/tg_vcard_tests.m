#import "tg_vcard_tests.h"
#import "../../src/Utilities/TGVCard.h"

TGTestOutcome TGVCardTestWhatACardSays(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSString *card = TGVCardForContact(@"Ada", @"Lovelace", @"+441234567", @"@ada");
	TGTestExpectTrue(&outcome, [card hasPrefix:@"BEGIN:VCARD\r\nVERSION:3.0\r\n"],
		"a card opens the way every reader expects");
	TGTestExpectTrue(&outcome, [card rangeOfString:@"N:Lovelace;Ada;;;"].location != NSNotFound,
		"the structured name puts the family name first");
	TGTestExpectTrue(&outcome, [card rangeOfString:@"FN:Ada Lovelace"].location != NSNotFound,
		"the display name reads the way a person writes it");
	TGTestExpectTrue(&outcome, [card rangeOfString:@"TEL;TYPE=CELL:+441234567"].location != NSNotFound,
		"the number is carried as a mobile number");
	TGTestExpectTrue(&outcome, [card rangeOfString:@"URL:https://t.me/ada"].location != NSNotFound,
		"the username travels as a link, with the @ dropped");
	TGTestExpectTrue(&outcome, [card hasSuffix:@"END:VCARD\r\n"],
		"and it ends where it should");

	NSString *noPhone = TGVCardForContact(@"Ada", @"", @"", @"ada");
	TGTestExpectTrue(&outcome, [noPhone rangeOfString:@"TEL"].location == NSNotFound,
		"an account that hides its number simply carries no number");

	NSString *bare = TGVCardForContact(@"", @"", @"441234567", @"");
	TGTestExpectTrue(&outcome, [bare rangeOfString:@"TEL;TYPE=CELL:+441234567"].location != NSNotFound,
		"a number without a plus still leaves as an international one");

	TGTestExpectTrue(&outcome, TGVCardForContact(@"", @"", @"", @"") == nil,
		"a contact with nothing in it produces no card at all");

	NSString *awkward = TGVCardForContact(@"A;B,C\\D", @"E\nF", @"+1", @"");
	TGTestExpectTrue(&outcome,
		[awkward rangeOfString:@"N:E\\nF;A\\;B\\,C\\\\D;;;"].location != NSNotFound,
		"semicolons, commas, backslashes and newlines are escaped, not passed through");

	return outcome;
}

TGTestOutcome TGVCardTestWhatTheFileIsCalled(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGTestExpectTrue(&outcome,
		[TGVCardFileNameForContact(@"Ada", @"Lovelace") isEqualToString:@"Ada Lovelace.vcf"],
		"the file is named after the person");
	TGTestExpectTrue(&outcome,
		[TGVCardFileNameForContact(@"Ada/Bad:Name", @"") isEqualToString:@"Ada Bad Name.vcf"],
		"characters a file system refuses never reach it");
	TGTestExpectTrue(&outcome,
		[TGVCardFileNameForContact(@"", @"") isEqualToString:@"Contact.vcf"],
		"a nameless contact still gets a usable file name");

	return outcome;
}

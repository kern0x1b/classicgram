#import "TGVCard.h"

static NSString *TGVCardTrimmed(NSString *value) {
	if (![value isKindOfClass:NSString.class])
		return @"";
	return [value stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

NSString *TGVCardEscaped(NSString *value) {
	NSString *text = TGVCardTrimmed(value);
	text = [text stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
	text = [text stringByReplacingOccurrencesOfString:@";" withString:@"\\;"];
	text = [text stringByReplacingOccurrencesOfString:@"," withString:@"\\,"];
	text = [text stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\\n"];
	text = [text stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
	text = [text stringByReplacingOccurrencesOfString:@"\r" withString:@"\\n"];
	return text;
}

NSString *TGVCardForContact(NSString *firstName, NSString *lastName, NSString *phoneNumber,
	NSString *username) {
	NSString *first = TGVCardTrimmed(firstName);
	NSString *last = TGVCardTrimmed(lastName);
	NSString *phone = TGVCardTrimmed(phoneNumber);
	NSString *handle = TGVCardTrimmed(username);
	if ([handle hasPrefix:@"@"])
		handle = [handle substringFromIndex:1];
	if (!first.length && !last.length && !phone.length && !handle.length)
		return nil;

	NSMutableArray *display = [NSMutableArray array];
	if (first.length)
		[display addObject:first];
	if (last.length)
		[display addObject:last];
	NSString *fullName = display.count ? [display componentsJoinedByString:@" "] : handle;
	if (!fullName.length)
		fullName = phone;

	NSMutableArray *lines = [NSMutableArray array];
	[lines addObject:@"BEGIN:VCARD"];
	[lines addObject:@"VERSION:3.0"];
	[lines addObject:[NSString stringWithFormat:@"N:%@;%@;;;",
			TGVCardEscaped(last), TGVCardEscaped(first)]];
	[lines addObject:[NSString stringWithFormat:@"FN:%@", TGVCardEscaped(fullName)]];
	if (phone.length)
		[lines addObject:[NSString stringWithFormat:@"TEL;TYPE=CELL:%@",
				[phone hasPrefix:@"+"] ? TGVCardEscaped(phone)
									   : [@"+" stringByAppendingString:TGVCardEscaped(phone)]]];
	if (handle.length)
		[lines addObject:[NSString stringWithFormat:@"URL:https://t.me/%@", TGVCardEscaped(handle)]];
	[lines addObject:@"END:VCARD"];
	return [[lines componentsJoinedByString:@"\r\n"] stringByAppendingString:@"\r\n"];
}

NSString *TGVCardFileNameForContact(NSString *firstName, NSString *lastName) {
	NSMutableArray *parts = [NSMutableArray array];
	NSString *first = TGVCardTrimmed(firstName);
	NSString *last = TGVCardTrimmed(lastName);
	if (first.length)
		[parts addObject:first];
	if (last.length)
		[parts addObject:last];
	NSString *base = parts.count ? [parts componentsJoinedByString:@" "] : @"Contact";
	NSCharacterSet *unsafe = [NSCharacterSet characterSetWithCharactersInString:@"/\\:*?\"<>|"];
	base = [[base componentsSeparatedByCharactersInSet:unsafe] componentsJoinedByString:@" "];
	base = [base stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!base.length)
		base = @"Contact";
	return [base stringByAppendingPathExtension:@"vcf"];
}

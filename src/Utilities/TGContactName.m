#import "TGContactName.h"

const CGFloat kContactRowHeight = 51.0f;

NSString *TGContactString(NSDictionary *u, NSString *key) {
	id value = u[key];
	return [value isKindOfClass:NSString.class] ? value : @"";
}

NSString *TGContactName(NSDictionary *u) {
	NSString *first = TGContactString(u, @"first_name");
	NSString *last = TGContactString(u, @"last_name");
	NSString *name = [[NSString stringWithFormat:@"%@ %@", first, last]
		stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if (name.length)
		return name;
	NSString *username = TGContactString(u, @"username");
	if (username.length)
		return [NSString stringWithFormat:@"@%@", username];
	return TGContactString(u, @"phone");
}

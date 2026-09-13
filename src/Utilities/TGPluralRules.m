#import "TGPluralRules.h"

NSString *TGPluralFormName(NSInteger count, NSString *pluralCode) {
	long long n = llabs((long long)count);
	NSString *code = pluralCode.length ? pluralCode : @"en";

	static NSSet *slavicThreeForm = nil;
	static NSSet *serboCroatianThreeForm = nil;
	static NSSet *balticLithuanian = nil;
	static NSSet *czechSlovak = nil;
	static NSSet *frenchZeroAsOne = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		slavicThreeForm = [NSSet setWithObjects:@"ru", @"uk", @"be", nil];
		serboCroatianThreeForm = [NSSet setWithObjects:@"sr", @"hr", @"bs", @"sh", nil];
		balticLithuanian = [NSSet setWithObjects:@"lt", nil];
		czechSlovak = [NSSet setWithObjects:@"cs", @"sk", nil];
		frenchZeroAsOne = [NSSet setWithObjects:@"fr", @"pt_BR", @"hy", nil];
	});

	if ([code isEqualToString:@"ar"]) {
		if (n == 0)
			return @"zero";
		if (n == 1)
			return @"one";
		if (n == 2)
			return @"two";
		if (n % 100 >= 3 && n % 100 <= 10)
			return @"few";
		if (n % 100 >= 11 && n % 100 <= 99)
			return @"many";
		return @"other";
	}
	if ([code isEqualToString:@"lv"]) {
		if (n % 10 == 0 || (n % 100 >= 11 && n % 100 <= 19))
			return @"zero";
		if (n % 10 == 1 && n % 100 != 11)
			return @"one";
		return @"other";
	}
	if ([balticLithuanian containsObject:code]) {
		if (n % 10 == 1 && !(n % 100 >= 11 && n % 100 <= 19))
			return @"one";
		if (n % 10 >= 2 && n % 10 <= 9 && !(n % 100 >= 11 && n % 100 <= 19))
			return @"few";
		return @"other";
	}
	if ([czechSlovak containsObject:code]) {
		if (n == 1)
			return @"one";
		if (n >= 2 && n <= 4)
			return @"few";
		return @"other";
	}
	if ([code isEqualToString:@"ro"]) {
		if (n == 1)
			return @"one";
		if (n == 0 || (n % 100 >= 1 && n % 100 <= 19))
			return @"few";
		return @"other";
	}
	if ([slavicThreeForm containsObject:code] || [serboCroatianThreeForm containsObject:code]) {
		BOOL lastOne = n % 10 == 1 && n % 100 != 11;
		BOOL lastFewRange = n % 10 >= 2 && n % 10 <= 4 && !(n % 100 >= 12 && n % 100 <= 14);
		if (lastOne)
			return @"one";
		if (lastFewRange)
			return @"few";
		return [slavicThreeForm containsObject:code] ? @"many" : @"other";
	}
	if ([code isEqualToString:@"pl"]) {
		BOOL fewRange = n % 10 >= 2 && n % 10 <= 4 && !(n % 100 >= 12 && n % 100 <= 14);
		if (n == 1)
			return @"one";
		if (fewRange)
			return @"few";
		return @"many";
	}
	if ([frenchZeroAsOne containsObject:code]) {
		if (n == 0 || n == 1)
			return @"one";
		return @"other";
	}
	return n == 1 ? @"one" : @"other";
}

NSString *TGPluralSubstituteCount(NSString *pattern, NSInteger count) {
	if (![pattern isKindOfClass:[NSString class]] || !pattern.length)
		return pattern;

	NSString *digits = [@(count) stringValue];
	NSMutableString *result = [NSMutableString stringWithCapacity:pattern.length];
	NSUInteger index = 0;
	while (index < pattern.length) {
		unichar character = [pattern characterAtIndex:index];
		if (character != '%') {
			[result appendString:[pattern substringWithRange:NSMakeRange(index, 1)]];
			index += 1;
			continue;
		}
		NSUInteger scan = index + 1;
		while (scan < pattern.length &&
			[[NSCharacterSet characterSetWithCharactersInString:@"lhqzjtL"]
				characterIsMember:[pattern characterAtIndex:scan]])
			scan += 1;
		unichar conversion = scan < pattern.length ? [pattern characterAtIndex:scan] : 0;
		BOOL isCount = conversion == 'd' || conversion == 'i' || conversion == 'u' ||
			conversion == '@';
		if (!isCount) {
			[result appendString:[pattern substringWithRange:NSMakeRange(index, 1)]];
			index += 1;
			continue;
		}
		[result appendString:digits];
		index = scan + 1;
	}
	return [result copy];
}

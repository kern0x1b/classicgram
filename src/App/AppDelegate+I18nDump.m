#import "AppDelegate+Private.h"
#import "TGClient+Translation.h"
#import "TGLocalization.h"

static NSString *TGI18nPlaceholderGuard(NSString *text, NSMutableArray *found) {
	NSMutableString *out = [NSMutableString string];
	NSScanner *scanner = [NSScanner scannerWithString:text];
	scanner.charactersToBeSkipped = nil;
	NSCharacterSet *specifierModifiers = [NSCharacterSet characterSetWithCharactersInString:@"0123456789.$-+ #0hlLqjzt"];
	while (![scanner isAtEnd]) {
		NSString *chunk = nil;
		[scanner scanUpToString:@"%" intoString:&chunk];
		if (chunk)
			[out appendString:chunk];
		if ([scanner isAtEnd])
			break;
		NSInteger start = scanner.scanLocation;
		NSInteger cursor = start + 1;
		if (cursor < (NSInteger)text.length && [text characterAtIndex:cursor] == '%') {
			[out appendString:@"%%"];
			scanner.scanLocation = cursor + 1;
			continue;
		}
		while (cursor < (NSInteger)text.length &&
			[specifierModifiers characterIsMember:[text characterAtIndex:cursor]])
			cursor++;
		if (cursor < (NSInteger)text.length)
			cursor++;
		NSString *token = [text substringWithRange:NSMakeRange(start, cursor - start)];
		[out appendFormat:@"【%d】", (int)found.count];
		[found addObject:token];
		scanner.scanLocation = cursor;
	}
	return out;
}

static NSString *TGI18nPlaceholderRestore(NSString *text, NSArray *found) {
	NSMutableString *out = [text mutableCopy];
	for (NSInteger i = 0; i < found.count; i++) {
		NSString *marker = [NSString stringWithFormat:@"【%d】", (int)i];
		[out replaceOccurrencesOfString:marker
							 withString:[found objectAtIndex:i]
								options:0
								  range:NSMakeRange(0, out.length)];
	}
	return out;
}

static NSString *TGI18nEscaped(NSString *text) {
	NSMutableString *out = [text mutableCopy];
	[out replaceOccurrencesOfString:@"\\" withString:@"\\\\" options:0 range:NSMakeRange(0, out.length)];
	[out replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:0 range:NSMakeRange(0, out.length)];
	[out replaceOccurrencesOfString:@"\n" withString:@"\\n" options:0 range:NSMakeRange(0, out.length)];
	return out;
}

@implementation AppDelegate (I18nDump)

- (NSArray *)i18nCustomKeys {
	NSString *path = [[NSBundle mainBundle] pathForResource:@"CustomKeys" ofType:@"txt"];
	NSString *body = path ? [NSString stringWithContentsOfFile:path
													 encoding:NSUTF8StringEncoding
														error:NULL]
						  : nil;
	if (!body.length)
		return @[];
	NSMutableArray *keys = [NSMutableArray array];
	for (NSString *line in [body componentsSeparatedByString:@"\n"]) {
		NSString *key = [line stringByTrimmingCharactersInSet:
				[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if (key.length)
			[keys addObject:key];
	}
	return keys;
}

- (NSString *)i18nOutputPathForLanguage:(NSString *)language {
	NSString *dir = [NSSearchPathForDirectoriesInDomains(
		NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	[[NSFileManager defaultManager] createDirectoryAtPath:dir
							  withIntermediateDirectories:YES
											   attributes:nil
													error:NULL];
	return [dir stringByAppendingPathComponent:
			[NSString stringWithFormat:@"%@.strings", language]];
}

- (void)i18nTranslateKeys:(NSArray *)keys
					   at:(NSUInteger)index
				 language:(NSString *)language
					 into:(NSMutableString *)out {
	if (index >= keys.count) {
		NSString *path = [self i18nOutputPathForLanguage:language];
		BOOL ok = [out writeToFile:path atomically:YES
						  encoding:NSUTF8StringEncoding error:NULL];
		NSLog(@"i18n %@: %@ (%d keys)", language, ok ? @"written" : @"FAILED",
			(int)keys.count);
		return;
	}

	NSString *key = [keys objectAtIndex:index];
	NSString *english = [[NSBundle mainBundle] localizedStringForKey:key
															   value:@""
															   table:@"Localizable"];
	if (!english.length) {
		[self i18nTranslateKeys:keys at:index + 1 language:language into:out];
		return;
	}

	NSMutableArray *placeholders = [NSMutableArray array];
	NSString *guarded = TGI18nPlaceholderGuard(english, placeholders);

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] translateText:guarded
							entities:nil
						  toLanguage:language
								tone:nil
						  completion:^(NSString *translated, NSArray *translatedEntities, NSString *errorMessage) {
							  typeof(self) strongSelf = weakSelf;
							  if (!strongSelf)
								  return;
							  NSString *value = translated.length
								  ? TGI18nPlaceholderRestore(translated, placeholders)
								  : english;
							  [out appendFormat:@"\"%@\" = \"%@\";\n",
									  TGI18nEscaped(key), TGI18nEscaped(value)];
							  if ((index % 25) == 0) {
								  NSLog(@"i18n %@: %d/%d", language, (int)index,
									  (int)keys.count);
								  [out writeToFile:[strongSelf i18nOutputPathForLanguage:language]
										atomically:YES
										  encoding:NSUTF8StringEncoding
											 error:NULL];
							  }
							  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
												(int64_t)(0.12 * NSEC_PER_SEC)),
								  dispatch_get_main_queue(), ^{
									  [strongSelf i18nTranslateKeys:keys
														 at:index + 1
												   language:language
													   into:out];
								  });
						  }];
}

- (void)i18nDumpForLanguage:(NSString *)language {
	NSArray *keys = [self i18nCustomKeys];
	if (!keys.count || !language.length) {
		NSLog(@"i18n: nothing to do");
		return;
	}
	NSLog(@"i18n %@: starting %d keys", language, (int)keys.count);
	NSString *marker = [NSString stringWithFormat:@"started %@ with %d keys\n",
		language, (int)keys.count];
	[marker writeToFile:[[self i18nOutputPathForLanguage:language]
							 stringByAppendingString:@".progress"]
			 atomically:YES
			   encoding:NSUTF8StringEncoding
				  error:NULL];
	[self i18nTranslateKeys:keys at:0 language:language into:[NSMutableString string]];
}

@end

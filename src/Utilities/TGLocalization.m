#import "TGLocalization.h"
#import "TGMirroredRect.h"
#import "TGPluralRules.h"

NSString *const TGLocalizationDidChangeNotification = @"TGLocalizationDidChangeNotification";

static NSString *const TGLocalizationPackIdDefaultsKey = @"TGLocalization.packId";

static NSString *TGLocalizationPackFilePath(void) {
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *base = paths.firstObject;
	if (!base.length)
		return nil;
	NSString *dir = [base stringByAppendingPathComponent:@"TGLocalization"];
	[[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
	return [dir stringByAppendingPathComponent:@"CustomPack.plist"];
}

NSLocale *TGFormatterLocale(void) {
	static NSLocale *locale = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
	});
	return locale;
}

@interface TGLocalization ()

@property (nonatomic, copy) NSString *packId;
@property (nonatomic, strong) NSDictionary *overrides;
@property (nonatomic, copy) NSString *pluralCode;
@property (nonatomic, assign) BOOL rtl;

@end

@implementation TGLocalization

+ (instancetype)shared {
	static TGLocalization *instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[TGLocalization alloc] init];
		[instance loadInstalledPack];
	});
	return instance;
}

- (void)loadInstalledPack {
	NSString *path = TGLocalizationPackFilePath();
	NSDictionary *stored = path.length ? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
	NSString *packId = [stored[@"packId"] isKindOfClass:[NSString class]] ? stored[@"packId"] : nil;
	NSDictionary *strings = [stored[@"strings"] isKindOfClass:[NSDictionary class]] ? stored[@"strings"] : nil;
	NSString *pluralCode = [stored[@"pluralCode"] isKindOfClass:[NSString class]] ? stored[@"pluralCode"] : nil;
	BOOL rtl = [stored[@"rtl"] boolValue];
	BOOL usable = packId.length && ![packId isEqualToString:@"en"] && strings.count;
	@synchronized (self) {
		self.packId = usable ? packId : nil;
		self.overrides = usable ? strings : nil;
		self.pluralCode = usable ? pluralCode : nil;
		self.rtl = usable ? rtl : NO;
	}
}

- (void)installPackId:(NSString *)packId strings:(NSDictionary *)strings {
	[self installPackId:packId strings:strings pluralCode:nil rtl:NO];
}

- (void)installPackId:(NSString *)packId
			  strings:(NSDictionary *)strings
		   pluralCode:(NSString *)pluralCode
				  rtl:(BOOL)rtl {
	if (!packId.length || [packId isEqualToString:@"en"] || !strings.count) {
		[self clearInstalledPack];
		return;
	}

	NSMutableDictionary *flat = [NSMutableDictionary dictionaryWithCapacity:strings.count];
	[strings enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
		(void)stop;
		if (![key isKindOfClass:[NSString class]])
			return;
		if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSDictionary class]])
			flat[key] = value;
	}];

	NSString *safePluralCode = pluralCode.length ? pluralCode : packId;
	@synchronized (self) {
		self.packId = packId;
		self.overrides = flat;
		self.pluralCode = safePluralCode;
		self.rtl = rtl;
	}

	NSString *path = TGLocalizationPackFilePath();
	if (path.length) {
		NSDictionary *stored = @{
			@"packId" : packId,
			@"strings" : flat,
			@"pluralCode" : safePluralCode,
			@"rtl" : @(rtl),
		};
		[stored writeToFile:path atomically:YES];
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:TGLocalizationDidChangeNotification object:self];
}

- (void)clearInstalledPack {
	@synchronized (self) {
		self.packId = nil;
		self.overrides = nil;
		self.pluralCode = nil;
		self.rtl = NO;
	}
	NSString *path = TGLocalizationPackFilePath();
	if (path.length)
		[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:TGLocalizationDidChangeNotification object:self];
}

- (NSString *)installedPackId {
	@synchronized (self) {
		return self.packId;
	}
}

static NSString *const TGLocalizationSystemPackAttemptKey = @"TGLocalizationSystemPackAttempted";

- (BOOL)wantsSystemLanguagePack {
	if ([self installedPackId].length)
		return NO;
	if ([[NSUserDefaults standardUserDefaults] boolForKey:TGLocalizationSystemPackAttemptKey])
		return NO;
	return [[self systemLanguagePackId] length] > 0;
}

- (NSString *)systemLanguagePackId {
	NSArray *preferred = [NSLocale preferredLanguages];
	NSString *first = [preferred.firstObject isKindOfClass:[NSString class]]
		? preferred.firstObject
		: nil;
	if (!first.length)
		return nil;
	NSString *code = [[first componentsSeparatedByString:@"-"] firstObject];
	if (!code.length || [code isEqualToString:@"en"])
		return nil;
	return code;
}

- (void)rememberSystemLanguagePackAttempt {
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:TGLocalizationSystemPackAttemptKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)installedPackPluralCode {
	@synchronized (self) {
		return self.pluralCode.length ? self.pluralCode : @"en";
	}
}

- (BOOL)installedPackIsRTL {
	@synchronized (self) {
		return self.rtl;
	}
}

- (NSString *)overrideForKey:(NSString *)key {
	if (!key.length)
		return nil;
	@synchronized (self) {
		id value = self.overrides[key];
		return [value isKindOfClass:[NSString class]] ? value : nil;
	}
}

- (id)overrideValueForKey:(NSString *)key {
	if (!key.length)
		return nil;
	@synchronized (self) {
		return self.overrides[key];
	}
}

@end

NSTextAlignment TGLocalizedLeadingTextAlignment(void) {
	return [[TGLocalization shared] installedPackIsRTL] ? NSTextAlignmentRight : NSTextAlignmentLeft;
}

static UIImage *TGHorizontallyFlipped(UIImage *image) {
	UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextTranslateCTM(ctx, image.size.width, 0);
	CGContextScaleCTM(ctx, -1, 1);
	[image drawAtPoint:CGPointZero];
	UIImage *flipped = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return flipped;
}

UIImage *TGLocalizedDirectionalStretchableImage(UIImage *image, NSInteger leftCapWidth) {
	if (!image)
		return nil;
	if (![[TGLocalization shared] installedPackIsRTL])
		return [image stretchableImageWithLeftCapWidth:(int)leftCapWidth topCapHeight:0];

	NSInteger mirroredLeftCap = (NSInteger)image.size.width - leftCapWidth - 1;
	if (mirroredLeftCap < 0)
		mirroredLeftCap = 0;
	UIImage *flipped = TGHorizontallyFlipped(image);
	return [flipped stretchableImageWithLeftCapWidth:(int)mirroredLeftCap topCapHeight:0];
}

UIImage *TGLocalizedDirectionalImage(UIImage *image) {
	if (!image)
		return nil;
	if (![[TGLocalization shared] installedPackIsRTL])
		return image;
	return TGHorizontallyFlipped(image);
}

BOOL TGLocalizedIsRTL(void) {
	return [[TGLocalization shared] installedPackIsRTL];
}

CGRect TGLocalizedMirroredRect(CGRect rect, CGFloat containerWidth) {
	return TGMirroredRectInContainer(rect, containerWidth, TGLocalizedIsRTL());
}

void TGApplyRTLTableMirroring(UITableView *tableView) {
	tableView.transform = TGLocalizedIsRTL()
		? CGAffineTransformMakeScale(-1, 1)
		: CGAffineTransformIdentity;
}

void TGApplyRTLCellMirroring(UITableViewCell *cell) {
	CGAffineTransform t = TGLocalizedIsRTL()
		? CGAffineTransformMakeScale(-1, 1)
		: CGAffineTransformIdentity;
	cell.imageView.transform = t;
	cell.textLabel.transform = t;
	cell.detailTextLabel.transform = t;
	if (TGLocalizedIsRTL()) {
		cell.textLabel.textAlignment = NSTextAlignmentRight;
		cell.detailTextLabel.textAlignment = NSTextAlignmentRight;
	}
}

void TGApplyRTLHeaderMirroring(UIView *headerOrFooterView) {
	if (!headerOrFooterView)
		return;
	CGAffineTransform t = TGLocalizedIsRTL()
		? CGAffineTransformMakeScale(-1, 1)
		: CGAffineTransformIdentity;
	for (UIView *sub in headerOrFooterView.subviews) {
		if ([sub isKindOfClass:[UILabel class]])
			sub.transform = t;
		else
			TGApplyRTLHeaderMirroring(sub);
	}
}

static NSBundle *TGLocalizationLanguageBundle(void) {
	static NSString *cachedPackId = nil;
	static NSBundle *cachedBundle = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		[[NSNotificationCenter defaultCenter] addObserverForName:TGLocalizationDidChangeNotification
														   object:nil
															queue:nil
													   usingBlock:^(NSNotification *note) {
														   (void)note;
														   @synchronized ([TGLocalization class]) {
															   cachedPackId = nil;
															   cachedBundle = nil;
														   }
													   }];
	});

	NSString *packId = [[TGLocalization shared] installedPackId] ?: @"en";

	@synchronized ([TGLocalization class]) {
		if ([packId isEqualToString:cachedPackId])
			return cachedBundle;
	}

	NSBundle *bundle = nil;
	NSString *path = [[NSBundle mainBundle] pathForResource:packId ofType:@"lproj"];
	if (!path.length) {
		NSString *baseCode = [packId componentsSeparatedByString:@"-"].firstObject;
		if (baseCode.length && ![baseCode isEqualToString:packId])
			path = [[NSBundle mainBundle] pathForResource:baseCode ofType:@"lproj"];
	}
	if (path.length)
		bundle = [NSBundle bundleWithPath:path];

	NSBundle *resolved = bundle ?: [NSBundle mainBundle];
	@synchronized ([TGLocalization class]) {
		cachedPackId = packId;
		cachedBundle = resolved;
	}
	return resolved;
}

NSString *TGLocalizedString(NSString *key, NSString *fallback) {
	NSString *safeFallback = fallback ?: key ?
											 : @"";
	if (!key.length)
		return safeFallback;

	NSString *override = [[TGLocalization shared] overrideForKey:key];
	if (override.length)
		return override;

	NSString *bundled = [TGLocalizationLanguageBundle() localizedStringForKey:key value:safeFallback table:@"Localizable"];
	return bundled.length ? bundled : safeFallback;
}

NSString *TGLocalizedPlural(NSString *key, NSInteger count, NSString *fallbackOne, NSString *fallbackOther) {
	TGLocalization *shared = [TGLocalization shared];
	id override = [shared overrideValueForKey:key];
	NSString *installedForm = TGPluralFormName(count, [shared installedPackPluralCode]);

	if ([override isKindOfClass:[NSDictionary class]]) {
		NSDictionary *forms = override;
		NSString *value = forms[installedForm] ?: (forms[@"other"] ?: forms[@"one"]);
		if ([value isKindOfClass:[NSString class]] && value.length)
			return TGPluralSubstituteCount(value, count);
	}
	if ([override isKindOfClass:[NSString class]] && [(NSString *) override length])
		return TGPluralSubstituteCount(override, count);

	if (key.length) {
		NSBundle *bundle = TGLocalizationLanguageBundle();
		NSString *miss = @"\x01TGLocalizationPluralMiss\x01";
		NSString *bundledOne = [bundle localizedStringForKey:[key stringByAppendingString:@"_1"] value:miss table:@"Localizable"];
		NSString *bundledOther = [bundle localizedStringForKey:[key stringByAppendingString:@"_any"] value:miss table:@"Localizable"];
		if ([bundledOne isEqualToString:miss])
			bundledOne = nil;
		if ([bundledOther isEqualToString:miss])
			bundledOther = nil;
		BOOL wantsOneForm = [installedForm isEqualToString:@"one"];
		NSString *bundledValue = wantsOneForm ? (bundledOne ?: bundledOther) : (bundledOther ?: bundledOne);
		if (bundledValue.length)
			return TGPluralSubstituteCount(bundledValue, count);
	}

	NSString *safeOne = fallbackOne.length ? fallbackOne : fallbackOther;
	NSString *safeOther = fallbackOther.length ? fallbackOther : fallbackOne;
	NSString *englishForm = TGPluralFormName(count, @"en");
	NSString *safeFallback = [englishForm isEqualToString:@"one"] ? safeOne : safeOther;
	safeFallback = safeFallback.length ? safeFallback : (key ?: @"");

	return TGPluralSubstituteCount(safeFallback, count);
}

#import "TGEmoji.h"
#import "TGTextWarmup.h"
#import "TGRichText.h"

#import <CoreText/CoreText.h>

static NSString *const kTGEmojiKeyAttribute = @"TGEmojiKey";
static const unichar kTGEmojiPlaceholder = 0xFFFC;
static const CGFloat kTGEmojiUnboundedWidth = 100000.0f;

typedef struct {
	CGFloat ascent;
	CGFloat descent;
	CGFloat width;
} TGEmojiBox;

static void TGEmojiBoxRelease(void *ref) {
	free(ref);
}

static CGFloat TGEmojiBoxAscent(void *ref) {
	return ((TGEmojiBox *)ref)->ascent;
}

static CGFloat TGEmojiBoxDescent(void *ref) {
	return ((TGEmojiBox *)ref)->descent;
}

static CGFloat TGEmojiBoxWidth(void *ref) {
	return ((TGEmojiBox *)ref)->width;
}

static NSUInteger gTGEmojiPlaceholdersBuilt = 0;
static NSUInteger gTGEmojiImagesDrawn = 0;

static BOOL TGEmojiScalarIsCandidate(UTF32Char code) {
	if (code < 0x2000)
		return NO;
	if (code <= 0x3300)
		return YES;
	if (code >= 0xFE00 && code <= 0xFE0F)
		return YES;
	if (code >= 0x1F000 && code <= 0x1FBFF)
		return YES;
	return code >= 0xE0020 && code <= 0xE007F;
}

static BOOL TGEmojiScalarIsPictographic(UTF32Char code) {
	return code >= 0x1F000 && code <= 0x1FBFF;
}

static BOOL TGEmojiScalarIsInvisible(UTF32Char code) {
	if (code == 0x200D || code == 0xFE0E || code == 0xFE0F)
		return YES;
	if (code >= 0x1F3FB && code <= 0x1F3FF)
		return YES;
	return code >= 0xE0020 && code <= 0xE007F;
}

static NSUInteger TGEmojiAppendScalar(UTF32Char code, unichar *units) {
	if (code <= 0xFFFF) {
		units[0] = (unichar)code;
		return 1;
	}
	UTF32Char shifted = code - 0x10000;
	units[0] = (unichar)(0xD800 + (shifted >> 10));
	units[1] = (unichar)(0xDC00 + (shifted & 0x3FF));
	return 2;
}

static CTFontRef TGEmojiSystemFont(void) {
	static CTFontRef font = NULL;
	static BOOL resolved = NO;
	if (resolved)
		return font;
	resolved = YES;

	CTFontRef candidate = CTFontCreateWithName(CFSTR("AppleColorEmoji"), 16.0f, NULL);
	if (!candidate)
		return NULL;

	NSString *family = CFBridgingRelease(CTFontCopyFamilyName(candidate));
	unichar probe[2];
	CGGlyph glyphs[2] = {0, 0};
	NSInteger count = TGEmojiAppendScalar(0x1F604, probe);
	CTFontGetGlyphsForCharacters(candidate, probe, glyphs, (CFIndex)count);
	BOOL usable = [family rangeOfString:@"Emoji"].location != NSNotFound && glyphs[0] != 0;
	if (!usable) {
		CFRelease(candidate);
		return NULL;
	}
	font = candidate;
	return font;
}

UIFont *TGEmojiFontOfSize(CGFloat size) {
	if (size < 1.0f)
		size = 1.0f;
	if (!TGEmojiSystemFont())
		return [UIFont systemFontOfSize:size];
	return [UIFont fontWithName:@"AppleColorEmoji" size:size] ?: [UIFont systemFontOfSize:size];
}

static BOOL TGEmojiSystemDrawsScalar(UTF32Char code) {
	CTFontRef font = TGEmojiSystemFont();
	if (!font)
		return NO;

	static NSMutableDictionary *cache = nil;
	if (!cache)
		cache = [[NSMutableDictionary alloc] init];
	NSNumber *slot = [NSNumber numberWithUnsignedInt:code];
	NSNumber *known = [cache objectForKey:slot];
	if (known)
		return [known boolValue];

	unichar units[2];
	CGGlyph glyphs[2] = {0, 0};
	NSInteger count = TGEmojiAppendScalar(code, units);
	CTFontGetGlyphsForCharacters(font, units, glyphs, (CFIndex)count);
	BOOL drawn = glyphs[0] != 0;
	[cache setObject:[NSNumber numberWithBool:drawn] forKey:slot];
	return drawn;
}

static BOOL TGEmojiSystemDrawsPair(UTF32Char first, UTF32Char second) {
	CTFontRef font = TGEmojiSystemFont();
	if (!font)
		return NO;

	static NSMutableDictionary *cache = nil;
	if (!cache)
		cache = [[NSMutableDictionary alloc] init];
	NSNumber *slot = [NSNumber numberWithUnsignedLongLong:
			((unsigned long long)first << 32) | second];
	NSNumber *known = [cache objectForKey:slot];
	if (known)
		return [known boolValue];

	unichar units[4];
	NSInteger count = TGEmojiAppendScalar(first, units);
	count += TGEmojiAppendScalar(second, units + count);
	NSString *text = [NSString stringWithCharacters:units length:count];
	NSString *fontKey = (__bridge NSString *)kCTFontAttributeName;
	NSDictionary *attributes = [NSDictionary dictionaryWithObject:(__bridge id)font forKey:fontKey];
	NSAttributedString *bareString = [NSAttributedString alloc];
	NSAttributedString *string = [bareString initWithString:text
												 attributes:attributes];
	CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)string);
	CFIndex glyphs = line ? CTLineGetGlyphCount(line) : 2;
	if (line)
		CFRelease(line);

	BOOL drawn = glyphs == 1;
	[cache setObject:[NSNumber numberWithBool:drawn] forKey:slot];
	return drawn;
}

static BOOL TGEmojiScalarIsRemovable(UTF32Char code) {
	if (TGEmojiScalarIsInvisible(code))
		return YES;
	return TGEmojiSystemFont() && TGEmojiScalarIsPictographic(code);
}

static NSString *TGEmojiKeyForScalars(const UTF32Char *scalars, NSUInteger count) {
	if (count == 1)
		return [NSString stringWithFormat:@"%x", (unsigned)scalars[0]];
	return [NSString stringWithFormat:@"%x-%x", (unsigned)scalars[0], (unsigned)scalars[1]];
}

static NSString *TGEmojiDirectory(void) {
	static NSString *path = nil;
	if (!path)
		path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"emoji"];
	return path;
}

static BOOL TGEmojiHasImage(NSString *key) {
	static NSMutableDictionary *known = nil;
	if (!known)
		known = [[NSMutableDictionary alloc] init];

	NSNumber *cached = [known objectForKey:key];
	if (cached)
		return [cached boolValue];

	NSString *path = [[TGEmojiDirectory() stringByAppendingPathComponent:key]
		stringByAppendingPathExtension:@"png"];
	BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
	[known setObject:[NSNumber numberWithBool:exists] forKey:key];
	return exists;
}

static NSCache *TGEmojiImageCache(void) {
	static NSCache *cache = nil;
	if (!cache) {
		cache = [[NSCache alloc] init];
		[cache setCountLimit:96];
	}
	return cache;
}

void TGEmojiPurgeImages(void) {
	[TGEmojiImageCache() removeAllObjects];
}

static UIImage *TGEmojiImage(NSString *key) {
	NSCache *cache = TGEmojiImageCache();
	UIImage *image = [cache objectForKey:key];
	if (image)
		return image;

	NSString *path = [[TGEmojiDirectory() stringByAppendingPathComponent:key]
		stringByAppendingPathExtension:@"png"];
	image = [UIImage imageWithContentsOfFile:path];
	if (image)
		[cache setObject:image forKey:key];
	return image;
}

static NSDictionary *TGEmojiPlainAttributes(UIFont *font, UIColor *colour) {
	id ctFont = CFBridgingRelease(CTFontCreateWithName(
		(__bridge CFStringRef)font.fontName, font.pointSize, NULL));
	UIColor *ink = colour ?: [UIColor blackColor];
	return [NSDictionary dictionaryWithObjectsAndKeys:
			ctFont, (__bridge NSString *)kCTFontAttributeName,
		(__bridge id)ink.CGColor, (__bridge NSString *)kCTForegroundColorAttributeName,
		nil];
}

static NSAttributedString *TGEmojiPlaceholderWithMetrics(NSString *key, CGFloat ascent,
	CGFloat descent,
	NSDictionary *plain) {
	TGEmojiBox *box = malloc(sizeof(TGEmojiBox));
	if (!box)
		return nil;
	box->ascent = ascent;
	box->descent = descent;
	box->width = ceilf(ascent + descent);

	CTRunDelegateCallbacks callbacks;
	memset(&callbacks, 0, sizeof(callbacks));
	callbacks.version = kCTRunDelegateVersion1;
	callbacks.dealloc = TGEmojiBoxRelease;
	callbacks.getAscent = TGEmojiBoxAscent;
	callbacks.getDescent = TGEmojiBoxDescent;
	callbacks.getWidth = TGEmojiBoxWidth;

	id delegate = CFBridgingRelease(CTRunDelegateCreate(&callbacks, box));
	if (!delegate) {
		free(box);
		return nil;
	}

	NSMutableDictionary *attributes = plain ? [plain mutableCopy]
											: [NSMutableDictionary dictionary];
	[attributes setObject:(__bridge id)[UIColor clearColor].CGColor
				   forKey:(__bridge NSString *)kCTForegroundColorAttributeName];
	[attributes removeObjectForKey:NSForegroundColorAttributeName];
	[attributes setObject:delegate
				   forKey:(__bridge NSString *)kCTRunDelegateAttributeName];
	[attributes setObject:key forKey:kTGEmojiKeyAttribute];

	gTGEmojiPlaceholdersBuilt++;
	return [[NSAttributedString alloc]
		initWithString:[NSString stringWithCharacters:&kTGEmojiPlaceholder length:1]
			attributes:attributes];
}

static NSAttributedString *TGEmojiPlaceholder(NSString *key, UIFont *font,
	NSDictionary *plain) {
	TGEmojiBox *box = malloc(sizeof(TGEmojiBox));
	if (!box)
		return nil;
	box->ascent = font.ascender;
	box->descent = -font.descender;
	box->width = ceilf(font.ascender - font.descender);

	CTRunDelegateCallbacks callbacks;
	memset(&callbacks, 0, sizeof(callbacks));
	callbacks.version = kCTRunDelegateVersion1;
	callbacks.dealloc = TGEmojiBoxRelease;
	callbacks.getAscent = TGEmojiBoxAscent;
	callbacks.getDescent = TGEmojiBoxDescent;
	callbacks.getWidth = TGEmojiBoxWidth;

	id delegate = CFBridgingRelease(CTRunDelegateCreate(&callbacks, box));
	if (!delegate) {
		free(box);
		return nil;
	}

	NSMutableDictionary *attributes = [plain mutableCopy];
	[attributes setObject:(__bridge id)[UIColor clearColor].CGColor
				   forKey:(__bridge NSString *)kCTForegroundColorAttributeName];
	[attributes setObject:delegate
				   forKey:(__bridge NSString *)kCTRunDelegateAttributeName];
	[attributes setObject:key forKey:kTGEmojiKeyAttribute];

	gTGEmojiPlaceholdersBuilt++;
	return [[NSAttributedString alloc]
		initWithString:[NSString stringWithCharacters:&kTGEmojiPlaceholder length:1]
			attributes:attributes];
}

static NSDictionary *TGEmojiRunAttributes(NSDictionary *source, UIFont *font,
	UIColor *colour) {
	UIFont *runFont = font;
	id fontValue = [source objectForKey:NSFontAttributeName];
	if ([fontValue isKindOfClass:UIFont.class])
		runFont = fontValue;
	UIColor *runColour = colour;
	id colourValue = [source objectForKey:NSForegroundColorAttributeName];
	if ([colourValue isKindOfClass:UIColor.class])
		runColour = colourValue;
	return TGEmojiPlainAttributes(runFont ?: font, runColour ?: colour);
}

static NSAttributedString *TGEmojiCoreTextString(NSAttributedString *styled,
	UIFont *font, UIColor *colour) {
	if (!styled.length)
		return nil;
	NSMutableAttributedString *out =
		[[NSMutableAttributedString alloc] initWithString:styled.string];
	NSInteger index = 0;
	NSInteger length = styled.length;
	while (index < length) {
		NSRange range = NSMakeRange(index, 0);
		NSDictionary *attributes = [styled attributesAtIndex:index effectiveRange:&range];
		if (range.length == 0)
			range = NSMakeRange(index, 1);
		[out setAttributes:TGEmojiRunAttributes(attributes, font, colour) range:range];
		index = NSMaxRange(range);
	}
	return out;
}

static void TGEmojiAppendPlain(NSMutableAttributedString *target, NSString *text,
	NSAttributedString *styled,
	NSUInteger from, NSUInteger to, NSDictionary *attributes) {
	if (to <= from)
		return;
	NSRange range = NSMakeRange(from, to - from);
	if (styled && NSMaxRange(range) <= styled.length) {
		[target appendAttributedString:[styled attributedSubstringFromRange:range]];
		return;
	}
	NSString *piece = [text substringWithRange:range];
	NSAttributedString *barePiece = [NSAttributedString alloc];
	NSAttributedString *chunk = [barePiece initWithString:piece
											   attributes:attributes];
	[target appendAttributedString:chunk];
}

static BOOL TGEmojiWalk(NSString *text, UIFont *font, UIColor *colour,
	NSAttributedString *styled, NSMutableArray *paragraphs) {
	NSInteger length = text.length;
	if (!length)
		return NO;

	unichar stackUnits[256];
	unichar *units = length <= 256 ? stackUnits : malloc(length * sizeof(unichar));
	if (!units)
		return NO;
	[text getCharacters:units range:NSMakeRange(0, length)];

	NSDictionary *plain = paragraphs ? TGEmojiPlainAttributes(font, colour) : nil;
	NSMutableAttributedString *current = paragraphs
		? [[NSMutableAttributedString alloc] init]
		: nil;
	NSInteger run = 0;
	BOOL changed = NO;

	NSInteger i = 0;
	while (i < length) {
		unichar high = units[i];
		UTF32Char code = high;
		NSInteger size = 1;
		if (high >= 0xD800 && high <= 0xDBFF && i + 1 < length &&
			units[i + 1] >= 0xDC00 && units[i + 1] <= 0xDFFF) {
			code = ((UTF32Char)(high - 0xD800) << 10) +
				(units[i + 1] - 0xDC00) + 0x10000;
			size = 2;
		}

		if (high == '\n') {
			if (paragraphs) {
				TGEmojiAppendPlain(current, text, styled, run, i, plain);
				[paragraphs addObject:current];
				current = [[NSMutableAttributedString alloc] init];
			}
			i += 1;
			run = i;
			continue;
		}

		if (!TGEmojiScalarIsCandidate(code)) {
			i += size;
			continue;
		}

		UTF32Char scalars[2] = {code, 0};
		NSInteger scalarCount = 1;
		NSInteger end = i + size;
		if (code >= 0x1F1E6 && code <= 0x1F1FF && end + 1 < length &&
			units[end] >= 0xD800 && units[end] <= 0xDBFF) {
			UTF32Char next = ((UTF32Char)(units[end] - 0xD800) << 10) +
				(units[end + 1] - 0xDC00) + 0x10000;
			if (next >= 0x1F1E6 && next <= 0x1F1FF) {
				scalars[1] = next;
				scalarCount = 2;
				end += 2;
			}
		}

		NSInteger consumed = end;
		while (consumed < length &&
			(units[consumed] == 0xFE0F || units[consumed] == 0xFE0E))
			consumed++;

		BOOL drawable = scalarCount == 2
			? TGEmojiSystemDrawsPair(scalars[0], scalars[1])
			: TGEmojiSystemDrawsScalar(code);
		if (drawable) {
			i = consumed;
			continue;
		}

		NSString *key = TGEmojiKeyForScalars(scalars, scalarCount);
		BOOL replaceable = TGEmojiHasImage(key);
		if (!replaceable && !TGEmojiScalarIsRemovable(code)) {
			i = consumed;
			continue;
		}

		changed = YES;
		if (!paragraphs)
			break;

		TGEmojiAppendPlain(current, text, styled, run, i, plain);
		if (replaceable) {
			NSDictionary *base = plain;
			if (styled && i < styled.length)
				base = [styled attributesAtIndex:i effectiveRange:NULL];
			NSAttributedString *slot = TGEmojiPlaceholder(key, font, base);
			if (slot)
				[current appendAttributedString:slot];
		}
		i = consumed;
		run = i;
	}

	if (paragraphs) {
		if (changed) {
			TGEmojiAppendPlain(current, text, styled, run, length, plain);
			[paragraphs addObject:current];
		} else {
			[paragraphs removeAllObjects];
		}
	}

	if (units != stackUnits)
		free(units);
	return changed;
}

static BOOL TGEmojiTextCarriesSymbols(NSString *text) {
	CFIndex length = (CFIndex)text.length;
	CFStringInlineBuffer buffer;
	CFStringInitInlineBuffer((__bridge CFStringRef)text, &buffer, CFRangeMake(0, length));
	for (CFIndex i = 0; i < length; i++) {
		if (CFStringGetCharacterFromInlineBuffer(&buffer, i) >= 0x2000)
			return YES;
	}
	return NO;
}

BOOL TGEmojiTextNeedsSubstitution(NSString *text) {
	if (!text.length)
		return NO;
	if (!TGEmojiTextCarriesSymbols(text))
		return NO;
	return TGEmojiWalk(text, nil, nil, nil, nil);
}

static NSArray *TGEmojiBuildLines(NSArray *paragraphs, NSDictionary *plain, CGFloat limit,
	NSInteger maxLines, CGFloat *widest) {
	NSMutableArray *lines = [NSMutableArray array];
	CGFloat maxWidth = 0;
	if (limit < 1 || limit > kTGEmojiUnboundedWidth)
		limit = kTGEmojiUnboundedWidth;

	NSAttributedString *bareDots = [NSAttributedString alloc];
	NSAttributedString *dots = [bareDots initWithString:@"…"
											 attributes:plain];

	for (NSAttributedString *paragraph in paragraphs) {
		if (maxLines > 0 && (NSInteger)lines.count >= maxLines)
			break;

		CFIndex length = (CFIndex)paragraph.length;
		if (length == 0) {
			CTLineRef empty = CTLineCreateWithAttributedString(
				(__bridge CFAttributedStringRef)paragraph);
			if (empty)
				[lines addObject:CFBridgingRelease(empty)];
			continue;
		}

		CTTypesetterRef setter = CTTypesetterCreateWithAttributedString(
			(__bridge CFAttributedStringRef)paragraph);
		if (!setter)
			continue;

		CFIndex start = 0;
		while (start < length) {
			BOOL lastAllowed = maxLines > 0 && (NSInteger)lines.count == maxLines - 1;
			CTLineRef line = NULL;

			if (lastAllowed) {
				CTLineRef whole = CTTypesetterCreateLine(setter,
					CFRangeMake(start, length - start));
				CTLineRef token = CTLineCreateWithAttributedString(
					(__bridge CFAttributedStringRef)dots);
				if (whole)
					line = CTLineCreateTruncatedLine(whole, limit,
						kCTLineTruncationEnd, token);
				if (!line && whole)
					line = (CTLineRef)CFRetain(whole);
				if (whole)
					CFRelease(whole);
				if (token)
					CFRelease(token);
				start = length;
			} else {
				CFIndex count = CTTypesetterSuggestLineBreak(setter, start, limit);
				if (count < 1)
					break;
				line = CTTypesetterCreateLine(setter, CFRangeMake(start, count));
				start += count;
			}

			if (!line)
				break;
			CGFloat width = (CGFloat)CTLineGetTypographicBounds(line, NULL, NULL, NULL);
			if (width > maxWidth)
				maxWidth = width;
			[lines addObject:CFBridgingRelease(line)];

			if (maxLines > 0 && (NSInteger)lines.count >= maxLines)
				break;
		}
		CFRelease(setter);
	}

	if (widest)
		*widest = maxWidth;
	return lines;
}

static CGSize TGEmojiMeasure(NSString *text, UIFont *font, CGSize limit,
	NSLineBreakMode mode, NSInteger maxLines) {
	TGWaitForTextWarm();
	NSMutableArray *paragraphs = nil;
	if (text.length && TGEmojiTextCarriesSymbols(text)) {
		paragraphs = [NSMutableArray array];
		if (!TGEmojiWalk(text, font, [UIColor blackColor], nil, paragraphs))
			paragraphs = nil;
	}
	if (!paragraphs.count)
		return [text sizeWithFont:font constrainedToSize:limit lineBreakMode:mode];

	CGFloat widest = 0;
	NSDictionary *plain = TGEmojiPlainAttributes(font, [UIColor blackColor]);
	NSArray *lines = TGEmojiBuildLines(paragraphs, plain, limit.width, maxLines, &widest);
	CGFloat height = lines.count * font.lineHeight;
	if (limit.width > 0 && widest > limit.width)
		widest = limit.width;
	if (limit.height > 0 && height > limit.height)
		height = limit.height;
	return CGSizeMake(ceilf(widest), ceilf(height));
}

static unsigned long long TGEmojiMeasureKey(NSString *text, UIFont *font, CGSize limit,
	NSLineBreakMode mode, NSInteger maxLines) {
	unsigned long long key = 1469598103934665603ULL;
	unsigned long long parts[8];
	parts[0] = (unsigned long long)[text hash];
	parts[1] = (unsigned long long)text.length;
	parts[2] = (unsigned long long)[font.fontName hash];
	parts[3] = (unsigned long long)(long long)(font.pointSize * 16.0f);
	parts[4] = (unsigned long long)(long long)(limit.width * 16.0f);
	parts[5] = (unsigned long long)(long long)(limit.height * 16.0f);
	parts[6] = (unsigned long long)mode;
	parts[7] = (unsigned long long)maxLines;
	for (NSInteger i = 0; i < 8; i++)
		key = (key ^ parts[i]) * 1099511628211ULL;
	return key;
}

CGSize TGEmojiTextSize(NSString *text, UIFont *font, CGSize limit,
	NSLineBreakMode mode, NSInteger maxLines) {
	if (!text.length)
		return CGSizeZero;

	static NSCache *measured = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		measured = [[NSCache alloc] init];
		[measured setCountLimit:512];
	});

	NSNumber *key = @(TGEmojiMeasureKey(text, font, limit, mode, maxLines));
	NSArray *hit = [measured objectForKey:key];
	if (hit.count == 2 && (hit[0] == text || [hit[0] isEqualToString:text]))
		return [hit[1] CGSizeValue];

	CGSize size = TGEmojiMeasure(text, font, limit, mode, maxLines);
	[measured setObject:@[ text, [NSValue valueWithCGSize:size] ] forKey:key];
	return size;
}

void TGEmojiDrawImagesInLine(CTLineRef line, CGFloat left, CGFloat baseline) {
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (!context || !line)
		return;

	CFArrayRef runs = CTLineGetGlyphRuns(line);
	CFIndex runCount = runs ? CFArrayGetCount(runs) : 0;
	for (CFIndex slot = 0; slot < runCount; slot++) {
		CTRunRef glyphRun = (CTRunRef)CFArrayGetValueAtIndex(runs, slot);
		NSDictionary *attributes = (__bridge NSDictionary *)CTRunGetAttributes(glyphRun);
		NSString *key = [attributes objectForKey:kTGEmojiKeyAttribute];
		if (!key)
			continue;

		UIImage *image = TGEmojiImage(key);
		if (!image)
			continue;

		CGPoint position = CGPointZero;
		CTRunGetPositions(glyphRun, CFRangeMake(0, 1), &position);
		CGFloat ascent = 0, descent = 0;
		CGFloat advance = (CGFloat)CTRunGetTypographicBounds(glyphRun,
			CFRangeMake(0, 1), &ascent, &descent, NULL);
		CGRect box = CGRectMake(left + position.x, baseline - descent, advance,
			ascent + descent);
		CGContextDrawImage(context, box, image.CGImage);
		gTGEmojiImagesDrawn++;
	}
}

static void TGEmojiMetricsOfAttributes(NSDictionary *attributes, CGFloat *ascent,
	CGFloat *descent) {
	*ascent = 14.0f;
	*descent = 4.0f;

	id ctFont = [attributes objectForKey:(__bridge NSString *)kCTFontAttributeName];
	if (ctFont) {
		CTFontRef font = (__bridge CTFontRef)ctFont;
		*ascent = CTFontGetAscent(font);
		*descent = CTFontGetDescent(font);
		return;
	}
	id uiFont = [attributes objectForKey:NSFontAttributeName];
	if ([uiFont isKindOfClass:UIFont.class]) {
		*ascent = [uiFont ascender];
		*descent = -[uiFont descender];
	}
}

NSAttributedString *TGEmojiSubstituteInString(NSAttributedString *source) {
	NSString *text = source.string;
	NSInteger length = text.length;
	if (!length || !TGEmojiTextCarriesSymbols(text))
		return nil;

	unichar stackUnits[256];
	unichar *units = length <= 256 ? stackUnits : malloc(length * sizeof(unichar));
	if (!units)
		return nil;
	[text getCharacters:units range:NSMakeRange(0, length)];

	NSMutableAttributedString *out = nil;
	NSInteger run = 0;
	NSInteger i = 0;
	while (i < length) {
		unichar high = units[i];
		UTF32Char code = high;
		NSInteger size = 1;
		if (high >= 0xD800 && high <= 0xDBFF && i + 1 < length &&
			units[i + 1] >= 0xDC00 && units[i + 1] <= 0xDFFF) {
			code = ((UTF32Char)(high - 0xD800) << 10) +
				(units[i + 1] - 0xDC00) + 0x10000;
			size = 2;
		}

		if (!TGEmojiScalarIsCandidate(code)) {
			i += size;
			continue;
		}

		UTF32Char scalars[2] = {code, 0};
		NSInteger scalarCount = 1;
		NSInteger end = i + size;
		if (code >= 0x1F1E6 && code <= 0x1F1FF && end + 1 < length &&
			units[end] >= 0xD800 && units[end] <= 0xDBFF) {
			UTF32Char next = ((UTF32Char)(units[end] - 0xD800) << 10) +
				(units[end + 1] - 0xDC00) + 0x10000;
			if (next >= 0x1F1E6 && next <= 0x1F1FF) {
				scalars[1] = next;
				scalarCount = 2;
				end += 2;
			}
		}

		NSInteger consumed = end;
		while (consumed < length &&
			(units[consumed] == 0xFE0F || units[consumed] == 0xFE0E))
			consumed++;

		BOOL drawable = scalarCount == 2
			? TGEmojiSystemDrawsPair(scalars[0], scalars[1])
			: TGEmojiSystemDrawsScalar(code);
		if (drawable) {
			i = consumed;
			continue;
		}

		NSString *key = TGEmojiKeyForScalars(scalars, scalarCount);
		BOOL replaceable = TGEmojiHasImage(key);
		if (!replaceable && !TGEmojiScalarIsRemovable(code)) {
			i = consumed;
			continue;
		}

		if (!out)
			out = [[NSMutableAttributedString alloc] init];
		if (i > run)
			[out appendAttributedString:[source attributedSubstringFromRange:
												NSMakeRange(run, i - run)]];
		if (replaceable) {
			NSDictionary *base = [source attributesAtIndex:i effectiveRange:NULL];
			CGFloat ascent = 0, descent = 0;
			TGEmojiMetricsOfAttributes(base, &ascent, &descent);
			NSAttributedString *slot = TGEmojiPlaceholderWithMetrics(key, ascent,
				descent, base);
			if (slot)
				[out appendAttributedString:slot];
		}
		i = consumed;
		run = i;
	}

	if (out && length > run)
		[out appendAttributedString:[source attributedSubstringFromRange:
											NSMakeRange(run, length - run)]];

	if (units != stackUnits)
		free(units);
	return out;
}

static void TGEmojiDrawLines(NSArray *lines, UIFont *font, CGRect rect,
	NSTextAlignment alignment) {
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (!context || !lines.count)
		return;

	CGFloat lineHeight = font.lineHeight;
	CGFloat total = lines.count * lineHeight;
	CGFloat top = rect.origin.y + floorf((rect.size.height - total) / 2);
	if (top < rect.origin.y)
		top = rect.origin.y;

	CGContextSaveGState(context);
	CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
	CGContextTranslateCTM(context, 0, rect.origin.y + rect.size.height);
	CGContextScaleCTM(context, 1, -1);
	CGContextSetTextMatrix(context, CGAffineTransformIdentity);
	CGFloat base = rect.origin.y + rect.size.height;

	for (NSInteger index = 0; index < lines.count; index++) {
		CTLineRef line = (__bridge CTLineRef)[lines objectAtIndex:index];
		CGFloat width = (CGFloat)CTLineGetTypographicBounds(line, NULL, NULL, NULL);
		CGFloat x = rect.origin.x;
		if (alignment == NSTextAlignmentCenter)
			x += floorf((rect.size.width - width) / 2);
		else if (alignment == NSTextAlignmentRight)
			x += rect.size.width - width;
		if (x < rect.origin.x)
			x = rect.origin.x;

		CGFloat baseline = base - (top + index * lineHeight + font.ascender);
		CGContextSetTextPosition(context, x, baseline);
		CTLineDraw(line, context);
		TGEmojiDrawImagesInLine(line, x, baseline);
	}

	CGContextRestoreGState(context);
}

void TGEmojiTextDraw(NSString *text, UIFont *font, UIColor *colour, CGRect rect,
	NSTextAlignment alignment, NSInteger maxLines) {
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (!context || rect.size.width < 1 || rect.size.height < 1)
		return;

	NSMutableArray *paragraphs = [NSMutableArray array];
	if (!TGEmojiWalk(text, font, colour, nil, paragraphs) || !paragraphs.count) {
		[colour set];
		[text drawInRect:rect withFont:font lineBreakMode:NSLineBreakByWordWrapping];
		return;
	}

	CGFloat widest = 0;
	NSDictionary *plain = TGEmojiPlainAttributes(font, colour);
	NSArray *lines = TGEmojiBuildLines(paragraphs, plain, rect.size.width, maxLines, &widest);
	TGEmojiDrawLines(lines, font, rect, alignment);
}

static BOOL TGEmojiAttributedDraw(NSAttributedString *styled, UIFont *font, UIColor *colour,
	CGRect rect, NSTextAlignment alignment, NSInteger maxLines) {
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (!context || !styled.length || rect.size.width < 1 || rect.size.height < 1)
		return NO;

	NSAttributedString *coreText = TGEmojiCoreTextString(styled, font, colour);
	NSMutableArray *paragraphs = [NSMutableArray array];
	if (!TGEmojiWalk(styled.string, font, colour, coreText, paragraphs) || !paragraphs.count)
		return NO;

	CGFloat widest = 0;
	NSDictionary *plain = TGEmojiPlainAttributes(font, colour);
	NSArray *lines = TGEmojiBuildLines(paragraphs, plain, rect.size.width, maxLines, &widest);
	if (!lines.count)
		return NO;

	TGEmojiDrawLines(lines, font, rect, alignment);
	return YES;
}

static UTF32Char TGEmojiFirstScalar(NSString *sample) {
	if (!sample.length)
		return 0;
	unichar high = [sample characterAtIndex:0];
	if (high >= 0xD800 && high <= 0xDBFF && sample.length > 1)
		return ((UTF32Char)(high - 0xD800) << 10) +
			([sample characterAtIndex:1] - 0xDC00) + 0x10000;
	return high;
}

static NSString *TGEmojiProbeVerdict(NSString *sample) {
	NSAttributedString *source = [[NSAttributedString alloc] initWithString:sample];
	if (TGEmojiSubstituteInString(source))
		return @"atlas";
	return TGEmojiSystemDrawsScalar(TGEmojiFirstScalar(sample)) ? @"font" : @"MISSING";
}

void TGEmojiLogHealthOnce(void) {
	static BOOL logged = NO;
	if (logged)
		return;
	logged = YES;

	NSInteger substituted = (unsigned)gTGEmojiPlaceholdersBuilt;
	NSInteger drawn = (unsigned)gTGEmojiImagesDrawn;

	CTFontRef font = TGEmojiSystemFont();
	NSString *face = font ? CFBridgingRelease(CTFontCopyFullName(font)) : nil;
	NSString *directory = TGEmojiDirectory();
	NSUInteger atlas = [[[NSFileManager defaultManager]
		contentsOfDirectoryAtPath:directory
							error:NULL] count];

	NSString *plain = TGEmojiProbeVerdict(@"\U0001F604");
	NSString *zwj = TGEmojiProbeVerdict(
		@"\U0001F468‍\U0001F469‍\U0001F467‍\U0001F466");
	NSString *tone = TGEmojiProbeVerdict(@"\U0001F44D\U0001F3FD");
	NSString *flag = TGEmojiProbeVerdict(@"\U0001F1FA\U0001F1E6");

	NSLog(@"[emoji] font=%@ atlas=%u substituted=%u drawn=%u "
		  @"plain=%@ zwj=%@ tone=%@ flag=%@",
		face ?: @"UNRESOLVED", (unsigned)atlas, substituted, drawn,
		plain, zwj, tone, flag);

	if (!font)
		NSLog(@"[emoji] BROKEN: AppleColorEmoji did not resolve, so every glyph "
			  @"now depends on the %u-image atlas at %@",
			(unsigned)atlas, directory);
	if (!atlas)
		NSLog(@"[emoji] BROKEN: no emoji atlas in the bundle at %@", directory);
	if ([plain isEqualToString:@"MISSING"] || [zwj isEqualToString:@"MISSING"] ||
		[tone isEqualToString:@"MISSING"] || [flag isEqualToString:@"MISSING"])
		NSLog(@"[emoji] BROKEN: the substitution path draws nothing for a probe "
			  @"(plain=%@ zwj=%@ tone=%@ flag=%@)",
			plain, zwj, tone, flag);
}

@implementation TGEmojiLabel

- (NSAttributedString *)emojiStyledText {
	if (![self respondsToSelector:@selector(attributedText)])
		return nil;
	NSAttributedString *styled = self.attributedText;
	if (!styled.length)
		return nil;
	NSRange run = NSMakeRange(0, 0);
	[styled attributesAtIndex:0
		longestEffectiveRange:&run
					  inRange:NSMakeRange(0, styled.length)];
	return run.length < styled.length ? styled : nil;
}

- (NSString *)emojiPlainText {
	NSString *text = self.text;
	if (text.length)
		return text;
	return [self emojiStyledText].string;
}

- (void)setRichLayout:(TGRichTextLayout *)richLayout {
	if (_richLayout == richLayout)
		return;
	_richLayout = richLayout;
	[self setNeedsDisplay];
}

- (void)drawTextInRect:(CGRect)rect {
	if (self.richLayout) {
		[self.richLayout drawInRect:self.bounds];
		TGEmojiLogHealthOnce();
		return;
	}

	NSString *text = [self emojiPlainText];
	if (!TGEmojiTextNeedsSubstitution(text)) {
		[super drawTextInRect:rect];
		TGEmojiLogHealthOnce();
		return;
	}

	UIColor *ink = self.highlighted && self.highlightedTextColor
		? self.highlightedTextColor
		: self.textColor;
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (context)
		CGContextSaveGState(context);
	if (context && self.shadowColor)
		CGContextSetShadowWithColor(context, self.shadowOffset, 0, self.shadowColor.CGColor);

	NSAttributedString *styled = [self emojiStyledText];
	BOOL drawn = styled && TGEmojiAttributedDraw(styled, self.font, ink ?: [UIColor blackColor], self.bounds, self.textAlignment, self.numberOfLines);
	if (!drawn)
		TGEmojiTextDraw(text, self.font, ink ?: [UIColor blackColor], self.bounds,
			self.textAlignment, self.numberOfLines);

	if (context)
		CGContextRestoreGState(context);
	TGEmojiLogHealthOnce();
}

- (CGSize)sizeThatFits:(CGSize)size {
	if (self.richLayout)
		return self.richLayout.size;
	NSString *text = [self emojiPlainText];
	if (!TGEmojiTextNeedsSubstitution(text))
		return [super sizeThatFits:size];
	return TGEmojiTextSize(text, self.font, size, self.lineBreakMode,
		self.numberOfLines);
}

@end

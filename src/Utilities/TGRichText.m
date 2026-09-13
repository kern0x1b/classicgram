#import "TGRichText.h"
#import "TGEmoji.h"

static UIImage * (^sCustomEmojiImageProvider)(long long) = nil;
static void (^sCustomEmojiImageRequester)(long long) = nil;

void TGRichTextSetCustomEmojiImageProvider(UIImage * (^provider)(long long customEmojiId)) {
	sCustomEmojiImageProvider = [provider copy];
}

UIImage *TGRichTextCustomEmojiImage(long long customEmojiId) {
	return sCustomEmojiImageProvider ? sCustomEmojiImageProvider(customEmojiId) : nil;
}

void TGRichTextSetCustomEmojiImageRequester(void (^requester)(long long customEmojiId)) {
	sCustomEmojiImageRequester = [requester copy];
}

void TGRichTextRequestCustomEmojiImage(long long customEmojiId) {
	if (sCustomEmojiImageRequester)
		sCustomEmojiImageRequester(customEmojiId);
}

NSString *const TGRichLinkAttribute = @"TGRichLink";
NSString *const TGRichSpoilerAttribute = @"TGRichSpoiler";
NSString *const TGRichBlockAttribute = @"TGRichBlock";
NSString *const TGRichStrikeAttribute = @"TGRichStrike";
NSString *const TGRichCodeAttribute = @"TGRichCode";
NSString *const TGRichCustomEmojiAttribute = @"TGRichCustomEmoji";

NSString *const TGRichLinkKindKey = @"kind";
NSString *const TGRichLinkValueKey = @"value";

static const CGFloat kBlockLeftInset = 10.0f;
static const CGFloat kBlockRightInset = 8.0f;
static const CGFloat kBlockPadTop = 4.0f;
static const CGFloat kBlockPadBottom = 4.0f;
static const CGFloat kBlockBarWidth = 3.0f;
static const CGFloat kBlockRadius = 4.0f;
static const CGFloat kBlockGap = 4.0f;
static const CGFloat kCodePadX = 3.0f;
static const NSInteger kCollapsedBlockLines = 3;

@implementation TGRichTextPalette

+ (TGRichTextPalette *)paletteWithFont:(UIFont *)font
								colour:(UIColor *)colour
							linkColour:(UIColor *)linkColour
						  accentColour:(UIColor *)accentColour {
	TGRichTextPalette *palette = [[TGRichTextPalette alloc] init];
	palette.font = font ?: [UIFont systemFontOfSize:16];
	palette.textColour = colour ?: [UIColor blackColor];
	palette.linkColour = linkColour ?: [UIColor colorWithRed:0x00 / 255.0f green:0x4b / 255.0f blue:0xad / 255.0f alpha:1.0f];
	palette.accentColour = accentColour ?: palette.linkColour;
	palette.codeBackgroundColour = [UIColor colorWithWhite:0.0f alpha:0.06f];
	palette.underlineLinks = YES;
	return palette;
}

@end

@interface TGRichBlockSpec : NSObject
@property (nonatomic, assign) BOOL code;
@property (nonatomic, copy) NSString *language;
@property (nonatomic, assign) BOOL collapsible;
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, strong) UIColor *tint;
@end

@implementation TGRichBlockSpec
@end

@interface TGRichLineBox : NSObject
@property (nonatomic, strong) id line;
@property (nonatomic, strong) NSAttributedString *source;
@property (nonatomic, assign) CGFloat left;
@property (nonatomic, assign) CGFloat available;
@property (nonatomic, assign) CGFloat top;
@property (nonatomic, assign) CGFloat height;
@property (nonatomic, assign) CGFloat ascent;
@property (nonatomic, assign) CGFloat width;
@property (nonatomic, assign) CGFloat rightLimit;
@property (nonatomic, assign) BOOL rightAligned;
@property (nonatomic, assign) NSUInteger globalOffset;
@property (nonatomic, assign) NSUInteger globalLength;
@end

@implementation TGRichLineBox
@end

@interface TGRichBlockBox : NSObject
@property (nonatomic, assign) CGRect frame;
@property (nonatomic, strong) TGRichBlockSpec *spec;
@property (nonatomic, assign) BOOL collapsed;
@end

@implementation TGRichBlockBox
@end

#pragma mark - fonts

static CTFontRef TGRichCreateFont(UIFont *font, CTFontSymbolicTraits traits) {
	CTFontRef base = CTFontCreateWithName((__bridge CFStringRef)font.fontName,
		font.pointSize, NULL);
	if (!base)
		return NULL;
	if (traits == 0)
		return base;

	CTFontRef shaped = CTFontCreateCopyWithSymbolicTraits(base, font.pointSize, NULL,
		traits, traits);
	if (shaped) {
		CFRelease(base);
		return shaped;
	}

	UIFont *fallback = nil;
	if (traits & kCTFontBoldTrait)
		fallback = [UIFont boldSystemFontOfSize:font.pointSize];
	else if (traits & kCTFontItalicTrait)
		fallback = [UIFont italicSystemFontOfSize:font.pointSize];
	if (!fallback)
		return base;

	CFRelease(base);
	return CTFontCreateWithName((__bridge CFStringRef)fallback.fontName,
		fallback.pointSize, NULL);
}

static CTFontRef TGRichCreateMonoFont(CGFloat size) {
	static NSString *name = nil;
	if (!name) {
		NSArray *candidates = @[ @"Menlo-Regular", @"Courier", @"CourierNewPSMT" ];
		for (NSString *candidate in candidates) {
			if ([UIFont fontWithName:candidate size:12]) {
				name = candidate;
				break;
			}
		}
		if (!name)
			name = @"Courier";
	}
	return CTFontCreateWithName((__bridge CFStringRef)name, size, NULL);
}

#pragma mark - entities

static NSString *TGRichEntityKind(NSDictionary *entity) {
	id kind = entity[@"kind"];
	if (![kind isKindOfClass:NSString.class])
		return @"";
	return [kind lowercaseString];
}

static BOOL TGRichKindIsBlock(NSString *kind) {
	return [kind isEqualToString:@"pre"] || [kind isEqualToString:@"precode"] ||
		[kind isEqualToString:@"blockquote"] ||
		[kind isEqualToString:@"expandableblockquote"];
}

#pragma mark - building

static void TGRichApplyFonts(NSMutableAttributedString *string, uint8_t *mask,
	UIFont *base) {
	NSInteger length = string.length;
	NSInteger start = 0;
	while (start < length) {
		uint8_t flags = mask[start];
		NSInteger end = start + 1;
		while (end < length && mask[end] == flags)
			end++;
		if (flags) {
			CTFontRef font = NULL;
			if (flags & 4) {
				font = TGRichCreateMonoFont(base.pointSize - 1);
			} else {
				CTFontSymbolicTraits traits = 0;
				if (flags & 1)
					traits |= kCTFontBoldTrait;
				if (flags & 2)
					traits |= kCTFontItalicTrait;
				font = TGRichCreateFont(base, traits);
			}
			if (font) {
				[string addAttribute:(__bridge NSString *)kCTFontAttributeName
							   value:CFBridgingRelease(font)
							   range:NSMakeRange(start, end - start)];
			}
		}
		start = end;
	}
}

static NSDictionary *TGRichLinkValue(NSString *kind, NSString *value) {
	return @{TGRichLinkKindKey : kind ?: @"", TGRichLinkValueKey : value ?: @""};
}

NSAttributedString *TGRichTextBuild(NSString *text, NSArray *entities,
	TGRichTextPalette *palette,
	BOOL spoilersRevealed) {
	if (!text.length)
		return nil;
	if (!palette)
		palette = [TGRichTextPalette paletteWithFont:nil colour:nil linkColour:nil
										accentColour:nil];

	CTFontRef baseFont = TGRichCreateFont(palette.font, 0);
	NSMutableDictionary *baseAttributes = [NSMutableDictionary dictionary];
	if (baseFont) {
		[baseAttributes setObject:CFBridgingRelease(baseFont)
						   forKey:(__bridge NSString *)kCTFontAttributeName];
	}
	[baseAttributes setObject:(__bridge id)palette.textColour.CGColor
					   forKey:(__bridge NSString *)kCTForegroundColorAttributeName];

	NSMutableAttributedString *string =
		[[NSMutableAttributedString alloc] initWithString:text
											   attributes:baseAttributes];
	NSInteger length = string.length;
	if (!entities.count)
		return string;

	uint8_t *mask = calloc(length ?: 1, sizeof(uint8_t));
	if (!mask)
		return string;

	NSInteger blockIndex = 0;
	NSNumber *underline = @(kCTUnderlineStyleSingle);
	NSMutableArray *hidden = [NSMutableArray array];

	for (id item in entities) {
		if (![item isKindOfClass:NSDictionary.class])
			continue;
		NSDictionary *entity = item;
		NSInteger offset = [entity[@"offset"] integerValue];
		NSInteger span = [entity[@"length"] integerValue];
		if (offset < 0 || span <= 0 || (NSUInteger)offset >= length)
			continue;
		if ((NSUInteger)(offset + span) > length)
			span = (NSInteger)length - offset;
		NSRange range = NSMakeRange((NSUInteger)offset, (NSUInteger)span);
		NSString *kind = TGRichEntityKind(entity);

		if ([kind isEqualToString:@"bold"]) {
			for (NSInteger i = range.location; i < NSMaxRange(range); i++)
				mask[i] |= 1;
			continue;
		}
		if ([kind isEqualToString:@"italic"]) {
			for (NSInteger i = range.location; i < NSMaxRange(range); i++)
				mask[i] |= 2;
			continue;
		}
		if ([kind isEqualToString:@"code"]) {
			for (NSInteger i = range.location; i < NSMaxRange(range); i++)
				mask[i] |= 4;
			[string addAttribute:TGRichCodeAttribute
						   value:(palette.codeBackgroundColour
										 ?: [UIColor colorWithWhite:0 alpha:0.06f])
				range:range];
			continue;
		}
		if ([kind isEqualToString:@"underline"]) {
			[string addAttribute:(__bridge NSString *)kCTUnderlineStyleAttributeName
						   value:underline
						   range:range];
			continue;
		}
		if ([kind isEqualToString:@"strikethrough"]) {
			[string addAttribute:TGRichStrikeAttribute value:@YES range:range];
			continue;
		}
		if ([kind isEqualToString:@"spoiler"]) {
			[string addAttribute:TGRichSpoilerAttribute value:@YES range:range];
			if (!spoilersRevealed)
				[hidden addObject:[NSValue valueWithRange:range]];
			continue;
		}
		if ([kind isEqualToString:@"customemoji"]) {
			long long customEmojiId = [entity[@"customEmojiId"] longLongValue];
			if (customEmojiId != 0) {
				[string addAttribute:TGRichCustomEmojiAttribute
							   value:@(customEmojiId)
							   range:range];
			}
			continue;
		}
		if (TGRichKindIsBlock(kind)) {
			TGRichBlockSpec *spec = [[TGRichBlockSpec alloc] init];
			spec.code = [kind isEqualToString:@"pre"] ||
				[kind isEqualToString:@"precode"];
			spec.language = [entity[@"language"] isKindOfClass:NSString.class]
				? entity[@"language"]
				: nil;
			spec.collapsible = [kind isEqualToString:@"expandableblockquote"];
			spec.index = blockIndex++;
			spec.tint = spec.code ? palette.accentColour : palette.accentColour;
			if (spec.code) {
				for (NSInteger i = range.location; i < NSMaxRange(range); i++)
					mask[i] |= 4;
			}
			[string addAttribute:TGRichBlockAttribute value:spec range:range];
			continue;
		}

		NSString *linkKind = nil;
		NSString *linkValue = nil;
		if ([kind isEqualToString:@"url"]) {
			linkKind = @"url";
			linkValue = [text substringWithRange:range];
		} else if ([kind isEqualToString:@"texturl"]) {
			linkKind = @"url";
			linkValue = [entity[@"url"] isKindOfClass:NSString.class]
				? entity[@"url"]
				: nil;
		} else if ([kind isEqualToString:@"emailaddress"]) {
			linkKind = @"url";
			linkValue = [@"mailto:" stringByAppendingString:
					[text substringWithRange:range]];
		} else if ([kind isEqualToString:@"phonenumber"]) {
			linkKind = @"phone";
			linkValue = [text substringWithRange:range];
		} else if ([kind isEqualToString:@"mention"]) {
			linkKind = @"mention";
			linkValue = [text substringWithRange:range];
		} else if ([kind isEqualToString:@"mentionname"]) {
			linkKind = @"user";
			linkValue = [entity[@"userId"] stringValue];
		} else if ([kind isEqualToString:@"hashtag"] ||
			[kind isEqualToString:@"cashtag"]) {
			linkKind = @"hashtag";
			linkValue = [text substringWithRange:range];
		} else if ([kind isEqualToString:@"botcommand"]) {
			linkKind = @"command";
			linkValue = [text substringWithRange:range];
		} else if ([kind isEqualToString:@"bankcardnumber"]) {
			linkKind = @"bankcard";
			linkValue = [text substringWithRange:range];
		} else if ([kind isEqualToString:@"mediatimestamp"]) {
			linkKind = @"timestamp";
			linkValue = [entity[@"timestamp"] stringValue];
		} else if ([kind isEqualToString:@"datetime"]) {
			NSNumber *unixTime = [entity[@"unixTime"] isKindOfClass:NSNumber.class]
				? entity[@"unixTime"]
				: nil;
			if (unixTime.longLongValue > 0) {
				linkKind = @"date";
				linkValue = [unixTime stringValue];
			}
		}

		if (!linkKind.length || !linkValue.length)
			continue;

		NSDictionary *linkDict = TGRichLinkValue(linkKind, linkValue);
		if ([linkKind isEqualToString:@"date"]) {
			NSMutableDictionary *withText = [linkDict mutableCopy];
			withText[@"text"] = [text substringWithRange:range];
			linkDict = [withText copy];
		}

		[string addAttribute:TGRichLinkAttribute
					   value:linkDict
					   range:range];
		[string addAttribute:(__bridge NSString *)kCTForegroundColorAttributeName
					   value:(__bridge id)palette.linkColour.CGColor
					   range:range];
		if (palette.underlineLinks) {
			[string addAttribute:(__bridge NSString *)kCTUnderlineStyleAttributeName
						   value:underline
						   range:range];
		}
	}

	for (NSValue *box in hidden) {
		[string addAttribute:(__bridge NSString *)kCTForegroundColorAttributeName
					   value:(__bridge id)[UIColor clearColor].CGColor
					   range:[box rangeValue]];
		[string removeAttribute:(__bridge NSString *)kCTUnderlineStyleAttributeName
						  range:[box rangeValue]];
	}

	TGRichApplyFonts(string, mask, palette.font);
	free(mask);
	return string;
}

#pragma mark - layout

@implementation TGRichTextLayout {
	NSAttributedString *_text;
	NSMutableArray *_lines;
	NSMutableArray *_blocks;
	CGSize _size;
	NSTextAlignment _alignment;
	BOOL _carriesSpoilers;
	BOOL _carriesCollapsedBlocks;
	UIColor *_codeBackground;
	UIColor *_defaultInk;
}

@synthesize size = _size;
@synthesize carriesSpoilers = _carriesSpoilers;
@synthesize carriesCollapsedBlocks = _carriesCollapsedBlocks;

static NSAttributedString *TGRichSubstituteEmoji(NSAttributedString *source) {
	if (!source.length)
		return source;

	NSMutableAttributedString *out = nil;
	NSInteger index = 0;
	NSInteger length = source.length;
	while (index < length) {
		NSRange run = NSMakeRange(index, 0);
		id spoiler = [source attribute:TGRichSpoilerAttribute atIndex:index
				 longestEffectiveRange:&run
							   inRange:NSMakeRange(index, length - index)];
		if (run.length == 0)
			run = NSMakeRange(index, 1);
		NSAttributedString *piece = [source attributedSubstringFromRange:run];
		NSAttributedString *swapped = spoiler ? nil : TGEmojiSubstituteInString(piece);
		if (swapped && !out) {
			out = [[NSMutableAttributedString alloc] init];
			if (run.location > 0) {
				NSAttributedString *prefix = [source attributedSubstringFromRange:NSMakeRange(0, run.location)];
				[out appendAttributedString:prefix];
			}
		}
		if (out)
			[out appendAttributedString:swapped ?: piece];
		index = NSMaxRange(run);
	}
	return out ?: source;
}

static void TGRichDrawCustomEmojiInLine(CTLineRef line, CGFloat left, CGFloat baseline) {
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (!context || !line)
		return;

	CFArrayRef runs = CTLineGetGlyphRuns(line);
	CFIndex runCount = runs ? CFArrayGetCount(runs) : 0;
	for (CFIndex slot = 0; slot < runCount; slot++) {
		CTRunRef glyphRun = (CTRunRef)CFArrayGetValueAtIndex(runs, slot);
		NSDictionary *attributes = (__bridge NSDictionary *)CTRunGetAttributes(glyphRun);
		NSNumber *idValue = attributes[TGRichCustomEmojiAttribute];
		if (!idValue)
			continue;

		long long customEmojiId = [idValue longLongValue];
		UIImage *image = TGRichTextCustomEmojiImage(customEmojiId);
		if (!image) {
			TGRichTextRequestCustomEmojiImage(customEmojiId);
			continue;
		}

		CFIndex glyphCount = CTRunGetGlyphCount(glyphRun);
		if (glyphCount < 1)
			continue;

		CGPoint position = CGPointZero;
		CTRunGetPositions(glyphRun, CFRangeMake(0, 1), &position);
		CGFloat ascent = 0, descent = 0;
		CGFloat advance = (CGFloat)CTRunGetTypographicBounds(glyphRun,
			CFRangeMake(0, 1), &ascent, &descent, NULL);
		CGRect box = CGRectMake(left + position.x, baseline - descent, advance,
			ascent + descent);
		CGContextDrawImage(context, box, image.CGImage);
	}
}

static CGFloat TGRichLineAdvance(CTLineRef line, UIFont *base, CGFloat *ascentOut) {
	CGFloat ascent = 0, descent = 0, leading = 0;
	CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
	if (ascent < base.ascender)
		ascent = base.ascender;
	if (descent < -base.descender)
		descent = -base.descender;
	if (ascentOut)
		*ascentOut = ascent;
	CGFloat advance = ceilf(ascent + descent);
	return MAX(advance, base.lineHeight);
}

- (UIFont *)baseFontOf:(NSAttributedString *)text {
	if (!text.length)
		return [UIFont systemFontOfSize:16];
	id value = [text attribute:(__bridge NSString *)kCTFontAttributeName atIndex:0
				effectiveRange:NULL];
	if (!value)
		return [UIFont systemFontOfSize:16];
	CTFontRef font = (__bridge CTFontRef)value;
	NSString *name = CFBridgingRelease(CTFontCopyPostScriptName(font));
	UIFont *shaped = [UIFont fontWithName:name size:CTFontGetSize(font)];
	return shaped ?: [UIFont systemFontOfSize:CTFontGetSize(font)];
}

- (void)appendParagraph:(NSAttributedString *)paragraph
					atX:(CGFloat)left
			  available:(CGFloat)available
			   baseFont:(UIFont *)base
			 blockLimit:(NSInteger)blockLimit
			   maxLines:(NSInteger)maxLines
				 cursor:(CGFloat *)cursor
			 lineBudget:(NSInteger *)lineBudget
			  laidLines:(NSInteger *)laidLines
			 globalBase:(NSUInteger)globalBase {
	if (available < 8)
		available = 8;

	CFIndex length = (CFIndex)paragraph.length;
	if (length == 0) {
		CTLineRef empty = CTLineCreateWithAttributedString(
			(__bridge CFAttributedStringRef)paragraph);
		if (!empty)
			return;
		TGRichLineBox *box = [[TGRichLineBox alloc] init];
		box.line = CFBridgingRelease(empty);
		box.source = paragraph;
		box.left = left;
		box.available = available;
		box.top = *cursor;
		box.ascent = base.ascender;
		box.height = base.lineHeight;
		box.width = 0;
		box.rightAligned = (_alignment == NSTextAlignmentRight);
		box.globalOffset = globalBase;
		box.globalLength = 0;
		[_lines addObject:box];
		*cursor += box.height;
		(*laidLines)++;
		if (*lineBudget > 0)
			(*lineBudget)--;
		return;
	}

	CTTypesetterRef setter = CTTypesetterCreateWithAttributedString(
		(__bridge CFAttributedStringRef)paragraph);
	if (!setter)
		return;

	NSMutableDictionary *tokenAttributes =
		[[paragraph attributesAtIndex:0 effectiveRange:NULL] mutableCopy];
	[tokenAttributes removeObjectForKey:
			(__bridge NSString *)kCTRunDelegateAttributeName];
	[tokenAttributes removeObjectForKey:@"TGEmojiKey"];
	[tokenAttributes removeObjectForKey:TGRichSpoilerAttribute];
	[tokenAttributes removeObjectForKey:TGRichCodeAttribute];
	[tokenAttributes setObject:(__bridge id)_defaultInk.CGColor
						forKey:(__bridge NSString *)kCTForegroundColorAttributeName];
	NSAttributedString *ellipsis = [[NSAttributedString alloc]
		initWithString:@"…"
			attributes:tokenAttributes];

	CFIndex start = 0;
	while (start < length) {
		BOOL lastAllowed = NO;
		if (maxLines > 0 && *lineBudget <= 1)
			lastAllowed = YES;
		if (blockLimit > 0 && *laidLines >= blockLimit - 1)
			lastAllowed = YES;

		CFIndex lineStart = start;
		CFIndex consumedCount = 0;
		CTLineRef line = NULL;
		if (lastAllowed) {
			CTLineRef whole = CTTypesetterCreateLine(setter,
				CFRangeMake(start, length - start));
			CFIndex fits = CTTypesetterSuggestLineBreak(setter, start, available);
			if (whole && fits < length - start) {
				CTLineRef token = CTLineCreateWithAttributedString(
					(__bridge CFAttributedStringRef)ellipsis);
				if (token) {
					line = CTLineCreateTruncatedLine(whole, available,
						kCTLineTruncationEnd, token);
					CFRelease(token);
				}
			}
			if (!line && whole)
				line = (CTLineRef)CFRetain(whole);
			if (whole)
				CFRelease(whole);
			consumedCount = length - lineStart;
			start = length;
		} else {
			CFIndex count = CTTypesetterSuggestLineBreak(setter, start, available);
			if (count < 1)
				break;
			line = CTTypesetterCreateLine(setter, CFRangeMake(start, count));
			consumedCount = count;
			start += count;
		}
		if (!line)
			break;

		CGFloat ascent = 0;
		CGFloat advance = TGRichLineAdvance(line, base, &ascent);
		TGRichLineBox *box = [[TGRichLineBox alloc] init];
		box.line = CFBridgingRelease(line);
		box.source = paragraph;
		box.left = left;
		box.available = available;
		box.top = *cursor;
		box.ascent = ascent;
		box.height = advance;
		box.width = (CGFloat)CTLineGetTypographicBounds(
			(__bridge CTLineRef)box.line, NULL, NULL, NULL);
		box.rightAligned = (_alignment == NSTextAlignmentRight);
		box.globalOffset = globalBase + (NSUInteger)lineStart;
		box.globalLength = (NSUInteger)consumedCount;
		[_lines addObject:box];
		*cursor += advance;
		(*laidLines)++;
		if (*lineBudget > 0)
			(*lineBudget)--;

		if (maxLines > 0 && *lineBudget <= 0)
			break;
		if (blockLimit > 0 && *laidLines >= blockLimit)
			break;
	}
	CFRelease(setter);
}

- (void)appendSegment:(NSAttributedString *)segment
				  atX:(CGFloat)left
			available:(CGFloat)available
			 baseFont:(UIFont *)base
		   blockLimit:(NSInteger)blockLimit
			 maxLines:(NSInteger)maxLines
			   cursor:(CGFloat *)cursor
		   lineBudget:(NSInteger *)lineBudget
		   globalBase:(NSUInteger)globalBase {
	NSString *plain = segment.string;
	NSInteger length = plain.length;
	NSInteger start = 0;
	NSInteger laid = 0;

	while (start <= length) {
		NSRange search = NSMakeRange(start, length - start);
		NSRange newline = [plain rangeOfString:@"\n" options:0 range:search];
		NSInteger end = (newline.location == NSNotFound) ? length : newline.location;
		NSAttributedString *paragraph = [segment attributedSubstringFromRange:
				NSMakeRange(start, end - start)];
		[self appendParagraph:paragraph atX:left available:available baseFont:base
				   blockLimit:blockLimit
					 maxLines:maxLines
					   cursor:cursor
				   lineBudget:lineBudget
					laidLines:&laid
				   globalBase:globalBase + start];

		if (maxLines > 0 && *lineBudget <= 0)
			return;
		if (blockLimit > 0 && laid >= blockLimit)
			return;
		if (newline.location == NSNotFound)
			return;
		start = newline.location + 1;
	}
}

+ (TGRichTextLayout *)layoutWithText:(NSAttributedString *)text
							   width:(CGFloat)width
							maxLines:(NSInteger)maxLines
						   alignment:(NSTextAlignment)alignment
					  expandedBlocks:(NSSet *)expandedBlocks {
	if (!text.length || width < 1)
		return nil;
	TGRichTextLayout *layout = [[TGRichTextLayout alloc] init];
	[layout buildWithText:text width:width maxLines:maxLines alignment:alignment
		   expandedBlocks:expandedBlocks];
	return layout;
}

- (void)buildWithText:(NSAttributedString *)text
				width:(CGFloat)width
			 maxLines:(NSInteger)maxLines
			alignment:(NSTextAlignment)alignment
	   expandedBlocks:(NSSet *)expandedBlocks {
	_alignment = alignment;
	_lines = [NSMutableArray array];
	_blocks = [NSMutableArray array];
	_codeBackground = [UIColor colorWithWhite:0.0f alpha:0.06f];
	_text = TGRichSubstituteEmoji(text);
	_defaultInk = [self opaqueInkOf:_text];
	_carriesSpoilers = [self stringCarries:TGRichSpoilerAttribute in:_text];

	UIFont *base = [self baseFontOf:_text];
	CGFloat cursor = 0;
	CGFloat rightMost = 0;
	NSInteger budget = maxLines;
	NSInteger index = 0;
	NSInteger length = _text.length;

	while (index < length) {
		if (maxLines > 0 && budget <= 0)
			break;

		NSRange run = NSMakeRange(index, 0);
		TGRichBlockSpec *spec = [_text attribute:TGRichBlockAttribute atIndex:index
						   longestEffectiveRange:&run
										 inRange:NSMakeRange(index, length - index)];
		if (run.length == 0)
			run = NSMakeRange(index, 1);

		NSRange trimmed = run;
		BOOL blockFollows = NSMaxRange(run) < length &&
			[_text attribute:TGRichBlockAttribute atIndex:NSMaxRange(run)
				effectiveRange:NULL] != nil;
		while (trimmed.length > 0 && (spec || blockFollows || _blocks.count) &&
			[_text.string characterAtIndex:NSMaxRange(trimmed) - 1] == '\n')
			trimmed.length--;
		while (trimmed.length > 0 && (spec || _blocks.count) &&
			[_text.string characterAtIndex:trimmed.location] == '\n') {
			trimmed.location++;
			trimmed.length--;
		}
		NSAttributedString *segment = [_text attributedSubstringFromRange:trimmed];
		if (!segment.length && (spec || blockFollows || _blocks.count)) {
			index = NSMaxRange(run);
			continue;
		}

		if (!spec) {
			NSInteger before = _lines.count;
			[self appendSegment:segment atX:0 available:width baseFont:base
					 blockLimit:0
					   maxLines:maxLines
						 cursor:&cursor
					 lineBudget:&budget
					 globalBase:trimmed.location];
			for (NSInteger i = before; i < _lines.count; i++) {
				TGRichLineBox *box = [_lines objectAtIndex:i];
				rightMost = MAX(rightMost, box.left + ceilf(box.width));
			}
			index = NSMaxRange(run);
			continue;
		}

		BOOL collapsed = spec.collapsible &&
			![expandedBlocks containsObject:@(spec.index)];
		if (collapsed)
			_carriesCollapsedBlocks = YES;

		CGFloat blockTop = cursor + (_lines.count ? kBlockGap : 0);
		cursor = blockTop + kBlockPadTop;
		CGFloat inner = width - kBlockLeftInset - kBlockRightInset;
		NSInteger before = _lines.count;

		if (spec.code && spec.language.length) {
			CTFontRef titleFont = TGRichCreateFont(
				[UIFont boldSystemFontOfSize:floorf(base.pointSize * 0.8f)], 0);
			NSMutableDictionary *titleAttributes = [NSMutableDictionary dictionary];
			if (titleFont) {
				[titleAttributes setObject:CFBridgingRelease(titleFont)
									forKey:(__bridge NSString *)kCTFontAttributeName];
			}
			[titleAttributes setObject:(__bridge id)spec.tint.CGColor
								forKey:(__bridge NSString *)kCTForegroundColorAttributeName];
			NSAttributedString *title = [[NSAttributedString alloc]
				initWithString:[spec.language capitalizedString]
					attributes:titleAttributes];
			NSInteger spare = 0;
			NSInteger titleBudget = 1;
			[self appendParagraph:title atX:kBlockLeftInset available:inner
						 baseFont:base
					   blockLimit:0
						 maxLines:1
						   cursor:&cursor
					   lineBudget:&titleBudget
						laidLines:&spare
					   globalBase:trimmed.location];
		}

		[self appendSegment:segment atX:kBlockLeftInset available:inner baseFont:base
				 blockLimit:(collapsed ? kCollapsedBlockLines : 0)maxLines:maxLines
					 cursor:&cursor
				 lineBudget:&budget
				 globalBase:trimmed.location];

		CGFloat blockRight = kBlockLeftInset + 24;
		for (NSInteger i = before; i < _lines.count; i++) {
			TGRichLineBox *box = [_lines objectAtIndex:i];
			blockRight = MAX(blockRight, box.left + ceilf(box.width));
		}
		blockRight = MIN(blockRight + kBlockRightInset, width);
		for (NSInteger i = before; i < _lines.count; i++)
			((TGRichLineBox *)[_lines objectAtIndex:i]).rightLimit =
				blockRight - kBlockRightInset;
		cursor += kBlockPadBottom;

		TGRichBlockBox *blockBox = [[TGRichBlockBox alloc] init];
		blockBox.spec = spec;
		blockBox.collapsed = collapsed;
		blockBox.frame = CGRectMake(0, blockTop, blockRight, cursor - blockTop);
		[_blocks addObject:blockBox];
		rightMost = MAX(rightMost, blockRight);

		cursor += kBlockGap;
		index = NSMaxRange(run);
	}

	if (_blocks.count && _lines.count) {
		TGRichBlockBox *last = [_blocks lastObject];
		if (fabsf(CGRectGetMaxY(last.frame) + kBlockGap - cursor) < 0.01f)
			cursor -= kBlockGap;
	}

	_size = CGSizeMake(ceilf(MIN(rightMost, width)), ceilf(cursor));

	for (TGRichLineBox *box in _lines)
		if (box.rightLimit < 0.5f)
			box.rightLimit = _size.width;
}

- (BOOL)stringCarries:(NSString *)attribute in:(NSAttributedString *)text {
	NSInteger index = 0;
	while (index < text.length) {
		NSRange run = NSMakeRange(index, 0);
		id value = [text attribute:attribute atIndex:index
			 longestEffectiveRange:&run
						   inRange:NSMakeRange(index, text.length - index)];
		if (value)
			return YES;
		index = run.length ? NSMaxRange(run) : index + 1;
	}
	return NO;
}

- (UIColor *)opaqueInkOf:(NSAttributedString *)text {
	NSInteger index = 0;
	while (index < text.length) {
		NSRange run = NSMakeRange(index, 0);
		id value = [text attribute:(__bridge NSString *)kCTForegroundColorAttributeName
						   atIndex:index
			 longestEffectiveRange:&run
						   inRange:NSMakeRange(index, text.length - index)];
		if (value && CGColorGetAlpha((__bridge CGColorRef)value) > 0.05f)
			return [UIColor colorWithCGColor:(__bridge CGColorRef)value];
		index = run.length ? NSMaxRange(run) : index + 1;
	}
	return [UIColor darkGrayColor];
}

#pragma mark - drawing

- (CGFloat)shiftForRect:(CGRect)rect {
	if (_alignment != NSTextAlignmentRight)
		return 0;
	return MAX(0.0f, rect.size.width - _size.width);
}

- (CGFloat)verticalSlackIn:(CGRect)rect {
	return floorf(MAX(0.0f, rect.size.height - _size.height) / 2);
}

- (CGFloat)xOfLine:(TGRichLineBox *)box shift:(CGFloat)shift {
	if (box.rightAligned) {
		CGFloat limit = box.rightLimit > 0.5f ? box.rightLimit
											  : box.left + box.available;
		return shift + MAX(box.left, limit - box.width);
	}
	return shift + box.left;
}

- (void)enumerateRunsOf:(TGRichLineBox *)box
			  attribute:(NSString *)attribute
				  shift:(CGFloat)shift
				  block:(void (^)(CGRect rect, NSRange range))handler {
	CTLineRef line = (__bridge CTLineRef)box.line;
	if (!line)
		return;
	CFRange span = CTLineGetStringRange(line);
	if (span.length <= 0)
		return;

	NSInteger limit = box.source.length;
	NSInteger start = (NSUInteger)span.location;
	NSInteger end = MIN(limit, (NSUInteger)(span.location + span.length));
	CGFloat originX = [self xOfLine:box shift:shift];

	while (start < end) {
		NSRange run = NSMakeRange(start, 0);
		id value = [box.source attribute:attribute atIndex:start
				   longestEffectiveRange:&run
								 inRange:NSMakeRange(start, end - start)];
		if (run.length == 0)
			run = NSMakeRange(start, 1);
		if (value) {
			CGFloat from = CTLineGetOffsetForStringIndex(line, (CFIndex)run.location,
				NULL);
			CGFloat to = CTLineGetOffsetForStringIndex(line,
				(CFIndex)NSMaxRange(run), NULL);
			if (to < from) {
				CGFloat swap = from;
				from = to;
				to = swap;
			}
			handler(CGRectMake(originX + from, box.top, to - from, box.height), run);
		}
		start = NSMaxRange(run);
	}
}

- (UIColor *)inkOf:(TGRichLineBox *)box at:(NSUInteger)index {
	if (index >= box.source.length)
		return _defaultInk;
	id value = [box.source attribute:(__bridge NSString *)kCTForegroundColorAttributeName
							 atIndex:index
					  effectiveRange:NULL];
	if (!value)
		return _defaultInk;
	CGColorRef colour = (__bridge CGColorRef)value;
	if (CGColorGetAlpha(colour) < 0.05f)
		return _defaultInk;
	return [UIColor colorWithCGColor:colour] ?: _defaultInk;
}

- (BOOL)rangeIsHidden:(NSRange)range in:(TGRichLineBox *)box {
	if (range.location >= box.source.length)
		return NO;
	id value = [box.source attribute:(__bridge NSString *)kCTForegroundColorAttributeName
							 atIndex:range.location
					  effectiveRange:NULL];
	if (!value)
		return NO;
	return CGColorGetAlpha((__bridge CGColorRef)value) < 0.05f;
}

- (void)drawBlockBackgroundsWithShift:(CGFloat)shift {
	CGContextRef context = UIGraphicsGetCurrentContext();
	for (TGRichBlockBox *box in _blocks) {
		CGRect frame = CGRectOffset(box.frame, shift, 0);
		UIColor *tint = box.spec.tint ?: [UIColor grayColor];

		CGContextSetFillColorWithColor(context,
			[tint colorWithAlphaComponent:0.1f].CGColor);
		CGContextAddPath(context,
			[UIBezierPath bezierPathWithRoundedRect:frame
									   cornerRadius:kBlockRadius]
				.CGPath);
		CGContextFillPath(context);

		CGContextSetFillColorWithColor(context, tint.CGColor);
		CGContextAddPath(context,
			[UIBezierPath bezierPathWithRoundedRect:
					CGRectMake(frame.origin.x, frame.origin.y, kBlockBarWidth,
						frame.size.height)
									   cornerRadius:kBlockBarWidth / 2]
				.CGPath);
		CGContextFillPath(context);

		if (box.spec.collapsible)
			[self drawChevronInBlock:frame collapsed:box.collapsed tint:tint];
		else if (!box.spec.code)
			[self drawQuoteMarkInBlock:frame tint:tint];
	}
}

- (void)drawQuoteMarkInBlock:(CGRect)frame tint:(UIColor *)tint {
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGFloat right = CGRectGetMaxX(frame) - 5;
	CGFloat top = frame.origin.y + 5;
	CGContextSetFillColorWithColor(context, tint.CGColor);
	for (NSInteger i = 0; i < 2; i++) {
		CGFloat x = right - 7 + i * 4;
		CGContextFillRect(context, CGRectMake(x, top, 1.5f, 5));
		CGContextFillRect(context, CGRectMake(x, top + 4, 1.5f, 2));
	}
}

- (void)drawChevronInBlock:(CGRect)frame collapsed:(BOOL)collapsed
					  tint:(UIColor *)tint {
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGFloat right = CGRectGetMaxX(frame) - 6;
	CGFloat middle = CGRectGetMaxY(frame) - 8;
	CGContextSaveGState(context);
	CGContextSetStrokeColorWithColor(context, tint.CGColor);
	CGContextSetLineWidth(context, 1.5f);
	CGContextSetLineCap(context, kCGLineCapRound);
	CGContextSetLineJoin(context, kCGLineJoinRound);
	CGFloat rise = collapsed ? 3.0f : -3.0f;
	CGContextMoveToPoint(context, right - 8, middle);
	CGContextAddLineToPoint(context, right - 4, middle + rise);
	CGContextAddLineToPoint(context, right, middle);
	CGContextStrokePath(context);
	CGContextRestoreGState(context);
}

- (void)drawSpoilerCover:(CGRect)rect tint:(UIColor *)tint {
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSaveGState(context);
	CGContextAddPath(context, [UIBezierPath bezierPathWithRoundedRect:CGRectInset(rect, -1, -1) cornerRadius:3].CGPath);
	CGContextClip(context);
	CGContextSetFillColorWithColor(context,
		[tint colorWithAlphaComponent:0.14f].CGColor);
	CGContextFillRect(context, CGRectInset(rect, -1, -1));

	CGContextSetFillColorWithColor(context,
		[tint colorWithAlphaComponent:0.6f].CGColor);
	unsigned int seed = (unsigned int)(rect.origin.x * 7 + rect.origin.y * 13) | 1;
	for (CGFloat y = rect.origin.y + 1; y < CGRectGetMaxY(rect) - 1; y += 3.0f) {
		for (CGFloat x = rect.origin.x; x < CGRectGetMaxX(rect); x += 3.0f) {
			seed = seed * 1103515245u + 12345u;
			CGFloat jitterX = ((seed >> 16) & 3) * 0.5f;
			seed = seed * 1103515245u + 12345u;
			CGFloat jitterY = ((seed >> 16) & 3) * 0.5f;
			CGContextFillRect(context,
				CGRectMake(x + jitterX, y + jitterY, 1.0f, 1.0f));
		}
	}
	CGContextRestoreGState(context);
}

- (void)drawInRect:(CGRect)rect {
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (!context || !_lines.count)
		return;

	CGFloat shift = [self shiftForRect:rect];
	CGContextSaveGState(context);
	CGContextTranslateCTM(context, rect.origin.x,
		rect.origin.y + [self verticalSlackIn:rect]);

	[self drawBlockBackgroundsWithShift:shift];

	for (TGRichLineBox *box in _lines) {
		[self enumerateRunsOf:box attribute:TGRichCodeAttribute shift:shift
						block:^(CGRect runRect, NSRange range) {
							id plate = [box.source attribute:TGRichCodeAttribute atIndex:range.location effectiveRange:NULL];
							UIColor *fill = [plate isKindOfClass:UIColor.class] ? plate : _codeBackground;
							CGContextSetFillColorWithColor(context, fill.CGColor);
							CGContextAddPath(context, [UIBezierPath bezierPathWithRoundedRect:CGRectMake(runRect.origin.x - kCodePadX, runRect.origin.y + 1, runRect.size.width + 2 * kCodePadX, runRect.size.height - 2) cornerRadius:3].CGPath);
							CGContextFillPath(context);
						}];
	}

	CGContextSaveGState(context);
	CGContextSetTextMatrix(context, CGAffineTransformIdentity);
	CGContextTranslateCTM(context, 0, _size.height);
	CGContextScaleCTM(context, 1, -1);
	for (TGRichLineBox *box in _lines) {
		CTLineRef line = (__bridge CTLineRef)box.line;
		if (!line)
			continue;
		CGFloat x = [self xOfLine:box shift:shift];
		CGFloat baseline = _size.height - (box.top + box.ascent);
		CGContextSetTextPosition(context, x, baseline);
		CTLineDraw(line, context);
		TGEmojiDrawImagesInLine(line, x, baseline);
		TGRichDrawCustomEmojiInLine(line, x, baseline);
	}
	CGContextRestoreGState(context);

	for (TGRichLineBox *box in _lines) {
		[self enumerateRunsOf:box attribute:TGRichStrikeAttribute shift:shift
						block:^(CGRect runRect, NSRange range) {
							CGFloat y = floorf(runRect.origin.y + box.ascent * 0.68f) + 0.5f;
							CGContextSetStrokeColorWithColor(context,
								[self inkOf:box at:range.location].CGColor);
							CGContextSetLineWidth(context, 1.0f);
							CGContextMoveToPoint(context, runRect.origin.x, y);
							CGContextAddLineToPoint(context, CGRectGetMaxX(runRect), y);
							CGContextStrokePath(context);
						}];
	}

	for (TGRichLineBox *box in _lines) {
		[self enumerateRunsOf:box attribute:TGRichSpoilerAttribute shift:shift
						block:^(CGRect runRect, NSRange range) {
							if ([self rangeIsHidden:range in:box])
								[self drawSpoilerCover:runRect tint:_defaultInk];
						}];
	}

	CGContextRestoreGState(context);
}

#pragma mark - hit testing

- (BOOL)lineBox:(TGRichLineBox **)outBox stringIndex:(NSUInteger *)outIndex
		atPoint:(CGPoint)point inRect:(CGRect)rect {
	CGFloat shift = [self shiftForRect:rect];
	CGPoint local = CGPointMake(point.x - rect.origin.x,
		point.y - rect.origin.y - [self verticalSlackIn:rect]);

	for (TGRichLineBox *box in _lines) {
		if (local.y < box.top - 2 || local.y > box.top + box.height + 2)
			continue;
		CGFloat x = [self xOfLine:box shift:shift];
		if (local.x < x - 4 || local.x > x + box.width + 4)
			continue;
		CTLineRef line = (__bridge CTLineRef)box.line;
		CFIndex index = CTLineGetStringIndexForPosition(line,
			CGPointMake(local.x - x, 0));
		if (index < 0 || (NSUInteger)index >= box.source.length)
			continue;
		if (outBox)
			*outBox = box;
		if (outIndex)
			*outIndex = (NSUInteger)index;
		return YES;
	}
	return NO;
}

- (id)attribute:(NSString *)attribute atPoint:(CGPoint)point inRect:(CGRect)rect {
	TGRichLineBox *box = nil;
	NSUInteger index = 0;
	if (![self lineBox:&box stringIndex:&index atPoint:point inRect:rect])
		return nil;
	return [box.source attribute:attribute atIndex:index effectiveRange:NULL];
}

- (NSDictionary *)linkAtPoint:(CGPoint)point inRect:(CGRect)rect {
	TGRichLineBox *box = nil;
	NSUInteger index = 0;
	if (![self lineBox:&box stringIndex:&index atPoint:point inRect:rect])
		return nil;
	if ([box.source attribute:TGRichSpoilerAttribute atIndex:index effectiveRange:NULL] &&
		[self rangeIsHidden:NSMakeRange(index, 1) in:box])
		return nil;
	id value = [box.source attribute:TGRichLinkAttribute atIndex:index
					  effectiveRange:NULL];
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

- (NSUInteger)stringIndexAtPoint:(CGPoint)point inRect:(CGRect)rect {
	if (!_lines.count)
		return 0;

	CGFloat shift = [self shiftForRect:rect];
	CGPoint local = CGPointMake(point.x - rect.origin.x,
		point.y - rect.origin.y - [self verticalSlackIn:rect]);

	TGRichLineBox *best = _lines.firstObject;
	for (TGRichLineBox *box in _lines) {
		best = box;
		if (local.y <= box.top + box.height)
			break;
	}

	CTLineRef line = (__bridge CTLineRef)best.line;
	if (!line)
		return best.globalOffset;

	CGFloat x = [self xOfLine:best shift:shift];
	CFIndex index = CTLineGetStringIndexForPosition(line,
		CGPointMake(local.x - x, 0));
	if (index == kCFNotFound || index < 0)
		index = 0;
	NSInteger localIndex = MIN((NSUInteger)index, best.globalLength);
	return best.globalOffset + localIndex;
}

- (NSArray *)rectsForRange:(NSRange)range inRect:(CGRect)rect {
	NSMutableArray *result = [[NSMutableArray alloc] init];
	if (range.length == 0 || !_lines.count)
		return result;

	CGFloat shift = [self shiftForRect:rect];
	CGFloat voffsetY = rect.origin.y + [self verticalSlackIn:rect];
	NSInteger rangeEnd = range.location + range.length;

	for (TGRichLineBox *box in _lines) {
		NSInteger boxEnd = box.globalOffset + box.globalLength;
		NSInteger start = MAX(range.location, box.globalOffset);
		NSInteger end = MIN(rangeEnd, boxEnd);
		if (start >= end)
			continue;

		CTLineRef line = (__bridge CTLineRef)box.line;
		if (!line)
			continue;
		CGFloat originX = [self xOfLine:box shift:shift];
		CGFloat from = CTLineGetOffsetForStringIndex(line,
			(CFIndex)(start - box.globalOffset), NULL);
		CGFloat to = CTLineGetOffsetForStringIndex(line,
			(CFIndex)(end - box.globalOffset), NULL);
		if (to < from) {
			CGFloat swap = from;
			from = to;
			to = swap;
		}

		CGRect lineRect = CGRectMake(rect.origin.x + originX + from,
			voffsetY + box.top, MAX(2.0f, to - from), box.height);
		[result addObject:[NSValue valueWithCGRect:lineRect]];
	}
	return result;
}

- (BOOL)spoilerAtPoint:(CGPoint)point inRect:(CGRect)rect {
	return [self attribute:TGRichSpoilerAttribute atPoint:point inRect:rect] != nil;
}

- (NSNumber *)collapsibleBlockAtPoint:(CGPoint)point inRect:(CGRect)rect {
	CGFloat shift = [self shiftForRect:rect];
	CGPoint local = CGPointMake(point.x - rect.origin.x,
		point.y - rect.origin.y - [self verticalSlackIn:rect]);
	for (TGRichBlockBox *box in _blocks) {
		if (!box.spec.collapsible)
			continue;
		if (CGRectContainsPoint(CGRectOffset(box.frame, shift, 0), local))
			return @(box.spec.index);
	}
	return nil;
}

@end

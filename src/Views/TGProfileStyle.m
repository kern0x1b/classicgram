#import "TGProfileStyle.h"
#import "TGStringTruncation.h"
#import <CoreText/CoreText.h>
#import "TGDateUtils.h"
#import "TGLocalization.h"

const CGFloat kActionButtonHeight = 45.0f;
const CGFloat kButtonsRowHeight = 43.0f;
const CGFloat kButtonGutter = 10.0f;
const CGFloat kGroupedInset = 9.0f;
const CGFloat kButtonsRowGutter = 10.0f;
const CGFloat kTitleContainerHeight = 86.0f;
const CGFloat kGroupTitleContainerHeight = 89.0f;
const CGFloat kProfileAvatarSide = 70.0f;
const CGFloat kProfileAvatarPhotoSide = 69.0f;
const CGFloat kProfileAvatarPhotoOffset = 0.5f;
const CGFloat kProfileAvatarRadius = 10.0f;
const CGFloat kProfileNameGap = 15.0f;
const CGFloat kGroupNameGap = 13.0f;
const CGFloat kMemberRowHeight = 49.0f;
const CGFloat kMemberAvatarSide = 36.0f;

CGFloat TGProfileRetinaPixel(void) {
	return [UIScreen mainScreen].scale > 1.5f ? 0.5f : 0.0f;
}

NSString *TGProfileText(id value) {
	if (![value isKindOfClass:[NSString class]])
		return nil;
	NSString *text = [value stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	return text.length ? text : nil;
}

NSString *TGProfileNumberText(id value) {
	if ([value isKindOfClass:[NSNumber class]])
		return [value stringValue];
	return TGProfileText(value);
}

BOOL TGProfileBool(id value) {
	return [value isKindOfClass:[NSNumber class]] && [value boolValue];
}

int64_t TGProfileInt64(id value) {
	if ([value isKindOfClass:[NSNumber class]])
		return [value longLongValue];
	if ([value isKindOfClass:[NSString class]])
		return [value longLongValue];
	return 0;
}

NSString *TGProfileInitial(NSString *name) {
	NSString *trimmed = TGProfileText(name);
	if (!trimmed.length)
		return @"?";
	return [TGSafeFirstCharacter(trimmed) uppercaseString];
}

UIImage *TGProfileStretched(NSString *name) {
	UIImage *raw = [UIImage imageNamed:name];
	if (!raw)
		return nil;
	return [raw stretchableImageWithLeftCapWidth:(int)(raw.size.width / 2) topCapHeight:0];
}

UIImage *TGProfileStretchedInCentre(NSString *name) {
	UIImage *raw = [UIImage imageNamed:name];
	if (!raw)
		return nil;
	return [raw stretchableImageWithLeftCapWidth:(int)(raw.size.width / 2)
									topCapHeight:(int)(raw.size.height / 2)];
}

UIImage *TGProfileAvatarPlate(UIImage *photo) {
	if (!photo)
		return nil;
	CGFloat side = kProfileAvatarSide;
	CGFloat inner = kProfileAvatarPhotoSide;
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0.0f);
	CGRect box = CGRectMake(kProfileAvatarPhotoOffset, 0, inner, inner);
	[[UIBezierPath bezierPathWithRoundedRect:box
								cornerRadius:kProfileAvatarRadius] addClip];
	[photo drawInRect:box];
	UIImage *plate = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return plate ?: photo;
}

UIImage *TGProfilePlaceholderPlate(int64_t colourId, BOOL isGroup) {
	if (isGroup || colourId == 0)
		return TGProfileStretchedInCentre(@"ProfilePhotoPlaceholder.png")
			?: [UIImage imageNamed:@"ProfilePhotoPlaceholderGeneric.png"];
	if (colourId == 777000 || colourId == 333000)
		return [UIImage imageNamed:@"ProfileAvatarSystem.png"];
	NSInteger slot = (NSUInteger)(llabs(colourId) % 8);
	UIImage *plate = [UIImage imageNamed:
			[NSString stringWithFormat:@"ProfileAvatar%u.png", (unsigned)(slot + 1)]];
	return plate ?: [UIImage imageNamed:@"ProfilePhotoPlaceholderGeneric.png"];
}

BOOL TGProfileCanRenderText(NSString *text) {
	if (!text.length)
		return NO;
	NSInteger length = text.length;
	unichar *chars = (unichar *)malloc(sizeof(unichar) * length);
	if (!chars)
		return NO;
	[text getCharacters:chars range:NSMakeRange(0, length)];
	CGGlyph *glyphs = (CGGlyph *)calloc(length, sizeof(CGGlyph));
	BOOL renderable = NO;
	if (glyphs) {
		NSArray *families = @[ @"AppleColorEmoji", @"Helvetica", @"AppleGothic" ];
		for (NSString *family in families) {
			CTFontRef font = CTFontCreateWithName((__bridge CFStringRef)family, 16, NULL);
			if (!font)
				continue;
			BOOL all = CTFontGetGlyphsForCharacters(font, chars, glyphs, (CFIndex)length);
			CFRelease(font);
			if (all) {
				renderable = YES;
				break;
			}
		}
		free(glyphs);
	}
	free(chars);
	return renderable;
}

NSString *TGProfileLastSeenText(long long wasOnline) {
	if (wasOnline <= 0)
		return nil;
	NSString *stamp = [TGDateUtils stringForLastSeen:(int)wasOnline];
	if (!stamp.length)
		return nil;
	return [NSString stringWithFormat:TGL(@"LastSeen.AtDate", @"last seen %@"), stamp];
}

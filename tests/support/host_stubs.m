#import "UIKit.h"
#import "TGEmoji.h"
#import <CoreText/CoreText.h>
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGBubbleCellCatalogue.h"
#import "TGLocalization.h"
#import "TGPluralRules.h"
#import "TGReactionPickerView.h"

CGSize TGEmojiTextSize(NSString *text, UIFont *font, CGSize limit,
					   NSLineBreakMode mode, NSInteger maxLines) {
	return [text sizeWithFont:font constrainedToSize:limit lineBreakMode:mode];
}

BOOL TGEmojiTextNeedsSubstitution(NSString *text) {
	return NO;
}

NSAttributedString *TGEmojiSubstituteInString(NSAttributedString *source) {
	return source;
}

void TGEmojiDrawImagesInLine(CTLineRef line, CGFloat left, CGFloat baseline) {
}

@implementation TGEmojiLabel
@synthesize richLayout = _richLayout;
@end

static UIColor *TGHostThemeColour(NSString *name) {
	static NSMutableDictionary *colours = nil;
	if (!colours)
		colours = [NSMutableDictionary dictionary];
	UIColor *colour = colours[name];
	if (!colour) {
		CGFloat shade = (CGFloat)(name.length % 10) / 10.0f;
		colour = [UIColor colorWithRed:shade green:shade blue:shade alpha:1.0f];
		colours[name] = colour;
	}
	return colour;
}

@implementation TGTheme

+ (TGTheme *)shared {
	static TGTheme *shared = nil;
	if (!shared)
		shared = [[TGTheme alloc] init];
	return shared;
}

- (CGFloat)bubbleCornerRadius {
	return 10.0f;
}

- (UIColor *)barColour {
	return TGHostThemeColour(@"barColour");
}

- (UIColor *)barTitleColour {
	return TGHostThemeColour(@"barTitleColour");
}

- (UIColor *)accentColour {
	return TGHostThemeColour(@"accentColour");
}

- (UIColor *)chatBackgroundColour {
	return TGHostThemeColour(@"chatBackgroundColour");
}

- (UIColor *)bubbleMineColour {
	return TGHostThemeColour(@"bubbleMineColour");
}

- (UIColor *)bubbleTheirsColour {
	return TGHostThemeColour(@"bubbleTheirsColour");
}

- (UIColor *)bubbleBorderColour {
	return TGHostThemeColour(@"bubbleBorderColour");
}

- (UIColor *)listBackgroundColour {
	return TGHostThemeColour(@"listBackgroundColour");
}

- (UIColor *)primaryTextColour {
	return TGHostThemeColour(@"primaryTextColour");
}

- (UIColor *)secondaryTextColour {
	return TGHostThemeColour(@"secondaryTextColour");
}

- (UIColor *)cellDetailColour {
	return TGHostThemeColour(@"cellDetailColour");
}

- (UIColor *)typingColour {
	return TGHostThemeColour(@"typingColour");
}

- (UIColor *)onlineColour {
	return TGHostThemeColour(@"onlineColour");
}

- (UIColor *)separatorColour {
	return TGHostThemeColour(@"separatorColour");
}

- (UIColor *)groupedSeparatorColour {
	return TGHostThemeColour(@"groupedSeparatorColour");
}

- (UIColor *)groupedTitleColour {
	return TGHostThemeColour(@"groupedTitleColour");
}

- (UIColor *)groupedActionColour {
	return TGHostThemeColour(@"groupedActionColour");
}

- (UIColor *)groupedDestructiveColour {
	return TGHostThemeColour(@"groupedDestructiveColour");
}

- (UIColor *)groupedInfoColour {
	return TGHostThemeColour(@"groupedInfoColour");
}

- (UIColor *)groupedDisabledColour {
	return TGHostThemeColour(@"groupedDisabledColour");
}

- (UIColor *)serviceTextColour {
	return TGHostThemeColour(@"serviceTextColour");
}

- (CGFloat)mediaCornerRadius {
	return [self bubbleCornerRadius];
}

- (CGFloat)bubbleBorderWidth {
	return 1.0f;
}

@end

@implementation TGIcons

+ (UIImage *)messageChecksRead:(BOOL)read white:(BOOL)white {
	TGHostSetNamedImageSize(@"TGHostChecks", CGSizeMake(16, 10));
	return [UIImage imageNamed:@"TGHostChecks"];
}

+ (UIImage *)callArrowOutgoing:(BOOL)outgoing missed:(BOOL)missed {
	NSString *name = [NSString stringWithFormat:@"TGHostCallArrow.%d.%d", outgoing ? 1 : 0, missed ? 1 : 0];
	TGHostSetNamedImageSize(name, CGSizeMake(10, 10));
	return [UIImage imageNamed:name];
}

+ (UIImage *)avatarWithInitials:(NSString *)initials size:(CGFloat)size colourId:(int64_t)colourId {
	NSString *name = [NSString stringWithFormat:@"TGHostAvatar.%@.%.0f", initials ?: @"", size];
	TGHostSetNamedImageSize(name, CGSizeMake(size, size));
	return [UIImage imageNamed:name];
}

@end

@implementation TGBubbleCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGChatRowKind)kind {
	return @"TGBubbleCell.HostTest";
}

+ (Class)cellClassForReuseIdentifier:(NSString *)identifier {
	return [NSObject class];
}

@end

NSString *TGLocalizedString(NSString *key, NSString *fallback) {
	return fallback ?: key;
}

NSTextAlignment TGLocalizedLeadingTextAlignment(void) {
	return NSTextAlignmentLeft;
}

NSLocale *TGFormatterLocale(void) {
	static NSLocale *locale = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
	});
	return locale;
}

NSString *TGLocalizedPlural(NSString *key, NSInteger count, NSString *fallbackOne,
	NSString *fallbackOther) {
	NSString *safeOne = fallbackOne.length ? fallbackOne : fallbackOther;
	NSString *safeOther = fallbackOther.length ? fallbackOther : fallbackOne;
	NSString *englishForm = TGPluralFormName(count, @"en");
	NSString *safeFallback = [englishForm isEqualToString:@"one"] ? safeOne : safeOther;
	safeFallback = safeFallback.length ? safeFallback : (key ?: @"");
	return TGPluralSubstituteCount(safeFallback, count);
}

@implementation TGReactionChipsView

+ (CGFloat)rowHeight {
	return 24.0f;
}

@end

@interface TGGroupMemberCell : UITableViewCell
@end

@implementation TGGroupMemberCell
@end

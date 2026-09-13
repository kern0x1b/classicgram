#import "TGRowColours.h"
#import "TGGroupedCaption.h"
#import "TGTheme.h"
#import "TGGroupedMetrics.h"
#import "TGHexColour.h"
#import "TGLocalization.h"

#import <objc/runtime.h>
#import "TGThemeGeometry.h"

NSString *const TGThemeChangedNotification = @"TGThemeChanged";

UIImage *TGBoxBlurredImage(UIImage *image) {
	CGSize size = image.size;
	if (size.width < 8 || size.height < 8)
		return image;
	CGSize small = CGSizeMake(floorf(size.width / 12.0f),
		floorf(size.height / 12.0f));
	if (small.width < 1 || small.height < 1)
		return image;

	UIGraphicsBeginImageContextWithOptions(small, YES, 1.0f);
	[image drawInRect:CGRectMake(0, 0, small.width, small.height)];
	UIImage *shrunk = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	if (!shrunk)
		return image;

	UIGraphicsBeginImageContextWithOptions(size, YES, 1.0f);
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (context)
		CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
	[shrunk drawInRect:CGRectMake(0, 0, size.width, size.height)];
	UIImage *blurred = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return blurred ?: image;
}

UIImage *TGCompositeWallpaperPattern(UIImage *fill, UIImage *pattern, NSInteger intensity, BOOL isInverted) {
	CGSize size = fill.size;
	if (size.width < 1 || size.height < 1 || !pattern.CGImage)
		return fill;

	CGFloat alpha = MIN(1.0f, MAX(0.0f, ABS(intensity) / 100.0f));
	CGRect fillRect = CGRectMake(0, 0, size.width, size.height);
	CGRect patternRect = CGRectMake(0, 0, pattern.size.width, pattern.size.height);

	UIGraphicsBeginImageContextWithOptions(size, YES, 1.0f);
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (!context) {
		UIGraphicsEndImageContext();
		return fill;
	}

	if (isInverted) {
		CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
		CGContextFillRect(context, fillRect);

		UIGraphicsBeginImageContextWithOptions(pattern.size, NO, pattern.scale);
		CGContextRef maskContext = UIGraphicsGetCurrentContext();
		if (maskContext) {
			CGContextClipToMask(maskContext, patternRect, pattern.CGImage);
			[fill drawInRect:patternRect];
		}
		UIImage *maskedFill = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();

		if (maskedFill) {
			CGContextSaveGState(context);
			CGContextSetAlpha(context, alpha > 0.0f ? alpha : 1.0f);
			[maskedFill drawInRect:fillRect];
			CGContextRestoreGState(context);
		}
	} else {
		[fill drawInRect:fillRect];

		if (alpha > 0.0f) {
			UIGraphicsBeginImageContextWithOptions(pattern.size, NO, pattern.scale);
			CGContextRef maskContext = UIGraphicsGetCurrentContext();
			if (maskContext) {
				CGContextClipToMask(maskContext, patternRect, pattern.CGImage);
				CGContextSetFillColorWithColor(maskContext, [UIColor blackColor].CGColor);
				CGContextFillRect(maskContext, patternRect);
			}
			UIImage *tinted = UIGraphicsGetImageFromCurrentImageContext();
			UIGraphicsEndImageContext();

			if (tinted) {
				CGContextSaveGState(context);
				CGContextSetAlpha(context, alpha);
				[tinted drawInRect:fillRect];
				CGContextRestoreGState(context);
			}
		}
	}

	UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return result ?: fill;
}

@interface UINavigationBar (TGThemeGeneration)
@property (nonatomic, assign) NSUInteger tgStyleGeneration;
@end

@implementation UINavigationBar (TGThemeGeneration)

static const char kTGStyleGenerationKey = 0;

- (NSUInteger)tgStyleGeneration {
	return [objc_getAssociatedObject(self, &kTGStyleGenerationKey) unsignedIntegerValue];
}

- (void)setTgStyleGeneration:(NSUInteger)generation {
	objc_setAssociatedObject(self, &kTGStyleGenerationKey, @(generation),
		OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

static NSString *const kFontKey = @"messageFontSize";
static NSString *const kBuiltinKey = @"themeBuiltinWallpaper";
static NSString *const kDefaultBackgroundIdKey = @"themeDefaultBackgroundId";

@implementation TGTheme {
	UIImage *_wallpaper;
	NSUInteger _styleGeneration;
	NSUInteger _backButtonGeneration;
}

+ (instancetype)shared {
	static TGTheme *s = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ s = [[TGTheme alloc] init]; });
	return s;
}

+ (NSArray *)messageFontSizes {
	static NSArray *sizes = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		sizes = @[ @14.0f, @15.0f, @16.0f, @17.0f, @19.0f, @23.0f, @26.0f ];
	});
	return sizes;
}

+ (CGFloat)defaultMessageFontSize {
	return 16.0f;
}

+ (UIColor *)folderTagColourForColourId:(NSInteger)colourId {
	static const unsigned int kThemeFolderTagColours[7] = {
		0xe15052, 0xe0802b, 0xa05ff3, 0x27a910, 0x27acce, 0x3391d4, 0xdd4371};
	if (colourId < 0 || colourId >= 7)
		return nil;
	return TGColourFromHex(kThemeFolderTagColours[colourId]);
}

- (CGFloat)messageFontSize {
	CGFloat stored = [NSUserDefaults.standardUserDefaults floatForKey:kFontKey];
	if (stored <= 0)
		return [TGTheme defaultMessageFontSize];
	NSArray *sizes = [TGTheme messageFontSizes];
	return MAX([sizes.firstObject floatValue],
		MIN([sizes.lastObject floatValue], stored));
}

- (NSUInteger)messageFontStep {
	NSArray *sizes = [TGTheme messageFontSizes];
	CGFloat current = self.messageFontSize;
	NSInteger closest = 0;
	for (NSInteger index = 0; index < sizes.count; index++)
		if (fabsf([sizes[index] floatValue] - current) < fabsf([sizes[closest] floatValue] - current))
			closest = index;
	return closest;
}

- (void)setMessageFontStep:(NSUInteger)step {
	NSArray *sizes = [TGTheme messageFontSizes];
	if (step >= sizes.count)
		step = sizes.count - 1;
	self.messageFontSize = [sizes[step] floatValue];
}

- (CGFloat)listFontDelta {
	CGFloat delta = self.messageFontSize - [TGTheme defaultMessageFontSize];
	return MAX(-2.0f, MIN(4.0f, delta));
}

- (void)setMessageFontSize:(CGFloat)size {
	[NSUserDefaults.standardUserDefaults setFloat:size forKey:kFontKey];
	[NSUserDefaults.standardUserDefaults synchronize];
	[self noteStyleChanged];
	NSNotificationCenter *centre = [NSNotificationCenter defaultCenter];
	[centre postNotificationName:TGThemeChangedNotification object:nil];
}

#pragma mark - wallpaper

- (NSString *)wallpaperPath {
	NSString *documents = [NSSearchPathForDirectoriesInDomains(
		NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
	return [documents stringByAppendingPathComponent:@"wallpaper.jpg"];
}

- (UIImage *)wallpaper {
	if (!_wallpaper)
		_wallpaper = [UIImage imageWithContentsOfFile:[self wallpaperPath]];
	if (!_wallpaper)
		_wallpaper = [UIImage imageNamed:@"builtin-wallpaper-0.jpg"];
	return _wallpaper;
}

static UIImage *TGThemeScaledWallpaper(UIImage *image) {
	CGFloat maxSide = 640;
	CGFloat scale = MIN(1.0f, maxSide / MAX(image.size.width, image.size.height));
	if (scale >= 1.0f)
		return image;
	CGSize size = CGSizeMake(image.size.width * scale, image.size.height * scale);
	UIGraphicsBeginImageContextWithOptions(size, YES, 1);
	[image drawInRect:CGRectMake(0, 0, size.width, size.height)];
	UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return scaled;
}

- (void)storeWallpaperImage:(UIImage *)image {
	NSString *path = [self wallpaperPath];
	if (image) {
		image = TGThemeScaledWallpaper(image);
		[UIImageJPEGRepresentation(image, 0.8f) writeToFile:path atomically:YES];
	} else {
		[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
	}
	_wallpaper = image;
}

- (void)setWallpaperImage:(UIImage *)image {
	[self storeWallpaperImage:image];
	self.builtinWallpaperName = nil;
	[self noteStyleChanged];
	NSNotificationCenter *centre = [NSNotificationCenter defaultCenter];
	[centre postNotificationName:TGThemeChangedNotification object:nil];
}

- (NSString *)builtinWallpaperName {
	if (![[NSFileManager defaultManager] fileExistsAtPath:[self wallpaperPath]])
		return nil;
	return [NSUserDefaults.standardUserDefaults stringForKey:kBuiltinKey];
}

- (void)setBuiltinWallpaperName:(NSString *)name {
	if (name.length)
		[NSUserDefaults.standardUserDefaults setObject:name forKey:kBuiltinKey];
	else
		[NSUserDefaults.standardUserDefaults removeObjectForKey:kBuiltinKey];
	[NSUserDefaults.standardUserDefaults synchronize];
}

- (NSString *)defaultBackgroundId {
	return [NSUserDefaults.standardUserDefaults stringForKey:kDefaultBackgroundIdKey];
}

- (void)setDefaultBackgroundId:(NSString *)backgroundId {
	if (backgroundId.length)
		[NSUserDefaults.standardUserDefaults setObject:backgroundId forKey:kDefaultBackgroundIdKey];
	else
		[NSUserDefaults.standardUserDefaults removeObjectForKey:kDefaultBackgroundIdKey];
	[NSUserDefaults.standardUserDefaults synchronize];
}

+ (void)resetDefaultBackgroundIdForAccountSwitch {
	[NSUserDefaults.standardUserDefaults removeObjectForKey:kDefaultBackgroundIdKey];
	[[TGTheme shared] setWallpaperImage:nil];
	[NSUserDefaults.standardUserDefaults synchronize];
}

- (BOOL)applyBuiltinWallpaperNamed:(NSString *)name {
	NSString *path = name.length
		? [[NSBundle mainBundle] pathForResource:name ofType:@"jpg"]
		: nil;
	UIImage *image = path ? [UIImage imageWithContentsOfFile:path] : nil;
	if (!image)
		return NO;
	[self storeWallpaperImage:image];
	self.builtinWallpaperName = name;
	NSNotificationCenter *centre = [NSNotificationCenter defaultCenter];
	[centre postNotificationName:TGThemeChangedNotification object:nil];
	return YES;
}

#pragma mark - palette

static UIColor *rgb(int r, int g, int b) {
	return [UIColor colorWithRed:r / 255.0f green:g / 255.0f blue:b / 255.0f alpha:1.0f];
}

#define TG_BAR_BLUE rgb(0x54, 0x7A, 0xA1)
#define TG_ACTION_BLUE rgb(0x07, 0x79, 0xD0)
#define TG_BADGE_STEEL rgb(0x92, 0x9F, 0xB0)
#define TG_BUBBLE_OUT rgb(0xD3, 0xFB, 0xB1)
#define TG_BUBBLE_IN rgb(0xFB, 0xFB, 0xFB)
#define TG_LINEN rgb(0xDB, 0xE4, 0xED)
#define TG_SETTINGS_GROUND rgb(0xC9, 0xD1, 0xDB)
#define TG_INPUT_PANEL rgb(0xE7, 0xEB, 0xF0)
#define TG_MUTE_GREY rgb(0xBA, 0xBA, 0xBA)
#define TG_PRESENCE_TEXT rgb(0x77, 0x86, 0x98)
#define TG_HAIRLINE rgb(0xE5, 0xE5, 0xE5)
#define TG_GROUPED_HAIRLINE rgb(0xDF, 0xE3, 0xE8)
#define TG_TEXT_PRIMARY rgb(0x11, 0x11, 0x11)
#define TG_TEXT_SECONDARY rgb(0x88, 0x88, 0x88)
#define TG_MESSAGE_DATE rgb(0x23, 0x2D, 0x37)
#define TG_CHECKED_TITLE rgb(0x51, 0x66, 0x91)
#define TG_DESTRUCTIVE rgb(0xC4, 0x36, 0x2F)
#define TG_FOOTER_CAPTION rgb(0x69, 0x74, 0x87)
#define TG_ACTION_TEXT rgb(0x53, 0x6C, 0x8C)
#define TG_ATTACH_TITLE rgb(0x62, 0x76, 0x8A)
#define TG_ATTACH_META rgb(0x72, 0x87, 0x9B)

#define TG_BAR_TITLE_SHADOW rgb(0x3D, 0x5C, 0x81)
#define TG_BAR_BUTTON_SHADOW [rgb(0x0E, 0x28, 0x4D) colorWithAlphaComponent:0.4f]

- (UIColor *)barColour {
	return TG_BAR_BLUE;
}

- (UIColor *)barTitleColour {
	return [UIColor whiteColor];
}

- (UIColor *)accentColour {
	return TG_ACTION_BLUE;
}

- (UIColor *)chatBackgroundColour {
	static UIColor *linen = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		UIImage *tile = [UIImage imageNamed:@"Linen.png"];
		if (tile)
			linen = [UIColor colorWithPatternImage:tile];
	});
	return linen ?: TG_LINEN;
}

- (UIColor *)bubbleMineColour {
	return TG_BUBBLE_OUT;
}

- (UIColor *)bubbleTheirsColour {
	return TG_BUBBLE_IN;
}

- (UIColor *)bubbleBorderColour {
	return [UIColor colorWithRed:0x01 / 255.0f green:0x29 / 255.0f
							blue:0x68 / 255.0f
						   alpha:52.0f / 255.0f];
}

- (UIColor *)listBackgroundColour {
	return [UIColor whiteColor];
}

- (UIColor *)primaryTextColour {
	return TG_TEXT_PRIMARY;
}

- (UIColor *)secondaryTextColour {
	return TG_TEXT_SECONDARY;
}

- (UIColor *)cellDetailColour {
	return TGSettingsValueColour();
}

- (UIColor *)inputBarColour {
	return TG_INPUT_PANEL;
}

#pragma mark - media and file blocks

- (UIColor *)fileTileColour {
	return [UIColor whiteColor];
}

- (UIColor *)mediaCircleColour {
	return [UIColor colorWithRed:0x60 / 255.0f green:0x78 / 255.0f
							blue:0x99 / 255.0f
						   alpha:140.0f / 255.0f];
}

- (UIColor *)fileNameColour {
	return TG_ATTACH_TITLE;
}

- (UIColor *)fileMetaColour {
	return TG_ATTACH_META;
}

- (UIColor *)mediaStampColour {
	return [UIColor colorWithWhite:0.0f alpha:0.35f];
}

#pragma mark - chat list

- (UIColor *)typingColour {
	return TG_ACTION_TEXT;
}

- (UIColor *)onlineColour {
	return rgb(0x4c, 0xd9, 0x64);
}

- (UIColor *)separatorColour {
	return TG_HAIRLINE;
}

- (UIColor *)groupedSeparatorColour {
	return TG_GROUPED_HAIRLINE;
}

#pragma mark - grouped footers

+ (UIFont *)groupedCommentFont {
	return [UIFont systemFontOfSize:14];
}

static CGFloat TGGroupedCommentWidth(CGFloat width) {
	return width > 0 ? width : [UIScreen mainScreen].bounds.size.width;
}

- (CGFloat)groupedCommentHeightForText:(NSString *)text width:(CGFloat)rawWidth {
	if (!text.length)
		return 0;
	CGFloat width = TGGroupedCommentWidth(rawWidth);
	CGFloat inset = TGGroupedCommentInset(width);
	CGSize size = [text sizeWithFont:[TGTheme groupedCommentFont]
				   constrainedToSize:CGSizeMake(MAX(40.0f, width - 24 - inset * 2), 1000)
					   lineBreakMode:NSLineBreakByWordWrapping];
	return TGGroupedCommentHeight(size.height);
}

- (UIView *)groupedCommentViewWithText:(NSString *)text width:(CGFloat)rawWidth {
	if (!text.length)
		return nil;
	CGFloat width = TGGroupedCommentWidth(rawWidth);
	CGFloat inset = TGGroupedCommentInset(width);
	CGFloat height = [self groupedCommentHeightForText:text width:width];
	UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
	container.backgroundColor = [UIColor clearColor];
	container.autoresizingMask = UIViewAutoresizingFlexibleWidth;

	UILabel *label = [[UILabel alloc] initWithFrame:
			CGRectMake(1 + inset, 7, MAX(40.0f, width - 2 - inset * 2), height - 14)];
	label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	label.contentMode = UIViewContentModeCenter;
	label.textAlignment = NSTextAlignmentCenter;
	label.font = [TGTheme groupedCommentFont];
	label.backgroundColor = [UIColor clearColor];
	label.numberOfLines = 0;
	label.lineBreakMode = NSLineBreakByWordWrapping;
	label.text = text;
	label.textColor = TG_FOOTER_CAPTION;
	label.shadowColor = rgb(0xDA, 0xE0, 0xE8);
	label.shadowOffset = CGSizeMake(0, 1);
	[container addSubview:label];
	return container;
}

#pragma mark - grouped section headers

- (CGFloat)groupedHeaderHeightForTitle:(NSString *)title {
	return TGGroupedHeaderHeight(title);
}

- (UIView *)groupedHeaderViewWithTitle:(NSString *)title width:(CGFloat)rawWidth {
	if (!title.length)
		return nil;
	CGFloat width = TGGroupedCommentWidth(rawWidth);
	CGFloat inset = TGGroupedCommentInset(width);
	UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 46)];
	container.backgroundColor = [UIColor clearColor];
	container.autoresizingMask = UIViewAutoresizingFlexibleWidth;

	UILabel *label = [[UILabel alloc] init];
	label.text = [title uppercaseStringWithLocale:[NSLocale currentLocale]];
	label.backgroundColor = [UIColor clearColor];
	label.font = [UIFont boldSystemFontOfSize:17];
	label.textColor = TG_FOOTER_CAPTION;
	label.shadowColor = rgb(0xDA, 0xE0, 0xE8);
	label.shadowOffset = CGSizeMake(0, 1);
	[label sizeToFit];
	CGRect frame = label.frame;
	frame.origin = CGPointMake(21 + inset, 16);
	frame.size.width = MIN(frame.size.width, MAX(40.0f, width - 42 - inset * 2));
	label.frame = CGRectIntegral(frame);
	[container addSubview:label];
	return container;
}

#pragma mark - grouped rows

- (UIColor *)groupedTitleColour {
	return [UIColor blackColor];
}

- (UIColor *)groupedActionColour {
	return [self accentColour];
}

- (UIColor *)groupedDestructiveColour {
	return TG_DESTRUCTIVE;
}

- (UIColor *)groupedInfoColour {
	return TG_CHECKED_TITLE;
}

- (UIColor *)groupedDisabledColour {
	return [self secondaryTextColour];
}

- (UIColor *)emptyStateColour {
	return TGEmptyStateColour();
}

#pragma mark - service messages

- (UIColor *)serviceTextColour {
	return [UIColor whiteColor];
}

#pragma mark - bubble metrics

- (CGFloat)bubbleCornerRadius {
	return 10.0f;
}

- (CGFloat)mediaCornerRadius {
	return [self bubbleCornerRadius];
}

- (CGFloat)bubbleBorderWidth {
	return 1.0f;
}

#pragma mark - styling views

- (void)styleCell:(UITableViewCell *)cell {
	cell.textLabel.font = TGGroupedRowTitleFont();
	cell.detailTextLabel.font = TGGroupedRowValueFont();
	cell.detailTextLabel.textColor = [self cellDetailColour];
	cell.textLabel.textColor = [UIColor blackColor];
	cell.backgroundColor = [UIColor whiteColor];
}

- (void)styleTabBar:(UITabBar *)bar {
}

- (void)noteStyleChanged {
	_styleGeneration++;
}

- (void)restyleNavigationBar:(UINavigationBar *)bar {
	if (!bar)
		return;
	bar.tgStyleGeneration = 0;
	[self styleNavigationBar:bar];
}

- (UIColor *)navigationBarTintColour {
	if ([UINavigationBar instancesRespondToSelector:@selector(setBarTintColor:)])
		return [UIColor whiteColor];
	return [self barColour];
}

- (UIColor *)barTitleShadowColour {
	return TG_BAR_TITLE_SHADOW;
}

- (UIColor *)barButtonTitleShadowColour {
	return TG_BAR_BUTTON_SHADOW;
}

- (BOOL)navigationBarCarriesCurrentStyle:(UINavigationBar *)bar {
	if (![bar.tintColor isEqual:[self navigationBarTintColour]])
		return NO;
	if (![bar respondsToSelector:@selector(backgroundImageForBarMetrics:)])
		return YES;
	return [bar backgroundImageForBarMetrics:UIBarMetricsDefault] == [self carvedBarBackground];
}

- (void)styleNavigationBar:(UINavigationBar *)bar {
	if (!bar)
		return;
	if (bar.tgStyleGeneration == _styleGeneration + 1 && [self navigationBarCarriesCurrentStyle:bar])
		return;
	bar.tgStyleGeneration = _styleGeneration + 1;

	bar.barStyle = UIBarStyleDefault;
	bar.tintColor = [self navigationBarTintColour];

	UIColor *titleShadow = [self barTitleShadowColour];
	if ([bar respondsToSelector:@selector(setBarTintColor:)]) {
		bar.translucent = YES;
		bar.barTintColor = [self barColour];
		NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
		attributes[NSForegroundColorAttributeName] = [self barTitleColour];
		if (titleShadow) {
			NSShadow *shadow = [[NSShadow alloc] init];
			shadow.shadowColor = titleShadow;
			shadow.shadowOffset = CGSizeMake(0.0f, -1.0f);
			attributes[NSShadowAttributeName] = shadow;
		}
		bar.titleTextAttributes = attributes;
	} else {
		NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
		attributes[UITextAttributeTextColor] = [self barTitleColour];
		if (titleShadow) {
			attributes[UITextAttributeTextShadowColor] = titleShadow;
			attributes[UITextAttributeTextShadowOffset] =
				[NSValue valueWithUIOffset:UIOffsetMake(0.0f, -1.0f)];
		}
		bar.titleTextAttributes = attributes;
	}

	[self applyCarvedBarBackground:bar];

	[self styleBackButton];
}

- (UIImage *)carvedBarBackground {
	static UIImage *background = nil;
	if (!background) {
		background = [UIImage imageNamed:@"NavBarBackground"];
		if ([background respondsToSelector:@selector(resizableImageWithCapInsets:)])
			background = [background resizableImageWithCapInsets:UIEdgeInsetsMake(0, 8, 0, 8)];
	}
	return background;
}

- (void)applyCarvedBarBackground:(UINavigationBar *)bar {
	UIImage *background = [self carvedBarBackground];
	if (background && [bar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)])
		[bar setBackgroundImage:background forBarMetrics:UIBarMetricsDefault];
}

- (void)styleBackButton {
	if (_backButtonGeneration == _styleGeneration + 1)
		return;
	_backButtonGeneration = _styleGeneration + 1;

	UIBarButtonItem *proxy = [UIBarButtonItem appearance];

	static UIImage *normal = nil;
	static UIImage *pressed = nil;
	if (!normal)
		normal = TGLocalizedDirectionalStretchableImage(
			[UIImage imageNamed:@"BackButton"], 15);
	if (!pressed)
		pressed = TGLocalizedDirectionalStretchableImage(
			[UIImage imageNamed:@"BackButton_Pressed"], 15);
	if (normal)
		[proxy setBackButtonBackgroundImage:normal forState:UIControlStateNormal
								 barMetrics:UIBarMetricsDefault];
	if (pressed)
		[proxy setBackButtonBackgroundImage:pressed forState:UIControlStateHighlighted
								 barMetrics:UIBarMetricsDefault];

	UIColor *buttonShadow = [self barButtonTitleShadowColour];
	NSMutableDictionary *titleAttributes = [NSMutableDictionary dictionary];
	if (NSFoundationVersionNumber > 993.00) {
		titleAttributes[NSForegroundColorAttributeName] = [UIColor whiteColor];
		if (buttonShadow) {
			NSShadow *shadow = [[NSShadow alloc] init];
			shadow.shadowColor = buttonShadow;
			shadow.shadowOffset = CGSizeMake(0.0f, -1.0f);
			titleAttributes[NSShadowAttributeName] = shadow;
		}
	} else {
		titleAttributes[UITextAttributeTextColor] = [UIColor whiteColor];
		if (buttonShadow) {
			titleAttributes[UITextAttributeTextShadowColor] = buttonShadow;
			titleAttributes[UITextAttributeTextShadowOffset] =
				[NSValue valueWithUIOffset:UIOffsetMake(0.0f, -1.0f)];
		}
	}
	[proxy setTitleTextAttributes:titleAttributes forState:UIControlStateNormal];
}

@end

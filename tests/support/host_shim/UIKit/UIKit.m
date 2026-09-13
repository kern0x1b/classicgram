#import "UIKit.h"

@interface UIFont ()
@property (nonatomic, assign, readwrite) CGFloat pointSize;
@property (nonatomic, assign, readwrite) BOOL isBold;
@property (nonatomic, assign, readwrite) BOOL isItalic;
@end

@interface UIImage ()
@property (nonatomic, assign, readwrite) CGSize size;
@property (nonatomic, assign, readwrite) CGFloat tgHostScale;
@end

NSString *const UIApplicationDidReceiveMemoryWarningNotification = @"TGHostUIApplicationDidReceiveMemoryWarningNotification";
NSString *const UIApplicationDidEnterBackgroundNotification = @"TGHostUIApplicationDidEnterBackgroundNotification";

static NSMutableDictionary *TGHostNamedImageSizes(void) {
	static NSMutableDictionary *sizes = nil;
	if (!sizes)
		sizes = [[NSMutableDictionary alloc] init];
	return sizes;
}

CGFloat TGHostTextWidthPerPoint(void) {
	return 0.55f;
}

void TGHostSetNamedImageSize(NSString *name, CGSize size) {
	if (!name)
		return;
	TGHostNamedImageSizes()[name] = [NSValue valueWithBytes:&size objCType:@encode(CGSize)];
}

@implementation UIFont

+ (UIFont *)fontOfSize:(CGFloat)size bold:(BOOL)bold {
	UIFont *font = [[UIFont alloc] init];
	font.pointSize = size;
	font.isBold = bold;
	return font;
}

+ (UIFont *)italicSystemFontOfSize:(CGFloat)size {
	UIFont *font = [self fontOfSize:size bold:NO];
	font.isItalic = YES;
	return font;
}

+ (UIFont *)fontWithName:(NSString *)name size:(CGFloat)size {
	UIFont *font = [self fontOfSize:size bold:[name rangeOfString:@"Bold"].location != NSNotFound];
	font.isItalic = [name rangeOfString:@"Italic"].location != NSNotFound;
	return font;
}

- (NSString *)fontName {
	if (self.isBold && self.isItalic)
		return @"Helvetica-BoldOblique";
	if (self.isBold)
		return @"Helvetica-Bold";
	if (self.isItalic)
		return @"Helvetica-Oblique";
	return @"Helvetica";
}

- (NSString *)familyName {
	return @"Helvetica";
}

- (CGFloat)ascender {
	return self.pointSize * 0.78f;
}

- (CGFloat)descender {
	return -self.pointSize * 0.22f;
}

+ (UIFont *)systemFontOfSize:(CGFloat)size {
	return [self fontOfSize:size bold:NO];
}

+ (UIFont *)boldSystemFontOfSize:(CGFloat)size {
	return [self fontOfSize:size bold:YES];
}

- (CGFloat)lineHeight {
	return ceilf(self.pointSize * 1.2f);
}

@end

@implementation UIImage

+ (UIImage *)imageWithContentsOfFile:(NSString *)path {
	return nil;
}

- (CGImageRef)CGImage {
	return NULL;
}

+ (UIImage *)imageNamed:(NSString *)name {
	NSValue *stored = TGHostNamedImageSizes()[name ?: @""];
	if (!stored)
		return nil;
	CGSize size = CGSizeZero;
	[stored getValue:&size];
	UIImage *image = [[UIImage alloc] init];
	image.size = size;
	return image;
}

+ (UIImage *)imageWithData:(NSData *)data {
	return [self imageWithData:data scale:1.0f];
}

static NSData *TGHostUndecodableMarker(void) {
	static NSData *marker = nil;
	if (!marker) {
		uint8_t bytes[4] = {0xDE, 0xAD, 0xBE, 0xEF};
		marker = [NSData dataWithBytes:bytes length:sizeof(bytes)];
	}
	return marker;
}

+ (UIImage *)imageWithData:(NSData *)data scale:(CGFloat)scale {
	if (!data.length)
		return nil;
	if ([data isEqualToData:TGHostUndecodableMarker()])
		return nil;
	UIImage *image = [[UIImage alloc] init];
	image.tgHostPixelData = data;
	image.tgHostScale = scale;
	image.size = CGSizeMake((CGFloat)data.length, 1);
	return image;
}

+ (UIImage *)tgHostImageWithPixelData:(NSData *)data {
	return [self imageWithData:data scale:1.0f];
}

+ (UIImage *)tgHostUndecodableImage {
	UIImage *image = [[UIImage alloc] init];
	image.tgHostPixelData = TGHostUndecodableMarker();
	image.tgHostScale = 1.0f;
	image.size = CGSizeMake(1, 1);
	return image;
}

- (UIImage *)resizableImageWithCapInsets:(UIEdgeInsets)insets {
	return self;
}

- (UIImage *)stretchableImageWithLeftCapWidth:(NSInteger)left topCapHeight:(NSInteger)top {
	return self;
}

@end

NSData *UIImagePNGRepresentation(UIImage *image) {
	return image.tgHostPixelData;
}

@implementation UIBarButtonItem
@end

@implementation UITableView

- (void)reloadData {
	self.tgReloadCount += 1;
}

@end

@implementation UITableViewCell {
	UILabel *_textLabel;
	UILabel *_detailTextLabel;
	UIImageView *_imageView;
	UIView *_contentView;
	NSString *_reuseIdentifier;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super init];
	if (!self)
		return nil;
	_reuseIdentifier = [reuseIdentifier copy];
	_textLabel = [[UILabel alloc] init];
	_detailTextLabel = [[UILabel alloc] init];
	_imageView = [[UIImageView alloc] init];
	_contentView = [[UIView alloc] init];
	return self;
}

- (instancetype)init {
	return [self initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
}

- (UILabel *)textLabel {
	return _textLabel;
}

- (UILabel *)detailTextLabel {
	return _detailTextLabel;
}

- (UIImageView *)imageView {
	return _imageView;
}

- (UIView *)contentView {
	return _contentView;
}

- (NSString *)reuseIdentifier {
	return _reuseIdentifier;
}

- (void)prepareForReuse {
}

@end

@implementation UINavigationBar
@end

@implementation UISearchBar
@end

@implementation UITabBar
@end

@implementation NSValue (TGHostGeometry)

+ (NSValue *)valueWithCGRect:(CGRect)rect {
	return [NSValue valueWithBytes:&rect objCType:@encode(CGRect)];
}

+ (NSValue *)valueWithCGSize:(CGSize)size {
	return [NSValue valueWithBytes:&size objCType:@encode(CGSize)];
}

- (CGRect)CGRectValue {
	CGRect rect = CGRectZero;
	[self getValue:&rect];
	return rect;
}

- (CGSize)CGSizeValue {
	CGSize size = CGSizeZero;
	[self getValue:&size];
	return size;
}

@end

@implementation UITextField
@end

@interface UIColor ()
@property (nonatomic, assign) CGFloat hostRed;
@property (nonatomic, assign) CGFloat hostGreen;
@property (nonatomic, assign) CGFloat hostBlue;
@property (nonatomic, assign) CGFloat hostAlpha;
@end

@implementation UIColor {
	CGColorRef _cgColor;
}

+ (UIColor *)colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha {
	UIColor *colour = [[UIColor alloc] init];
	colour.hostRed = red;
	colour.hostGreen = green;
	colour.hostBlue = blue;
	colour.hostAlpha = alpha;
	return colour;
}

+ (UIColor *)colorWithWhite:(CGFloat)white alpha:(CGFloat)alpha {
	return [self colorWithRed:white green:white blue:white alpha:alpha];
}

+ (UIColor *)colorWithCGColor:(CGColorRef)color {
	if (!color)
		return [self clearColor];
	const CGFloat *components = CGColorGetComponents(color);
	size_t count = CGColorGetNumberOfComponents(color);
	if (count >= 4)
		return [self colorWithRed:components[0] green:components[1] blue:components[2] alpha:components[3]];
	if (count >= 2)
		return [self colorWithWhite:components[0] alpha:components[1]];
	return [self clearColor];
}

- (BOOL)getRed:(CGFloat *)red green:(CGFloat *)green blue:(CGFloat *)blue alpha:(CGFloat *)alpha {
	if (red)
		*red = self.hostRed;
	if (green)
		*green = self.hostGreen;
	if (blue)
		*blue = self.hostBlue;
	if (alpha)
		*alpha = self.hostAlpha;
	return YES;
}

+ (UIColor *)colorWithPatternImage:(UIImage *)image {
	UIColor *colour = [[UIColor alloc] init];
	colour.patternImage = image;
	return colour;
}

+ (UIColor *)clearColor {
	return [self colorWithWhite:0 alpha:0];
}

+ (UIColor *)whiteColor {
	return [self colorWithWhite:1 alpha:1];
}

+ (UIColor *)blackColor {
	return [self colorWithWhite:0 alpha:1];
}

+ (UIColor *)grayColor {
	return [self colorWithWhite:0.5f alpha:1];
}

+ (UIColor *)darkGrayColor {
	return [self colorWithWhite:0.333f alpha:1];
}

+ (UIColor *)lightGrayColor {
	return [self colorWithWhite:0.667f alpha:1];
}

+ (UIColor *)redColor {
	return [self colorWithRed:1 green:0 blue:0 alpha:1];
}

+ (UIColor *)blueColor {
	return [self colorWithRed:0 green:0 blue:1 alpha:1];
}

- (UIColor *)colorWithAlphaComponent:(CGFloat)alpha {
	return [UIColor colorWithRed:self.hostRed green:self.hostGreen blue:self.hostBlue alpha:alpha];
}

- (void)set {
}

- (void)setFill {
}

- (void)setStroke {
}

- (CGColorRef)CGColor {
	if (!_cgColor) {
		CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
		CGFloat components[4] = {self.hostRed, self.hostGreen, self.hostBlue, self.hostAlpha};
		_cgColor = CGColorCreate(space, components);
		CGColorSpaceRelease(space);
	}
	return _cgColor;
}

- (void)dealloc {
	if (_cgColor)
		CGColorRelease(_cgColor);
}

@end

@implementation UIBezierPath {
	CGMutablePathRef _path;
}

+ (UIBezierPath *)bezierPath {
	return [[UIBezierPath alloc] init];
}

+ (UIBezierPath *)bezierPathWithRect:(CGRect)rect {
	UIBezierPath *path = [[UIBezierPath alloc] init];
	CGPathAddRect(path.hostMutablePath, NULL, rect);
	return path;
}

+ (UIBezierPath *)bezierPathWithOvalInRect:(CGRect)rect {
	UIBezierPath *path = [[UIBezierPath alloc] init];
	CGPathAddEllipseInRect(path.hostMutablePath, NULL, rect);
	return path;
}

+ (UIBezierPath *)bezierPathWithRoundedRect:(CGRect)rect cornerRadius:(CGFloat)radius {
	UIBezierPath *path = [[UIBezierPath alloc] init];
	CGPathAddRoundedRect(path.hostMutablePath, NULL, rect, radius, radius);
	return path;
}

- (CGMutablePathRef)hostMutablePath {
	if (!_path)
		_path = CGPathCreateMutable();
	return _path;
}

- (CGPathRef)CGPath {
	return self.hostMutablePath;
}

- (void)moveToPoint:(CGPoint)point {
	CGPathMoveToPoint(self.hostMutablePath, NULL, point.x, point.y);
}

- (void)addLineToPoint:(CGPoint)point {
	CGPathAddLineToPoint(self.hostMutablePath, NULL, point.x, point.y);
}

- (void)closePath {
	CGPathCloseSubpath(self.hostMutablePath);
}

- (void)fill {
}

- (void)stroke {
}

- (void)addClip {
}

- (void)dealloc {
	if (_path)
		CGPathRelease(_path);
}

@end

NSString *const NSFontAttributeName = @"NSFont";
NSString *const NSForegroundColorAttributeName = @"NSColor";
NSString *const NSParagraphStyleAttributeName = @"NSParagraphStyle";

@implementation NSString (TGHostDrawing)

- (void)drawInRect:(CGRect)rect withFont:(UIFont *)font lineBreakMode:(NSLineBreakMode)mode {
}

- (void)drawInRect:(CGRect)rect withFont:(UIFont *)font lineBreakMode:(NSLineBreakMode)mode alignment:(NSTextAlignment)alignment {
}

- (void)drawAtPoint:(CGPoint)point withFont:(UIFont *)font {
}

@end

CGContextRef UIGraphicsGetCurrentContext(void) {
	return NULL;
}

void UIGraphicsBeginImageContextWithOptions(CGSize size, BOOL opaque, CGFloat scale) {
}

UIImage *UIGraphicsGetImageFromCurrentImageContext(void) {
	return nil;
}

void UIGraphicsEndImageContext(void) {
}

void UIGraphicsPushContext(CGContextRef context) {
}

void UIGraphicsPopContext(void) {
}

@implementation CALayer
@end

@implementation UIView {
	NSMutableArray *_subviews;
	CALayer *_layer;
}

- (instancetype)initWithFrame:(CGRect)frame {
	self = [super init];
	if (self)
		self.frame = frame;
	return self;
}

- (CALayer *)layer {
	if (!_layer)
		_layer = [[CALayer alloc] init];
	return _layer;
}

- (NSArray *)subviews {
	return _subviews ?: @[];
}

- (void)addSubview:(UIView *)view {
	if (!view)
		return;
	if (!_subviews)
		_subviews = [NSMutableArray array];
	[_subviews addObject:view];
}

- (void)removeFromSuperview {
}

- (void)setNeedsDisplay {
}

- (void)setNeedsLayout {
}

- (void)layoutSubviews {
}

@end

@implementation UIAlertView {
	BOOL _dismissed;
}
- (BOOL)dismissed {
	return _dismissed;
}
- (void)dismissWithClickedButtonIndex:(NSInteger)index animated:(BOOL)animated {
	(void)index;
	(void)animated;
	_dismissed = YES;
}
@end

@implementation UIActionSheet {
	BOOL _dismissed;
}
- (BOOL)dismissed {
	return _dismissed;
}
- (void)dismissWithClickedButtonIndex:(NSInteger)index animated:(BOOL)animated {
	(void)index;
	(void)animated;
	_dismissed = YES;
}
@end

@implementation UIActivityIndicatorView {
	BOOL _animating;
}
- (instancetype)initWithActivityIndicatorStyle:(UIActivityIndicatorViewStyle)style {
	(void)style;
	return [self initWithFrame:CGRectZero];
}
- (BOOL)animating {
	return _animating;
}
- (void)startAnimating {
	_animating = YES;
}
- (void)stopAnimating {
	_animating = NO;
}
@end

@implementation UILabel

- (void)drawTextInRect:(CGRect)rect {
}

- (CGSize)sizeThatFits:(CGSize)size {
	NSString *text = self.text ?: self.attributedText.string;
	CGFloat width = (CGFloat)text.length * self.font.pointSize * TGHostTextWidthPerPoint();
	return CGSizeMake(MIN(width, size.width), self.font.lineHeight);
}

@end

@implementation UIButton
@end

@implementation UIImageView

- (instancetype)initWithImage:(UIImage *)image {
	self = [super init];
	if (self)
		self.image = image;
	return self;
}

@end

@implementation UIDevice

+ (UIDevice *)currentDevice {
	static UIDevice *device = nil;
	if (!device)
		device = [[UIDevice alloc] init];
	return device;
}

- (NSString *)systemVersion {
	return @"6.1";
}

- (NSString *)model {
	return @"iPhone";
}

- (UIUserInterfaceIdiom)userInterfaceIdiom {
	return UIUserInterfaceIdiomPhone;
}

@end

@implementation UIScreen

+ (UIScreen *)mainScreen {
	static UIScreen *screen = nil;
	if (!screen)
		screen = [[UIScreen alloc] init];
	return screen;
}

- (CGFloat)scale {
	return 1.0f;
}

@end

@implementation NSString (TGHostTextMetrics)

- (CGSize)sizeWithFont:(UIFont *)font {
	CGFloat point = font ? font.pointSize : 14.0f;
	CGFloat width = self.length * point * TGHostTextWidthPerPoint();
	if (font.isBold)
		width *= 1.05f;
	return CGSizeMake(ceilf(width), font ? font.lineHeight : ceilf(point * 1.2f));
}

- (CGSize)sizeWithFont:(UIFont *)font
	 constrainedToSize:(CGSize)limit
		 lineBreakMode:(NSLineBreakMode)mode {
	CGSize single = [self sizeWithFont:font];
	if (limit.width <= 0 || single.width <= limit.width)
		return single;

	CGFloat lines = ceilf(single.width / limit.width);
	CGFloat height = lines * single.height;
	if (height > limit.height)
		height = limit.height;
	return CGSizeMake(limit.width, height);
}

@end

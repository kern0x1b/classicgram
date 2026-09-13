#ifndef TG_HOST_TESTS_UIKIT_SHIM_H
#define TG_HOST_TESTS_UIKIT_SHIM_H

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <math.h>

typedef NS_ENUM(NSInteger, NSLineBreakMode) {
	NSLineBreakByWordWrapping = 0,
	NSLineBreakByCharWrapping,
	NSLineBreakByClipping,
	NSLineBreakByTruncatingHead,
	NSLineBreakByTruncatingTail,
	NSLineBreakByTruncatingMiddle
};

typedef NS_ENUM(NSInteger, NSTextAlignment) {
	NSTextAlignmentLeft = 0,
	NSTextAlignmentCenter,
	NSTextAlignmentRight
};

typedef struct {
	CGFloat top, left, bottom, right;
} UIEdgeInsets;

static inline UIEdgeInsets UIEdgeInsetsMake(CGFloat top, CGFloat left,
											 CGFloat bottom, CGFloat right) {
	UIEdgeInsets insets = {top, left, bottom, right};
	return insets;
}

@class UIColor;
@class UILabel;
@class UIImageView;

typedef NS_ENUM(NSInteger, UIViewContentMode) {
	UIViewContentModeScaleToFill = 0,
	UIViewContentModeScaleAspectFit,
	UIViewContentModeScaleAspectFill,
	UIViewContentModeCenter,
};

#define CALayer TGHostCALayer

@interface TGHostCALayer : NSObject
@property (nonatomic, assign) CGFloat cornerRadius;
@property (nonatomic, assign) BOOL masksToBounds;
@property (nonatomic, assign) CGFloat borderWidth;
@end

typedef NS_OPTIONS(NSUInteger, UIViewAutoresizing) {
	UIViewAutoresizingNone = 0,
	UIViewAutoresizingFlexibleLeftMargin = 1 << 0,
	UIViewAutoresizingFlexibleWidth = 1 << 1,
	UIViewAutoresizingFlexibleRightMargin = 1 << 2,
	UIViewAutoresizingFlexibleTopMargin = 1 << 3,
	UIViewAutoresizingFlexibleHeight = 1 << 4,
	UIViewAutoresizingFlexibleBottomMargin = 1 << 5,
};

@interface UIView : NSObject
- (instancetype)initWithFrame:(CGRect)frame;
@property (nonatomic, readonly, strong) CALayer *layer;
@property (nonatomic, assign) UIViewContentMode contentMode;
@property (nonatomic, assign) CGRect frame;
@property (nonatomic, assign) CGRect bounds;
@property (nonatomic, assign) BOOL hidden;
@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic, assign) BOOL clipsToBounds;
@property (nonatomic, assign) BOOL opaque;
@property (nonatomic, assign) BOOL userInteractionEnabled;
@property (nonatomic, assign) UIViewAutoresizing autoresizingMask;
@property (nonatomic, strong, readonly) NSArray *subviews;
- (void)addSubview:(UIView *)view;
- (void)removeFromSuperview;
- (void)setNeedsDisplay;
- (void)setNeedsLayout;
- (void)layoutSubviews;
@end

@class UIFont;
@class UIImage;
@class UIColor;

@interface UIAlertView : UIView
@property (nonatomic, assign) id delegate;
@property (nonatomic, assign) NSInteger cancelButtonIndex;
@property (nonatomic, readonly, assign) BOOL dismissed;
- (void)dismissWithClickedButtonIndex:(NSInteger)index animated:(BOOL)animated;
@end

@interface UIActionSheet : UIView
@property (nonatomic, assign) id delegate;
@property (nonatomic, assign) NSInteger cancelButtonIndex;
@property (nonatomic, readonly, assign) BOOL dismissed;
- (void)dismissWithClickedButtonIndex:(NSInteger)index animated:(BOOL)animated;
@end

static const NSTextAlignment UITextAlignmentLeft = NSTextAlignmentLeft;
static const NSTextAlignment UITextAlignmentCenter = NSTextAlignmentCenter;
static const NSTextAlignment UITextAlignmentRight = NSTextAlignmentRight;

typedef NS_ENUM(NSInteger, UIActivityIndicatorViewStyle) {
	UIActivityIndicatorViewStyleWhiteLarge = 0,
	UIActivityIndicatorViewStyleWhite,
	UIActivityIndicatorViewStyleGray,
};

@interface UIActivityIndicatorView : UIView
- (instancetype)initWithActivityIndicatorStyle:(UIActivityIndicatorViewStyle)style;
@property (nonatomic, assign) BOOL hidesWhenStopped;
@property (nonatomic, readonly, assign) BOOL animating;
- (void)startAnimating;
- (void)stopAnimating;
@end

@interface UILabel : UIView
@property (nonatomic, assign) BOOL adjustsFontSizeToFitWidth;
@property (nonatomic, assign) CGFloat minimumFontSize;
@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) NSAttributedString *attributedText;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, strong) UIColor *highlightedTextColor;
@property (nonatomic, assign) BOOL highlighted;
@property (nonatomic, assign) NSInteger numberOfLines;
@property (nonatomic, assign) NSLineBreakMode lineBreakMode;
@property (nonatomic, assign) NSTextAlignment textAlignment;
@property (nonatomic, strong) UIColor *shadowColor;
@property (nonatomic, assign) CGSize shadowOffset;
- (void)drawTextInRect:(CGRect)rect;
- (CGSize)sizeThatFits:(CGSize)size;
@end

@interface UIButton : UIView
@end

typedef NS_ENUM(NSInteger, UITextBorderStyle) {
	UITextBorderStyleNone = 0,
	UITextBorderStyleLine,
	UITextBorderStyleBezel,
	UITextBorderStyleRoundedRect
};

@interface UITextField : UIView
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *placeholder;
@property (nonatomic, strong) NSAttributedString *attributedPlaceholder;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, assign) UITextBorderStyle borderStyle;
@end

@interface UIImageView : UIView
@property (nonatomic, strong) UIImage *image;
- (instancetype)initWithImage:(UIImage *)image;
@end

@interface UIScreen : NSObject
@property (nonatomic, readonly) CGFloat scale;
+ (UIScreen *)mainScreen;
@end

typedef NS_ENUM(NSInteger, UIUserInterfaceIdiom) {
	UIUserInterfaceIdiomPhone,
	UIUserInterfaceIdiomPad,
};

@interface UIDevice : NSObject
@property (nonatomic, readonly) NSString *systemVersion;
@property (nonatomic, readonly) NSString *model;
@property (nonatomic, readonly) UIUserInterfaceIdiom userInterfaceIdiom;
+ (UIDevice *)currentDevice;
@end

#define UI_USER_INTERFACE_IDIOM() ([[UIDevice currentDevice] userInterfaceIdiom])

@interface UIFont : NSObject

@property (nonatomic, readonly) CGFloat pointSize;
@property (nonatomic, readonly) BOOL isBold;
@property (nonatomic, readonly) BOOL isItalic;
@property (nonatomic, readonly) CGFloat lineHeight;
@property (nonatomic, readonly) CGFloat ascender;
@property (nonatomic, readonly) CGFloat descender;
@property (nonatomic, readonly) NSString *fontName;
@property (nonatomic, readonly) NSString *familyName;

+ (UIFont *)systemFontOfSize:(CGFloat)size;
+ (UIFont *)boldSystemFontOfSize:(CGFloat)size;
+ (UIFont *)italicSystemFontOfSize:(CGFloat)size;
+ (UIFont *)fontWithName:(NSString *)name size:(CGFloat)size;

@end

@interface UIImage : NSObject

@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) CGFloat tgHostScale;
@property (nonatomic, strong) NSData *tgHostPixelData;
@property (nonatomic, readonly) CGImageRef CGImage;

+ (UIImage *)imageNamed:(NSString *)name;
+ (UIImage *)imageWithContentsOfFile:(NSString *)path;
+ (UIImage *)imageWithData:(NSData *)data;
+ (UIImage *)imageWithData:(NSData *)data scale:(CGFloat)scale;
+ (UIImage *)tgHostImageWithPixelData:(NSData *)data;
+ (UIImage *)tgHostUndecodableImage;
- (UIImage *)resizableImageWithCapInsets:(UIEdgeInsets)insets;
- (UIImage *)stretchableImageWithLeftCapWidth:(NSInteger)left topCapHeight:(NSInteger)top;

@end

NSData *UIImagePNGRepresentation(UIImage *image);

extern NSString *const UIApplicationDidReceiveMemoryWarningNotification;
extern NSString *const UIApplicationDidEnterBackgroundNotification;

@interface UIBarButtonItem : NSObject
@end

@interface UITableView : UIView
@property (nonatomic, assign) NSInteger tgReloadCount;
- (void)reloadData;
@end

typedef NS_ENUM(NSInteger, UITableViewCellStyle) {
	UITableViewCellStyleDefault = 0,
	UITableViewCellStyleValue1,
	UITableViewCellStyleValue2,
	UITableViewCellStyleSubtitle,
};

typedef NS_ENUM(NSInteger, UITableViewCellAccessoryType) {
	UITableViewCellAccessoryNone = 0,
	UITableViewCellAccessoryDisclosureIndicator,
	UITableViewCellAccessoryDetailDisclosureButton,
	UITableViewCellAccessoryCheckmark,
};

typedef NS_ENUM(NSInteger, UITableViewCellSelectionStyle) {
	UITableViewCellSelectionStyleNone = 0,
	UITableViewCellSelectionStyleBlue,
	UITableViewCellSelectionStyleGray,
};

@interface UITableViewCell : UIView
@property (nonatomic, readonly, strong) UILabel *textLabel;
@property (nonatomic, readonly, strong) UILabel *detailTextLabel;
@property (nonatomic, readonly, strong) UIImageView *imageView;
@property (nonatomic, readonly, strong) UIView *contentView;
@property (nonatomic, strong) UIView *backgroundView;
@property (nonatomic, strong) UIView *selectedBackgroundView;
@property (nonatomic, strong) UIView *accessoryView;
@property (nonatomic, assign) UITableViewCellAccessoryType accessoryType;
@property (nonatomic, assign) UITableViewCellSelectionStyle selectionStyle;
@property (nonatomic, readonly, copy) NSString *reuseIdentifier;
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier;
- (void)prepareForReuse;
@end

@interface UINavigationBar : UIView
@end

@interface UISearchBar : UIView
@end

@interface UITabBar : UIView
@end

@interface NSValue (TGHostGeometry)
+ (NSValue *)valueWithCGRect:(CGRect)rect;
+ (NSValue *)valueWithCGSize:(CGSize)size;
- (CGRect)CGRectValue;
- (CGSize)CGSizeValue;
@end

@interface UIColor : NSObject

@property (nonatomic, readonly) CGColorRef CGColor;
@property (nonatomic, strong) UIImage *patternImage;

- (void)set;
- (void)setFill;
- (void)setStroke;

+ (UIColor *)clearColor;
+ (UIColor *)whiteColor;
+ (UIColor *)blackColor;
+ (UIColor *)grayColor;
+ (UIColor *)darkGrayColor;
+ (UIColor *)lightGrayColor;
+ (UIColor *)redColor;
+ (UIColor *)blueColor;
+ (UIColor *)colorWithWhite:(CGFloat)white alpha:(CGFloat)alpha;
+ (UIColor *)colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
+ (UIColor *)colorWithCGColor:(CGColorRef)color;
+ (UIColor *)colorWithPatternImage:(UIImage *)image;
- (UIColor *)colorWithAlphaComponent:(CGFloat)alpha;
- (BOOL)getRed:(CGFloat *)red green:(CGFloat *)green blue:(CGFloat *)blue alpha:(CGFloat *)alpha;
@end

@interface NSString (TGHostTextMetrics)

- (CGSize)sizeWithFont:(UIFont *)font;
- (CGSize)sizeWithFont:(UIFont *)font
	 constrainedToSize:(CGSize)limit
		 lineBreakMode:(NSLineBreakMode)mode;

@end

CGFloat TGHostTextWidthPerPoint(void);
void TGHostSetNamedImageSize(NSString *name, CGSize size);

extern NSString *const NSFontAttributeName;
extern NSString *const NSForegroundColorAttributeName;
extern NSString *const NSParagraphStyleAttributeName;

@interface NSString (TGHostDrawing)
- (void)drawInRect:(CGRect)rect withFont:(UIFont *)font lineBreakMode:(NSLineBreakMode)mode;
- (void)drawInRect:(CGRect)rect withFont:(UIFont *)font lineBreakMode:(NSLineBreakMode)mode alignment:(NSTextAlignment)alignment;
- (void)drawAtPoint:(CGPoint)point withFont:(UIFont *)font;
@end

@interface UIBezierPath : NSObject

@property (nonatomic, assign) CGFloat lineWidth;
@property (nonatomic, assign) CGLineCap lineCapStyle;
@property (nonatomic, assign) CGLineJoin lineJoinStyle;
@property (nonatomic, readonly) CGPathRef CGPath;
@property (nonatomic, readonly) CGMutablePathRef hostMutablePath;

+ (UIBezierPath *)bezierPath;
+ (UIBezierPath *)bezierPathWithRect:(CGRect)rect;
+ (UIBezierPath *)bezierPathWithOvalInRect:(CGRect)rect;
+ (UIBezierPath *)bezierPathWithRoundedRect:(CGRect)rect cornerRadius:(CGFloat)radius;
- (void)moveToPoint:(CGPoint)point;
- (void)addLineToPoint:(CGPoint)point;
- (void)closePath;
- (void)fill;
- (void)stroke;
- (void)addClip;

@end

CGContextRef UIGraphicsGetCurrentContext(void);
void UIGraphicsBeginImageContextWithOptions(CGSize size, BOOL opaque, CGFloat scale);
UIImage *UIGraphicsGetImageFromCurrentImageContext(void);
void UIGraphicsEndImageContext(void);
void UIGraphicsPushContext(CGContextRef context);
void UIGraphicsPopContext(void);

#endif

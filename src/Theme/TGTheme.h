#import <UIKit/UIKit.h>
#import "TGThemeGeometry.h"
#import "TGHexColour.h"

UIImage *TGBoxBlurredImage(UIImage *image);

UIImage *TGCompositeWallpaperPattern(UIImage *fill, UIImage *pattern, NSInteger intensity, BOOL isInverted);

@interface TGTheme : NSObject

+ (instancetype)shared;

extern NSString *const TGThemeChangedNotification;

@property (nonatomic, assign) CGFloat messageFontSize;

+ (NSArray *)messageFontSizes;
+ (CGFloat)defaultMessageFontSize;
+ (UIColor *)folderTagColourForColourId:(NSInteger)colourId;

@property (nonatomic, assign) NSUInteger messageFontStep;

@property (nonatomic, readonly) CGFloat listFontDelta;

#pragma mark - wallpaper

- (UIImage *)wallpaper;

- (void)setWallpaperImage:(UIImage *)image;

- (BOOL)applyBuiltinWallpaperNamed:(NSString *)name;

@property (nonatomic, copy) NSString *builtinWallpaperName;

@property (nonatomic, copy) NSString *defaultBackgroundId;

+ (void)resetDefaultBackgroundIdForAccountSwitch;

#pragma mark - palette

- (UIColor *)barColour;
- (UIColor *)barTitleColour;
- (UIColor *)barTitleShadowColour;
- (UIColor *)accentColour;
- (UIColor *)chatBackgroundColour;
- (UIColor *)bubbleMineColour;
- (UIColor *)bubbleTheirsColour;
- (UIColor *)bubbleBorderColour;
- (UIColor *)listBackgroundColour;
- (UIColor *)primaryTextColour;
- (UIColor *)secondaryTextColour;
- (UIColor *)inputBarColour;
- (UIColor *)cellDetailColour;

#pragma mark - media and file blocks

- (UIColor *)fileTileColour;
- (UIColor *)mediaCircleColour;
- (UIColor *)fileNameColour;
- (UIColor *)fileMetaColour;
- (UIColor *)mediaStampColour;

#pragma mark - chat list

- (UIColor *)typingColour;
- (UIColor *)onlineColour;
- (UIColor *)separatorColour;
- (UIColor *)groupedSeparatorColour;

#pragma mark - grouped footers

- (CGFloat)groupedCommentHeightForText:(NSString *)text width:(CGFloat)width;
- (UIView *)groupedCommentViewWithText:(NSString *)text width:(CGFloat)width;

#pragma mark - grouped section headers

- (CGFloat)groupedHeaderHeightForTitle:(NSString *)title;
- (UIView *)groupedHeaderViewWithTitle:(NSString *)title width:(CGFloat)width;

#pragma mark - grouped rows

- (UIColor *)groupedTitleColour;
- (UIColor *)groupedActionColour;
- (UIColor *)groupedDestructiveColour;
- (UIColor *)groupedInfoColour;
- (UIColor *)groupedDisabledColour;
- (UIColor *)emptyStateColour;

#pragma mark - service messages

- (UIColor *)serviceTextColour;

- (CGFloat)bubbleCornerRadius;
- (CGFloat)mediaCornerRadius;
- (CGFloat)bubbleBorderWidth;

- (void)styleCell:(UITableViewCell *)cell;

- (void)styleNavigationBar:(UINavigationBar *)bar;
- (void)restyleNavigationBar:(UINavigationBar *)bar;

- (void)styleTabBar:(UITabBar *)bar;

@end

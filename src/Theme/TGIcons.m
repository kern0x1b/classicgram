#import "TGLocalization.h"
#import "TGGroupedCaption.h"
#import "TGIcons.h"
#import "TGIconsInternal.h"
#import "TGHexColour.h"
#import "TGTheme.h"

static const NSInteger kTGActionRowButtonTag = 7710;

@interface TGHeaderButton : UIButton
@end

@implementation TGHeaderButton

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
	return CGRectContainsPoint(CGRectInset(self.bounds, -8, -8), point);
}

@end

NSMutableDictionary *sCache = nil;
NSCache *sAvatarCache = nil;

UIImage *TGArtwork(NSString *name) {
	return [UIImage imageNamed:name];
}

UIImage *TGArtworkTemplate(NSString *name) {
	UIImage *image = [UIImage imageNamed:name];
	if (image && [image respondsToSelector:@selector(imageWithRenderingMode:)])
		image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	return image;
}

UIImage *TGArtworkMasked(NSString *name, UIColor *colour, CGSize target) {
	UIImage *src = [UIImage imageNamed:name];
	if (!src || src.size.width < 1 || src.size.height < 1)
		return nil;

	CGSize size = target.width > 0 && target.height > 0 ? target : src.size;
	UIGraphicsBeginImageContextWithOptions(size, NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGRect rect = CGRectMake(0, 0, size.width, size.height);

	CGContextTranslateCTM(ctx, 0, size.height);
	CGContextScaleCTM(ctx, 1, -1);
	CGContextClipToMask(ctx, rect, src.CGImage);
	[colour set];
	CGContextFillRect(ctx, rect);

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

NSCache *TGAvatarCache(void) {
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		sAvatarCache = [[NSCache alloc] init];
		sAvatarCache.countLimit = 64;
		sAvatarCache.totalCostLimit = 1536 * 1024;
	});
	return sAvatarCache;
}

@implementation TGIcons

+ (void)load {
	@autoreleasepool {
		[[NSNotificationCenter defaultCenter]
			addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
						object:nil
						 queue:[NSOperationQueue mainQueue]
					usingBlock:^(NSNotification *note) {
						[TGIcons flush];
					}];
	}
}

+ (void)flush {
	[sCache removeAllObjects];
	[TGAvatarCache() removeAllObjects];
	[TGWaveformHeightCache() removeAllObjects];
}

+ (void)styleHeaderButton:(UIButton *)button {
	[self styleHeaderButton:button done:NO];
}

static const CGFloat kHeaderPlateHeight = 30.0f;

static CGFloat TGHeaderPlateLabelLift(void) {
	return [UIScreen mainScreen].scale > 1.5f ? -1.0f : 0.0f;
}

+ (void)styleHeaderButton:(UIButton *)button done:(BOOL)done {
	static UIImage *bg = nil;
	static UIImage *bgPressed = nil;
	static UIImage *bgDone = nil;
	static UIImage *bgDonePressed = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		bg = [[UIImage imageNamed:@"HeaderButton"] stretchableImageWithLeftCapWidth:6 topCapHeight:0];
		bgPressed = [[UIImage imageNamed:@"HeaderButton_Pressed"] stretchableImageWithLeftCapWidth:6 topCapHeight:0];

		UIImage *rawDone = [UIImage imageNamed:@"HeaderButton_Blue"];
		UIImage *rawDonePressed = [UIImage imageNamed:@"HeaderButton_Blue_Pressed"];
		bgDone = [rawDone stretchableImageWithLeftCapWidth:(int)(rawDone.size.width / 2) topCapHeight:0];
		bgDonePressed = [rawDonePressed stretchableImageWithLeftCapWidth:(int)(rawDonePressed.size.width / 2) topCapHeight:0];
	});

	UIImage *normal = (done && bgDone) ? bgDone : bg;
	UIImage *pressed = (done && bgDonePressed) ? bgDonePressed : bgPressed;
	[button setBackgroundImage:normal forState:UIControlStateNormal];
	[button setBackgroundImage:pressed forState:UIControlStateHighlighted];
}

+ (UIButton *)headerButtonWithTitle:(NSString *)title bold:(BOOL)bold
							 target:(id)target
							 action:(SEL)action {
	UIButton *button = [[TGHeaderButton alloc] initWithFrame:CGRectZero];
	button.exclusiveTouch = YES;
	button.adjustsImageWhenDisabled = NO;
	button.adjustsImageWhenHighlighted = NO;
	[self styleHeaderButton:button done:bold];
	[button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];

	UIFont *font = [UIFont boldSystemFontOfSize:12];
	CGSize size = [title sizeWithFont:font];
	button.frame = CGRectMake(0, 0, size.width + 14, kHeaderPlateHeight);

	UILabel *label = [[UILabel alloc] initWithFrame:
			CGRectOffset(button.bounds, 0, TGHeaderPlateLabelLift())];
	label.text = title;
	label.textColor = [UIColor whiteColor];
	label.shadowColor = bold
		? [UIColor colorWithRed:0x04 / 255.0f green:0x26 / 255.0f blue:0x51 / 255.0f alpha:0.3f]
		: [UIColor colorWithRed:0x0e / 255.0f green:0x28 / 255.0f blue:0x4d / 255.0f alpha:0.4f];
	label.shadowOffset = CGSizeMake(0, -1);
	label.textAlignment = NSTextAlignmentCenter;
	label.backgroundColor = [UIColor clearColor];
	label.font = font;
	label.userInteractionEnabled = NO;
	[button addSubview:label];

	return button;
}

+ (UIButton *)backButtonWithTitle:(NSString *)title target:(id)target action:(SEL)action {
	static UIImage *plate = nil;
	static UIImage *platePressed = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		plate = [[UIImage imageNamed:@"BackButton"] stretchableImageWithLeftCapWidth:15 topCapHeight:0];
		platePressed = [[UIImage imageNamed:@"BackButton_Pressed"]
			stretchableImageWithLeftCapWidth:15
								topCapHeight:0];
	});

	UIButton *button = [[TGHeaderButton alloc] initWithFrame:CGRectZero];
	button.exclusiveTouch = YES;
	button.adjustsImageWhenDisabled = NO;
	button.adjustsImageWhenHighlighted = NO;
	[button setBackgroundImage:plate forState:UIControlStateNormal];
	[button setBackgroundImage:platePressed forState:UIControlStateHighlighted];
	[button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];

	static const CGFloat kArrowInset = 14.0f;
	static const CGFloat kTailInset = 7.0f;
	UIFont *font = [UIFont boldSystemFontOfSize:12];
	CGSize size = [title sizeWithFont:font];
	button.frame = CGRectMake(0, 0, size.width + kArrowInset + kTailInset, kHeaderPlateHeight);

	UILabel *label = [[UILabel alloc] initWithFrame:
			CGRectMake(kArrowInset, TGHeaderPlateLabelLift(), size.width, kHeaderPlateHeight)];
	label.text = title;
	label.textColor = [UIColor whiteColor];
	label.shadowColor = [UIColor colorWithRed:0x0e / 255.0f green:0x28 / 255.0f
										 blue:0x4d / 255.0f
										alpha:0.4f];
	label.shadowOffset = CGSizeMake(0, -1);
	label.textAlignment = NSTextAlignmentCenter;
	label.backgroundColor = [UIColor clearColor];
	label.font = font;
	label.userInteractionEnabled = NO;
	[button addSubview:label];

	return button;
}

+ (UIBarButtonItem *)backBarButtonItemWithTitle:(NSString *)title
										 target:(id)target
										 action:(SEL)action {
	return [[UIBarButtonItem alloc] initWithCustomView:
			[self backButtonWithTitle:title target:target action:action]];
}

static const NSInteger kTGBackButtonBadgeContainerTag = 894612001;
static const NSInteger kTGBackButtonBadgeImageTag = 894612002;
static const NSInteger kTGBackButtonBadgeLabelTag = 894612003;

+ (void)setUnreadCount:(NSInteger)count onBackButton:(UIButton *)backButton {
	if (!backButton)
		return;

	UIView *container = [backButton viewWithTag:kTGBackButtonBadgeContainerTag];
	if (count <= 0) {
		container.hidden = true;
		return;
	}

	static UIImage *badgeBackground = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		badgeBackground = [[UIImage imageNamed:@"ConversationUnreadBadge"]
			stretchableImageWithLeftCapWidth:12
								topCapHeight:0];
	});
	CGFloat badgeHeight = badgeBackground.size.height;

	if (!container) {
		container = [[UIView alloc] initWithFrame:
				CGRectMake(backButton.bounds.size.width - 13, -7, badgeHeight, badgeHeight)];
		container.tag = kTGBackButtonBadgeContainerTag;
		container.userInteractionEnabled = false;
		container.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[backButton addSubview:container];

		UIImageView *badge = [[UIImageView alloc] initWithImage:badgeBackground];
		badge.tag = kTGBackButtonBadgeImageTag;
		[container addSubview:badge];

		UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
		label.tag = kTGBackButtonBadgeLabelTag;
		label.backgroundColor = [UIColor clearColor];
		label.textColor = [UIColor whiteColor];
		label.font = [UIFont boldSystemFontOfSize:12];
		label.textAlignment = NSTextAlignmentCenter;
		[container addSubview:label];
	}

	UIImageView *badge = (UIImageView *)[container viewWithTag:kTGBackButtonBadgeImageTag];
	UILabel *label = (UILabel *)[container viewWithTag:kTGBackButtonBadgeLabelTag];

	NSString *text;
	if (count < 1000)
		text = [NSString stringWithFormat:@"%ld", (long)count];
	else if (count < 1000000)
		text = [NSString stringWithFormat:@"%ldK", (long)(count / 1000)];
	else
		text = [NSString stringWithFormat:@"%ldM", (long)(count / 1000000)];

	label.text = text;
	container.hidden = false;

	CGFloat textWidth = ceilf([text sizeWithFont:label.font
							   constrainedToSize:CGSizeMake(200, badgeHeight)
								   lineBreakMode:NSLineBreakByTruncatingTail]
			.width);
	CGFloat badgeWidth = MAX(badgeHeight, textWidth + 18);

	badge.frame = CGRectMake(container.bounds.size.width - badgeWidth, 0, badgeWidth, badgeHeight);
	label.frame = CGRectMake(badge.frame.origin.x + (badgeWidth - textWidth) / 2.0f,
		(badgeHeight - 14) / 2.0f, textWidth, 14);
}

+ (UIBarButtonItem *)headerBarButtonItemWithTitle:(NSString *)title
											 bold:(BOOL)bold
										   target:(id)target
										   action:(SEL)action {
	return [[UIBarButtonItem alloc] initWithCustomView:
			[self headerButtonWithTitle:title bold:bold target:target action:action]];
}

+ (UIButton *)actionButtonWithTitle:(NSString *)title
							   kind:(TGActionButtonKind)kind
							 target:(id)target
							 action:(SEL)action {
	BOOL destructive = (kind == TGActionButtonKindDestructive);
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.titleLabel.font = [UIFont boldSystemFontOfSize:17];
	button.titleLabel.shadowOffset = CGSizeMake(0, destructive ? -1 : 1);
	button.adjustsImageWhenHighlighted = NO;
	button.adjustsImageWhenDisabled = NO;
	button.exclusiveTouch = YES;
	[button setTitle:title forState:UIControlStateNormal];

	if (destructive) {
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
		[button setTitleShadowColor:[UIColor colorWithRed:0xa1 / 255.0f
													green:0x06 / 255.0f
													 blue:0x03 / 255.0f
													alpha:0.5f]
						   forState:UIControlStateNormal];
	} else {
		[button setTitleColor:TGColourFromHex(0x4a6587) forState:UIControlStateNormal];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
		[button setTitleShadowColor:[UIColor colorWithWhite:1.0f alpha:0.45f]
						   forState:UIControlStateNormal];
		[button setTitleShadowColor:[UIColor clearColor] forState:UIControlStateHighlighted];
	}

	NSString *plate = destructive ? @"MenuRedButton.png" : @"GroupedActionButton.png";
	NSString *platePressed = destructive ? @"MenuRedButton_Highlighted.png"
										 : @"GroupedActionButton_Highlighted.png";
	UIImage *raw = [UIImage imageNamed:plate];
	UIImage *rawPressed = [UIImage imageNamed:platePressed];
	if (raw)
		[button setBackgroundImage:[raw stretchableImageWithLeftCapWidth:(int)(raw.size.width / 2)
														   topCapHeight:0]
						  forState:UIControlStateNormal];
	if (rawPressed)
		[button setBackgroundImage:[rawPressed
				stretchableImageWithLeftCapWidth:(int)(rawPressed.size.width / 2) topCapHeight:0]
						  forState:UIControlStateHighlighted];
	if (!raw)
		button.backgroundColor = destructive
			? [[TGTheme shared] groupedDestructiveColour]
			: [[TGTheme shared] listBackgroundColour];

	if (target && action)
		[button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
	return button;
}

+ (CGFloat)actionRowHeight {
	return TGActionRowHeight();
}

+ (void)removeActionButtonFromCell:(UITableViewCell *)cell {
	UIView *button = [cell.contentView viewWithTag:kTGActionRowButtonTag];
	if (!button)
		return;
	[button removeFromSuperview];
	cell.backgroundView = nil;
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	[[TGTheme shared] styleCell:cell];
}

+ (void)setActionButton:(UIButton *)button enabled:(BOOL)enabled {
	button.enabled = enabled;
	button.alpha = enabled ? 1.0f : 0.7f;
}

+ (UIButton *)actionButtonInCell:(UITableViewCell *)cell
						   title:(NSString *)title
							kind:(TGActionButtonKind)kind
						  target:(id)target
						  action:(SEL)action {
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.textLabel.text = nil;
	cell.detailTextLabel.text = nil;
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.accessoryView = nil;
	cell.backgroundColor = [UIColor clearColor];
	cell.contentView.backgroundColor = [UIColor clearColor];
	cell.backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
	cell.backgroundView.backgroundColor = [UIColor clearColor];

	UIButton *button = (UIButton *)[cell.contentView viewWithTag:kTGActionRowButtonTag];
	if (![button isKindOfClass:[UIButton class]]) {
		button = [self actionButtonWithTitle:title kind:kind target:target action:action];
		button.tag = kTGActionRowButtonTag;
		[cell.contentView addSubview:button];
	} else {
		[button setTitle:title forState:UIControlStateNormal];
	}
	button.frame = TGActionRowButtonFrame(cell.contentView.bounds.size.width);
	button.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	button.transform = TGLocalizedIsRTL() ? CGAffineTransformMakeScale(-1, 1)
										  : CGAffineTransformIdentity;
	return button;
}

+ (UIImage *)iconNamed:(NSString *)name draw:(void (^)(CGContextRef ctx, CGFloat s))draw {
	if (!sCache)
		sCache = [NSMutableDictionary dictionary];

	NSString *key = name;
	UIImage *cached = sCache[key];
	if (cached)
		return cached;

	CGFloat side = 28;
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();

	CGContextSaveGState(ctx);
	CGContextTranslateCTM(ctx, 0, 1);
	CGContextSetRGBFillColor(ctx, 1, 1, 1, 0.55f);
	CGContextSetRGBStrokeColor(ctx, 1, 1, 1, 0.55f);
	draw(ctx, side);
	CGContextRestoreGState(ctx);

	CGContextSetRGBFillColor(ctx, 0, 0, 0, 1);
	CGContextSetRGBStrokeColor(ctx, 0, 0, 0, 1);
	draw(ctx, side);

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	if ([image respondsToSelector:@selector(imageWithRenderingMode:)])
		image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

	sCache[key] = image;
	return image;
}

@end

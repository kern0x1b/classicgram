#import "TGIconsInternal.h"

static CGFloat TGAvatarCornerRadius(CGFloat side) {
	if (fabs(side - 70) < 0.5f)
		return 9;
	if (fabs(side - 56) < 0.5f)
		return 5;
	if (fabs(side - 40) < 0.5f)
		return 4;
	if (fabs(side - 30) < 0.5f)
		return 3;
	return roundf(side * 0.09f);
}

static BOOL TGInitialsAreName(NSString *initials) {
	if (initials.length == 0)
		return YES;
	if ([initials isEqualToString:@"★"])
		return YES;
	NSCharacterSet *letters = [NSCharacterSet alphanumericCharacterSet];
	for (NSInteger i = 0; i < initials.length; i++) {
		if ([letters characterIsMember:[initials characterAtIndex:i]])
			return YES;
	}
	return NO;
}

static NSUInteger TGImageByteCost(UIImage *image) {
	CGFloat scale = image.scale > 0 ? image.scale : 1.0f;
	CGFloat w = image.size.width * scale;
	CGFloat h = image.size.height * scale;
	if (w < 1)
		w = 1;
	if (h < 1)
		h = 1;
	return (NSUInteger)(w * h * 4.0f);
}

static UIImage *TGGlyphAvatar(CGFloat side, void (^draw)(CGContextRef ctx, CGFloat s)) {
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();

	UIBezierPath *shape = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, side, side) cornerRadius:TGAvatarCornerRadius(side)];
	CGContextSetRGBFillColor(ctx, 0x0f / 255.0f, 0x94 / 255.0f, 0xed / 255.0f, 1.0f);
	CGContextAddPath(ctx, shape.CGPath);
	CGContextFillPath(ctx);

	CGContextSetRGBFillColor(ctx, 1, 1, 1, 1);
	CGContextSetRGBStrokeColor(ctx, 1, 1, 1, 1);
	draw(ctx, side);

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

@implementation TGIcons (Avatars)

+ (UIImage *)archiveAvatarOfSide:(CGFloat)side {
	return TGGlyphAvatar(side, ^(CGContextRef ctx, CGFloat s) {
		CGFloat w = s * 0.46f, x = (s - w) / 2;
		CGContextFillRect(ctx, CGRectMake(x, s * 0.32f, w, s * 0.10f));
		CGContextFillRect(ctx, CGRectMake(x + s * 0.03f, s * 0.44f, w - s * 0.06f, s * 0.24f));
		CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.25f);
		CGContextFillRect(ctx, CGRectMake(s * 0.44f, s * 0.50f, s * 0.12f, s * 0.05f));
	});
}

+ (UIImage *)savedMessagesAvatarOfSide:(CGFloat)side {
	return TGGlyphAvatar(side, ^(CGContextRef ctx, CGFloat s) {
		CGContextMoveToPoint(ctx, s * 0.36f, s * 0.30f);
		CGContextAddLineToPoint(ctx, s * 0.64f, s * 0.30f);
		CGContextAddLineToPoint(ctx, s * 0.64f, s * 0.70f);
		CGContextAddLineToPoint(ctx, s * 0.50f, s * 0.58f);
		CGContextAddLineToPoint(ctx, s * 0.36f, s * 0.70f);
		CGContextClosePath(ctx);
		CGContextFillPath(ctx);
	});
}

+ (UIImage *)myNotesAvatarOfSide:(CGFloat)side {
	return TGGlyphAvatar(side, ^(CGContextRef ctx, CGFloat s) {
		CGContextSetLineWidth(ctx, MAX(1.0f, s * 0.045f));
		CGContextSetLineCap(ctx, kCGLineCapRound);
		CGContextSetLineJoin(ctx, kCGLineJoinRound);

		CGContextMoveToPoint(ctx, s * 0.28f, s * 0.72f);
		CGContextAddLineToPoint(ctx, s * 0.31f, s * 0.60f);
		CGContextAddLineToPoint(ctx, s * 0.62f, s * 0.29f);
		CGContextAddLineToPoint(ctx, s * 0.73f, s * 0.40f);
		CGContextAddLineToPoint(ctx, s * 0.42f, s * 0.71f);
		CGContextClosePath(ctx);
		CGContextFillPath(ctx);

		CGContextMoveToPoint(ctx, s * 0.27f, s * 0.78f);
		CGContextAddLineToPoint(ctx, s * 0.74f, s * 0.78f);
		CGContextStrokePath(ctx);
	});
}

+ (UIImage *)hiddenAuthorAvatarOfSide:(CGFloat)side {
	return TGGlyphAvatar(side, ^(CGContextRef ctx, CGFloat s) {
		CGContextFillRect(ctx, CGRectMake(s * 0.36f, s * 0.20f, s * 0.28f, s * 0.16f));
		CGContextFillRect(ctx, CGRectMake(s * 0.20f, s * 0.36f, s * 0.60f, s * 0.06f));

		CGContextSaveGState(ctx);
		CGContextClipToRect(ctx, CGRectMake(0, 0, s, s * 0.80f));
		CGContextFillEllipseInRect(ctx, CGRectMake(s * 0.22f, s * 0.56f, s * 0.56f, s * 0.34f));
		CGContextRestoreGState(ctx);

		CGContextFillEllipseInRect(ctx, CGRectMake(s * 0.29f, s * 0.44f, s * 0.16f, s * 0.10f));
		CGContextFillEllipseInRect(ctx, CGRectMake(s * 0.55f, s * 0.44f, s * 0.16f, s * 0.10f));
		CGContextFillRect(ctx, CGRectMake(s * 0.44f, s * 0.47f, s * 0.12f, s * 0.03f));
	});
}

+ (UIImage *)generalTopicAvatarOfSide:(CGFloat)side {
	return TGGlyphAvatar(side, ^(CGContextRef ctx, CGFloat s) {
		CGFloat barHeight = MAX(1.0f, s * 0.085f);
		CGFloat leftX = s * 0.28f;
		CGFloat width = s * 0.44f;
		CGContextFillRect(ctx, CGRectMake(leftX, s * 0.32f, width, barHeight));
		CGContextFillRect(ctx, CGRectMake(leftX, s * 0.46f, width, barHeight));
		CGContextFillRect(ctx, CGRectMake(leftX, s * 0.60f, width * 0.6f, barHeight));
	});
}

static void TGDrawAvatarSilhouette(CGContextRef ctx, CGFloat size, uint32_t ink) {
	CGContextSetRGBFillColor(ctx,
		((ink >> 16) & 0xff) / 255.0f,
		((ink >> 8) & 0xff) / 255.0f,
		(ink & 0xff) / 255.0f, 1.0f);

	CGContextSaveGState(ctx);
	CGContextClipToRect(ctx, CGRectMake(0, 0, size, size * 0.795f));
	CGContextFillEllipseInRect(ctx, CGRectMake(size * 0.357f, size * 0.170f, size * 0.268f, size * 0.339f));
	CGContextFillEllipseInRect(ctx, CGRectMake(size * 0.143f, size * 0.595f, size * 0.714f, size * 0.400f));
	CGContextRestoreGState(ctx);
}

static void TGDrawAvatarInitials(NSString *text, CGFloat size) {
	UIFont *font = [UIFont boldSystemFontOfSize:size * 0.4f];
	CGSize textSize = [text sizeWithFont:font];
	[[UIColor whiteColor] set];
	[text drawAtPoint:CGPointMake((size - textSize.width) / 2,
						  (size - textSize.height) / 2)
			 withFont:font];
}

static BOOL TGAvatarIsServiceAccount(int64_t colourId) {
	return colourId == 777000LL || colourId == 333000LL;
}

static UIImage *TGServiceAvatarPlate(CGFloat size) {
	NSString *cacheKey = [NSString stringWithFormat:@"service-%d", (int)(size * 100)];
	UIImage *cached = [TGAvatarCache() objectForKey:cacheKey];
	if (cached)
		return cached;

	NSString *name = size <= 56.0f ? @"DialogListAvatarSystem.png" : @"ProfileAvatarSystem.png";
	UIImage *source = [UIImage imageNamed:name]
		?: [UIImage imageNamed:@"ProfileAvatarSystem.png"];
	if (!source)
		return nil;

	UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();

	UIBezierPath *shape = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size, size) cornerRadius:TGAvatarCornerRadius(size)];
	CGContextSaveGState(ctx);
	CGContextAddPath(ctx, shape.CGPath);
	CGContextClip(ctx);
	CGContextSetRGBFillColor(ctx, 0x2f / 255.0f, 0x9e / 255.0f, 0xda / 255.0f, 1.0f);
	CGContextFillRect(ctx, CGRectMake(0, 0, size, size));
	[source drawInRect:CGRectMake(0, 0, size, size)];
	CGContextRestoreGState(ctx);

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	if (image)
		[TGAvatarCache() setObject:image forKey:cacheKey cost:TGImageByteCost(image)];
	return image;
}

+ (UIImage *)avatarWithInitials:(NSString *)initials
						   size:(CGFloat)size
					   colourId:(int64_t)colourId {
	if (TGAvatarIsServiceAccount(colourId)) {
		UIImage *service = TGServiceAvatarPlate(size);
		if (service)
			return service;
	}

	static const uint32_t plate[8] = {
		0xed650b, 0x4abc0d, 0xffc600, 0x2f92e9,
		0xa054fe, 0xfb2e6a, 0x06a6c8, 0xde3f12};
	static const uint32_t ink[8] = {
		0xaf3600, 0x088202, 0xe36008, 0x0854b7,
		0x6915b7, 0xad0055, 0x006785, 0x8a1e00};
	NSInteger slot = (NSUInteger)(llabs(colourId) % 8);
	uint32_t fill = plate[slot];

	NSString *cacheKey = [NSString stringWithFormat:@"%@-%d-%u",
		TGInitialsAreName(initials) ? initials : @"*", (int)(size * 100),
		(unsigned)slot];
	UIImage *cachedAvatar = [TGAvatarCache() objectForKey:cacheKey];
	if (cachedAvatar)
		return cachedAvatar;

	UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();

	UIBezierPath *shape = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size, size) cornerRadius:TGAvatarCornerRadius(size)];
	CGContextSetRGBFillColor(ctx, ((fill >> 16) & 0xff) / 255.0f,
		((fill >> 8) & 0xff) / 255.0f,
		(fill & 0xff) / 255.0f, 1.0f);
	CGContextAddPath(ctx, shape.CGPath);
	CGContextFillPath(ctx);

	CGContextSaveGState(ctx);
	CGContextAddPath(ctx, shape.CGPath);
	CGContextClip(ctx);

	if (TGInitialsAreName(initials))
		TGDrawAvatarInitials(initials, size);
	else
		TGDrawAvatarSilhouette(ctx, size, ink[slot]);
	CGContextRestoreGState(ctx);

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	if (image)
		[TGAvatarCache() setObject:image forKey:cacheKey cost:TGImageByteCost(image)];
	return image;
}

@end

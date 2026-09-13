#import "TGIconsInternal.h"

static void TGMenuDrawReply(CGContextRef ctx, CGFloat s, CGFloat m) {
	CGContextMoveToPoint(ctx, m + 5, s * 0.30f);
	CGContextAddLineToPoint(ctx, m, s * 0.45f);
	CGContextAddLineToPoint(ctx, m + 5, s * 0.60f);
	CGContextStrokePath(ctx);
	CGContextMoveToPoint(ctx, m, s * 0.45f);
	CGContextAddLineToPoint(ctx, s - m - 5, s * 0.45f);
	CGContextAddArc(ctx, s - m - 5, s * 0.62f, s * 0.17f, -M_PI_2, 0, 0);
	CGContextStrokePath(ctx);
}

static void TGMenuDrawForward(CGContextRef ctx, CGFloat s, CGFloat m) {
	CGContextMoveToPoint(ctx, s - m - 5, s * 0.30f);
	CGContextAddLineToPoint(ctx, s - m, s * 0.45f);
	CGContextAddLineToPoint(ctx, s - m - 5, s * 0.60f);
	CGContextStrokePath(ctx);
	CGContextMoveToPoint(ctx, s - m, s * 0.45f);
	CGContextAddLineToPoint(ctx, m + 5, s * 0.45f);
	CGContextAddArc(ctx, m + 5, s * 0.62f, s * 0.17f, -M_PI_2, M_PI, 1);
	CGContextStrokePath(ctx);
}

static void TGMenuDrawCopy(CGContextRef ctx, CGFloat s, CGFloat m) {
	CGContextStrokeRect(ctx, CGRectMake(m, m, s * 0.46f, s * 0.46f));
	CGContextStrokeRect(ctx, CGRectMake(s * 0.34f, s * 0.34f, s * 0.46f, s * 0.46f));
}

static void TGMenuDrawEdit(CGContextRef ctx, CGFloat s, CGFloat m) {
	CGContextMoveToPoint(ctx, m, s - m);
	CGContextAddLineToPoint(ctx, m + s * 0.10f, s - m - s * 0.16f);
	CGContextAddLineToPoint(ctx, s - m - s * 0.06f, m + s * 0.06f);
	CGContextAddLineToPoint(ctx, s - m, m + s * 0.16f);
	CGContextAddLineToPoint(ctx, m + s * 0.20f, s - m - s * 0.06f);
	CGContextClosePath(ctx);
	CGContextStrokePath(ctx);
}

static void TGMenuDrawDelete(CGContextRef ctx, CGFloat s, CGFloat m) {
	CGContextMoveToPoint(ctx, m, s * 0.30f);
	CGContextAddLineToPoint(ctx, s - m, s * 0.30f);
	CGContextStrokePath(ctx);
	CGContextMoveToPoint(ctx, s * 0.40f, s * 0.30f);
	CGContextAddLineToPoint(ctx, s * 0.40f, s * 0.22f);
	CGContextAddLineToPoint(ctx, s * 0.60f, s * 0.22f);
	CGContextAddLineToPoint(ctx, s * 0.60f, s * 0.30f);
	CGContextStrokePath(ctx);
	CGContextMoveToPoint(ctx, m + 2, s * 0.30f);
	CGContextAddLineToPoint(ctx, m + 4, s - m);
	CGContextAddLineToPoint(ctx, s - m - 4, s - m);
	CGContextAddLineToPoint(ctx, s - m - 2, s * 0.30f);
	CGContextStrokePath(ctx);
}

static void TGMenuDrawPin(CGContextRef ctx, CGFloat s, CGFloat m) {
	CGContextMoveToPoint(ctx, s * 0.34f, m);
	CGContextAddLineToPoint(ctx, s * 0.66f, m);
	CGContextAddLineToPoint(ctx, s * 0.58f, s * 0.46f);
	CGContextAddLineToPoint(ctx, s * 0.76f, s * 0.60f);
	CGContextAddLineToPoint(ctx, s * 0.24f, s * 0.60f);
	CGContextAddLineToPoint(ctx, s * 0.42f, s * 0.46f);
	CGContextClosePath(ctx);
	CGContextStrokePath(ctx);
	CGContextMoveToPoint(ctx, s / 2, s * 0.60f);
	CGContextAddLineToPoint(ctx, s / 2, s - m);
	CGContextStrokePath(ctx);
}

static void TGMenuDrawCheck(CGContextRef ctx, CGFloat s, CGFloat m) {
	CGContextMoveToPoint(ctx, m, s * 0.54f);
	CGContextAddLineToPoint(ctx, s * 0.40f, s - m * 1.4f);
	CGContextAddLineToPoint(ctx, s - m, m * 1.2f);
	CGContextStrokePath(ctx);
}

static void TGMenuDrawSpeaker(CGContextRef ctx, CGFloat s, CGFloat m, BOOL crossed) {
	CGContextMoveToPoint(ctx, m, s * 0.38f);
	CGContextAddLineToPoint(ctx, s * 0.34f, s * 0.38f);
	CGContextAddLineToPoint(ctx, s * 0.54f, s * 0.20f);
	CGContextAddLineToPoint(ctx, s * 0.54f, s * 0.80f);
	CGContextAddLineToPoint(ctx, s * 0.34f, s * 0.62f);
	CGContextAddLineToPoint(ctx, m, s * 0.62f);
	CGContextClosePath(ctx);
	CGContextStrokePath(ctx);
	if (crossed) {
		CGContextMoveToPoint(ctx, s * 0.66f, s * 0.38f);
		CGContextAddLineToPoint(ctx, s * 0.86f, s * 0.62f);
		CGContextMoveToPoint(ctx, s * 0.86f, s * 0.38f);
		CGContextAddLineToPoint(ctx, s * 0.66f, s * 0.62f);
		CGContextStrokePath(ctx);
	}
}

static void TGMenuDrawArchive(CGContextRef ctx, CGFloat s, CGFloat m) {
	CGContextStrokeRect(ctx, CGRectMake(m, m, s - 2 * m, s * 0.18f));
	CGContextMoveToPoint(ctx, m + 2, m + s * 0.18f);
	CGContextAddLineToPoint(ctx, m + 2, s - m);
	CGContextAddLineToPoint(ctx, s - m - 2, s - m);
	CGContextAddLineToPoint(ctx, s - m - 2, m + s * 0.18f);
	CGContextStrokePath(ctx);
	CGContextMoveToPoint(ctx, s * 0.40f, s * 0.58f);
	CGContextAddLineToPoint(ctx, s * 0.60f, s * 0.58f);
	CGContextStrokePath(ctx);
}

static void TGMenuDrawReact(CGContextRef ctx, CGFloat s, CGFloat m) {
	CGContextMoveToPoint(ctx, s / 2, s - m - 2);
	CGContextAddCurveToPoint(ctx, m, s * 0.60f, m, s * 0.22f, s / 2, s * 0.38f);
	CGContextAddCurveToPoint(ctx, s - m, s * 0.22f, s - m, s * 0.60f, s / 2, s - m - 2);
	CGContextStrokePath(ctx);
}

static void TGMenuDrawCall(CGContextRef ctx, CGFloat s, CGFloat m) {
	CGContextSetLineWidth(ctx, 2.0f);
	CGContextMoveToPoint(ctx, m + 1, m + 4);
	CGContextAddCurveToPoint(ctx, m + 1, s * 0.70f, s * 0.70f, s - m - 1,
		s - m - 4, s - m - 1);
	CGContextAddLineToPoint(ctx, s - m, s * 0.68f);
	CGContextAddLineToPoint(ctx, s * 0.62f, s * 0.58f);
	CGContextAddLineToPoint(ctx, s * 0.50f, s * 0.68f);
	CGContextAddCurveToPoint(ctx, s * 0.40f, s * 0.60f, s * 0.40f, s * 0.60f,
		s * 0.32f, s * 0.50f);
	CGContextAddLineToPoint(ctx, s * 0.42f, s * 0.38f);
	CGContextAddLineToPoint(ctx, s * 0.32f, m);
	CGContextClosePath(ctx);
	CGContextStrokePath(ctx);
}

static void TGMenuDrawVideo(CGContextRef ctx, CGFloat s, CGFloat m) {
	CGContextAddPath(ctx, [UIBezierPath bezierPathWithRoundedRect:CGRectMake(m, s * 0.32f, s * 0.44f, s * 0.36f) cornerRadius:3].CGPath);
	CGContextStrokePath(ctx);
	CGContextMoveToPoint(ctx, m + s * 0.46f, s * 0.44f);
	CGContextAddLineToPoint(ctx, s - m, s * 0.34f);
	CGContextAddLineToPoint(ctx, s - m, s * 0.66f);
	CGContextAddLineToPoint(ctx, m + s * 0.46f, s * 0.56f);
	CGContextClosePath(ctx);
	CGContextStrokePath(ctx);
}

static void TGMenuDrawSearch(CGContextRef ctx, CGFloat s, CGFloat m) {
	CGContextStrokeEllipseInRect(ctx, CGRectMake(m, m, s * 0.50f, s * 0.50f));
	CGContextMoveToPoint(ctx, m + s * 0.46f, m + s * 0.46f);
	CGContextAddLineToPoint(ctx, s - m, s - m);
	CGContextStrokePath(ctx);
}

static void TGMenuDrawMore(CGContextRef ctx, CGFloat s, CGFloat m) {
	for (NSInteger i = 0; i < 3; i++)
		CGContextFillEllipseInRect(ctx, CGRectMake(s * 0.24f + i * s * 0.20f - 1.5f, s / 2 - 1.5f, 3, 3));
}

static void TGMenuDrawNotifications(CGContextRef ctx, CGFloat s, CGFloat m) {
	CGContextAddArc(ctx, s / 2, s * 0.46f, s * 0.26f, M_PI, 0, 0);
	CGContextStrokePath(ctx);
	CGContextMoveToPoint(ctx, s * 0.24f, s * 0.46f);
	CGContextAddLineToPoint(ctx, s * 0.24f, s * 0.66f);
	CGContextAddLineToPoint(ctx, s * 0.76f, s * 0.66f);
	CGContextAddLineToPoint(ctx, s * 0.76f, s * 0.46f);
	CGContextStrokePath(ctx);
	CGContextMoveToPoint(ctx, s * 0.42f, s * 0.74f);
	CGContextAddLineToPoint(ctx, s * 0.58f, s * 0.74f);
	CGContextStrokePath(ctx);
}

static void TGMenuDrawPrivacy(CGContextRef ctx, CGFloat s, CGFloat m) {
	CGContextAddArc(ctx, s / 2, s * 0.42f, s * 0.16f, M_PI, 0, 0);
	CGContextStrokePath(ctx);
	CGContextStrokeRect(ctx, CGRectMake(s * 0.26f, s * 0.44f, s * 0.48f, s * 0.34f));
}

static void TGMenuDrawData(CGContextRef ctx, CGFloat s, CGFloat m) {
	CGContextStrokeEllipseInRect(ctx, CGRectInset(CGRectMake(0, 0, s, s), m, m));
	CGContextMoveToPoint(ctx, s / 2, s / 2);
	CGContextAddLineToPoint(ctx, s / 2, m);
	CGContextMoveToPoint(ctx, s / 2, s / 2);
	CGContextAddLineToPoint(ctx, s - m, s / 2);
	CGContextStrokePath(ctx);
}

static void TGMenuDrawChat(CGContextRef ctx, CGFloat s, CGFloat m) {
	CGRect body = CGRectMake(m, m, s - 2 * m, s * 0.50f);
	CGContextAddPath(ctx, [UIBezierPath bezierPathWithRoundedRect:body cornerRadius:s * 0.14f].CGPath);
	CGContextStrokePath(ctx);
	CGContextMoveToPoint(ctx, s * 0.30f, CGRectGetMaxY(body));
	CGContextAddLineToPoint(ctx, s * 0.30f, s - m);
	CGContextAddLineToPoint(ctx, s * 0.48f, CGRectGetMaxY(body));
	CGContextStrokePath(ctx);
}

static void TGMenuDrawFolder(CGContextRef ctx, CGFloat s, CGFloat m) {
	CGContextMoveToPoint(ctx, m, s * 0.74f);
	CGContextAddLineToPoint(ctx, m, s * 0.28f);
	CGContextAddLineToPoint(ctx, s * 0.42f, s * 0.28f);
	CGContextAddLineToPoint(ctx, s * 0.50f, s * 0.38f);
	CGContextAddLineToPoint(ctx, s - m, s * 0.38f);
	CGContextAddLineToPoint(ctx, s - m, s * 0.74f);
	CGContextClosePath(ctx);
	CGContextStrokePath(ctx);
}

static void TGMenuDrawDevices(CGContextRef ctx, CGFloat s, CGFloat m) {
	CGContextStrokeRect(ctx, CGRectMake(s * 0.20f, s * 0.28f, s * 0.60f, s * 0.36f));
	CGContextMoveToPoint(ctx, m, s * 0.72f);
	CGContextAddLineToPoint(ctx, s - m, s * 0.72f);
	CGContextStrokePath(ctx);
}

static void TGMenuDrawLanguage(CGContextRef ctx, CGFloat s, CGFloat m) {
	CGRect ball = CGRectInset(CGRectMake(0, 0, s, s), m, m);
	CGContextStrokeEllipseInRect(ctx, ball);
	CGContextMoveToPoint(ctx, m, s / 2);
	CGContextAddLineToPoint(ctx, s - m, s / 2);
	CGContextStrokePath(ctx);
	CGContextSaveGState(ctx);
	CGContextTranslateCTM(ctx, s / 2, s / 2);
	CGContextScaleCTM(ctx, 0.5f, 1.0f);
	CGContextTranslateCTM(ctx, -s / 2, -s / 2);
	CGContextStrokeEllipseInRect(ctx, ball);
	CGContextRestoreGState(ctx);
}

static void TGMenuDrawFaq(CGContextRef ctx, CGFloat s, CGFloat m) {
	CGContextStrokeEllipseInRect(ctx, CGRectInset(CGRectMake(0, 0, s, s), m, m));
	CGContextAddArc(ctx, s / 2, s * 0.40f, s * 0.11f, M_PI, M_PI_2, 1);
	CGContextStrokePath(ctx);
	CGContextMoveToPoint(ctx, s / 2, s * 0.51f);
	CGContextAddLineToPoint(ctx, s / 2, s * 0.60f);
	CGContextStrokePath(ctx);
	CGContextFillEllipseInRect(ctx, CGRectMake(s / 2 - 1, s * 0.68f, 2, 2));
}

static void TGMenuDrawPolicy(CGContextRef ctx, CGFloat s, CGFloat m) {
	CGContextMoveToPoint(ctx, s / 2, m);
	CGContextAddLineToPoint(ctx, s - m, s * 0.30f);
	CGContextAddLineToPoint(ctx, s - m, s * 0.56f);
	CGContextAddCurveToPoint(ctx, s - m, s * 0.76f, s * 0.70f, s - m,
		s / 2, s - m);
	CGContextAddCurveToPoint(ctx, s * 0.30f, s - m, m, s * 0.76f,
		m, s * 0.56f);
	CGContextAddLineToPoint(ctx, m, s * 0.30f);
	CGContextClosePath(ctx);
	CGContextStrokePath(ctx);
	CGContextMoveToPoint(ctx, s * 0.36f, s * 0.50f);
	CGContextAddLineToPoint(ctx, s * 0.46f, s * 0.60f);
	CGContextAddLineToPoint(ctx, s * 0.66f, s * 0.38f);
	CGContextStrokePath(ctx);
}

static NSSet *TGKnownMenuGlyphNames(void) {
	static NSSet *known = nil;
	if (!known)
		known = [NSSet setWithObjects:@"reply", @"undo", @"forward", @"copy",
			@"edit", @"delete", @"pin", @"unpin", @"mute", @"unmute",
			@"archive", @"unarchive", @"react",

			@"notifications", @"privacy", @"data", @"chat", @"folder",
			@"devices", @"language", @"faq", @"policy",

			@"call", @"video", @"search", @"more", @"check", nil];
	return known;
}

@implementation TGIcons (MenuGlyphs)

+ (UIImage *)menuGlyphNamed:(NSString *)name {
	if (![TGKnownMenuGlyphNames() containsObject:name])
		return nil;

	if ([name isEqualToString:@"search"]) {
		UIImage *art = TGArtworkTemplate(@"SearchBarIcon");
		if (art)
			return art;
	}

	NSString *key = [@"menu-" stringByAppendingString:name];
	return [self iconNamed:key draw:^(CGContextRef ctx, CGFloat s) {
		CGContextSetLineWidth(ctx, 1.8f);
		CGContextSetLineCap(ctx, kCGLineCapRound);
		CGContextSetLineJoin(ctx, kCGLineJoinRound);
		CGFloat m = s * 0.18f;

		if ([name isEqualToString:@"reply"] || [name isEqualToString:@"undo"]) {
			TGMenuDrawReply(ctx, s, m);

		} else if ([name isEqualToString:@"forward"]) {
			TGMenuDrawForward(ctx, s, m);

		} else if ([name isEqualToString:@"copy"]) {
			TGMenuDrawCopy(ctx, s, m);

		} else if ([name isEqualToString:@"edit"]) {
			TGMenuDrawEdit(ctx, s, m);

		} else if ([name isEqualToString:@"delete"]) {
			TGMenuDrawDelete(ctx, s, m);

		} else if ([name isEqualToString:@"pin"] || [name isEqualToString:@"unpin"]) {
			TGMenuDrawPin(ctx, s, m);

		} else if ([name isEqualToString:@"mute"] || [name isEqualToString:@"unmute"]) {
			TGMenuDrawSpeaker(ctx, s, m, [name isEqualToString:@"mute"]);

		} else if ([name isEqualToString:@"archive"] || [name isEqualToString:@"unarchive"]) {
			TGMenuDrawArchive(ctx, s, m);

		} else if ([name isEqualToString:@"react"]) {
			TGMenuDrawReact(ctx, s, m);

		} else if ([name isEqualToString:@"call"]) {
			TGMenuDrawCall(ctx, s, m);

		} else if ([name isEqualToString:@"video"]) {
			TGMenuDrawVideo(ctx, s, m);

		} else if ([name isEqualToString:@"search"]) {
			TGMenuDrawSearch(ctx, s, m);

		} else if ([name isEqualToString:@"more"]) {
			TGMenuDrawMore(ctx, s, m);

		} else if ([name isEqualToString:@"check"]) {
			TGMenuDrawCheck(ctx, s, m);

		} else if ([name isEqualToString:@"notifications"]) {
			TGMenuDrawNotifications(ctx, s, m);

		} else if ([name isEqualToString:@"privacy"]) {
			TGMenuDrawPrivacy(ctx, s, m);

		} else if ([name isEqualToString:@"data"]) {
			TGMenuDrawData(ctx, s, m);

		} else if ([name isEqualToString:@"chat"]) {
			TGMenuDrawChat(ctx, s, m);

		} else if ([name isEqualToString:@"folder"]) {
			TGMenuDrawFolder(ctx, s, m);

		} else if ([name isEqualToString:@"devices"]) {
			TGMenuDrawDevices(ctx, s, m);

		} else if ([name isEqualToString:@"language"]) {
			TGMenuDrawLanguage(ctx, s, m);

		} else if ([name isEqualToString:@"faq"]) {
			TGMenuDrawFaq(ctx, s, m);

		} else if ([name isEqualToString:@"policy"]) {
			TGMenuDrawPolicy(ctx, s, m);

		} else {
			return;
		}
	}];
}

+ (UIImage *)musicNoteOfSide:(CGFloat)side colour:(UIColor *)colour {
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();

	[colour set];
	CGFloat stem = MAX((CGFloat)1.5, side * 0.07f);
	CGFloat headR = side * 0.16f;
	CGFloat top = side * 0.20f, bottom = side * 0.72f;
	CGFloat left = side * 0.36f, right = side * 0.68f;

	CGContextFillRect(ctx, CGRectMake(left, top, stem, bottom - top));
	CGContextFillRect(ctx, CGRectMake(right, top, stem, bottom - top));
	CGContextFillRect(ctx, CGRectMake(left, top, right - left + stem, stem * 1.6f));
	CGContextFillEllipseInRect(ctx, CGRectMake(left - headR * 1.4f, bottom - headR, headR * 2, headR * 1.7f));
	CGContextFillEllipseInRect(ctx, CGRectMake(right - headR * 1.4f, bottom - headR, headR * 2, headR * 1.7f));

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

+ (UIImage *)floatingPlateOfSide:(CGFloat)side chevron:(BOOL)chevron
						 pressed:(BOOL)pressed {
	if (side < 1)
		return nil;

	if (!sCache)
		sCache = [NSMutableDictionary dictionary];
	NSString *key = [NSString stringWithFormat:@"floatingPlate-%d-%d-%d",
		(int)side, (int)chevron, (int)pressed];
	UIImage *cached = sCache[key];
	if (cached)
		return cached;

	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGRect disc = CGRectMake(0, 0, side, side);

	static const CGFloat lightFace[8] = {
		222 / 255.0f, 229 / 255.0f, 237 / 255.0f, 1.0f,
		198 / 255.0f, 207 / 255.0f, 219 / 255.0f, 1.0f};
	static const CGFloat pressedFace[8] = {
		136 / 255.0f, 153 / 255.0f, 174 / 255.0f, 1.0f,
		116 / 255.0f, 129 / 255.0f, 150 / 255.0f, 1.0f};

	CGContextSaveGState(ctx);
	CGContextAddEllipseInRect(ctx, disc);
	CGContextClip(ctx);
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGGradientRef face = CGGradientCreateWithColorComponents(space,
		pressed ? pressedFace : lightFace, NULL, 2);
	CGContextDrawLinearGradient(ctx, face, CGPointMake(0, 0), CGPointMake(0, side), 0);
	CGGradientRelease(face);
	CGColorSpaceRelease(space);
	CGContextRestoreGState(ctx);

	CGContextSetLineWidth(ctx, 1.0f);
	if (pressed)
		CGContextSetRGBStrokeColor(ctx, 0x5e / 255.0f, 0x70 / 255.0f, 0x83 / 255.0f, 1.0f);
	else
		CGContextSetRGBStrokeColor(ctx, 0x8b / 255.0f, 0x99 / 255.0f, 0xab / 255.0f, 1.0f);
	CGContextStrokeEllipseInRect(ctx, CGRectInset(disc, 0.5f, 0.5f));

	if (chevron) {
		CGFloat mid = side / 2;
		CGFloat arm = side * 0.17f;
		if (pressed)
			CGContextSetRGBStrokeColor(ctx, 1, 1, 1, 1);
		else
			CGContextSetRGBStrokeColor(ctx, 0x5c / 255.0f, 0x70 / 255.0f,
				0x8b / 255.0f, 1.0f);
		CGContextSetLineWidth(ctx, MAX(1.5f, side * 0.055f));
		CGContextSetLineCap(ctx, kCGLineCapRound);
		CGContextSetLineJoin(ctx, kCGLineJoinRound);
		CGContextMoveToPoint(ctx, mid - arm, mid - arm * 0.5f);
		CGContextAddLineToPoint(ctx, mid, mid + arm * 0.55f);
		CGContextAddLineToPoint(ctx, mid + arm, mid - arm * 0.5f);
		CGContextStrokePath(ctx);
	}

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	if (image)
		sCache[key] = image;
	return image;
}

+ (UIImage *)microphoneOfSide:(CGFloat)side colour:(UIColor *)colour {
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	[colour set];

	CGRect headRect = CGRectMake(side * 0.409f, side * 0.135f, side * 0.182f, side * 0.40f);
	UIBezierPath *head = [UIBezierPath bezierPathWithRoundedRect:headRect cornerRadius:side * 0.091f];
	[head fill];

	CGContextSetLineWidth(ctx, MAX(1.0f, side * 0.075f));
	CGContextSetLineCap(ctx, kCGLineCapRound);
	CGContextAddArc(ctx, side / 2, side * 0.395f, side * 0.25f, 0, M_PI, 0);
	CGContextStrokePath(ctx);

	CGContextMoveToPoint(ctx, side / 2, side * 0.645f);
	CGContextAddLineToPoint(ctx, side / 2, side * 0.83f);
	CGContextStrokePath(ctx);

	CGContextMoveToPoint(ctx, side * 0.31f, side * 0.83f);
	CGContextAddLineToPoint(ctx, side * 0.69f, side * 0.83f);
	CGContextStrokePath(ctx);

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

+ (UIImage *)progressLineOfSize:(CGSize)size played:(CGFloat)played
						 colour:(UIColor *)colour {
	if (size.width <= 0 || size.height <= 0)
		return nil;

	UIGraphicsBeginImageContextWithOptions(size, NO, 0);

	CGFloat radius = size.height / 2;
	CGRect track = CGRectMake(0, 0, size.width, size.height);
	[[colour colorWithAlphaComponent:0.24f] set];
	[[UIBezierPath bezierPathWithRoundedRect:track cornerRadius:radius] fill];

	CGFloat clamped = MAX(0.0f, MIN(1.0f, played));
	CGFloat filled = size.width * clamped;
	if (filled > 0.5f) {
		[colour set];
		CGRect done = CGRectMake(0, 0, MAX(size.height, filled), size.height);
		[[UIBezierPath bezierPathWithRoundedRect:done cornerRadius:radius] fill];
	}

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

NSMapTable *TGWaveformHeightCache(void) {
	static NSMapTable *cache = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		cache = [NSMapTable mapTableWithKeyOptions:NSMapTableObjectPointerPersonality | NSMapTableStrongMemory
									  valueOptions:NSMapTableStrongMemory];
	});
	return cache;
}

+ (NSArray *)heightsForWaveform:(NSData *)waveform bars:(NSUInteger)bars size:(CGSize)size {
	NSMapTable *cache = TGWaveformHeightCache();
	NSDictionary *entry = [cache objectForKey:waveform];
	if (entry && [entry[@"bars"] unsignedIntegerValue] == bars &&
		CGSizeEqualToSize([entry[@"size"] CGSizeValue], size))
		return entry[@"heights"];

	const uint8_t *bytes = (const uint8_t *)waveform.bytes;
	NSInteger bits = waveform.length * 8 / 5;

	NSMutableArray *heights = [NSMutableArray arrayWithCapacity:bars];
	for (NSInteger i = 0; i < bars; i++) {
		CGFloat value = 0.35f;
		if (bits > 0) {
			NSInteger index = i * bits / bars;
			NSInteger bit = index * 5;
			NSInteger byte = bit / 8;
			if (byte + 1 < waveform.length) {
				uint16_t window = (uint16_t)((bytes[byte] | (bytes[byte + 1] << 8)) >> (bit % 8));
				value = (window & 0x1F) / 31.0f;
			}
		}
		[heights addObject:@(MAX(2.0f, value * size.height))];
	}

	if (waveform)
		[cache setObject:@{@"bars" : @(bars), @"size" : [NSValue valueWithCGSize:size], @"heights" : heights}
				  forKey:waveform];
	return heights;
}

+ (UIImage *)waveform:(NSData *)waveform size:(CGSize)size
			   played:(CGFloat)played
			   colour:(UIColor *)colour {
	CGFloat barW = 2, gap = 1;
	if (size.width <= 0 || size.height <= 0)
		return nil;
	NSInteger bars = (NSUInteger)(size.width / (barW + gap));
	if (bars == 0)
		return nil;

	NSArray *heights = [self heightsForWaveform:waveform bars:bars size:size];

	UIGraphicsBeginImageContextWithOptions(size, NO, 0);

	NSInteger playedCount = (NSUInteger)(bars * played);

	CGMutablePathRef unplayedPath = CGPathCreateMutable();
	CGMutablePathRef playedPath = CGPathCreateMutable();

	for (NSInteger i = 0; i < bars; i++) {
		CGFloat height = [heights[i] doubleValue];
		CGFloat x = i * (barW + gap);
		CGRect bar = CGRectMake(x, (size.height - height) / 2, barW, height);
		UIBezierPath *rounded = [UIBezierPath bezierPathWithRoundedRect:bar cornerRadius:1];
		CGPathAddPath(i < playedCount ? playedPath : unplayedPath, NULL, rounded.CGPath);
	}

	CGContextRef ctx = UIGraphicsGetCurrentContext();
	if (!CGPathIsEmpty(unplayedPath)) {
		[[colour colorWithAlphaComponent:0.32f] setFill];
		CGContextAddPath(ctx, unplayedPath);
		CGContextFillPath(ctx);
	}
	if (!CGPathIsEmpty(playedPath)) {
		[[colour colorWithAlphaComponent:1.0f] setFill];
		CGContextAddPath(ctx, playedPath);
		CGContextFillPath(ctx);
	}
	CGPathRelease(unplayedPath);
	CGPathRelease(playedPath);

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

+ (UIImage *)bubbleTailForColour:(UIColor *)colour outgoing:(BOOL)outgoing {
	CGSize size = CGSizeMake(6, 10);
	UIGraphicsBeginImageContextWithOptions(size, NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	[colour set];

	if (outgoing) {
		CGContextMoveToPoint(ctx, 0, 0);
		CGContextAddLineToPoint(ctx, 0, 10);
		CGContextAddCurveToPoint(ctx, 3, 9, 5, 7, 6, 4);
		CGContextAddLineToPoint(ctx, 0, 4);
	} else {
		CGContextMoveToPoint(ctx, 6, 0);
		CGContextAddLineToPoint(ctx, 6, 10);
		CGContextAddCurveToPoint(ctx, 3, 9, 1, 7, 0, 4);
		CGContextAddLineToPoint(ctx, 6, 4);
	}
	CGContextClosePath(ctx);
	CGContextFillPath(ctx);

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

static const CGFloat kTGMessageCheckOverlap = 4.0f;

static UIImage *TGDrawnChecks(BOOL read, BOOL white) {
	CGSize size = CGSizeMake(read ? 12 + kTGMessageCheckOverlap : 12, 10);
	UIGraphicsBeginImageContextWithOptions(size, NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();

	if (white)
		CGContextSetRGBStrokeColor(ctx, 1, 1, 1, 1);
	else
		CGContextSetRGBStrokeColor(ctx, 0.051f, 0.710f, 0.051f, 1);
	CGContextSetLineWidth(ctx, 1.2f);
	CGContextSetLineCap(ctx, kCGLineCapRound);
	CGContextSetLineJoin(ctx, kCGLineJoinRound);

	for (NSInteger i = 0; i < (read ? 2 : 1); i++) {
		CGFloat dx = i * kTGMessageCheckOverlap;
		CGContextMoveToPoint(ctx, dx + 0.6f, 5.4f);
		CGContextAddLineToPoint(ctx, dx + 3.4f, 8.4f);
		CGContextAddLineToPoint(ctx, dx + 11.4f, 1.6f);
		CGContextStrokePath(ctx);
	}

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

+ (UIImage *)messageChecksRead:(BOOL)read white:(BOOL)white {
	if (!sCache)
		sCache = [NSMutableDictionary dictionary];
	NSString *key = [NSString stringWithFormat:@"messageChecks-%d-%d", (int)read, (int)white];
	UIImage *cached = sCache[key];
	if (cached)
		return cached;

	UIImage *full = white ? TGArtworkMasked(@"MessageCheckFull", [UIColor whiteColor], CGSizeZero)
						  : TGArtwork(@"MessageCheckFull");
	if (!full || full.size.width < 1) {
		UIImage *drawn = TGDrawnChecks(read, white);
		if (drawn)
			sCache[key] = drawn;
		return drawn;
	}
	if (!read) {
		sCache[key] = full;
		return full;
	}

	UIImage *half = white ? TGArtworkMasked(@"MessageCheckHalf", [UIColor whiteColor], CGSizeZero)
						  : TGArtwork(@"MessageCheckHalf");
	UIImage *second = (half && half.size.width >= 1) ? half : full;

	CGSize size = CGSizeMake(full.size.width + kTGMessageCheckOverlap,
		MAX(full.size.height, second.size.height));
	UIGraphicsBeginImageContextWithOptions(size, NO, 0);
	[full drawAtPoint:CGPointZero];
	[second drawAtPoint:CGPointMake(kTGMessageCheckOverlap, 0)];
	UIImage *pair = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	if (pair)
		sCache[key] = pair;
	return pair ?: TGDrawnChecks(read, white);
}

+ (UIImage *)messageTimestampPlateOutgoing:(BOOL)outgoing {
	UIImage *art = TGArtwork(outgoing ? @"MessageTimestampBackground"
									  : @"MessageTimestampBackgroundIncoming");
	if (!art || art.size.width < 2)
		return nil;
	return [art stretchableImageWithLeftCapWidth:(int)(art.size.width / 2) topCapHeight:0];
}

@end

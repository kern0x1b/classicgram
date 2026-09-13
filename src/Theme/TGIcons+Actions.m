#import "TGIconsInternal.h"

@implementation TGIcons (Actions)

+ (UIImage *)compose {
	UIImage *art = TGArtworkTemplate(@"ComposeMessageIcon");
	if (art)
		return art;
	return [self iconNamed:@"compose" draw:^(CGContextRef ctx, CGFloat s) {
		CGContextSetLineWidth(ctx, 1.8f);
		CGContextSetLineCap(ctx, kCGLineCapRound);
		CGContextSetLineJoin(ctx, kCGLineJoinRound);
		CGContextMoveToPoint(ctx, s - 9, 5);
		CGContextAddLineToPoint(ctx, 5, 5);
		CGContextAddLineToPoint(ctx, 5, s - 5);
		CGContextAddLineToPoint(ctx, s - 5, s - 5);
		CGContextAddLineToPoint(ctx, s - 5, 10);
		CGContextStrokePath(ctx);

		CGFloat tipX = 11, tipY = s - 10;
		CGContextMoveToPoint(ctx, tipX, tipY);
		CGContextAddLineToPoint(ctx, tipX + 2, tipY + 3.5f);
		CGContextAddLineToPoint(ctx, tipX + 5.5f, tipY + 1.5f);
		CGContextAddLineToPoint(ctx, s - 5, 6.5f);
		CGContextAddLineToPoint(ctx, s - 8.5f, 3);
		CGContextClosePath(ctx);
		CGContextFillPath(ctx);
	}];
}

+ (UIImage *)send {
	UIImage *art = TGArtwork(@"Send");
	if (art)
		return art;
	return [self iconNamed:@"send" draw:^(CGContextRef ctx, CGFloat s) {
		CGContextMoveToPoint(ctx, 3, s / 2);
		CGContextAddLineToPoint(ctx, s - 3, 4);
		CGContextAddLineToPoint(ctx, s - 8, s - 4);
		CGContextAddLineToPoint(ctx, s / 2 - 1, s / 2 + 3);
		CGContextClosePath(ctx);
		CGContextFillPath(ctx);
	}];
}

+ (UIImage *)attach {
	UIImage *art = TGArtwork(@"AttachBtn");
	if (art)
		return art;
	return [self iconNamed:@"attach" draw:^(CGContextRef ctx, CGFloat s) {
		CGContextSetLineWidth(ctx, 3);
		CGContextMoveToPoint(ctx, s / 2, 6);
		CGContextAddLineToPoint(ctx, s / 2, s - 6);
		CGContextMoveToPoint(ctx, 6, s / 2);
		CGContextAddLineToPoint(ctx, s - 6, s / 2);
		CGContextStrokePath(ctx);
	}];
}

+ (UIImage *)play {
	return [self iconNamed:@"play" draw:^(CGContextRef ctx, CGFloat s) {
		CGContextMoveToPoint(ctx, 8, 5);
		CGContextAddLineToPoint(ctx, s - 6, s / 2);
		CGContextAddLineToPoint(ctx, 8, s - 5);
		CGContextClosePath(ctx);
		CGContextFillPath(ctx);
	}];
}

+ (UIImage *)pause {
	return [self iconNamed:@"pause" draw:^(CGContextRef ctx, CGFloat s) {
		CGContextFillRect(ctx, CGRectMake(s * 0.32f, 5, s * 0.13f, s - 10));
		CGContextFillRect(ctx, CGRectMake(s * 0.55f, 5, s * 0.13f, s - 10));
	}];
}

+ (UIImage *)document {
	return [self iconNamed:@"document" draw:^(CGContextRef ctx, CGFloat s) {
		CGContextMoveToPoint(ctx, 6, 3);
		CGContextAddLineToPoint(ctx, s - 10, 3);
		CGContextAddLineToPoint(ctx, s - 5, 8);
		CGContextAddLineToPoint(ctx, s - 5, s - 3);
		CGContextAddLineToPoint(ctx, 6, s - 3);
		CGContextClosePath(ctx);
		CGContextFillPath(ctx);
	}];
}

+ (UIImage *)pin {
	return [self iconNamed:@"pin" draw:^(CGContextRef ctx, CGFloat s) {
		CGContextFillEllipseInRect(ctx, CGRectMake(s / 2 - 6, 4, 12, 12));
		CGContextMoveToPoint(ctx, s / 2 - 4, 14);
		CGContextAddLineToPoint(ctx, s / 2 + 4, 14);
		CGContextAddLineToPoint(ctx, s / 2, s - 4);
		CGContextClosePath(ctx);
		CGContextFillPath(ctx);
	}];
}

+ (UIImage *)microphone {
	return [self iconNamed:@"microphone" draw:^(CGContextRef ctx, CGFloat s) {
		CGRect headRect = CGRectMake(s / 2 - 4, 3, 8, 13);
		UIBezierPath *head = [UIBezierPath bezierPathWithRoundedRect:headRect cornerRadius:4];
		CGContextAddPath(ctx, head.CGPath);
		CGContextFillPath(ctx);

		CGContextSetLineWidth(ctx, 2);
		CGContextAddArc(ctx, s / 2, 14, 7, 0, M_PI, 0);
		CGContextStrokePath(ctx);

		CGContextMoveToPoint(ctx, s / 2, 21);
		CGContextAddLineToPoint(ctx, s / 2, s - 4);
		CGContextStrokePath(ctx);
	}];
}

+ (UIImage *)sticker {
	return [self iconNamed:@"sticker" draw:^(CGContextRef ctx, CGFloat s) {
		CGContextSetLineWidth(ctx, 2);
		CGContextStrokeEllipseInRect(ctx, CGRectMake(3, 3, s - 6, s - 6));
		CGContextFillEllipseInRect(ctx, CGRectMake(s * 0.33f, s * 0.34f, 2.5f, 3.5f));
		CGContextFillEllipseInRect(ctx, CGRectMake(s * 0.60f, s * 0.34f, 2.5f, 3.5f));
		CGContextAddArc(ctx, s / 2, s * 0.52f, s * 0.22f, 0.5f, M_PI - 0.5f, 0);
		CGContextStrokePath(ctx);
	}];
}

+ (UIImage *)callArrowOutgoing:(BOOL)outgoing missed:(BOOL)missed {
	CGFloat s = 14;
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(s, s), NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();

	if (missed)
		CGContextSetRGBStrokeColor(ctx, 0.871f, 0.227f, 0.227f, 1.0f);
	else
		CGContextSetRGBStrokeColor(ctx, 0.353f, 0.804f, 0.188f, 1.0f);
	CGContextSetLineWidth(ctx, 1.6f);
	CGContextSetLineCap(ctx, kCGLineCapRound);
	CGContextSetLineJoin(ctx, kCGLineJoinRound);

	CGFloat lo = 2.5f, hi = s - 2.5f;
	if (outgoing) {
		CGContextMoveToPoint(ctx, lo, hi);
		CGContextAddLineToPoint(ctx, hi, lo);
		CGContextStrokePath(ctx);
		CGContextMoveToPoint(ctx, hi - 5, lo);
		CGContextAddLineToPoint(ctx, hi, lo);
		CGContextAddLineToPoint(ctx, hi, lo + 5);
	} else {
		CGContextMoveToPoint(ctx, hi, lo);
		CGContextAddLineToPoint(ctx, lo, hi);
		CGContextStrokePath(ctx);
		CGContextMoveToPoint(ctx, lo + 5, hi);
		CGContextAddLineToPoint(ctx, lo, hi);
		CGContextAddLineToPoint(ctx, lo, hi - 5);
	}
	CGContextStrokePath(ctx);

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

@end

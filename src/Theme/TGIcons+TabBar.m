#import "TGIconsInternal.h"

@implementation TGIcons (TabBar)

+ (UIImage *)chats {
	UIImage *art = TGArtworkTemplate(@"TabIconMessages");
	if (art)
		return art;
	return [self iconNamed:@"chats" draw:^(CGContextRef ctx, CGFloat s) {
		CGRect body = CGRectMake(2, 3, s - 4, s - 9);
		UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:body cornerRadius:6];
		[p moveToPoint:CGPointMake(8, CGRectGetMaxY(body) - 2)];
		[p addLineToPoint:CGPointMake(7, CGRectGetMaxY(body) + 6)];
		[p addLineToPoint:CGPointMake(15, CGRectGetMaxY(body) - 2)];
		[p closePath];
		CGContextAddPath(ctx, p.CGPath);
		CGContextFillPath(ctx);
	}];
}

+ (UIImage *)contacts {
	UIImage *art = TGArtworkTemplate(@"TabIconContacts");
	if (art)
		return art;
	return [self iconNamed:@"contacts" draw:^(CGContextRef ctx, CGFloat s) {
		CGContextFillEllipseInRect(ctx, CGRectMake(s / 2 - 5, 4, 10, 10));
		CGRect shoulders = CGRectMake(s / 2 - 9, 16, 18, 12);
		UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:shoulders cornerRadius:9];
		CGContextAddPath(ctx, p.CGPath);
		CGContextFillPath(ctx);
	}];
}

+ (UIImage *)settings {
	UIImage *art = TGArtworkTemplate(@"TabIconSettings");
	if (art)
		return art;
	return [self iconNamed:@"settings" draw:^(CGContextRef ctx, CGFloat s) {
		CGPoint center = CGPointMake(s / 2, s / 2);
		CGFloat outerRadius = s * 0.46f;
		CGFloat innerRadius = s * 0.30f;
		CGFloat toothDepth = s * 0.12f;
		NSInteger toothCount = 8;

		UIBezierPath *gear = [UIBezierPath bezierPath];
		for (NSInteger i = 0; i < toothCount * 2; i++) {
			CGFloat angle = (CGFloat)i / (toothCount * 2) * 2 * M_PI;
			CGFloat radius = (i % 2 == 0) ? outerRadius + toothDepth : outerRadius;
			CGPoint p = CGPointMake(center.x + radius * cosf(angle),
				center.y + radius * sinf(angle));
			if (i == 0)
				[gear moveToPoint:p];
			else
				[gear addLineToPoint:p];
		}
		[gear closePath];

		UIBezierPath *hole = [UIBezierPath bezierPathWithArcCenter:center radius:innerRadius startAngle:0 endAngle:2 * M_PI clockwise:YES];
		[gear appendPath:hole];
		gear.usesEvenOddFillRule = YES;

		CGContextAddPath(ctx, gear.CGPath);
		CGContextEOFillPath(ctx);
	}];
}

@end

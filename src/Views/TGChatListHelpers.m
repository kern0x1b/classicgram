#import "TGChatListHelpers.h"
#import "TGTheme.h"

const CGFloat kRowHeight = 73.0f;
const CGFloat kAvatar = 56.0f;
const CGFloat kAvatarRadius = 5.0f;
const CGFloat kAvatarLeft = 8.0f;
const CGFloat kTextLeft = 73.0f;

const CGFloat kSwipeButtonHeight = 31.0f;
const CGFloat kSwipeButtonMinWidth = 61.0f;
const CGFloat kSwipeEdgeDistance = 6.0f;
const CGFloat kSwipeButtonTop = 20.0f;
const CGFloat kSwipeButtonGap = 6.0f;

const CGFloat kPinBadgeWidth = 27.0f;
const CGFloat kPinBadgeHeight = 21.0f;

const CGFloat kStoryTrayHeight = 82.0f;
const CGFloat kStoryCellWidth = 68.0f;
const CGFloat kStoryAvatar = 56.0f;
const CGFloat kSearchBarHeight = 44.0f;
const CGFloat kFolderStripHeight = 32.0f;
const CGFloat kFolderChipHeight = 24.0f;
const CGFloat kFolderChipPadding = 12.0f;
const CGFloat kFolderChipGap = 6.0f;
const CGFloat kLoginBannerHeight = 76.0f;
const CGFloat kFolderBannerHeight = 62.0f;
const CGFloat kBirthdayBannerHeight = 62.0f;
const NSUInteger kRowDetailCacheLimit = 200;
const NSInteger kAvatarPrefetchRows = 4;
const NSInteger kAvatarRetainRows = 14;
const CGFloat kArchivePullThreshold = 40.0f;

UIColor *TGChatListTitleColour(void) {
	static UIColor *colour = nil;
	if (!colour)
		colour = [[TGTheme shared] primaryTextColour];
	return colour;
}

UIColor *TGChatListMessageColour(void) {
	static UIColor *colour = nil;
	if (!colour)
		colour = [[TGTheme shared] secondaryTextColour];
	return colour;
}

UIColor *TGChatListActionColour(void) {
	static UIColor *colour = nil;
	if (!colour)
		colour = [UIColor colorWithRed:0x53 / 255.0f green:0x6c / 255.0f
								  blue:0x8c / 255.0f
								 alpha:1.0f];
	return colour;
}

UIColor *TGChatListAuthorColour(void) {
	static UIColor *colour = nil;
	if (!colour)
		colour = [UIColor colorWithRed:0x34 / 255.0f green:0x5f / 255.0f
								  blue:0x8f / 255.0f
								 alpha:1.0f];
	return colour;
}

NSDictionary *TGReplyDictionary(id value) {
	return [value isKindOfClass:[NSDictionary class]] ? (NSDictionary *)value : nil;
}

NSArray *TGReplyArray(id value) {
	return [value isKindOfClass:[NSArray class]] ? (NSArray *)value : nil;
}

NSString *TGReplyString(id value) {
	return [value isKindOfClass:[NSString class]] ? (NSString *)value : nil;
}

NSArray *TGChatRows(id value) {
	NSArray *raw = TGReplyArray(value);
	if (!raw.count)
		return @[];
	NSMutableArray *rows = [NSMutableArray arrayWithCapacity:raw.count];
	for (id entry in raw) {
		NSDictionary *chat = TGReplyDictionary(entry);
		if (chat && [chat[@"id"] longLongValue])
			[rows addObject:chat];
	}
	return rows;
}

UIImage *TGDialogListBadgeImage(BOOL highlighted) {
	static UIImage *normal = nil, *bright = nil;
	if (!normal) {
		UIImage *raw = [UIImage imageNamed:@"DialogListUnreadBadge.png"];
		normal = [raw stretchableImageWithLeftCapWidth:(int)(raw.size.width / 2)
										  topCapHeight:(int)(raw.size.height / 2)];
		UIImage *rawHigh = [UIImage imageNamed:@"DialogListUnreadBadge_Highlighted.png"];
		bright = [rawHigh stretchableImageWithLeftCapWidth:(int)(rawHigh.size.width / 2)
											  topCapHeight:(int)(rawHigh.size.height / 2)];
	}
	return highlighted ? bright : normal;
}

UIImage *TGDialogListPinBadgeImage(BOOL highlighted) {
	static UIImage *normal = nil, *bright = nil;
	UIImage *cached = highlighted ? bright : normal;
	if (cached)
		return cached;

	UIImage *plate = TGDialogListBadgeImage(highlighted);
	if (!plate)
		return nil;

	CGSize size = CGSizeMake(kPinBadgeWidth, kPinBadgeHeight);
	UIGraphicsBeginImageContextWithOptions(size, NO, 0);
	[plate drawInRect:CGRectMake(0, 0, size.width, size.height)];

	CGContextRef ctx = UIGraphicsGetCurrentContext();

	if (highlighted)
		CGContextSetRGBFillColor(ctx, 0x23 / 255.0f, 0x71 / 255.0f,
			0xc2 / 255.0f, 1.0f);
	else
		CGContextSetRGBFillColor(ctx, 1, 1, 1, 1);

	CGFloat midX = size.width / 2;
	CGContextFillEllipseInRect(ctx, CGRectMake(midX - 3.5f, 4.0f, 7, 7));
	CGContextFillRect(ctx, CGRectMake(midX - 5, 11.0f, 10, 1.5f));
	CGContextMoveToPoint(ctx, midX - 1.5f, 12.5f);
	CGContextAddLineToPoint(ctx, midX + 1.5f, 12.5f);
	CGContextAddLineToPoint(ctx, midX, 17.0f);
	CGContextClosePath(ctx);
	CGContextFillPath(ctx);

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	if (highlighted)
		bright = image;
	else
		normal = image;
	return image;
}

UIImage *TGDialogListMentionBadgeImage(BOOL highlighted) {
	static UIImage *normal = nil, *bright = nil;
	UIImage *cached = highlighted ? bright : normal;
	if (cached)
		return cached;

	UIImage *plate = TGDialogListBadgeImage(highlighted);
	if (!plate)
		return nil;

	CGSize size = CGSizeMake(kPinBadgeWidth, kPinBadgeHeight);
	UIGraphicsBeginImageContextWithOptions(size, NO, 0);
	[plate drawInRect:CGRectMake(0, 0, size.width, size.height)];

	UIFont *font = [UIFont boldSystemFontOfSize:14];
	NSString *glyph = @"@";
	CGSize glyphSize = [glyph sizeWithFont:font];
	UIColor *ink = highlighted
		? [UIColor colorWithRed:0x23 / 255.0f green:0x71 / 255.0f blue:0xc2 / 255.0f alpha:1.0f]
		: [UIColor whiteColor];
	[ink set];
	[glyph drawAtPoint:CGPointMake((size.width - glyphSize.width) / 2,
					(size.height - glyphSize.height) / 2)
			  withFont:font];

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	if (highlighted)
		bright = image;
	else
		normal = image;
	return image;
}

UIImage *TGDialogListReactionBadgeImage(BOOL highlighted) {
	static UIImage *normal = nil, *bright = nil;
	UIImage *cached = highlighted ? bright : normal;
	if (cached)
		return cached;

	UIImage *plate = TGDialogListBadgeImage(highlighted);
	if (!plate)
		return nil;

	CGSize size = CGSizeMake(kPinBadgeWidth, kPinBadgeHeight);
	UIGraphicsBeginImageContextWithOptions(size, NO, 0);
	[plate drawInRect:CGRectMake(0, 0, size.width, size.height)];

	CGContextRef ctx = UIGraphicsGetCurrentContext();
	if (highlighted)
		CGContextSetRGBFillColor(ctx, 0x23 / 255.0f, 0x71 / 255.0f, 0xc2 / 255.0f, 1.0f);
	else
		CGContextSetRGBFillColor(ctx, 1, 1, 1, 1);

	CGFloat midX = size.width / 2;
	CGFloat lobeRadius = 3.0f;
	CGFloat lobeY = size.height / 2 - 1.5f;
	CGContextFillEllipseInRect(ctx,
		CGRectMake(midX - lobeRadius * 2, lobeY - lobeRadius, lobeRadius * 2, lobeRadius * 2));
	CGContextFillEllipseInRect(ctx,
		CGRectMake(midX, lobeY - lobeRadius, lobeRadius * 2, lobeRadius * 2));
	CGContextMoveToPoint(ctx, midX - lobeRadius * 2, lobeY);
	CGContextAddLineToPoint(ctx, midX + lobeRadius * 2, lobeY);
	CGContextAddLineToPoint(ctx, midX, lobeY + lobeRadius * 2 + 0.5f);
	CGContextClosePath(ctx);
	CGContextFillPath(ctx);

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	if (highlighted)
		bright = image;
	else
		normal = image;
	return image;
}

UIImage *TGSwipePlateImage(BOOL destructive, BOOL highlighted) {
	static UIImage *cache[4] = {nil, nil, nil, nil};
	NSInteger slot = (destructive ? 2 : 0) + (highlighted ? 1 : 0);
	if (cache[slot])
		return cache[slot];

	NSString *name = destructive ? @"MenuRedButton" : @"GroupedActionButton";
	if (highlighted)
		name = [name stringByAppendingString:@"_Highlighted"];
	UIImage *raw = [UIImage imageNamed:[name stringByAppendingString:@".png"]];
	if (!raw)
		return nil;
	cache[slot] = [raw stretchableImageWithLeftCapWidth:(int)(raw.size.width / 2)
										   topCapHeight:(int)(raw.size.height / 2)];
	return cache[slot];
}

UIImage *TGScopeBarBackgroundImage(void) {
	static UIImage *plate = nil;
	static BOOL looked = NO;
	if (!looked) {
		looked = YES;
		UIImage *raw = [UIImage imageNamed:@"SearchBarScopeBarBackground.png"];
		if (raw)
			plate = [raw stretchableImageWithLeftCapWidth:1 topCapHeight:0];
	}
	return plate;
}

UIImage *TGTitleCaretImage(void) {
	static UIImage *caret = nil;
	if (caret)
		return caret;
	CGSize size = CGSizeMake(10, 6);
	UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
	CGContextMoveToPoint(ctx, 0, 0);
	CGContextAddLineToPoint(ctx, size.width, 0);
	CGContextAddLineToPoint(ctx, size.width / 2, size.height);
	CGContextClosePath(ctx);
	CGContextFillPath(ctx);
	caret = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return caret;
}

UIImage *TGStoryScaledImage(UIImage *source, CGSize bounds) {
	if (!source || bounds.width < 1 || bounds.height < 1)
		return source;
	CGFloat scale = MIN(bounds.width / source.size.width, bounds.height / source.size.height);
	if (scale >= 1.0f)
		return source;
	CGSize target = CGSizeMake((int)(source.size.width * scale), (int)(source.size.height * scale));
	UIGraphicsBeginImageContextWithOptions(target, YES, 1.0f);
	[source drawInRect:CGRectMake(0, 0, target.width, target.height)];
	UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return scaled ?: source;
}

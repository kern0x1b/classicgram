#import "TGStoryHelpers.h"
#import "TGDateUtils.h"

const CGFloat kStoryStripHeight = 3.0f;
const CGFloat kStoryStripInset = 4.0f;
const CGFloat kStoryStripGap = 2.0f;
const CGFloat kStoryStatusBarHeight = 20.0f;
const CGFloat kStoryPanelHeight = 45.0f;
const CGFloat kStoryPanelButtonSize = 40.0f;
const CGFloat kStoryPanelButtonInset = 6.0f;
const CGFloat kStoryPanelButtonTop = 2.0f;
const CGFloat kStoryPlateHeight = 30.0f;
const CGFloat kStoryPlateTop = 7.0f;
const CGFloat kStoryPlateLeft = 5.0f;
const CGFloat kStoryFooterHeight = 30.0f;
const CGFloat kStoryFooterInset = 10.0f;
const CGFloat kStoryFooterBottom = 10.0f;
const CGFloat kStoryCaptionHeight = 50.0f;
const NSInteger kStoryPhotoPixels = 640;
const CGFloat kStoryPageGap = 16.0f;
const CGFloat kStoryOverscroll = 48.0f;
const CGFloat kStoryDismissDistance = 100.0f;
const CGFloat kStoryDismissVelocity = 700.0f;
const NSTimeInterval kStoryDuration = 5.0;
const NSTimeInterval kStoryTick = 0.0667;
const NSUInteger kStoryPageQueueLimit = 2;

UIImage *TGStoryStretch(NSString *name, NSInteger leftCap) {
	UIImage *image = [UIImage imageNamed:name];
	if (image == nil)
		return nil;
	return [image stretchableImageWithLeftCapWidth:leftCap topCapHeight:0];
}

NSString *TGStoryAgeText(int date) {
	if (date <= 0)
		return @"";
	return [TGDateUtils stringForRelativeLastSeen:date];
}

NSString *TGStoryString(NSDictionary *story, NSString *key) {
	id value = [story objectForKey:key];
	return [value isKindOfClass:[NSString class]] ? (NSString *)value : @"";
}

NSInteger TGStoryNumber(NSDictionary *story, NSString *key) {
	id value = [story objectForKey:key];
	return [value respondsToSelector:@selector(integerValue)] ? [value integerValue] : 0;
}

int64_t TGStoryChatId(NSDictionary *story, NSString *key) {
	id value = [story objectForKey:key];
	return [value respondsToSelector:@selector(longLongValue)] ? [value longLongValue] : 0;
}

BOOL TGStoryFlag(NSDictionary *story, NSString *key) {
	id value = [story objectForKey:key];
	return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

NSDictionary *TGStoryPosterEntry(int64_t chatId, NSString *title, NSDictionary *active) {
	NSArray *stories = [active objectForKey:@"stories"];
	if (![stories isKindOfClass:[NSArray class]] || stories.count == 0 ||
		TGStoryFlag(active, @"archived")) {
		return nil;
	}

	NSMutableArray *ids = [[NSMutableArray alloc] init];
	for (NSDictionary *story in stories) {
		if ([story isKindOfClass:[NSDictionary class]])
			[ids addObject:[NSNumber numberWithInteger:TGStoryNumber(story, @"id")]];
	}
	if (ids.count == 0)
		return nil;

	return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithLongLong:chatId], @"chatId",
		title, @"title",
		ids, @"ids",
		([active objectForKey:@"order"] ?: [NSNumber numberWithInt:0]), @"order",
		nil];
}

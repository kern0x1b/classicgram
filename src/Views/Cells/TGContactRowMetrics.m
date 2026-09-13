#import "TGContactRowMetrics.h"

const CGFloat kContactAvatar = 40.0f;
const CGFloat kContactAvatarLeft = 5.0f;
const CGFloat kContactAvatarTop = 5.0f;
const CGFloat kContactTextLeft = 54.0f;
const CGFloat kContactSectionHeight = 25.0f;
const CGFloat kContactBadgeSide = 14.0f;
const CGFloat kContactBadgeGap = 3.0f;
const CGFloat kContactActionRowHeight = 44.0f;
const CGFloat kContactAvatarCorner = 4.0f;

CGFloat TGContactsRetinaPixel(void) {
	return ([UIScreen mainScreen].scale > 1.5f) ? 0.5f : 0.0f;
}

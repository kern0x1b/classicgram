#import <UIKit/UIKit.h>

typedef struct {
	CGRect count;
	CGRect mention;
	CGRect reaction;
	CGRect pin;
	CGFloat consumedWidth;
} TGChatBadgeSlots;

TGChatBadgeSlots TGChatBadgeSlotsInWidth(CGFloat width,
	CGFloat countTextWidth,
	BOOL hasCount,
	BOOL hasMention,
	BOOL hasReaction,
	BOOL hasPin);

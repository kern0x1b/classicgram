#import <Foundation/Foundation.h>

typedef enum {
	TGChatDateKindTime = 0,
	TGChatDateKindWeekday,
	TGChatDateKindFullDate,
} TGChatDateKind;

TGChatDateKind TGChatDateKindForAge(BOOL sameYear, NSInteger dayGap);

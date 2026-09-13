#import "TGChatDateKind.h"

TGChatDateKind TGChatDateKindForAge(BOOL sameYear, NSInteger dayGap) {
	if (!sameYear)
		return TGChatDateKindFullDate;
	if (dayGap == 0)
		return TGChatDateKindTime;
	if (dayGap >= 1 && dayGap <= 6)
		return TGChatDateKindWeekday;
	return TGChatDateKindFullDate;
}

#import "TGProfileSectionMetrics.h"

CGFloat TGProfileSectionHeaderHeight(NSString *kind, BOOL isFirstSection, BOOL isGroupProfile,
	BOOL isSecretChat, BOOL sectionIsEmpty, BOOL hasDetails) {
	if (!isFirstSection && sectionIsEmpty)
		return 0;
	if (isGroupProfile)
		return 8;
	if (isFirstSection)
		return ([kind isEqualToString:@"details"] && !hasDetails) ? 2 : 12;
	if ([kind isEqualToString:@"actions"])
		return 10;
	if ([kind isEqualToString:@"media"])
		return isSecretChat ? 10 : 28;
	return 12;
}

#import "TGSearchBarPin.h"

BOOL TGChatListShouldPinSearchBar(CGFloat shownOffset,
	CGFloat restingOffset,
	CGFloat searchBarHeight,
	CGFloat reachableOffset) {
	if (reachableOffset < searchBarHeight)
		return NO;
	if (shownOffset > searchBarHeight - 0.5f)
		return NO;
	return fabs(shownOffset - restingOffset) >= 0.5f;
}

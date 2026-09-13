#import "TGGroupedMetrics.h"

static const CGFloat kTitledHeaderHeight = 46.0f;
static const CGFloat kUntitledHeaderHeight = 8.0f;
static const CGFloat kCommentVerticalPadding = 14.0f;

CGFloat TGGroupedHeaderHeight(NSString *title) {
	return [title isKindOfClass:[NSString class]] && title.length > 0
		? kTitledHeaderHeight
		: kUntitledHeaderHeight;
}

CGFloat TGGroupedCommentHeight(CGFloat textHeight) {
	return textHeight <= 0 ? 0 : textHeight + kCommentVerticalPadding;
}

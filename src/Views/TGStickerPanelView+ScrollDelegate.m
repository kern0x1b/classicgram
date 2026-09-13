#import "TGStickerPanelView.h"
#import "TGStickerPanelViewInternal.h"
#import "TGLocalization.h"

#import "TGActionSheet.h"
#import "TGTheme.h"
#import "TGViewRecycler.h"

@implementation TGStickerPanelView (ScrollDelegate)

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	if (scrollView != self.grid)
		return;

	[self updateVisibleTiles];

	CGFloat offset = scrollView.contentOffset.y + 1.0f;
	NSInteger current = 0;
	for (NSInteger i = 0; i < (NSInteger)self.sections.count; i++) {
		if ([self.sections[i][@"y"] floatValue] <= offset)
			current = i;
		else
			break;
	}
	if (current != self.selectedSection) {
		self.selectedSection = current;
		[self updateTabSelection];
		if (current < (NSInteger)self.tabButtons.count) {
			UIButton *button = self.tabButtons[current];
			[self.tabStrip scrollRectToVisible:CGRectInset(button.frame, -20, 0) animated:YES];
		}
	}
}

@end

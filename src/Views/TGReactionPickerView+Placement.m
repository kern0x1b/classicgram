#import "TGReactionPickerView.h"
#import "TGReactionPickerViewInternal.h"

#import "TGSnackbar.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGActionSheet.h"
#import "TGLocalization.h"

@implementation TGReactionPickerView (Placement)

#pragma mark placement

- (void)positionCard {
	CGRect frame = _card.frame;
	CGRect rect = _anchorRect;

	frame.origin.x = floorf(rect.origin.x + rect.size.width / 2 - frame.size.width / 2);
	if (frame.origin.x < 4)
		frame.origin.x = 4;
	if (frame.origin.x + frame.size.width > self.bounds.size.width - 4)
		frame.origin.x = self.bounds.size.width - 4 - frame.size.width;
	if (frame.origin.x < 4)
		frame.origin.x = 4;

	frame.origin.y = rect.origin.y - frame.size.height - 14;
	if (frame.origin.y < 2) {
		frame.origin.y = rect.origin.y + rect.size.height + 17;
		if (frame.origin.y + frame.size.height > self.bounds.size.height - 14) {
			frame.origin.y = floorf((self.bounds.size.height - frame.size.height) / 2);
			_arrowOnTop = NO;
		} else
			_arrowOnTop = YES;
	} else
		_arrowOnTop = NO;

	_arrowLocation = floorf(rect.origin.x + rect.size.width / 2) - frame.origin.x;

	_card.layer.anchorPoint = CGPointMake(MAX(0.0f, MIN(1.0f, _arrowLocation / MAX(1.0f, frame.size.width))),
		_arrowOnTop ? -0.2f : 1.2f);
	_card.frame = frame;
}

- (void)layoutCard {
	CGFloat width = _card.bounds.size.width;

	CGFloat topHeight = _topLineView.image.size.height;
	CGFloat bottomHeight = _bottomLineView.image.size.height;

	CGFloat arrowWidth = _arrowTopView.image.size.width;
	CGFloat arrowX = floorf(_arrowLocation - arrowWidth / 2);
	arrowX = MIN(MAX(10.0f, arrowX), MAX(10.0f, width - arrowWidth - 10.0f));

	_arrowTopView.frame = CGRectMake(arrowX, -9, arrowWidth, _arrowTopView.image.size.height);
	_arrowBottomView.frame = CGRectMake(arrowX, kStripHeight - 4, _arrowBottomView.image.size.width,
		_arrowBottomView.image.size.height);

	_arrowTopView.hidden = !_arrowOnTop;
	_arrowBottomView.hidden = _arrowOnTop;

	CGFloat lineStart = 10.0f;
	CGFloat lineEnd = MAX(lineStart, width - 10.0f);
	CGFloat gapStart = MIN(MAX(lineStart, arrowX), lineEnd);
	CGFloat gapEnd = MIN(MAX(lineStart, arrowX + arrowWidth), lineEnd);

	CGFloat topLeftWidth = _arrowOnTop ? (gapStart - lineStart) : (lineEnd - lineStart);
	CGFloat topRightX = _arrowOnTop ? gapEnd : lineEnd;
	CGFloat bottomLeftWidth = _arrowOnTop ? (lineEnd - lineStart) : (gapStart - lineStart);
	CGFloat bottomRightX = _arrowOnTop ? lineEnd : gapEnd;

	_topLineView.frame = CGRectMake(lineStart, 0, MAX(0.0f, topLeftWidth), topHeight);
	_topLineRightView.frame = CGRectMake(topRightX, 0, MAX(0.0f, lineEnd - topRightX), topHeight);
	_bottomLineView.frame = CGRectMake(lineStart, kStripHeight - 4, MAX(0.0f, bottomLeftWidth), bottomHeight);
	_bottomLineRightView.frame = CGRectMake(bottomRightX, kStripHeight - 4,
		MAX(0.0f, lineEnd - bottomRightX), bottomHeight);

	[_card bringSubviewToFront:_arrowTopView];
	[_card bringSubviewToFront:_arrowBottomView];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	if (_dismissed)
		return;
	CGSize size = self.bounds.size;
	if (_hostSize.width > 0 &&
		(fabs(size.width - _hostSize.width) > 0.5f || fabs(size.height - _hostSize.height) > 0.5f)) {
		if (sOpenPicker == self)
			sOpenPicker = nil;
		[self teardownAnimated:NO];
	}
}

@end

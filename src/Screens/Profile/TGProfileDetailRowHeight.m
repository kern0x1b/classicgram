#import "TGProfileDetailRowHeight.h"

const CGFloat kTGProfileDetailValueLeft = 78;

static const CGFloat kValueRightMargin = 12;
static const CGFloat kValueMinimumWidth = 40;
static const CGFloat kValueMinimumHeight = 20;
static const CGFloat kValueVerticalPadding = 22;
static const CGFloat kRowMinimumHeight = 44;
static const CGFloat kValueMeasurementLimit = 400;

CGFloat TGProfileDetailValueWidthForContentWidth(CGFloat contentWidth) {
	CGFloat width = contentWidth - kTGProfileDetailValueLeft - kValueRightMargin;
	return width < kValueMinimumWidth ? kValueMinimumWidth : width;
}

CGFloat TGProfileDetailValueHeight(NSString *value, UIFont *font, CGFloat contentWidth) {
	CGSize bounds = CGSizeMake(TGProfileDetailValueWidthForContentWidth(contentWidth),
		kValueMeasurementLimit);
	CGSize size = [(value ?: @"") sizeWithFont:font
							 constrainedToSize:bounds
								 lineBreakMode:NSLineBreakByWordWrapping];
	return MAX(kValueMinimumHeight, size.height);
}

CGFloat TGProfileDetailRowHeightForValue(NSString *value, UIFont *font, CGFloat contentWidth) {
	return MAX(kRowMinimumHeight,
		TGProfileDetailValueHeight(value, font, contentWidth) + kValueVerticalPadding);
}

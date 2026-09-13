#import "TGProfileButtonsCell.h"
#import "TGProfileStyle.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGHexColour.h"

@implementation TGProfileButtonsCell

- (UIButton *)makeButton {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	[button setBackgroundImage:TGProfileStretched(@"GroupedActionButton.png")
					  forState:UIControlStateNormal];
	[button setBackgroundImage:TGProfileStretched(@"GroupedActionButton_Highlighted.png")
					  forState:UIControlStateHighlighted];
	[button setTitleColor:TGColourFromHex(0x4a6587) forState:UIControlStateNormal];
	[button setTitleShadowColor:[[UIColor whiteColor] colorWithAlphaComponent:0.45f]
					   forState:UIControlStateNormal];
	[button setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
	[button setTitleShadowColor:[UIColor clearColor] forState:UIControlStateHighlighted];
	button.titleLabel.font = [UIFont boldSystemFontOfSize:14];
	button.titleLabel.shadowOffset = CGSizeMake(0, 1);
	button.adjustsImageWhenDisabled = NO;
	button.exclusiveTouch = YES;
	return button;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
			  reuseIdentifier:(NSString *)reuseIdentifier {
	if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
		self.selectionStyle = UITableViewCellSelectionStyleNone;
		self.backgroundColor = [UIColor clearColor];
		self.backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
		self.backgroundView.backgroundColor = [UIColor clearColor];
		_leftButton = [self makeButton];
		_rightButton = [self makeButton];
		[self.contentView addSubview:_leftButton];
		[self.contentView addSubview:_rightButton];
	}
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGFloat contentWidth = self.contentView.bounds.size.width;
	CGFloat height = kButtonsRowHeight;
	if (!_leftButton.hidden && !_rightButton.hidden) {
		CGFloat buttonWidth = floorf((contentWidth - kButtonGutter) / 2);
		_leftButton.frame = CGRectMake(0, 0, buttonWidth, height);
		_rightButton.frame = CGRectMake(contentWidth - buttonWidth, 0,
			buttonWidth, height);
	} else if (!_leftButton.hidden) {
		_leftButton.frame = CGRectMake(0, 0, contentWidth, height);
	} else if (!_rightButton.hidden) {
		_rightButton.frame = CGRectMake(0, 0, contentWidth, height);
	}
}

@end

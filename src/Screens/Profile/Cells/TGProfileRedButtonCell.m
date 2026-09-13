#import "TGProfileRedButtonCell.h"
#import "TGProfileStyle.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGHexColour.h"

@implementation TGProfileRedButtonCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
			  reuseIdentifier:(NSString *)reuseIdentifier {
	if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
		self.selectionStyle = UITableViewCellSelectionStyleNone;
		self.backgroundColor = [UIColor clearColor];
		self.backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
		self.backgroundView.backgroundColor = [UIColor clearColor];
		_button = [UIButton buttonWithType:UIButtonTypeCustom];
		[_button setBackgroundImage:TGProfileStretched(@"MenuRedButton.png")
						   forState:UIControlStateNormal];
		[_button setBackgroundImage:TGProfileStretched(@"MenuRedButton_Highlighted.png")
						   forState:UIControlStateHighlighted];
		[_button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
		[_button setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
		UIColor *shadow = [TGColourFromHex(0xa10603) colorWithAlphaComponent:0.5f];
		[_button setTitleShadowColor:shadow forState:UIControlStateNormal];
		[_button setTitleShadowColor:shadow forState:UIControlStateHighlighted];
		_button.titleLabel.font = [UIFont boldSystemFontOfSize:17];
		_button.titleLabel.shadowOffset = CGSizeMake(0, -1);
		_button.adjustsImageWhenDisabled = NO;
		_button.exclusiveTouch = YES;
		[self.contentView addSubview:_button];
	}
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	_button.frame = CGRectMake(0, 0, self.contentView.bounds.size.width,
		kActionButtonHeight);
}

@end

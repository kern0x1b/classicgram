#import "UIButton+TGScopeButtonStyle.h"
#import "TGTheme.h"

@implementation UIButton (TGScopeButtonStyle)

- (void)tg_styleAsScopeButtonSelected:(BOOL)selected {
	UIImage *plate = [UIImage imageNamed:selected
			? @"SearchBarScopeButton_Highlighted.png"
			: @"SearchBarScopeButton.png"];
	if (plate) {
		plate = [plate stretchableImageWithLeftCapWidth:(int)(plate.size.width / 2)
										   topCapHeight:0];
		[self setBackgroundImage:plate forState:UIControlStateNormal];
		self.backgroundColor = [UIColor clearColor];
	} else {
		self.backgroundColor = selected
			? [[TGTheme shared] accentColour]
			: [UIColor clearColor];
	}

	if (selected) {
		[self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
		UIColor *shadow = [UIColor colorWithRed:0x11 / 255.0f green:0x2e / 255.0f blue:0x5c / 255.0f alpha:0.2f];
		[self setTitleShadowColor:shadow forState:UIControlStateNormal];
	} else {
		[self setTitleColor:[UIColor colorWithRed:0x5c / 255.0f green:0x70 / 255.0f
											 blue:0x8b / 255.0f
											alpha:1.0f]
					forState:UIControlStateNormal];
		[self setTitleShadowColor:[UIColor colorWithWhite:1.0f alpha:0.25f]
						 forState:UIControlStateNormal];
	}
	self.titleLabel.shadowOffset = CGSizeMake(0, -1);
}

@end

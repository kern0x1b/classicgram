#import "TGPlaceholderView.h"

@implementation TGPlaceholderView

- (instancetype)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		self.backgroundColor = [UIColor clearColor];

		_iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
		[self addSubview:_iconView];

		_titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		_titleLabel.backgroundColor = [UIColor clearColor];
		_titleLabel.textAlignment = NSTextAlignmentCenter;
		[self addSubview:_titleLabel];

		_bodyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		_bodyLabel.backgroundColor = [UIColor clearColor];
		_bodyLabel.textAlignment = NSTextAlignmentCenter;
		_bodyLabel.numberOfLines = 0;
		_bodyLabel.lineBreakMode = NSLineBreakByWordWrapping;
		[self addSubview:_bodyLabel];

		_actionButton = [UIButton buttonWithType:UIButtonTypeCustom];
		_actionButton.hidden = YES;
		[self addSubview:_actionButton];
	}
	return self;
}

- (CGFloat)layoutContentWidth:(CGFloat)width {
	CGFloat contentWidth = width - 18;
	CGFloat top = 0;

	self.iconView.hidden = (self.iconView.image == nil);
	if (!self.iconView.hidden) {
		CGSize icon = self.iconView.image.size;
		self.iconView.frame = CGRectMake((int)((width - icon.width) / 2), 0,
			icon.width, icon.height);
		top = CGRectGetMaxY(self.iconView.frame) + 21;
	}

	[self.titleLabel sizeToFit];
	CGRect titleFrame = self.titleLabel.frame;
	titleFrame.origin = CGPointMake((int)((width - titleFrame.size.width) / 2), top);
	self.titleLabel.frame = titleFrame;
	CGFloat height = CGRectGetMaxY(titleFrame);

	if (self.bodyLabel.text.length) {
		CGSize fits = [self.bodyLabel sizeThatFits:CGSizeMake(contentWidth, 1000)];
		self.bodyLabel.frame = CGRectMake((int)((width - fits.width) / 2),
			CGRectGetMaxY(titleFrame) + 8, fits.width, fits.height);
		self.bodyLabel.hidden = NO;
		height = CGRectGetMaxY(self.bodyLabel.frame);
	} else {
		self.bodyLabel.hidden = YES;
	}

	NSString *buttonTitle = [self.actionButton titleForState:UIControlStateNormal];
	if (buttonTitle.length) {
		CGSize fits = [self.actionButton.titleLabel sizeThatFits:CGSizeMake(contentWidth, 40)];
		CGFloat buttonWidth = MIN(contentWidth, fits.width + 32);
		CGFloat buttonHeight = 38;
		self.actionButton.frame = CGRectMake((int)((width - buttonWidth) / 2),
			height + 18, buttonWidth, buttonHeight);
		self.actionButton.hidden = NO;
		height = CGRectGetMaxY(self.actionButton.frame);
	} else {
		self.actionButton.hidden = YES;
	}

	return height;
}

@end

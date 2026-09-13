#import "TGMosaicTileView.h"

@implementation TGMosaicTileView

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (!self)
		return nil;
	self.contentMode = UIViewContentModeScaleAspectFill;
	self.clipsToBounds = YES;
	self.userInteractionEnabled = YES;
	_disc = [[UIImageView alloc] initWithFrame:CGRectZero];
	_disc.hidden = YES;
	_disc.userInteractionEnabled = NO;
	[self addSubview:_disc];
	return self;
}

@end

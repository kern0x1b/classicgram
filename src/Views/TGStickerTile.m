#import "TGStickerTile.h"
#import "TGStickerPanelViewInternal.h"
#import "TGTheme.h"
#import "TGViewRecycler.h"

@implementation TGStickerTile

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self != nil) {
		self.reuseIdentifier = @"stickerTile";
		self.opaque = NO;
		self.backgroundColor = [UIColor clearColor];
		self.exclusiveTouch = YES;

		_pressPlate = [[UIImageView alloc] initWithFrame:self.bounds];
		UIImage *pressed = TGStickerPanelKeyPlate(YES);
		if (pressed != nil)
			_pressPlate.image = pressed;
		else
			_pressPlate.backgroundColor = [[TGTheme shared] separatorColour];
		_pressPlate.layer.cornerRadius = kStickerPanelTileCornerRadius;
		_pressPlate.clipsToBounds = YES;
		_pressPlate.userInteractionEnabled = NO;
		_pressPlate.hidden = YES;
		[self addSubview:_pressPlate];

		_emojiLabel = [[UILabel alloc] initWithFrame:self.bounds];
		_emojiLabel.backgroundColor = [UIColor clearColor];
		_emojiLabel.textAlignment = NSTextAlignmentCenter;
		_emojiLabel.font = [UIFont systemFontOfSize:32];
		_emojiLabel.userInteractionEnabled = NO;
		[self addSubview:_emojiLabel];

		_imageView = [[UIImageView alloc] initWithFrame:self.bounds];
		_imageView.contentMode = UIViewContentModeScaleAspectFit;
		_imageView.userInteractionEnabled = NO;
		[self addSubview:_imageView];
	}
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGRect bounds = self.bounds;
	CGPoint centre = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
	_pressPlate.frame = bounds;
	_emojiLabel.bounds = CGRectMake(0, 0, bounds.size.width, bounds.size.height);
	_emojiLabel.center = centre;
	_imageView.bounds = CGRectMake(0, 0, bounds.size.width, bounds.size.height);
	_imageView.center = centre;
}

- (void)setHighlighted:(BOOL)highlighted {
	[super setHighlighted:highlighted];
	_pressPlate.hidden = !highlighted;
	CGAffineTransform wanted = highlighted
		? CGAffineTransformMakeScale(0.88f, 0.88f)
		: CGAffineTransformIdentity;
	_imageView.transform = wanted;
	_emojiLabel.transform = wanted;
}

- (void)reset {
	self.pressPlate.hidden = YES;
	self.imageView.transform = CGAffineTransformIdentity;
	self.emojiLabel.transform = CGAffineTransformIdentity;
	self.alpha = 1.0f;
	self.sticker = nil;
	self.imageKey = nil;
	self.imageView.image = nil;
	self.imageView.alpha = 1.0f;
	self.emojiLabel.text = @"";
}

- (void)prepareForReuse {
	[self reset];
}

- (void)prepareForRecycle:(TGViewRecycler *)recycler {
	[self reset];
	[self removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
	for (UIGestureRecognizer *recogniser in [self.gestureRecognizers copy])
		[self removeGestureRecognizer:recogniser];
}

@end

#import "TGMediaTileView.h"
#import "TGDurationText.h"
#import "TGIcons.h"
#import "TGViewRecycler.h"

const CGFloat kMediaTileSide = 75.0f;
const CGFloat kMediaTileSpacing = 4.0f;

NSString *const TGMediaTileIdentifier = @"TGMediaTile";

UIColor *TGMediaPlaceholderColour(void) {
	static UIColor *colour = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		colour = [UIColor colorWithRed:0xdf / 255.0f green:0xe4 / 255.0f
								  blue:0xeb / 255.0f
								 alpha:1.0f];
	});
	return colour;
}

NSString *TGMediaFormatDuration(NSInteger seconds) {
	return TGDurationText(seconds);
}

UIImage *TGMediaTilePlaceholder(void) {
	static UIImage *placeholder = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		placeholder = [UIImage imageNamed:@"FlatImagePlaceholder.png"];
		if (placeholder)
			return;
		CGSize size = CGSizeMake(kMediaTileSide, kMediaTileSide);
		UIGraphicsBeginImageContextWithOptions(size, YES, 0.0f);
		[TGMediaPlaceholderColour() setFill];
		UIRectFill(CGRectMake(0, 0, size.width, size.height));
		placeholder = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
	});
	return placeholder;
}

@implementation TGMediaTileView

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		self.reuseIdentifier = TGMediaTileIdentifier;
		self.clipsToBounds = YES;
		self.contentMode = UIViewContentModeScaleAspectFill;
		self.userInteractionEnabled = NO;
		self.fadeTransition = true;
		self.backgroundColor = TGMediaPlaceholderColour();

		UIImage *shadow = [UIImage imageNamed:@"MediaGridImageShadow.png"];
		if (shadow) {
			_shadowView = [[UIImageView alloc] initWithImage:
					[shadow stretchableImageWithLeftCapWidth:(int)(shadow.size.width / 2)
												topCapHeight:(int)(shadow.size.height / 2)]];
			_shadowView.frame = CGRectMake(0, 0, kMediaTileSide, kMediaTileSide);
			_shadowView.userInteractionEnabled = NO;
			[self addSubview:_shadowView];
		}
	}
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	if (_shadowView)
		_shadowView.frame = self.bounds;
}

- (void)buildBadge {
	if (_badgeBar)
		return;

	CGRect badgeFrame = CGRectMake(0, kMediaTileSide - 19, kMediaTileSide, 19);
	_badgeBar = [[UIView alloc] initWithFrame:badgeFrame];
	_badgeBar.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.6f];
	_badgeBar.userInteractionEnabled = NO;

	UIImage *play = [UIImage imageNamed:@"MessageInlineVideoIcon.png"];
	if (play) {
		_playView = [[UIImageView alloc] initWithImage:play];
		_playView.frame = CGRectOffset(_playView.frame, 4, 5);
	} else {
		play = [TGIcons play];
		_playView = [[UIImageView alloc] initWithImage:play];
		_playView.frame = CGRectMake(4, (int)((19 - MIN(11.0f, play.size.height)) / 2),
			MIN(11.0f, play.size.width), MIN(11.0f, play.size.height));
		_playView.contentMode = UIViewContentModeScaleAspectFit;
	}
	[_badgeBar addSubview:_playView];

	_badgeLabel = [[UILabel alloc] initWithFrame:CGRectMake(kMediaTileSide - 56 - 3, 0, 56, 19)];
	_badgeLabel.backgroundColor = [UIColor clearColor];
	_badgeLabel.textColor = [UIColor whiteColor];
	_badgeLabel.font = [UIFont boldSystemFontOfSize:10];
	_badgeLabel.textAlignment = NSTextAlignmentRight;
	[_badgeBar addSubview:_badgeLabel];

	[self addSubview:_badgeBar];
}

- (void)showVideoBadge:(NSString *)text {
	[self buildBadge];
	_badgeLabel.text = text;
	_badgeBar.hidden = NO;
	_badgeBar.frame = CGRectMake(0, self.bounds.size.height - 19, self.bounds.size.width, 19);
	_badgeLabel.frame = CGRectMake(self.bounds.size.width - 56 - 3, 0, 56, 19);
}

- (void)hideVideoBadge {
	_badgeBar.hidden = YES;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	[self hideVideoBadge];
	self.image = TGMediaTilePlaceholder();
}

- (void)prepareForRecycle:(TGViewRecycler *)recycler {
	[super prepareForRecycle:recycler];
	[self hideVideoBadge];
	self.image = nil;
	self.fileId = nil;
}

@end

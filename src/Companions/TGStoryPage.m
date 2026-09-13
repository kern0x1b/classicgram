#import "TGStoryPage.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGImageDecode.h"
#import "TGLazyFramework.h"
#import "TGStoryHelpers.h"
#import <MediaPlayer/MediaPlayer.h>

static NSString *TGStoryAreaChipText(NSDictionary *area) {
	NSString *kind = TGStoryString(area, @"kind");
	NSString *title = TGStoryString(area, @"title");

	if ([kind isEqualToString:@"location"])
		return [NSString stringWithFormat:@"\U0001F4CD %@", title.length > 0 ? title : TGL(@"Map.Location", @"Location")];
	if ([kind isEqualToString:@"venue"])
		return [NSString stringWithFormat:@"\U0001F4CD %@", title.length > 0 ? title : TGL(@"Story.Areas.Venue", @"Venue")];
	if ([kind isEqualToString:@"weather"])
		return [NSString stringWithFormat:@"%@ %@", TGStoryString(area, @"emoji"), title];
	if ([kind isEqualToString:@"gift"])
		return [NSString stringWithFormat:@"\U0001F381 %@", title.length > 0 ? title : TGL(@"Attachment.Gift", @"Gift")];
	if ([kind isEqualToString:@"link"])
		return [NSString stringWithFormat:@"\U0001F517 %@", TGL(@"Channel.Edit.LinkItem", @"Link")];
	if ([kind isEqualToString:@"message"])
		return [NSString stringWithFormat:@"\U0001F4AC %@", TGL(@"Call.Message", @"Message")];
	if ([kind isEqualToString:@"reaction"]) {
		NSString *emoji = TGStoryString(area, @"emoji");
		return emoji.length > 0 ? emoji : @"❤";
	}
	return nil;
}

@implementation TGStoryPage {
	UIImageView *_imageView;
	UIView *_captionPlate;
	UILabel *_captionLabel;
	UIActivityIndicatorView *_spinner;
	UILabel *_statusLabel;
	NSArray *_areas;
	NSMutableArray *_areaChipViews;
	NSMutableArray *_areaChipAreas;
	MPMoviePlayerController *_videoPlayer;
	NSString *_videoPath;
}

- (NSString *)videoPath {
	return _videoPath;
}

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self != nil) {
		self.backgroundColor = [UIColor clearColor];

		_imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
		_imageView.backgroundColor = [UIColor blackColor];
		_imageView.contentMode = UIViewContentModeScaleAspectFit;
		_imageView.userInteractionEnabled = NO;
		[self addSubview:_imageView];

		_captionPlate = [[UIView alloc] initWithFrame:CGRectZero];
		_captionPlate.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.45f];
		_captionPlate.userInteractionEnabled = NO;
		_captionPlate.hidden = YES;
		[self addSubview:_captionPlate];

		_captionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		_captionLabel.backgroundColor = [UIColor clearColor];
		_captionLabel.textColor = [UIColor whiteColor];
		_captionLabel.font = [UIFont systemFontOfSize:15];
		_captionLabel.numberOfLines = 2;
		_captionLabel.lineBreakMode = NSLineBreakByTruncatingTail;
		[_captionPlate addSubview:_captionLabel];

		_spinner = [[UIActivityIndicatorView alloc]
			initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
		_spinner.hidesWhenStopped = YES;
		_spinner.userInteractionEnabled = NO;
		[self addSubview:_spinner];

		_statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		_statusLabel.backgroundColor = [UIColor clearColor];
		_statusLabel.textColor = [UIColor whiteColor];
		_statusLabel.font = [UIFont systemFontOfSize:14];
		_statusLabel.textAlignment = NSTextAlignmentCenter;
		_statusLabel.numberOfLines = 2;
		_statusLabel.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.5f];
		_statusLabel.shadowOffset = CGSizeMake(0, -1);
		_statusLabel.text = TGL(@"Stories.PhotoUnavailableTapToReload", @"Photo unavailable\nTap to reload");
		_statusLabel.hidden = YES;
		_statusLabel.userInteractionEnabled = NO;
		[self addSubview:_statusLabel];
	}
	return self;
}

- (void)beginLoading {
	_failed = NO;
	_statusLabel.hidden = YES;
	if (_imageView.image == nil)
		[_spinner startAnimating];
	[self setNeedsLayout];
}

- (void)showFailure {
	[_spinner stopAnimating];
	if (_imageView.image != nil)
		return;
	_failed = YES;
	_statusLabel.hidden = NO;
	[self setNeedsLayout];
}

- (BOOL)isRetryPoint:(CGPoint)point {
	if (!_failed)
		return NO;
	CGRect area = self.bounds;
	if (area.size.width < 1.0f || area.size.height < 1.0f)
		return NO;
	CGRect band = CGRectMake(area.size.width / 3.0f,
		CGRectGetMidY(area) - 40.0f,
		area.size.width / 3.0f,
		80.0f);
	return CGRectContainsPoint(band, point);
}

- (UIImage *)image {
	return _imageView.image;
}

- (void)setStoryImage:(UIImage *)image animated:(BOOL)animated {
	if (image != nil) {
		_failed = NO;
		_statusLabel.hidden = YES;
		[_spinner stopAnimating];
	}
	if (animated && image != nil) {
		UIImageView *view = _imageView;
		[UIView transitionWithView:view
						  duration:0.15
						   options:UIViewAnimationOptionTransitionCrossDissolve
						animations:^{ view.image = image; }
						completion:nil];
	} else {
		_imageView.image = image;
	}
	[self setNeedsLayout];
}

- (void)playVideoAtPath:(NSString *)path {
	[self stopVideo];
	if (!path.length)
		return;

	MPMoviePlayerController *player = [[TGMPClass(MPMoviePlayerController) alloc]
		initWithContentURL:[NSURL fileURLWithPath:path]];
	if (!player)
		return;

	_videoPath = [path copy];

	player.controlStyle = MPMovieControlStyleNone;
	player.scalingMode = MPMovieScalingModeAspectFit;
	player.shouldAutoplay = NO;
	player.repeatMode = MPMovieRepeatModeNone;
	player.view.frame = _imageView.frame;
	player.view.autoresizingMask = _imageView.autoresizingMask;
	player.view.userInteractionEnabled = NO;
	[self insertSubview:player.view aboveSubview:_imageView];

	_videoPlayer = player;
	[player prepareToPlay];
	[player play];
}

- (void)stopVideo {
	[_videoPlayer stop];
	[_videoPlayer.view removeFromSuperview];
	_videoPlayer = nil;
	_videoPath = nil;
}

- (void)pauseVideo {
	[_videoPlayer pause];
}

- (void)resumeVideo {
	[_videoPlayer play];
}

- (void)setCaption:(NSString *)caption {
	_captionLabel.text = caption ?: @"";
	_captionPlate.hidden = (caption.length == 0);
	[self setNeedsLayout];
}

- (void)setCaptionBottomInset:(CGFloat)captionBottomInset {
	if (_captionBottomInset == captionBottomInset)
		return;
	_captionBottomInset = captionBottomInset;
	[self setNeedsLayout];
}

- (void)setAreas:(NSArray *)areas {
	_areas = [areas isKindOfClass:[NSArray class]] ? [areas copy] : nil;

	for (UIView *chip in _areaChipViews)
		[chip removeFromSuperview];
	if (_areaChipViews == nil)
		_areaChipViews = [NSMutableArray array];
	else
		[_areaChipViews removeAllObjects];
	if (_areaChipAreas == nil)
		_areaChipAreas = [NSMutableArray array];
	else
		[_areaChipAreas removeAllObjects];

	for (NSDictionary *area in _areas) {
		if (![area isKindOfClass:[NSDictionary class]])
			continue;
		NSString *text = TGStoryAreaChipText(area);
		if (text.length == 0)
			continue;

		BOOL isReaction = [TGStoryString(area, @"kind") isEqualToString:@"reaction"];

		UIView *plate = [[UIView alloc] initWithFrame:CGRectZero];
		plate.backgroundColor = isReaction ? [UIColor clearColor] : [UIColor colorWithWhite:0.0f alpha:0.45f];
		plate.layer.cornerRadius = 12.0f;
		plate.layer.masksToBounds = YES;
		plate.userInteractionEnabled = NO;

		UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
		label.backgroundColor = [UIColor clearColor];
		label.textColor = [UIColor whiteColor];
		label.font = [UIFont systemFontOfSize:(isReaction ? 28.0f : 13.0f)];
		label.text = text;
		[label sizeToFit];
		[plate addSubview:label];

		CGSize size = isReaction ? label.bounds.size : CGSizeMake(label.bounds.size.width + 16.0f, label.bounds.size.height + 8.0f);
		plate.bounds = CGRectMake(0.0f, 0.0f, size.width, size.height);
		label.center = CGPointMake(size.width / 2.0f, size.height / 2.0f);

		[self addSubview:plate];
		[_areaChipViews addObject:plate];
		[_areaChipAreas addObject:area];
	}

	[self setNeedsLayout];
}

- (CGRect)storyFrame {
	CGRect area = self.bounds;
	CGSize size = CGSizeMake(9.0f, 16.0f);
	CGFloat scale = MIN(area.size.width / size.width, area.size.height / size.height);
	CGFloat drawWidth = floorf(size.width * scale);
	CGFloat drawHeight = floorf(size.height * scale);
	return CGRectMake(floorf((area.size.width - drawWidth) / 2.0f),
		floorf((area.size.height - drawHeight) / 2.0f),
		drawWidth, drawHeight);
}

- (CGRect)boxForArea:(NSDictionary *)area inStoryFrame:(CGRect)frame {
	CGFloat width = frame.size.width * (CGFloat)[[area objectForKey:@"width"] doubleValue] / 100.0f;
	CGFloat height = frame.size.height * (CGFloat)[[area objectForKey:@"height"] doubleValue] / 100.0f;
	CGFloat centerX = frame.origin.x +
		frame.size.width * (CGFloat)[[area objectForKey:@"x"] doubleValue] / 100.0f;
	CGFloat centerY = frame.origin.y +
		frame.size.height * (CGFloat)[[area objectForKey:@"y"] doubleValue] / 100.0f;
	return CGRectMake(centerX - width / 2.0f, centerY - height / 2.0f, width, height);
}

- (NSDictionary *)areaAtPoint:(CGPoint)point {
	if (_areas.count == 0)
		return nil;

	CGRect frame = [self storyFrame];
	if (frame.size.width < 1.0f || frame.size.height < 1.0f)
		return nil;

	for (NSDictionary *area in _areas) {
		if (![area isKindOfClass:[NSDictionary class]])
			continue;
		CGRect box = [self boxForArea:area inStoryFrame:frame];
		if (box.size.width < 1.0f || box.size.height < 1.0f)
			continue;
		if (CGRectContainsPoint(CGRectInset(box, -4.0f, -4.0f), point))
			return area;
	}
	return nil;
}

- (void)prepareForReuse {
	_imageView.image = nil;
	_captionLabel.text = @"";
	_captionPlate.hidden = YES;
	_areas = nil;
	for (UIView *chip in _areaChipViews)
		[chip removeFromSuperview];
	[_areaChipViews removeAllObjects];
	[_areaChipAreas removeAllObjects];
	_failed = NO;
	_statusLabel.hidden = YES;
	[_spinner stopAnimating];
	self.itemId = nil;
	self.photoFileId = nil;
	self.videoFileId = nil;
	[self stopVideo];
}

- (CGRect)captionFrame {
	if (_captionPlate.hidden)
		return CGRectZero;
	return _captionPlate.frame;
}

- (void)layoutSubviews {
	[super layoutSubviews];

	CGRect area = self.bounds;
	CGRect frame = [self storyFrame];
	_imageView.frame = frame;
	_videoPlayer.view.frame = frame;

	_spinner.center = CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
	_statusLabel.frame = CGRectMake(frame.origin.x,
		floorf(CGRectGetMidY(frame) - 20.0f),
		frame.size.width, 40.0f);

	CGFloat plateBottom = MIN(CGRectGetMaxY(frame), area.size.height - _captionBottomInset);
	CGFloat available = MAX(0.0f, plateBottom - frame.origin.y);
	CGFloat plateHeight = MIN(kStoryCaptionHeight, available);
	_captionPlate.frame = CGRectMake(frame.origin.x,
		plateBottom - plateHeight,
		frame.size.width, plateHeight);
	_captionLabel.frame = CGRectInset(_captionPlate.bounds, 8.0f, 6.0f);

	for (NSInteger i = 0; i < _areaChipViews.count; i++) {
		UIView *chip = _areaChipViews[i];
		NSDictionary *chipArea = _areaChipAreas[i];
		CGRect box = [self boxForArea:chipArea inStoryFrame:frame];
		CGPoint center = CGPointMake(CGRectGetMidX(box), CGRectGetMidY(box));
		CGSize chipSize = chip.bounds.size;

		CGFloat minX = frame.origin.x + chipSize.width / 2.0f + 4.0f;
		CGFloat maxX = CGRectGetMaxX(frame) - chipSize.width / 2.0f - 4.0f;
		if (maxX > minX)
			center.x = MAX(minX, MIN(maxX, center.x));

		CGFloat minY = frame.origin.y + chipSize.height / 2.0f + 4.0f;
		CGFloat maxY = CGRectGetMaxY(frame) - chipSize.height / 2.0f - 4.0f;
		if (maxY > minY)
			center.y = MAX(minY, MIN(maxY, center.y));

		chip.center = center;
	}
}

@end

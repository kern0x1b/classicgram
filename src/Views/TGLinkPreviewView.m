#import "TGLinkPreviewView.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGHexColour.h"

static const CGFloat kPreviewBar = 2.0f;
static const CGFloat kPreviewGap = 8.0f;
static const CGFloat kPreviewThumb = 52.0f;
static const CGFloat kPreviewLargeMax = 160.0f;
static const CGFloat kInstantHeight = 33.0f;
static const CGFloat kMediaRadius = 6.0f;

@implementation TGLinkPreviewView {
	UIView *_bar;
	UILabel *_site;
	UILabel *_title;
	UILabel *_text;
	UIImageView *_thumb;
	UIButton *_instant;
}

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (!self)
		return nil;
	self.backgroundColor = [UIColor clearColor];

	_bar = [[UIView alloc] init];
	[self addSubview:_bar];

	_site = [[UILabel alloc] init];
	_site.font = [UIFont boldSystemFontOfSize:14];
	_site.backgroundColor = [UIColor clearColor];
	[self addSubview:_site];

	_title = [[UILabel alloc] init];
	_title.font = [UIFont boldSystemFontOfSize:14];
	_title.numberOfLines = 2;
	_title.backgroundColor = [UIColor clearColor];
	_title.textColor = TGColourFromHex(0x141617);
	[self addSubview:_title];

	_text = [[UILabel alloc] init];
	_text.font = [UIFont systemFontOfSize:14];
	_text.numberOfLines = 2;
	_text.backgroundColor = [UIColor clearColor];
	_text.textColor = TGColourFromHex(0x62768A);
	[self addSubview:_text];

	_thumb = [[UIImageView alloc] init];
	_thumb.contentMode = UIViewContentModeScaleAspectFill;
	_thumb.clipsToBounds = YES;
	[self addSubview:_thumb];

	_instant = [UIButton buttonWithType:UIButtonTypeCustom];
	_instant.titleLabel.font = [UIFont boldSystemFontOfSize:13];
	[_instant setTitleColor:TGColourFromHex(0x506E8D) forState:UIControlStateNormal];
	[_instant setTitleShadowColor:[UIColor colorWithWhite:1.0f alpha:0.7f]
						 forState:UIControlStateNormal];
	_instant.titleLabel.shadowOffset = CGSizeMake(0, 1);
	[_instant setTitle:TGL(@"Conversation.InstantPagePreview", @"INSTANT VIEW") forState:UIControlStateNormal];
	[_instant addTarget:self action:@selector(instantTapped)
		forControlEvents:UIControlEventTouchUpInside];
	_instant.hidden = YES;
	[self addSubview:_instant];

	[self addGestureRecognizer:[[UITapGestureRecognizer alloc]
								   initWithTarget:self
										   action:@selector(blockTapped:)]];
	return self;
}

+ (BOOL)preview:(NSDictionary *)preview showsLargeMediaWithImage:(UIImage *)image {
	if (!image)
		return NO;
	return [preview[@"showLargeMedia"] boolValue];
}

+ (CGSize)largeImageSizeForImage:(UIImage *)image width:(CGFloat)width {
	if (!image || image.size.width < 1)
		return CGSizeZero;
	CGFloat height = image.size.height * (width / image.size.width);
	return CGSizeMake(width, MIN(height, kPreviewLargeMax));
}

+ (CGSize)sizeForPreview:(NSDictionary *)preview
				   image:(UIImage *)image
				maxWidth:(CGFloat)maxWidth {
	if (![preview[@"url"] length])
		return CGSizeZero;

	CGFloat columnX = kPreviewBar + kPreviewGap;
	CGFloat columnW = maxWidth - columnX;
	BOOL large = [self preview:preview showsLargeMediaWithImage:image];
	BOOL smallThumb = (image != nil && !large);
	CGFloat textW = smallThumb ? columnW - kPreviewThumb - 6 : columnW;
	if (textW < 40)
		textW = columnW;

	CGFloat textH = 0;
	if ([preview[@"siteName"] length])
		textH += 17;
	NSString *title = preview[@"title"];
	if ([title length]) {
		CGSize s = [title sizeWithFont:[UIFont boldSystemFontOfSize:14]
					 constrainedToSize:CGSizeMake(textW, 32)
						 lineBreakMode:NSLineBreakByWordWrapping];
		textH += MIN(s.height, 32);
	}
	NSString *body = preview[@"description"];
	if ([body length]) {
		CGSize s = [body sizeWithFont:[UIFont systemFontOfSize:14]
					constrainedToSize:CGSizeMake(textW, 32)
						lineBreakMode:NSLineBreakByWordWrapping];
		textH += MIN(s.height, 32);
	}

	CGFloat height = textH;
	if (smallThumb)
		height = MAX(height, kPreviewThumb);
	if (large)
		height += [self largeImageSizeForImage:image width:columnW].height + 5;
	if (height < 1)
		return CGSizeZero;
	if ([preview[@"hasInstantView"] boolValue])
		height += 8 + kInstantHeight;

	CGFloat width = (large || smallThumb) ? maxWidth : columnX + textW;
	return CGSizeMake(width, ceilf(height));
}

- (void)configureWithPreview:(NSDictionary *)preview
					   image:(UIImage *)image
					outgoing:(BOOL)outgoing
					maxWidth:(CGFloat)maxWidth {
	self.url = preview[@"url"];

	UIColor *accent = outgoing ? TGColourFromHex(0x3A8E26) : TGColourFromHex(0x0E7ACD);
	CGFloat columnX = kPreviewBar + kPreviewGap;
	CGFloat columnW = maxWidth - columnX;
	BOOL large = [TGLinkPreviewView preview:preview showsLargeMediaWithImage:image];
	BOOL smallThumb = (image != nil && !large);
	BOOL mediaAbove = large && [preview[@"showMediaAboveDescription"] boolValue];
	CGFloat textW = smallThumb ? columnW - kPreviewThumb - 6 : columnW;
	if (textW < 40)
		textW = columnW;

	CGFloat y = 0;
	CGSize largeSize = large
		? [TGLinkPreviewView largeImageSizeForImage:image width:columnW]
		: CGSizeZero;

	_thumb.image = image;
	_thumb.hidden = (image == nil);
	if (smallThumb) {
		_thumb.frame = CGRectMake(maxWidth - kPreviewThumb, 0, kPreviewThumb, kPreviewThumb);
		_thumb.layer.cornerRadius = 4;
	} else if (large) {
		_thumb.layer.cornerRadius = kMediaRadius;
		if (mediaAbove) {
			_thumb.frame = CGRectMake(columnX, y, largeSize.width, largeSize.height);
			y += largeSize.height + 5;
		}
	}

	NSString *site = preview[@"siteName"];
	_site.hidden = ![site length];
	if (!_site.hidden) {
		_site.text = site;
		_site.textColor = accent;
		_site.frame = CGRectMake(columnX, y, textW, 17);
		y += 17;
	}

	NSString *title = preview[@"title"];
	_title.hidden = ![title length];
	if (!_title.hidden) {
		CGSize s = [title sizeWithFont:[UIFont boldSystemFontOfSize:14]
					 constrainedToSize:CGSizeMake(textW, 32)
						 lineBreakMode:NSLineBreakByWordWrapping];
		_title.text = title;
		_title.frame = CGRectMake(columnX, y, textW, MIN(s.height, 32));
		y += MIN(s.height, 32);
	}

	NSString *body = preview[@"description"];
	_text.hidden = ![body length];
	if (!_text.hidden) {
		CGSize s = [body sizeWithFont:[UIFont systemFontOfSize:14]
					constrainedToSize:CGSizeMake(textW, 32)
						lineBreakMode:NSLineBreakByWordWrapping];
		_text.text = body;
		_text.frame = CGRectMake(columnX, y, textW, MIN(s.height, 32));
		y += MIN(s.height, 32);
	}

	if (large && !mediaAbove) {
		_thumb.frame = CGRectMake(columnX, y, largeSize.width, largeSize.height);
		y += largeSize.height + 5;
	}
	if (smallThumb)
		y = MAX(y, kPreviewThumb);

	_instant.hidden = ![preview[@"hasInstantView"] boolValue];
	if (!_instant.hidden) {
		[_instant setTitle:(self.buttonTitleOverride.length
								   ? self.buttonTitleOverride
								   : TGL(@"Conversation.InstantPagePreview", @"INSTANT VIEW"))
				  forState:UIControlStateNormal];
		UIImage *plate = [UIImage imageNamed:@"GroupedActionButton.png"];
		UIImage *pressed = [UIImage imageNamed:@"GroupedActionButton_Highlighted.png"];
		if (plate)
			[_instant setBackgroundImage:[plate stretchableImageWithLeftCapWidth:24 topCapHeight:0]
								forState:UIControlStateNormal];
		if (pressed)
			[_instant setBackgroundImage:[pressed stretchableImageWithLeftCapWidth:24 topCapHeight:0]
								forState:UIControlStateHighlighted];
		_instant.frame = CGRectMake(kPreviewBar, y + 8, maxWidth - kPreviewBar, kInstantHeight);
		y += 8 + kInstantHeight;
	}

	_bar.backgroundColor = accent;
	CGFloat barBottom = _instant.hidden ? y : (y - 8 - kInstantHeight);
	_bar.frame = CGRectMake(0, 0, kPreviewBar, MAX(0, barBottom));
}

- (void)blockTapped:(UITapGestureRecognizer *)recognizer {
	if (!self.url.length)
		return;

	CGPoint point = [recognizer locationInView:self];
	if (self.onOpenMedia && !_thumb.hidden && CGRectContainsPoint(_thumb.frame, point)) {
		self.onOpenMedia(self.url);
		return;
	}
	if (self.onOpen)
		self.onOpen(self.url);
}

- (void)instantTapped {
	if (self.onInstantView && self.url.length)
		self.onInstantView(self.url);
}

@end

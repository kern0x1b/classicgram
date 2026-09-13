#import "TGQuoteBadgeView.h"

@interface TGQuoteBadgeView ()

@property (nonatomic, strong, readwrite) UIView *bar;
@property (nonatomic, strong, readwrite) TGEmojiLabel *authorLabel;
@property (nonatomic, strong, readwrite) TGEmojiLabel *textLabel;
@property (nonatomic, strong, readwrite) UIImageView *thumbnail;
@property (nonatomic, strong, readwrite) UIButton *tapTarget;

@end

@implementation TGQuoteBadgeView

- (instancetype)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (!self)
		return nil;

	self.bar = [[UIView alloc] init];
	[self addSubview:self.bar];

	self.authorLabel = [[TGEmojiLabel alloc] init];
	self.authorLabel.numberOfLines = 1;
	self.authorLabel.backgroundColor = [UIColor clearColor];
	[self addSubview:self.authorLabel];

	self.textLabel = [[TGEmojiLabel alloc] init];
	self.textLabel.numberOfLines = 1;
	self.textLabel.backgroundColor = [UIColor clearColor];
	[self addSubview:self.textLabel];

	self.thumbnail = [[UIImageView alloc] init];
	self.thumbnail.contentMode = UIViewContentModeScaleAspectFill;
	self.thumbnail.clipsToBounds = YES;
	self.thumbnail.hidden = YES;
	[self addSubview:self.thumbnail];

	self.tapTarget = [UIButton buttonWithType:UIButtonTypeCustom];
	self.tapTarget.backgroundColor = [UIColor clearColor];
	[self addSubview:self.tapTarget];

	return self;
}

- (void)layoutWithBarFrame:(CGRect)barFrame
			   authorFrame:(CGRect)authorFrame
				 textFrame:(CGRect)textFrame
			thumbnailFrame:(CGRect)thumbnailFrame
			tapTargetFrame:(CGRect)tapTargetFrame {
	self.bar.frame = barFrame;
	self.authorLabel.frame = authorFrame;
	self.textLabel.frame = textFrame;
	self.thumbnail.image = nil;
	self.thumbnail.hidden = CGRectIsEmpty(thumbnailFrame);
	if (!self.thumbnail.hidden)
		self.thumbnail.frame = thumbnailFrame;
	self.tapTarget.frame = tapTargetFrame;
}

@end

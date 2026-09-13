#import "TGMessageRowCell.h"
#import "TGMessageItem.h"
#import "TGMessageLayout.h"
#import <QuartzCore/QuartzCore.h>

extern const CGFloat kSystemPlateHeight;
extern const CGFloat kDayRowHeight;
extern const CGFloat kUnreadRowHeight;
extern const CGFloat kRetinaPixel;
extern UIColor *TGSystemPlateColour(void);
extern UIImage *TGUnreadDividerImage(void);
extern UIImage *TGUnreadArrowImage(void);

@interface TGMessageRowCell ()

@property (nonatomic, strong, readwrite) UIView *dayPlate;
@property (nonatomic, strong, readwrite) UILabel *dayLabel;
@property (nonatomic, strong, readwrite) UIButton *dayHit;
@property (nonatomic, strong, readwrite) UIView *unreadStrip;
@property (nonatomic, strong, readwrite) UIView *unreadTopLine;
@property (nonatomic, strong, readwrite) UIView *unreadBottomLine;
@property (nonatomic, strong, readwrite) UILabel *unreadLabel;
@property (nonatomic, strong, readwrite) UIImageView *unreadArrow;
@property (nonatomic, strong, readwrite) UIImageView *selectionCheck;

@property (nonatomic, assign, readwrite) int64_t appliedMessageId;
@property (nonatomic, assign) CGRect lastSelectionCheckFrame;

@end

@implementation TGMessageRowCell

- (void)buildDayPlateViews {
	self.dayPlate = [[UIView alloc] init];
	self.dayPlate.backgroundColor = TGSystemPlateColour();
	self.dayPlate.layer.cornerRadius = kSystemPlateHeight / 2;
	self.dayPlate.userInteractionEnabled = NO;
	self.dayPlate.hidden = YES;
	[self addSubview:self.dayPlate];

	self.dayLabel = [[UILabel alloc] init];
	self.dayLabel.font = [UIFont boldSystemFontOfSize:13];
	self.dayLabel.textColor = [UIColor whiteColor];
	self.dayLabel.textAlignment = NSTextAlignmentCenter;
	self.dayLabel.backgroundColor = [UIColor clearColor];
	self.dayLabel.userInteractionEnabled = NO;
	self.dayLabel.hidden = YES;
	[self addSubview:self.dayLabel];

	self.dayHit = [UIButton buttonWithType:UIButtonTypeCustom];
	self.dayHit.backgroundColor = [UIColor clearColor];
	self.dayHit.hidden = YES;
	[self.dayHit addTarget:self action:@selector(dayPlateTapped)
		  forControlEvents:UIControlEventTouchUpInside];
	[self addSubview:self.dayHit];
}

- (void)buildUnreadViews {
	UIImage *dividerArt = TGUnreadDividerImage();
	if (dividerArt) {
		UIImageView *plate = [[UIImageView alloc] initWithImage:dividerArt];
		plate.userInteractionEnabled = NO;
		plate.hidden = YES;
		[self addSubview:plate];
		self.unreadStrip = plate;
	} else {
		self.unreadStrip = [[UIView alloc] init];
		self.unreadStrip.userInteractionEnabled = NO;
		self.unreadStrip.hidden = YES;
		self.unreadStrip.clipsToBounds = YES;
		[self addSubview:self.unreadStrip];

		CAGradientLayer *strip = [CAGradientLayer layer];
		strip.colors = @[
			(id)[UIColor colorWithRed:250 / 255.0f green:253 / 255.0f
								 blue:255 / 255.0f
								alpha:1.0f]
				.CGColor,
			(id)[UIColor colorWithRed:229 / 255.0f green:236 / 255.0f
								 blue:243 / 255.0f
								alpha:1.0f]
				.CGColor
		];
		[self.unreadStrip.layer insertSublayer:strip atIndex:0];

		self.unreadTopLine = [[UIView alloc] init];
		UIColor *topLineColour = [UIColor colorWithRed:0 green:35 / 255.0f blue:70 / 255.0f alpha:0.13f];
		self.unreadTopLine.backgroundColor = topLineColour;
		[self.unreadStrip addSubview:self.unreadTopLine];

		self.unreadBottomLine = [[UIView alloc] init];
		UIColor *bottomLineColour = [UIColor colorWithRed:0 green:43 / 255.0f blue:86 / 255.0f alpha:0.26f];
		self.unreadBottomLine.backgroundColor = bottomLineColour;
		[self.unreadStrip addSubview:self.unreadBottomLine];
	}

	self.unreadLabel = [[UILabel alloc] init];
	self.unreadLabel.font = [UIFont boldSystemFontOfSize:13];
	UIColor *unreadTextColour = [UIColor colorWithRed:0x50 / 255.0f green:0x6e / 255.0f blue:0x8d / 255.0f alpha:1.0f];
	self.unreadLabel.textColor = unreadTextColour;
	self.unreadLabel.shadowColor = [UIColor colorWithWhite:1.0f alpha:0.6f];
	self.unreadLabel.shadowOffset = CGSizeMake(0, 1);
	self.unreadLabel.textAlignment = NSTextAlignmentCenter;
	self.unreadLabel.backgroundColor = [UIColor clearColor];
	self.unreadLabel.userInteractionEnabled = NO;
	self.unreadLabel.hidden = YES;
	[self addSubview:self.unreadLabel];

	self.unreadArrow = [[UIImageView alloc] initWithImage:TGUnreadArrowImage()];
	self.unreadArrow.hidden = YES;
	[self addSubview:self.unreadArrow];
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.backgroundColor = [UIColor clearColor];
	self.contentView.backgroundColor = [UIColor clearColor];
	self.selectionStyle = UITableViewCellSelectionStyleNone;

	[self buildDayPlateViews];
	[self buildUnreadViews];

	self.selectionCheck = [[UIImageView alloc] initWithFrame:CGRectMake(2, 0, 26, 26)];
	self.selectionCheck.hidden = YES;
	[self addSubview:self.selectionCheck];

	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.appliedMessageId = 0;
	self.appliedRow = 0;
	self.lastSelectionCheckFrame = CGRectZero;
	self.lastTouchKnown = NO;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	UITouch *touch = [touches anyObject];
	if (touch) {
		self.lastTouchInCell = [touch locationInView:self.contentView];
		self.lastTouchKnown = YES;
	}
	[super touchesBegan:touches withEvent:event];
}

- (TGEmojiLabel *)tg_richTextLabel {
	return nil;
}

- (void)setHeaderHeight:(CGFloat)headerHeight {
	if (_headerHeight == headerHeight)
		return;
	_headerHeight = headerHeight;
	[self setNeedsLayout];
}

- (void)layoutSubviews {
	[super layoutSubviews];

	CGRect content = self.contentView.bounds;
	if (content.origin.y != -_headerHeight) {
		content.origin.y = -_headerHeight;
		self.contentView.bounds = content;
	}

	CGFloat width = self.bounds.size.width;

	if (!self.dayLabel.hidden) {
		[self.dayLabel sizeToFit];
		CGRect label = self.dayLabel.frame;
		label.origin = CGPointMake(floorf((width - label.size.width) / 2),
			floorf((kDayRowHeight - label.size.height) / 2) - 1);
		self.dayLabel.frame = label;
		self.dayPlate.frame = CGRectMake(label.origin.x - 10,
			label.origin.y - 2,
			label.size.width + 20, kSystemPlateHeight);
		[self bringSubviewToFront:self.dayPlate];
		[self bringSubviewToFront:self.dayLabel];
		if (!self.dayHit.hidden) {
			self.dayHit.frame = CGRectInset(self.dayPlate.frame, -14, -3);
			[self bringSubviewToFront:self.dayHit];
		}
	}

	if (!self.unreadStrip.hidden) {
		CGFloat top = _headerHeight - kUnreadRowHeight;
		CGFloat stripH = TGUnreadDividerImage()
			? TGUnreadDividerImage().size.height
			: 27.0f;
		self.unreadStrip.frame = CGRectMake(0, top + 3, width, stripH);
		if (self.unreadTopLine) {
			CALayer *strip = [self.unreadStrip.layer.sublayers count]
				? [self.unreadStrip.layer.sublayers objectAtIndex:0]
				: nil;
			strip.frame = self.unreadStrip.bounds;
			self.unreadTopLine.frame = CGRectMake(0, 0, width, kRetinaPixel);
			self.unreadBottomLine.frame =
				CGRectMake(0, stripH - kRetinaPixel, width, kRetinaPixel);
		}

		[self.unreadLabel sizeToFit];
		CGRect label = self.unreadLabel.frame;
		label.origin = CGPointMake(floorf((width - label.size.width) / 2),
			top + floorf((kUnreadRowHeight - label.size.height) / 2) - 1);
		self.unreadLabel.frame = label;

		CGRect arrow = self.unreadArrow.frame;
		arrow.origin = CGPointMake(width - arrow.size.width - 7, top + 13 + kRetinaPixel);
		self.unreadArrow.frame = arrow;

		[self bringSubviewToFront:self.unreadStrip];
		[self bringSubviewToFront:self.unreadLabel];
		[self bringSubviewToFront:self.unreadArrow];
	}
}

- (void)applyItem:(TGMessageItem *)item layout:(TGMessageLayout *)layout {
	self.appliedMessageId = item.messageId;
	self.headerHeight = layout.headerHeight;

	BOOL opensDay = item.opensNewDay;
	self.dayPlate.hidden = !opensDay;
	self.dayLabel.hidden = !opensDay;
	self.dayHit.hidden = !opensDay;
	if (opensDay)
		self.dayLabel.text = item.dayText;

	BOOL divides = item.carriesUnreadBand;
	self.unreadStrip.hidden = !divides;
	self.unreadLabel.hidden = !divides;
	self.unreadArrow.hidden = !divides;
	if (divides && [self.delegate respondsToSelector:@selector(bubbleCell:unreadBandTextAtRow:)])
		self.unreadLabel.text = [self.delegate bubbleCell:self unreadBandTextAtRow:self.appliedRow];

	self.lastSelectionCheckFrame = layout.row.selectionCheck;
	self.selectionCheck.frame = self.lastSelectionCheckFrame;
}

- (void)setSelectionChecked:(BOOL)checked
					  image:(UIImage *)image
					 hidden:(BOOL)hidden
				   animated:(BOOL)__unused animated {
	self.selectionCheck.hidden = hidden;
	if (!hidden) {
		self.selectionCheck.image = image;
		self.selectionCheck.frame = self.lastSelectionCheckFrame;
		[self bringSubviewToFront:self.selectionCheck];
	}
}

- (void)dayPlateTapped {
	[self.delegate bubbleCell:self didTapPart:TGBubbleCellPartDayPlate atRow:self.appliedRow];
}

@end

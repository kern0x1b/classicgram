#import "TGStarsListBadgeSubtitleCell.h"
#import "TGTheme.h"
#import "TGHexColour.h"

static const CGFloat kBadgeSubtitleTextLeft = 15.0f;
static const CGFloat kBadgeSubtitleTitleTop = 6.0f;
static const CGFloat kBadgeSubtitleTitleHeight = 20.0f;
static const CGFloat kBadgeSubtitleRowTop = 28.0f;
static const CGFloat kBadgeSubtitleRowHeight = 16.0f;
static const CGFloat kBadgeInsetH = 5.0f;
static const CGFloat kBadgeGap = 5.0f;
static const CGFloat kBadgeSubtitleRightMargin = 10.0f;

@interface TGStarsListBadgeSubtitleCell ()
@property (nonatomic, strong) UIView *badgeBackground;
@property (nonatomic, strong) UILabel *badgeLabel;
@property (nonatomic, strong) UILabel *rowDetailLabel;
@end

@implementation TGStarsListBadgeSubtitleCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.textLabel.font = [UIFont systemFontOfSize:16];

	self.badgeBackground = [[UIView alloc] init];
	self.badgeBackground.layer.cornerRadius = 5;
	self.badgeBackground.layer.masksToBounds = YES;
	[self.contentView addSubview:self.badgeBackground];

	self.badgeLabel = [[UILabel alloc] init];
	self.badgeLabel.backgroundColor = [UIColor clearColor];
	self.badgeLabel.font = [UIFont systemFontOfSize:13];
	self.badgeLabel.textAlignment = NSTextAlignmentCenter;
	self.badgeLabel.textColor = [UIColor whiteColor];
	[self.badgeBackground addSubview:self.badgeLabel];

	self.rowDetailLabel = [[UILabel alloc] init];
	self.rowDetailLabel.backgroundColor = [UIColor clearColor];
	self.rowDetailLabel.font = [UIFont systemFontOfSize:13];
	[self.contentView addSubview:self.rowDetailLabel];

	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.textLabel.text = nil;
	self.badgeLabel.text = nil;
	self.rowDetailLabel.text = nil;
	self.accessoryType = UITableViewCellAccessoryNone;
}

- (void)applyTitle:(NSString *)title
		 badgeText:(NSString *)badgeText
		detailText:(NSString *)detailText
	   destructive:(BOOL)destructive
		  tappable:(BOOL)tappable {
	[[TGTheme shared] styleCell:self];

	self.textLabel.text = title;
	self.textLabel.font = [UIFont systemFontOfSize:16];
	self.textLabel.textColor = destructive
		? [[TGTheme shared] groupedDestructiveColour]
		: [[TGTheme shared] primaryTextColour];

	self.badgeLabel.text = badgeText;
	self.badgeBackground.backgroundColor = [[TGTheme shared] groupedActionColour];

	self.rowDetailLabel.text = detailText;
	self.rowDetailLabel.textColor = TGColourFromHex(0x888888);

	self.selectionStyle = tappable
		? UITableViewCellSelectionStyleBlue
		: UITableViewCellSelectionStyleNone;

	[self setNeedsLayout];
}

- (void)layoutSubviews {
	[super layoutSubviews];

	CGFloat width = self.contentView.bounds.size.width;

	self.textLabel.frame = CGRectMake(kBadgeSubtitleTextLeft, kBadgeSubtitleTitleTop,
		MAX(0, width - kBadgeSubtitleTextLeft - kBadgeSubtitleRightMargin), kBadgeSubtitleTitleHeight);

	CGSize badgeTextSize = [self.badgeLabel.text sizeWithFont:self.badgeLabel.font];
	CGFloat badgeWidth = badgeTextSize.width + kBadgeInsetH * 2;
	self.badgeBackground.frame = CGRectMake(kBadgeSubtitleTextLeft, kBadgeSubtitleRowTop,
		badgeWidth, kBadgeSubtitleRowHeight);
	self.badgeLabel.frame = self.badgeBackground.bounds;

	CGFloat detailX = kBadgeSubtitleTextLeft + badgeWidth + kBadgeGap;
	self.rowDetailLabel.frame = CGRectMake(detailX, kBadgeSubtitleRowTop,
		MAX(0, width - detailX - kBadgeSubtitleRightMargin), kBadgeSubtitleRowHeight);
}

@end

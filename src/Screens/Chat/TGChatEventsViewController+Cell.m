#import "TGChatEventsViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGClient.h"
#import "TGClient+ChatManagement.h"
#import "TGClient+Messages.h"
#import "TGChatViewController.h"
#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGDateUtils.h"
#import "UIView+SafeTint.h"

static const CGFloat kEventsTextOrigin = 49.0f;
static const CGFloat kEventsRightInset = 10.0f;

@implementation TGChatEventCell

+ (UIFont *)bodyFont {
	return [UIFont systemFontOfSize:14];
}

+ (CGFloat)heightForText:(NSString *)text width:(CGFloat)width {
	CGFloat textWidth = width - kEventsTextOrigin - kEventsRightInset;
	if (textWidth < 40)
		textWidth = 40;
	CGSize size = [(text.length ? text : @" ") sizeWithFont:[self bodyFont]
										  constrainedToSize:CGSizeMake(textWidth, 1000)
											  lineBreakMode:NSLineBreakByWordWrapping];
	CGFloat height = 28 + size.height + 8;
	return height < kEventsMinRowHeight ? kEventsMinRowHeight : floorf(height);
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (self) {
		self.selectionStyle = UITableViewCellSelectionStyleNone;

		_avatarView = [[UIImageView alloc] initWithFrame:
				CGRectMake(5, 5, kEventsAvatarSide, kEventsAvatarSide)];
		[self.contentView addSubview:_avatarView];

		_nameLabel = [[TGEmojiLabel alloc] initWithFrame:CGRectZero];
		_nameLabel.backgroundColor = [UIColor clearColor];
		_nameLabel.font = [UIFont boldSystemFontOfSize:16];
		[self.contentView addSubview:_nameLabel];

		_dateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		_dateLabel.backgroundColor = [UIColor clearColor];
		_dateLabel.font = [UIFont systemFontOfSize:13];
		_dateLabel.textAlignment = NSTextAlignmentRight;
		[self.contentView addSubview:_dateLabel];

		_bodyLabel = [[TGEmojiLabel alloc] initWithFrame:CGRectZero];
		_bodyLabel.backgroundColor = [UIColor clearColor];
		_bodyLabel.font = [TGChatEventCell bodyFont];
		_bodyLabel.numberOfLines = 0;
		_bodyLabel.lineBreakMode = NSLineBreakByWordWrapping;
		[self.contentView addSubview:_bodyLabel];

		_hairline = [[UIView alloc] initWithFrame:CGRectZero];
		[self.contentView addSubview:_hairline];
	}
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];

	CGRect bounds = self.contentView.bounds;
	CGFloat width = bounds.size.width;

	self.avatarView.frame = CGRectMake(5, 5, kEventsAvatarSide, kEventsAvatarSide);

	CGSize dateSize = [self.dateLabel.text.length ? self.dateLabel.text : @" "
		sizeWithFont:self.dateLabel.font];
	CGFloat dateWidth = floorf(dateSize.width) + 2;
	self.dateLabel.frame = CGRectMake(width - dateWidth - 9, 7 + TGEventsRetinaPixel(),
		dateWidth, 15);

	CGFloat nameWidth = width - kEventsTextOrigin - dateWidth - 9 - 6;
	if (nameWidth < 20)
		nameWidth = 20;
	self.nameLabel.frame = CGRectMake(kEventsTextOrigin, 5, nameWidth, 20);

	CGFloat textWidth = width - kEventsTextOrigin - kEventsRightInset;
	if (textWidth < 40)
		textWidth = 40;
	CGSize bodySize = [self.bodyLabel.text.length ? self.bodyLabel.text : @" "
			 sizeWithFont:self.bodyLabel.font
		constrainedToSize:CGSizeMake(textWidth, 1000)
			lineBreakMode:NSLineBreakByWordWrapping];
	self.bodyLabel.frame = CGRectMake(kEventsTextOrigin, 26 + TGEventsRetinaPixel(),
		textWidth, floorf(bodySize.height));

	CGFloat thickness = 1.0f / [UIScreen mainScreen].scale;
	self.hairline.frame = CGRectMake(kEventsTextOrigin, bounds.size.height - thickness,
		width - kEventsTextOrigin, thickness);
}

@end

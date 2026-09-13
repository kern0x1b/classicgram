#import "TGAccountRowCell.h"
#import "TGAccountsItem.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGLocalization.h"

static const CGFloat kAccountRowCellAvatarSide = 38.0f;

static UIColor *TGAccountRowCellSubtitleColour(void) {
	return [[TGTheme shared] secondaryTextColour];
}

static UIView *TGAccountRowCellBadgeWithCount(NSInteger count) {
	if (count <= 0)
		return nil;
	NSString *text = count > 999 ? @"999+" : [NSString stringWithFormat:@"%ld", (long)count];
	UILabel *label = [[UILabel alloc] init];
	label.text = text;
	label.font = [UIFont boldSystemFontOfSize:13];
	label.textColor = [UIColor whiteColor];
	label.textAlignment = NSTextAlignmentCenter;
	label.backgroundColor = [UIColor colorWithWhite:0.6f alpha:1.0f];
	[label sizeToFit];
	CGFloat width = MAX(22.0f, label.bounds.size.width + 12);
	label.frame = CGRectMake(0, 0, width, 20);
	label.layer.cornerRadius = 10.0f;
	label.clipsToBounds = YES;
	return label;
}

@implementation TGAccountRowCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	return self;
}

- (void)applyItem:(TGAccountsItem *)item {
	[[TGTheme shared] styleCell:self];

	self.textLabel.text = item.titleText;
	self.textLabel.font = [UIFont boldSystemFontOfSize:17];
	self.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	self.textLabel.highlightedTextColor = [UIColor whiteColor];

	self.detailTextLabel.text = item.subtitleText;
	self.detailTextLabel.font = [UIFont systemFontOfSize:13];
	self.detailTextLabel.textColor = TGAccountRowCellSubtitleColour();
	self.detailTextLabel.highlightedTextColor = [UIColor whiteColor];

	UIImage *avatar = [TGIcons avatarWithInitials:item.initials
											 size:kAccountRowCellAvatarSide
										 colourId:item.userId];
	self.imageView.image = avatar;
	self.imageView.layer.cornerRadius = 6.0f;
	self.imageView.clipsToBounds = YES;

	if (item.current) {
		self.accessoryType = UITableViewCellAccessoryCheckmark;
		self.accessoryView = nil;
	} else {
		UIView *badge = TGAccountRowCellBadgeWithCount(item.unreadCount);
		badge.transform = TGLocalizedIsRTL() ? CGAffineTransformMakeScale(-1, 1) : CGAffineTransformIdentity;
		self.accessoryType = UITableViewCellAccessoryNone;
		self.accessoryView = badge;
	}
}

@end

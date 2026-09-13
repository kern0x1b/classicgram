#import "TGProfileDetailCell.h"
#import "TGProfileDetailItem.h"
#import "TGProfileDetailRowHeight.h"
#import "TGTheme.h"
#import "TGHexColour.h"

@implementation TGProfileDetailCell {
	UILabel *_labelView;
	UILabel *_valueView;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.selectionStyle = UITableViewCellSelectionStyleNone;

	_labelView = [[UILabel alloc] initWithFrame:CGRectMake(4, 13, 62, 16)];
	_labelView.textAlignment = NSTextAlignmentRight;
	_labelView.font = [UIFont boldSystemFontOfSize:13];
	_labelView.adjustsFontSizeToFitWidth = YES;
	_labelView.minimumFontSize = 10;
	_labelView.backgroundColor = [UIColor clearColor];
	[self.contentView addSubview:_labelView];

	_valueView = [[UILabel alloc] initWithFrame:
			CGRectMake(78, 11, self.contentView.bounds.size.width - 80, 20)];
	_valueView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_valueView.font = [UIFont boldSystemFontOfSize:15];
	_valueView.numberOfLines = 0;
	_valueView.lineBreakMode = NSLineBreakByWordWrapping;
	_valueView.backgroundColor = [UIColor clearColor];
	[self.contentView addSubview:_valueView];

	return self;
}

- (void)applyItem:(TGProfileDetailItem *)item {
	[[TGTheme shared] styleCell:self];

	self.selectionStyle = item.selectable
		? UITableViewCellSelectionStyleBlue
		: UITableViewCellSelectionStyleNone;
	self.accessoryType = item.showsDisclosure
		? UITableViewCellAccessoryDisclosureIndicator
		: UITableViewCellAccessoryNone;
	self.userInteractionEnabled = item.interactionEnabled;

	_labelView.text = item.labelText;
	_labelView.textColor = TGColourFromHex(0x5d708f);
	_valueView.text = item.valueText;
	_valueView.textColor = item.valueTextColor;

	CGFloat contentWidth = self.contentView.bounds.size.width;
	_valueView.frame = CGRectMake(kTGProfileDetailValueLeft, 11,
		TGProfileDetailValueWidthForContentWidth(contentWidth),
		TGProfileDetailValueHeight(item.valueText, _valueView.font, contentWidth));
}

@end

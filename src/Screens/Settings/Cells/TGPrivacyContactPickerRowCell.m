#import "TGPrivacyContactPickerRowCell.h"
#import "TGPrivacyContactPickerItem.h"
#import "TGTheme.h"

@implementation TGPrivacyContactPickerRowCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.selectionStyle = UITableViewCellSelectionStyleBlue;

	return self;
}

- (void)applyItem:(TGPrivacyContactPickerItem *)item {
	[[TGTheme shared] styleCell:self];

	self.textLabel.text = item.titleText;
	self.textLabel.font = [UIFont boldSystemFontOfSize:17];
	self.textLabel.textColor = item.chosen
		? [[TGTheme shared] groupedInfoColour]
		: [[TGTheme shared] groupedTitleColour];
	self.accessoryType = item.chosen ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
}

@end

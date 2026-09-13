#import "TGAccountUsernameRowCell.h"
#import "TGAccountUsernamesItem.h"
#import "TGTheme.h"

@implementation TGAccountUsernameRowCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	return self;
}

- (void)applyItem:(TGAccountUsernamesItem *)item {
	[[TGTheme shared] styleCell:self];

	self.textLabel.font = [UIFont systemFontOfSize:17];
	self.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	self.textLabel.text = item.displayText;

	self.detailTextLabel.text = nil;
	self.accessoryView = nil;
	self.accessoryType = UITableViewCellAccessoryNone;
}

@end

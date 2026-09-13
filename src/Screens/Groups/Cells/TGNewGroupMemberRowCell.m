#import "TGNewGroupMemberRowCell.h"
#import "TGNewGroupMembersItem.h"
#import "TGTheme.h"

@implementation TGNewGroupMemberRowCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	return self;
}

- (void)applyItem:(TGNewGroupMembersItem *)item {
	self.textLabel.font = [UIFont systemFontOfSize:19];
	self.textLabel.text = item.titleText;
	self.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.accessoryType = item.selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
}

@end

#import "TGSupergroupUsernameRowCell.h"
#import "TGSupergroupUsernamesItem.h"
#import "TGTheme.h"

@implementation TGSupergroupUsernameRowCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	return self;
}

- (void)applyItem:(TGSupergroupUsernamesItem *)item {
	[[TGTheme shared] styleCell:self];

	self.textLabel.font = [UIFont systemFontOfSize:17];
	self.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	self.textLabel.text = item.displayText;

	if (item.badgeText.length) {
		self.detailTextLabel.text = nil;
		self.accessoryType = UITableViewCellAccessoryNone;
		UILabel *badge = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 90, 20)];
		badge.backgroundColor = [UIColor clearColor];
		badge.font = [UIFont systemFontOfSize:13];
		badge.textColor = [[TGTheme shared] secondaryTextColour];
		badge.textAlignment = NSTextAlignmentRight;
		badge.text = item.badgeText;
		self.accessoryView = badge;
	} else {
		self.accessoryView = nil;
		self.accessoryType = UITableViewCellAccessoryNone;
	}
}

@end

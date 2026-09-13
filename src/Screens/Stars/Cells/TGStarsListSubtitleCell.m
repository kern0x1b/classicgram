#import "TGStarsListSubtitleCell.h"
#import "TGStarsListItem.h"
#import "TGTheme.h"
#import "TGHexColour.h"

@implementation TGStarsListSubtitleCell

- (void)applyItem:(TGStarsListItem *)item {
	[super applyItem:item];
	[[TGTheme shared] styleCell:self];

	self.textLabel.text = item.titleText;
	self.textLabel.font = [UIFont systemFontOfSize:16];
	self.textLabel.textColor = item.destructive
		? [[TGTheme shared] groupedDestructiveColour]
		: [[TGTheme shared] primaryTextColour];

	self.detailTextLabel.text = item.detailText;
	self.detailTextLabel.font = [UIFont systemFontOfSize:13];
	self.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];

	self.accessoryType = UITableViewCellAccessoryNone;
	self.selectionStyle = item.tappable
		? UITableViewCellSelectionStyleBlue
		: UITableViewCellSelectionStyleNone;
}

@end

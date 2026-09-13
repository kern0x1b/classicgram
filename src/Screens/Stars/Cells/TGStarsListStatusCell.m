#import "TGStarsListStatusCell.h"
#import "TGStarsListItem.h"
#import "TGTheme.h"
#import "TGHexColour.h"

@implementation TGStarsListStatusCell

- (void)applyItem:(TGStarsListItem *)item {
	[super applyItem:item];
	[[TGTheme shared] styleCell:self];

	self.textLabel.textAlignment = item.statusIsMore ? NSTextAlignmentLeft : NSTextAlignmentCenter;
	self.textLabel.font = [UIFont boldSystemFontOfSize:item.statusIsMore ? 17 : 14];
	self.textLabel.text = item.titleText;

	if (item.statusIsLoading) {
		self.textLabel.textColor = [[TGTheme shared] secondaryTextColour];
		self.selectionStyle = UITableViewCellSelectionStyleNone;
	} else if (item.statusIsMore) {
		self.textLabel.textColor = [[TGTheme shared] groupedActionColour];
		self.selectionStyle = UITableViewCellSelectionStyleBlue;
	} else {
		self.textLabel.textColor = [[TGTheme shared] emptyStateColour];
		self.selectionStyle = UITableViewCellSelectionStyleNone;
	}
}

@end

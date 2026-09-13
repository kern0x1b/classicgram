#import "TGOwnedSetsCreateCell.h"
#import "TGOwnedSetsItem.h"
#import "TGTheme.h"

@implementation TGOwnedSetsCreateCell

- (void)applyItem:(TGOwnedSetsItem *)item {
	[super applyItem:item];

	self.textLabel.text = item.titleText;
	self.textLabel.textColor = [[TGTheme shared] groupedActionColour];
	self.textLabel.textAlignment = NSTextAlignmentCenter;
	self.accessoryType = UITableViewCellAccessoryNone;
}

@end

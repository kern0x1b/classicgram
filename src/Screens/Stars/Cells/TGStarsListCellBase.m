#import "TGStarsListCellBase.h"
#import "TGStarsListItem.h"

@implementation TGStarsListCellBase

- (void)applyItem:(TGStarsListItem *)item {
	self.textLabel.textAlignment = NSTextAlignmentLeft;
	self.accessoryView = nil;
	self.accessoryType = UITableViewCellAccessoryNone;
}

@end

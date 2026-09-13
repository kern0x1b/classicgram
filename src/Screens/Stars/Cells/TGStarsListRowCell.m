#import "TGStarsListRowCell.h"

@implementation TGStarsListRowCell

- (void)prepareForReuse {
	[super prepareForReuse];
	self.accessoryView = nil;
	self.accessoryType = UITableViewCellAccessoryNone;
	self.detailTextLabel.text = nil;
}

@end

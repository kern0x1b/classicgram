#import "TGOwnedSetsSetCell.h"
#import "TGOwnedSetsItem.h"

@implementation TGOwnedSetsSetCell

- (void)applyItem:(TGOwnedSetsItem *)item {
	[super applyItem:item];

	self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	self.textLabel.text = item.titleText;
	self.detailTextLabel.text = item.countText;
	self.imageView.image = item.thumbnailPlaceholder;
	self.imageView.contentMode = UIViewContentModeScaleAspectFit;
}

@end

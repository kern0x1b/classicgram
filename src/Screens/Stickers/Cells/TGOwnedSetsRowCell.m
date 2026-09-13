#import "TGOwnedSetsRowCell.h"

@implementation TGOwnedSetsRowCell

- (void)prepareForReuse {
	[super prepareForReuse];
	self.imageView.image = nil;
	self.detailTextLabel.text = nil;
}

@end

#import "TGStorageDownloadsRowCell.h"

@implementation TGStorageDownloadsRowCell

- (void)prepareForReuse {
	[super prepareForReuse];
	self.accessoryView = nil;
	self.accessoryType = UITableViewCellAccessoryNone;
	self.selectionStyle = UITableViewCellSelectionStyleNone;
	self.detailTextLabel.text = @"";
}

@end

#import "TGStoryViewerRowCell.h"
#import "TGStoryViewersItem.h"
#import "TGTheme.h"

@implementation TGStoryViewerRowCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.selectionStyle = UITableViewCellSelectionStyleBlue;

	return self;
}

- (void)applyItem:(TGStoryViewersItem *)item {
	self.textLabel.text = item.titleText;
	self.detailTextLabel.text = item.detailText;
	[[TGTheme shared] styleCell:self];
}

@end

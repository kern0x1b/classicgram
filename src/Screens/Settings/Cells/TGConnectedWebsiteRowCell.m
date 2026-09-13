#import "TGConnectedWebsiteRowCell.h"
#import "TGConnectedWebsitesItem.h"
#import "TGTheme.h"

@implementation TGConnectedWebsiteRowCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.selectionStyle = UITableViewCellSelectionStyleNone;

	return self;
}

- (void)applyItem:(TGConnectedWebsitesItem *)item {
	[[TGTheme shared] styleCell:self];

	self.textLabel.text = item.titleText;
	self.textLabel.font = [UIFont boldSystemFontOfSize:16];
	self.textLabel.textColor = [[TGTheme shared] groupedTitleColour];

	self.detailTextLabel.text = item.detailText;
	self.detailTextLabel.font = [UIFont systemFontOfSize:13];
	self.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	self.detailTextLabel.numberOfLines = 2;
}

@end

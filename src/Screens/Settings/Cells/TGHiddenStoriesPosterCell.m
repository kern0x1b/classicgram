#import "TGHiddenStoriesPosterCell.h"
#import "TGHiddenStoriesItem.h"
#import "TGTheme.h"

@implementation TGHiddenStoriesPosterCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.selectionStyle = UITableViewCellSelectionStyleNone;

	return self;
}

- (void)applyItem:(TGHiddenStoriesItem *)item {
	[[TGTheme shared] styleCell:self];

	self.textLabel.text = item.titleText;
	self.textLabel.font = [UIFont boldSystemFontOfSize:17];
	self.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
}

@end

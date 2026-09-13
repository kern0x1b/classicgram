#import "TGInstantViewRowCell.h"

@implementation TGInstantViewRowCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.selectionStyle = UITableViewCellSelectionStyleNone;
	self.backgroundColor = [UIColor whiteColor];

	return self;
}

@end

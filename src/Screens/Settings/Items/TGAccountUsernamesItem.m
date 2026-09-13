#import "TGAccountUsernamesItem.h"

@implementation TGAccountUsernamesItem

- (instancetype)initWithKind:(TGAccountUsernamesRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
					username:(NSString *)username
				 displayText:(NSString *)displayText
		  showsEditableBadge:(BOOL)showsEditableBadge {
	self = [super init];
	if (!self)
		return nil;

	_kind = kind;
	_reuseIdentifier = [reuseIdentifier copy];
	_cellClass = cellClass;
	_username = [username copy];
	_displayText = [displayText copy];
	_showsEditableBadge = showsEditableBadge;

	return self;
}

@end

#import "TGSupergroupUsernamesItem.h"

@implementation TGSupergroupUsernamesItem

- (instancetype)initWithKind:(TGSupergroupUsernamesRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
					username:(NSString *)username
				 displayText:(NSString *)displayText
				   badgeText:(NSString *)badgeText {
	self = [super init];
	if (!self)
		return nil;

	_kind = kind;
	_reuseIdentifier = [reuseIdentifier copy];
	_cellClass = cellClass;
	_username = [username copy];
	_displayText = [displayText copy];
	_badgeText = [badgeText copy];

	return self;
}

@end

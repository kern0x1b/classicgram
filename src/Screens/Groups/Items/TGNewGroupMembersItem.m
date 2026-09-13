#import "TGNewGroupMembersItem.h"

@implementation TGNewGroupMembersItem

- (instancetype)initWithKind:(TGNewGroupMembersRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
					  userId:(int64_t)userId
				   titleText:(NSString *)titleText
				  isSelected:(BOOL)isSelected {
	self = [super init];
	if (!self)
		return nil;

	_kind = kind;
	_reuseIdentifier = [reuseIdentifier copy];
	_cellClass = cellClass;
	_userId = userId;
	_titleText = [titleText copy];
	_selected = isSelected;

	return self;
}

@end

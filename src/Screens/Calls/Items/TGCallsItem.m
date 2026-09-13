#import "TGCallsItem.h"

@implementation TGCallsItem

- (instancetype)initWithKind:(TGCallsRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
					nameText:(NSString *)nameText
				  nameColour:(UIColor *)nameColour
				   countText:(NSString *)countText
					dateText:(NSString *)dateText
				subtitleText:(NSString *)subtitleText
				  arrowImage:(UIImage *)arrowImage
				   avatarKey:(NSNumber *)avatarKey
		   avatarPlaceholder:(UIImage *)avatarPlaceholder {
	self = [super init];
	if (!self)
		return nil;

	_kind = kind;
	_reuseIdentifier = [reuseIdentifier copy];
	_cellClass = cellClass;
	_nameText = [nameText copy];
	_nameColour = nameColour;
	_countText = [countText copy];
	_dateText = [dateText copy];
	_subtitleText = [subtitleText copy];
	_arrowImage = arrowImage;
	_avatarKey = [avatarKey copy];
	_avatarPlaceholder = avatarPlaceholder;

	return self;
}

@end

#import "TGPrivacyContactPickerItem.h"

@implementation TGPrivacyContactPickerItem

- (instancetype)initWithKind:(TGPrivacyContactPickerRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
					  userId:(int64_t)userId
				   titleText:(NSString *)titleText
					isChosen:(BOOL)isChosen {
	self = [super init];
	if (!self)
		return nil;

	_kind = kind;
	_reuseIdentifier = [reuseIdentifier copy];
	_cellClass = cellClass;
	_userId = userId;
	_titleText = [titleText copy];
	_chosen = isChosen;

	return self;
}

@end

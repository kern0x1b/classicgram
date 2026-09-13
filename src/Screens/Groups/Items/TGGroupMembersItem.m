#import "TGGroupMembersItem.h"

@implementation TGGroupMembersItem

- (instancetype)initWithKind:(TGGroupMembersRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
					  userId:(long long)userId
				   titleText:(NSString *)titleText
				subtitleText:(NSString *)subtitleText
			subtitleIsOnline:(BOOL)subtitleIsOnline
					roleText:(NSString *)roleText
		   avatarPlaceholder:(UIImage *)avatarPlaceholder {
	self = [super init];
	if (!self)
		return nil;

	_kind = kind;
	_reuseIdentifier = [reuseIdentifier copy];
	_cellClass = cellClass;
	_userId = userId;
	_titleText = [titleText copy];
	_subtitleText = [subtitleText copy];
	_subtitleIsOnline = subtitleIsOnline;
	_roleText = [roleText copy];
	_avatarPlaceholder = avatarPlaceholder;

	return self;
}

@end

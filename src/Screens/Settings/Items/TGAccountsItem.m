#import "TGAccountsItem.h"

@implementation TGAccountsItem

- (instancetype)initWithKind:(TGAccountsRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
						slot:(NSInteger)slot
					  userId:(int64_t)userId
				   titleText:(NSString *)titleText
				subtitleText:(NSString *)subtitleText
					initials:(NSString *)initials
				   isCurrent:(BOOL)isCurrent
				 unreadCount:(NSInteger)unreadCount {
	self = [super init];
	if (!self)
		return nil;

	_kind = kind;
	_reuseIdentifier = [reuseIdentifier copy];
	_cellClass = cellClass;
	_slot = slot;
	_userId = userId;
	_titleText = [titleText copy];
	_subtitleText = [subtitleText copy];
	_initials = [initials copy];
	_current = isCurrent;
	_unreadCount = unreadCount;

	return self;
}

@end

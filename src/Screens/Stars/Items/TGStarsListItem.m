#import "TGStarsListItem.h"

@implementation TGStarsListItem

- (instancetype)initWithKind:(TGStarsListRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
				   titleText:(NSString *)titleText
				  detailText:(NSString *)detailText
			   isDestructive:(BOOL)isDestructive
				  isTappable:(BOOL)isTappable
			 statusIsLoading:(BOOL)statusIsLoading
				statusIsMore:(BOOL)statusIsMore {
	self = [super init];
	if (!self)
		return nil;

	_kind = kind;
	_reuseIdentifier = [reuseIdentifier copy];
	_cellClass = cellClass;
	_titleText = [titleText copy];
	_detailText = [detailText copy];
	_destructive = isDestructive;
	_tappable = isTappable;
	_statusIsLoading = statusIsLoading;
	_statusIsMore = statusIsMore;
	return self;
}

@end

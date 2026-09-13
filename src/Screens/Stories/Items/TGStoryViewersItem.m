#import "TGStoryViewersItem.h"

@implementation TGStoryViewersItem

- (instancetype)initWithKind:(TGStoryViewersRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
				   titleText:(NSString *)titleText
				  detailText:(NSString *)detailText {
	self = [super init];
	if (!self)
		return nil;

	_kind = kind;
	_reuseIdentifier = [reuseIdentifier copy];
	_cellClass = cellClass;
	_titleText = [titleText copy];
	_detailText = [detailText copy];

	return self;
}

@end

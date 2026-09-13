#import "TGHiddenStoriesItem.h"

@implementation TGHiddenStoriesItem

- (instancetype)initWithKind:(TGHiddenStoriesRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
					posterId:(int64_t)posterId
				posterIsChat:(BOOL)posterIsChat
				   titleText:(NSString *)titleText {
	self = [super init];
	if (!self)
		return nil;

	_kind = kind;
	_reuseIdentifier = [reuseIdentifier copy];
	_cellClass = cellClass;
	_posterId = posterId;
	_posterIsChat = posterIsChat;
	_titleText = [titleText copy];

	return self;
}

@end

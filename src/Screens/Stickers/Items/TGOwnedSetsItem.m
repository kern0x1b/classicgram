#import "TGOwnedSetsItem.h"

@implementation TGOwnedSetsItem

- (instancetype)initWithKind:(TGOwnedSetsRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
				   titleText:(NSString *)titleText
				   countText:(NSString *)countText
				thumbnailKey:(NSString *)thumbnailKey
			 thumbnailFileId:(int64_t)thumbnailFileId
		thumbnailPlaceholder:(UIImage *)thumbnailPlaceholder {
	self = [super init];
	if (!self)
		return nil;

	_kind = kind;
	_reuseIdentifier = [reuseIdentifier copy];
	_cellClass = cellClass;
	_titleText = [titleText copy];
	_countText = [countText copy];
	_thumbnailKey = [thumbnailKey copy];
	_thumbnailFileId = thumbnailFileId;
	_thumbnailPlaceholder = thumbnailPlaceholder;
	return self;
}

@end

#import "TGSearchResultItem.h"

@implementation TGSearchResultItem

- (instancetype)initWithKind:(TGSearchRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
				  titleFirst:(NSString *)titleFirst
				 titleSecond:(NSString *)titleSecond
				  authorText:(NSString *)authorText
				subtitleText:(NSString *)subtitleText
					dateText:(NSString *)dateText
			  avatarColourId:(int64_t)avatarColourId
				 avatarTitle:(NSString *)avatarTitle
				avatarFileId:(NSNumber *)avatarFileId
		 avatarIsPrecomputed:(BOOL)avatarIsPrecomputed
		   avatarPrecomputed:(UIImage *)avatarPrecomputed {
	self = [super init];
	if (!self)
		return nil;

	_kind = kind;
	_reuseIdentifier = [reuseIdentifier copy];
	_cellClass = cellClass;
	_titleFirst = [titleFirst copy];
	_titleSecond = [titleSecond copy];
	_authorText = [authorText copy];
	_subtitleText = [subtitleText copy];
	_dateText = [dateText copy];
	_avatarColourId = avatarColourId;
	_avatarTitle = [avatarTitle copy];
	_avatarFileId = [avatarFileId copy];
	_avatarIsPrecomputed = avatarIsPrecomputed;
	_avatarPrecomputed = avatarPrecomputed;

	return self;
}

@end

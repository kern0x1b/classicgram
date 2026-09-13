#import "TGChatLayoutContext.h"

@implementation TGChatLayoutContext

- (instancetype)initWithTableWidth:(CGFloat)tableWidth
					  baseFontSize:(CGFloat)baseFontSize
					   screenScale:(CGFloat)screenScale
						   isGroup:(BOOL)isGroup
					  isWideLayout:(BOOL)isWideLayout
					   isSelecting:(BOOL)isSelecting
						generation:(uint32_t)generation {
	self = [super init];
	if (!self)
		return nil;

	_tableWidth = tableWidth;
	_baseFontSize = baseFontSize;
	_screenScale = screenScale;
	_group = isGroup;
	_wideLayout = isWideLayout;
	_selecting = isSelecting;
	_generation = generation;
	return self;
}

@end

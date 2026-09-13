#import "TGRichMessageContent.h"

@implementation TGRichMessageContent

- (instancetype)initWithRawBlocks:(NSArray *)rawBlocks
					   isFullView:(BOOL)isFullView
					isRightToLeft:(BOOL)isRightToLeft
						   kicker:(NSString *)kicker
							title:(NSString *)title
						 subtitle:(NSString *)subtitle
						  snippet:(NSString *)snippet
					  coverFileId:(int64_t)coverFileId
					   coverWidth:(NSInteger)coverWidth
					  coverHeight:(NSInteger)coverHeight {
	self = [super init];
	if (self != nil) {
		_rawBlocks = [rawBlocks copy];
		_fullView = isFullView;
		_rightToLeft = isRightToLeft;
		_kicker = [kicker copy];
		_title = [title copy];
		_subtitle = [subtitle copy];
		_snippet = [snippet copy];
		_coverFileId = coverFileId;
		_coverWidth = coverWidth;
		_coverHeight = coverHeight;
	}
	return self;
}

@end

#import "TGMessageLayout+Construction.h"

@implementation TGMessageLayout {
	NSData *_repeatedRowsData;
}

- (instancetype)initWithHeaderHeight:(CGFloat)headerHeight
					   messageHeight:(CGFloat)messageHeight
							   parts:(TGMessageLayoutParts)parts
								 row:(TGMessageRowFrames)row
							  bubble:(TGMessageBubbleFrames)bubble
				  bubbleCornerRadius:(CGFloat)bubbleCornerRadius
				   bubbleBorderWidth:(CGFloat)bubbleBorderWidth
						  isOutgoing:(BOOL)isOutgoing
					 sitsOnWallpaper:(BOOL)sitsOnWallpaper
						repeatedRows:(const TGMessageLayoutRepeatedRow *)repeatedRows
							   count:(NSUInteger)repeatedRowCount {
	self = [super init];
	if (!self)
		return nil;

	NSAssert(repeatedRowCount <= kMessageLayoutMaxRows,
		@"repeated row count %lu exceeds kMessageLayoutMaxRows",
		(unsigned long)repeatedRowCount);

	_headerHeight = headerHeight;
	_messageHeight = messageHeight;
	_height = headerHeight + messageHeight;
	_parts = parts;
	_row = row;
	_bubble = bubble;
	_bubbleCornerRadius = bubbleCornerRadius;
	_bubbleBorderWidth = bubbleBorderWidth;
	_outgoing = isOutgoing;
	_sitsOnWallpaper = sitsOnWallpaper;
	_repeatedRowCount = repeatedRowCount;
	_repeatedRowsData = repeatedRowCount
		? [NSData dataWithBytes:repeatedRows
						 length:repeatedRowCount * sizeof(TGMessageLayoutRepeatedRow)]
		: nil;
	return self;
}

- (TGMessageLayoutRepeatedRow)repeatedRowAtIndex:(NSUInteger)index {
	NSAssert(index < _repeatedRowCount, @"repeated row index %lu out of range %lu",
		(unsigned long)index, (unsigned long)_repeatedRowCount);
	const TGMessageLayoutRepeatedRow *rows = _repeatedRowsData.bytes;
	return rows[index];
}

@end

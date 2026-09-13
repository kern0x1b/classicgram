#import "TGMessageLayout.h"

@interface TGMessageLayout ()

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
							   count:(NSUInteger)repeatedRowCount NS_DESIGNATED_INITIALIZER;

@end

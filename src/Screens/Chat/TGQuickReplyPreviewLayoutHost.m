#import "TGQuickReplyPreviewLayoutHost.h"
#import "TGChatViewControllerInternal.h"
#import "TGBubbleCellDelegate.h"

@implementation TGQuickReplyPreviewLayoutHost

- (void)attachInteractionsToRowCell:(TGMessageRowCell *)__unused cell {
}

- (void)bubbleCell:(TGMessageRowCell *)__unused cell
		didTapPart:(TGBubbleCellPart)__unused part
			 atRow:(NSInteger)__unused row {
}

- (void)bubbleCell:(TGMessageRowCell *)__unused cell
	didTapPollOptionAtIndex:(NSUInteger)__unused index
					  atRow:(NSInteger)__unused row {
}

- (void)bubbleCell:(TGMessageRowCell *)__unused cell
	didTapChecklistTaskAtIndex:(NSUInteger)__unused index
						 atRow:(NSInteger)__unused row {
}

- (void)bubbleCell:(TGMessageRowCell *)__unused cell
	didLongPressChecklistTaskAtIndex:(NSUInteger)__unused index
							 atRow:(NSInteger)__unused row {
}

@end

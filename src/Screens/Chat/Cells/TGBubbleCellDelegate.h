#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@class TGMessageRowCell;

typedef NS_ENUM(NSInteger, TGBubbleCellPart) {
	TGBubbleCellPartBubble = 0,
	TGBubbleCellPartAvatar,
	TGBubbleCellPartSender,
	TGBubbleCellPartTail,
	TGBubbleCellPartForwardJump,
	TGBubbleCellPartQuote,
	TGBubbleCellPartLinkPreview,
	TGBubbleCellPartSignature,
	TGBubbleCellPartMediaBadge,
	TGBubbleCellPartFileStatus,
	TGBubbleCellPartRetryDisc,
	TGBubbleCellPartPlay,
	TGBubbleCellPartDayPlate,
	TGBubbleCellPartSelectionCheck,
	TGBubbleCellPartAlbumTile,
	TGBubbleCellPartPollOption,
	TGBubbleCellPartPollRetract,
	TGBubbleCellPartPollAdd,
	TGBubbleCellPartChecklistTask,
	TGBubbleCellPartChecklistAdd,
	TGBubbleCellPartCall,
	TGBubbleCellPartComments
};

@protocol TGBubbleCellDelegate <NSObject>

- (void)bubbleCell:(TGMessageRowCell *)cell didTapPart:(TGBubbleCellPart)part atRow:(NSInteger)row;

@optional

- (void)configureBitmapsForCell:(TGMessageRowCell *)cell atRow:(NSInteger)row;
- (void)attachInteractionsToRowCell:(TGMessageRowCell *)cell;
- (void)resetRowCellSwipeIfNeeded:(TGMessageRowCell *)cell;

- (NSString *)bubbleCell:(TGMessageRowCell *)cell unreadBandTextAtRow:(NSInteger)row;
- (void)bubbleCell:(TGMessageRowCell *)cell
	didTapReactionEmoji:(NSString *)emoji
				  atRow:(NSInteger)row;
- (void)bubbleCell:(TGMessageRowCell *)cell
	didTapAlbumTileAtIndex:(NSUInteger)index
					 atRow:(NSInteger)row;
- (void)bubbleCell:(TGMessageRowCell *)cell
	didTapPollOptionAtIndex:(NSUInteger)index
					  atRow:(NSInteger)row;
- (void)bubbleCell:(TGMessageRowCell *)cell
	didTapChecklistTaskAtIndex:(NSUInteger)index
						 atRow:(NSInteger)row;
- (void)bubbleCell:(TGMessageRowCell *)cell
	didLongPressChecklistTaskAtIndex:(NSUInteger)index
							 atRow:(NSInteger)row;

- (NSString *)bubbleCell:(TGMessageRowCell *)cell
	pollOptionTitleAtIndex:(NSUInteger)index
					 atRow:(NSInteger)row;
- (CGFloat)bubbleCell:(TGMessageRowCell *)cell
	pollOptionFractionAtIndex:(NSUInteger)index
						atRow:(NSInteger)row;
- (NSInteger)bubbleCell:(TGMessageRowCell *)cell
	pollOptionPercentValueAtIndex:(NSUInteger)index
							atRow:(NSInteger)row;
- (BOOL)bubbleCell:(TGMessageRowCell *)cell
	pollOptionIsChosenAtIndex:(NSUInteger)index
						atRow:(NSInteger)row;

- (NSString *)bubbleCell:(TGMessageRowCell *)cell
	checklistTaskTitleAtIndex:(NSUInteger)index
						atRow:(NSInteger)row;
- (BOOL)bubbleCell:(TGMessageRowCell *)cell
	checklistTaskIsCheckedAtIndex:(NSUInteger)index
							atRow:(NSInteger)row;
- (NSString *)bubbleCell:(TGMessageRowCell *)cell
	checklistTaskCompletedByAtIndex:(NSUInteger)index
							   atRow:(NSInteger)row;

@end

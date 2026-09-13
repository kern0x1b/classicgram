#import "TGBubbleCellBase.h"
#import "TGChecklistTaskRowView.h"

@interface TGChecklistBubbleCell : TGBubbleCellBase

@property (nonatomic, strong, readonly) TGEmojiLabel *body;
@property (nonatomic, strong, readonly) UIButton *addButton;

@property (nonatomic, assign) int64_t checklistMessageId;
@property (nonatomic, copy) NSArray *checklistTaskIds;

@property (nonatomic, readonly) NSUInteger taskCount;
- (TGChecklistTaskRowView *)taskAtIndex:(NSUInteger)index;

@end

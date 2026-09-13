#import "TGBubbleCellBase.h"
#import "TGPollOptionRowView.h"

@interface TGPollBubbleCell : TGBubbleCellBase

@property (nonatomic, strong, readonly) TGEmojiLabel *body;
@property (nonatomic, strong, readonly) UILabel *subtitle;
@property (nonatomic, strong, readonly) UIButton *retractButton;
@property (nonatomic, strong, readonly) UIButton *addButton;
@property (nonatomic, strong, readonly) TGEmojiLabel *explanationLabel;

@property (nonatomic, assign) int64_t pollMessageId;

@property (nonatomic, readonly) NSUInteger optionCount;
- (TGPollOptionRowView *)optionAtIndex:(NSUInteger)index;

@end

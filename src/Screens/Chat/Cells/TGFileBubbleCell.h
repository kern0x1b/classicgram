#import "TGBubbleCellBase.h"
#import "TGFileStatusView.h"

@interface TGFileBubbleCell : TGBubbleCellBase

@property (nonatomic, strong, readonly) UIImageView *picture;
@property (nonatomic, strong, readonly) TGFileStatusView *fileStatus;
@property (nonatomic, strong, readonly) TGEmojiLabel *body;
@property (nonatomic, strong, readonly) UILabel *subtitle;
@property (nonatomic, strong, readonly) TGEmojiLabel *caption;
@property (nonatomic, strong, readonly) UILabel *audioTime;
@property (nonatomic, strong, readonly) UIImageView *audioProgress;

@property (nonatomic, assign) int64_t audioMessageId;

@end

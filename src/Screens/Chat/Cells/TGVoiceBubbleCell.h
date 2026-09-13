#import "TGBubbleCellBase.h"
#import "TGFileStatusView.h"

@interface TGVoiceBubbleCell : TGBubbleCellBase

@property (nonatomic, strong, readonly) TGFileStatusView *disc;
@property (nonatomic, strong, readonly) UIImageView *wave;
@property (nonatomic, strong, readonly) UILabel *body;
@property (nonatomic, strong, readonly) TGEmojiLabel *subtitle;

@property (nonatomic, assign) int64_t voiceMessageId;
@property (nonatomic, strong) NSData *waveformData;

- (void)updateVoicePlaybackText:(NSString *)text;

@end

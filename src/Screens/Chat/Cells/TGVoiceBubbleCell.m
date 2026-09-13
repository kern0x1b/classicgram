#import "TGVoiceBubbleCell.h"
#import "TGMessageItem.h"
#import "TGMessageLayout.h"
#import "TGTheme.h"
#import "TGLocalization.h"

extern UIColor *TGMessageBodyColour(void);

@interface TGVoiceBubbleCell ()

@property (nonatomic, strong, readwrite) TGFileStatusView *disc;
@property (nonatomic, strong, readwrite) UIImageView *wave;
@property (nonatomic, strong, readwrite) UILabel *body;
@property (nonatomic, strong, readwrite) TGEmojiLabel *subtitle;

@end

@implementation TGVoiceBubbleCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.disc = [[TGFileStatusView alloc] init];
	self.disc.hidden = YES;
	[self.bubble addSubview:self.disc];

	self.wave = [[UIImageView alloc] init];
	[self.bubble addSubview:self.wave];

	self.body = [[UILabel alloc] init];
	self.body.font = [UIFont systemFontOfSize:12];
	self.body.textColor = [[TGTheme shared] secondaryTextColour];
	self.body.backgroundColor = [UIColor clearColor];
	[self.bubble addSubview:self.body];

	self.subtitle = [[TGEmojiLabel alloc] init];
	self.subtitle.numberOfLines = 0;
	self.subtitle.font = [UIFont systemFontOfSize:14];
	self.subtitle.textColor = TGMessageBodyColour();
	self.subtitle.backgroundColor = [UIColor clearColor];
	self.subtitle.hidden = YES;
	[self.bubble addSubview:self.subtitle];

	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.voiceMessageId = 0;
	self.waveformData = nil;
	self.subtitle.richLayout = nil;
}

- (void)applyItem:(TGMessageItem *)item layout:(TGMessageLayout *)layout {
	[super applyItem:item layout:layout];

	TGMessageLayoutParts parts = layout.parts;
	self.voiceMessageId = item.messageId;

	self.disc.hidden = !(parts & TGMessageLayoutPartMediaDisc);
	if (parts & TGMessageLayoutPartMediaDisc)
		self.disc.frame = layout.bubble.disc;

	self.wave.hidden = !(parts & TGMessageLayoutPartWaveform);
	if (parts & TGMessageLayoutPartWaveform)
		self.wave.frame = layout.bubble.waveform;

	self.body.hidden = !(parts & TGMessageLayoutPartBody);
	if (parts & TGMessageLayoutPartBody) {
		self.body.frame = layout.bubble.body;
		self.body.text = item.voiceDurationText;
	}

	self.subtitle.hidden = !(parts & TGMessageLayoutPartTranscript);
	if (parts & TGMessageLayoutPartTranscript) {
		self.subtitle.frame = layout.bubble.transcript;
		self.subtitle.text = item.transcriptText;
	}

	self.isAccessibilityElement = YES;
	self.accessibilityLabel = [self tg_accessibilityLabelWithParts:@[
		item.senderDisplayName ?: @"",
		TGL(@"VoiceOver.Chat.VoiceMessage", @"Voice message"),
		item.voiceDurationText ?: @"",
		item.transcriptText ?: @"",
		item.stampText ?: @"",
	]];
}

- (void)updateVoicePlaybackText:(NSString *)text {
	self.body.text = text;
}

@end

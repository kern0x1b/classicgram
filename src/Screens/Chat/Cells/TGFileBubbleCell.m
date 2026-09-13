#import "TGFileBubbleCell.h"
#import "TGMessageItem.h"
#import "TGMessageLayout.h"
#import "TGMessage.h"
#import "TGTheme.h"
#import "TGLocalization.h"

extern CGFloat TGMessageBaseFontSize(void);
extern UIColor *TGMessageBodyColour(void);

@interface TGFileBubbleCell ()

@property (nonatomic, strong, readwrite) UIImageView *picture;
@property (nonatomic, strong, readwrite) TGFileStatusView *fileStatus;
@property (nonatomic, strong, readwrite) TGEmojiLabel *body;
@property (nonatomic, strong, readwrite) UILabel *subtitle;
@property (nonatomic, strong, readwrite) TGEmojiLabel *caption;
@property (nonatomic, strong, readwrite) UILabel *audioTime;
@property (nonatomic, strong, readwrite) UIImageView *audioProgress;

@end

@implementation TGFileBubbleCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.picture = [[UIImageView alloc] init];
	self.picture.contentMode = UIViewContentModeScaleAspectFill;
	self.picture.clipsToBounds = YES;
	self.picture.hidden = YES;
	[self.bubble addSubview:self.picture];

	self.fileStatus = [[TGFileStatusView alloc] init];
	self.fileStatus.hidden = YES;
	[self.bubble addSubview:self.fileStatus];

	self.body = [[TGEmojiLabel alloc] init];
	self.body.numberOfLines = 1;
	self.body.font = [UIFont systemFontOfSize:15];
	self.body.backgroundColor = [UIColor clearColor];
	[self.bubble addSubview:self.body];

	self.subtitle = [[UILabel alloc] init];
	self.subtitle.font = [UIFont systemFontOfSize:13];
	self.subtitle.backgroundColor = [UIColor clearColor];
	[self.bubble addSubview:self.subtitle];

	self.caption = [[TGEmojiLabel alloc] init];
	self.caption.numberOfLines = 0;
	self.caption.lineBreakMode = NSLineBreakByWordWrapping;
	self.caption.backgroundColor = [UIColor clearColor];
	self.caption.hidden = YES;
	[self.bubble addSubview:self.caption];

	self.audioTime = [[UILabel alloc] init];
	self.audioTime.font = [UIFont systemFontOfSize:13];
	self.audioTime.textAlignment = NSTextAlignmentRight;
	self.audioTime.backgroundColor = [UIColor clearColor];
	self.audioTime.hidden = YES;
	[self.bubble addSubview:self.audioTime];

	self.audioProgress = [[UIImageView alloc] init];
	self.audioProgress.hidden = YES;
	[self.bubble addSubview:self.audioProgress];

	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.picture.image = nil;
	self.picture.backgroundColor = [UIColor clearColor];
	self.body.richLayout = nil;
	self.caption.richLayout = nil;
	self.audioMessageId = 0;
	self.audioProgress.image = nil;
}

- (TGEmojiLabel *)tg_richTextLabel {
	return self.caption;
}

- (void)applyItem:(TGMessageItem *)item layout:(TGMessageLayout *)layout {
	[super applyItem:item layout:layout];

	TGMessageLayoutParts parts = layout.parts;
	self.audioMessageId = item.messageId;
	BOOL isContact = item.message.kind == TGMessageContentKindContact;

	self.picture.hidden = !(parts & TGMessageLayoutPartPicture);
	if (parts & TGMessageLayoutPartPicture)
		self.picture.frame = layout.bubble.picture;

	self.fileStatus.hidden = !(parts & TGMessageLayoutPartFileStatus);
	if (parts & TGMessageLayoutPartFileStatus)
		self.fileStatus.frame = layout.bubble.fileStatus;

	self.body.hidden = !(parts & TGMessageLayoutPartBody);
	if (parts & TGMessageLayoutPartBody) {
		self.body.frame = layout.bubble.body;
		self.body.text = item.fileTitleText;
		self.body.textColor = isContact ? [[TGTheme shared] primaryTextColour]
										: [[TGTheme shared] fileNameColour];
	}

	self.subtitle.hidden = !(parts & TGMessageLayoutPartSubtitle);
	if (parts & TGMessageLayoutPartSubtitle) {
		self.subtitle.frame = layout.bubble.subtitle;
		self.subtitle.text = item.fileMetaText;
		self.subtitle.textColor = [[TGTheme shared] fileMetaColour];
	}

	self.caption.hidden = !(parts & TGMessageLayoutPartTranscript);
	if (parts & TGMessageLayoutPartTranscript) {
		self.caption.frame = layout.bubble.transcript;
		self.caption.font = [UIFont systemFontOfSize:TGMessageBaseFontSize()];
		self.caption.textColor = TGMessageBodyColour();
		self.caption.text = item.fileCaptionText;
		self.caption.richLayout = item.bodyRichLayout;
	}

	self.audioTime.hidden = CGRectIsEmpty(layout.bubble.audioClock);
	if (!self.audioTime.hidden)
		self.audioTime.frame = layout.bubble.audioClock;

	self.audioProgress.hidden = YES;
	if (!CGRectIsEmpty(layout.bubble.waveform))
		self.audioProgress.frame = layout.bubble.waveform;

	NSString *kindNoun = isContact
		? TGL(@"Attachment.Contact", @"Contact")
		: (item.message.kind == TGMessageContentKindAudio
				  ? TGL(@"Attachment.Audio", @"Audio")
				  : TGL(@"Attachment.File", @"File"));

	self.isAccessibilityElement = YES;
	self.accessibilityLabel = [self tg_accessibilityLabelWithParts:@[
		item.senderDisplayName ?: @"",
		kindNoun,
		item.fileTitleText ?: @"",
		item.fileMetaText ?: @"",
		item.fileCaptionText ?: @"",
		item.stampText ?: @"",
	]];
}

@end

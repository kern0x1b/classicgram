#import "TGPhotoBubbleCell.h"
#import "TGMessageItem.h"
#import "TGMessageLayout.h"
#import "TGTheme.h"
#import "TGMessage.h"

extern UIColor *TGMessageBodyColour(void);
extern CGFloat TGMessageBaseFontSize(void);

@interface TGPhotoBubbleCell ()

@property (nonatomic, strong, readwrite) UIImageView *picture;
@property (nonatomic, strong, readwrite) UIImageView *disc;
@property (nonatomic, strong, readwrite) TGFileStatusView *fileStatus;
@property (nonatomic, strong, readwrite) UILabel *mediaBadge;
@property (nonatomic, strong, readwrite) TGEmojiLabel *body;

@end

@implementation TGPhotoBubbleCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.picture = [[UIImageView alloc] init];
	self.picture.contentMode = UIViewContentModeScaleAspectFill;
	self.picture.clipsToBounds = YES;
	[self.bubble addSubview:self.picture];

	self.disc = [[UIImageView alloc] init];
	self.disc.hidden = YES;
	[self.bubble addSubview:self.disc];

	self.fileStatus = [[TGFileStatusView alloc] init];
	self.fileStatus.hidden = YES;
	[self.bubble addSubview:self.fileStatus];

	self.mediaBadge = [[UILabel alloc] init];
	self.mediaBadge.font = [UIFont boldSystemFontOfSize:11];
	self.mediaBadge.textColor = [UIColor whiteColor];
	self.mediaBadge.textAlignment = NSTextAlignmentCenter;
	self.mediaBadge.backgroundColor = [[TGTheme shared] mediaStampColour];
	self.mediaBadge.layer.cornerRadius = 8;
	self.mediaBadge.hidden = YES;
	self.mediaBadge.clipsToBounds = YES;
	[self.bubble addSubview:self.mediaBadge];

	self.body = [[TGEmojiLabel alloc] init];
	self.body.numberOfLines = 0;
	self.body.lineBreakMode = NSLineBreakByWordWrapping;
	self.body.backgroundColor = [UIColor clearColor];
	self.body.hidden = YES;
	[self.bubble addSubview:self.body];

	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.picture.image = nil;
	self.disc.image = nil;
	self.mediaBadge.text = nil;
	self.body.richLayout = nil;
}

- (TGEmojiLabel *)tg_richTextLabel {
	return self.body;
}

- (void)applyItem:(TGMessageItem *)item layout:(TGMessageLayout *)layout {
	[super applyItem:item layout:layout];

	TGMessageLayoutParts parts = layout.parts;

	self.picture.hidden = !(parts & TGMessageLayoutPartPicture);
	if (parts & TGMessageLayoutPartPicture) {
		self.picture.frame = layout.bubble.picture;
		self.picture.layer.cornerRadius = [[TGTheme shared] mediaCornerRadius];
	}

	self.disc.hidden = !(parts & TGMessageLayoutPartRetryDisc);
	if (parts & TGMessageLayoutPartRetryDisc)
		self.disc.frame = layout.bubble.disc;

	self.fileStatus.hidden = !(parts & TGMessageLayoutPartFileStatus);
	if (parts & TGMessageLayoutPartFileStatus)
		self.fileStatus.frame = layout.bubble.fileStatus;

	self.mediaBadge.hidden = !(parts & TGMessageLayoutPartMediaBadge);
	if (parts & TGMessageLayoutPartMediaBadge) {
		self.mediaBadge.frame = layout.bubble.mediaBadge;
		self.mediaBadge.text = item.mediaBadgeText;
	}

	self.body.hidden = !(parts & TGMessageLayoutPartBody);
	if (parts & TGMessageLayoutPartBody) {
		self.body.frame = layout.bubble.body;
		self.body.font = [UIFont systemFontOfSize:TGMessageBaseFontSize()];
		self.body.textColor = TGMessageBodyColour();
		self.body.text = item.bodyText;
		self.body.richLayout = item.bodyRichLayout;
	}
}

@end

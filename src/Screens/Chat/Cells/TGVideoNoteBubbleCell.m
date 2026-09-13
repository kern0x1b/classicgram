#import "TGVideoNoteBubbleCell.h"
#import "TGMessageItem.h"
#import "TGMessageLayout.h"

extern CGFloat TGRoundNoteRimWidth(void);
extern UIColor *TGRoundNoteRimColour(void);

@interface TGVideoNoteBubbleCell ()

@property (nonatomic, strong, readwrite) UIImageView *picture;
@property (nonatomic, strong, readwrite) UIImageView *rim;
@property (nonatomic, strong, readwrite) UILabel *badge;

@end

@implementation TGVideoNoteBubbleCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.rim = [[UIImageView alloc] init];
	self.rim.backgroundColor = [UIColor whiteColor];
	self.rim.clipsToBounds = YES;
	[self.bubble addSubview:self.rim];

	self.picture = [[UIImageView alloc] init];
	self.picture.contentMode = UIViewContentModeScaleAspectFill;
	self.picture.clipsToBounds = YES;
	[self.bubble addSubview:self.picture];

	self.badge = [[UILabel alloc] init];
	self.badge.font = [UIFont systemFontOfSize:11];
	self.badge.textColor = [UIColor whiteColor];
	self.badge.backgroundColor = [UIColor clearColor];
	[self.bubble addSubview:self.badge];

	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.picture.image = nil;
}

- (void)applyItem:(TGMessageItem *)item layout:(TGMessageLayout *)layout {
	[super applyItem:item layout:layout];

	TGMessageLayoutParts parts = layout.parts;
	self.picture.frame = layout.bubble.picture;
	self.picture.layer.cornerRadius = layout.bubble.picture.size.width / 2;

	self.rim.hidden = !(parts & TGMessageLayoutPartRoundRim);
	if (parts & TGMessageLayoutPartRoundRim) {
		self.rim.frame = layout.bubble.roundRim;
		self.rim.layer.cornerRadius = layout.bubble.roundRim.size.width / 2;
		self.rim.layer.borderWidth = TGRoundNoteRimWidth();
		self.rim.layer.borderColor = TGRoundNoteRimColour().CGColor;
	}

	self.badge.hidden = !(parts & TGMessageLayoutPartRoundBadge);
	if (parts & TGMessageLayoutPartRoundBadge) {
		self.badge.frame = layout.bubble.roundBadge;
		self.badge.text = item.roundNoteDurationText;
	}
}

@end

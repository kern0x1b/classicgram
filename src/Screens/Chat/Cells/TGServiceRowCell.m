#import "TGServiceRowCell.h"
#import "TGMessageItem.h"
#import "TGMessageLayout.h"
#import "TGTheme.h"

extern UIColor *TGSystemPlateColour(void);

@interface TGServiceRowCell ()

@property (nonatomic, strong, readwrite) UIView *plate;
@property (nonatomic, strong, readwrite) TGEmojiLabel *body;
@property (nonatomic, strong, readwrite) UIImageView *picture;

@end

@implementation TGServiceRowCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.plate = [[UIView alloc] init];
	self.plate.backgroundColor = TGSystemPlateColour();
	self.plate.clipsToBounds = NO;
	[self.contentView addSubview:self.plate];

	self.body = [[TGEmojiLabel alloc] init];
	self.body.numberOfLines = 0;
	self.body.lineBreakMode = NSLineBreakByWordWrapping;
	self.body.textAlignment = NSTextAlignmentCenter;
	self.body.backgroundColor = [UIColor clearColor];
	self.body.font = [UIFont boldSystemFontOfSize:13];
	self.body.textColor = [[TGTheme shared] serviceTextColour];
	[self.plate addSubview:self.body];

	self.picture = [[UIImageView alloc] init];
	self.picture.contentMode = UIViewContentModeScaleAspectFill;
	self.picture.clipsToBounds = YES;
	self.picture.hidden = YES;
	[self.plate addSubview:self.picture];

	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.body.richLayout = nil;
	self.picture.image = nil;
}

- (void)applyItem:(TGMessageItem *)item layout:(TGMessageLayout *)layout {
	[super applyItem:item layout:layout];

	self.plate.frame = layout.row.bubble;
	self.plate.layer.cornerRadius = layout.bubbleCornerRadius;

	self.body.text = item.serviceLineText;
	self.body.frame = layout.bubble.body;

	BOOL showsPicture = (layout.parts & TGMessageLayoutPartPicture) != 0;
	self.picture.hidden = !showsPicture;
	if (showsPicture) {
		self.picture.frame = layout.bubble.picture;
		self.picture.layer.cornerRadius = layout.bubble.picture.size.width / 2;
	}
}

@end

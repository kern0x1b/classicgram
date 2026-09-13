#import "TGMapBubbleCell.h"
#import "TGMessageItem.h"
#import "TGMessageLayout.h"
#import "TGTheme.h"
#import "TGMessage.h"
#import "TGVenueContent.h"
#import "TGLiveLocationContent.h"
#import "TGLocalization.h"

extern UIColor *TGMessageBodyColour(void);
extern CGFloat TGMessageBaseFontSize(void);

@interface TGMapBubbleCell ()

@property (nonatomic, strong, readwrite) UIImageView *picture;
@property (nonatomic, strong, readwrite) TGEmojiLabel *body;
@property (nonatomic, strong) UIView *headingConeStorage;

@end

@implementation TGMapBubbleCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.picture = [[UIImageView alloc] init];
	self.picture.contentMode = UIViewContentModeScaleAspectFill;
	self.picture.clipsToBounds = YES;
	[self.bubble addSubview:self.picture];

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

	self.body.hidden = !(parts & TGMessageLayoutPartBody);
	if (parts & TGMessageLayoutPartBody) {
		self.body.frame = layout.bubble.body;
		self.body.font = [UIFont systemFontOfSize:TGMessageBaseFontSize()];
		self.body.textColor = TGMessageBodyColour();
		self.body.text = item.bodyText;
		self.body.richLayout = item.bodyRichLayout;
	}

	NSString *locationDescription;
	if ([item.message.content isKindOfClass:[TGVenueContent class]]) {
		NSString *venueTitle = ((TGVenueContent *)item.message.content).title;
		locationDescription = venueTitle.length
			? [NSString stringWithFormat:@"%@, %@", TGL(@"Attachment.Location", @"Location"), venueTitle]
			: TGL(@"Attachment.Location", @"Location");
	} else if ([item.message.content isKindOfClass:[TGLiveLocationContent class]]) {
		locationDescription = TGL(@"Message.LiveLocation", @"Live location");
	} else {
		locationDescription = TGL(@"Attachment.Location", @"Location");
	}

	self.isAccessibilityElement = YES;
	self.accessibilityLabel = [self tg_accessibilityLabelWithParts:@[
		item.senderDisplayName ?: @"",
		locationDescription,
		item.stampText ?: @"",
	]];

	NSInteger heading = 0;
	if ([item.message.content isKindOfClass:[TGLiveLocationContent class]])
		heading = ((TGLiveLocationContent *)item.message.content).heading;
	if (heading != 0 && (parts & TGMessageLayoutPartPicture)) {
		self.headingCone.hidden = NO;
		CGRect picture = layout.bubble.picture;
		CGFloat side = 20.0f;
		self.headingCone.center = CGPointMake(CGRectGetMidX(picture), CGRectGetMidY(picture));
		self.headingCone.bounds = CGRectMake(0, 0, side, side);
		self.headingCone.transform = CGAffineTransformMakeRotation((CGFloat)heading * (CGFloat)M_PI / 180.0f);
	} else if (self.headingConeStorage) {
		self.headingConeStorage.hidden = YES;
	}
}

- (UIView *)headingCone {
	if (!self.headingConeStorage) {
		self.headingConeStorage = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 20, 20)];
		self.headingConeStorage.backgroundColor = [UIColor clearColor];
		self.headingConeStorage.userInteractionEnabled = NO;
		self.headingConeStorage.hidden = YES;

		CAShapeLayer *cone = [CAShapeLayer layer];
		UIBezierPath *path = [UIBezierPath bezierPath];
		[path moveToPoint:CGPointMake(10, 0)];
		[path addLineToPoint:CGPointMake(17, 20)];
		[path addLineToPoint:CGPointMake(10, 15)];
		[path addLineToPoint:CGPointMake(3, 20)];
		[path closePath];
		cone.path = path.CGPath;
		cone.fillColor = [[UIColor colorWithRed:0.16f green:0.5f blue:0.98f alpha:0.9f] CGColor];
		cone.strokeColor = [[UIColor whiteColor] CGColor];
		cone.lineWidth = 1.0f;
		[self.headingConeStorage.layer addSublayer:cone];

		[self.bubble addSubview:self.headingConeStorage];
	}
	return self.headingConeStorage;
}

@end

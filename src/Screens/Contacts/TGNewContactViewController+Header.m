#import "TGNewContactViewController.h"
#import "TGNewContactViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import <QuartzCore/QuartzCore.h>

@implementation TGNewContactViewController (Header)

- (CGFloat)headerWidth {
	CGFloat width = self.tableView.bounds.size.width;
	if (width < 1)
		width = self.view.bounds.size.width;
	if (width < 1)
		width = [UIScreen mainScreen].bounds.size.width;
	return width;
}

- (CGFloat)headerHeight {
	return kNewContactHeaderTop + kNewContactNameRow * 2 + kNewContactHeaderBottom;
}

- (void)buildTableHeader {
	CGFloat width = [self headerWidth];
	BOOL showsPhoto = !self.editingExistingContact && ![self hasKnownPeer];
	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, [self headerHeight])];
	header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	header.backgroundColor = [UIColor clearColor];
	header.clipsToBounds = NO;

	self.addPhotoButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.addPhotoButton.frame = CGRectMake(TGNewContactGroupedInset(width), kNewContactHeaderTop,
		kNewContactAvatarSide, kNewContactAvatarSide);
	self.addPhotoButton.exclusiveTouch = YES;
	UIImage *placeholder = TGNewContactStretchedImage(@"ProfilePhotoPlaceholder.png");
	UIImage *placeholderPressed = TGNewContactStretchedImage(@"ProfilePhotoPlaceholder_Highlighted.png");
	if (placeholder) {
		[self.addPhotoButton setBackgroundImage:placeholder forState:UIControlStateNormal];
		if (placeholderPressed)
			[self.addPhotoButton setBackgroundImage:placeholderPressed forState:UIControlStateHighlighted];
	} else {
		[self.addPhotoButton setBackgroundImage:[self drawnPlaceholderOfSide:70 colour:TGNewContactColour(0x9aa7b6, 1.0f)]
									   forState:UIControlStateNormal];
		[self.addPhotoButton setBackgroundImage:[self drawnPlaceholderOfSide:70 colour:TGNewContactColour(0x7f8d9d, 1.0f)]
									   forState:UIControlStateHighlighted];
	}
	[self.addPhotoButton addTarget:self action:@selector(addPhotoPressed) forControlEvents:UIControlEventTouchUpInside];
	[header addSubview:self.addPhotoButton];

	CGFloat retinaPixel = ([UIScreen mainScreen].scale > 1.0f) ? 0.5f : 0.0f;
	UILabel *addLabel = [[UILabel alloc] init];
	addLabel.text = TGL(@"NewContact.PhotoAdd", @"add");
	addLabel.font = [UIFont boldSystemFontOfSize:14 + retinaPixel];
	addLabel.backgroundColor = [UIColor clearColor];
	addLabel.textColor = [UIColor whiteColor];
	addLabel.shadowColor = TGNewContactColour(0x47586c, 0.5f);
	addLabel.shadowOffset = CGSizeMake(0, -1);
	[addLabel sizeToFit];
	addLabel.frame = CGRectIntegral(CGRectMake((kNewContactAvatarSide - addLabel.frame.size.width) / 2,
		16 + retinaPixel,
		addLabel.frame.size.width, addLabel.frame.size.height));
	[self.addPhotoButton addSubview:addLabel];

	UILabel *photoLabel = [[UILabel alloc] init];
	photoLabel.text = TGL(@"NewContact.PhotoPhoto", @"photo");
	photoLabel.font = [UIFont boldSystemFontOfSize:14 + retinaPixel];
	photoLabel.backgroundColor = [UIColor clearColor];
	photoLabel.textColor = [UIColor whiteColor];
	photoLabel.shadowColor = TGNewContactColour(0x47586c, 0.5f);
	photoLabel.shadowOffset = CGSizeMake(0, -1);
	[photoLabel sizeToFit];
	photoLabel.frame = CGRectIntegral(CGRectMake((kNewContactAvatarSide - photoLabel.frame.size.width) / 2, 33,
		photoLabel.frame.size.width, photoLabel.frame.size.height));
	[self.addPhotoButton addSubview:photoLabel];

	self.avatarView = [[UIImageView alloc] initWithFrame:self.addPhotoButton.frame];
	self.avatarView.contentMode = UIViewContentModeScaleAspectFill;
	self.avatarView.clipsToBounds = YES;
	self.avatarView.layer.cornerRadius = 4.0f;
	self.avatarView.hidden = YES;
	self.avatarView.userInteractionEnabled = NO;
	[header addSubview:self.avatarView];

	self.addPhotoButton.hidden = !showsPhoto;
	self.editNameContainer = [[UIView alloc] initWithFrame:CGRectZero];
	self.editNameContainer.backgroundColor = [UIColor clearColor];

	self.firstNameBackground = [self groupedNameBackgroundOfWidth:width top:YES];
	self.firstNameBackground.userInteractionEnabled = YES;
	UITapGestureRecognizer *firstNameTap = [UITapGestureRecognizer alloc];
	firstNameTap = [firstNameTap initWithTarget:self action:@selector(focusOnFirstNameField)];
	[self.firstNameBackground addGestureRecognizer:firstNameTap];
	[self.editNameContainer addSubview:self.firstNameBackground];

	self.lastNameBackground = [self groupedNameBackgroundOfWidth:width top:NO];
	self.lastNameBackground.userInteractionEnabled = YES;
	UITapGestureRecognizer *lastNameTap = [UITapGestureRecognizer alloc];
	lastNameTap = [lastNameTap initWithTarget:self action:@selector(focusOnLastNameField)];
	[self.lastNameBackground addGestureRecognizer:lastNameTap];
	[self.editNameContainer addSubview:self.lastNameBackground];

	[self.editNameContainer addSubview:self.firstNameField];
	[self.editNameContainer addSubview:self.lastNameField];

	[header addSubview:self.editNameContainer];
	self.tableView.tableHeaderView = header;
	self.headerLaidOutForWidth = 0.0f;
	[self layoutTableHeader];
}

- (void)layoutTableHeader {
	UIView *header = self.tableView.tableHeaderView;
	if (!header)
		return;
	CGFloat width = [self headerWidth];
	if (width < 1)
		return;
	if (fabsf(width - self.headerLaidOutForWidth) < 0.5f)
		return;
	self.headerLaidOutForWidth = width;

	CGFloat inset = TGNewContactGroupedInset(width);
	header.frame = CGRectMake(0, 0, width, [self headerHeight]);

	CGRect avatar = CGRectMake(inset, kNewContactHeaderTop,
		kNewContactAvatarSide, kNewContactAvatarSide);
	self.addPhotoButton.frame = avatar;
	self.avatarView.frame = avatar;

	CGFloat nameLeft = self.addPhotoButton.hidden
		? inset
		: CGRectGetMaxX(avatar) + kNewContactAvatarGap;
	CGFloat nameWidth = MAX(1.0f, width - nameLeft - inset);
	self.editNameContainer.frame = CGRectMake(nameLeft, kNewContactHeaderTop,
		nameWidth, kNewContactNameRow * 2);
	self.firstNameBackground.frame = CGRectMake(0, 0, nameWidth, kNewContactNameRow);
	self.lastNameBackground.frame = CGRectMake(0, kNewContactNameRow, nameWidth, kNewContactNameRow);

	CGFloat fieldWidth = MAX(1.0f, nameWidth - 30.0f);
	self.firstNameField.frame = CGRectMake(15, 12, fieldWidth, 22);
	self.lastNameField.frame = CGRectMake(15, kNewContactNameRow + 11, fieldWidth, 22);
}

- (UIImage *)drawnPlaceholderOfSide:(CGFloat)side colour:(UIColor *)colour {
	CGSize size = CGSizeMake(side, side);
	UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
	UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, side, side) cornerRadius:4.0f];
	[colour setFill];
	[path fill];
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

- (UIView *)groupedNameBackgroundOfWidth:(CGFloat)width top:(BOOL)top {
	UIImage *art = [UIImage imageNamed:top ? @"GroupedCellTop.png" : @"GroupedCellBottom.png"];
	if (art) {
		UIImage *stretched = [art stretchableImageWithLeftCapWidth:(int)(art.size.width / 2) topCapHeight:0];
		UIImageView *view = [[UIImageView alloc] initWithImage:stretched];
		return view;
	}
	UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 44)];
	view.backgroundColor = [UIColor whiteColor];
	UIView *hairline = [[UIView alloc] initWithFrame:CGRectMake(0, top ? 43 : 0, width, 1)];
	hairline.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	hairline.backgroundColor = [[TGTheme shared] separatorColour];
	[view addSubview:hairline];
	return view;
}

@end

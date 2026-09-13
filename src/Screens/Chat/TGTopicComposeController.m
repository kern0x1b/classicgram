#import "TGTextFieldStyle.h"
#import "TGTopicComposeController.h"
#import "TGTopicsViewControllerInternal.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import <QuartzCore/QuartzCore.h>

static UIImage *TGTopicSwatchImage(NSInteger rgb, BOOL selected, CGFloat size) {
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGFloat inset = 3.0f;
	CGRect circle = CGRectMake(inset, inset, size - inset * 2, size - inset * 2);

	CGContextSetRGBFillColor(ctx,
		((rgb >> 16) & 0xff) / 255.0f,
		((rgb >> 8) & 0xff) / 255.0f,
		(rgb & 0xff) / 255.0f, 1.0f);
	CGContextFillEllipseInRect(ctx, circle);

	if (selected) {
		CGContextSetLineWidth(ctx, 2.0f);
		CGContextSetRGBStrokeColor(ctx, 0.20f, 0.48f, 0.80f, 1.0f);
		CGContextStrokeEllipseInRect(ctx, CGRectInset(circle, -2.0f, -2.0f));
	}

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

@implementation TGTopicComposeController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"CreateTopic.CreateTitle", @"New Topic");
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];

	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	CGFloat width = self.view.bounds.size.width;
	[self buildNameFieldWithWidth:width];
	[self buildColourSectionWithWidth:width];

	UIButton *create = [TGIcons headerButtonWithTitle:TGL(@"Common.Create", @"Create") bold:YES
											   target:self
											   action:@selector(createPressed)];
	self.createButton = create;
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:create];
}

- (void)buildNameFieldWithWidth:(CGFloat)width {
	UIView *plate = [[UIView alloc] initWithFrame:CGRectMake(0, 12, width, 44)];
	plate.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	plate.backgroundColor = [UIColor whiteColor];
	[self.view addSubview:plate];

	self.nameField = [[UITextField alloc] initWithFrame:CGRectMake(12, 0, width - 24, 44)];
	self.nameField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.nameField.font = TGTextFieldFont();
	self.nameField.textColor = [[TGTheme shared] primaryTextColour];
	self.nameField.placeholder = TGL(@"CreateTopic.EnterTopicTitle", @"Name the topic.");
	self.nameField.delegate = self;
	self.nameField.returnKeyType = UIReturnKeyDone;
	self.nameField.autocorrectionType = UITextAutocorrectionTypeNo;
	self.nameField.clearButtonMode = UITextFieldViewModeWhileEditing;
	TGStyleTextField(self.nameField);
	[plate addSubview:self.nameField];
}

- (void)buildColourSectionWithWidth:(CGFloat)width {
	self.swatches = [NSMutableArray array];
	CGFloat swatchSize = 40.0f;
	CGFloat spacing = 6.0f;
	NSInteger count = self.colours.count;
	CGFloat totalWidth = count * swatchSize + (count > 0 ? (count - 1) * spacing : 0);
	CGFloat startX = (width - totalWidth) / 2.0f;
	if (startX < 10)
		startX = 10;

	for (NSInteger i = 0; i < count; i++) {
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.frame = CGRectMake(startX + i * (swatchSize + spacing), 68, swatchSize, swatchSize);
		button.tag = (NSInteger)i;
		[button addTarget:self action:@selector(swatchPressed:)
			forControlEvents:UIControlEventTouchUpInside];
		[self.view addSubview:button];
		[self.swatches addObject:button];
	}
	[self refreshSwatches];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[self.nameField becomeFirstResponder];
}

- (void)refreshSwatches {
	for (UIButton *button in self.swatches) {
		NSInteger index = (NSUInteger)button.tag;
		if (index >= self.colours.count)
			continue;
		NSInteger rgb = [self.colours[index] integerValue];
		[button setImage:TGTopicSwatchImage(rgb, rgb == self.selectedColour, 40.0f)
				forState:UIControlStateNormal];
	}
}

- (void)swatchPressed:(UIButton *)button {
	NSInteger index = (NSUInteger)button.tag;
	if (index >= self.colours.count)
		return;
	self.selectedColour = [self.colours[index] integerValue];
	[self refreshSwatches];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
	return NO;
}

- (void)createPressed {
	if (self.created)
		return;
	NSString *name = [self.nameField.text
		stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (name.length == 0)
		return;
	self.created = YES;
	self.createButton.enabled = NO;
	[self.nameField resignFirstResponder];
	if (self.onCreate)
		self.onCreate(name, self.selectedColour);
}

@end

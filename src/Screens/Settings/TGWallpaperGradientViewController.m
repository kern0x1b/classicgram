#import "TGListBackground.h"
#import "TGActionSheet.h"
#import "TGWallpaperGradientViewController.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGSettingsService.h"
#import "TGSettingsViewController.h"
#import "TGSettingsViewControllerInternal.h"
#import "TGActionSheetIndexBuilder.h"
#import <QuartzCore/QuartzCore.h>
#import "TGHexColour.h"

static const NSInteger kWallpaperGradientTopSheetTag = 8301;
static const NSInteger kWallpaperGradientBottomSheetTag = 8302;

static UIImage *TGWallpaperGradientSwatch(NSInteger topColor, NSInteger bottomColor, CGSize size, CGFloat cornerRadius) {
	UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (!context) {
		UIGraphicsEndImageContext();
		return nil;
	}
	UIBezierPath *clip = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size.width, size.height)
													 cornerRadius:cornerRadius];
	[clip addClip];
	NSArray *colours = @[ (id)TGColourFromHex((unsigned int)topColor).CGColor,
		(id)TGColourFromHex((unsigned int)bottomColor).CGColor ];
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGGradientRef gradient = CGGradientCreateWithColors(space, (__bridge CFArrayRef)colours, NULL);
	if (gradient) {
		CGContextDrawLinearGradient(context, gradient, CGPointZero, CGPointMake(0, size.height), 0);
		CGGradientRelease(gradient);
	}
	CGColorSpaceRelease(space);
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

static UIImage *TGWallpaperGradientSwatchCircle(NSInteger colour, CGFloat diameter) {
	CGRect rect = CGRectMake(0, 0, diameter, diameter);
	UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0.0f);
	UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(rect, 1, 1)];
	[TGColourFromHex((unsigned int)colour) setFill];
	[path fill];
	path.lineWidth = 2.0f;
	[[UIColor colorWithWhite:1.0f alpha:0.85f] setStroke];
	[path stroke];
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

@interface TGWallpaperGradientViewController () <UIActionSheetDelegate>
@property (nonatomic, strong) UIView *previewView;
@property (nonatomic, strong) CAGradientLayer *previewGradientLayer;
@property (nonatomic, strong) UIButton *topSwatchButton;
@property (nonatomic, strong) UIButton *bottomSwatchButton;
@property (nonatomic, assign) BOOL applyingGradient;
@end

@implementation TGWallpaperGradientViewController

- (instancetype)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.title = TGL(@"Wallpaper.Gradient", @"Gradient");
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	self.tableView.rowHeight = 50;
	self.tableView.tableHeaderView = [self buildHeaderView];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if (self.navigationController.navigationBar)
		[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	self.previewGradientLayer.frame = self.previewView.bounds;
}

- (UIView *)buildHeaderView {
	CGFloat width = self.view.bounds.size.width ?: TGSettingsScreenWidth();
	CGFloat previewHeight = 160;
	CGFloat margin = 16;

	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, previewHeight + margin * 2)];
	header.backgroundColor = [[TGTheme shared] listBackgroundColour];
	header.autoresizingMask = UIViewAutoresizingFlexibleWidth;

	UIView *preview = [[UIView alloc] initWithFrame:CGRectMake(margin, margin, width - margin * 2, previewHeight)];
	preview.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	preview.clipsToBounds = YES;
	preview.layer.cornerRadius = [[TGTheme shared] mediaCornerRadius];
	self.previewView = preview;

	CAGradientLayer *gradientLayer = [CAGradientLayer layer];
	gradientLayer.frame = preview.bounds;
	[preview.layer addSublayer:gradientLayer];
	self.previewGradientLayer = gradientLayer;

	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
		initWithTarget:self action:@selector(previewTapped)];
	[preview addGestureRecognizer:tap];
	[header addSubview:preview];

	CGFloat swatchDiameter = 40;
	UIButton *topButton = [UIButton buttonWithType:UIButtonTypeCustom];
	topButton.frame = CGRectMake(CGRectGetMinX(preview.frame) + 12,
		CGRectGetMaxY(preview.frame) - swatchDiameter / 2, swatchDiameter, swatchDiameter);
	topButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
	[topButton addTarget:self action:@selector(topSwatchTapped:) forControlEvents:UIControlEventTouchUpInside];
	[header addSubview:topButton];
	self.topSwatchButton = topButton;

	UIButton *bottomButton = [UIButton buttonWithType:UIButtonTypeCustom];
	bottomButton.frame = CGRectMake(CGRectGetMaxX(preview.frame) - 12 - swatchDiameter,
		CGRectGetMaxY(preview.frame) - swatchDiameter / 2, swatchDiameter, swatchDiameter);
	bottomButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[bottomButton addTarget:self action:@selector(bottomSwatchTapped:) forControlEvents:UIControlEventTouchUpInside];
	[header addSubview:bottomButton];
	self.bottomSwatchButton = bottomButton;

	[self updatePreview];
	return header;
}

- (void)updatePreview {
	self.previewGradientLayer.frame = self.previewView.bounds;
	self.previewGradientLayer.colors = @[ (id)TGColourFromHex((unsigned int)self.topColor).CGColor,
		(id)TGColourFromHex((unsigned int)self.bottomColor).CGColor ];

	CGFloat radians = (CGFloat)((double)self.rotation * M_PI / 180.0);
	CGFloat dx = (CGFloat)sin(radians);
	CGFloat dy = (CGFloat)cos(radians);
	self.previewGradientLayer.startPoint = CGPointMake(0.5f - dx / 2.0f, 0.5f - dy / 2.0f);
	self.previewGradientLayer.endPoint = CGPointMake(0.5f + dx / 2.0f, 0.5f + dy / 2.0f);

	[self.topSwatchButton setImage:TGWallpaperGradientSwatchCircle(self.topColor, 40) forState:UIControlStateNormal];
	[self.bottomSwatchButton setImage:TGWallpaperGradientSwatchCircle(self.bottomColor, 40) forState:UIControlStateNormal];
}

- (void)previewTapped {
	if (self.applyingGradient)
		return;
	self.rotation = (self.rotation + 45) % 360;
	[self updatePreview];
	[self persist];
}

- (void)topSwatchTapped:(UIButton *)sender {
	[self presentColourSheetForTop:YES fromView:sender];
}

- (void)bottomSwatchTapped:(UIButton *)sender {
	[self presentColourSheetForTop:NO fromView:sender];
}

- (void)presentColourSheetForTop:(BOOL)isTop fromView:(UIView *)view {
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:TGL(@"Wallpaper.SetColor", @"Set a Color")
					  delegate:self
				   otherTitles:[TGSettingsViewController wallpaperColourNames]
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = isTop ? kWallpaperGradientTopSheetTag : kWallpaperGradientBottomSheetTag;
	[sheet tg_showFromRect:view.frame inView:view.superview];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex == actionSheet.cancelButtonIndex)
		return;
	if (actionSheet.tag != kWallpaperGradientTopSheetTag
		&& actionSheet.tag != kWallpaperGradientBottomSheetTag)
		return;
	if (self.applyingGradient)
		return;

	NSArray *values = [TGSettingsViewController wallpaperColourValues];
	if ((NSUInteger)buttonIndex >= values.count)
		return;
	NSInteger colour = [values[buttonIndex] integerValue];
	if (actionSheet.tag == kWallpaperGradientTopSheetTag)
		self.topColor = colour;
	else
		self.bottomColor = colour;

	[self updatePreview];
	[self.tableView reloadData];
	[self persist];
}

- (void)persist {
	self.applyingGradient = YES;
	__weak typeof(self) weakSelf = self;
	[TGSettingsService setDefaultBackgroundGradientTop:self.topColor
												 bottom:self.bottomColor
											   rotation:self.rotation
										   forDarkTheme:NO
											 completion:^(NSDictionary *background) {
												 __strong typeof(weakSelf) strongSelf = weakSelf;
												 if (!strongSelf)
													 return;
												 strongSelf.applyingGradient = NO;
												 if (![background isKindOfClass:[NSDictionary class]])
													 return;
												 if (strongSelf.onApplied)
													 strongSelf.onApplied(background);
											 }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)[TGSettingsViewController wallpaperGradientNames].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *reuse = @"TGWallpaperGradientPresetCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuse];
	[[TGTheme shared] styleCell:cell];

	NSArray *names = [TGSettingsViewController wallpaperGradientNames];
	NSArray *values = [TGSettingsViewController wallpaperGradientValues];
	if ((NSUInteger)indexPath.row >= names.count || (NSUInteger)indexPath.row >= values.count)
		return cell;

	cell.textLabel.text = names[indexPath.row];
	NSArray *pair = values[indexPath.row];
	NSInteger presetTop = [pair[0] integerValue];
	NSInteger presetBottom = [pair[1] integerValue];
	cell.imageView.image = TGWallpaperGradientSwatch(presetTop, presetBottom, CGSizeMake(30, 30), 6);
	cell.accessoryType = (presetTop == self.topColor && presetBottom == self.bottomColor)
		? UITableViewCellAccessoryCheckmark
		: UITableViewCellAccessoryNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (self.applyingGradient)
		return;
	NSArray *values = [TGSettingsViewController wallpaperGradientValues];
	if ((NSUInteger)indexPath.row >= values.count)
		return;

	NSArray *pair = values[indexPath.row];
	self.topColor = [pair[0] integerValue];
	self.bottomColor = [pair[1] integerValue];
	self.rotation = 45;
	[self updatePreview];
	[tableView reloadData];
	[self persist];
}

@end

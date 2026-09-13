#import "TGQRCodeViewController.h"
#import "TGLocalization.h"
#import "TGQRImage.h"
#import "TGTheme.h"
#import "TGResendCountdown.h"

@interface TGQRCodeViewController ()
@property (nonatomic, copy) NSString *link;
@property (nonatomic, copy) NSString *caption;
@property (nonatomic, assign) NSInteger expiresIn;
@property (nonatomic, copy) void (^refreshLink)(void (^completion)(NSString *link, NSInteger expiresIn));
@property (nonatomic, strong) TGResendCountdown *expiryCountdown;
@property (nonatomic, assign) BOOL refreshingLink;
@property (nonatomic, strong) TGQRCodeView *codeView;
@property (nonatomic, strong) UILabel *linkLabel;
@property (nonatomic, strong) UILabel *captionLabel;
@property (nonatomic, strong) UIButton *actionButton;
@end

@implementation TGQRCodeViewController

- (id)initWithLink:(NSString *)link caption:(NSString *)caption {
	return [self initWithLink:link caption:caption expiresIn:0 refreshLink:nil];
}

- (id)initWithLink:(NSString *)link
		   caption:(NSString *)caption
		 expiresIn:(NSInteger)expiresIn
	   refreshLink:(void (^)(void (^completion)(NSString *link, NSInteger expiresIn)))refreshLink {
	self = [super init];
	if (!self)
		return nil;
	_link = [link copy];
	_caption = [caption copy];
	_expiresIn = expiresIn;
	_refreshLink = [refreshLink copy];
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	TGTheme *theme = [TGTheme shared];
	[theme styleNavigationBar:self.navigationController.navigationBar];
	self.title = TGL(@"PeerInfo.QRCode.Title", @"QR Code");
	self.view.backgroundColor = [theme listBackgroundColour];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	self.codeView = [[TGQRCodeView alloc] initWithFrame:CGRectZero];
	self.codeView.text = self.link;
	[self.view addSubview:self.codeView];

	self.captionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.captionLabel.text = self.caption;
	self.captionLabel.numberOfLines = 0;
	self.captionLabel.textAlignment = NSTextAlignmentCenter;
	self.captionLabel.font = [UIFont systemFontOfSize:14];
	self.captionLabel.textColor = [theme secondaryTextColour];
	self.captionLabel.backgroundColor = [UIColor clearColor];
	[self.view addSubview:self.captionLabel];

	self.linkLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.linkLabel.text = self.link;
	self.linkLabel.numberOfLines = 0;
	self.linkLabel.lineBreakMode = NSLineBreakByCharWrapping;
	self.linkLabel.textAlignment = NSTextAlignmentCenter;
	self.linkLabel.font = [UIFont boldSystemFontOfSize:15];
	self.linkLabel.textColor = [theme primaryTextColour];
	self.linkLabel.backgroundColor = [UIColor clearColor];
	[self.view addSubview:self.linkLabel];

	UIImage *rawPlate = [UIImage imageNamed:@"GroupedActionButton.png"];
	UIImage *rawPressed = [UIImage imageNamed:@"GroupedActionButton_Highlighted.png"];
	UIImage *plate = [rawPlate
		stretchableImageWithLeftCapWidth:(int)(rawPlate.size.width / 2)
							topCapHeight:(int)(rawPlate.size.height / 2)];
	UIImage *platePressed = [rawPressed
		stretchableImageWithLeftCapWidth:(int)(rawPressed.size.width / 2)
							topCapHeight:(int)(rawPressed.size.height / 2)];
	self.actionButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.actionButton.exclusiveTouch = YES;
	self.actionButton.adjustsImageWhenHighlighted = NO;
	self.actionButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
	[self.actionButton setBackgroundImage:plate forState:UIControlStateNormal];
	[self.actionButton setBackgroundImage:(platePressed ?: plate)
								 forState:UIControlStateHighlighted];
	[self.actionButton setTitle:TGL(@"GroupInfo.InviteLink.CopyLink", @"Copy Link") forState:UIControlStateNormal];

	UIColor *slate = [UIColor colorWithRed:0x4a / 255.0f green:0x65 / 255.0f
									  blue:0x87 / 255.0f
									 alpha:1.0f];
	[self.actionButton setTitleColor:slate forState:UIControlStateNormal];
	[self.actionButton setTitleColor:slate forState:UIControlStateHighlighted];
	[self.actionButton setTitleShadowColor:[UIColor colorWithWhite:1.0f alpha:0.45f]
								  forState:UIControlStateNormal];
	self.actionButton.titleLabel.shadowOffset = CGSizeMake(0, 1);
	[self.actionButton addTarget:self action:@selector(copyLink)
				forControlEvents:UIControlEventTouchUpInside];
	self.actionButton.hidden = !self.link.length;
	[self.view addSubview:self.actionButton];

	[self startExpiryCountdownIfNeeded];
}

- (void)startExpiryCountdownIfNeeded {
	if (self.expiresIn <= 0 || !self.refreshLink)
		return;
	__weak typeof(self) weakSelf = self;
	TGResendCountdown *countdown = [[TGResendCountdown alloc] init];
	countdown.onFinished = ^{
		[weakSelf refreshExpiredLink];
	};
	[countdown startWithSeconds:self.expiresIn];
	self.expiryCountdown = countdown;
}

- (void)refreshExpiredLink {
	if (self.refreshingLink || !self.refreshLink)
		return;
	self.refreshingLink = YES;
	__weak typeof(self) weakSelf = self;
	self.refreshLink(^(NSString *newLink, NSInteger newExpiresIn) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.refreshingLink = NO;
		if (!newLink.length)
			return;
		strongSelf.link = newLink;
		strongSelf.expiresIn = newExpiresIn;
		strongSelf.codeView.text = newLink;
		strongSelf.linkLabel.text = newLink;
		[strongSelf.view setNeedsLayout];
		if (newExpiresIn > 0) {
			TGResendCountdown *countdown = strongSelf.expiryCountdown;
			[countdown startWithSeconds:newExpiresIn];
		}
	});
}

- (void)viewWillLayoutSubviews {
	[super viewWillLayoutSubviews];
	[self layoutContent];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self layoutContent];
}

- (void)layoutContent {
	CGRect bounds = self.view.bounds;
	CGFloat width = bounds.size.width;
	CGFloat inset = 20;
	CGFloat side = MIN(width - inset * 2, bounds.size.height * 0.52f);

	if (side < 80)
		side = 80;

	CGSize captionSize = [self.captionLabel.text
			 sizeWithFont:self.captionLabel.font
		constrainedToSize:CGSizeMake(width - inset * 2, 200)
			lineBreakMode:NSLineBreakByWordWrapping];
	CGSize linkSize = [self.linkLabel.text
			 sizeWithFont:self.linkLabel.font
		constrainedToSize:CGSizeMake(width - inset * 2, 200)
			lineBreakMode:NSLineBreakByCharWrapping];

	CGFloat buttonHeight = 43;
	CGFloat total = captionSize.height + 16 + side + 14 + linkSize.height + 18 + buttonHeight;
	CGFloat top = (int)MAX(16.0f, (bounds.size.height - total) / 2);

	self.captionLabel.frame = CGRectMake(inset, top, width - inset * 2,
		captionSize.height);
	top += captionSize.height + 16;
	self.codeView.frame = CGRectMake((int)((width - side) / 2), (int)top,
		(int)side, (int)side);
	top += side + 14;
	self.linkLabel.frame = CGRectMake(inset, (int)top, width - inset * 2,
		linkSize.height);
	top += linkSize.height + 18;
	self.actionButton.frame = CGRectMake((int)((width - 148) / 2), (int)top,
		148, buttonHeight);
}

- (void)copyLink {
	if (!self.link.length)
		return;
	[UIPasteboard generalPasteboard].string = self.link;
	[self.actionButton setTitle:TGL(@"PeerInfo.QRCode.CopiedTitle", @"Copied") forState:UIControlStateNormal];
	[self performSelector:@selector(restoreCopyTitle) withObject:nil afterDelay:1.2];
}

- (void)restoreCopyTitle {
	[self.actionButton setTitle:TGL(@"GroupInfo.InviteLink.CopyLink", @"Copy Link") forState:UIControlStateNormal];
}

- (void)dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[self.expiryCountdown stop];
}

@end

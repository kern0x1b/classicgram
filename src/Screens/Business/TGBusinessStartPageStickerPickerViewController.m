#import "TGBusinessStartPageStickerPickerViewController.h"
#import "TGLocalization.h"
#import "TGStickerPanelView.h"
#import "TGSnackbar.h"
#import "TGTheme.h"

@interface TGBusinessStartPageStickerPickerViewController ()

@property (nonatomic, strong) TGStickerPanelView *panel;

@end

@implementation TGBusinessStartPageStickerPickerViewController

- (instancetype)init {
	self = [super init];
	if (self) {
		self.title = TGL(@"Message.Sticker", @"Sticker");
		self.hidesBottomBarWhenPushed = YES;
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];

	self.panel = [[TGStickerPanelView alloc] initWithFrame:self.view.bounds];
	self.panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.panel.suppressesRecentStickerTracking = YES;
	[self.view addSubview:self.panel];

	__weak typeof(self) weakSelf = self;
	self.panel.onStickerPicked = ^(NSDictionary *sticker) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if ([sticker[@"customEmojiId"] longLongValue] != 0) {
			[TGSnackbar showInView:strongSelf.navigationController.view
							  text:TGL(@"Business.Intro.StickerMustNotBeEmoji", @"Custom emoji can't be used here. Choose a sticker instead.")
						   seconds:2
						  onCommit:nil];
			return;
		}
		void (^picked)(NSDictionary *) = strongSelf.onPicked;
		if (picked)
			picked(sticker);
		[strongSelf.navigationController popViewControllerAnimated:YES];
	};
	self.panel.onCloseRequested = ^{
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf.navigationController popViewControllerAnimated:YES];
	};
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

@end

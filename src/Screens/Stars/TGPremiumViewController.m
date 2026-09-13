#import "TGListBackground.h"
#import "TGPremiumViewController.h"
#import "TGDateUtils.h"
#import "TGPremiumViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGIcons.h"

NSString *TGPremiumDateText(id value) {
	if (![value isKindOfClass:[NSNumber class]] || [value doubleValue] <= 0)
		return @"";
	return [TGDateUtils stringForFullDate:(int)[value doubleValue]];
}

@implementation TGPremiumViewController

- (id)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	self.title = TGL(@"Settings.Premium", @"Telegram Premium");
	self.limits = @[];
	self.features = @[];
	self.slots = @[];
	self.trialRemaining = -1;

	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	self.tableView.sectionFooterHeight = 1;
	if (self.navigationController.navigationBar)
		[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];

	UIButton *reload = [TGIcons headerButtonWithTitle:TGL(@"WebBrowser.Reload", @"Reload") bold:NO
											   target:self
											   action:@selector(reloadTapped)];
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:reload];

	[self buildHeader];
	[self load];
}

- (void)reloadTapped {
	self.subscriptionLoaded = NO;
	self.optionsLoaded = NO;
	self.slotsLoaded = NO;
	[self.tableView reloadData];
	[self load];
}

- (void)dealloc {
	if (self.trialObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.trialObserverToken];
}

@end

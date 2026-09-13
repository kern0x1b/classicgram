#import "TGMediaViewController.h"
#import "TGMediaViewControllerInternal.h"

#import "TGProgressIndicatorView.h"
#import "TGTheme.h"
#import "TGViewRecycler.h"
#import "TGLocalization.h"

#pragma mark - shared media

@implementation TGMediaViewController

- (instancetype)initWithChatId:(int64_t)chatId {
	self = [super init];
	if (self) {
		_chatId = chatId;
	}
	return self;
}

- (UIColor *)backgroundColourForScope:(NSInteger)scope {
	return TGMediaScopeIsGrid(scope)
		? [UIColor whiteColor]
		: [[TGTheme shared] listBackgroundColour];
}

- (void)buildMediaTableView {
	self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds
											  style:UITableViewStylePlain];
	self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	self.tableView.backgroundColor = [self backgroundColourForScope:self.scope];
	self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 4, 0);
	self.tableView.scrollIndicatorInsets = UIEdgeInsetsZero;
	self.tableView.rowHeight = kMediaRowHeight;
	self.tableView.dataSource = self;
	self.tableView.delegate = self;
	[self.view addSubview:self.tableView];

	UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(handleRowLongPress:)];
	longPress.minimumPressDuration = 0.5;
	[self.tableView addGestureRecognizer:longPress];
}

- (void)buildSpinnerAndEmptyView {
	self.spinner = [[TGProgressIndicatorView alloc]
		initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	self.spinner.center = CGPointMake(self.view.bounds.size.width / 2,
		self.view.bounds.size.height / 2 - 40);
	self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
	self.spinner.hidesWhenStopped = YES;
	[self.view addSubview:self.spinner];

	UIImage *blank = [UIImage imageNamed:@"PhotosBlankPlaceholder.png"];
	self.emptyImageView = [[UIImageView alloc] initWithImage:blank];

	self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.emptyLabel.backgroundColor = [UIColor clearColor];
	self.emptyLabel.textAlignment = NSTextAlignmentCenter;
	self.emptyLabel.font = [UIFont boldSystemFontOfSize:17];
	self.emptyLabel.textColor = [UIColor colorWithRed:0x80 / 255.0f green:0x88 / 255.0f
											 blue:0x95 / 255.0f
											alpha:1.0f];
	self.emptyLabel.text = TGMediaEmptyTextForScope(self.scope);
	[self.emptyLabel sizeToFit];

	self.emptyView = [[UIView alloc] initWithFrame:CGRectZero];
	self.emptyView.backgroundColor = [UIColor clearColor];
	self.emptyView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
	[self.emptyView addSubview:self.emptyImageView];
	[self.emptyView addSubview:self.emptyLabel];
	self.emptyImageView.hidden = !TGMediaScopeIsGrid(self.scope);
	self.emptyView.alpha = 0.0f;
	self.emptyView.userInteractionEnabled = NO;
	[self.view insertSubview:self.emptyView aboveSubview:self.tableView];
	[self layoutEmptyView];
}

- (void)buildDateIndicator {
	self.dateIndicator = [[UILabel alloc] initWithFrame:
			CGRectMake(self.view.bounds.size.width - 140, kMediaScopeHeight + 8, 128, 22)];
	self.dateIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	self.dateIndicator.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.6f];
	self.dateIndicator.textColor = [UIColor whiteColor];
	self.dateIndicator.font = [UIFont boldSystemFontOfSize:12];
	self.dateIndicator.textAlignment = NSTextAlignmentCenter;
	self.dateIndicator.layer.cornerRadius = 4.0f;
	self.dateIndicator.clipsToBounds = YES;
	self.dateIndicator.alpha = 0.0f;
	[self.view addSubview:self.dateIndicator];
}

- (void)layoutEmptyView {
	CGRect bounds = self.view.bounds;
	UIImage *blank = self.emptyImageView.hidden ? nil : self.emptyImageView.image;
	CGFloat imageHeight = blank ? blank.size.height : 0.0f;
	CGFloat imageWidth = blank ? blank.size.width : 0.0f;
	CGFloat gap = imageHeight > 0.0f ? 12.0f : 0.0f;
	CGFloat width = MAX(imageWidth, self.emptyLabel.frame.size.width);
	CGFloat height = imageHeight + gap + self.emptyLabel.frame.size.height;

	self.emptyView.frame = CGRectIntegral(CGRectMake((bounds.size.width - width) / 2.0f,
		(bounds.size.height - height) / 2.0f - 18.0f,
		width, height));
	self.emptyImageView.frame = CGRectIntegral(CGRectMake((width - imageWidth) / 2.0f, 0,
		imageWidth, imageHeight));
	self.emptyLabel.frame = CGRectIntegral(CGRectMake(
		(width - self.emptyLabel.frame.size.width) / 2.0f, imageHeight + gap,
		self.emptyLabel.frame.size.width, self.emptyLabel.frame.size.height));
}

- (void)setEmptyVisible:(BOOL)visible animated:(BOOL)animated {
	if (self.emptyVisible == visible)
		return;
	self.emptyVisible = visible;
	[self layoutEmptyView];

	BOOL keepTable = (self.query ?: @"").length > 0;
	void (^apply)(void) = ^{
		self.emptyView.alpha = visible ? 1.0f : 0.0f;
		self.tableView.alpha = (visible && !keepTable) ? 0.0f : 1.0f;
	};
	if (animated)
		[UIView animateWithDuration:0.2 animations:apply];
	else
		apply();
}

- (void)updateTitleForScope {
	NSArray *titles = TGMediaScopeTitles();
	self.title = (self.scope >= 0 && self.scope < (NSInteger)titles.count)
		? titles[self.scope]
		: TGL(@"PeerInfo.PaneMedia", @"Media");
}

- (void)viewDidLoad {
	[super viewDidLoad];

	self.scope = self.initialScope;
	[self updateTitleForScope];
	self.view.backgroundColor = [self backgroundColourForScope:self.scope];

	self.items = [[NSMutableArray alloc] init];
	self.recycler = [[TGViewRecycler alloc] init];
	self.extensionCache = [[NSMutableDictionary alloc] init];
	self.pendingDownloadFileIds = [[NSMutableSet alloc] init];
	self.canLoadMore = YES;
	self.itemsPerRow = [self itemsPerRowForWidth:self.view.bounds.size.width];

	[self buildMediaTableView];
	[self buildScopeBar];
	[self buildSearchBar];
	[self updateSearchBarVisibility];
	[self buildDownloadsBanner];
	[self buildSpinnerAndEmptyView];
	[self buildDateIndicator];

	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	[self loadNextPage];
	[self installMessageObserver];
	[self refreshDownloadsBanner];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	self.tableView.backgroundColor = [self backgroundColourForScope:self.scope];
	[self refreshDownloadsBanner];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];

	CGFloat top = self.bannerVisible ? kMediaBannerHeight : 0.0f;
	CGRect bounds = self.view.bounds;
	self.banner.frame = CGRectMake(0, 0, bounds.size.width, kMediaBannerHeight);
	self.scopeBar.frame = CGRectMake(0, top, bounds.size.width, kMediaScopeHeight);
	[self layoutScopeButtons];
	top += kMediaScopeHeight;
	self.tableView.frame = CGRectMake(0, top, bounds.size.width, bounds.size.height - top);
	[self layoutEmptyView];
	self.dateIndicator.frame = CGRectMake(bounds.size.width - 140, top + 8, 128, 22);

	NSInteger perRow = [self itemsPerRowForWidth:bounds.size.width];
	if (perRow != self.itemsPerRow) {
		self.itemsPerRow = perRow;
		[self.tableView reloadData];
	}
}

- (NSInteger)itemsPerRowForWidth:(CGFloat)width {
	NSInteger perRow = (NSInteger)(width / (kMediaTileSide + kMediaTileSpacing));
	return perRow < 1 ? 1 : perRow;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
	return orientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	[self.recycler removeAllViews];
}

- (void)dealloc {
	if (_messageObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_messageObserverToken];
	_tableView.delegate = nil;
	_tableView.dataSource = nil;
	[_recycler removeAllViews];
}

@end

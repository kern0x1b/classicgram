#import "TGListBackground.h"
#import "TGUpgradedGiftInfoViewController.h"
#import "TGGiftValueInfoViewController.h"
#import "TGLocalization.h"
#import "TGClient+UpgradedGifts.h"
#import "TGTheme.h"
#import "TGWebViewController.h"
#import "TGFlattenPayments.h"

static NSString *const kTGGiftValueRowKind = @"value";

@interface TGUpgradedGiftInfoViewController ()
@property (nonatomic, copy) NSString *giftName;
@property (nonatomic, copy) NSString *screenTitle;
@property (nonatomic, copy) NSArray *rows;
@property (nonatomic, copy) NSArray *valueRows;
@property (nonatomic, copy) NSString *fragmentUrl;
@property (nonatomic, assign) NSInteger pendingRequests;
@property (nonatomic, copy) NSDictionary *giftInfo;
@property (nonatomic, copy) NSDictionary *valueInfo;
@end

@implementation TGUpgradedGiftInfoViewController

- (instancetype)initWithGiftName:(NSString *)name title:(NSString *)title {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		_giftName = [name copy];
		_screenTitle = [title copy];
		_rows = @[];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = self.screenTitle.length ? self.screenTitle : TGL(@"Gift.View.Title", @"Gift");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.rowHeight = 44;
	[self load];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (NSString *)formattedAmount:(long long)amount currency:(NSString *)currency {
	if (!currency.length || amount <= 0)
		return nil;
	return [NSString stringWithFormat:@"%@ %@", TGPayDecimalAmount(amount, currency), currency];
}

- (NSString *)formattedDate:(long long)timestamp {
	if (timestamp <= 0)
		return nil;
	return [NSDateFormatter localizedStringFromDate:
			[NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)timestamp]
										  dateStyle:NSDateFormatterMediumStyle
										  timeStyle:NSDateFormatterNoStyle];
}

- (void)load {
	if (!self.giftName.length) {
		[self applyResults];
		return;
	}
	self.pendingRequests = 2;
	__weak typeof(self) weakSelf = self;

	[[TGClient shared] upgradedGiftInfoForName:self.giftName completion:^(NSDictionary *info) {
		TGUpgradedGiftInfoViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.giftInfo = info;
		if (--strongSelf.pendingRequests <= 0)
			[strongSelf applyResults];
	}];

	[[TGClient shared] upgradedGiftValueInfoForName:self.giftName completion:^(NSDictionary *value) {
		TGUpgradedGiftInfoViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.valueInfo = value;
		if (--strongSelf.pendingRequests <= 0)
			[strongSelf applyResults];
	}];
}

- (void)applyResults {
	NSMutableArray *rows = [NSMutableArray array];
	NSMutableArray *valueRows = [NSMutableArray array];
	self.fragmentUrl = nil;

	if (!self.giftInfo && !self.valueInfo) {
		self.rows = rows;
		self.valueRows = valueRows;
		[self.tableView reloadData];
		return;
	}

	NSString *modelName = self.giftInfo[@"modelName"];
	if (modelName.length)
		[rows addObject:@[ TGL(@"Gift.Unique.Model", @"Model"), modelName ]];

	NSString *symbolName = self.giftInfo[@"symbolName"];
	if (symbolName.length)
		[rows addObject:@[ TGL(@"Gift.Unique.Symbol", @"Symbol"), symbolName ]];

	NSString *backdropName = self.giftInfo[@"backdropName"];
	if (backdropName.length)
		[rows addObject:@[ TGL(@"Gift.Unique.Backdrop", @"Backdrop"), backdropName ]];

	long long number = [self.giftInfo[@"number"] longLongValue];
	long long total = [self.giftInfo[@"totalCount"] longLongValue];
	if (number > 0) {
		NSString *edition = total > 0
			? [NSString stringWithFormat:@"#%lld of %lld", number, total]
			: [NSString stringWithFormat:@"#%lld", number];
		[rows addObject:@[ TGL(@"Gift.Unique.Availability", @"Availability"), edition ]];
	}

	BOOL haveValueInfo = [self.valueInfo[@"currency"] length] > 0;
	NSString *currency = haveValueInfo ? self.valueInfo[@"currency"] : self.giftInfo[@"valueCurrency"];
	long long value = haveValueInfo
		? [self.valueInfo[@"value"] longLongValue]
		: [self.giftInfo[@"valueAmount"] longLongValue];
	NSString *marketValue = [self formattedAmount:value currency:currency];
	if (marketValue.length) {
		[rows addObject:@[
			[self.valueInfo[@"isAverage"] boolValue]
				? TGL(@"Gift.Estimated.Value", @"Estimated Value")
				: TGL(@"Gift.View.Value", @"Value"),
			marketValue,
			kTGGiftValueRowKind,
		]];
	}

	NSString *initialSaleDate = [self formattedDate:[self.valueInfo[@"initialSaleDate"] longLongValue]];
	if (initialSaleDate.length)
		[valueRows addObject:@[ TGL(@"Gift.Value.InitialSale", @"Initial Sale"), initialSaleDate ]];

	NSString *initialPrice = [self formattedAmount:[self.valueInfo[@"initialSalePrice"] longLongValue]
										  currency:self.valueInfo[@"currency"]];
	if (initialPrice.length)
		[valueRows addObject:@[ TGL(@"Gift.Value.InitialPrice", @"Initial Price"), initialPrice ]];

	NSString *lastSaleDate = [self formattedDate:[self.valueInfo[@"lastSaleDate"] longLongValue]];
	if (lastSaleDate.length)
		[valueRows addObject:@[ TGL(@"Gift.Value.LastSale", @"Last Sale"), lastSaleDate ]];

	NSString *lastSalePrice = [self formattedAmount:[self.valueInfo[@"lastSalePrice"] longLongValue]
										   currency:self.valueInfo[@"currency"]];
	if (lastSalePrice.length) {
		[valueRows addObject:@[ TGL(@"Gift.Value.LastPrice", @"Last Price"), lastSalePrice ]];
	}

	NSString *averagePrice = [self formattedAmount:[self.valueInfo[@"averageSalePrice"] longLongValue]
										  currency:self.valueInfo[@"currency"]];
	if (averagePrice.length)
		[valueRows addObject:@[ TGL(@"Gift.Value.AveragePrice", @"Average Sale (30d)"), averagePrice ]];

	NSInteger telegramListed = [self.valueInfo[@"telegramListedCount"] integerValue];
	NSInteger fragmentListed = [self.valueInfo[@"fragmentListedCount"] integerValue];
	if (telegramListed > 0 || fragmentListed > 0) {
		[valueRows addObject:@[ TGL(@"Gift.Options.Gift.Resale", @"On Resale"),
			[NSString stringWithFormat:@"%d", (int)(telegramListed + fragmentListed)] ]];
	}

	NSString *url = self.valueInfo[@"fragmentUrl"];
	if (url.length) {
		self.fragmentUrl = url;
		[valueRows addObject:@[ TGL(@"Gift.UnavailableAction.OpenFragment", @"View on Fragment"), @"",
			TGGiftValueInfoFragmentRowKind ]];
	}

	self.rows = rows;
	self.valueRows = valueRows;
	[self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:@"row"];
	[[TGTheme shared] styleCell:cell];

	NSArray *pair = (NSUInteger)indexPath.row < self.rows.count ? self.rows[(NSUInteger)indexPath.row] : nil;
	BOOL isValueRow = pair.count > 2 && [pair[2] isEqualToString:kTGGiftValueRowKind];

	cell.textLabel.text = pair.firstObject ?: @"";
	cell.detailTextLabel.text = pair.count > 1 ? pair[1] : @"";
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.detailTextLabel.textColor = [[TGTheme shared] groupedInfoColour];
	cell.selectionStyle = isValueRow ? UITableViewCellSelectionStyleDefault
									 : UITableViewCellSelectionStyleNone;
	cell.accessoryType = isValueRow && self.valueRows.count
		? UITableViewCellAccessoryDisclosureIndicator
		: UITableViewCellAccessoryNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSArray *pair = (NSUInteger)indexPath.row < self.rows.count ? self.rows[(NSUInteger)indexPath.row] : nil;
	BOOL isValueRow = pair.count > 2 && [pair[2] isEqualToString:kTGGiftValueRowKind];
	if (!isValueRow || !self.valueRows.count)
		return;
	TGGiftValueInfoViewController *info = [[TGGiftValueInfoViewController alloc]
		initWithRows:self.valueRows fragmentUrl:self.fragmentUrl];
	[self.navigationController pushViewController:info animated:YES];
}

@end

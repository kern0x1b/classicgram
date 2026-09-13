#import "TGIcons.h"
#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGCollectibleInfoViewController.h"
#import "TGLocalization.h"
#import "TGClient+Collectibles.h"
#import "TGTheme.h"
#import "TGWebViewController.h"
#import "TGFlattenPayments.h"

@interface TGCollectibleInfoViewController ()
@property (nonatomic, copy) NSDictionary *collectibleType;
@property (nonatomic, copy) NSString *screenTitle;
@property (nonatomic, copy) NSString *infoSentence;
@property (nonatomic, copy) NSString *fragmentUrl;
@property (nonatomic, assign) BOOL loaded;
@end

@implementation TGCollectibleInfoViewController

- (instancetype)initWithUsername:(NSString *)username {
	return [self initWithCollectibleType:@{@"username" : username ?: @""}
								   title:[@"@" stringByAppendingString:username ?: @""]];
}

- (instancetype)initWithCollectibleType:(NSDictionary *)type title:(NSString *)title {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		_collectibleType = [type copy];
		_screenTitle = [title copy];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = self.screenTitle;
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
	if (!currency.length)
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
	__weak typeof(self) weakSelf = self;
	void (^completion)(NSDictionary *) = ^(NSDictionary *info) {
		TGCollectibleInfoViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.loaded = YES;
		[strongSelf applyInfo:info];
	};

	NSString *username = self.collectibleType[@"username"];
	NSString *phone = self.collectibleType[@"phone_number"];
	if (username.length)
		[[TGClient shared] collectibleItemInfoForUsername:username completion:completion];
	else if (phone.length)
		[[TGClient shared] collectibleItemInfoForPhoneNumber:phone completion:completion];
	else
		completion(nil);
}

- (void)applyInfo:(NSDictionary *)info {
	self.fragmentUrl = nil;
	self.infoSentence = nil;

	if (!info) {
		[self.tableView reloadData];
		return;
	}

	NSString *subject = self.screenTitle ?: @"";
	NSString *storeName = TGL(@"CollectibleItemInfo.StoreName", @"Fragment");
	NSString *dateText = [self formattedDate:[info[@"purchaseDate"] longLongValue]] ?: @"";

	NSString *cryptoCurrency = info[@"cryptocurrency"];
	long long cryptoAmount = [info[@"cryptocurrencyAmount"] longLongValue];
	NSString *cryptoText = (cryptoCurrency.length && cryptoAmount > 0)
		? [NSString stringWithFormat:@"~%.4f %@", cryptoAmount / 1000000000.0, cryptoCurrency]
		: @"";

	NSString *fiatText = [self formattedAmount:[info[@"amount"] longLongValue]
									  currency:info[@"currency"]] ?: @"";

	BOOL isPhone = [self.collectibleType[@"phone_number"] length] > 0;
	NSString *template = isPhone
		? TGL(@"CollectibleItemInfo.PhoneText",
			@"The phone number %1$@ was acquired on %2$@ on %3$@ for %4$@ (%5$@).")
		: TGL(@"CollectibleItemInfo.UsernameText",
			@"The username %1$@ was acquired on %2$@ on %3$@ for %4$@ (%5$@).");
	self.infoSentence = [NSString stringWithFormat:template, subject, storeName, dateText, cryptoText, fiatText];

	NSString *url = info[@"url"];
	self.fragmentUrl = url.length ? url : nil;

	[self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.fragmentUrl.length ? 1 : 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	return self.infoSentence;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	CGFloat measured = [[TGTheme shared] groupedCommentHeightForText:caption width:tableView.bounds.size.width];
	return TGGroupedFooterHeight(caption, measured);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	if (!caption.length)
		return nil;
	return [[TGTheme shared] groupedCommentViewWithText:caption width:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"learnMore"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"learnMore"];
	[[TGTheme shared] styleCell:cell];

	[TGIcons actionButtonInCell:cell
						  title:TGL(@"CollectibleItemInfo.ButtonOpenInfo", @"Learn More")
						   kind:TGActionButtonKindNeutral
						 target:self
						 action:@selector(learnMorePressed)];
	return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return TGActionRowHeight();
}

- (void)learnMorePressed {
	if (!self.fragmentUrl.length)
		return;
	[TGWebViewController openURLString:self.fragmentUrl fromViewController:self];
}

@end

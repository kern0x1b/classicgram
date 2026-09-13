#import "TGStarsAction.h"
#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGClient+ChatState.h"
#import "TGStringTruncation.h"
#import "TGDateUtils.h"
#import "TGStarsViewController.h"
#import "TGStarsViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGClient+Premium.h"
#import "TGClient+Payments.h"
#import "TGClient+ChatList.h"
#import "TGUpgradedGiftInfoViewController.h"
#import "TGForwardPicker.h"
#import "TGAlertView.h"
#import "TGActionSheet.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGPlainEmojiText.h"
#import "TGHexColour.h"

const NSInteger kStarsPageSize = 25;
const NSInteger kStarsGiftPageSize = 20;
const NSInteger kStarsGiftCollectionNameMaxLength = 12;

UIView *TGStarsSectionHeaderWithTitle(NSString *title, CGFloat width) {
	TGTheme *theme = [TGTheme shared];
	return [theme groupedHeaderViewWithTitle:title
									   width:width];
}

CGFloat TGStarsCommentHeight(NSString *comment, CGFloat width) {
	if (!comment.length)
		return 8;
	return [[TGTheme shared] groupedCommentHeightForText:comment width:width];
}

UIView *TGStarsCommentViewWithText(NSString *comment, CGFloat width) {
	return [[TGTheme shared] groupedCommentViewWithText:comment width:width];
}

NSDictionary *TGStarsRow(NSString *title,
	NSString *subtitle,
	NSString *value,
	void (^block)(void)) {
	NSMutableDictionary *row = [NSMutableDictionary dictionary];
	row[@"title"] = title ?: @"";
	if (subtitle.length)
		row[@"subtitle"] = subtitle;
	if (value.length)
		row[@"value"] = value;
	if (block)
		row[@"block"] = [block copy];
	return row;
}

NSDictionary *TGStarsBadgeRow(NSString *title,
	NSString *badgeText,
	NSString *detailText,
	void (^block)(void)) {
	NSMutableDictionary *row = [NSMutableDictionary dictionary];
	row[@"title"] = title ?: @"";
	if (badgeText.length)
		row[@"badge"] = badgeText;
	if (detailText.length)
		row[@"subtitle"] = detailText;
	if (block)
		row[@"block"] = [block copy];
	return row;
}

@implementation TGStarsViewController

- (id)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	self.title = TGL(@"Stars.Intro.Title", @"Telegram Stars");
	self.transactions = [NSMutableArray array];
	self.gifts = [NSMutableArray array];
	self.subscriptions = [NSMutableArray array];
	self.transactionsOffset = @"";
	self.giftsOffset = @"";
	self.balance = [[TGClient shared] cachedStarBalance];
	self.balanceKnown = self.balance != 0;

	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	if (self.navigationController.navigationBar)
		[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];

	UIButton *reload = [TGIcons headerButtonWithTitle:TGL(@"WebBrowser.Reload", @"Reload") bold:NO
											   target:self
											   action:@selector(reloadTapped)];
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:reload];

	[self generateSectionHeaders];
	[self loadFirstPages];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if ([self.tableView indexPathForSelectedRow])
		[self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow]
									  animated:animated];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	if (self.opensGiftCatalogue && !self.cataloguePushed) {
		self.cataloguePushed = YES;
		[self pushGiftCatalogue];
		return;
	}
	if (self.opensStarPacks && !self.starPacksPushed) {
		self.starPacksPushed = YES;
		[self pushStarPacks];
	}
}

- (void)generateSectionHeaders {
	CGFloat width = self.tableView.bounds.size.width ?: [UIScreen mainScreen].bounds.size.width;
	NSString *giftsTitle = self.giftTotal > 0
		? [NSString stringWithFormat:TGL(@"Stars.Sections.GiftsReceivedCount", @"Gifts Received (%d)"), (int)self.giftTotal]
		: TGL(@"Stars.Sections.GiftsReceived", @"Gifts Received");
	id subscriptionsHeader = self.subscriptions.count
		? TGStarsSectionHeaderWithTitle(TGL(@"Stars.Intro.Subscriptions.Title", @"Subscriptions"), width)
		: (id)[NSNull null];
	self.sectionHeaderViews = [NSArray arrayWithObjects:
			[NSNull null],
		TGStarsSectionHeaderWithTitle(TGL(@"Stars.Sections.Transactions", @"Transactions"), width),
		subscriptionsHeader,
		TGStarsSectionHeaderWithTitle(giftsTitle, width),
		TGStarsSectionHeaderWithTitle(TGL(@"Privacy.Gifts", @"Gifts"), width),
		TGStarsSectionHeaderWithTitle(TGL(@"Common.More", @"More"), width), nil];
}

- (void)reloadTapped {
	self.reloadEpoch = self.reloadEpoch + 1;
	[self.transactions removeAllObjects];
	[self.gifts removeAllObjects];
	[self.subscriptions removeAllObjects];
	self.subscriptionsLoaded = NO;
	self.subscriptionsLoading = NO;
	self.transactionsOffset = @"";
	self.giftsOffset = @"";
	self.transactionsLoaded = NO;
	self.transactionsFailed = NO;
	self.transactionsLoading = NO;
	self.giftsLoaded = NO;
	self.giftsLoading = NO;
	self.giftTotal = 0;
	[self generateSectionHeaders];
	[self.tableView reloadData];
	[self loadFirstPages];
}

#pragma mark - loading

- (void)loadFirstPages {
	[self loadMoreTransactions];
	[self loadMoreGifts];
	[self loadSubscriptions];
}

- (void)loadSubscriptions {
	if (self.subscriptionsLoading)
		return;
	self.subscriptionsLoading = YES;
	NSInteger epoch = self.reloadEpoch;
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client
		starSubscriptionsOnlyExpiring:NO
							   offset:@""
						   completion:^(NSDictionary *page) {
							   typeof(self) strongSelf = weakSelf;
							   if (!strongSelf || strongSelf.reloadEpoch != epoch)
								   return;
							   strongSelf.subscriptionsLoading = NO;
							   strongSelf.subscriptionsLoaded = YES;
							   [strongSelf.subscriptions removeAllObjects];
							   if ([page isKindOfClass:[NSDictionary class]]) {
								   NSArray *rows = page[@"subscriptions"];
								   if ([rows isKindOfClass:[NSArray class]]) {
									   for (id row in rows) {
										   if ([row isKindOfClass:[NSDictionary class]])
											   [strongSelf.subscriptions addObject:row];
									   }
								   }
								   NSNumber *balance = page[@"balance"];
								   if ([balance isKindOfClass:[NSNumber class]] && [balance longLongValue]) {
									   strongSelf.balance = [balance longLongValue];
									   strongSelf.balanceNanos = [page[@"balanceNanos"] longLongValue];
									   strongSelf.balanceKnown = YES;
								   }
							   }
							   [strongSelf generateSectionHeaders];
							   [strongSelf.tableView reloadData];
						   }];
}

- (void)loadMoreTransactions {
	if (self.transactionsLoading)
		return;
	self.transactionsLoading = YES;
	NSInteger epoch = self.reloadEpoch;
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client starTransactionsWithOffset:self.transactionsOffset
								 limit:kStarsPageSize
							completion:^(NSDictionary *page) {
								typeof(self) strongSelf = weakSelf;
								if (!strongSelf || strongSelf.reloadEpoch != epoch)
									return;
								strongSelf.transactionsLoading = NO;
								strongSelf.transactionsLoaded = YES;
								if (![page isKindOfClass:[NSDictionary class]]) {
									strongSelf.transactionsFailed = YES;
									[strongSelf.tableView reloadData];
									return;
								}
								strongSelf.transactionsFailed = NO;
								NSNumber *balance = page[@"balance"];
								if ([balance isKindOfClass:[NSNumber class]]) {
									strongSelf.balance = [balance longLongValue];
									strongSelf.balanceNanos = [page[@"balanceNanos"] longLongValue];
									strongSelf.balanceKnown = YES;
								}
								NSArray *rows = page[@"transactions"];
								if ([rows isKindOfClass:[NSArray class]]) {
									for (id row in rows) {
										if ([row isKindOfClass:[NSDictionary class]])
											[strongSelf.transactions addObject:row];
									}
								}
								NSString *next = page[@"nextOffset"];
								strongSelf.transactionsOffset = [next isKindOfClass:[NSString class]] ? next : @"";
								[strongSelf.tableView reloadData];
							}];
}

- (void)loadMoreGifts {
	if (self.giftsLoading)
		return;
	int64_t userId = [[TGClient shared].me[@"id"] longLongValue];
	if (!userId) {
		self.giftsLoaded = YES;
		[self.tableView reloadData];
		return;
	}
	self.giftsLoading = YES;
	NSInteger epoch = self.reloadEpoch;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] receivedGiftsForUser:userId
							   collectionId:0
									 offset:self.giftsOffset
									  limit:kStarsGiftPageSize
								 completion:^(NSArray *gifts, NSString *nextOffset, NSInteger total) {
									 typeof(self) strongSelf = weakSelf;
									 if (!strongSelf || strongSelf.reloadEpoch != epoch)
										 return;
									 strongSelf.giftsLoading = NO;
									 strongSelf.giftsLoaded = YES;
									 if ([gifts isKindOfClass:[NSArray class]]) {
										 for (id gift in gifts) {
											 if ([gift isKindOfClass:[NSDictionary class]])
												 [strongSelf.gifts addObject:gift];
										 }
									 }
									 strongSelf.giftTotal = total;
									 [strongSelf generateSectionHeaders];
									 strongSelf.giftsOffset = [nextOffset isKindOfClass:[NSString class]] ? nextOffset : @"";
									 [strongSelf.tableView reloadData];
								 }];
}

- (BOOL)hasMoreTransactions {
	return self.transactions.count > 0 && self.transactionsOffset.length > 0;
}

- (BOOL)hasMoreGifts {
	return self.gifts.count > 0 && self.giftsOffset.length > 0;
}

#pragma mark - formatting

- (NSString *)formattedNumber:(NSNumber *)value {
	if (![value isKindOfClass:[NSNumber class]])
		return @"-";
	long long raw = [value longLongValue];
	if (raw >= 1000 || raw <= -1000) {
		static NSNumberFormatter *formatter = nil;
		if (!formatter) {
			formatter = [[NSNumberFormatter alloc] init];
			formatter.numberStyle = NSNumberFormatterDecimalStyle;
		}
		NSString *text = [formatter stringFromNumber:@(raw)];
		if (text.length)
			return text;
	}
	return [NSString stringWithFormat:@"%lld", raw];
}

- (NSString *)starsText:(long long)stars signed:(BOOL)withSign {
	return [self starsText:stars nanos:0 signed:withSign];
}

- (NSString *)starsText:(long long)stars nanos:(long long)nanos signed:(BOOL)withSign {
	BOOL isPositive = stars > 0 || (stars == 0 && nanos > 0);
	NSString *text = [self formattedNumber:@(stars)];
	long long fraction = llabs(nanos) / 10000000;
	if (fraction > 0)
		text = [text stringByAppendingFormat:@".%lld", fraction];
	return [NSString stringWithFormat:@"%@%@ ★", (withSign && isPositive) ? @"+" : @"", text];
}

- (NSString *)dayTextFromValue:(NSNumber *)value {
	if (![value isKindOfClass:[NSNumber class]] || ![value doubleValue])
		return @"";
	return [TGDateUtils stringForFullDate:(int)[value doubleValue]];
}

- (NSString *)dateTextFromValue:(NSNumber *)value {
	if (![value isKindOfClass:[NSNumber class]] || ![value doubleValue])
		return @"";
	return [TGDateUtils stringForFullDateAndTime:(int)[value doubleValue]];
}

- (NSString *)counterpartyForTransaction:(NSDictionary *)transaction {
	NSString *title = transaction[@"title"];
	if ([title isKindOfClass:[NSString class]] && title.length)
		return title;
	NSString *type = transaction[@"type"];
	if ([type isKindOfClass:[NSString class]] && type.length)
		return type;
	return TGL(@"Stars.Transaction.CounterpartyTelegram", @"Telegram");
}

- (BOOL)transactionIsRefund:(NSDictionary *)transaction {
	return [transaction[@"refund"] boolValue] || [transaction[@"isRefund"] boolValue];
}

- (NSString *)subtitleForTransaction:(NSDictionary *)transaction {
	NSString *date = [self dateTextFromValue:transaction[@"date"]];
	if ([self transactionIsRefund:transaction]) {
		NSString *refund = TGL(@"Stars.Transaction.Refund", @"Refund");
		if (date.length)
			return [NSString stringWithFormat:@"%@ · %@", refund, date];
		return refund;
	}
	return date;
}

- (NSString *)senderNameForGift:(NSDictionary *)gift {
	NSString *sender = gift[@"senderName"];
	if (![sender isKindOfClass:[NSString class]] || !sender.length) {
		int64_t senderId = [gift[@"senderId"] longLongValue];
		BOOL senderIsChat = [gift[@"senderIsChat"] boolValue];
		if (senderId)
			sender = senderIsChat ? [[TGClient shared] cachedTitleForChatId:senderId]
								   : [[TGClient shared] nameForUserId:senderId];
		else
			sender = nil;
	}
	if (![sender isKindOfClass:[NSString class]] || !sender.length)
		return nil;
	return sender;
}

- (NSString *)initialsForName:(NSString *)name {
	if (!name.length)
		return @"★";
	return [TGSafeFirstCharacter(name) uppercaseString];
}

#pragma mark - shape

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return TGStarsSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == TGStarsSectionBalance)
		return 1;
	if (section == TGStarsSectionTransactions) {
		if (!self.transactions.count)
			return 1;
		return (NSInteger)self.transactions.count + ([self hasMoreTransactions] ? 1 : 0);
	}
	if (section == TGStarsSectionSubscriptions)
		return (NSInteger)self.subscriptions.count;
	if (section == TGStarsSectionGiftTools)
		return TGStarsGiftToolCount;
	if (section == TGStarsSectionMore)
		return TGStarsMoreCount;
	if (!self.gifts.count)
		return 1;
	return (NSInteger)self.gifts.count + ([self hasMoreGifts] ? 1 : 0);
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	id header = self.sectionHeaderViews[section];
	return [header isKindOfClass:[UIView class]] ? 46 : 8;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	id header = self.sectionHeaderViews[section];
	return [header isKindOfClass:[UIView class]] ? header : nil;
}

- (NSString *)commentForSection:(NSInteger)section {
	if (section == TGStarsSectionBalance)
		return TGL(@"Stars.Sections.BalanceFooter", @"Stars are earned and spent inside Telegram. They cannot be bought here.");
	if (section == TGStarsSectionTransactions) {
		if (self.transactionsFailed)
			return TGL(@"Stars.Sections.TransactionsFailedFooter", @"The history could not be loaded. Tap Reload to try again.");
		if (self.transactionsLoaded && !self.transactions.count)
			return TGL(@"Stars.Sections.TransactionsEmptyFooter", @"Everything this account earns or spends will be listed here.");
		return nil;
	}
	if (section == TGStarsSectionSubscriptions) {
		if (self.subscriptions.count)
			return TGL(@"Stars.Sections.SubscriptionsFooter", @"Canceled subscriptions stay active until the paid period ends.");
		return nil;
	}
	if (section == TGStarsSectionGifts) {
		if (self.giftsLoaded && !self.gifts.count)
			return TGL(@"Stars.Sections.GiftsEmptyFooter", @"Gifts friends send you appear here.");
		return nil;
	}
	if (section == TGStarsSectionGiftTools)
		return TGL(@"Stars.Sections.GiftToolsFooter", @"Sending a gift spends stars from the balance above.");
	if (section == TGStarsSectionMore)
		return TGL(@"Stars.Sections.MoreFooter", @"Star packs are listed for reference. Stars are bought outside this client.");
	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *comment = [self commentForSection:section];
	if (!comment.length)
		return section + 1 == TGStarsSectionCount ? 8 : 1;
	return TGStarsCommentHeight(comment, tableView.bounds.size.width ?: [UIScreen mainScreen].bounds.size.width);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	return TGStarsCommentViewWithText([self commentForSection:section],
		tableView.bounds.size.width ?: [UIScreen mainScreen].bounds.size.width);
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == TGStarsSectionTransactions && self.transactions.count)
		return 51;
	if (indexPath.section == TGStarsSectionGifts && self.gifts.count)
		return 51;
	if (indexPath.section == TGStarsSectionSubscriptions)
		return 51;
	if (indexPath.section == TGStarsSectionMore && indexPath.row == TGStarsMoreClearPaymentInfo)
		return TGActionRowHeight();
	return 44;
}

#pragma mark - cells

- (UITableViewCell *)plainCellInTable:(UITableView *)tableView
								style:(UITableViewCellStyle)style
							  reuseId:(NSString *)reuseId {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseId];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:reuseId];
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.accessoryView = nil;
	cell.imageView.image = nil;
	cell.detailTextLabel.text = @"";
	cell.textLabel.textAlignment = NSTextAlignmentLeft;
	cell.textLabel.shadowColor = nil;
	cell.textLabel.shadowOffset = CGSizeZero;
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	cell.textLabel.font = [UIFont systemFontOfSize:16];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	[[TGTheme shared] styleCell:cell];
	return cell;
}

- (UITableViewCell *)balanceCellInTable:(UITableView *)tableView {
	UITableViewCell *cell = [self plainCellInTable:tableView
											 style:UITableViewCellStyleValue1
										   reuseId:@"TGStarsBalance"];
	cell.textLabel.text = TGL(@"Stars.Intro.Balance", @"Balance");
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;

	if (self.balanceKnown) {
		cell.detailTextLabel.text = [self starsText:self.balance nanos:self.balanceNanos signed:NO];
		cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	} else if (self.transactionsFailed) {
		cell.detailTextLabel.text = TGL(@"SocksProxySetup.ProxyStatusUnavailable", @"unavailable");
		cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	} else {
		cell.detailTextLabel.text = TGL(@"SocksProxySetup.ProxyStatusChecking", @"checking...");
		cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	}
	return cell;
}

- (UITableViewCell *)statusCellInTable:(UITableView *)tableView text:(NSString *)text {
	UITableViewCell *cell = [self plainCellInTable:tableView
											 style:UITableViewCellStyleDefault
										   reuseId:@"TGStarsStatus"];
	cell.textLabel.text = text;
	cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
	cell.textLabel.textColor = [[TGTheme shared] emptyStateColour];
	cell.textLabel.shadowColor = [UIColor colorWithWhite:1.0f alpha:0.5f];
	cell.textLabel.shadowOffset = CGSizeMake(0, 1);
	cell.textLabel.textAlignment = NSTextAlignmentCenter;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	return cell;
}

- (UITableViewCell *)moreCellInTable:(UITableView *)tableView loading:(BOOL)loading {
	UITableViewCell *cell = [self plainCellInTable:tableView
											 style:UITableViewCellStyleDefault
										   reuseId:@"TGStarsMore"];
	cell.textLabel.text = loading ? TGL(@"Channel.NotificationLoading", @"Loading…") : TGL(@"Chat.RichText.ShowMore", @"Show more");
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textColor = loading ? [[TGTheme shared] secondaryTextColour]
									   : [[TGTheme shared] groupedActionColour];
	cell.selectionStyle = loading ? UITableViewCellSelectionStyleNone
								  : UITableViewCellSelectionStyleBlue;
	return cell;
}

- (UILabel *)amountLabelWithStars:(long long)stars {
	return [self amountLabelWithStars:stars nanos:0];
}

- (UILabel *)amountLabelWithStars:(long long)stars nanos:(long long)nanos {
	BOOL isNegative = stars < 0 || (stars == 0 && nanos < 0);
	NSString *text = [self starsText:stars nanos:nanos signed:YES];
	UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 90, 20)];
	label.text = text;
	label.font = [UIFont boldSystemFontOfSize:16];
	label.backgroundColor = [UIColor clearColor];
	label.textAlignment = NSTextAlignmentRight;
	label.textColor = isNegative ? TGColourFromHex(0xee4928) : TGColourFromHex(0x41a903);
	CGSize size = [text sizeWithFont:label.font];
	label.frame = CGRectMake(0, 0, ceilf(size.width) + 2, 20);
	return label;
}

- (UILabel *)valueLabelWithText:(NSString *)text {
	UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 90, 20)];
	label.text = text;
	label.font = [UIFont boldSystemFontOfSize:16];
	label.backgroundColor = [UIColor clearColor];
	label.textAlignment = NSTextAlignmentRight;
	label.textColor = [[TGTheme shared] emptyStateColour];
	CGSize size = [text sizeWithFont:label.font];
	label.frame = CGRectMake(0, 0, ceilf(size.width) + 2, 20);
	return label;
}

- (UITableViewCell *)transactionCellInTable:(UITableView *)tableView
										row:(NSInteger)row {
	NSDictionary *transaction = self.transactions[row];
	UITableViewCell *cell = [self plainCellInTable:tableView
											 style:UITableViewCellStyleSubtitle
										   reuseId:@"TGStarsTransaction"];
	NSString *name = [self counterpartyForTransaction:transaction];
	cell.textLabel.text = name;
	cell.textLabel.font = [UIFont systemFontOfSize:16];
	cell.detailTextLabel.text = [self subtitleForTransaction:transaction];

	NSString *type = transaction[@"type"];
	int64_t colourId = [type isKindOfClass:[NSString class]] ? (int64_t)[type hash] : 0;
	if (colourId < 0)
		colourId = -colourId;
	UIImage *avatar = [TGIcons avatarWithInitials:[self initialsForName:name]
											 size:40
										 colourId:colourId];
	cell.imageView.image = avatar;

	cell.accessoryView = [self amountLabelWithStars:[transaction[@"stars"] longLongValue]
											   nanos:[transaction[@"starsNanos"] longLongValue]];
	return cell;
}

- (UITableViewCell *)giftCellInTable:(UITableView *)tableView row:(NSInteger)row {
	NSDictionary *gift = self.gifts[row];
	UITableViewCell *cell = [self plainCellInTable:tableView
											 style:UITableViewCellStyleSubtitle
										   reuseId:@"TGStarsGift"];
	NSString *title = gift[@"title"];
	if (![title isKindOfClass:[NSString class]] || !title.length)
		title = TGL(@"Gift.View.Title", @"Gift");
	cell.textLabel.text = title;
	cell.textLabel.font = [UIFont systemFontOfSize:16];

	NSString *sender = TGTextWithoutInvisibleEmojiModifiers([self senderNameForGift:gift]);
	if (!sender.length)
		sender = TGL(@"SendStarReactions.UserLabelAnonymous", @"Anonymous");
	NSString *date = [self dayTextFromValue:gift[@"date"]];
	cell.detailTextLabel.text = date.length
		? [NSString stringWithFormat:TGL(@"Stars.From", @"from %@ · %@"), sender, date]
		: [NSString stringWithFormat:TGL(@"Stars.ChannelGifts.FromSender", @"from %@"), sender];

	UIImage *avatar = [TGIcons avatarWithInitials:@"★"
											 size:40
										 colourId:[gift[@"isUnique"] boolValue] ? 4 : 2];
	cell.imageView.image = avatar;

	if ([gift[@"isUnique"] boolValue]) {
		NSString *currency = gift[@"valueCurrency"];
		long long value = [gift[@"valueAmount"] longLongValue];
		if ([currency isKindOfClass:[NSString class]] && currency.length && value > 0) {
			NSString *text = [NSString stringWithFormat:@"%.2f %@", value / 100.0, currency];
			cell.accessoryView = [self valueLabelWithText:text];
		}
	} else {
		long long stars = [gift[@"starCount"] longLongValue];
		if (stars > 0)
			cell.accessoryView = [self amountLabelWithStars:stars];
	}
	return cell;
}

- (NSString *)periodTextForSeconds:(long long)seconds {
	if (seconds >= 31000000)
		return TGL(@"Stars.Subscription.PeriodYear", @"year");
	if (seconds >= 2500000)
		return TGL(@"Stars.Subscription.PeriodMonth", @"month");
	if (seconds >= 600000)
		return TGL(@"Stars.Subscription.PeriodWeek", @"week");
	if (seconds >= 86400)
		return TGLPlural(@"Stars.Subscription.PeriodDays", (NSInteger)(seconds / 86400), @"%@ day", @"%@ days");
	return TGL(@"Stars.Subscription.PeriodGeneric", @"period");
}

- (NSString *)titleForSubscription:(NSDictionary *)subscription {
	NSString *title = subscription[@"title"];
	if ([title isKindOfClass:[NSString class]] && title.length)
		return title;
	int64_t chatId = [subscription[@"chatId"] longLongValue];
	if (chatId) {
		NSString *chatTitle = [[TGClient shared] cachedTitleForChatId:chatId];
		if (chatTitle.length)
			return chatTitle;
	}
	return TGL(@"Stars.Transaction.Subscription", @"Subscription");
}

- (NSString *)subtitleForSubscription:(NSDictionary *)subscription {
	NSString *date = [self dateTextFromValue:subscription[@"expirationDate"]];
	if ([subscription[@"isCanceled"] boolValue])
		return date.length ? [NSString stringWithFormat:TGL(@"Stars.Intro.Subscriptions.Expires", @"expires on %@"), date]
							: TGL(@"Stars.Intro.Subscriptions.Cancelled", @"cancelled");
	if ([subscription[@"isExpiring"] boolValue])
		return date.length ? [NSString stringWithFormat:TGL(@"Stars.Intro.Subscriptions.Expires", @"expires on %@"), date]
							: TGL(@"Stars.Subscription.Expiring", @"Expiring");
	return date.length ? [NSString stringWithFormat:TGL(@"Stars.Intro.Subscriptions.Renews", @"renews on %@"), date]
						: TGL(@"Stars.Subscription.Active", @"Active");
}

- (UITableViewCell *)subscriptionCellInTable:(UITableView *)tableView row:(NSInteger)row {
	NSDictionary *subscription = self.subscriptions[row];
	UITableViewCell *cell = [self plainCellInTable:tableView
											 style:UITableViewCellStyleSubtitle
										   reuseId:@"TGStarsSubscription"];
	NSString *title = [self titleForSubscription:subscription];
	cell.textLabel.text = title;
	cell.textLabel.font = [UIFont systemFontOfSize:16];
	cell.detailTextLabel.text = [self subtitleForSubscription:subscription];
	if ([subscription[@"isCanceled"] boolValue] || [subscription[@"isExpiring"] boolValue])
		cell.detailTextLabel.textColor = [[TGTheme shared] groupedDestructiveColour];

	int64_t chatId = [subscription[@"chatId"] longLongValue];
	if (chatId < 0)
		chatId = -chatId;
	UIImage *avatar = [TGIcons avatarWithInitials:[self initialsForName:title]
											 size:40
										 colourId:chatId];
	cell.imageView.image = avatar;

	long long stars = [subscription[@"stars"] longLongValue];
	if (stars > 0) {
		UILabel *label = [[UILabel alloc] init];
		label.text = [self starsText:stars signed:NO];
		label.font = [UIFont boldSystemFontOfSize:16];
		label.backgroundColor = [UIColor clearColor];
		label.textAlignment = NSTextAlignmentRight;
		label.textColor = [[TGTheme shared] secondaryTextColour];
		CGSize size = [label.text sizeWithFont:label.font];
		label.frame = CGRectMake(0, 0, ceilf(size.width) + 2, 20);
		cell.accessoryView = label;
	}
	return cell;
}

- (NSString *)menuTitleAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == TGStarsSectionGiftTools) {
		switch (indexPath.row) {
			case TGStarsGiftToolCatalogue:
				return TGL(@"Gift.Options.Gift.Title", @"Gift Catalogue");
			case TGStarsGiftToolCollections:
				return TGL(@"Stars.MyCollections", @"My Collections");
			case TGStarsGiftToolSettings:
				return TGL(@"Stars.WhoCanGiftMe", @"Who Can Gift Me");
			default:
				return TGL(@"Stars.GiftsOnAChannel", @"Gifts on a Channel");
		}
	}
	switch (indexPath.row) {
		case TGStarsMoreStarPacks:
			return TGL(@"Stars.MenuStarPacks", @"Star Packs");
		case TGStarsMoreIncoming:
			return TGL(@"Stars.Intro.Incoming", @"Incoming Payments");
		case TGStarsMoreOutgoing:
			return TGL(@"Stars.Intro.Outgoing", @"Outgoing Payments");
		case TGStarsMorePaidMessages:
			return TGL(@"GroupInfo.Permissions.ChargeForMessages", @"Charge for Messages");
		case TGStarsMoreAffiliatePrograms:
			return TGL(@"AffiliateSetup.TitleJoin", @"Affiliate Programs");
		default:
			return TGL(@"Privacy.PaymentsClearInfo", @"Clear Saved Payment Info");
	}
}

- (UITableViewCell *)menuCellInTable:(UITableView *)tableView
						 atIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [self plainCellInTable:tableView
											 style:UITableViewCellStyleValue1
										   reuseId:@"TGStarsMenu"];
	BOOL destructive = indexPath.section == TGStarsSectionMore &&
		indexPath.row == TGStarsMoreClearPaymentInfo;
	if (destructive) {
		[TGIcons actionButtonInCell:cell
							  title:[self menuTitleAtIndexPath:indexPath]
							   kind:TGActionButtonKindDestructive
							 target:self
							 action:@selector(clearSavedPaymentInfo)];
		return cell;
	}
	[TGIcons removeActionButtonFromCell:cell];
	cell.textLabel.text = [self menuTitleAtIndexPath:indexPath];
	cell.textLabel.textColor = [[TGTheme shared] primaryTextColour];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == TGStarsSectionSubscriptions)
		return [self subscriptionCellInTable:tableView row:indexPath.row];

	if (indexPath.section == TGStarsSectionBalance)
		return [self balanceCellInTable:tableView];

	if (indexPath.section == TGStarsSectionTransactions) {
		if (!self.transactions.count) {
			if (!self.transactionsLoaded)
				return [self statusCellInTable:tableView text:TGL(@"Stars.LoadingTransactions", @"Loading transactions...")];
			if (self.transactionsFailed)
				return [self statusCellInTable:tableView text:TGL(@"Stars.HistoryUnavailable", @"History Unavailable")];
			return [self statusCellInTable:tableView text:TGL(@"Stars.NoTransactionsYet", @"No Transactions Yet")];
		}
		if (indexPath.row >= (NSInteger)self.transactions.count)
			return [self moreCellInTable:tableView loading:self.transactionsLoading];
		return [self transactionCellInTable:tableView row:indexPath.row];
	}

	if (indexPath.section == TGStarsSectionGiftTools ||
		indexPath.section == TGStarsSectionMore)
		return [self menuCellInTable:tableView atIndexPath:indexPath];

	if (!self.gifts.count) {
		if (!self.giftsLoaded)
			return [self statusCellInTable:tableView text:TGL(@"Stars.LoadingGifts", @"Loading gifts...")];
		return [self statusCellInTable:tableView text:TGL(@"Stars.NoGiftsYet", @"No Gifts Yet")];
	}
	if (indexPath.row >= (NSInteger)self.gifts.count)
		return [self moreCellInTable:tableView loading:self.giftsLoading];
	return [self giftCellInTable:tableView row:indexPath.row];
}

@end

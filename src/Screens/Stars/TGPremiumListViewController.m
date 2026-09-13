#import "TGListBackground.h"
#import "TGPremiumListViewController.h"
#import "TGFriendlyError.h"
#import "TGPremiumViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGDateUtils.h"
#import "TGClient+Premium.h"
#import "TGClient+ChatList.h"
#import "TGTheme.h"
#import "TGAlertView.h"
#import "TGActionSheet.h"
#import "TGBusinessMessageViewController.h"
#import "TGBusinessLocationViewController.h"
#import "TGBusinessOpeningHoursViewController.h"
#import "TGBusinessChatLinksViewController.h"
#import "TGBusinessStartPageViewController.h"
#import "TGBusinessConnectedBotViewController.h"
#import "TGPrepaidGiveawayViewController.h"
#import "TGQuickReplyListViewController.h"

enum {
	TGPremiumRowPlain = 0,
	TGPremiumRowTappable,
	TGPremiumRowLevel,
	TGPremiumRowLoadMore
};

@interface TGPremiumListViewController ()
@property (nonatomic, assign) NSInteger mode;
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, strong) NSMutableArray *rows;
@property (nonatomic, strong) NSString *nextOffset;
@property (nonatomic, strong) NSString *statusText;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) int64_t sheetChatId;
@end

@implementation TGPremiumListViewController

- (id)initWithMode:(NSInteger)mode chatId:(int64_t)chatId title:(NSString *)title {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		_mode = mode;
		_chatId = chatId;
		_rows = [[NSMutableArray alloc] init];
		_nextOffset = @"";
		_statusText = TGL(@"Channel.NotificationLoading", @"Loading…");
		self.title = title;
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	if (self.navigationController.navigationBar)
		[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	[self load];
}

- (void)addRowWithTitle:(NSString *)title
				 detail:(NSString *)detail
				   kind:(NSInteger)kind
				payload:(NSDictionary *)payload {
	NSMutableDictionary *row = [NSMutableDictionary dictionaryWithCapacity:4];
	row[@"title"] = title.length ? title : @" ";
	row[@"detail"] = detail.length ? detail : @"";
	row[@"kind"] = @(kind);
	if (payload)
		row[@"payload"] = payload;
	[self.rows addObject:row];
}

- (void)finishedWithEmptyText:(NSString *)text {
	self.loading = NO;
	self.statusText = self.rows.count ? @"" : text;
	[self.tableView reloadData];
}

- (void)load {
	if (self.loading)
		return;
	self.loading = YES;
	switch (self.mode) {
		case TGPremiumListGiftCodes:
			[self loadGiftCodes];
			break;
		case TGPremiumListGiveaways:
			[self loadGiveaways];
			break;
		case TGPremiumListBoostLevels:
			[self loadBoosts];
			break;
		case TGPremiumListBoosters:
			[self loadBoosters];
			break;
		default:
			[self loadBusinessFeatures];
			break;
	}
}

- (void)loadGiftCodes {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] accountGiftCodesWithLimit:0 completion:^(NSArray *codes) {
		if (!weakSelf)
			return;
		[weakSelf.rows removeAllObjects];
		for (id raw in ([codes isKindOfClass:[NSArray class]] ? codes : @[])) {
			if (![raw isKindOfClass:[NSDictionary class]])
				continue;
			NSDictionary *entry = raw;
			NSString *code = [entry[@"code"] isKindOfClass:[NSString class]]
				? entry[@"code"]
				: @"";
			long long stars = [entry[@"stars"] longLongValue];
			NSMutableString *detail = [NSMutableString string];
			if (stars > 0)
				[detail appendString:TGLPlural(@"PeerInfo.Bot.Balance.Stars", (NSInteger)stars, @"%@ Star", @"%@ Stars")];
			else if ([entry[@"months"] integerValue] > 0)
				[detail appendString:TGLPlural(@"Premium.Gift.Months", [entry[@"months"] integerValue], @"%@ Month", @"%@ Months")];
			else if ([entry[@"days"] integerValue] > 0)
				[detail appendString:TGLPlural(@"Premium.Gift.Days", [entry[@"days"] integerValue], @"%@ Day", @"%@ Days")];
			if ([entry[@"unclaimed"] boolValue]) {
				NSString *unclaimed = TGL(@"Stats.Boosts.Unclaimed", @"Unclaimed");
				[detail appendString:detail.length ? [NSString stringWithFormat:@" · %@", unclaimed] : unclaimed];
			}
			NSString *date = TGPremiumDateText(entry[@"date"]);
			if (date.length)
				[detail appendString:detail.length ? [NSString stringWithFormat:@" · %@", date] : date];
			NSString *title = code.length ? code : TGL(@"Premium.StarPrize", @"Star prize");
			[weakSelf addRowWithTitle:title
							   detail:detail
								 kind:code.length ? TGPremiumRowTappable : TGPremiumRowPlain
							  payload:entry];
		}
		[weakSelf finishedWithEmptyText:TGL(@"Premium.NoGiftCodesHaveBeenSentToThis", @"No gift codes have been sent to this account.")];
	}];
}

- (void)loadGiveaways {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] enteredGiveawaysWithLimit:0 completion:^(NSArray *giveaways) {
		if (!weakSelf)
			return;
		[weakSelf.rows removeAllObjects];
		for (id raw in ([giveaways isKindOfClass:[NSArray class]] ? giveaways : @[])) {
			if (![raw isKindOfClass:[NSDictionary class]])
				continue;
			NSDictionary *entry = raw;
			NSString *title = [entry[@"chatTitle"] isKindOfClass:[NSString class]] && [entry[@"chatTitle"] length] ? entry[@"chatTitle"] : TGL(@"Channel.Setup.Title", @"Channel");
			NSString *status = [entry[@"statusText"] isKindOfClass:[NSString class]]
				? entry[@"statusText"]
				: @"";
			if (!status.length)
				status = [entry[@"ongoing"] boolValue] ? TGL(@"Premium.Ongoing", @"Ongoing") : TGL(@"BackgroundTasks.MediaFinished", @"Finished");
			[weakSelf addRowWithTitle:title
							   detail:status
								 kind:TGPremiumRowTappable
							  payload:entry];
		}
		[weakSelf finishedWithEmptyText:
				TGL(@"Premium.ThisAccountHasNotEnteredAnyGiveaway", @"This account has not entered any giveaway in a channel it boosts.")];
	}];
}

- (void)loadBoosts {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] availableBoostSlotsWithCompletion:^(NSArray *slots) {
		if (!weakSelf)
			return;
		[weakSelf.rows removeAllObjects];
		[weakSelf addRowWithTitle:TGL(@"Premium.BoostSlots", @"Boost slots")
							detail:@""
							  kind:TGPremiumRowLevel
						   payload:nil];
		for (id raw in ([slots isKindOfClass:[NSArray class]] ? slots : @[])) {
			if (![raw isKindOfClass:[NSDictionary class]])
				continue;
			NSDictionary *slot = raw;
			int64_t slotChat = [slot[@"chatId"] longLongValue];
			NSString *title = [NSString stringWithFormat:TGL(@"Premium.SlotNumbered", @"Slot %d"),
				(int)[slot[@"slotId"] integerValue]];
			if (slotChat == 0 || [slot[@"free"] boolValue]) {
				[weakSelf addRowWithTitle:title detail:TGL(@"Tour.Title6", @"Free")
									 kind:TGPremiumRowPlain
								  payload:slot];
				continue;
			}
			NSString *detail;
			if ([slot[@"reassignable"] boolValue]) {
				detail = TGL(@"Premium.InUseCanBeMoved", @"In use · can be moved");
			} else {
				NSTimeInterval cooldown = [slot[@"cooldownUntil"] doubleValue];
				detail = cooldown > [[NSDate date] timeIntervalSince1970]
					? [NSString stringWithFormat:@"%@ · %@",
						TGL(@"Premium.InUse", @"In use"),
						[NSString stringWithFormat:TGL(@"Channel.AdminLog.MessageRestrictedUntil", @"until %@"),
							[TGDateUtils stringForUntil:(int)cooldown]]]
					: TGL(@"Premium.InUse", @"In use");
			}
			[weakSelf addRowWithTitle:title detail:detail
								 kind:TGPremiumRowTappable
							  payload:slot];
			NSInteger index = weakSelf.rows.count - 1;
			[[TGClient shared] titleForChatId:slotChat completion:^(NSString *chatTitle) {
				if (!weakSelf || index >= weakSelf.rows.count || !chatTitle.length)
					return;
				NSMutableDictionary *row = weakSelf.rows[index];
				row[@"title"] = chatTitle;
				[weakSelf.tableView reloadData];
			}];
		}
		[weakSelf loadBoostLevelsAfterSlots];
	}];
}

- (void)loadBoostLevelsAfterSlots {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] boostFeaturesForChannel:YES completion:^(NSArray *levels) {
		if (!weakSelf)
			return;
		[weakSelf addRowWithTitle:TGL(@"Premium.WhatBoostsUnlock", @"What Boosts Unlock")
							detail:@""
							  kind:TGPremiumRowLevel
						   payload:nil];
		for (id raw in ([levels isKindOfClass:[NSArray class]] ? levels : @[])) {
			if (![raw isKindOfClass:[NSDictionary class]])
				continue;
			NSDictionary *level = raw;
			[weakSelf addRowWithTitle:[NSString stringWithFormat:TGL(@"ChannelBoost.Level", @"Level %@"),
										  [@((int)[level[@"level"] integerValue]) stringValue]]
							   detail:@""
								 kind:TGPremiumRowLevel
							  payload:nil];
			id features = level[@"features"];
			if (![features isKindOfClass:[NSArray class]])
				continue;
			for (id line in features) {
				if ([line isKindOfClass:[NSString class]])
					[weakSelf addRowWithTitle:line detail:@""
										 kind:TGPremiumRowPlain
									  payload:nil];
			}
		}
		[weakSelf finishedWithEmptyText:TGL(@"Premium.TheBoostLevelTableIsUnavailable", @"The boost level table is unavailable.")];
	}];
}

- (void)loadBoosters {
	__weak typeof(self) weakSelf = self;
	NSString *offset = self.nextOffset.length ? self.nextOffset : @"";
	void (^received)(NSDictionary *) = ^(NSDictionary *page) {
		if (!weakSelf)
			return;
		if (![page isKindOfClass:[NSDictionary class]]) {
			[weakSelf finishedWithEmptyText:TGL(@"Premium.TheBoosterListIsUnavailable", @"The booster list is unavailable.")];
			return;
		}
		if (weakSelf.rows.count && [weakSelf.rows.lastObject[@"kind"] integerValue] == TGPremiumRowLoadMore)
			[weakSelf.rows removeLastObject];
		id boosts = page[@"boosts"];
		for (id raw in ([boosts isKindOfClass:[NSArray class]] ? boosts : @[])) {
			if (![raw isKindOfClass:[NSDictionary class]])
				continue;
			NSDictionary *boost = raw;
			NSString *name = [boost[@"name"] isKindOfClass:[NSString class]] ? boost[@"name"] : @"";
			if (!name.length)
				name = [boost[@"unclaimed"] boolValue] ? TGL(@"Notification.PremiumPrize.Unclaimed", @"Unclaimed Prize") : TGL(@"Premium.Booster", @"Booster");
			NSString *source = [boost[@"source"] isKindOfClass:[NSString class]] ? boost[@"source"] : @"";
			NSInteger count = [boost[@"count"] integerValue];
			NSMutableString *detail = [NSMutableString string];
			if (count > 1)
				[detail appendString:TGLPlural(@"Stats.Boosts.TabBoosts", count, @"%@ Boost", @"%@ Boosts")];
			if (source.length)
				[detail appendString:detail.length ? [NSString stringWithFormat:@" · %@", source] : source];
			[weakSelf addRowWithTitle:name detail:detail kind:TGPremiumRowPlain payload:boost];
		}
		NSString *next = [page[@"nextOffset"] isKindOfClass:[NSString class]] ? page[@"nextOffset"] : @"";
		weakSelf.nextOffset = next;
		if (next.length && weakSelf.rows.count) {
			NSString *showMore = TGL(@"ChatList.Search.ShowMore", @"Show More");
			[weakSelf addRowWithTitle:showMore detail:@"" kind:TGPremiumRowLoadMore payload:nil];
		}
		NSInteger total = [page[@"totalCount"] integerValue];
		if (total > 0)
			weakSelf.title = TGLPlural(@"Stats.Boosts.Boosters", total, @"%@ BOOSTER", @"%@ BOOSTERS");
		[weakSelf finishedWithEmptyText:TGL(@"Stats.Boosts.NoBoostersYet", @"Nobody has boosted this channel yet.")];
	};
	[[TGClient shared] boostersInChat:self.chatId onlyGiftCodes:NO offset:offset limit:20 completion:received];
}

- (void)loadBusinessFeatures {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] businessFeaturesWithCompletion:^(NSArray *features) {
		if (!weakSelf)
			return;
		[weakSelf.rows removeAllObjects];
		for (id raw in ([features isKindOfClass:[NSArray class]] ? features : @[])) {
			if (![raw isKindOfClass:[NSDictionary class]])
				continue;
			NSDictionary *feature = raw;
			NSString *title = [feature[@"title"] isKindOfClass:[NSString class]] && [feature[@"title"] length] ? feature[@"title"] : feature[@"type"];
			NSString *subtitle = [feature[@"subtitle"] isKindOfClass:[NSString class]]
				? feature[@"subtitle"]
				: @"";
			[weakSelf addRowWithTitle:title
							   detail:subtitle
								 kind:subtitle.length ? TGPremiumRowTappable : TGPremiumRowPlain
							  payload:feature];
		}
		[weakSelf finishedWithEmptyText:TGL(@"Premium.TheBusinessFeatureListIsUnavailable", @"The Business feature list is unavailable.")];
	}];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.rows.count ? (NSInteger)self.rows.count : 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!self.rows.count)
		return 54;
	NSDictionary *row = self.rows[indexPath.row];
	if ([row[@"kind"] integerValue] == TGPremiumRowLevel)
		return 34;
	if ([row[@"detail"] length] > 34)
		return 58;
	return 44;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!self.rows.count) {
		static NSString *emptyId = @"TGPremiumListEmpty";
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:emptyId];
		if (!cell)
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
										  reuseIdentifier:emptyId];
		[[TGTheme shared] styleCell:cell];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.accessoryType = UITableViewCellAccessoryNone;
		cell.textLabel.numberOfLines = 0;
		cell.textLabel.textAlignment = NSTextAlignmentCenter;
		cell.textLabel.font = [UIFont systemFontOfSize:15];
		cell.textLabel.textColor = [[TGTheme shared] secondaryTextColour];
		cell.textLabel.text = self.loading ? TGL(@"Channel.NotificationLoading", @"Loading…") : self.statusText;
		return cell;
	}

	NSDictionary *row = self.rows[indexPath.row];
	NSInteger kind = [row[@"kind"] integerValue];
	BOOL isLevel = kind == TGPremiumRowLevel;
	NSString *reuseId = isLevel ? @"TGPremiumListLevel" : @"TGPremiumListRow";
	UITableViewCellStyle style = isLevel ? UITableViewCellStyleDefault : UITableViewCellStyleSubtitle;
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseId];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:reuseId];
	[[TGTheme shared] styleCell:cell];
	cell.textLabel.numberOfLines = 1;
	cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
	cell.textLabel.text = row[@"title"];
	cell.detailTextLabel.numberOfLines = 2;
	cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	cell.detailTextLabel.text = row[@"detail"];

	if (kind == TGPremiumRowLevel) {
		cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
		cell.textLabel.textColor = [[TGTheme shared] secondaryTextColour];
		cell.accessoryType = UITableViewCellAccessoryNone;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		return cell;
	}

	cell.textLabel.font = [UIFont systemFontOfSize:16];
	cell.textLabel.textColor = kind == TGPremiumRowLoadMore
		? [[TGTheme shared] accentColour]
		: [[TGTheme shared] primaryTextColour];
	cell.accessoryType = kind == TGPremiumRowTappable
		? UITableViewCellAccessoryDisclosureIndicator
		: UITableViewCellAccessoryNone;
	cell.selectionStyle = kind == TGPremiumRowPlain
		? UITableViewCellSelectionStyleNone
		: UITableViewCellSelectionStyleBlue;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (!self.rows.count)
		return;
	NSDictionary *row = self.rows[indexPath.row];
	NSInteger kind = [row[@"kind"] integerValue];
	if (kind == TGPremiumRowLoadMore) {
		[self load];
		return;
	}
	if (kind != TGPremiumRowTappable)
		return;

	NSDictionary *payload = row[@"payload"];
	switch (self.mode) {
		case TGPremiumListGiftCodes:
			[self showGiftCode:payload];
			break;
		case TGPremiumListGiveaways:
			[self showGiveaway:payload];
			break;
		case TGPremiumListBoostLevels:
			if (payload[@"chatId"])
				[self showSlotActions:payload atIndexPath:indexPath];
			break;
		case TGPremiumListBusiness: {
			NSString *type = payload[@"type"];
			if ([type isEqualToString:@"greetingMessage"]) {
				TGBusinessMessageViewController *editor = [[TGBusinessMessageViewController alloc]
					initWithKind:TGBusinessMessageGreeting];
				[self.navigationController pushViewController:editor animated:YES];
				break;
			}
			if ([type isEqualToString:@"awayMessage"]) {
				TGBusinessMessageViewController *editor = [[TGBusinessMessageViewController alloc]
					initWithKind:TGBusinessMessageAway];
				[self.navigationController pushViewController:editor animated:YES];
				break;
			}
			if ([type isEqualToString:@"location"]) {
				TGBusinessLocationViewController *editor = [[TGBusinessLocationViewController alloc] init];
				[self.navigationController pushViewController:editor animated:YES];
				break;
			}
			if ([type isEqualToString:@"openingHours"]) {
				TGBusinessOpeningHoursViewController *editor = [[TGBusinessOpeningHoursViewController alloc] init];
				[self.navigationController pushViewController:editor animated:YES];
				break;
			}
			if ([type isEqualToString:@"accountLinks"]) {
				TGBusinessChatLinksViewController *editor = [[TGBusinessChatLinksViewController alloc] init];
				[self.navigationController pushViewController:editor animated:YES];
				break;
			}
			if ([type isEqualToString:@"startPage"]) {
				TGBusinessStartPageViewController *editor = [[TGBusinessStartPageViewController alloc] init];
				[self.navigationController pushViewController:editor animated:YES];
				break;
			}
			if ([type isEqualToString:@"bots"]) {
				TGBusinessConnectedBotViewController *editor = [[TGBusinessConnectedBotViewController alloc] init];
				[self.navigationController pushViewController:editor animated:YES];
				break;
			}
			if ([type isEqualToString:@"quickReplies"]) {
				TGQuickReplyListViewController *list = [[TGQuickReplyListViewController alloc] initWithChatId:0];
				[self.navigationController pushViewController:list animated:YES];
				break;
			}
			TGAlertView *alert = [TGAlertView alloc];
			alert = [alert initWithTitle:row[@"title"]
								 message:row[@"detail"]
					   cancelButtonTitle:TGL(@"Common.OK", @"OK")
						   okButtonTitle:nil
						 completionBlock:nil];
			[alert show];
			break;
		}
		default:
			break;
	}
}

- (void)showGiftCode:(NSDictionary *)entry {
	NSString *code = [entry[@"code"] isKindOfClass:[NSString class]] ? entry[@"code"] : @"";
	if (!code.length)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] checkGiftCode:code completion:^(NSDictionary *info) {
		if (![info isKindOfClass:[NSDictionary class]]) {
			TGAlertView *fail = [TGAlertView alloc];
			fail = [fail initWithTitle:TGL(@"GiftLink.Title", @"Gift Code")
							   message:TGL(@"Login.UnknownError", @"An error occurred, please try again later.")
					 cancelButtonTitle:TGL(@"Common.OK", @"OK")
						 okButtonTitle:nil
					   completionBlock:nil];
			[fail show];
			return;
		}
		NSMutableString *message = [NSMutableString stringWithString:code];
		NSInteger months = [info[@"months"] integerValue];
		NSInteger days = [info[@"days"] integerValue];
		if (months > 0)
			[message appendFormat:@"\n%@", TGLPlural(@"Premium.MonthsOfPremium", months, @"%@ month of Premium", @"%@ months of Premium")];
		else if (days > 0)
			[message appendFormat:@"\n%@", TGLPlural(@"Premium.DaysOfPremium", days, @"%@ day of Premium", @"%@ days of Premium")];
		if ([info[@"fromGiveaway"] boolValue])
			[message appendFormat:@"\n%@", TGL(@"Premium.FromAGiveaway", @"From a giveaway")];
		NSString *created = TGPremiumDateText(info[@"creationDate"]);
		if (created.length)
			[message appendFormat:@"\n%@", [NSString stringWithFormat:TGL(@"Premium.CreatedDate", @"Created %@"), created]];
		BOOL used = [info[@"used"] boolValue];
		if (used) {
			NSString *usedDate = TGPremiumDateText(info[@"useDate"]);
			[message appendFormat:@"\n%@", usedDate.length
				? [NSString stringWithFormat:TGL(@"GiftLink.UsedFooter", @"This link was used on %@."), usedDate]
				: TGL(@"Premium.AlreadyUsed", @"Already used")];
			TGAlertView *alert = [TGAlertView alloc];
			alert = [alert initWithTitle:TGL(@"GiftLink.Title", @"Gift Code")
								 message:message
					   cancelButtonTitle:TGL(@"Common.OK", @"OK")
						   okButtonTitle:nil
						 completionBlock:nil];
			[alert show];
			return;
		}
		[message appendFormat:@"\n%@", TGL(@"GiftLink.NotUsedFooter", @"This link hasn't been used yet.")];
		void (^applied)(BOOL, NSString *) = ^(BOOL ok, NSString *error) {
			NSString *failure = TGFriendlyErrorText(error, TGL(@"Premium.TheCodeCouldNotBeRedeemed", @"The code could not be redeemed."));
			NSString *resultTitle = TGL(@"GiftLink.Title", @"Gift Code");
			NSString *resultText = ok ? TGL(@"Premium.TheCodeWasAppliedToThis", @"The code was applied to this account.") : failure;
			TGAlertView *result = [TGAlertView alloc];
			result = [result initWithTitle:resultTitle
								   message:resultText
						 cancelButtonTitle:TGL(@"Common.OK", @"OK")
							 okButtonTitle:nil
						   completionBlock:nil];
			[result show];
			if (ok && weakSelf)
				[weakSelf load];
		};
		void (^redeem)(bool) = ^(bool okPressed) {
			if (!okPressed)
				return;
			[[TGClient shared] applyGiftCode:code completion:applied];
		};
		TGAlertView *alert = [TGAlertView alloc];
		alert = [alert initWithTitle:TGL(@"GiftLink.Title", @"Gift Code")
							 message:message
				   cancelButtonTitle:TGL(@"Common.Close", @"Close")
					   okButtonTitle:TGL(@"GiftLink.UseLink", @"Use Link")
					 completionBlock:redeem];
		[alert show];
	}];
}

- (void)showGiveaway:(NSDictionary *)entry {
	int64_t messageId = [entry[@"messageId"] longLongValue];
	int64_t chatId = [entry[@"chatId"] longLongValue];
	NSString *title = [entry[@"chatTitle"] isKindOfClass:[NSString class]] && [entry[@"chatTitle"] length] ? entry[@"chatTitle"] : TGL(@"Message.Giveaway", @"Giveaway");
	if (messageId == 0 || chatId == 0)
		return;
	void (^received)(NSDictionary *) = ^(NSDictionary *info) {
		NSString *message = nil;
		if (![info isKindOfClass:[NSDictionary class]]) {
			message = TGL(@"Premium.ThisGiveawayCouldNotBeLoaded", @"This giveaway could not be loaded.");
		} else {
			NSMutableString *text = [NSMutableString string];
			NSString *status = [info[@"statusText"] isKindOfClass:[NSString class]] ? info[@"statusText"] : @"";
			if (status.length)
				[text appendString:status];
			BOOL ongoing = [info[@"ongoing"] boolValue];
			if (!ongoing) {
				NSString *winners = TGPremiumDateText(info[@"winnersDate"]);
				if (winners.length)
					[text appendFormat:@"%@%@", text.length ? @"\n" : @"",
						[NSString stringWithFormat:TGL(@"Premium.WinnersPickedDate", @"Winners picked %@"), winners]];
				NSInteger winnerCount = [info[@"winnerCount"] integerValue];
				if (winnerCount > 0)
					[text appendFormat:@"\n%@", TGLPlural(@"Notification.GiveawayWinnersCount", winnerCount, @"%ld winner", @"%ld winners")];
			} else {
				NSString *created = TGPremiumDateText(info[@"creationDate"]);
				if (created.length)
					[text appendFormat:@"%@%@", text.length ? @"\n" : @"",
						[NSString stringWithFormat:TGL(@"Premium.StartedDate", @"Started %@"), created]];
			}
			message = text.length ? text : TGL(@"Premium.NoDetailsForThisGiveaway", @"No details for this giveaway.");
		}
		TGAlertView *alert = [TGAlertView alloc];
		alert = [alert initWithTitle:title
							 message:message
				   cancelButtonTitle:TGL(@"Common.OK", @"OK")
					   okButtonTitle:nil
					 completionBlock:nil];
		[alert show];
	};
	[[TGClient shared] giveawayInfoForMessage:messageId inChat:chatId completion:received];
}

- (void)showSlotActions:(NSDictionary *)slot atIndexPath:(NSIndexPath *)indexPath {
	int64_t slotChat = [slot[@"chatId"] longLongValue];
	if (slotChat == 0)
		return;
	self.sheetChatId = slotChat;

	NSArray *actions = @[
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Stats.Boosts", @"Boosts") action:@"status"],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Premium.WhoBoosted", @"Who Boosted") action:@"boosters"],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"ChannelBoost.CopyLink", @"Copy Boost Link") action:@"link"],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Common.Cancel", @"Cancel") action:@"cancel"
											  type:TGActionSheetActionTypeCancel]
	];

	__weak typeof(self) weakSelf = self;
	TGActionSheet *sheet = [[TGActionSheet alloc]
		initWithTitle:nil
			  actions:actions
		  actionBlock:^(id target, NSString *action) {
			  if (!weakSelf)
				  return;
			  if ([action isEqualToString:@"status"])
				  [weakSelf showBoostStatusForChat:weakSelf.sheetChatId];
			  else if ([action isEqualToString:@"boosters"])
				  [weakSelf pushBoostersForChat:weakSelf.sheetChatId];
			  else if ([action isEqualToString:@"link"])
				  [weakSelf copyBoostLinkForChat:weakSelf.sheetChatId];
		  }
			   target:self];
	UITableViewCell *rowCell = [self.tableView cellForRowAtIndexPath:indexPath];
	CGRect anchorRect = rowCell ? rowCell.frame
		: CGRectMake(CGRectGetMidX(self.tableView.bounds), CGRectGetMidY(self.tableView.bounds), 1, 1);
	[sheet tg_showFromRect:anchorRect inView:self.tableView];
}

- (void)pushBoostersForChat:(int64_t)chatId {
	TGPremiumListViewController *list = [[TGPremiumListViewController alloc]
		initWithMode:TGPremiumListBoosters
			  chatId:chatId
			   title:TGL(@"Stats.Boosts", @"Boosts")];
	[self.navigationController pushViewController:list animated:YES];
}

- (void)copyBoostLinkForChat:(int64_t)chatId {
	void (^received)(NSString *, BOOL) = ^(NSString *url, BOOL isPublic) {
		NSString *title = nil;
		NSString *message = nil;
		if (url.length) {
			[[UIPasteboard generalPasteboard] setString:url];
			NSString *note = isPublic ? @"" : TGL(@"Premium.ThisChatIsPrivateSoTheLinkOnlyWorks", @" This chat is private, so the link only works for people who can already see it.");
			title = TGL(@"ChannelBoost.BoostLinkCopied", @"Boost link copied.");
			message = [NSString stringWithFormat:@"%@%@", url, note];
		} else {
			title = TGL(@"ChannelBoost.CopyLink", @"Copy Boost Link");
			message = TGL(@"Premium.TheBoostLinkCouldNotBeFetched", @"The boost link could not be fetched.");
		}
		TGAlertView *alert = [TGAlertView alloc];
		alert = [alert initWithTitle:title
							 message:message
				   cancelButtonTitle:TGL(@"Common.OK", @"OK")
					   okButtonTitle:nil
					 completionBlock:nil];
		[alert show];
	};
	[[TGClient shared] chatBoostLinkForChat:chatId completion:received];
}

- (void)showBoostStatusForChat:(int64_t)chatId {
	__weak typeof(self) weakSelf = self;
	void (^received)(NSDictionary *) = ^(NSDictionary *status) {
		NSString *message = nil;
		NSArray *prepaidGiveaways = nil;
		if (![status isKindOfClass:[NSDictionary class]]) {
			message = TGL(@"Premium.TheBoostStatusCouldNotBeFetched", @"The boost status could not be fetched.");
		} else {
			NSMutableString *text = [NSMutableString string];
			[text appendString:[NSString stringWithFormat:TGL(@"ChannelBoost.Level", @"Level %@"), [@([status[@"level"] integerValue]) stringValue]]];
			[text appendFormat:@"\n%@", TGLPlural(@"Stats.Boosts.TabBoosts", [status[@"boostCount"] integerValue], @"%@ Boost", @"%@ Boosts")];
			NSInteger next = [status[@"nextLevelBoostCount"] integerValue];
			NSInteger current = [status[@"boostCount"] integerValue];
			if (next > current)
				[text appendFormat:@"\n%d %@", (int)(next - current), TGL(@"Stats.Boosts.BoostsToLevelUp", @"Boosts to Level Up")];
			NSInteger gifted = [status[@"giftCodeBoostCount"] integerValue];
			if (gifted > 0)
				[text appendFormat:@"\n%@", TGLPlural(@"Stats.Boosts.TabGifts", gifted, @"%@ Gift", @"%@ Gifts")];
			NSInteger premiumMembers = [status[@"premiumMemberCount"] integerValue];
			if (premiumMembers > 0) {
				double percentage = [status[@"premiumMemberPercentage"] doubleValue];
				[text appendFormat:@"\n%d %@ (%.1f%%)", (int)premiumMembers, TGL(@"Stats.Boosts.PremiumMembers", @"Premium Members"), percentage];
			}
			if ([status[@"boosted"] boolValue])
				[text appendFormat:@"\n%@", TGL(@"ChannelBoost.YouBoostedOtherChannelText", @"You boosted this channel")];
			id prepaid = status[@"prepaidGiveaways"];
			if ([prepaid isKindOfClass:[NSArray class]] && [prepaid count]) {
				prepaidGiveaways = prepaid;
				[text appendFormat:@"\n%d %@", (int)[prepaid count], TGL(@"Stats.Boosts.PrepaidGiveawaysTitle", @"Prepaid Giveaways")];
			}
			message = text;
		}
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (prepaidGiveaways.count) {
			void (^launched)(bool) = ^(bool launch) {
				__strong typeof(weakSelf) innerSelf = weakSelf;
				if (!innerSelf || !launch)
					return;
				[innerSelf pushPrepaidGiveawaysForChat:chatId list:prepaidGiveaways];
			};
			TGAlertView *alert = [TGAlertView alloc];
			alert = [alert initWithTitle:TGL(@"Stats.Boosts", @"Boosts")
								 message:message
					   cancelButtonTitle:TGL(@"Common.OK", @"OK")
						   okButtonTitle:TGL(@"BoostGift.StartGiveaway", @"Launch a Giveaway")
						 completionBlock:launched];
			[alert show];
			return;
		}
		TGAlertView *alert = [TGAlertView alloc];
		alert = [alert initWithTitle:TGL(@"Stats.Boosts", @"Boosts")
							 message:message
				   cancelButtonTitle:TGL(@"Common.OK", @"OK")
					   okButtonTitle:nil
					 completionBlock:nil];
		[alert show];
	};
	[[TGClient shared] chatBoostStatusForChat:chatId completion:received];
}

- (void)pushPrepaidGiveawaysForChat:(int64_t)chatId list:(NSArray *)prepaidGiveaways {
	TGPrepaidGiveawayViewController *picker = [[TGPrepaidGiveawayViewController alloc]
		initWithChatId:chatId
			 giveaways:prepaidGiveaways];
	[self.navigationController pushViewController:picker animated:YES];
}

@end

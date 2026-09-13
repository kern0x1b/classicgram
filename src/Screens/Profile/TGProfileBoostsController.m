#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGClient+Contacts.h"
#import "TGClient+ChatState.h"
#import "TGProfileBoostsController.h"
#import "TGBoosterPageMerge.h"
#import "TGProfileViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGPopupMenu.h"
#import "TGActionSheet.h"
#import "TGForwardPicker.h"
#import "UIView+SafeTint.h"
#import "TGImageDecode.h"
#import "TGClient+Channels.h"
#import "TGClient+Notifications.h"
#import "TGLazyFramework.h"
#import <AVFoundation/AVFoundation.h>
#import <AddressBook/AddressBook.h>
#import <ImageIO/ImageIO.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>
#import "TGEmoji.h"
#import "TGDateLabel.h"
#import "TGDateUtils.h"
#import "TGAlertView.h"

static const NSInteger kBoostersPageLimit = 50;

@implementation TGProfileBoostsController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"Stats.Boosts", @"Boosts");
	self.boosters = @[];
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	[self reload];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)reload {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] boostStatusForChat:self.chatId completion:^(NSDictionary *status) {
		if ([status isKindOfClass:[NSDictionary class]])
			weakSelf.status = status;
		[weakSelf.tableView reloadData];
		[weakSelf loadNextLevelFeatures];
	}];
	[[TGClient shared] boostLevelFeatureTableForChannel:self.channel
											 completion:^(NSArray *levels,
												 NSDictionary *minimums) {
												 weakSelf.featureTable = [levels isKindOfClass:[NSArray class]] ? levels : @[];
												 [weakSelf.tableView reloadData];
											 }];
	[[TGClient shared] boostLinkForChat:self.chatId
							 completion:^(NSString *link, BOOL isPublic) {
								 weakSelf.boostLink = TGProfileText(link);
								 [weakSelf.tableView reloadData];
							 }];
	self.boostersGeneration++;
	self.boosters = @[];
	self.boostersOffset = @"";
	self.boostersExhausted = NO;
	self.boostersPending = NO;
	[self loadMoreBoosters];
}

- (void)loadMoreBoosters {
	if (self.boostersPending || self.boostersExhausted)
		return;
	self.boostersPending = YES;
	NSString *offset = [self.boostersOffset isKindOfClass:[NSString class]]
		? self.boostersOffset
		: @"";
	NSInteger generation = self.boostersGeneration;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] boostsForChat:self.chatId
					   onlyGiftCodes:NO
							  offset:offset
							   limit:kBoostersPageLimit
						  completion:^(NSArray *boosts, NSString *nextOffset,
							  NSInteger totalCount) {
							  TGProfileBoostsController *strongSelf = weakSelf;
							  if (!strongSelf || strongSelf.boostersGeneration != generation)
								  return;
							  strongSelf.boostersPending = NO;
							  strongSelf.boostersTotal = totalCount;
							  NSString *next = [nextOffset isKindOfClass:[NSString class]]
								  ? nextOffset
								  : @"";
							  NSArray *merged = TGBoostersWithPageAppended(strongSelf.boosters, boosts);
							  if (!merged || !next.length || [next isEqualToString:offset]) {
								  strongSelf.boostersExhausted = YES;
								  if (!merged)
									  return;
							  }
							  strongSelf.boostersOffset = next;
							  strongSelf.boosters = merged;
							  [strongSelf.tableView reloadData];
						  }];
}

- (void)tableView:(UITableView *)tableView
	willDisplayCell:(UITableViewCell *)cell
  forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section != 2 || !self.boosters.count)
		return;
	if (indexPath.row < (NSInteger)self.boosters.count - 1)
		return;
	[self loadMoreBoosters];
}

- (NSInteger)numberForKey:(NSString *)key {
	id value = self.status[key];
	return [value isKindOfClass:[NSNumber class]] ? [value integerValue] : 0;
}

- (void)loadNextLevelFeatures {
	NSInteger next = [self numberForKey:@"level"] + 1;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] boostLevelFeaturesForChannel:self.channel
											  level:next
										 completion:^(NSDictionary *features) {
											 if (![features isKindOfClass:[NSDictionary class]])
												 return;
											 weakSelf.nextLevelFeatures = features;
											 [weakSelf.tableView reloadData];
										 }];
}

+ (NSString *)summaryOfFeatures:(NSDictionary *)features {
	if (![features isKindOfClass:[NSDictionary class]])
		return nil;
	NSMutableArray *parts = [NSMutableArray array];
	NSInteger stories = [features[@"story_per_day_count"] isKindOfClass:[NSNumber class]]
		? [features[@"story_per_day_count"] integerValue]
		: 0;
	if (stories > 0)
		[parts addObject:TGLPlural(@"ChannelBoost.SummaryStoriesPerDay", stories, @"%ld story a day", @"%ld stories a day")];
	NSInteger reactions =
		[features[@"custom_emoji_reaction_count"] isKindOfClass:[NSNumber class]]
		? [features[@"custom_emoji_reaction_count"] integerValue]
		: 0;
	if (reactions > 0)
		[parts addObject:TGLPlural(@"ChannelBoost.SummaryCustomReactions", reactions, @"%ld custom reaction", @"%ld custom reactions")];
	NSInteger colours = [features[@"accent_color_count"] isKindOfClass:[NSNumber class]]
		? [features[@"accent_color_count"] integerValue]
		: 0;
	if (colours > 0)
		[parts addObject:TGLPlural(@"ChannelBoost.SummaryNameColours", colours, @"%ld name colour", @"%ld name colours")];
	if (TGProfileBool(features[@"can_set_emoji_status"]))
		[parts addObject:TGL(@"ChannelBoost.SummaryEmojiStatus", @"emoji status")];
	if (TGProfileBool(features[@"can_set_custom_background"]))
		[parts addObject:TGL(@"ChannelBoost.SummaryCustomBackground", @"custom background")];
	if (!parts.count)
		return nil;
	return [parts componentsJoinedByString:@", "];
}

- (void)openProfileForUserId:(int64_t)userId named:(NSString *)name {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] privateChatWithUser:userId completion:^(int64_t chatId) {
		TGProfileBoostsController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[TGProfileViewController showProfileForChatId:chatId
											   userId:userId
												title:name
										 inNavigation:strongSelf.navigationController];
	}];
}

- (NSArray *)summaryRows {
	if (!self.status)
		return @[];
	NSMutableArray *rows = [NSMutableArray array];
	[rows addObject:@[ TGL(@"Stats.Boosts.Level", @"Level"), [NSString stringWithFormat:@"%ld", (long)[self numberForKey:@"level"]] ]];
	[rows addObject:@[ TGL(@"Stats.Boosts.ExistingBoosts", @"Existing Boosts"), [NSString stringWithFormat:@"%ld", (long)[self numberForKey:@"boost_count"]] ]];
	NSInteger next = [self numberForKey:@"next_level_boost_count"];
	NSInteger current = [self numberForKey:@"boost_count"];
	if (next > current)
		[rows addObject:@[ TGL(@"Stats.Boosts.BoostsToLevelUp", @"Boosts to Level Up"),
			[NSString stringWithFormat:TGL(@"ChannelBoost.MoreToNextLevel", @"%ld more"), (long)(next - current)] ]];
	NSInteger premium = [self numberForKey:@"premium_member_count"];
	if (premium > 0)
		[rows addObject:@[ (self.channel
					? TGL(@"Stats.Boosts.PremiumSubscribers", @"Premium Subscribers")
					: TGL(@"Stats.Boosts.PremiumMembers", @"Premium Members")),
			[NSString stringWithFormat:TGL(@"ChannelBoost.PremiumMembersCountFormat", @"%ld (%ld%%)"), (long)premium,
				(long)[self numberForKey:@"premium_member_percentage"]] ]];
	return rows;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return [self summaryRows].count;
	if (section == 1)
		return self.status ? (self.boostLink.length ? 2 : 1) : 0;
	if (section == 2)
		return self.boosters.count;
	return self.featureTable.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 2 && self.boosters.count)
		return TGL(@"ChannelBoost.BoostedBySectionHeader", @"Boosted by");
	if (section == 3 && self.featureTable.count)
		return TGL(@"ChannelBoost.LevelUnlocksSectionHeader", @"What each level unlocks");
	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return [[TGTheme shared] groupedHeaderHeightForTitle:
			[self tableView:tableView titleForHeaderInSection:section]];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	TGTheme *theme = [TGTheme shared];
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [theme groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section != 0)
		return nil;
	if (!self.status)
		return TGL(@"Channel.NotificationLoading", @"Loading…");
	NSString *base = self.channel
		? TGL(@"ChannelBoost.SummaryFooterChannel", @"Boosts unlock extra features for this channel.")
		: TGL(@"ChannelBoost.SummaryFooterGroup", @"Boosts unlock extra features for this group.");
	NSString *next = [TGProfileBoostsController
		summaryOfFeatures:self.nextLevelFeatures];
	if (!next.length)
		return base;
	return [NSString stringWithFormat:TGL(@"ChannelBoost.SummaryFooterNextLevel", @"%@\nLevel %ld unlocks %@."), base,
		(long)([self numberForKey:@"level"] + 1), next];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	TGTheme *theme = [TGTheme shared];
	CGFloat measured = [theme groupedCommentHeightForText:caption width:tableView.bounds.size.width];
	return TGGroupedFooterHeight(caption, measured);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	TGTheme *theme = [TGTheme shared];
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	return [theme groupedCommentViewWithText:caption width:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"boost"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:@"boost"];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
	cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	cell.detailTextLabel.text = nil;

	if (indexPath.section == 0) {
		NSArray *rows = [self summaryRows];
		NSArray *pair = indexPath.row < (NSInteger)rows.count ? rows[indexPath.row] : nil;
		cell.textLabel.text = pair.count ? pair[0] : @"";
		cell.detailTextLabel.text = pair.count > 1 ? pair[1] : nil;
		return cell;
	}

	if (indexPath.section == 1) {
		[self fillBoostActionCell:cell atRow:indexPath.row];
		return cell;
	}

	if (indexPath.section == 3) {
		[self fillLevelFeatureCell:cell atRow:indexPath.row];
		return cell;
	}

	id raw = indexPath.row < (NSInteger)self.boosters.count
		? self.boosters[indexPath.row]
		: nil;
	NSDictionary *entry = [raw isKindOfClass:[NSDictionary class]] ? raw : @{};
	NSString *name = TGProfileText(entry[@"name"]);
	if (!name) {
		int64_t userId = TGProfileInt64(entry[@"user_id"]);
		name = userId ? TGProfileText([[TGClient shared] nameForUserId:userId]) : nil;
	}
	NSString *source = TGProfileText(entry[@"source"]);
	cell.textLabel.text = name ?: ([source isEqualToString:@"giveaway"] ? TGL(@"Message.Giveaway", @"Giveaway") : TGL(@"Stats.Boosts.Unclaimed", @"Unclaimed"));
	NSInteger count = [entry[@"count"] isKindOfClass:[NSNumber class]]
		? [entry[@"count"] integerValue]
		: 0;
	cell.detailTextLabel.text = count > 1
		? TGLPlural(@"Stats.Boosts.Boosts", count, @"%ld BOOST", @"%ld BOOSTS")
		: source;
	if (TGProfileInt64(entry[@"user_id"]))
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	return cell;
}

- (void)fillBoostActionCell:(UITableViewCell *)cell atRow:(NSInteger)row {
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	cell.textLabel.textAlignment = NSTextAlignmentCenter;
	cell.textLabel.textColor = [[TGTheme shared] groupedActionColour];
	BOOL boosted = TGProfileBool(self.status[@"is_boosted"]);
	if (row == 0)
		cell.textLabel.text = boosted ? TGL(@"ChannelBoost.BoostAgain", @"Boost Again") : TGL(@"ChannelBoost.BoostChannel", @"Boost This Chat");
	else
		cell.textLabel.text = TGL(@"ChannelBoost.CopyLink", @"Copy Boost Link");
}

- (void)fillLevelFeatureCell:(UITableViewCell *)cell atRow:(NSInteger)row {
	id level = row < (NSInteger)self.featureTable.count
		? self.featureTable[row]
		: nil;
	NSDictionary *features = [level isKindOfClass:[NSDictionary class]] ? level : @{};
	NSInteger number = [features[@"level"] isKindOfClass:[NSNumber class]]
		? [features[@"level"] integerValue]
		: (row + 1);
	cell.textLabel.text = [NSString stringWithFormat:TGL(@"ChannelBoost.Level", @"Level %@"), [@(number) stringValue]];
	cell.detailTextLabel.text =
		[TGProfileBoostsController summaryOfFeatures:features];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section == 2) {
		id raw = indexPath.row < (NSInteger)self.boosters.count
			? self.boosters[indexPath.row]
			: nil;
		if (![raw isKindOfClass:[NSDictionary class]])
			return;
		int64_t userId = TGProfileInt64([raw objectForKey:@"user_id"]);
		if (!userId)
			return;
		NSString *name = TGProfileText([raw objectForKey:@"name"])
			?: TGProfileText([[TGClient shared] nameForUserId:userId]);
		[self openProfileForUserId:userId named:name];
		return;
	}
	if (indexPath.section != 1)
		return;
	if (indexPath.row == 1) {
		if (!self.boostLink.length)
			return;
		[UIPasteboard generalPasteboard].string = self.boostLink;
		[[[UIAlertView alloc] initWithTitle:nil message:TGL(@"ChannelBoost.BoostLinkCopied", @"Boost link copied.")
								   delegate:nil
						  cancelButtonTitle:TGL(@"Common.OK", @"OK")
						  otherButtonTitles:nil] show];
		return;
	}
	[self boostNow];
}

- (void)boostNow {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] channelBoostSlotsWithCompletion:^(NSArray *slots) {
		if (![slots isKindOfClass:[NSArray class]])
			slots = @[];
		NSNumber *freeSlotId = nil;
		NSNumber *reassignSlotId = nil;
		int64_t reassignFromChatId = 0;
		BOOL hasCommittedSlot = NO;
		NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
		NSTimeInterval earliestCooldownDate = 0;
		for (id raw in slots) {
			if (![raw isKindOfClass:[NSDictionary class]])
				continue;
			NSDictionary *slot = raw;
			id slotId = slot[@"slot_id"];
			if (![slotId isKindOfClass:[NSNumber class]])
				continue;
			if (TGProfileBool(slot[@"is_free"])) {
				if (!freeSlotId)
					freeSlotId = slotId;
			} else if (TGProfileBool(slot[@"is_reassignable"]) && TGProfileInt64(slot[@"currently_boosted_chat_id"]) != self.chatId) {
				if (!reassignSlotId) {
					reassignSlotId = slotId;
					reassignFromChatId = TGProfileInt64(slot[@"currently_boosted_chat_id"]);
				}
			} else {
				hasCommittedSlot = YES;
				NSTimeInterval cooldown = (NSTimeInterval)TGProfileInt64(slot[@"cooldown_until_date"]);
				if (cooldown > now && (earliestCooldownDate == 0 || cooldown < earliestCooldownDate))
					earliestCooldownDate = cooldown;
			}
		}
		if (freeSlotId) {
			[weakSelf applyBoostWithSlotId:freeSlotId];
			return;
		}
		if (!reassignSlotId) {
			[weakSelf showNoAvailableSlotsAlertForCommittedSlots:hasCommittedSlot availableAgainDate:earliestCooldownDate];
			return;
		}
		[weakSelf confirmReassignFromChatId:reassignFromChatId thenApplyBoostWithSlotId:reassignSlotId];
	}];
}

- (void)showNoAvailableSlotsAlertForCommittedSlots:(BOOL)hasCommittedSlot availableAgainDate:(NSTimeInterval)availableAgainDate {
	NSString *message;
	if (hasCommittedSlot) {
		message = availableAgainDate > 0
			? [NSString stringWithFormat:
				TGL(@"ChannelBoost.Error.SlotsInCooldownDateText", @"All of your boost slots are currently boosting other chats. The next one becomes available %@."),
				[TGDateUtils stringForUntil:(int)availableAgainDate]]
			: TGL(@"ChannelBoost.Error.SlotsInCooldownText", @"All of your boost slots are currently boosting other chats. Try again once one of them becomes available.");
	} else {
		message = TGL(@"ChannelBoost.Error.PremiumNeededText", @"Only Telegram Premium subscribers can boost channels. Do you want to subscribe to Telegram Premium?");
	}
	[[[UIAlertView alloc] initWithTitle:nil
								message:message
							   delegate:nil
					  cancelButtonTitle:TGL(@"Common.OK", @"OK")
					  otherButtonTitles:nil] show];
}

- (void)confirmReassignFromChatId:(int64_t)fromChatId thenApplyBoostWithSlotId:(NSNumber *)slotId {
	__weak typeof(self) weakSelf = self;
	NSString *fromName = fromChatId ? TGProfileText([[TGClient shared] titleForChatId:fromChatId]) : nil;
	if (!fromName.length)
		fromName = TGL(@"ChannelBoost.AnotherChat", @"another chat");
	NSString *message = [NSString stringWithFormat:
		TGL(@"ChannelBoost.ReassignConfirmText", @"This will move your boost from %@. Continue?"), fromName];
	TGAlertView *confirm = [[TGAlertView alloc]
			initWithTitle:nil
				  message:message
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			okButtonTitle:TGL(@"ChannelBoost.BoostAgain", @"Boost Again")
		  completionBlock:^(bool okButtonPressed) {
			  if (okButtonPressed)
				  [weakSelf applyBoostWithSlotId:slotId];
		  }];
	[confirm show];
}

- (void)applyBoostWithSlotId:(NSNumber *)slotId {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] boostChat:self.chatId withSlotIds:@[ slotId ] completion:^(NSArray *updated) {
		if (!updated) {
			[[[UIAlertView alloc] initWithTitle:nil
										message:TGL(@"ChannelBoost.TheBoostCouldNotBeApplied", @"The boost could not be applied.")
									   delegate:nil
							  cancelButtonTitle:TGL(@"Common.OK", @"OK")
							  otherButtonTitles:nil] show];
			return;
		}
		[weakSelf reload];
	}];
}

@end

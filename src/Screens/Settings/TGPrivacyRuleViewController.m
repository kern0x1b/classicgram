#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGPrivacyViewController.h"
#import "TGPrivacyViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGClient+Privacy.h"
#import "TGFlattenPrivacy.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGSessionsViewController.h"
#import "TGPasscodeLock.h"
#import "TGSecurityStepViewController.h"

#import "TGPrivacyContactPickerViewController.h"
#import "TGPrivacyBotsFlags.h"
#pragma mark - privacy rule

typedef enum {
	TGPrivacyExceptionRowAllowed = 0,
	TGPrivacyExceptionRowRestricted,
	TGPrivacyExceptionRowBots,
	TGPrivacyExceptionRowPremium,
	TGPrivacyExceptionRowNone,
} TGPrivacyExceptionRowKind;

@interface TGPrivacyRuleViewController ()
@property (nonatomic, strong) NSString *setting;
@property (nonatomic, strong) NSString *value;
@property (nonatomic, strong) NSArray *allowedUsers;
@property (nonatomic, strong) NSArray *restrictedUsers;
@property (nonatomic, strong) NSArray *allowedChats;
@property (nonatomic, strong) NSArray *restrictedChats;
@property (nonatomic, assign) BOOL allowBots;
@property (nonatomic, assign) BOOL restrictBots;
@property (nonatomic, assign) BOOL allowPremiumUsers;
@property (nonatomic, assign) BOOL loaded;
@end

@implementation TGPrivacyRuleViewController

- (instancetype)initWithSetting:(NSString *)setting {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self)
		_setting = setting;
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = [TGClient titleForPrivacySetting:self.setting];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.rowHeight = 44;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] privacyRuleDetailed:self.setting completion:^(NSDictionary *info) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (![info isKindOfClass:[NSDictionary class]]) {
			TGPrivacyComplain(TGL(@"Privacy.TheSettingCouldNotBeRead",
					@"That setting could not be read."));
			[strongSelf.tableView reloadData];
			return;
		}
		strongSelf.loaded = YES;
		{
			id value = info[@"value"];
			strongSelf.value = [value isKindOfClass:[NSString class]] ? value : @"everybody";
			id allowed = info[@"allowedUserIds"];
			id restricted = info[@"restrictedUserIds"];
			strongSelf.allowedUsers = [allowed isKindOfClass:[NSArray class]] ? allowed : nil;
			strongSelf.restrictedUsers =
				[restricted isKindOfClass:[NSArray class]] ? restricted : nil;
			id allowedChats = info[@"allowedChatIds"];
			id restrictedChats = info[@"restrictedChatIds"];
			strongSelf.allowedChats =
				[allowedChats isKindOfClass:[NSArray class]] ? allowedChats : nil;
			strongSelf.restrictedChats =
				[restrictedChats isKindOfClass:[NSArray class]] ? restrictedChats : nil;
			strongSelf.allowBots = [info[@"allowBots"] boolValue];
			strongSelf.restrictBots = [info[@"restrictBots"] boolValue];
			strongSelf.allowPremiumUsers = [info[@"allowPremiumUsers"] boolValue];
		}
		[strongSelf.tableView reloadData];
	}];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (NSArray *)values {
	if ([self.setting isEqualToString:@"AllowFindingByPhoneNumber"])
		return [NSArray arrayWithObjects:@"everybody", @"contacts", nil];
	return [NSArray arrayWithObjects:@"everybody", @"contacts", @"nobody", nil];
}

- (NSString *)titleForValue:(NSString *)value {
	if ([value isEqualToString:@"contacts"])
		return TGL(@"PrivacySettings.LastSeenContacts", @"My Contacts");
	if ([value isEqualToString:@"nobody"])
		return TGL(@"PrivacySettings.LastSeenNobody", @"Nobody");
	return TGL(@"PrivacySettings.LastSeenEverybody", @"Everybody");
}

- (BOOL)showsAllowedRow {
	if (!TGPrivacySettingSupportsExceptions(self.setting))
		return NO;
	return ![self.value isEqualToString:@"everybody"];
}

- (BOOL)showsRestrictedRow {
	if (!TGPrivacySettingSupportsExceptions(self.setting))
		return NO;
	return ![self.value isEqualToString:@"nobody"];
}

- (BOOL)showsBotsRow {
	return self.loaded && [self.setting isEqualToString:@"AutosaveGifts"];
}

- (BOOL)showsPremiumRow {
	return self.loaded && [self.setting isEqualToString:@"AllowChatInvites"] && ![self.value isEqualToString:@"everybody"];
}

- (BOOL)showsExceptions {
	return self.loaded;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return [self showsExceptions] ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return self.loaded ? (NSInteger)[self values].count : 0;
	NSInteger rows = 0;
	if ([self showsAllowedRow])
		rows++;
	if ([self showsRestrictedRow])
		rows++;
	if ([self showsBotsRow])
		rows++;
	if ([self showsPremiumRow])
		rows++;
	return rows;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 0)
		return TGL(@"Privacy.WhoCanSeeThis", @"Who can see this");
	return TGL(@"Privacy.Exceptions", @"EXCEPTIONS");
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return [[TGTheme shared] groupedHeaderHeightForTitle:
			[self tableView:tableView titleForHeaderInSection:section]];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section == 0) {
		if (!self.loaded)
			return TGL(@"Channel.NotificationLoading", @"Loading…");
		if ([self.setting isEqualToString:@"AllowFindingByPhoneNumber"])
			return TGL(@"Privacy.FindByPhoneNumberRestriction",
				@"Telegram does not let this one be closed to everybody: "
				@"people who already have your number can always find you.");
		if ([self.setting isEqualToString:@"ShowPhoneNumber"])
			return TGL(@"PrivacyPhoneNumberSettings.CustomHelp",
				@"Users who already have your number saved in the contacts "
				@"will also see it on Telegram.");
		return nil;
	}
	return TGL(@"Privacy.ExceptionsFooter", @"These people are treated differently, whatever you chose above.");
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	CGFloat measured = [[TGTheme shared] groupedCommentHeightForText:caption width:tableView.bounds.size.width];
	return TGGroupedFooterHeight(caption, measured);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	return [[TGTheme shared] groupedCommentViewWithText:caption width:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 0) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"value"];
		if (!cell)
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
										  reuseIdentifier:@"value"];
		[[TGTheme shared] styleCell:cell];
		NSString *value = [self values][indexPath.row];
		cell.textLabel.text = [self titleForValue:value];
		cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
		cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
		BOOL chosen = [value isEqualToString:self.value];
		cell.textLabel.textColor = chosen ? [[TGTheme shared] groupedInfoColour]
										  : [[TGTheme shared] groupedTitleColour];
		cell.accessoryType = chosen
			? UITableViewCellAccessoryCheckmark
			: UITableViewCellAccessoryNone;
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		return cell;
	}

	TGPrivacyExceptionRowKind kind = [self exceptionRowKindAt:indexPath.row];
	if (kind == TGPrivacyExceptionRowBots || kind == TGPrivacyExceptionRowPremium) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"toggle"];
		if (!cell)
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
										  reuseIdentifier:@"toggle"];
		[[TGTheme shared] styleCell:cell];
		cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
		cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
		cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		UISwitch *toggle = [[UISwitch alloc] init];
		if (kind == TGPrivacyExceptionRowBots) {
			BOOL everybody = [self.value isEqualToString:@"everybody"];
			cell.textLabel.text = everybody ? TGL(@"Privacy.ExcludeBots", @"Exclude Bots") : TGL(@"Privacy.IncludeBots", @"Include Bots");
			toggle.on = everybody ? self.restrictBots : self.allowBots;
			toggle.tag = 1;
		} else {
			cell.textLabel.text = TGL(@"Privacy.IncludePremiumUsers", @"Include Premium Users");
			toggle.on = self.allowPremiumUsers;
			toggle.tag = 2;
		}
		[toggle addTarget:self action:@selector(exceptionToggleChanged:)
			forControlEvents:UIControlEventValueChanged];
		cell.accessoryView = toggle;
		return cell;
	}

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"exception"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:@"exception"];
	[[TGTheme shared] styleCell:cell];
	BOOL allowedRow = [self isAllowedRowAt:indexPath];
	NSArray *list = allowedRow ? self.allowedUsers : self.restrictedUsers;
	cell.textLabel.text = allowedRow ? TGL(@"PrivacyLastSeenSettings.AlwaysShareWith", @"Always Share With") : TGL(@"PrivacyLastSeenSettings.NeverShareWith", @"Never Share With");
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	if (!list.count)
		cell.detailTextLabel.text = TGL(@"PrivacyLastSeenSettings.EmpryUsersPlaceholder", @"Add Users");
	else
		cell.detailTextLabel.text = TGLPlural(@"UserCount", (NSInteger)list.count, @"1 user", @"%d users");
	cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	return cell;
}

- (TGPrivacyExceptionRowKind)exceptionRowKindAt:(NSInteger)row {
	NSInteger idx = 0;
	if ([self showsAllowedRow]) {
		if (row == idx)
			return TGPrivacyExceptionRowAllowed;
		idx++;
	}
	if ([self showsRestrictedRow]) {
		if (row == idx)
			return TGPrivacyExceptionRowRestricted;
		idx++;
	}
	if ([self showsBotsRow]) {
		if (row == idx)
			return TGPrivacyExceptionRowBots;
		idx++;
	}
	if ([self showsPremiumRow]) {
		if (row == idx)
			return TGPrivacyExceptionRowPremium;
		idx++;
	}
	return TGPrivacyExceptionRowNone;
}

- (BOOL)isAllowedRowAt:(NSIndexPath *)indexPath {
	return [self exceptionRowKindAt:indexPath.row] == TGPrivacyExceptionRowAllowed;
}

- (void)saveExceptionsAllowed:(NSArray *)allowed restricted:(NSArray *)restricted {
	NSArray *previousAllowed = self.allowedUsers;
	NSArray *previousRestricted = self.restrictedUsers;
	self.allowedUsers = allowed;
	self.restrictedUsers = restricted;
	[self.tableView reloadData];

	BOOL effectiveAllowBots = NO;
	BOOL effectiveRestrictBots = NO;
	TGPrivacyEffectiveBotsFlags(self.value, self.allowBots, self.restrictBots,
		&effectiveAllowBots, &effectiveRestrictBots);

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setPrivacyRule:self.setting
								   to:self.value
						 allowedUsers:allowed
					  restrictedUsers:restricted
						 allowedChats:self.allowedChats
					  restrictedChats:self.restrictedChats
							allowBots:effectiveAllowBots
						 restrictBots:effectiveRestrictBots
					allowPremiumUsers:self.allowPremiumUsers
						   completion:^(BOOL ok) {
							   __strong typeof(weakSelf) strongSelf = weakSelf;
							   if (ok || !strongSelf)
								   return;
							   strongSelf.allowedUsers = previousAllowed;
							   strongSelf.restrictedUsers = previousRestricted;
							   [strongSelf.tableView reloadData];
							   TGPrivacyComplain(TGL(@"Privacy.TheExceptionsCouldNotBeSaved", @"Those exceptions could not be saved."));
						   }];
}

- (void)exceptionToggleChanged:(UISwitch *)toggle {
	BOOL previousBots = self.allowBots;
	BOOL previousRestrictBots = self.restrictBots;
	BOOL previousPremium = self.allowPremiumUsers;

	if (toggle.tag == 1) {
		if ([self.value isEqualToString:@"everybody"])
			self.restrictBots = toggle.on;
		else
			self.allowBots = toggle.on;
	} else if (toggle.tag == 2) {
		self.allowPremiumUsers = toggle.on;
	}

	BOOL effectiveAllowBots = NO;
	BOOL effectiveRestrictBots = NO;
	TGPrivacyEffectiveBotsFlags(self.value, self.allowBots, self.restrictBots,
		&effectiveAllowBots, &effectiveRestrictBots);

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setPrivacyRule:self.setting
								   to:self.value
						 allowedUsers:self.allowedUsers
					  restrictedUsers:self.restrictedUsers
						 allowedChats:self.allowedChats
					  restrictedChats:self.restrictedChats
							allowBots:effectiveAllowBots
						 restrictBots:effectiveRestrictBots
					allowPremiumUsers:self.allowPremiumUsers
						   completion:^(BOOL ok) {
							   __strong typeof(weakSelf) strongSelf = weakSelf;
							   if (ok || !strongSelf)
								   return;
							   strongSelf.allowBots = previousBots;
							   strongSelf.restrictBots = previousRestrictBots;
							   strongSelf.allowPremiumUsers = previousPremium;
							   [strongSelf.tableView reloadData];
							   TGPrivacyComplain(TGL(@"Privacy.TheSettingCouldNotBeChanged", @"That setting could not be changed."));
						   }];
}

- (void)editExceptionsAllowed:(BOOL)allowed {
	__weak typeof(self) weakSelf = self;
	NSArray *current = allowed ? self.allowedUsers : self.restrictedUsers;
	NSString *title = allowed
		? TGL(@"PrivacyLastSeenSettings.AlwaysShareWith", @"Always Share With")
		: TGL(@"PrivacyLastSeenSettings.NeverShareWith", @"Never Share With");
	TGPrivacyContactPickerViewController *picker =
		[[TGPrivacyContactPickerViewController alloc]
			initWithTitle:title
				 selected:current
			   completion:^(NSArray *userIds) {
				   __strong typeof(weakSelf) strongSelf = weakSelf;
				   if (!strongSelf)
					   return;
				   if (allowed) {
					   NSArray *restricted = TGPrivacyExceptionListRemoving(strongSelf.restrictedUsers, userIds);
					   [strongSelf saveExceptionsAllowed:userIds restricted:restricted];
				   } else {
					   NSArray *stillAllowed = TGPrivacyExceptionListRemoving(strongSelf.allowedUsers, userIds);
					   [strongSelf saveExceptionsAllowed:stillAllowed restricted:userIds];
				   }
			   }];
	[self.navigationController pushViewController:picker animated:YES];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (!self.loaded)
		return;
	if (indexPath.section == 1) {
		TGPrivacyExceptionRowKind kind = [self exceptionRowKindAt:indexPath.row];
		if (kind == TGPrivacyExceptionRowAllowed || kind == TGPrivacyExceptionRowRestricted)
			[self editExceptionsAllowed:(kind == TGPrivacyExceptionRowAllowed)];
		return;
	}

	NSString *picked = [self values][indexPath.row];
	if ([picked isEqualToString:self.value])
		return;

	NSString *previous = self.value;
	self.value = picked;
	[tableView reloadData];

	BOOL effectiveAllowBots = NO;
	BOOL effectiveRestrictBots = NO;
	TGPrivacyEffectiveBotsFlags(picked, self.allowBots, self.restrictBots,
		&effectiveAllowBots, &effectiveRestrictBots);
	self.allowBots = effectiveAllowBots;
	self.restrictBots = effectiveRestrictBots;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setPrivacyRule:self.setting
								   to:picked
						 allowedUsers:self.allowedUsers
					  restrictedUsers:self.restrictedUsers
						 allowedChats:self.allowedChats
					  restrictedChats:self.restrictedChats
							allowBots:effectiveAllowBots
						 restrictBots:effectiveRestrictBots
					allowPremiumUsers:self.allowPremiumUsers
						   completion:^(BOOL ok) {
							   __strong typeof(weakSelf) strongSelf = weakSelf;
							   if (ok || !strongSelf)
								   return;
							   strongSelf.value = previous;
							   [strongSelf.tableView reloadData];
							   TGPrivacyComplain(TGL(@"Privacy.TheSettingCouldNotBeChanged", @"That setting could not be changed."));
						   }];
}

@end

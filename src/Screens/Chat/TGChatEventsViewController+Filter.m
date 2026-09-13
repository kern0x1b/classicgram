#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGChatEventsViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGClient.h"
#import "TGClient+ChatManagement.h"
#import "TGClient+Messages.h"
#import "TGChatViewController.h"
#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGDateUtils.h"
#import "UIView+SafeTint.h"
#import "TGHexColour.h"

static NSArray *TGEventsAllFilters(void) {
	static NSArray *filters = nil;
	if (!filters) {
		filters = [NSArray arrayWithObjects:
				@"messageEdits", @"messageDeletions", @"messagePins",
			@"memberJoins", @"memberLeaves", @"memberInvites",
			@"memberPromotions", @"memberRestrictions", @"memberTagChanges",
			@"infoChanges", @"settingChanges", @"inviteLinkChanges",
			@"videoChatChanges", @"forumChanges", @"subscriptionExtensions", nil];
	}
	return filters;
}

static NSDictionary *TGEventsCategory(NSString *title, NSArray *filters) {
	return [NSDictionary dictionaryWithObjectsAndKeys:
			title, @"title", filters, @"filters", nil];
}

static NSArray *TGEventsMainCategories(void) {
	static NSArray *categories = nil;
	if (!categories) {
		categories = [NSArray arrayWithObjects:
				TGEventsCategory(TGL(@"Channel.AdminLogFilter.EventsRestrictions",
									 @"New Restrictions"),
								  @[ @"memberRestrictions" ]),
			TGEventsCategory(TGL(@"Channel.AdminLogFilter.EventsAdmins", @"New Admins"),
							  @[ @"memberPromotions" ]),
			TGEventsCategory(TGL(@"Channel.AdminLogFilter.EventsNewMembers", @"New Members"),
							  @[ @"memberJoins", @"memberInvites" ]),
			TGEventsCategory(TGL(@"Channel.AdminLogFilter.EventsLeaving", @"Members Removed"),
							  @[ @"memberLeaves" ]),
			TGEventsCategory(TGL(@"Channel.AdminLogFilter.EventsInfo", @"Group Info"),
							  @[ @"infoChanges", @"settingChanges" ]),
			TGEventsCategory(TGL(@"Channel.AdminLogFilter.EventsDeletedMessages",
								 @"Deleted Messages"),
							  @[ @"messageDeletions" ]),
			TGEventsCategory(TGL(@"Channel.AdminLogFilter.EventsEditedMessages",
								 @"Edited Messages"),
							  @[ @"messageEdits" ]),
			TGEventsCategory(TGL(@"Channel.AdminLogFilter.EventsPinned", @"Pinned messages"),
							  @[ @"messagePins" ]),
			nil];
	}
	return categories;
}

static NSArray *TGEventsOtherCategories(void) {
	static NSArray *categories = nil;
	if (!categories) {
		categories = [NSArray arrayWithObjects:
				TGEventsCategory(TGL(@"Channel.AdminLogFilter.EventsInviteLinks", @"Invite Links"),
								  @[ @"inviteLinkChanges" ]),
			TGEventsCategory(TGL(@"Channel.AdminLogFilter.EventsCalls", @"Voice Chats"),
							  @[ @"videoChatChanges" ]),
			TGEventsCategory(TGL(@"ChatEvents.CategoryTopics", @"Topics"),
							  @[ @"forumChanges" ]),
			TGEventsCategory(TGL(@"ChatEvents.CategoryMemberTags", @"Member Tags"),
							  @[ @"memberTagChanges" ]),
			TGEventsCategory(TGL(@"ChatEvents.CategorySubscriptions", @"Subscriptions"),
							  @[ @"subscriptionExtensions" ]),
			nil];
	}
	return categories;
}

typedef NS_ENUM(NSInteger, TGEventsFilterPage) {
	TGEventsFilterPageMain = 0,
	TGEventsFilterPageOther = 1
};

@interface TGChatEventsFilterController : UITableViewController

@property (nonatomic, strong) NSMutableArray *selection;
@property (nonatomic, strong) NSArray *administrators;
@property (nonatomic, strong) NSMutableArray *userSelection;
@property (nonatomic, assign) TGEventsFilterPage page;
@property (nonatomic, strong) UIButton *doneButton;
@property (nonatomic, copy) void (^completion)(NSArray *filters, NSArray *userIds);

- (instancetype)initWithFilters:(NSArray *)filters
				 administrators:(NSArray *)administrators
						userIds:(NSArray *)userIds;

@end

@implementation TGChatEventsFilterController

- (instancetype)initWithFilters:(NSArray *)filters
				 administrators:(NSArray *)administrators
						userIds:(NSArray *)userIds {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		_selection = filters.count ? [NSMutableArray arrayWithArray:filters]
								   : [NSMutableArray arrayWithArray:TGEventsAllFilters()];
		_administrators = [administrators isKindOfClass:[NSArray class]]
			? administrators
			: [NSArray array];
		_userSelection = userIds.count ? [NSMutableArray arrayWithArray:userIds]
									   : [NSMutableArray array];
		if (!_userSelection.count) {
			for (NSDictionary *admin in _administrators) {
				NSNumber *userId = TGEventsNumber(admin, @"userId");
				if (userId)
					[_userSelection addObject:userId];
			}
		}
	}
	return self;
}

- (instancetype)initWithSelection:(NSMutableArray *)selection page:(TGEventsFilterPage)page {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		_selection = selection;
		_administrators = [NSArray array];
		_userSelection = [NSMutableArray array];
		_page = page;
	}
	return self;
}

- (NSArray *)categories {
	return self.page == TGEventsFilterPageOther ? TGEventsOtherCategories()
												: TGEventsMainCategories();
}

- (BOOL)isCategorySelected:(NSDictionary *)category {
	NSArray *filters = category[@"filters"];
	for (NSString *filter in filters) {
		if (![self.selection containsObject:filter])
			return NO;
	}
	return filters.count != 0;
}

- (void)setCategory:(NSDictionary *)category selected:(BOOL)selected {
	for (NSString *filter in category[@"filters"]) {
		if (selected) {
			if (![self.selection containsObject:filter])
				[self.selection addObject:filter];
		} else {
			[self.selection removeObject:filter];
		}
	}
}

- (NSInteger)selectedOtherCount {
	NSInteger count = 0;
	for (NSDictionary *category in TGEventsOtherCategories()) {
		if ([self isCategorySelected:category])
			count++;
	}
	return count;
}

- (BOOL)allActionsSelected {
	return self.selection.count == TGEventsAllFilters().count;
}

- (NSDictionary *)adminAtRow:(NSInteger)row {
	if (row < 1 || row - 1 >= (NSInteger)self.administrators.count)
		return nil;
	NSDictionary *admin = self.administrators[row - 1];
	return [admin isKindOfClass:[NSDictionary class]] ? admin : nil;
}

- (NSNumber *)userIdAtRow:(NSInteger)row {
	return TGEventsNumber([self adminAtRow:row], @"userId");
}

- (NSString *)adminNameAtRow:(NSInteger)row {
	NSString *name = TGEventsText([self adminAtRow:row], @"name");
	return name.length ? name : TGL(@"ChatEvents.UnknownAdminName", @"Admin");
}

- (NSString *)adminStatusAtRow:(NSInteger)row {
	NSDictionary *admin = [self adminAtRow:row];
	if (!admin)
		return TGL(@"GroupInfo.LabelAdmin", @"admin");
	NSString *custom = TGEventsText(admin, @"customTitle");
	if (custom.length)
		return custom;
	return [TGEventsNumber(admin, @"isOwner") boolValue]
		? TGL(@"GroupInfo.LabelOwner", @"owner")
		: TGL(@"GroupInfo.LabelAdmin", @"admin");
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	self.tableView.rowHeight = 44;

	if (self.page == TGEventsFilterPageOther) {
		self.title = TGL(@"ChatEvents.OtherActions", @"Other Actions");
		return;
	}

	self.title = TGL(@"Channel.AdminLogFilter.Title", @"Filter");
	UIButton *cancel = [TGIcons headerButtonWithTitle:TGL(@"Common.Cancel", @"Cancel") bold:NO
											   target:self
											   action:@selector(cancelPressed)];
	self.doneButton = [TGIcons headerButtonWithTitle:TGL(@"Common.Done", @"Done") bold:YES
											  target:self
											  action:@selector(donePressed)];
	self.navigationItem.leftBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:cancel];
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:self.doneButton];
	[self updateDone];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	if (self.page == TGEventsFilterPageMain) {
		[self updateDone];
		[self.tableView reloadData];
	}
}

- (void)updateDone {
	if (!self.doneButton)
		return;
	BOOL enabled = self.selection.count != 0 && (self.administrators.count == 0 || self.userSelection.count != 0);
	self.doneButton.enabled = enabled;
	self.doneButton.alpha = enabled ? 1.0f : 0.4f;
}

- (void)cancelPressed {
	[self dismissModalViewControllerAnimated:YES];
}

- (void)donePressed {
	if (!self.selection.count)
		return;
	if (self.administrators.count && !self.userSelection.count)
		return;
	NSArray *result = nil;
	if (self.selection.count < TGEventsAllFilters().count)
		result = [NSArray arrayWithArray:self.selection];
	NSArray *users = nil;
	if (self.administrators.count && self.userSelection.count && self.userSelection.count < self.administrators.count)
		users = [NSArray arrayWithArray:self.userSelection];
	if (self.completion)
		self.completion(result, users);
	[self dismissModalViewControllerAnimated:YES];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if (self.page == TGEventsFilterPageOther)
		return 1;
	return self.administrators.count ? 3 : 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (self.page == TGEventsFilterPageOther)
		return (NSInteger)[self categories].count;
	if (section == 0)
		return 1;
	if (section == 1)
		return (NSInteger)[self categories].count + 1;
	return (NSInteger)self.administrators.count + 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (self.page == TGEventsFilterPageOther)
		return nil;
	return section == 2 ? TGL(@"Channel.AdminLogFilter.AdminsTitle", @"ADMINS") : nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderHeightForTitle:title];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (self.page == TGEventsFilterPageOther)
		return TGL(@"ChatEvents.RarerActionsFooter",
				   @"Actions of these kinds are rarer, so they are kept on a screen of their own."
					"own.");
	if (section == 1)
		return TGL(@"ChatEvents.OnlySelectedKindsListed",
				   @"Only the selected kinds of action are listed.");
	if (section == 2)
		return TGL(@"ChatEvents.OnlySelectedAdminsListed",
				   @"Only actions taken by the selected admins are listed.");
	return nil;
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

- (UIView *)checkAccessory {
	UIImage *art = [UIImage imageNamed:@"ListCheck.png"];
	if (!art) {
		UILabel *mark = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 14, 20)];
		mark.backgroundColor = [UIColor clearColor];
		mark.font = [UIFont boldSystemFontOfSize:16];
		mark.textColor = TGColourFromHex(0x0779d0);
		mark.text = @"✓";
		return mark;
	}
	UIImage *highlighted = [UIImage imageNamed:@"ListCheck_Highlighted.png"];
	UIImageView *view = [UIImageView alloc];
	view = [view initWithImage:art
			  highlightedImage:highlighted];
	view.frame = CGRectMake(0, 0, art.size.width, art.size.height);
	return view;
}

- (UIView *)disclosureAccessory {
	UIImage *art = TGLocalizedDirectionalImage([UIImage imageNamed:@"MenuDisclosureIndicator.png"]);
	if (!art)
		return nil;
	UIImage *highlighted = [UIImage imageNamed:@"MenuDisclosureIndicator_Highlighted.png"];
	UIImageView *view = [UIImageView alloc];
	view = [view initWithImage:art
			  highlightedImage:highlighted];
	view.frame = CGRectMake(0, 0, art.size.width, art.size.height);
	return view;
}

- (void)mark:(BOOL)checked on:(UITableViewCell *)cell {
	if (!checked) {
		cell.accessoryView = nil;
		cell.accessoryType = UITableViewCellAccessoryNone;
		return;
	}
	UIView *check = [self checkAccessory];
	if (check) {
		cell.accessoryView = check;
		cell.accessoryType = UITableViewCellAccessoryNone;
	} else {
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	}
}

- (UITableViewCell *)cellWithIdentifier:(NSString *)identifier
								  style:(UITableViewCellStyle)style
							  tableView:(UITableView *)tableView {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:identifier];
	[[TGTheme shared] styleCell:cell];
	cell.accessoryView = nil;
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	return cell;
}

- (UITableViewCell *)switchCellWithTitle:(NSString *)title on:(BOOL)on
								  action:(SEL)action
							   tableView:(UITableView *)tableView {
	UITableViewCell *cell = [self cellWithIdentifier:@"switch"
											   style:UITableViewCellStyleDefault
										   tableView:tableView];
	cell.textLabel.text = title;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;

	UISwitch *toggle = [[UISwitch alloc] init];
	toggle.on = on;
	[toggle addTarget:self action:action forControlEvents:UIControlEventValueChanged];
	cell.accessoryView = toggle;
	return cell;
}

- (UITableViewCell *)categoryCell:(NSDictionary *)category tableView:(UITableView *)tableView {
	UITableViewCell *cell = [self cellWithIdentifier:@"check"
											   style:UITableViewCellStyleDefault
										   tableView:tableView];
	cell.textLabel.text = category[@"title"];
	[self mark:[self isCategorySelected:category] on:cell];
	return cell;
}

- (UITableViewCell *)otherActionsCellForTableView:(UITableView *)tableView {
	UITableViewCell *cell = [self cellWithIdentifier:@"variant"
											   style:UITableViewCellStyleValue1
										   tableView:tableView];
	cell.textLabel.text = TGL(@"ChatEvents.OtherActions", @"Other Actions");
	cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	cell.detailTextLabel.text = [NSString stringWithFormat:@"%d / %d",
		(int)[self selectedOtherCount], (int)TGEventsOtherCategories().count];
	UIView *chevron = [self disclosureAccessory];
	if (chevron)
		cell.accessoryView = chevron;
	else
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	return cell;
}

- (UITableViewCell *)adminCellAtRow:(NSInteger)row tableView:(UITableView *)tableView {
	UITableViewCell *cell = [self cellWithIdentifier:@"admin"
											   style:UITableViewCellStyleSubtitle
										   tableView:tableView];
	cell.textLabel.text = [self adminNameAtRow:row];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	cell.detailTextLabel.text = [self adminStatusAtRow:row];
	NSNumber *userId = [self userIdAtRow:row];
	[self mark:userId != nil && [self.userSelection containsObject:userId] on:cell];
	return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSArray *categories = [self categories];

	if (self.page == TGEventsFilterPageOther)
		return [self categoryCell:categories[indexPath.row] tableView:tableView];

	if (indexPath.section == 0) {
		return [self switchCellWithTitle:TGL(@"Channel.AdminLog.TitleAllEvents", @"All Actions") on:[self allActionsSelected]
								  action:@selector(allActionsToggled:)
							   tableView:tableView];
	}

	if (indexPath.section == 1) {
		if (indexPath.row == (NSInteger)categories.count)
			return [self otherActionsCellForTableView:tableView];
		return [self categoryCell:categories[indexPath.row] tableView:tableView];
	}

	if (indexPath.row == 0) {
		return [self switchCellWithTitle:TGL(@"Channel.AdminLogFilter.AdminsAll", @"All Admins")
									  on:self.userSelection.count == self.administrators.count
								  action:@selector(allAdminsToggled:)
							   tableView:tableView];
	}

	return [self adminCellAtRow:indexPath.row tableView:tableView];
}

- (void)allActionsToggled:(UISwitch *)toggle {
	[self.selection removeAllObjects];
	if (toggle.on)
		[self.selection addObjectsFromArray:TGEventsAllFilters()];
	[self updateDone];
	[self.tableView reloadData];
}

- (void)allAdminsToggled:(UISwitch *)toggle {
	[self.userSelection removeAllObjects];
	if (toggle.on) {
		for (NSDictionary *admin in self.administrators) {
			NSNumber *userId = TGEventsNumber(admin, @"userId");
			if (userId)
				[self.userSelection addObject:userId];
		}
	}
	[self updateDone];
	[self.tableView reloadData];
}

- (void)openOtherActions {
	TGChatEventsFilterController *controller = [[TGChatEventsFilterController alloc]
		initWithSelection:self.selection
					 page:TGEventsFilterPageOther];
	[self.navigationController pushViewController:controller animated:YES];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	NSArray *categories = [self categories];

	if (self.page == TGEventsFilterPageOther) {
		NSDictionary *category = categories[indexPath.row];
		[self setCategory:category selected:![self isCategorySelected:category]];
		[tableView reloadData];
		return;
	}

	if (indexPath.section == 0)
		return;

	if (indexPath.section == 1) {
		if (indexPath.row == (NSInteger)categories.count) {
			[self openOtherActions];
			return;
		}
		NSDictionary *category = categories[indexPath.row];
		[self setCategory:category selected:![self isCategorySelected:category]];
		[self updateDone];
		[tableView reloadData];
		return;
	}

	if (indexPath.row == 0)
		return;

	NSNumber *userId = [self userIdAtRow:indexPath.row];
	if (!userId)
		return;
	if ([self.userSelection containsObject:userId])
		[self.userSelection removeObject:userId];
	else
		[self.userSelection addObject:userId];
	[self updateDone];
	[tableView reloadData];
}

@end

@implementation TGChatEventsViewController (Filter)

- (void)filterPressed {
	TGChatEventsFilterController *controller = [[TGChatEventsFilterController alloc]
		initWithFilters:self.filters
		 administrators:self.administrators
				userIds:self.userIds];
	__weak typeof(self) weakSelf = self;
	controller.completion = ^(NSArray *filters, NSArray *userIds) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.filters = filters;
		strongSelf.userIds = userIds;
		[strongSelf reload];
	};

	UINavigationController *navigation =
		[[UINavigationController alloc] initWithRootViewController:controller];
	[[TGTheme shared] styleNavigationBar:navigation.navigationBar];
	if ([self respondsToSelector:@selector(presentViewController:animated:completion:)])
		[self presentViewController:navigation animated:YES completion:nil];
	else
		[self presentModalViewController:navigation animated:YES];
}

@end

#import "TGGroupAddMembersViewController.h"
#import "TGMemberPickerStatusText.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGClient+Groups.h"
#import "TGClient+Contacts.h"
#import "TGClient+Messages.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGPopupMenu.h"
#import "TGAlertView.h"
#import "TGImageDecode.h"
#import "UIView+SafeTint.h"
#import <QuartzCore/QuartzCore.h>
#import "TGGroupMembersViewControllerInternal.h"
#import "TGGroupInviteLinkOffer.h"

@implementation TGGroupAddMembersViewController

- (id)initWithChatId:(int64_t)chatId {
	self = [super initWithStyle:UITableViewStylePlain];
	if (!self)
		return nil;
	_chatId = chatId;
	self.picked = [NSMutableArray array];
	self.pickedNames = [NSMutableDictionary dictionary];
	self.users = [NSArray array];
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];

	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	self.title = TGL(@"Group.Members.AddMembers", @"Add Members");
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	self.tableView.rowHeight = 44;
	self.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tableView.separatorColor = [[TGTheme shared] separatorColour];

	self.searchBar = [[UISearchBar alloc] initWithFrame:
			CGRectMake(0, 0, self.view.bounds.size.width, 44)];
	self.searchBar.delegate = self;
	self.searchBar.placeholder = TGL(@"Common.Search", @"Search");
	self.tableView.tableHeaderView = self.searchBar;

	UIView *background = [[UIView alloc] initWithFrame:self.tableView.bounds];
	background.backgroundColor = [[TGTheme shared] listBackgroundColour];
	background.autoresizingMask =
		UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

	self.statusLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(0, 110, background.bounds.size.width, 22)];
	self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.statusLabel.backgroundColor = [UIColor clearColor];
	self.statusLabel.textAlignment = NSTextAlignmentCenter;
	self.statusLabel.font = [UIFont systemFontOfSize:15];
	self.statusLabel.textColor = [[TGTheme shared] secondaryTextColour];
	self.statusLabel.hidden = YES;
	[background addSubview:self.statusLabel];

	self.spinner = [[UIActivityIndicatorView alloc]
		initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	self.spinner.center = CGPointMake(background.bounds.size.width / 2, 84);
	self.spinner.autoresizingMask =
		UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	self.spinner.hidesWhenStopped = YES;
	[background addSubview:self.spinner];
	self.tableView.backgroundView = background;

	self.navigationItem.rightBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"Contacts.AddContact", @"Add") bold:NO
									   target:self
									   action:@selector(addPicked)];
	[self updateDoneButton];
	[self runSearchWithQuery:@""];
}

- (void)updateDoneButton {
	self.navigationItem.rightBarButtonItem.enabled = self.picked.count != 0 && !self.adding;
}

- (void)runSearchWithQuery:(NSString *)query {
	self.generation++;
	NSInteger generation = self.generation;
	[self.spinner startAnimating];
	self.statusLabel.hidden = YES;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] searchContacts:query ?: @"" limit:kMemberPageSize
						   completion:^(NSArray *users, BOOL failed) {
							   TGGroupAddMembersViewController *strongSelf = weakSelf;
							   if (!strongSelf || strongSelf.generation != generation)
								   return;
							   [strongSelf.spinner stopAnimating];
							   strongSelf.users = [users isKindOfClass:NSArray.class] ? users : [NSArray array];
							   [strongSelf.tableView reloadData];
							   strongSelf.statusLabel.text =
									   TGMemberPickerStatusText(failed, strongSelf.users.count);
							   strongSelf.statusLabel.hidden = strongSelf.statusLabel.text.length == 0;
						   }];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)text {
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(runDelayedSearch)
											   object:nil];
	[self performSelector:@selector(runDelayedSearch) withObject:nil afterDelay:0.3f];
}

- (void)runDelayedSearch {
	[self runSearchWithQuery:self.searchBar.text ?: @""];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
}

- (NSDictionary *)userAtRow:(NSInteger)row {
	if (row < 0 || row >= (NSInteger)self.users.count)
		return nil;
	NSDictionary *user = [self.users objectAtIndex:(NSUInteger)row];
	return [user isKindOfClass:NSDictionary.class] ? user : nil;
}

- (NSString *)nameOfUser:(NSDictionary *)user {
	NSString *first = TGMembersString(user, @"first_name");
	NSString *last = TGMembersString(user, @"last_name");
	NSString *name = last.length
		? (first.length ? [NSString stringWithFormat:@"%@ %@", first, last] : last)
		: first;
	if (!name.length)
		name = TGMembersString(user, @"username");
	return name.length ? name : TGL(@"Contacts.UnknownName", @"Unknown");
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.users.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *reuse = @"TGGroupAddMemberCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:reuse];
		cell.textLabel.font = [UIFont systemFontOfSize:17];
		cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
	}
	NSDictionary *user = [self userAtRow:indexPath.row];
	cell.textLabel.text = user ? [self nameOfUser:user] : @"";
	cell.textLabel.textColor = [[TGTheme shared] primaryTextColour];
	NSString *username = user ? TGMembersString(user, @"username") : @"";
	cell.detailTextLabel.text = username.length
		? [NSString stringWithFormat:@"@%@", username]
		: @"";
	int64_t userId = user ? TGMembersUserId(user) : 0;
	BOOL on = userId != 0 && [self.picked containsObject:[NSNumber numberWithLongLong:userId]];
	cell.accessoryType = on ? UITableViewCellAccessoryCheckmark
							: UITableViewCellAccessoryNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSDictionary *user = [self userAtRow:indexPath.row];
	int64_t userId = user ? TGMembersUserId(user) : 0;
	if (userId == 0)
		return;
	NSNumber *key = [NSNumber numberWithLongLong:userId];
	if ([self.picked containsObject:key]) {
		[self.picked removeObject:key];
		[self.pickedNames removeObjectForKey:key];
	} else {
		[self.picked addObject:key];
		[self.pickedNames setObject:[self nameOfUser:user] forKey:key];
	}
	[tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
					 withRowAnimation:UITableViewRowAnimationNone];
	[self updateDoneButton];
}

- (void)addPicked {
	if (self.adding || self.picked.count == 0)
		return;
	self.adding = YES;
	[self updateDoneButton];
	[self.searchBar resignFirstResponder];

	NSArray *ids = [self.picked copy];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] addMembers:ids toGroup:_chatId completion:^(NSArray *failedUserIds, NSString *errorMessage) {
		TGGroupAddMembersViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.adding = NO;
		[strongSelf updateDoneButton];

		if (errorMessage.length) {
			[[[TGAlertView alloc] initWithTitle:nil message:errorMessage cancelButtonTitle:TGL(@"Common.OK", @"OK")
										  okButtonTitle:nil
									completionBlock:nil] show];
			return;
		}
		NSArray *failed = [failedUserIds isKindOfClass:NSArray.class]
			? failedUserIds
			: [NSArray array];
		if (failed.count < ids.count && strongSelf.onAdded)
			strongSelf.onAdded();
		if (failed.count == 0) {
			[strongSelf.navigationController popViewControllerAnimated:YES];
			return;
		}
		TGOfferInviteLinkToRestrictedUsers(strongSelf, strongSelf->_chatId, failed, strongSelf.pickedNames, ^{
			TGGroupAddMembersViewController *innerSelf = weakSelf;
			if (!innerSelf)
				return;
			[innerSelf.navigationController popViewControllerAnimated:YES];
		});
	}];
}

@end

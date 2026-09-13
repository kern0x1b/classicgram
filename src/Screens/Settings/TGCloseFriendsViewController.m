#import "TGFormSaveState.h"
#import "TGGroupedCaption.h"
#import "TGCloseFriendsStatus.h"
#import "TGCloseFriendsViewController.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGContactsService.h"
#import "TGClient+Contacts.h"
#import "TGSnackbar.h"

@interface TGCloseFriendsViewController ()
@property (nonatomic, strong) NSArray *contacts;
@property (nonatomic, strong) NSMutableSet *chosen;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL loadFailed;
@property (nonatomic, strong) UIButton *saveButton;
@end

@implementation TGCloseFriendsViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStylePlain];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
	self.title = TGL(@"Story.Privacy.CategoryCloseFriends", @"Close Friends");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tableView.separatorColor = [[TGTheme shared] separatorColour];
	self.tableView.rowHeight = 44;
	self.chosen = [NSMutableSet set];

	UIButton *save = [TGIcons headerButtonWithTitle:TGL(@"Common.Done", @"Done") bold:YES
											 target:self
											 action:@selector(commit)];
	save.enabled = NO;
	self.saveButton = save;
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:save];
	[self reload];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)reload {
	__weak typeof(self) weakSelf = self;
	[TGContactsService contactsWithCompletion:^(NSArray *users) {
		TGCloseFriendsViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.contacts = [users isKindOfClass:NSArray.class] ? users : @[];
		[TGContactsService contactCloseFriendsWithCompletion:^(NSArray *close, BOOL failed) {
			TGCloseFriendsViewController *innerSelf = weakSelf;
			if (!innerSelf)
				return;
			innerSelf.loadFailed = failed;
			if (!failed) {
				[innerSelf.chosen removeAllObjects];
				for (NSDictionary *user in ([close isKindOfClass:NSArray.class] ? close : @[])) {
					NSNumber *userId = [user[@"id"] isKindOfClass:NSNumber.class] ? user[@"id"] : nil;
					if (userId)
						[innerSelf.chosen addObject:userId];
				}
			}
			innerSelf.loaded = YES;
			innerSelf.saveButton.enabled = TGFormCanSave(innerSelf.loaded, failed, NO);
			[innerSelf.tableView reloadData];
		}];
	}];
}

- (NSString *)nameOfUser:(NSDictionary *)user {
	NSString *first = [user[@"first_name"] isKindOfClass:NSString.class] ? user[@"first_name"] : @"";
	NSString *last = [user[@"last_name"] isKindOfClass:NSString.class] ? user[@"last_name"] : @"";
	NSString *name = [[NSString stringWithFormat:@"%@ %@", first, last]
		stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	return name.length ? name : TGL(@"User.DeletedAccount", @"Deleted Account");
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (!self.loaded || self.loadFailed)
		return 0;
	return (NSInteger)self.contacts.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	return TGCloseFriendsFooterText(self.loaded, self.loadFailed, self.chosen.count);
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	CGFloat measured = [[TGTheme shared] groupedCommentHeightForText:caption
															   width:tableView.bounds.size.width];
	return TGGroupedFooterHeight(caption, measured);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	if (!caption.length)
		return nil;
	return [[TGTheme shared] groupedCommentViewWithText:caption width:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"row"];
	[[TGTheme shared] styleCell:cell];
	NSDictionary *user = [self.contacts objectAtIndex:(NSUInteger)indexPath.row];
	cell.textLabel.text = [self nameOfUser:user];
	NSNumber *userId = [user[@"id"] isKindOfClass:NSNumber.class] ? user[@"id"] : nil;
	cell.accessoryType = (userId && [self.chosen containsObject:userId])
		? UITableViewCellAccessoryCheckmark
		: UITableViewCellAccessoryNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSDictionary *user = [self.contacts objectAtIndex:(NSUInteger)indexPath.row];
	NSNumber *userId = [user[@"id"] isKindOfClass:NSNumber.class] ? user[@"id"] : nil;
	if (!userId)
		return;
	if ([self.chosen containsObject:userId])
		[self.chosen removeObject:userId];
	else
		[self.chosen addObject:userId];
	[tableView reloadRowsAtIndexPaths:@[ indexPath ]
					 withRowAnimation:UITableViewRowAnimationNone];
}

- (void)commit {
	NSArray *ids = [self.chosen allObjects];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setCloseFriends:ids completion:^(BOOL ok) {
		TGCloseFriendsViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[TGSnackbar showInView:strongSelf.navigationController.view
							   text:TGL(@"Toast.CouldNotSaveCloseFriends", @"Could not save your Close Friends list")
							seconds:2
						   onCommit:nil];
			return;
		}
		[strongSelf.navigationController popViewControllerAnimated:YES];
	}];
}

@end

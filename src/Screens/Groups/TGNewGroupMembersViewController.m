#import "TGNewGroupMembersViewController.h"
#import "TGContactName.h"
#import "TGChatViewController.h"
#import "TGClient+Groups.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGAlertView.h"
#import "TGNewGroupMembersPresenter.h"
#import "TGNewGroupMembersRowBridge.h"
#import "TGGroupInviteLinkOffer.h"

@interface TGNewGroupMembersViewController ()
@property (nonatomic, strong) TGNewGroupMembersPresenter *rowPresenter;
@property (nonatomic, strong) TGNewGroupMembersRowBridge *rowBridge;
- (void)refreshRowPresenter;
@end

@implementation TGNewGroupMembersViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.title = TGL(@"Compose.NewGroup", @"New Group");
	self.selected = [NSMutableArray array];
	self.rowPresenter = [[TGNewGroupMembersPresenter alloc] init];
	self.rowBridge = [[TGNewGroupMembersRowBridge alloc] initWithPresenter:self.rowPresenter];
	[self refreshRowPresenter];
	self.tableView.rowHeight = kContactRowHeight;
	self.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tableView.separatorColor = [[TGTheme shared] separatorColour];
	self.nextButton = [UIButton buttonWithType:UIButtonTypeCustom];
	[TGIcons styleHeaderButton:self.nextButton];
	[self.nextButton addTarget:self action:@selector(nextTapped)
			  forControlEvents:UIControlEventTouchUpInside];
	self.nextLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.nextLabel.textColor = [UIColor whiteColor];
	self.nextLabel.textAlignment = NSTextAlignmentCenter;
	self.nextLabel.backgroundColor = [UIColor clearColor];
	self.nextLabel.font = [UIFont boldSystemFontOfSize:12];
	self.nextLabel.userInteractionEnabled = NO;
	[self.nextButton addSubview:self.nextLabel];
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:self.nextButton];
	[self updateNextButton];
}

- (void)refreshRowPresenter {
	NSMutableArray<NSString *> *titles = [NSMutableArray arrayWithCapacity:self.contacts.count];
	for (NSDictionary *user in self.contacts)
		[titles addObject:TGContactName(user)];
	[self.rowPresenter updateWithContacts:self.contacts titles:titles selected:self.selected];
}

- (void)updateNextButton {
	NSString *title = self.selected.count
		? [NSString stringWithFormat:TGL(@"NewGroupMembers.NextWithCount", @"Next (%d)"), (int)self.selected.count]
		: TGL(@"Common.Next", @"Next");
	self.nextLabel.text = title;
	CGSize size = [title sizeWithFont:self.nextLabel.font];
	self.nextButton.frame = CGRectMake(0, 0, size.width + 16, 30);
	self.nextLabel.frame = self.nextButton.bounds;
	self.nextButton.enabled = self.selected.count > 0;
	self.nextButton.alpha = self.selected.count ? 1.0f : 0.5f;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.contacts.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([self.rowBridge ownsRowAtIndex:indexPath.row])
		return [self.rowBridge cellForRow:indexPath.row inTable:tableView];

	static NSString *reuse = @"TGNewGroupMemberCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:reuse];
	if (indexPath.row >= (NSInteger)self.contacts.count)
		return cell;
	NSDictionary *u = self.contacts[indexPath.row];
	cell.textLabel.font = [UIFont systemFontOfSize:19];
	cell.textLabel.text = TGContactName(u);
	cell.backgroundColor = [[TGTheme shared] listBackgroundColour];
	NSNumber *userId = [u[@"id"] isKindOfClass:NSNumber.class] ? u[@"id"] : nil;
	cell.accessoryType = (userId && [self.selected containsObject:userId])
		? UITableViewCellAccessoryCheckmark
		: UITableViewCellAccessoryNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.row >= (NSInteger)self.contacts.count)
		return;
	NSDictionary *u = self.contacts[indexPath.row];
	NSNumber *userId = [u[@"id"] isKindOfClass:NSNumber.class] ? u[@"id"] : nil;
	if (!userId)
		return;
	if ([self.selected containsObject:userId])
		[self.selected removeObject:userId];
	else
		[self.selected addObject:userId];
	[self refreshRowPresenter];
	[tableView reloadRowsAtIndexPaths:@[ indexPath ]
					 withRowAnimation:UITableViewRowAnimationNone];
	[self updateNextButton];
}

- (void)nextTapped {
	if (!self.selected.count || self.creatingGroup)
		return;
	UIAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:TGL(@"Compose.NewGroup", @"New Group")
						 message:TGL(@"GroupInfo.GroupNamePlaceholder", @"Group name")
						delegate:self
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			   otherButtonTitles:TGL(@"Common.Create", @"Create"), nil];
	alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	[alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
	if (index == alertView.cancelButtonIndex)
		return;
	if (self.creatingGroup)
		return;
	NSString *title = [[alertView textFieldAtIndex:0].text
		stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!title.length)
		return;
	self.creatingGroup = YES;
	self.nextButton.enabled = NO;
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client createBasicGroupWithTitle:title
							  userIds:[self.selected copy]
						   completion:^(int64_t chatId, NSArray *failedUserIds) {
							   TGNewGroupMembersViewController *strongSelf = weakSelf;
							   if (!strongSelf)
								   return;
							   strongSelf.creatingGroup = NO;
							   strongSelf.nextButton.enabled = strongSelf.selected.count > 0;
							   if (chatId == 0) {
								   [[[UIAlertView alloc] initWithTitle:nil
																	message:TGL(@"NewGroupMembers.CouldNotCreateGroup", @"Could not create the group.")
																   delegate:nil
														  cancelButtonTitle:TGL(@"Common.OK", @"OK")
														  otherButtonTitles:nil] show];
								   return;
							   }
							   TGChatViewController *vc = [[TGChatViewController alloc] init];
							   vc.chatId = chatId;
							   vc.chatTitle = title;
							   NSMutableArray *stack = [strongSelf.navigationController.viewControllers mutableCopy];
							   [stack removeObject:strongSelf];
							   [stack addObject:vc];
							   [strongSelf.navigationController setViewControllers:stack animated:YES];

							   NSArray *failed = [failedUserIds isKindOfClass:NSArray.class]
								   ? failedUserIds
								   : [NSArray array];
							   if (failed.count == 0)
								   return;
							   NSMutableDictionary *names = [NSMutableDictionary dictionaryWithCapacity:failed.count];
							   for (NSDictionary *user in strongSelf.contacts) {
								   NSNumber *userId = [user[@"id"] isKindOfClass:NSNumber.class] ? user[@"id"] : nil;
								   if (userId)
									   [names setObject:TGContactName(user) forKey:userId];
							   }
							   TGOfferInviteLinkToRestrictedUsers(vc, chatId, failed, names, nil);
						   }];
}

@end

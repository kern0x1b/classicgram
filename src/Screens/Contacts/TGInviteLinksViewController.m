#import "TGListBackground.h"
#import "TGInviteLinksViewController.h"
#import "TGInviteLinksViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGInviteLinkService.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGClient.h"

@implementation TGInviteLinksViewController

- (instancetype)init {
	return [self initWithStyle:UITableViewStyleGrouped];
}

- (instancetype)initWithStyle:(__unused UITableViewStyle)style {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (instancetype)initWithChatId:(int64_t)chatId {
	self = [self init];
	if (self)
		_chatId = chatId;
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"GroupInfo.InviteLinks", @"Invite Links");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

	[self updateNewButton];
	[self rebuildSections];
	[self reload];

	__weak typeof(self) weakSelf = self;
	self.pendingJoinRequestsObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatPendingJoinRequestsDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					TGInviteLinksViewController *strongSelf = weakSelf;
					if (!strongSelf)
						return;
					if (![note.object isEqual:@(strongSelf.chatId)])
						return;
					[strongSelf reload];
				}];
}

- (void)dealloc {
	if (_pendingJoinRequestsObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_pendingJoinRequestsObserverToken];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	if (self.currentActionSheet) {
		TGActionSheet *sheet = self.currentActionSheet;
		[sheet dismissWithClickedButtonIndex:sheet.cancelButtonIndex animated:NO];
		self.currentActionSheet = nil;
	}
	if (self.createSheet) {
		[self.createSheet dismissWithClickedButtonIndex:self.createSheet.cancelButtonIndex
											   animated:NO];
		self.createSheet = nil;
	}
}

#pragma mark - loading

- (void)updateNewButton {
	if (!self.canManage) {
		self.navigationItem.rightBarButtonItem = nil;
		return;
	}
	if (self.navigationItem.rightBarButtonItem)
		return;
	UIButton *button = [TGIcons headerButtonWithTitle:TGL(@"ChatList.ContextMenuBadgeNew", @"New") bold:NO
											   target:self
											   action:@selector(createLink)];
	if (button)
		self.navigationItem.rightBarButtonItem =
			[[UIBarButtonItem alloc] initWithCustomView:button];
}

- (void)stepFinishedWithFailure:(BOOL)failure {
	if (failure)
		self.failed = YES;
	if (self.outstanding > 0)
		self.outstanding -= 1;
	if (self.outstanding > 0)
		return;
	self.loaded = YES;
	[self rebuildSections];
	[self.tableView reloadData];
}

- (NSArray *)secondaryLinksFrom:(NSArray *)links {
	NSMutableArray *result = [NSMutableArray array];
	for (NSDictionary *link in links) {
		if (![link isKindOfClass:[NSDictionary class]])
			continue;
		if ([link[@"isPrimary"] boolValue])
			continue;
		[result addObject:link];
	}
	return result;
}

@end

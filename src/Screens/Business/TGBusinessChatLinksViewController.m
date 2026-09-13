#import "TGBusinessChatLinksViewController.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGBusinessService.h"
#import "TGBusinessChatLinkEditViewController.h"
#import "TGTheme.h"
#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "TGSnackbar.h"

static const NSInteger kLinkLimitFallback = 5;

@interface TGBusinessChatLinksViewController ()

@property (nonatomic, strong) NSArray *links;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL deleting;
@property (nonatomic, assign) NSInteger linkLimit;
@property (nonatomic, strong) UILabel *emptyLabel;

@end

@implementation TGBusinessChatLinksViewController

- (instancetype)init {
	self = [super initWithStyle:UITableViewStylePlain];
	if (self) {
		self.title = TGL(@"Business.Links", @"Chat Links");
		_links = @[];
		_linkLimit = kLinkLimitFallback;
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.navigationItem.rightBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"Common.Add", @"Add") bold:NO
									   target:self
									   action:@selector(createLink)];

	self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.emptyLabel.backgroundColor = [UIColor clearColor];
	self.emptyLabel.font = [UIFont systemFontOfSize:15];
	self.emptyLabel.textColor = [[TGTheme shared] secondaryTextColour];
	self.emptyLabel.textAlignment = NSTextAlignmentCenter;
	self.emptyLabel.numberOfLines = 0;
	self.emptyLabel.text = TGL(@"Business.LinksInfo", @"Create a link with a preset message. When someone opens it, that message is filled into their message field so they can start the conversation with one tap.");
	self.emptyLabel.hidden = YES;
	[self.view addSubview:self.emptyLabel];

	[self reload];

	__weak typeof(self) weakSelf = self;
	[TGBusinessService businessChatLinkCountMaxWithCompletion:^(NSInteger maxCount) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (strongSelf && maxCount > 0)
			strongSelf.linkLimit = maxCount;
	}];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)viewDidLayoutSubviews {
	if ([[UIViewController class] instancesRespondToSelector:@selector(viewDidLayoutSubviews)])
		[super viewDidLayoutSubviews];
	if (!self.emptyLabel.hidden) {
		CGSize size = [self.emptyLabel.text sizeWithFont:self.emptyLabel.font
									   constrainedToSize:CGSizeMake(self.view.bounds.size.width - 48, 1000)
										   lineBreakMode:NSLineBreakByWordWrapping];
		self.emptyLabel.frame = CGRectMake(24,
			floorf((self.view.bounds.size.height - size.height) / 2),
			self.view.bounds.size.width - 48, ceilf(size.height));
	}
}

- (void)reload {
	self.loading = YES;
	__weak typeof(self) weakSelf = self;
	[TGBusinessService businessChatLinksWithCompletion:^(NSArray *links) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.loading = NO;
		strongSelf.loaded = YES;
		strongSelf.links = links ?: @[];
		strongSelf.emptyLabel.text = links
			? TGL(@"Business.LinksInfo", @"Create a link with a preset message. When someone opens it, that message is filled into their message field so they can start the conversation with one tap."
										  "opens it, that message is filled into their message "
										  "field so they can start the conversation with one tap.")
			: TGL(@"Business.LinksLoadFailed", @"Your links could not be loaded.");
		strongSelf.tableView.hidden = strongSelf.links.count == 0;
		strongSelf.emptyLabel.hidden = strongSelf.links.count != 0;
		[strongSelf.tableView reloadData];
		[strongSelf.view setNeedsLayout];
	}];
}

#pragma mark - table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.links.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"link"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"link"];
	[[TGTheme shared] styleCell:cell];
	cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;

	NSDictionary *link = self.links[(NSUInteger)indexPath.row];
	NSString *title = link[@"title"];
	cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
	cell.textLabel.text = title.length ? title : link[@"link"];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	NSString *text = link[@"text"];
	NSInteger views = [link[@"viewCount"] integerValue];
	NSString *clicksText = views == 0
		? TGL(@"Business.Links.ItemNoClicks", @"no clicks")
		: TGLPlural(@"Business.Links.ItemClickCount", views, @"%@ click", @"%@ clicks");
	cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@",
		text.length ? text : link[@"link"], clicksText];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	[self showActionsForLinkAtIndex:indexPath.row];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
	[self showActionsForLinkAtIndex:indexPath.row];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return YES;
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
	return TGL(@"Common.Delete", @"Delete");
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
	 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete)
		return;
	[self deleteLinkAtIndex:indexPath.row];
}

#pragma mark - actions

- (void)showActionsForLinkAtIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)self.links.count)
		return;
	NSDictionary *link = self.links[(NSUInteger)index];
	NSMutableArray *actions = [NSMutableArray array];
	[actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGL(@"PeerInfo.Gifts.Context.CopyLink", @"Copy Link") action:@"copy"]];
	[actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGL(@"Common.Edit", @"Edit") action:@"edit"]];
	TGActionSheetAction *remove = [TGActionSheetAction alloc];
	remove = [remove initWithTitle:TGL(@"Common.Delete", @"Delete")
							action:@"delete"
							  type:TGActionSheetActionTypeDestructive];
	[actions addObject:remove];
	TGActionSheetAction *cancel = [TGActionSheetAction alloc];
	cancel = [cancel initWithTitle:TGL(@"Common.Cancel", @"Cancel")
							action:@"cancel"
							  type:TGActionSheetActionTypeCancel];
	[actions addObject:cancel];
	NSString *sheetTitle = [link[@"title"] length] ? link[@"title"] : link[@"link"];
	__weak typeof(self) weakSelf = self;
	TGActionSheet *sheet = [TGActionSheet alloc];
	sheet = [sheet initWithTitle:sheetTitle
						 actions:actions
					 actionBlock:^(id target, NSString *action) {
						 __strong typeof(weakSelf) strongSelf = weakSelf;
						 if (!strongSelf)
							 return;
						 if ([action isEqualToString:@"copy"]) {
							 [UIPasteboard generalPasteboard].string = link[@"link"];
							 [TGSnackbar showInView:strongSelf.view text:TGL(@"Story.ToastLinkCopied", @"Link Copied") seconds:2 onCommit:nil];
						 } else if ([action isEqualToString:@"edit"]) {
							 [strongSelf pushEditorForLink:link];
						 } else if ([action isEqualToString:@"delete"]) {
							 [strongSelf deleteLink:link[@"link"]];
						 }
					 }
						  target:self];
	NSIndexPath *rowIndexPath = [NSIndexPath indexPathForRow:index inSection:0];
	UITableViewCell *rowCell = [self.tableView cellForRowAtIndexPath:rowIndexPath];
	CGRect anchorRect = rowCell ? rowCell.frame
		: CGRectMake(CGRectGetMidX(self.tableView.bounds), CGRectGetMidY(self.tableView.bounds), 1, 1);
	[sheet tg_showFromRect:anchorRect inView:self.tableView];
}

- (void)createLink {
	if (self.links.count >= (NSUInteger)self.linkLimit) {
		[self showAlert:TGL(@"Business.Links.ErrorTooManyLinks", @"You have reached the limit for chat links.")];
		return;
	}
	[self pushEditorForLink:nil];
}

- (void)pushEditorForLink:(NSDictionary *)link {
	TGBusinessChatLinkEditViewController *editor = [[TGBusinessChatLinkEditViewController alloc] initWithLink:link];
	__weak typeof(self) weakSelf = self;
	editor.onSaved = ^{
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf reload];
	};
	[self.navigationController pushViewController:editor animated:YES];
}

- (void)deleteLink:(NSString *)link {
	if (self.deleting)
		return;
	self.deleting = YES;
	__weak typeof(self) weakSelf = self;
	[TGBusinessService deleteBusinessChatLink:link completion:^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.deleting = NO;
		if (!ok) {
			[TGSnackbar showInView:strongSelf.view
							   text:TGL(@"Toast.CouldNotDeleteChatLink", @"Could not delete the chat link")
							seconds:2
						   onCommit:nil];
			return;
		}
		[strongSelf reload];
	}];
}

- (void)deleteLinkAtIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)self.links.count)
		return;
	NSDictionary *link = self.links[(NSUInteger)index];
	[self deleteLink:link[@"link"]];
}

- (void)showAlert:(NSString *)message {
	TGAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:nil message:message
						delegate:nil
			   cancelButtonTitle:TGL(@"Common.OK", @"OK")
			   otherButtonTitles:nil];
	[alert show];
}

@end

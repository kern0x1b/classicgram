#import "TGListBackground.h"
#import "TGChatFolderLinkPreviewViewController.h"
#import "TGLocalization.h"
#import "TGClient.h"
#import "TGClient+ChatList.h"
#import "TGTheme.h"
#import "TGSnackbar.h"
#import "TGSimpleAvatarCache.h"

@interface TGChatFolderLinkPreviewViewController ()
@property (nonatomic, strong) NSMutableSet *selectedChatIds;
@property (nonatomic, strong) NSDictionary *titlesByChatId;
@property (nonatomic, strong) TGSimpleAvatarCache *avatarCache;
@property (nonatomic, strong) UIButton *joinButton;
@property (nonatomic, assign) BOOL joining;
@end

@implementation TGChatFolderLinkPreviewViewController

+ (void)presentForInviteLink:(NSString *)link
	fromNavigationController:(UINavigationController *)navigationController {
	if (![link isKindOfClass:NSString.class] || !link.length)
		return;
	[[TGClient shared] checkFolderInviteLink:link completion:^(NSDictionary *reply) {
		NSDictionary *info = [reply isKindOfClass:NSDictionary.class] ? reply : nil;
		if (!info) {
			UIAlertView *bad = [UIAlertView alloc];
			bad = [bad initWithTitle:TGL(@"ChatList.AddFolder", @"Add Folder")
							 message:TGL(@"Chat.ErrorFolderLinkExpired", @"That link is not valid any more.")
							delegate:nil
				   cancelButtonTitle:TGL(@"Common.OK", @"OK")
				   otherButtonTitles:nil];
			[bad show];
			return;
		}

		TGChatFolderLinkPreviewViewController *screen = [[self alloc] init];
		screen.inviteLink = link;
		NSString *title = info[@"title"];
		screen.folderTitle = [title isKindOfClass:NSString.class] && title.length ? title : @"Folder";
		NSString *icon = info[@"icon"];
		screen.folderIconName = [icon isKindOfClass:NSString.class] ? icon : @"";
		NSNumber *folderId = info[@"folderId"];
		screen.folderId = [folderId isKindOfClass:NSNumber.class] ? folderId.integerValue : 0;
		NSArray *missing = info[@"missingChatIds"];
		screen.missingChatIds = [missing isKindOfClass:NSArray.class] ? missing : @[];
		NSArray *added = info[@"addedChatIds"];
		screen.addedChatIds = [added isKindOfClass:NSArray.class] ? added : @[];
		[navigationController pushViewController:screen animated:YES];
	}];
}

- (id)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	self.title = self.folderTitle.length ? self.folderTitle : @"Folder";
	self.selectedChatIds = [NSMutableSet setWithArray:(self.missingChatIds ?: @[])];
	self.avatarCache = [[TGSimpleAvatarCache alloc] initWithAvatarSide:40];
	self.avatarCache.tableView = self.tableView;

	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	if (self.navigationController.navigationBar)
		[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];

	self.tableView.tableHeaderView = [self buildHeaderView];

	if (self.missingChatIds.count) {
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] titlesForChatIds:self.missingChatIds completion:^(NSDictionary *reply) {
			TGChatFolderLinkPreviewViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			strongSelf.titlesByChatId = [reply isKindOfClass:NSDictionary.class] ? reply : @{};
			[strongSelf.tableView reloadData];
		}];
	}
}

- (UIView *)buildHeaderView {
	CGFloat width = self.view.bounds.size.width ?: [UIScreen mainScreen].bounds.size.width;
	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 64)];
	header.backgroundColor = [[TGTheme shared] listBackgroundColour];
	header.autoresizingMask = UIViewAutoresizingFlexibleWidth;

	NSString *glyph = self.folderIconName.length
		? [[TGClient shared] symbolForFolderIconName:self.folderIconName]
		: nil;
	NSString *text = glyph.length
		? [NSString stringWithFormat:@"%@  %@", glyph, self.folderTitle]
		: self.folderTitle;

	UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(16, 8, width - 32, 48)];
	label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	label.backgroundColor = [UIColor clearColor];
	label.font = [UIFont boldSystemFontOfSize:20];
	label.textAlignment = NSTextAlignmentCenter;
	label.textColor = [[TGTheme shared] primaryTextColour];
	label.numberOfLines = 2;
	label.lineBreakMode = NSLineBreakByTruncatingTail;
	label.text = text;
	[header addSubview:label];
	return header;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (!self.missingChatIds.count)
		return nil;
	return TGLPlural(@"FolderLinkPreview.ChatSectionJoinHeader", (NSInteger)self.missingChatIds.count,
		@"%d CHAT IN THIS FOLDER TO JOIN", @"%d CHATS IN THIS FOLDER TO JOIN");
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderHeightForTitle:title];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.missingChatIds.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	return [self chatCellForTable:tableView atIndex:indexPath.row];
}

- (UITableViewCell *)chatCellForTable:(UITableView *)tableView atIndex:(NSInteger)index {
	static NSString *reuse = @"TGChatFolderLinkPreviewChatCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:reuse];

	NSNumber *chatId = self.missingChatIds[index];
	NSString *title = self.titlesByChatId[chatId];
	if (![title isKindOfClass:NSString.class] || !title.length)
		title = [[TGClient shared] cachedTitleForChatId:chatId.longLongValue];
	NSString *shownTitle = title.length ? title : TGL(@"ChatList.UnnamedChat", @"Chat");

	cell.textLabel.text = shownTitle;
	cell.textLabel.textColor = [[TGTheme shared] primaryTextColour];
	cell.imageView.image = [self.avatarCache avatarForChatId:chatId.longLongValue title:shownTitle];
	cell.accessoryType = [self.selectedChatIds containsObject:chatId]
		? UITableViewCellAccessoryCheckmark
		: UITableViewCellAccessoryNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.row >= (NSInteger)self.missingChatIds.count)
		return;
	NSNumber *chatId = self.missingChatIds[indexPath.row];
	if ([self.selectedChatIds containsObject:chatId])
		[self.selectedChatIds removeObject:chatId];
	else
		[self.selectedChatIds addObject:chatId];
	[tableView reloadRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationNone];
}

- (BOOL)needsJoinAction {
	return self.folderId == 0 || self.missingChatIds.count > 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	CGFloat width = tableView.bounds.size.width ?: [UIScreen mainScreen].bounds.size.width;
	if (![self needsJoinAction])
		return [[TGTheme shared] groupedCommentHeightForText:[self allAddedText] width:width] + 24;
	return 74;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	CGFloat width = tableView.bounds.size.width ?: [UIScreen mainScreen].bounds.size.width;
	if (![self needsJoinAction])
		return [[TGTheme shared] groupedCommentViewWithText:[self allAddedText] width:width];
	return [self joinFooterViewWithWidth:width];
}

- (NSString *)allAddedText {
	return TGL(@"FolderLinkPreview.TextAllAdded", @"You have already added this\nfolder and its chats.");
}

- (UIView *)joinFooterViewWithWidth:(CGFloat)width {
	UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 74)];

	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.frame = CGRectMake(16, 10, width - 32, 44);
	button.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	button.layer.cornerRadius = 8;
	button.clipsToBounds = YES;
	button.exclusiveTouch = YES;
	button.backgroundColor = [[TGTheme shared] accentColour];
	button.titleLabel.font = [UIFont boldSystemFontOfSize:17];
	[button setTitle:TGL(@"FolderLinkPreview.ButtonJoinChats", @"Join Chats") forState:UIControlStateNormal];
	[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[button addTarget:self action:@selector(joinTapped) forControlEvents:UIControlEventTouchUpInside];
	[footer addSubview:button];
	self.joinButton = button;
	return footer;
}

- (void)joinTapped {
	if (self.joining)
		return;
	self.joining = YES;
	self.joinButton.enabled = NO;

	NSMutableArray *picked = [NSMutableArray array];
	for (NSNumber *chatId in (self.missingChatIds ?: @[]))
		if ([self.selectedChatIds containsObject:chatId])
			[picked addObject:chatId];

	NSString *link = self.inviteLink;
	NSString *name = self.folderTitle.length ? self.folderTitle : @"Folder";
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] joinFolderByInviteLink:link chatIds:picked completion:^(BOOL ok) {
		TGChatFolderLinkPreviewViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		UINavigationController *nc = strongSelf.navigationController;
		if (!ok) {
			strongSelf.joining = NO;
			strongSelf.joinButton.enabled = YES;
			[TGSnackbar showInView:strongSelf.view
							   text:TGL(@"Login.UnknownError", @"An error occurred, please try again later.")
							seconds:3
						   onCommit:nil];
			return;
		}
		[nc popViewControllerAnimated:YES];
		NSString *toast = [NSString stringWithFormat:
			TGL(@"FolderLinkPreview.ToastFolderAddedTitle", @"Folder %@ Added"), name];
		[TGSnackbar showInView:nc.view text:toast seconds:3 onCommit:nil];
	}];
}

@end

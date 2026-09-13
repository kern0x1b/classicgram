#import "TGListBackground.h"
#import "TGFoldersViewController.h"
#import "TGFoldersInternal.h"
#import "TGLocalization.h"
#import "TGClient+ChatList.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGAlertView.h"
#import "TGActionSheetIndexBuilder.h"

@implementation TGFoldersViewController

- (id)init {
	return [self initWithStyle:UITableViewStyleGrouped];
}

- (id)initWithStyle:(UITableViewStyle)style {
	self = [super initWithStyle:style];
	if (self) {
		_page = TGFoldersPageList;
		_folderId = 0;
		_pendingDeleteIndex = -1;
		_activeLinkIndex = -1;
		_mainListPosition = [TGClient shared].mainChatListPosition;
	}
	return self;
}

#pragma mark - lifecycle

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	self.folders = [NSMutableArray array];
	self.counts = [NSMutableDictionary dictionary];
	self.icons = [NSMutableDictionary dictionary];
	self.recommended = [NSMutableArray array];
	self.pickerChats = [NSMutableArray array];
	self.inviteLinks = [NSMutableArray array];
	self.avatarImages = [NSMutableDictionary dictionary];
	self.avatarsRequested = [NSMutableSet set];

	[self applyTheme];
	[self buildStatusLabel];
	TGApplyRTLTableMirroring(self.tableView);

	switch (self.page) {
		case TGFoldersPageEditor:
			self.title = self.folderId ? TGL(@"ChatListFolder.TitleEdit", @"Edit Folder") : TGL(@"ChatListFolder.TitleCreate", @"New Folder");
			[self buildEditorButtons];
			[self loadDraft];
			[self loadChosenChatLimit];
			if (self.folderId)
				[self loadInviteLinks];
			else
				[self loadFolderLimit];
			break;
		case TGFoldersPageChatPicker:
			if (!self.title.length)
				self.title = TGL(@"GlobalAutodeleteSettings.ApplyChatsTitle", @"Select Chats");
			[self buildPickerButtons];
			if (self.pickerFixedChats)
				[self adoptFixedPickerChats];
			else
				[self loadPickerChats];
			break;
		case TGFoldersPageIconPicker:
			self.title = TGL(@"Folders.Icon", @"Icon");
			self.iconNames = [[TGClient shared] folderIconNames];
			break;
		default:
			self.title = TGL(@"ChatListFolderSettings.Title", @"Folders");
			[self buildListButtons];
			[self observeFolderChanges];
			[self loadFolderLimit];
			[self loadFolders];
			[self loadRecommended];
			break;
	}
}

- (void)observeFolderChanges {
	if (self.observingFolders)
		return;
	self.observingFolders = YES;
	__weak typeof(self) weakSelf = self;
	self.foldersDidChangeObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatFoldersDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf foldersDidChange];
				}];
	self.chatsDidChangeObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatsDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf || strongSelf.page != TGFoldersPageList)
						return;
					[strongSelf refreshCounts];
				}];
	self.archivedChatsDidChangeObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGArchivedChatsDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf || strongSelf.page != TGFoldersPageList)
						return;
					[strongSelf refreshCounts];
				}];
	[[TGClient shared] beginObservingFolderChanges];
}

- (void)foldersDidChange {
	if (self.page != TGFoldersPageList)
		return;
	if (self.tableView.isEditing)
		return;
	[self.counts removeAllObjects];
	[self loadFolders];
	[self loadRecommended];
}

- (void)dealloc {
	if (self.observingFolders)
		[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (self.foldersDidChangeObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.foldersDidChangeObserverToken];
	if (self.chatsDidChangeObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.chatsDidChangeObserverToken];
	if (self.archivedChatsDidChangeObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.archivedChatsDidChangeObserverToken];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if (self.page == TGFoldersPageList) {
		[self.counts removeAllObjects];
		[self loadFolders];
	} else {
		[self.tableView reloadData];
	}
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	if (self.page == TGFoldersPageList)
		[self commitOrder];
}

- (void)viewWillLayoutSubviews {
	[super viewWillLayoutSubviews];
	[self layoutStatusLabel];
}

- (void)applyTheme {
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	if (self.navigationController.navigationBar)
		[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

#pragma mark - chrome

- (void)buildListButtons {
	UIButton *edit = [TGIcons headerButtonWithTitle:TGL(@"Common.Edit", @"Edit") bold:NO
											 target:self
											 action:@selector(toggleEditing)];
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:edit];
}

- (void)buildEditorButtons {
	UIButton *done = [TGIcons headerButtonWithTitle:TGL(@"Common.Done", @"Done") bold:YES
											 target:self
											 action:@selector(saveDraft)];
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:done];
}

- (void)buildPickerButtons {
	UIButton *done = [TGIcons headerButtonWithTitle:TGL(@"Common.Done", @"Done") bold:YES
											 target:self
											 action:@selector(finishPicking)];
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:done];
}

- (void)toggleEditing {
	BOOL editing = !self.tableView.isEditing;
	[self.tableView setEditing:editing animated:YES];
	UIButton *button = [TGIcons headerButtonWithTitle:(editing ? TGL(@"Common.Done", @"Done") : TGL(@"Common.Edit", @"Edit"))
												 bold:editing
											   target:self
											   action:@selector(toggleEditing)];
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:button];
	if (!editing)
		[self commitOrder];
}

#pragma mark - status label

- (void)buildStatusLabel {
	self.statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.statusLabel.backgroundColor = [UIColor clearColor];
	self.statusLabel.textAlignment = NSTextAlignmentCenter;
	self.statusLabel.font = [UIFont systemFontOfSize:15];
	self.statusLabel.numberOfLines = 3;
	self.statusLabel.textColor = [[TGTheme shared] secondaryTextColour];
	self.statusLabel.userInteractionEnabled = NO;
	self.statusLabel.hidden = YES;
	[self.tableView addSubview:self.statusLabel];
}

- (void)layoutStatusLabel {
	if (!self.statusLabel || self.statusLabel.hidden)
		return;
	CGRect bounds = self.tableView.bounds;
	self.statusLabel.frame = CGRectMake(kCaptionInset,
		floorf((bounds.size.height - 60) / 2), bounds.size.width - kCaptionInset * 2, 60);
	[self.tableView bringSubviewToFront:self.statusLabel];
}

- (void)showStatus:(NSString *)text {
	if (!text.length) {
		self.statusLabel.hidden = YES;
		return;
	}
	self.statusLabel.text = text;
	self.statusLabel.textColor = [[TGTheme shared] secondaryTextColour];
	self.statusLabel.hidden = NO;
	[self layoutStatusLabel];
}

@end

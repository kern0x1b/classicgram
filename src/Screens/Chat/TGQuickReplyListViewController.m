#import "TGQuickReplyListViewController.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGClient.h"
#import "TGClient+Messages.h"
#import "TGClient+MessageContent.h"
#import "TGTheme.h"
#import "TGSnackbar.h"
#import "TGAlertView.h"
#import "TGCapabilities.h"
#import "TGQuickReplyPreviewLayoutHost.h"
#import "TGChatViewControllerInternal.h"

static const CGFloat kQuickReplyRowHeight = 60.0f;
static const NSInteger kRenameAlertTag = 1;
static const NSInteger kCreateAlertTag = 2;
static const NSInteger kCreateTextAlertTag = 3;
static const NSInteger kEditMessageAlertTag = 4;
static const NSInteger kAddMessageAlertTag = 5;

@interface TGQuickReplyPreviewViewController : UITableViewController <UIAlertViewDelegate>
@property (nonatomic, assign) NSInteger shortcutId;
@property (nonatomic, copy) NSString *shortcutName;
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, copy) void (^onSent)(void);
@property (nonatomic, strong) TGQuickReplyPreviewLayoutHost *layoutHost;
@property (nonatomic, strong) id messagesUpdatedObserverToken;
@property (nonatomic, strong) id shortcutsUpdatedObserverToken;
@property (nonatomic, assign) int64_t editingMessageId;
@end

@implementation TGQuickReplyPreviewViewController {
	NSArray *_messages;
	BOOL _loaded;
	UILabel *_statusLabel;
}

- (instancetype)init {
	self = [super initWithStyle:UITableViewStylePlain];
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (self.messagesUpdatedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.messagesUpdatedObserverToken];
	if (self.shortcutsUpdatedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.shortcutsUpdatedObserverToken];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = [NSString stringWithFormat:@"/%@", self.shortcutName.length ? self.shortcutName : @"reply"];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	UIBarButtonItem *addItem = [[UIBarButtonItem alloc]
		initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
							 target:self
							 action:@selector(addMessageTapped)];
	if (self.chatId != 0) {
		UIBarButtonItem *sendItem = [[UIBarButtonItem alloc]
			initWithTitle:TGL(@"MediaPicker.Send", @"Send")
					style:UIBarButtonItemStyleDone
				   target:self
				   action:@selector(sendTapped)];
		self.navigationItem.rightBarButtonItems = @[ sendItem, addItem ];
	} else {
		self.navigationItem.rightBarButtonItem = addItem;
	}

	_statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_statusLabel.font = [UIFont systemFontOfSize:15];
	_statusLabel.textColor = [[TGTheme shared] secondaryTextColour];
	_statusLabel.textAlignment = NSTextAlignmentCenter;
	_statusLabel.numberOfLines = 0;
	_statusLabel.text = TGL(@"Channel.NotificationLoading", @"Loading…");
	[self.view addSubview:_statusLabel];

	self.layoutHost = [[TGQuickReplyPreviewLayoutHost alloc] init];
	self.layoutHost.table = self.tableView;
	self.layoutHost.chatId = 0;
	self.layoutHost.group = NO;
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	if ([TGCapabilities canShowWallpaper]) {
		UIImageView *wallpaper = [[UIImageView alloc] initWithFrame:self.view.bounds];
		wallpaper.contentMode = UIViewContentModeScaleAspectFill;
		wallpaper.clipsToBounds = YES;
		wallpaper.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		wallpaper.image = [[TGTheme shared] wallpaper];
		[self.view insertSubview:wallpaper atIndex:0];
		self.tableView.backgroundColor = [UIColor clearColor];
	} else {
		self.tableView.backgroundColor = [[TGTheme shared] chatBackgroundColour];
	}

	__weak typeof(self) weakSelf = self;
	self.messagesUpdatedObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGQuickReplyShortcutMessagesUpdatedNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf messagesUpdated:note];
				}];

	self.shortcutsUpdatedObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGQuickReplyShortcutsUpdatedNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf shortcutRenamedIfNeeded];
				}];

	NSArray *cached = [[TGClient shared] cachedQuickReplyShortcutMessages:self.shortcutId];
	if (cached)
		[self applyMessages:cached];
	[[TGClient shared] loadQuickReplyShortcutMessages:self.shortcutId];
	[self performSelector:@selector(loadTimedOut) withObject:nil afterDelay:6.0];
	[self refreshStatus];
}

- (void)applyMessages:(NSArray *)messages {
	_messages = messages ?: @[];
	_loaded = YES;
	self.layoutHost.messages = _messages;
	[self.layoutHost resolveUnknownSenders];
	[self.layoutHost fetchMissingQuotes];
	[self.layoutHost fetchMissingVoiceFiles];
	[self.layoutHost fetchMissingImages];
	[self.tableView reloadData];
	[self refreshStatus];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	CGSize size = [_statusLabel.text sizeWithFont:_statusLabel.font
								constrainedToSize:CGSizeMake(self.view.bounds.size.width - 48, 1000)
									lineBreakMode:NSLineBreakByWordWrapping];
	_statusLabel.frame = CGRectMake(24, floorf((self.view.bounds.size.height - size.height) / 2),
		self.view.bounds.size.width - 48, ceilf(size.height));
}

- (void)messagesUpdated:(NSNotification *)note {
	NSNumber *shortcutId = note.object;
	if ([shortcutId isKindOfClass:NSNumber.class] && shortcutId.integerValue != self.shortcutId)
		return;
	NSObject *cancelToken = self;
	[NSObject cancelPreviousPerformRequestsWithTarget:cancelToken selector:@selector(loadTimedOut) object:nil];
	[self applyMessages:[[TGClient shared] cachedQuickReplyShortcutMessages:self.shortcutId] ?: @[]];
}

- (void)loadTimedOut {
	if (_loaded)
		return;
	_statusLabel.text = TGL(@"Chat.CouldNotLoadAPreviewOfThis", @"Could not load a preview of this shortcut.");
	[self.view setNeedsLayout];
}

- (void)shortcutRenamedIfNeeded {
	NSInteger shortcutId = self.shortcutId;
	for (NSDictionary *shortcut in [[TGClient shared] quickReplyShortcuts]) {
		if ([shortcut[@"id"] integerValue] != shortcutId)
			continue;
		NSString *name = [shortcut[@"name"] isKindOfClass:NSString.class] ? shortcut[@"name"] : @"";
		if ([name isEqualToString:self.shortcutName ?: @""])
			return;
		self.shortcutName = name;
		self.title = [NSString stringWithFormat:@"/%@", name.length ? name : @"reply"];
		return;
	}
}

- (BOOL)shortcutStillExists {
	NSInteger shortcutId = self.shortcutId;
	for (NSDictionary *shortcut in [[TGClient shared] quickReplyShortcuts])
		if ([shortcut[@"id"] integerValue] == shortcutId)
			return YES;
	return NO;
}

- (void)refreshStatus {
	if (!_loaded) {
		_statusLabel.hidden = NO;
		_statusLabel.text = TGL(@"Channel.NotificationLoading", @"Loading…");
	} else if (_messages.count == 0) {
		_statusLabel.hidden = NO;
		_statusLabel.text = TGL(@"Conversation.EmptyPlaceholder", @"No messages here yet");
	} else {
		_statusLabel.hidden = YES;
	}
	[self.view setNeedsLayout];
}

- (void)sendTapped {
	if (self.chatId == 0)
		return;
	int64_t chatId = self.chatId;
	NSInteger shortcutId = self.shortcutId;
	__weak typeof(self) weakSelf = self;
	self.navigationItem.rightBarButtonItem.enabled = NO;
	[[TGClient shared] sendQuickReplyShortcut:shortcutId toChat:chatId
								   completion:^(NSArray *sentMessages, BOOL ok) {
									   TGQuickReplyPreviewViewController *strongSelf = weakSelf;
									   if (!strongSelf)
										   return;
									   if (!ok) {
										   strongSelf.navigationItem.rightBarButtonItem.enabled = YES;
										   [TGSnackbar showInView:strongSelf.view
															  text:TGL(@"Toast.CouldNotSendQuickReply", @"Could not send the quick reply.")
														   seconds:2
														  onCommit:nil];
										   return;
									   }
									   if (strongSelf.onSent)
										   strongSelf.onSent();
									   [strongSelf.navigationController popViewControllerAnimated:YES];
								   }];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [self.layoutHost displayRowCount];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return [self.layoutHost tableView:tableView heightForRowAtIndexPath:indexPath];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	return [self.layoutHost tableView:tableView cellForRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSArray *group = [self.layoutHost messagesAtRow:indexPath.row];
	NSMutableArray *retryIds = [NSMutableArray array];
	for (NSDictionary *m in group)
		if ([m[@"canRetry"] boolValue] && [m[@"id"] isKindOfClass:NSNumber.class])
			[retryIds addObject:m[@"id"]];
	if (retryIds.count) {
		NSString *shortcutName = self.shortcutName;
		TGClient *client = [TGClient shared];
		__weak typeof(self) weakSelf = self;
		[client retryQuickReplyShortcutMessages:retryIds shortcutName:shortcutName
									  completion:^(BOOL ok) {
										  TGQuickReplyPreviewViewController *strongSelf = weakSelf;
										  if (!strongSelf || ok)
											  return;
										  [TGSnackbar showInView:strongSelf.view
															 text:TGL(@"Toast.CouldNotRetryQuickReply", @"Could not resend this quick reply message.")
														  seconds:2
														 onCommit:nil];
									  }];
		return;
	}

	if (group.count != 1)
		return;
	NSDictionary *message = group.firstObject;
	if (![message[@"id"] isKindOfClass:NSNumber.class])
		return;
	if (![message[@"canBeEdited"] boolValue])
		return;
	if (![message[@"kind"] isEqualToString:@"messageText"])
		return;
	[self presentEditMessageAlertWithMessage:message];
}

- (void)presentEditMessageAlertWithMessage:(NSDictionary *)message {
	self.editingMessageId = [message[@"id"] longLongValue];
	NSString *text = [message[@"text"] isKindOfClass:NSString.class] ? message[@"text"] : @"";
	TGAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:TGL(@"Conversation.EditCurrentMessage", @"Edit Message")
						 message:nil
						delegate:self
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			   otherButtonTitles:TGL(@"Conversation.LinkDialogSave", @"Save"), nil];
	if ([alert respondsToSelector:@selector(setAlertViewStyle:)])
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	[alert textFieldAtIndex:0].text = text;
	alert.tag = kEditMessageAlertTag;
	[alert show];
}

- (void)addMessageTapped {
	TGAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:TGL(@"QuickReply.CreateShortcutTitle", @"New Quick Reply")
						 message:TGL(@"QuickReply.CreateShortcutTextPrompt", @"Add the text for this quick reply.")
						delegate:self
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			   otherButtonTitles:TGL(@"Conversation.LinkDialogSave", @"Save"), nil];
	if ([alert respondsToSelector:@selector(setAlertViewStyle:)])
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	alert.tag = kAddMessageAlertTag;
	[alert show];
}

- (void)finishAddingMessageWithAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	if (buttonIndex == alertView.cancelButtonIndex)
		return;
	NSString *text = [alertView textFieldAtIndex:0].text;
	if (!text.length) {
		[TGSnackbar showInView:self.view
						   text:TGL(@"Chat.AQuickReplyNeedsText", @"A quick reply needs some text.")
						seconds:2
					   onCommit:nil];
		return;
	}
	if (![self shortcutStillExists]) {
		[TGSnackbar showInView:self.view
						   text:TGL(@"Toast.CouldNotSaveQuickReply", @"Could not save the quick reply.")
						seconds:2
					   onCommit:nil];
		return;
	}

	NSString *shortcutName = self.shortcutName;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] formattedTextFromMarkdown:text completion:^(NSString *parsedText, NSArray *entities) {
		TGQuickReplyPreviewViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[[TGClient shared] addQuickReplyShortcutNamed:shortcutName
												  text:parsedText.length ? parsedText : text
											  entities:entities
											completion:^(BOOL ok) {
												TGQuickReplyPreviewViewController *innerSelf = weakSelf;
												if (!innerSelf || ok)
													return;
												[TGSnackbar showInView:innerSelf.view
																   text:TGL(@"Toast.CouldNotSaveQuickReply", @"Could not save the quick reply.")
																seconds:2
															   onCommit:nil];
											}];
	}];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if (alertView.tag == kAddMessageAlertTag) {
		[self finishAddingMessageWithAlert:alertView buttonIndex:buttonIndex];
		return;
	}
	if (alertView.tag != kEditMessageAlertTag)
		return;
	if (buttonIndex == alertView.cancelButtonIndex)
		return;

	NSString *text = [alertView textFieldAtIndex:0].text;
	if (!text.length)
		return;

	int64_t messageId = self.editingMessageId;
	NSInteger shortcutId = self.shortcutId;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] formattedTextFromMarkdown:text completion:^(NSString *parsedText, NSArray *entities) {
		TGQuickReplyPreviewViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[[TGClient shared] editQuickReplyMessage:messageId
									  inShortcut:shortcutId
											text:parsedText.length ? parsedText : text
										entities:entities
									  completion:^(BOOL ok) {
										  TGQuickReplyPreviewViewController *innerSelf = weakSelf;
										  if (!innerSelf || ok)
											  return;
										  [TGSnackbar showInView:innerSelf.view
															 text:TGL(@"Toast.CouldNotEditQuickReply", @"Could not edit the quick reply.")
														  seconds:2
														 onCommit:nil];
									  }];
	}];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return YES;
}

- (NSString *)tableView:(UITableView *)tableView
	titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
	return TGL(@"Common.Delete", @"Delete");
}

- (void)tableView:(UITableView *)tableView
	commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
	 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete)
		return;
	NSArray *group = [self.layoutHost messagesAtRow:indexPath.row];
	NSMutableArray *ids = [NSMutableArray arrayWithCapacity:group.count];
	for (NSDictionary *m in group)
		if ([m[@"id"] isKindOfClass:NSNumber.class])
			[ids addObject:m[@"id"]];
	if (!ids.count)
		return;

	NSInteger shortcutId = self.shortcutId;
	TGClient *client = [TGClient shared];
	__weak typeof(self) weakSelf = self;
	[client deleteQuickReplyShortcutMessages:ids inShortcut:shortcutId
								   completion:^(BOOL ok) {
									   TGQuickReplyPreviewViewController *strongSelf = weakSelf;
									   if (!strongSelf || ok)
										   return;
									   [TGSnackbar showInView:strongSelf.view
														  text:TGL(@"Toast.CouldNotDeleteQuickReplyMessage", @"Could not delete this message.")
													   seconds:2
													  onCommit:nil];
								   }];
}

@end

@interface TGQuickReplyListViewController () <UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate>

@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) NSArray *shortcuts;
@property (nonatomic, assign) NSInteger renamingShortcutId;
@property (nonatomic, copy) NSString *pendingCreateText;
@property (nonatomic, copy) NSString *pendingCreateName;
@property (nonatomic, assign) BOOL autoPresentCreateAlert;
@property (nonatomic, assign) BOOL sendingShortcut;
@property (nonatomic, strong) id shortcutsChangedObserverToken;

@end

@implementation TGQuickReplyListViewController

- (instancetype)initWithChatId:(int64_t)chatId {
	self = [super initWithNibName:nil bundle:nil];
	if (self) {
		_chatId = chatId;
		_shortcuts = [NSArray array];
	}
	return self;
}

- (void)dealloc {
	_tableView.delegate = nil;
	_tableView.dataSource = nil;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (self.shortcutsChangedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.shortcutsChangedObserverToken];
}

- (void)viewDidLoad {
	[super viewDidLoad];

	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];

	UITableView *tableView = [UITableView alloc];
	self.tableView = [tableView initWithFrame:self.view.bounds style:UITableViewStylePlain];
	self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.tableView.backgroundColor = self.view.backgroundColor;
	self.tableView.rowHeight = kQuickReplyRowHeight;
	self.tableView.dataSource = self;
	self.tableView.delegate = self;
	[self.view addSubview:self.tableView];

	self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.emptyLabel.backgroundColor = [UIColor clearColor];
	self.emptyLabel.font = [UIFont systemFontOfSize:15];
	self.emptyLabel.textColor = [[TGTheme shared] secondaryTextColour];
	self.emptyLabel.textAlignment = NSTextAlignmentCenter;
	self.emptyLabel.numberOfLines = 0;
	self.emptyLabel.text = TGL(@"QuickReplies.EmptyState.Text", @"Saved replies you create with a message's ‘Save as Quick Reply’ action show up here.\nTap one to send it to this chat.");
	self.emptyLabel.hidden = YES;
	[self.view addSubview:self.emptyLabel];

	self.title = TGL(@"Premium.Business.Replies.Title", @"Quick Replies");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	self.tableView.allowsSelectionDuringEditing = YES;
	self.navigationItem.rightBarButtonItem =
		[TGIcons headerBarButtonItemWithTitle:TGL(@"Common.Edit", @"Edit") bold:NO
									   target:self
									   action:@selector(toggleEditing)];

	__weak typeof(self) weakSelf = self;
	self.shortcutsChangedObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGQuickReplyShortcutsUpdatedNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf shortcutsChanged];
				}];

	[self reload];
	[[TGClient shared] loadQuickReplyShortcuts];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	if (!self.autoPresentCreateAlert)
		return;
	self.autoPresentCreateAlert = NO;
	[self presentCreateShortcutAlert];
}

- (void)beginCreatingShortcutWithText:(NSString *)text {
	self.pendingCreateText = text ?: @"";
	self.autoPresentCreateAlert = YES;
	if (self.isViewLoaded && self.view.window) {
		self.autoPresentCreateAlert = NO;
		[self presentCreateShortcutAlert];
	}
}

- (void)presentCreateShortcutAlert {
	TGAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:TGL(@"QuickReply.CreateShortcutTitle", @"New Quick Reply")
						 message:TGL(@"QuickReply.CreateShortcutText", @"Add a shortcut for your quick reply.")
						delegate:self
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			   otherButtonTitles:TGL(@"Conversation.LinkDialogSave", @"Save"), nil];
	if ([alert respondsToSelector:@selector(setAlertViewStyle:)])
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	alert.tag = kCreateAlertTag;
	[alert show];
}

- (void)presentCreateShortcutTextAlert {
	TGAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:TGL(@"QuickReply.CreateShortcutTitle", @"New Quick Reply")
						 message:TGL(@"QuickReply.CreateShortcutTextPrompt", @"Add the text for this quick reply.")
						delegate:self
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			   otherButtonTitles:TGL(@"Conversation.LinkDialogSave", @"Save"), nil];
	if ([alert respondsToSelector:@selector(setAlertViewStyle:)])
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	alert.tag = kCreateTextAlertTag;
	[alert show];
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

- (void)shortcutsChanged {
	[self reload];
}

- (void)reload {
	self.shortcuts = [[TGClient shared] quickReplyShortcuts];
	self.tableView.hidden = self.shortcuts.count == 0;
	self.emptyLabel.hidden = self.shortcuts.count != 0;
	if (self.shortcuts.count == 0 && self.tableView.editing)
		[self setEditingWithButton:NO];
	[self.tableView reloadData];
	[self.view setNeedsLayout];
}

- (void)toggleEditing {
	[self setEditingWithButton:!self.tableView.editing];
}

- (void)setEditingWithButton:(BOOL)editing {
	[self.tableView setEditing:editing animated:YES];
	self.navigationItem.rightBarButtonItem.title = editing
		? TGL(@"Common.Done", @"Done")
		: TGL(@"Common.Edit", @"Edit");
}

#pragma mark - table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.shortcuts.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"quickReply"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"quickReply"];

	[[TGTheme shared] styleCell:cell];
	cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;

	NSDictionary *shortcut = self.shortcuts[(NSUInteger)indexPath.row];
	NSString *name = shortcut[@"name"];
	cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
	cell.textLabel.text = [NSString stringWithFormat:@"/%@", name.length ? name : @"reply"];

	NSInteger count = [shortcut[@"messageCount"] integerValue];
	NSString *preview = shortcut[@"preview"];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	cell.detailTextLabel.numberOfLines = 1;
	if (count > 1) {
		NSString *countText = TGLPlural(@"ChatList.Search.Messages", count, @"%@ message", @"%@ messages");
		cell.detailTextLabel.text = preview.length
			? [NSString stringWithFormat:@"%@ · %@", preview, countText]
			: countText;
	} else {
		cell.detailTextLabel.text = preview;
	}

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	NSDictionary *shortcut = self.shortcuts[(NSUInteger)indexPath.row];
	NSInteger shortcutId = [shortcut[@"id"] integerValue];

	if (tableView.editing) {
		[self renameShortcutId:shortcutId currentName:shortcut[@"name"]];
		return;
	}

	if (self.onPicked) {
		self.onPicked(shortcutId, shortcut[@"name"]);
		[self.navigationController popViewControllerAnimated:YES];
		return;
	}

	if (self.chatId == 0)
		return;

	if (self.sendingShortcut)
		return;
	self.sendingShortcut = YES;

	int64_t chatId = self.chatId;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] sendQuickReplyShortcut:shortcutId toChat:chatId
								   completion:^(NSArray *messages, BOOL ok) {
									   TGQuickReplyListViewController *strongSelf = weakSelf;
									   if (!strongSelf)
										   return;
									   strongSelf.sendingShortcut = NO;
									   if (!ok) {
										   [TGSnackbar showInView:strongSelf.view
															  text:TGL(@"Toast.CouldNotSendQuickReply", @"Could not send the quick reply.")
														   seconds:2
														  onCommit:nil];
										   return;
									   }
									   if (strongSelf.onSent)
										   strongSelf.onSent();
									   [strongSelf.navigationController popViewControllerAnimated:YES];
								   }];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *shortcut = self.shortcuts[(NSUInteger)indexPath.row];
	TGQuickReplyPreviewViewController *preview = [[TGQuickReplyPreviewViewController alloc] init];
	preview.shortcutId = [shortcut[@"id"] integerValue];
	preview.shortcutName = shortcut[@"name"];
	preview.chatId = self.chatId;
	__weak typeof(self) weakSelf = self;
	preview.onSent = ^{
		TGQuickReplyListViewController *strongSelf = weakSelf;
		if (strongSelf.onSent)
			strongSelf.onSent();
	};
	[self.navigationController pushViewController:preview animated:YES];
}

- (void)renameShortcutId:(NSInteger)shortcutId currentName:(NSString *)name {
	self.renamingShortcutId = shortcutId;
	TGAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:TGL(@"QuickReply.ShortcutPlaceholder", @"Shortcut Name")
						 message:nil
						delegate:self
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			   otherButtonTitles:TGL(@"Conversation.LinkDialogSave", @"Save"), nil];
	alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	[alert textFieldAtIndex:0].text = name ?: @"";
	alert.tag = kRenameAlertTag;
	[alert show];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if (alertView.tag == kCreateAlertTag) {
		[self finishCreatingShortcutWithAlert:alertView buttonIndex:buttonIndex];
		return;
	}
	if (alertView.tag == kCreateTextAlertTag) {
		[self finishCreatingShortcutTextWithAlert:alertView buttonIndex:buttonIndex];
		return;
	}
	if (alertView.tag != kRenameAlertTag) {
		return;
	}
	[self finishRenamingShortcutWithAlert:alertView buttonIndex:buttonIndex];
}

- (void)finishRenamingShortcutWithAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	if (buttonIndex == alertView.cancelButtonIndex)
		return;
	NSString *name = [alertView textFieldAtIndex:0].text;
	NSInteger shortcutId = self.renamingShortcutId;
	if (!name.length)
		return;

	BOOL duplicate = NO;
	for (NSDictionary *shortcut in self.shortcuts) {
		if ([shortcut[@"id"] integerValue] == shortcutId)
			continue;
		if ([shortcut[@"name"] isKindOfClass:NSString.class]
			&& [shortcut[@"name"] caseInsensitiveCompare:name] == NSOrderedSame) {
			duplicate = YES;
			break;
		}
	}
	if (duplicate) {
		[TGSnackbar showInView:self.view
						  text:TGL(@"QuickReply.ShortcutExistsInlineError", @"A quick reply with this name already exists.")
					   seconds:2
					  onCommit:nil];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] checkQuickReplyShortcutName:name completion:^(BOOL valid) {
		TGQuickReplyListViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!valid) {
			[TGSnackbar showInView:strongSelf.view
							  text:TGL(@"QuickReply.ShortcutInvalidInlineError", @"This isn't a valid name for a quick reply.")
						   seconds:2
						  onCommit:nil];
			return;
		}
		[[TGClient shared] setQuickReplyShortcutName:shortcutId name:name completion:^(BOOL ok) {
			TGQuickReplyListViewController *innerSelf = weakSelf;
			if (!innerSelf || ok)
				return;
			[TGSnackbar showInView:innerSelf.view
							  text:TGL(@"Toast.CouldNotRename", @"Could not rename")
						   seconds:2
						  onCommit:nil];
		}];
	}];
}

- (void)finishCreatingShortcutWithAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	NSString *text = self.pendingCreateText;
	self.pendingCreateText = nil;
	if (buttonIndex == alertView.cancelButtonIndex)
		return;

	NSString *name = [alertView textFieldAtIndex:0].text;
	if (!name.length) {
		[TGSnackbar showInView:self.view
						   text:TGL(@"Chat.AQuickReplyNeedsAName", @"A quick reply needs a name and some text.")
						seconds:2
					   onCommit:nil];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] checkQuickReplyShortcutName:name completion:^(BOOL valid) {
		TGQuickReplyListViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!valid) {
			[TGSnackbar showInView:strongSelf.view
							  text:TGL(@"QuickReply.ShortcutInvalidInlineError", @"This isn't a valid name for a quick reply.")
						   seconds:2
						  onCommit:nil];
			return;
		}
		if (!text.length) {
			strongSelf.pendingCreateName = name;
			[strongSelf presentCreateShortcutTextAlert];
			return;
		}
		[strongSelf submitNewShortcutNamed:name text:text];
	}];
}

- (void)finishCreatingShortcutTextWithAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	NSString *name = self.pendingCreateName;
	self.pendingCreateName = nil;
	if (buttonIndex == alertView.cancelButtonIndex || !name.length)
		return;

	NSString *text = [alertView textFieldAtIndex:0].text;
	if (!text.length) {
		[TGSnackbar showInView:self.view
						   text:TGL(@"Chat.AQuickReplyNeedsText", @"A quick reply needs some text.")
						seconds:2
					   onCommit:nil];
		return;
	}
	[self submitNewShortcutNamed:name text:text];
}

- (void)submitNewShortcutNamed:(NSString *)name text:(NSString *)text {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] formattedTextFromMarkdown:text completion:^(NSString *parsedText, NSArray *entities) {
		TGQuickReplyListViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf finishSubmittingShortcutNamed:name
											  text:parsedText.length ? parsedText : text
										  entities:entities];
	}];
}

- (void)finishSubmittingShortcutNamed:(NSString *)name text:(NSString *)text entities:(NSArray *)entities {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] addQuickReplyShortcutNamed:name text:text entities:entities completion:^(BOOL ok) {
		TGQuickReplyListViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[TGSnackbar showInView:strongSelf.view
							   text:TGL(@"Toast.CouldNotSaveQuickReply", @"Could not save the quick reply.")
							seconds:2
						   onCommit:nil];
			return;
		}
		[TGSnackbar showInView:strongSelf.view
						   text:TGL(@"Chat.SavedAsAQuickReply", @"Saved as a quick reply.")
						seconds:2
					   onCommit:nil];
		[[TGClient shared] loadQuickReplyShortcuts];
	}];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return YES;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
	return YES;
}

- (void)tableView:(UITableView *)tableView
	moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath
		   toIndexPath:(NSIndexPath *)destinationIndexPath {
	if (sourceIndexPath.row == destinationIndexPath.row)
		return;
	NSMutableArray *reordered = [self.shortcuts mutableCopy];
	NSDictionary *moved = reordered[(NSUInteger)sourceIndexPath.row];
	[reordered removeObjectAtIndex:(NSUInteger)sourceIndexPath.row];
	[reordered insertObject:moved atIndex:(NSUInteger)destinationIndexPath.row];
	self.shortcuts = reordered;

	NSMutableArray *ids = [NSMutableArray arrayWithCapacity:reordered.count];
	for (NSDictionary *shortcut in reordered)
		[ids addObject:shortcut[@"id"]];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] reorderQuickReplyShortcuts:ids completion:^(BOOL ok) {
		TGQuickReplyListViewController *strongSelf = weakSelf;
		if (!strongSelf || ok)
			return;
		[strongSelf reload];
		[TGSnackbar showInView:strongSelf.view
						   text:TGL(@"Toast.CouldNotReorderQuickReplies", @"Could not save the new order.")
						seconds:2
					   onCommit:nil];
	}];
}

- (NSString *)tableView:(UITableView *)tableView
	titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
	return TGL(@"Common.Delete", @"Delete");
}

- (void)tableView:(UITableView *)tableView
	commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
	 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete)
		return;
	if (indexPath.row < 0 || indexPath.row >= (NSInteger)self.shortcuts.count)
		return;

	NSDictionary *shortcut = self.shortcuts[(NSUInteger)indexPath.row];
	NSInteger shortcutId = [shortcut[@"id"] integerValue];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] deleteQuickReplyShortcut:shortcutId completion:^(BOOL ok) {
		TGQuickReplyListViewController *strongSelf = weakSelf;
		if (!strongSelf || ok)
			return;
		[TGSnackbar showInView:strongSelf.view
						   text:TGL(@"Toast.CouldNotDeleteQuickReply", @"Could not delete the quick reply.")
						seconds:2
					   onCommit:nil];
	}];
}

@end

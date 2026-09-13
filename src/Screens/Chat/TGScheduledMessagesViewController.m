#import "TGScheduledFooterText.h"
#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGScheduledMessagesViewController.h"
#import "TGDateUtils.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGClient.h"
#import "TGClient+Messages.h"
#import "TGSnackbar.h"
#import "TGActionSheetIndexBuilder.h"
#import "TGActionSheet.h"

static const NSInteger kItemSheetTag = 71;

@interface TGScheduledMessagesViewController () <UIActionSheetDelegate>
@property (nonatomic, strong) NSArray *messages;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL loadFailed;
@property (nonatomic, assign) int64_t chosenMessageId;
@property (nonatomic, strong) id messageObserverToken;
@end

@implementation TGScheduledMessagesViewController

- (id)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self)
		_chosenMessageId = 0;
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.title = self.remindersStyle ? TGL(@"ScheduledMessages.RemindersTitle", @"Reminders") : TGL(@"VoiceOver.ScheduledMessages", @"Scheduled Messages");
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	[self installMessageObserver];
	[self reload];
}

- (void)installMessageObserver {
	__weak typeof(self) weakSelf = self;
	self.messageObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGMessageDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		int64_t chatId = [note.userInfo[TGMessageChatIdKey] longLongValue];
		if (chatId != strongSelf.chatId)
			return;
		NSDictionary *message = [note.userInfo[TGMessageDataKey] isKindOfClass:[NSDictionary class]]
			? note.userInfo[TGMessageDataKey]
			: nil;
		int64_t deletedId = [note.userInfo[TGMessageDeletedIdKey] longLongValue];
		if (message && [message[@"scheduled"] boolValue]) {
			[strongSelf upsertScheduledMessage:message replacingId:deletedId];
			return;
		}
		if (!deletedId)
			return;
		[strongSelf removeMessageWithId:deletedId];
	}];
}

- (void)upsertScheduledMessage:(NSDictionary *)message replacingId:(int64_t)replacingId {
	int64_t newId = [message[@"id"] isKindOfClass:[NSNumber class]] ? [message[@"id"] longLongValue] : 0;
	NSInteger row = -1;
	for (NSInteger i = 0; i < (NSInteger)self.messages.count; i++) {
		int64_t candidateId = [self.messages[i][@"id"] longLongValue];
		if (candidateId == replacingId || (newId && candidateId == newId)) {
			row = i;
			break;
		}
	}
	NSMutableArray *updated = [self.messages mutableCopy] ?: [NSMutableArray array];
	if (row >= 0) {
		updated[row] = message;
		self.messages = updated;
		[self.tableView reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:row inSection:0] ]
							   withRowAnimation:UITableViewRowAnimationNone];
		return;
	}
	[updated addObject:message];
	self.messages = updated;
	[self.tableView reloadData];
}

- (void)removeMessageWithId:(int64_t)messageId {
	NSInteger row = -1;
	for (NSInteger i = 0; i < (NSInteger)self.messages.count; i++) {
		if ([self.messages[i][@"id"] longLongValue] == messageId) {
			row = i;
			break;
		}
	}
	if (row < 0)
		return;
	NSMutableArray *remaining = [self.messages mutableCopy];
	[remaining removeObjectAtIndex:row];
	self.messages = remaining;
	[self.tableView deleteRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:row inSection:0] ]
						   withRowAnimation:UITableViewRowAnimationAutomatic];
	if (!self.messages.count)
		[self.tableView reloadData];
}

- (void)dealloc {
	if (self.messageObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.messageObserverToken];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	[self reload];
}

- (void)reload {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] scheduledMessagesInChat:self.chatId
									completion:^(NSArray *found, BOOL failed) {
										__strong typeof(weakSelf) strongSelf = weakSelf;
										if (!strongSelf)
											return;
										strongSelf.messages = [found isKindOfClass:[NSArray class]] ? found : @[];
										strongSelf.loadFailed = failed;
										strongSelf.loaded = YES;
										[strongSelf.tableView reloadData];
									}];
}

- (NSDictionary *)messageAtRow:(NSInteger)row {
	if (row < 0 || row >= (NSInteger)self.messages.count)
		return nil;
	return self.messages[row];
}

- (NSDictionary *)messageWithId:(int64_t)messageId {
	if (!messageId)
		return nil;
	for (NSDictionary *m in self.messages) {
		if ([m[@"id"] isKindOfClass:[NSNumber class]] && [m[@"id"] longLongValue] == messageId)
			return m;
	}
	return nil;
}

- (BOOL)messageSupportsTextEdit:(NSDictionary *)m {
	NSString *kind = [m[@"kind"] isKindOfClass:[NSString class]] ? m[@"kind"] : nil;
	if (!kind.length)
		return NO;
	if ([kind isEqualToString:@"messageText"])
		return YES;
	return [@[ @"messagePhoto", @"messageVideo", @"messageAnimation",
		@"messageDocument", @"messageAudio", @"messageVoiceNote" ] containsObject:kind];
}

- (NSString *)stampForMessage:(NSDictionary *)m {
	double when = [m[@"sendDate"] isKindOfClass:[NSNumber class]]
		? [m[@"sendDate"] doubleValue]
		: 0;
	if (when <= 0)
		return TGL(@"ScheduledMessages.ScheduledOnline", @"Scheduled until online");
	return [TGDateUtils stringForFullDateAndTime:(int)when];
}

- (NSString *)previewForMessage:(NSDictionary *)m {
	if (self.previewOfMessage) {
		NSString *made = self.previewOfMessage(m);
		if (made.length)
			return made;
	}
	NSString *text = [m[@"text"] isKindOfClass:[NSString class]] ? m[@"text"] : nil;
	if (text.length)
		return text;
	return [m[@"kind"] isKindOfClass:[NSString class]] ? m[@"kind"] : TGL(@"Call.Message", @"Message");
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.messages.count;
}

- (NSString *)tableView:(UITableView *)tableView
	titleForFooterInSection:(NSInteger)section {
	return TGScheduledFooterText(self.loaded, self.loadFailed, self.messages.count, self.remindersStyle);
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

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *reuse = @"TGScheduledCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:reuse];
	[[TGTheme shared] styleCell:cell];

	NSDictionary *m = [self messageAtRow:indexPath.row];
	cell.textLabel.text = [self stampForMessage:m];
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.detailTextLabel.text = [self previewForMessage:m];
	cell.detailTextLabel.numberOfLines = 2;
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	return cell;
}

- (CGFloat)tableView:(UITableView *)tableView
	heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 56;
}

- (void)tableView:(UITableView *)tableView
	didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSDictionary *m = [self messageAtRow:indexPath.row];
	if (!m)
		return;
	self.chosenMessageId = [m[@"id"] isKindOfClass:[NSNumber class]] ? [m[@"id"] longLongValue] : 0;

	BOOL canEdit = self.onEdit != nil && [self messageSupportsTextEdit:m];
	NSMutableArray *titles = [NSMutableArray arrayWithObject:
		(self.remindersStyle ? TGL(@"ScheduledMessages.SendNow", @"Remind Me Now") : TGL(@"ScheduledMessages.SendMessageNow", @"Send Now"))];
	if (canEdit)
		[titles addObject:TGL(@"Conversation.MessageDialogEdit", @"Edit")];
	[titles addObject:TGL(@"ScheduledMessages.EditTime", @"Reschedule")];
	[titles addObject:TGL(@"Common.Delete", @"Delete")];

	NSInteger destructiveButtonIndex, cancelButtonIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:[self stampForMessage:m]
					  delegate:self
				   otherTitles:titles
			  destructiveIndex:(NSInteger)titles.count - 1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:&destructiveButtonIndex
			 cancelButtonIndex:&cancelButtonIndex];
	sheet.tag = kItemSheetTag;
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	[sheet tg_showFromRect:cell.frame inView:tableView];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
	if (sheet.tag != kItemSheetTag)
		return;
	int64_t messageId = self.chosenMessageId;
	self.chosenMessageId = 0;
	if (index == sheet.cancelButtonIndex)
		return;

	NSDictionary *m = [self messageWithId:messageId];
	if (!m)
		return;

	BOOL canEdit = self.onEdit != nil && [self messageSupportsTextEdit:m];
	NSInteger editIndex = canEdit ? 1 : -1;
	NSInteger rescheduleIndex = canEdit ? 2 : 1;
	NSInteger deleteIndex = rescheduleIndex + 1;

	if (canEdit && index == editIndex) {
		void (^handler)(NSDictionary *) = self.onEdit;
		[self.navigationController popViewControllerAnimated:YES];
		if (handler)
			handler(m);
		return;
	}
	if (index == rescheduleIndex) {
		void (^handler)(int64_t, NSTimeInterval) = self.onReschedule;
		NSTimeInterval sendDate = [m[@"sendDate"] isKindOfClass:[NSNumber class]] ? [m[@"sendDate"] doubleValue] : 0;
		[self.navigationController popViewControllerAnimated:YES];
		if (handler)
			handler(messageId, sendDate);
		return;
	}
	if (index == deleteIndex) {
		[self deleteMessage:messageId];
		return;
	}
	[self sendMessageNow:messageId];
}

- (void)sendMessageNow:(int64_t)messageId {
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client sendScheduledMessageNow:messageId inChat:self.chatId completion:^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[TGSnackbar showInView:strongSelf.view
							  text:TGL(@"Toast.CouldNotSendScheduledMessage", @"Could not send the scheduled message")
						   seconds:3
						  onCommit:nil];
			return;
		}
		[strongSelf reload];
	}];
}

- (void)deleteMessage:(int64_t)messageId {
	if (!messageId)
		return;
	int64_t chatId = self.chatId;
	[self removeMessageWithId:messageId];

	__weak typeof(self) weakSelf = self;
	[TGSnackbar showInView:self.view
					  text:TGL(@"Chat.DeletedForYou", @"Deleted for you")
				   seconds:5
					  kind:TGSnackbarKindDestructiveUndo
				  onCommit:^{
					  [[TGClient shared] deleteMessages:@[ @(messageId) ] inChat:chatId
											forEveryone:NO
											 completion:^(BOOL ok) {
												 __strong typeof(weakSelf) strongSelf = weakSelf;
												 if (!strongSelf)
													 return;
												 if (!ok) {
													 [TGSnackbar showInView:strongSelf.view
																	  text:TGL(@"Toast.CouldNotDeleteScheduledMessage", @"Could not delete the scheduled message")
																   seconds:3
																  onCommit:nil];
													 [strongSelf reload];
												 }
											 }];
				  }];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{ [weakSelf reload]; });
}

@end

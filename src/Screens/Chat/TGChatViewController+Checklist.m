#import "TGClient+Messages.h"
#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGActionSheet.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGAlertView.h"
#import "TGSnackbar.h"
#import "TGChecklistTasks.h"

@implementation TGChatViewController (Checklist)

- (NSString *)bubbleCell:(TGMessageRowCell *)__unused cell
	checklistTaskTitleAtIndex:(NSUInteger)index
						atRow:(NSInteger)row {
	NSDictionary *m = [self messageAtRow:row];
	NSArray *tasks = m[@"checklistTasks"];
	if (index >= tasks.count)
		return @"";
	id text = tasks[index][@"text"];
	return [text isKindOfClass:NSString.class] ? text : @"";
}

- (BOOL)bubbleCell:(TGMessageRowCell *)__unused cell
	checklistTaskIsCheckedAtIndex:(NSUInteger)index
							atRow:(NSInteger)row {
	NSDictionary *m = [self messageAtRow:row];
	NSArray *tasks = m[@"checklistTasks"];
	if (index >= tasks.count)
		return NO;
	return [tasks[index][@"done"] boolValue];
}

- (NSString *)bubbleCell:(TGMessageRowCell *)__unused cell
	checklistTaskCompletedByAtIndex:(NSUInteger)index
							   atRow:(NSInteger)row {
	NSDictionary *m = [self messageAtRow:row];
	if (![m[@"checklistOthersCanMark"] boolValue])
		return @"";
	NSArray *tasks = m[@"checklistTasks"];
	if (index >= tasks.count)
		return @"";
	id name = tasks[index][@"completedByName"];
	return [name isKindOfClass:NSString.class] ? name : @"";
}

- (void)promptAddChecklistTaskForRow:(NSInteger)row {
	NSDictionary *m = [self messageAtRow:row];
	int64_t messageId = [m[@"id"] longLongValue];
	if (!messageId)
		return;

	self.checklistAddMessageId = messageId;
	UIAlertView *askAlloc = [TGAlertView alloc];
	UIAlertView *ask = [askAlloc initWithTitle:TGL(@"Chat.Todo.ContextMenu.AddTask", @"Add a Task")
									   message:nil
									  delegate:self
							 cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
							 otherButtonTitles:TGL(@"Common.Done", @"Done"), nil];
	if ([ask respondsToSelector:@selector(setAlertViewStyle:)])
		ask.alertViewStyle = UIAlertViewStylePlainTextInput;
	ask.tag = kChecklistAddAlertTag;
	[ask show];
}

- (void)toggleChecklistTaskAtIndex:(NSUInteger)index atRow:(NSInteger)row {
	NSDictionary *m = [self messageAtRow:row];
	int64_t messageId = [m[@"id"] longLongValue];
	NSArray *tasks = m[@"checklistTasks"];
	if (!messageId || index >= tasks.count)
		return;
	NSDictionary *task = tasks[index];
	int32_t taskId = [task[@"id"] intValue];
	BOOL currentlyDone = [task[@"done"] boolValue];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] markChecklistTask:taskId
									done:!currentlyDone
							   inMessage:messageId
									chat:self.chatId
							  completion:^(BOOL ok) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[TGSnackbar showInView:strongSelf.view
							   text:TGL(@"Toast.CouldNotUpdateChecklistTask", @"Could not update the task")
							seconds:3
						   onCommit:nil];
			return;
		}
		[strongSelf reload];
	}];
}

- (void)handleChecklistAddAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	int64_t messageId = self.checklistAddMessageId;
	self.checklistAddMessageId = 0;
	if (buttonIndex == alertView.cancelButtonIndex || !messageId)
		return;
	NSString *text = [self textInAlert:alertView];
	if (!text.length)
		return;

	NSDictionary *m = [self messageAtRow:[self rowForMessageId:messageId]];
	int32_t nextId = TGNextChecklistTaskId(m[@"checklistTasks"]);

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] addChecklistTaskId:nextId
									 text:text
								inMessage:messageId
									 chat:self.chatId
							   completion:^(BOOL ok) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[TGSnackbar showInView:strongSelf.view
							   text:TGL(@"Toast.CouldNotAddChecklistTask", @"Could not add the task")
							seconds:3
						   onCommit:nil];
			return;
		}
		[strongSelf reload];
	}];
}

- (void)showChecklistTaskMenuAtIndex:(NSUInteger)index atRow:(NSInteger)row {
	NSDictionary *m = [self messageAtRow:row];
	int64_t messageId = [m[@"id"] longLongValue];
	NSArray *tasks = m[@"checklistTasks"];
	if (!messageId || index >= tasks.count)
		return;
	if (![m[@"canBeEdited"] boolValue])
		return;

	NSDictionary *task = tasks[index];
	id text = task[@"text"];

	self.checklistMenuMessageId = messageId;
	self.checklistMenuTaskId = [task[@"id"] intValue];
	self.checklistMenuTaskText = [text isKindOfClass:NSString.class] ? text : @"";

	UIActionSheet *sheetAlloc = [UIActionSheet alloc];
	UIActionSheet *sheet = [sheetAlloc initWithTitle:nil
											delegate:self
								   cancelButtonTitle:nil
							  destructiveButtonTitle:nil
								   otherButtonTitles:TGL(@"Chat.Todo.ContextMenu.EditTask", @"Edit Task"),
		TGL(@"Chat.Todo.ContextMenu.DeleteTask", @"Delete Task"), nil];
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
	sheet.tag = kChecklistTaskMenuSheetTag;
	NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:0];
	UITableViewCell *cell = [self.table cellForRowAtIndexPath:path];
	[sheet tg_showFromRect:cell.frame inView:self.table];
}

- (void)runChecklistTaskMenuOption:(NSString *)chosen {
	int64_t messageId = self.checklistMenuMessageId;
	int32_t taskId = self.checklistMenuTaskId;
	NSString *text = self.checklistMenuTaskText;
	self.checklistMenuMessageId = 0;
	self.checklistMenuTaskId = 0;
	self.checklistMenuTaskText = nil;
	if (!messageId || !chosen.length)
		return;

	if ([chosen isEqualToString:TGL(@"Chat.Todo.ContextMenu.EditTask", @"Edit Task")]) {
		self.checklistEditMessageId = messageId;
		self.checklistEditTaskId = taskId;
		[self promptEditChecklistTaskWithText:text];
	} else if ([chosen isEqualToString:TGL(@"Chat.Todo.ContextMenu.DeleteTask", @"Delete Task")]) {
		self.checklistDeleteMessageId = messageId;
		self.checklistDeleteTaskId = taskId;
		[self promptDeleteChecklistTask];
	}
}

- (void)promptEditChecklistTaskWithText:(NSString *)text {
	UIAlertView *askAlloc = [TGAlertView alloc];
	UIAlertView *ask = [askAlloc initWithTitle:TGL(@"Chat.Todo.ContextMenu.EditTask", @"Edit Task")
										   message:nil
										  delegate:self
								 cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
								 otherButtonTitles:TGL(@"Common.Done", @"Done"), nil];
	if ([ask respondsToSelector:@selector(setAlertViewStyle:)])
		ask.alertViewStyle = UIAlertViewStylePlainTextInput;
	if ([ask respondsToSelector:@selector(textFieldAtIndex:)])
		[ask textFieldAtIndex:0].text = text;
	ask.tag = kChecklistEditAlertTag;
	[ask show];
}

- (void)promptDeleteChecklistTask {
	UIActionSheet *sheetAlloc = [UIActionSheet alloc];
	UIActionSheet *sheet = [sheetAlloc initWithTitle:nil
											delegate:self
								   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
							  destructiveButtonTitle:TGL(@"Common.Delete", @"Delete")
								   otherButtonTitles:nil];
	sheet.tag = kChecklistDeleteTaskSheetTag;
	NSInteger row = [self rowForMessageId:self.checklistDeleteMessageId];
	NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:0];
	UITableViewCell *cell = [self.table cellForRowAtIndexPath:path];
	[sheet tg_showFromRect:cell.frame inView:self.table];
}

- (void)handleChecklistEditAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	int64_t messageId = self.checklistEditMessageId;
	int32_t taskId = self.checklistEditTaskId;
	self.checklistEditMessageId = 0;
	self.checklistEditTaskId = 0;
	if (buttonIndex == alertView.cancelButtonIndex || !messageId)
		return;
	NSString *text = [self textInAlert:alertView];
	if (!text.length)
		return;

	NSDictionary *m = [self messageAtRow:[self rowForMessageId:messageId]];
	if (!m)
		return;

	NSArray *updated = TGChecklistTasksByReplacingTaskId(m[@"checklistTasks"], taskId, text);

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] replaceChecklistTasks:updated
									   title:(m[@"checklistTitle"] ?: @"")
		othersCanAdd:[m[@"checklistOthersCanAdd"] boolValue]
							   othersCanMark:[m[@"checklistOthersCanMark"] boolValue]
								   inMessage:messageId
										chat:self.chatId
								  completion:^(BOOL ok) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[TGSnackbar showInView:strongSelf.view
							   text:TGL(@"Toast.CouldNotEditChecklistTask", @"Could not edit the task")
							seconds:3
						   onCommit:nil];
			return;
		}
		[strongSelf reload];
	}];
}

- (void)performDeleteChecklistTask {
	int64_t messageId = self.checklistDeleteMessageId;
	int32_t taskId = self.checklistDeleteTaskId;
	self.checklistDeleteMessageId = 0;
	self.checklistDeleteTaskId = 0;
	if (!messageId)
		return;

	NSDictionary *m = [self messageAtRow:[self rowForMessageId:messageId]];
	if (!m)
		return;

	NSArray *updated = TGChecklistTasksByRemovingTaskId(m[@"checklistTasks"], taskId);

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] replaceChecklistTasks:updated
									   title:(m[@"checklistTitle"] ?: @"")
		othersCanAdd:[m[@"checklistOthersCanAdd"] boolValue]
							   othersCanMark:[m[@"checklistOthersCanMark"] boolValue]
								   inMessage:messageId
										chat:self.chatId
								  completion:^(BOOL ok) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[TGSnackbar showInView:strongSelf.view
							   text:TGL(@"Toast.CouldNotDeleteChecklistTask", @"Could not delete the task")
							seconds:3
						   onCommit:nil];
			return;
		}
		[strongSelf reload];
	}];
}

@end

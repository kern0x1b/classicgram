#import "TGTopicsViewController.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGChatViewController.h"
#import "TGClient.h"
#import "TGClient+Forums.h"
#import "TGClient+Notifications.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGActionSheet.h"
#import "TGPopupMenu.h"
#import "TGDateUtils.h"
#import "TGDateLabel.h"
#import "UIView+SafeTint.h"
#import <QuartzCore/QuartzCore.h>
#import "TGAlertView.h"

#import "TGTopicsViewControllerInternal.h"

@implementation TGTopicsViewController (TopicActions)

#pragma mark - topic actions

- (int32_t)topicIdOf:(NSDictionary *)topic {
	int32_t topicId = (int32_t)TGTopicInteger(topic, @"topicId");
	if (topicId == 0)
		topicId = (int32_t)TGTopicLongLong(topic, @"threadId");
	return topicId;
}

- (void)showError:(NSString *)message {
	[[[UIAlertView alloc] initWithTitle:nil message:message delegate:nil
					  cancelButtonTitle:TGL(@"Common.OK", @"OK")
					  otherButtonTitles:nil] show];
}

- (BOOL)topicIsMuted:(NSDictionary *)topic {
	return TGTopicInteger(topic, @"muteFor") > 0;
}

- (NSInteger)pinnedCount {
	NSInteger count = 0;
	for (NSDictionary *topic in self.topics) {
		if (TGTopicFlag(topic, @"isPinned"))
			count++;
		else
			break;
	}
	return count;
}

- (void)topicHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan || self.reordering)
		return;

	NSIndexPath *path = [self.tableView indexPathForRowAtPoint:
			[hold locationInView:self.tableView]];
	NSArray *rows = [self displayedTopics];
	if (!path || path.row >= (NSInteger)rows.count)
		return;

	NSDictionary *t = rows[path.row];
	self.actionTopic = t;

	NSMutableArray *items = [NSMutableArray array];
	NSMutableArray *keys = [NSMutableArray array];
	[self appendMenuItemsForTopic:t intoItems:items keys:keys];

	CGRect rect = [self.tableView rectForRowAtIndexPath:path];
	CGPoint where = [self.tableView convertPoint:
			CGPointMake(120, CGRectGetMaxY(rect) - 10)
										  toView:self.navigationController.view];
	self.menuPoint = where;

	__weak typeof(self) weakSelf = self;
	[TGPopupMenu showItems:items atPoint:where inView:self.navigationController.view
				  onChoice:^(NSInteger choice, NSString *title) {
					  if (choice < 0 || choice >= (NSInteger)keys.count)
						  return;
					  [weakSelf runTopicAction:keys[choice]];
				  }];
}

- (void)appendMenuItemsForTopic:(NSDictionary *)t
					  intoItems:(NSMutableArray *)items
						   keys:(NSMutableArray *)keys {
	BOOL general = TGTopicFlag(t, @"isGeneral");
	BOOL closed = TGTopicFlag(t, @"isClosed");
	BOOL pinned = TGTopicFlag(t, @"isPinned");
	BOOL hidden = TGTopicFlag(t, @"isHidden");

	BOOL canEdit = [self canEditTopic:t];

	if (!general && canEdit) {
		[items addObject:@{@"title" : TGL(@"Common.Edit", @"Edit"), @"icon" : @"edit"}];
		[keys addObject:@"edit"];
	}
	if (self.canManageTopics) {
		[items addObject:@{@"title" : (pinned ? TGL(@"ChatList.Context.Unpin", @"Unpin") : TGL(@"ChatList.Context.Pin", @"Pin")),
			@"icon" : (pinned ? @"unpin" : @"pin")}];
		[keys addObject:@"pin"];
	}

	if (!general && canEdit) {
		[items addObject:@{@"title" : (closed ? TGL(@"ChatList.Context.ReopenTopic", @"Reopen") : TGL(@"ChatList.Context.CloseTopic", @"Close")),
			@"icon" : (closed ? @"unmute" : @"mute")}];
		[keys addObject:@"close"];
	}
	if (general && self.canManageTopics) {
		[items addObject:@{@"title" : (hidden ? TGL(@"ChatList.ThreadUnhideAction", @"Unhide") : TGL(@"ChatList.ThreadHideAction", @"Hide")),
			@"icon" : (hidden ? @"unmute" : @"mute")}];
		[keys addObject:@"hide"];
	}

	BOOL muted = [self topicIsMuted:t];
	[items addObject:@{@"title" : (muted ? TGL(@"ChatList.Context.Unmute", @"Unmute") : TGL(@"ChatList.Context.Mute", @"Mute")),
		@"icon" : (muted ? @"unmute" : @"mute")}];
	[keys addObject:@"mute"];

	if (TGTopicInteger(t, @"unread") > 0 || TGTopicInteger(t, @"unreadMentions") > 0 || TGTopicInteger(t, @"unreadReactions") > 0) {
		[items addObject:@{@"title" : TGL(@"ChatList.Context.MarkAsRead", @"Mark as Read"), @"icon" : @"unmute"}];
		[keys addObject:@"read"];
	}

	[items addObject:@{@"title" : TGL(@"Conversation.ContextMenuCopyLink", @"Copy Link"), @"icon" : @"copy"}];
	[keys addObject:@"link"];

	[items addObject:@{@"title" : TGL(@"Topics.TopicInfo", @"Topic Info"), @"icon" : @"more"}];
	[keys addObject:@"info"];

	if (pinned && !self.searchResults && self.canManageTopics && [self pinnedCount] > 1) {
		[items addObject:@{@"title" : TGL(@"Chat.InlineTopicMenu.Reorder", @"Reorder Pins"), @"icon" : @"pin"}];
		[keys addObject:@"reorder"];
	}

	if (!general && [self canDeleteTopic:t]) {
		[items addObject:@{@"title" : TGL(@"Common.Delete", @"Delete"),
			@"icon" : @"delete",
			@"destructive" : @YES}];
		[keys addObject:@"delete"];
	}
}

- (void)runTopicAction:(NSString *)key {
	NSDictionary *t = self.actionTopic;
	if (!t)
		return;

	int32_t topicId = [self topicIdOf:t];

	if ([key isEqualToString:@"edit"]) {
		[self askTopicNameForEdit:t];
		return;
	}

	if ([key isEqualToString:@"info"]) {
		[self openTopicInfoForTopic:t topicId:topicId];
		return;
	}

	if ([key isEqualToString:@"pin"]) {
		[self setTopic:topicId pinned:!TGTopicFlag(t, @"isPinned")];
	} else if ([key isEqualToString:@"close"]) {
		[self setTopic:topicId closed:!TGTopicFlag(t, @"isClosed")];
	} else if ([key isEqualToString:@"mute"]) {
		if ([self topicIsMuted:t]) {
			[self unmuteTopic:topicId];
		} else {
			[self showMuteDurationsForTopic:topicId];
			return;
		}
	} else if ([key isEqualToString:@"read"]) {
		[self markTopicRead:topicId];
	} else if ([key isEqualToString:@"link"]) {
		[self copyLinkForTopic:topicId];
	} else if ([key isEqualToString:@"reorder"]) {
		[self beginReordering];
		return;
	} else if ([key isEqualToString:@"delete"]) {
		[self confirmDeleteTopic:t];
		return;
	} else if ([key isEqualToString:@"hide"]) {
		[self setGeneralTopicHidden:!TGTopicFlag(t, @"isHidden")];
	}

	self.actionTopic = nil;
}

- (void)openTopicInfoForTopic:(NSDictionary *)t topicId:(int32_t)topicId {
	self.actionTopic = nil;
	if (topicId == 0) {
		[self showError:TGL(@"Topics.CouldNotLoad", @"Could not load the topic.")];
		return;
	}
	TGTopicInfoController *info = [[TGTopicInfoController alloc]
		initWithStyle:UITableViewStyleGrouped];
	info.chatId = self.chatId;
	info.topicId = topicId;
	info.topicName = TGTopicString(t, @"name");
	info.canPinMessages = self.canPinMessages;
	[self.navigationController pushViewController:info animated:YES];
}

- (void)showPinLimitReachedAlert {
	NSInteger max = [TGClient shared].pinnedForumTopicCountMax;
	NSString *message = TGLPlural(@"ChatList.MaxThreadPinsFinalText", max,
		@"Sorry, you can't pin more than %@ topic to the top. Unpin some that are currently pinned.",
		@"Sorry, you can't pin more than %@ topics to the top. Unpin some that are currently pinned.");
	TGAlertView *alert = [[TGAlertView alloc]
		initWithTitle:TGL(@"Premium.LimitReached", @"Limit Reached")
			  message:message
	  cancelButtonTitle:TGL(@"Common.OK", @"OK")
			okButtonTitle:nil
		  completionBlock:nil];
	[alert show];
}

- (void)setTopic:(int32_t)topicId pinned:(BOOL)pin {
	if (pin && [self pinnedCount] + 1 > [TGClient shared].pinnedForumTopicCountMax) {
		[self showPinLimitReachedAlert];
		return;
	}
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client setForumTopicInChat:self.chatId topic:topicId pinned:pin completion:^(BOOL success) {
		if (!success)
			[weakSelf showError:pin ? TGL(@"Topics.CouldNotPin", @"Could not pin the topic.") : TGL(@"Topics.CouldNotUnpin", @"Could not unpin the topic.")];
		[weakSelf reloadTopics];
	}];
}

- (void)setTopic:(int32_t)topicId closed:(BOOL)close {
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client setForumTopicInChat:self.chatId topic:topicId closed:close completion:^(BOOL success) {
		if (!success)
			[weakSelf showError:close ? TGL(@"Topics.CouldNotClose", @"Could not close the topic.") : TGL(@"Topics.CouldNotReopen", @"Could not reopen the topic.")];
		[weakSelf reloadTopics];
	}];
}

- (void)unmuteTopic:(int32_t)topicId {
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client setForumTopicInChat:self.chatId topic:topicId mutedFor:0 completion:^(BOOL success) {
		if (!success)
			[weakSelf showError:TGL(@"Topics.CouldNotUnmute", @"Could not unmute the topic.")];
		[weakSelf reloadTopics];
	}];
}

- (void)markTopicRead:(int32_t)topicId {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] markForumTopicReadInChat:self.chatId topic:topicId
									 completion:^(BOOL success) {
										 if (!success)
											 [weakSelf showError:TGL(@"Topics.CouldNotMarkRead", @"Could not mark the topic as read.")];
										 [weakSelf reloadTopics];
									 }];
}

- (void)copyLinkForTopic:(int32_t)topicId {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] forumTopicLinkInChat:self.chatId topic:topicId
								 completion:^(NSString *link) {
									 if (link.length)
										 [UIPasteboard generalPasteboard].string = link;
									 else
										 [weakSelf showError:TGL(@"Topics.CouldNotGetLink", @"Could not get a link to the topic.")];
								 }];
}

- (void)setGeneralTopicHidden:(BOOL)hide {
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client setGeneralForumTopicInChat:self.chatId hidden:hide completion:^(BOOL success) {
		if (!success)
			[weakSelf showError:hide ? TGL(@"Topics.CouldNotHideGeneral", @"Could not hide the General topic.") : TGL(@"Topics.CouldNotShowGeneral", @"Could not show the General topic.")];
		[weakSelf reloadTopics];
	}];
}

- (void)showMuteDurationsForTopic:(int32_t)topicId {
	NSArray *items = @[
		@{@"title" : TGL(@"Notification.Mute1h", @"Mute for 1 hour"), @"icon" : @"mute"},
		@{@"title" : TGLPlural(@"MuteFor.Hours", 8, @"Mute for %@ hour", @"Mute for %@ hours"), @"icon" : @"mute"},
		@{@"title" : TGL(@"MuteFor.Days_2", @"Mute for 2 days"), @"icon" : @"mute"},
		@{@"title" : TGL(@"MuteFor.Forever", @"Mute forever"), @"icon" : @"mute"},
	];
	NSArray *seconds = @[ @(3600), @(8 * 3600), @(2 * 24 * 3600), @(kNotificationMuteForever) ];

	__weak typeof(self) weakSelf = self;
	[TGPopupMenu showItems:items atPoint:self.menuPoint inView:self.navigationController.view onChoice:^(NSInteger choice, NSString *title) {
		TGTopicsViewController *strongSelf = weakSelf;
		if (!strongSelf || choice < 0 || choice >= (NSInteger)seconds.count)
			return;
		strongSelf.actionTopic = nil;
		TGClient *client = [TGClient shared];
		[client setForumTopicInChat:strongSelf.chatId topic:topicId mutedFor:[seconds[choice] integerValue] completion:^(BOOL success) {
			if (!success)
				[weakSelf showError:TGL(@"Topics.CouldNotMute", @"Could not mute the topic.")];
			[weakSelf reloadTopics];
		}];
	}];
}

- (void)confirmDeleteTopic:(NSDictionary *)topic {
	self.actionTopic = topic;
	NSString *name = TGTopicString(topic, @"name");
	if (!name.length)
		name = TGL(@"Topics.FallbackName", @"this topic");
	NSString *question = [NSString stringWithFormat:TGL(@"ChatList.DeleteTopicConfirmationText", @"Delete %@ and all of its messages?"), name];
	UIAlertView *alert = [UIAlertView alloc];
	alert = [alert initWithTitle:TGL(@"ChatList.DeleteTopicConfirmationAction", @"Delete Topic")
						 message:question
						delegate:self
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			   otherButtonTitles:TGL(@"Common.Delete", @"Delete"), nil];
	alert.tag = kTopicDeleteAlert;
	[alert show];
}

@end

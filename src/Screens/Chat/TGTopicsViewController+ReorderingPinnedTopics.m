#import "TGTopicsViewController.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGChatViewController.h"
#import "TGClient.h"
#import "TGClient+Forums.h"
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

@implementation TGTopicsViewController (ReorderingPinnedTopics)

#pragma mark - reordering pinned topics

- (void)beginReordering {
	if ([self pinnedCount] < 2)
		return;

	self.actionTopic = nil;
	self.reordering = YES;
	self.orderDirty = NO;
	[self.tableView setEditing:YES animated:YES];

	UIButton *done = [TGIcons headerButtonWithTitle:TGL(@"Common.Done", @"Done") bold:YES
											 target:self
											 action:@selector(finishReordering)];
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:done];
}

- (void)finishReordering {
	self.reordering = NO;
	[self.tableView setEditing:NO animated:YES];
	[self updateCreateButton];

	BOOL remoteChangeWhileReordering = self.reloadPendingAfterReorder;
	self.reloadPendingAfterReorder = NO;

	if (!self.orderDirty) {
		[self reloadTopics];
		return;
	}
	self.orderDirty = NO;

	NSArray *ids = [self pinnedTopicIdsFromTopics:self.topics];
	if (ids.count < 2) {
		[self reloadTopics];
		return;
	}

	if (!remoteChangeWhileReordering) {
		[self sendPinnedTopicOrder:ids];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] forumTopicsForChat:self.chatId
									query:nil
							   offsetDate:0
						  offsetMessageId:0
							offsetTopicId:0
									limit:40
							   completion:^(NSArray *topics, NSDictionary *nextOffset, NSInteger totalCount) {
								   TGTopicsViewController *strongSelf = weakSelf;
								   if (!strongSelf)
									   return;
								   NSArray *latest = [strongSelf cleanedTopics:topics];
								   NSArray *reconciled = [strongSelf reconcilePinnedOrder:ids withLatestTopics:latest];
								   if (reconciled.count < 2) {
									   [strongSelf reloadTopics];
									   return;
								   }
								   [strongSelf sendPinnedTopicOrder:reconciled];
							   }];
}

- (void)sendPinnedTopicOrder:(NSArray *)ids {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setPinnedForumTopicsInChat:self.chatId topicIds:ids
									   completion:^(BOOL success) {
										   if (!success)
											   [weakSelf showError:TGL(@"Topics.CouldNotReorder", @"Could not save the order of the pinned topics.")];
										   [weakSelf reloadTopics];
									   }];
}

- (NSArray *)pinnedTopicIdsFromTopics:(NSArray *)topics {
	NSMutableArray *ids = [NSMutableArray array];
	for (NSDictionary *topic in topics) {
		if (!TGTopicFlag(topic, @"isPinned"))
			continue;
		int32_t topicId = [self topicIdOf:topic];
		if (topicId != 0)
			[ids addObject:@(topicId)];
	}
	return ids;
}

- (NSArray *)reconcilePinnedOrder:(NSArray *)localOrderIds withLatestTopics:(NSArray *)latestTopics {
	NSArray *latestPinnedIds = [self pinnedTopicIdsFromTopics:latestTopics];
	NSSet *latestPinnedSet = [NSSet setWithArray:latestPinnedIds];

	NSMutableArray *reconciled = [NSMutableArray array];
	for (NSNumber *topicId in localOrderIds) {
		if ([latestPinnedSet containsObject:topicId])
			[reconciled addObject:topicId];
	}
	for (NSNumber *topicId in latestPinnedIds) {
		if (![reconciled containsObject:topicId])
			[reconciled addObject:topicId];
	}
	return reconciled;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
	return self.reordering && !self.searchResults && indexPath.row < [self pinnedCount];
}

- (BOOL)canDeleteTopicAtRow:(NSInteger)row {
	NSArray *rows = [self displayedTopics];
	if (row < 0 || row >= (NSInteger)rows.count)
		return NO;
	NSDictionary *topic = rows[row];
	if (TGTopicFlag(topic, @"isGeneral"))
		return NO;
	return [self canDeleteTopic:topic];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.reordering)
		return YES;
	return [self canDeleteTopicAtRow:indexPath.row];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
		   editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.reordering)
		return UITableViewCellEditingStyleNone;
	return [self canDeleteTopicAtRow:indexPath.row]
		? UITableViewCellEditingStyleDelete
		: UITableViewCellEditingStyleNone;
}

- (void)tableView:(UITableView *)tableView
	commitEditingStyle:(UITableViewCellEditingStyle)style
	 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (style != UITableViewCellEditingStyleDelete || self.reordering)
		return;
	NSArray *rows = [self displayedTopics];
	if (indexPath.row >= (NSInteger)rows.count)
		return;
	[tableView setEditing:NO animated:YES];
	[self confirmDeleteTopic:rows[indexPath.row]];
}

- (BOOL)tableView:(UITableView *)tableView
	shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
	return NO;
}

- (NSIndexPath *)tableView:(UITableView *)tableView
	targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)from
						 toProposedIndexPath:(NSIndexPath *)proposed {
	NSInteger last = [self pinnedCount] - 1;
	if (last < 0)
		return from;
	if (proposed.row > last)
		return [NSIndexPath indexPathForRow:last inSection:0];
	return proposed;
}

- (void)tableView:(UITableView *)tableView
	moveRowAtIndexPath:(NSIndexPath *)from
		   toIndexPath:(NSIndexPath *)to {
	NSInteger pinned = [self pinnedCount];
	if (from.row >= pinned || from.row >= (NSInteger)self.topics.count)
		return;

	NSMutableArray *ordered = [self.topics mutableCopy];
	NSDictionary *topic = ordered[from.row];
	[ordered removeObjectAtIndex:from.row];
	NSInteger target = MIN(MAX(to.row, 0), pinned - 1);
	[ordered insertObject:topic atIndex:target];
	self.topics = ordered;
	self.orderDirty = YES;
}

@end

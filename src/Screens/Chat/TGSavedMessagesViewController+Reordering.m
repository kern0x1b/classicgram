#import "TGSavedMessagesViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+SavedMessages.h"
#import "TGIcons.h"
#import "TGLocalization.h"

@implementation TGSavedMessagesViewController (Reordering)

- (NSInteger)pinnedCount {
	NSInteger count = 0;
	for (NSDictionary *topic in self.topics) {
		if ([topic[@"isPinned"] boolValue])
			count++;
		else
			break;
	}
	return count;
}

- (void)beginReordering {
	if ([self pinnedCount] < 2)
		return;

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
	[self showListButtons];

	if (!self.orderDirty) {
		[self applyCachedTopics];
		return;
	}
	self.orderDirty = NO;

	NSMutableArray *ids = [NSMutableArray array];
	for (NSDictionary *topic in self.topics) {
		if (![topic[@"isPinned"] boolValue])
			break;
		int64_t topicId = [topic[@"id"] longLongValue];
		if (topicId)
			[ids addObject:@(topicId)];
	}
	if (ids.count < 2) {
		[self applyCachedTopics];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setPinnedSavedMessagesTopics:ids completion:^(BOOL ok) {
		if (!ok)
			[weakSelf showError:TGL(@"Topics.CouldNotReorder", @"Could not save the order of the pinned topics.")];
		[weakSelf applyCachedTopics];
	}];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
	return self.reordering && [self sectionHoldsTopics:indexPath.section] && !self.query.length && indexPath.row < [self pinnedCount];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return self.reordering && [self sectionHoldsTopics:indexPath.section] && !self.query.length;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
		   editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
	return UITableViewCellEditingStyleNone;
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

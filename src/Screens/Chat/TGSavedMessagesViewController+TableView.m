#import "TGClient+ChatManagement.h"
#import "TGSavedMessagesViewControllerInternal.h"
#import "TGChatViewController.h"
#import "TGClient.h"
#import "TGClient+SavedMessages.h"
#import "TGLocalization.h"

@implementation TGSavedMessagesViewController (TableView)

- (BOOL)showsTopicSection {
	return self.scope == kSavedScopeChats;
}

- (BOOL)showsMessageSection {
	return self.scope != kSavedScopeChats || self.query.length > 0;
}

- (NSArray *)topicRows {
	return self.query.length ? self.topicHits : self.topics;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	NSInteger sections = 0;
	if ([self showsTopicSection])
		sections++;
	if ([self showsMessageSection])
		sections++;
	return sections ?: 1;
}

- (BOOL)sectionHoldsTopics:(NSInteger)section {
	return [self showsTopicSection] && section == 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if ([self sectionHoldsTopics:section])
		return (NSInteger)[self topicRows].count;
	return [self showsMessageSection] ? (NSInteger)self.messageHits.count : 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return [self sectionHoldsTopics:indexPath.section]
		? kSavedRowHeight
		: kSavedMessageRowHeight;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (!self.query.length || self.scope != kSavedScopeChats)
		return nil;
	if ([self tableView:tableView numberOfRowsInSection:section] == 0)
		return nil;
	return [self sectionHoldsTopics:section]
		? TGL(@"DialogList.TabTitle", @"Chats")
		: TGL(@"DialogList.SearchSectionMessages", @"Messages");
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell
	forRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([self sectionHoldsTopics:indexPath.section]) {
		if (self.reordering || self.loading || self.query.length)
			return;
		if (indexPath.row < (NSInteger)self.topics.count - 1)
			return;
		if ((NSInteger)self.topics.count >= [[TGClient shared] savedMessagesTopicCount])
			return;
		[self reloadTopics];
		return;
	}

	if (![self showsMessageSection] || !self.messagesCanLoadMore)
		return;
	if (indexPath.row < (NSInteger)self.messageHits.count - 1)
		return;
	[self loadMoreMessages];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (![self sectionHoldsTopics:indexPath.section]) {
		[self openMessageAtRow:indexPath.row];
		return;
	}

	NSArray *rows = [self topicRows];
	if (self.reordering || indexPath.row >= (NSInteger)rows.count)
		return;

	[self openTopic:rows[indexPath.row]];
}

- (void)openTopic:(NSDictionary *)topic {
	int64_t topicId = [topic[@"id"] longLongValue];
	int64_t chatId = [[TGClient shared] savedMessagesChatId];
	if (!topicId || !chatId)
		return;

	TGChatViewController *vc = [[TGChatViewController alloc] init];
	vc.chatId = chatId;
	vc.savedTopicId = topicId;
	vc.savedTopicOriginChatId = [topic[@"chatId"] longLongValue];
	vc.chatTitle = TGSavedTopicTitle(topic);
	[self presentSavedChat:vc];
}

- (void)openMessageAtRow:(NSInteger)row {
	if (row < 0 || row >= (NSInteger)self.messageHits.count)
		return;

	int64_t chatId = [[TGClient shared] savedMessagesChatId];
	if (!chatId)
		return;

	TGChatViewController *vc = [[TGChatViewController alloc] init];
	vc.chatId = chatId;
	vc.chatTitle = TGL(@"Settings.SavedMessages", @"Saved Messages");
	vc.focusMessageId = [self.messageHits[row][@"id"] longLongValue];
	[self presentSavedChat:vc];
}

@end

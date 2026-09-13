#import "TGTopicInfoController.h"
#import "TGTopicsViewControllerInternal.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGActionSheet.h"
#import "TGLocalization.h"
#import "TGClient.h"
#import "TGClient+Forums.h"
#import "TGAlertView.h"
#import "TGTopicMuteText.h"
#import "TGSnackbar.h"

@interface TGTopicInfoController ()

@property (nonatomic, strong) id forumTopicObserverToken;

@end

@implementation TGTopicInfoController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"Topics.TopicInfo", @"Topic Info");
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];

	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	self.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tableView.separatorColor = [[TGTheme shared] separatorColour];
	self.details = @[];
	self.recent = @[];

	[self rebuildDetails];
	[self loadTopic];
	[self loadRecent];

	__weak typeof(self) weakSelf = self;
	self.forumTopicObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGForumTopicDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf forumTopicChanged:note];
				}];
}

- (void)dealloc {
	if (self.forumTopicObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.forumTopicObserverToken];
}

- (void)forumTopicChanged:(NSNotification *)note {
	int64_t chatId = [note.userInfo[TGForumTopicChatIdKey] longLongValue];
	int32_t topicId = [note.userInfo[TGForumTopicTopicIdKey] intValue];
	if (chatId != self.chatId || topicId != self.topicId)
		return;
	[self loadTopic];
	[self loadRecent];
}

- (void)loadTopic {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] forumTopic:self.topicId inChat:self.chatId
					   completion:^(NSDictionary *topic) {
						   TGTopicInfoController *strongSelf = weakSelf;
						   if (!strongSelf)
							   return;
						   if (![topic isKindOfClass:NSDictionary.class])
							   return;
						   strongSelf.topic = topic;
						   NSString *name = TGTopicString(topic, @"name");
						   if (name.length)
							   strongSelf.topicName = name;
						   [strongSelf rebuildDetails];
						   [strongSelf.tableView reloadData];
					   }];
}

- (void)loadRecent {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared]
		forumTopicHistoryForChat:self.chatId
						   topic:self.topicId
					 fromMessage:0
						   limit:5
					  completion:^(NSArray *messages) {
						  TGTopicInfoController *strongSelf = weakSelf;
						  if (!strongSelf)
							  return;
						  NSMutableArray *clean = [NSMutableArray array];
						  if ([messages isKindOfClass:NSArray.class]) {
							  for (id message in messages) {
								  if ([message isKindOfClass:NSDictionary.class])
									  [clean addObject:message];
							  }
						  }
						  strongSelf.recent = clean;
						  [strongSelf.tableView reloadData];
					  }];
}

- (void)rebuildDetails {
	NSDictionary *t = self.topic;
	NSMutableArray *rows = [NSMutableArray array];

	NSString *name = self.topicName.length ? self.topicName : TGL(@"Topics.Info.DefaultTopicName", @"Topic");
	[rows addObject:@[ TGL(@"Checkout.Name", @"Name"), name ]];

	if (t) {
		[rows addObject:@[ TGL(@"SecretChat.Status", @"Status"),
			TGTopicFlag(t, @"isClosed") ? TGL(@"Topics.Info.Closed", @"Closed") : TGL(@"Topics.Info.Open", @"Open") ]];
		if (TGTopicFlag(t, @"isGeneral"))
			[rows addObject:@[ TGL(@"Topics.Info.GeneralLabel", @"General"),
				TGTopicFlag(t, @"isHidden") ? TGL(@"Topics.Hidden", @"Hidden") : TGL(@"Topics.Info.Shown", @"Shown") ]];
		[rows addObject:@[ TGL(@"Topics.Info.PinnedLabel", @"Pinned"),
			TGTopicFlag(t, @"isPinned") ? TGL(@"Common.Yes", @"Yes") : TGL(@"Common.No", @"No") ]];
		[rows addObject:@[ TGL(@"Notifications.Title", @"Notifications"),
			TGTopicMuteText(TGTopicInteger(t, @"muteFor")) ]];
		[rows addObject:@[ TGL(@"DialogList.Unread", @"Unread"),
			[NSString stringWithFormat:@"%ld", (long)TGTopicInteger(t, @"unread")] ]];
		NSInteger mentions = TGTopicInteger(t, @"unreadMentions");
		NSInteger reactions = TGTopicInteger(t, @"unreadReactions");
		if (mentions > 0)
			[rows addObject:@[ TGL(@"Settings.Mentions", @"Mentions"), [NSString stringWithFormat:@"%ld", (long)mentions] ]];
		if (reactions > 0)
			[rows addObject:@[ TGL(@"PeerInfo.AllowedReactions.Title", @"Reactions"), [NSString stringWithFormat:@"%ld", (long)reactions] ]];
		double date = TGTopicDouble(t, @"date");
		if (date > 0)
			[rows addObject:@[ TGL(@"Topics.Info.LastMessageLabel", @"Last Message"), TGTopicDate(date) ]];
	}

	self.details = rows;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return self.canPinMessages ? 3 : 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return self.details.count;
	if (section == 1)
		return MAX((NSInteger)1, (NSInteger)self.recent.count);
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 1)
		return TGL(@"Topics.Info.RecentMessagesHeader", @"RECENT MESSAGES");
	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return [[TGTheme shared] groupedHeaderHeightForTitle:
			[self tableView:tableView titleForHeaderInSection:section]];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 2)
		return [TGIcons actionRowHeight];
	return indexPath.section == 1 ? 52.0f : 44.0f;
}

- (UITableViewCell *)messageCellForTableView:(UITableView *)tableView
								   indexPath:(NSIndexPath *)indexPath {
	TGTheme *theme = [TGTheme shared];
	static NSString *reuse = @"TGTopicInfoMessage";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:reuse];
		cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
		cell.textLabel.font = [UIFont systemFontOfSize:15];
		cell.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	}
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.textLabel.textColor = [theme groupedTitleColour];
	cell.detailTextLabel.textColor = [theme secondaryTextColour];

	if (self.recent.count == 0) {
		cell.textLabel.text = TGL(@"Conversation.EmptyPlaceholder", @"No messages here yet");
		cell.textLabel.textColor = [theme secondaryTextColour];
		cell.detailTextLabel.text = @"";
		return cell;
	}

	NSDictionary *message = self.recent[self.recent.count - 1 - (NSUInteger)indexPath.row];
	NSString *text = TGTopicString(message, @"text");
	cell.textLabel.text = text.length ? text : TGL(@"Message.File", @"File");
	NSString *when = TGTopicDate(TGTopicDouble(message, @"date"));
	cell.detailTextLabel.text = TGTopicFlag(message, @"outgoing")
		? [NSString stringWithFormat:TGL(@"Topics.Info.YouAtDateFormat", @"You · %@"), when]
		: when;
	return cell;
}

- (UITableViewCell *)unpinAllCellForTableView:(UITableView *)tableView {
	static NSString *reuse = @"TGTopicInfoAction";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:reuse];
	}
	[TGIcons actionButtonInCell:cell
						  title:TGL(@"Chat.PanelUnpinAllMessages", @"Unpin All Messages")
						   kind:TGActionButtonKindDestructive
						 target:self
						 action:@selector(unpinAllPressed)];
	return cell;
}

- (UITableViewCell *)detailCellForTableView:(UITableView *)tableView
								  indexPath:(NSIndexPath *)indexPath {
	TGTheme *theme = [TGTheme shared];
	static NSString *reuse = @"TGTopicInfoDetail";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:reuse];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.textLabel.textColor = [theme groupedTitleColour];
	cell.detailTextLabel.textColor = [theme secondaryTextColour];
	cell.textLabel.text = @"";
	cell.detailTextLabel.text = @"";

	if (indexPath.row < (NSInteger)self.details.count) {
		NSArray *pair = self.details[indexPath.row];
		cell.textLabel.text = pair[0];
		cell.detailTextLabel.text = pair[1];
	}
	return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 1)
		return [self messageCellForTableView:tableView indexPath:indexPath];
	if (indexPath.section == 2)
		return [self unpinAllCellForTableView:tableView];
	return [self detailCellForTableView:tableView indexPath:indexPath];
}

- (void)unpinAllPressed {
	int64_t chatId = self.chatId;
	int32_t topicId = self.topicId;
	__weak typeof(self) weakSelf = self;
	[TGSnackbar showInView:self.navigationController.view
					   text:TGL(@"Topics.PinnedMessagesRemoved", @"Pinned messages removed.")
					seconds:5
					   kind:TGSnackbarKindDestructiveUndo
				   onCommit:^{
					   [[TGClient shared]
						   unpinAllMessagesInForumTopicInChat:chatId
														topic:topicId
												   completion:^(BOOL success) {
													   TGTopicInfoController *strongSelf = weakSelf;
													   if (!strongSelf)
														   return;
													   if (!success) {
														   [TGSnackbar showInView:strongSelf.navigationController.view
																			 text:TGL(@"Chat.CouldNotUnpinAllMessages", @"Could not unpin the messages.")
																		  seconds:2
																		 onCommit:nil];
														   return;
													   }
													   [strongSelf loadTopic];
													   [strongSelf loadRecent];
												   }];
				   }];
}

@end

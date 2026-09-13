#import "TGDirectMessagesViewController.h"
#import "TGLocalization.h"
#import "TGChatViewController.h"
#import "TGClient+DirectMessages.h"
#import "TGClient+Notifications.h"
#import "TGUserDisplayNameStore.h"
#import "TGTheme.h"
#import "TGActionSheet.h"
#import "TGSnackbar.h"
#import "TGDateUtils.h"

static const CGFloat kDMTopicRowHeight = 60.0f;

static NSString *TGDMTopicDate(NSTimeInterval unix) {
	if (unix <= 0)
		return @"";
	return [TGDateUtils stringForMessageListDate:(int)unix] ?: @"";
}

static NSString *TGDMTopicPartnerName(NSDictionary *topic) {
	int64_t senderChatId = [topic[@"senderChatId"] longLongValue];
	if (senderChatId)
		return [[TGClient shared] titleForChatId:senderChatId];
	int64_t senderUserId = [topic[@"senderUserId"] longLongValue];
	return [TGUserDisplayNameStore nameForUserId:senderUserId];
}

@interface TGDirectMessagesViewController ()
@property (nonatomic, strong) NSArray *topics;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) TGActionSheet *currentActionSheet;
@property (nonatomic, strong) NSDictionary *actionTopic;
@property (nonatomic, strong) id topicsChangedObserverToken;
@end

@implementation TGDirectMessagesViewController

- (instancetype)init {
	self = [super initWithStyle:UITableViewStylePlain];
	if (self)
		_topics = @[];
	return self;
}

- (void)dealloc {
	self.tableView.delegate = nil;
	self.tableView.dataSource = nil;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (self.topicsChangedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.topicsChangedObserverToken];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(loadTimedOut) object:nil];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
	self.tableView.rowHeight = kDMTopicRowHeight;

	self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.emptyLabel.backgroundColor = [UIColor clearColor];
	self.emptyLabel.font = [UIFont systemFontOfSize:15];
	self.emptyLabel.textColor = [[TGTheme shared] secondaryTextColour];
	self.emptyLabel.textAlignment = NSTextAlignmentCenter;
	self.emptyLabel.numberOfLines = 0;
	self.emptyLabel.text = TGL(@"ChatList.MonoforumEmptyText",
		@"Nobody has messaged this channel directly yet.");
	self.emptyLabel.hidden = YES;
	[self.view addSubview:self.emptyLabel];

	self.spinner = [[UIActivityIndicatorView alloc]
		initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	[self.view addSubview:self.spinner];

	self.title = self.chatTitle.length ? self.chatTitle
									   : TGL(@"Chat.Monoforum.Subtitle", @"Direct Messages");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];

	__weak typeof(self) weakSelf = self;
	self.topicsChangedObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGDirectMessagesChatTopicsUpdatedNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf topicsChanged:note];
				}];

	NSArray *cached = [[TGClient shared] cachedDirectMessagesTopicsForChat:self.chatId];
	if (!cached.count)
		[self.spinner startAnimating];
	[self reloadFromCache];
	[self performSelector:@selector(loadTimedOut) withObject:nil afterDelay:6.0];
	[[TGClient shared] directMessagesTopicsForChat:self.chatId completion:nil];
}

- (void)loadTimedOut {
	[self.spinner stopAnimating];
	[self reloadFromCache];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)viewDidLayoutSubviews {
	if ([[UIViewController class] instancesRespondToSelector:@selector(viewDidLayoutSubviews)])
		[super viewDidLayoutSubviews];
	self.spinner.center = CGPointMake(self.view.bounds.size.width / 2, 60);
	if (!self.emptyLabel.hidden) {
		CGSize size = [self.emptyLabel.text sizeWithFont:self.emptyLabel.font
									   constrainedToSize:CGSizeMake(self.view.bounds.size.width - 48, 1000)
										   lineBreakMode:NSLineBreakByWordWrapping];
		self.emptyLabel.frame = CGRectMake(24,
			floorf((self.view.bounds.size.height - size.height) / 2),
			self.view.bounds.size.width - 48, ceilf(size.height));
	}
}

- (void)topicsChanged:(NSNotification *)note {
	if ([note.object isKindOfClass:NSNumber.class] &&
		[note.object longLongValue] != self.chatId)
		return;
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(loadTimedOut) object:nil];
	[self.spinner stopAnimating];
	[self reloadFromCache];
}

- (void)reloadFromCache {
	self.topics = [[TGClient shared] cachedDirectMessagesTopicsForChat:self.chatId];
	BOOL empty = self.topics.count == 0 && !self.spinner.isAnimating;
	self.tableView.hidden = self.topics.count == 0;
	self.emptyLabel.hidden = !empty;
	[self.tableView reloadData];
	[self.view setNeedsLayout];
}

#pragma mark - table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.topics.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"dmTopic"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"dmTopic"];
	[[TGTheme shared] styleCell:cell];
	cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;

	NSDictionary *topic = self.topics[(NSUInteger)indexPath.row];
	NSString *name = TGDMTopicPartnerName(topic);
	if (!name.length)
		name = TGL(@"Community.Request.UnknownRequester", @"Someone");

	NSInteger unread = [topic[@"unread"] integerValue];
	BOOL markedUnread = [topic[@"isMarkedAsUnread"] boolValue];
	cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
	cell.textLabel.text = (unread > 0 || markedUnread)
		? [NSString stringWithFormat:@"%@ (%ld)", name, (long)MAX(unread, 1)]
		: name;

	NSString *preview = topic[@"text"];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	cell.detailTextLabel.numberOfLines = 1;
	NSString *date = TGDMTopicDate([topic[@"date"] doubleValue]);
	cell.detailTextLabel.text = preview.length && date.length
		? [NSString stringWithFormat:@"%@ · %@", preview, date]
		: (preview.length ? preview : date);

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.row < 0 || indexPath.row >= (NSInteger)self.topics.count)
		return;

	NSDictionary *topic = self.topics[(NSUInteger)indexPath.row];
	int64_t topicId = [topic[@"topicId"] longLongValue];
	if (topicId == 0)
		return;

	NSString *name = TGDMTopicPartnerName(topic);
	TGChatViewController *vc = [[TGChatViewController alloc] init];
	vc.chatId = self.chatId;
	vc.directMessagesTopicId = topicId;
	vc.chatTitle = name.length ? name : TGL(@"Community.Request.UnknownRequester", @"Someone");
	vc.group = NO;
	[self.navigationController pushViewController:vc animated:YES];

	if ([topic[@"unread"] integerValue] > 0 || [topic[@"isMarkedAsUnread"] boolValue])
		[[TGClient shared] setDirectMessagesTopicInChat:self.chatId topic:topicId
										 markedAsUnread:NO
											 completion:nil];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row < 0 || indexPath.row >= (NSInteger)self.topics.count)
		return;
	NSDictionary *topic = self.topics[(NSUInteger)indexPath.row];
	self.actionTopic = topic;
	BOOL canSendUnpaid = [topic[@"canSendUnpaidMessages"] boolValue];
	BOOL markedUnread = [topic[@"isMarkedAsUnread"] boolValue] ||
		[topic[@"unread"] integerValue] > 0;

	NSString *readTitle = markedUnread
		? TGL(@"ChatList.Context.MarkAsRead", @"Mark as Read")
		: TGL(@"ChatList.Context.MarkAsUnread", @"Mark as Unread");
	NSString *unpaidTitle = canSendUnpaid
		? TGL(@"Chat.ReinstatePaidMessages", @"Charge Message Fee")
		: TGL(@"Chat.PaidMessageFee.RemoveFee", @"Remove Fee");

	NSMutableArray *actions = [NSMutableArray array];
	[actions addObject:[[TGActionSheetAction alloc]
						   initWithTitle:readTitle
								  action:@"toggleRead"]];
	[actions addObject:[[TGActionSheetAction alloc]
						   initWithTitle:unpaidTitle
								  action:@"toggleUnpaid"]];
	[actions addObject:[[TGActionSheetAction alloc]
						   initWithTitle:TGL(@"Common.Cancel", @"Cancel")
								  action:@"cancel"
									type:TGActionSheetActionTypeCancel]];

	__weak typeof(self) weakSelf = self;
	self.currentActionSheet = [[TGActionSheet alloc]
		initWithTitle:nil
			  actions:actions
		  actionBlock:^(id target, NSString *action) {
			  TGDirectMessagesViewController *strongSelf = weakSelf;
			  strongSelf.currentActionSheet = nil;
			  if (!strongSelf)
				  return;
			  NSDictionary *acting = strongSelf.actionTopic;
			  strongSelf.actionTopic = nil;
			  int64_t topicId = [acting[@"topicId"] longLongValue];
			  if (!topicId || [action isEqualToString:@"cancel"])
				  return;

			  TGClient *client = [TGClient shared];
			  if ([action isEqualToString:@"toggleRead"]) {
				  BOOL nowUnread = ![acting[@"isMarkedAsUnread"] boolValue] &&
					  [acting[@"unread"] integerValue] == 0;
				  [client setDirectMessagesTopicInChat:strongSelf.chatId
												 topic:topicId
										markedAsUnread:nowUnread
											completion:nil];
			  } else if ([action isEqualToString:@"toggleUnpaid"]) {
				  BOOL nowCanSendUnpaid = ![acting[@"canSendUnpaidMessages"] boolValue];
				  [client
					  toggleDirectMessagesTopicInChat:strongSelf.chatId
												topic:topicId
								canSendUnpaidMessages:nowCanSendUnpaid
									   refundPayments:NO
										   completion:nil];
			  }
		  }
			   target:self];

	[self.currentActionSheet tg_showFromRect:[tableView rectForRowAtIndexPath:indexPath] inView:tableView];
}

@end

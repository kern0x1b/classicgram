#import "TGSearchCalendarViewController.h"
#import "TGDateUtils.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGClient+Search.h"

@implementation TGSearchCalendarViewController {
	NSArray *_days;
	NSMutableDictionary *_positions;
	NSInteger _sparseTotal;
	UILabel *_status;
	BOOL _calendarLoaded;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"Chat.JumpToDate", @"Jump to Date");
	_days = @[];
	_positions = [NSMutableDictionary dictionary];
	self.tableView.rowHeight = 44;
	self.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tableView.tableFooterView = [[UIView alloc] init];

	_status = [[UILabel alloc] initWithFrame:
			CGRectMake(0, 90, self.view.bounds.size.width, 40)];
	_status.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_status.backgroundColor = [UIColor clearColor];
	_status.textAlignment = NSTextAlignmentCenter;
	_status.font = [UIFont systemFontOfSize:15];
	_status.textColor = [[TGTheme shared] secondaryTextColour];
	_status.text = TGL(@"Channel.NotificationLoading", @"Loading…");
	[self.view addSubview:_status];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] messageCalendarForChat:_chatId
									   filter:_filterName
								fromMessageId:0
								   completion:^(NSArray *days, NSInteger totalCount) {
									   TGSearchCalendarViewController *strongSelf = weakSelf;
									   if (!strongSelf)
										   return;
									   NSCalendar *calendar = [NSCalendar currentCalendar];
									   NSMutableArray *clean = [NSMutableArray array];
									   for (NSDictionary *day in days) {
										   if (![day isKindOfClass:NSDictionary.class])
											   continue;
										   NSInteger rawDate = [day[@"date"] integerValue];
										   if (rawDate <= 0)
											   continue;
										   NSDateComponents *parts = [calendar components:
												   (NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit)
															  fromDate:[NSDate dateWithTimeIntervalSince1970:rawDate]];
										   NSDate *dayStart = [calendar dateFromComponents:parts];
										   NSMutableDictionary *normalized = [day mutableCopy];
										   [normalized setObject:[NSNumber numberWithInteger:
														 (NSInteger)[dayStart timeIntervalSince1970]]
														 forKey:@"date"];
										   [clean addObject:normalized];
									   }
									   strongSelf->_days = clean;
									   strongSelf->_calendarLoaded = YES;
									   [strongSelf refresh];
								   }];

	TGClient *client = [TGClient shared];
	[client sparseMessagePositionsInChat:_chatId
								  filter:_filterName
						   fromMessageId:0
								   limit:100
							  completion:^(NSArray *positions, NSInteger totalCount) {
								  TGSearchCalendarViewController *strongSelf = weakSelf;
								  if (!strongSelf)
									  return;
								  strongSelf->_sparseTotal = totalCount;
								  for (NSDictionary *entry in positions) {
									  if (![entry isKindOfClass:NSDictionary.class])
										  continue;
									  NSNumber *messageId = [entry[@"messageId"] isKindOfClass:NSNumber.class]
										  ? entry[@"messageId"]
										  : nil;
									  NSNumber *position = [entry[@"position"] isKindOfClass:NSNumber.class]
										  ? entry[@"position"]
										  : nil;
									  if (!messageId || !position)
										  continue;
									  strongSelf->_positions[messageId] = position;
								  }
								  [strongSelf refresh];
							  }];
}

- (void)refresh {
	if (_calendarLoaded && !_days.count) {
		_status.text = TGL(@"Conversation.EmptyPlaceholder", @"No messages here yet");
		_status.hidden = NO;
	} else {
		_status.hidden = _days.count != 0;
	}
	self.navigationItem.prompt = _sparseTotal > 0
		? [NSString stringWithFormat:TGL(@"Chat.JumpToDate.MessagesInChatFormat", @"%@ in %@"),
			  TGLPlural(@"ChatList.Search.Messages", _sparseTotal, @"%@ message", @"%@ messages"),
			  (_chatTitle.length ? _chatTitle : TGL(@"HashtagSearch.ThisChat", @"this chat"))]
		: nil;
	[self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)_days.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *reuse = @"TGSearchCalendarDay";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:reuse];
		cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
		cell.textLabel.textColor = [[TGTheme shared] primaryTextColour];
		cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	}

	NSDictionary *day = _days[indexPath.row];
	cell.textLabel.text = [TGDateUtils stringForFullDate:(int)[day[@"date"] doubleValue]];

	NSInteger count = [day[@"count"] integerValue];
	NSString *detail = [NSString stringWithFormat:@"%d", (int)count];
	NSNumber *position = [day[@"messageId"] isKindOfClass:NSNumber.class]
		? _positions[day[@"messageId"]]
		: nil;
	if (position)
		detail = [NSString stringWithFormat:@"%@  #%d", detail, (int)[position integerValue] + 1];
	cell.detailTextLabel.text = detail;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.row >= (NSInteger)_days.count)
		return;
	NSInteger date = [((NSDictionary *)_days[indexPath.row])[@"date"] integerValue];
	if (self.onPickDate)
		self.onPickDate(date);
}

@end

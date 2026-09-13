#import "TGMessageInfoViewController.h"
#import "TGStringTruncation.h"
#import "TGDateUtils.h"
#import "TGByteFormat.h"
#import "TGSeenByStatusText.h"
#import "TGSeenByViewController.h"
#import "TGLocalization.h"
#import "TGClient.h"
#import "TGClient+Channels.h"
#import "TGClient+MessageContent.h"
#import "TGClient+Messages.h"
#import "TGClient+WebLinks.h"
#import "TGClient+Translation.h"
#import "TGClient+Groups.h"
#import "TGTheme.h"
#import "TGAlertView.h"
#import "TGProfileChartView.h"
#import "TGActionSheet.h"
#import "TGReactionListCell.h"
#import "TGSettingsService.h"
#import "TGProfileService.h"
#import "TGFileDownloadService.h"
#import "TGImageDecode.h"
#import "TGIcons.h"

static const NSInteger kInfoCaptionAlertTag = 71;
static const NSInteger kInfoQuoteOutdatedAlertTag = 126;
static const NSInteger kInfoStopPollActionSheetTag = 217;

static NSString *TGMessageInfoSectionTitle(NSString *key) {
	if ([key isEqualToString:@"Details"])
		return TGL(@"Chat.Details", @"Details");
	if ([key isEqualToString:@"Voice"])
		return TGL(@"PeerInfo.PaneVoiceAndVideo", @"Voice");
	if ([key isEqualToString:@"Poll"])
		return TGL(@"AttachmentMenu.Poll", @"Poll");
	if ([key isEqualToString:@"Story"])
		return TGL(@"Notification.Story", @"Story");
	if ([key isEqualToString:@"Actions"])
		return TGL(@"Stats.GroupTopAdmin.Actions", @"Actions");
	if ([key isEqualToString:@"Seen By"])
		return TGL(@"Chat.SeenBy", @"Seen By");
	return key;
}

@implementation TGMessageInfoViewController {
	NSMutableArray *_order;
	NSMutableDictionary *_rows;
	NSMutableArray *_visible;
	BOOL _resendInFlight;
}

- (id)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"Chat.MessageInfo", @"Message Info");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	_order = [NSMutableArray arrayWithObjects:@"Details", @"Seen By",
		@"Voice", @"Poll", @"Story", @"Actions", nil];
	_rows = [NSMutableDictionary dictionary];
	_visible = [NSMutableArray array];
	for (NSString *name in _order)
		_rows[name] = [NSMutableArray array];

	[self loadEverything];
}

- (void)addRow:(NSString *)title
		detail:(NSString *)detail
		action:(NSString *)action
			to:(NSString *)section {
	NSMutableArray *list = _rows[section];
	if (!list)
		return;
	NSMutableDictionary *row = [NSMutableDictionary dictionary];
	row[@"title"] = title.length ? title : @" ";
	if (detail.length)
		row[@"detail"] = detail;
	if (action.length)
		row[@"action"] = action;
	[list addObject:row];
	[self refresh];
}

- (void)clearSection:(NSString *)section {
	[_rows[section] removeAllObjects];
}

- (void)refresh {
	[_visible removeAllObjects];
	for (NSString *name in _order)
		if ([_rows[name] count])
			[_visible addObject:name];
	[self.tableView reloadData];
	[self revealFocusSection];
}

- (void)revealFocusSection {
	if (!self.focusSection.length)
		return;
	NSInteger where = [_visible indexOfObject:self.focusSection];
	if (where == NSNotFound)
		return;
	self.focusSection = nil;
	[self.tableView scrollToRowAtIndexPath:
			[NSIndexPath indexPathForRow:0 inSection:(NSInteger)where]
						  atScrollPosition:UITableViewScrollPositionTop
								  animated:NO];
}

- (NSString *)sizeText:(long long)bytes {
	if (bytes <= 0)
		return nil;
	return TGMediaFormatBytes(bytes);
}

- (NSString *)stringOf:(id)value {
	return [value isKindOfClass:NSString.class] ? value : nil;
}

- (NSTimeInterval)messageDate {
	id date = self.message[@"date"];
	return [date isKindOfClass:NSNumber.class] ? [date doubleValue] : 0;
}

- (void)loadEverything {
	int64_t messageId = self.messageId;
	int64_t chatId = self.chatId;
	NSString *kind = [self stringOf:self.message[@"kind"]] ?: @"message";
	BOOL outgoing = [self.message[@"outgoing"] boolValue];
	__weak typeof(self) weakSelf = self;

	TGClient *client = [TGClient shared];
	[client mediaInfoForMessage:messageId inChat:chatId completion:^(NSDictionary *info) {
		TGMessageInfoViewController *strongSelf = weakSelf;
		if (!strongSelf || ![info isKindOfClass:NSDictionary.class])
			return;
		if (!outgoing)
			return;
		[strongSelf addRow:TGL(@"Conversation.EditingCaptionPanelTitle", @"Edit Caption") detail:nil action:@"editCaption" to:@"Actions"];
	}];

	if (outgoing && !self.group) {
		[client readDateOfMessage:messageId inChat:chatId completion:^(NSString *status, NSTimeInterval when) {
			TGMessageInfoViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			NSString *detail = TGL(@"Chat.NotReadYet", @"Not read yet");
			if ([status isEqualToString:@"read"] && when > 0)
				detail = [NSDateFormatter
					localizedStringFromDate:[NSDate dateWithTimeIntervalSince1970:when]
								  dateStyle:NSDateFormatterShortStyle
								  timeStyle:NSDateFormatterShortStyle];
			else if ([status isEqualToString:@"tooOld"])
				detail = TGL(@"Chat.TooOldToTell", @"Too old to tell");
			else if ([status isEqualToString:@"theirPrivacy"] ||
				[status isEqualToString:@"myPrivacy"])
				detail = TGL(@"Chat.HiddenByPrivacy", @"Hidden by privacy");
			[strongSelf addRow:TGL(@"DialogList.Read", @"Read") detail:detail action:nil to:@"Details"];
		}];
	}

	if (outgoing && self.group) {
		[client viewersOfMessage:messageId
						  inChat:chatId
					  completion:^(NSArray *viewers, NSString *unavailableReason) {
						  TGMessageInfoViewController *strongSelf = weakSelf;
						  if (!strongSelf)
							  return;
						  NSInteger count = [viewers isKindOfClass:[NSArray class]]
							  ? (NSInteger)viewers.count
							  : 0;
						  if (count > 0) {
							  [strongSelf addRow:TGLPlural(@"Story.Footer.Views", count,
													 @"%d view", @"%d views")
										  detail:nil
										  action:@"seenBy"
											  to:@"Seen By"];
							  return;
						  }
						  [strongSelf addRow:TGSeenByStatusText(unavailableReason)
									  detail:nil
									  action:nil
										  to:@"Seen By"];
					  }];
	}

	[client threadForMessage:messageId inChat:chatId completion:^(NSDictionary *thread) {
		TGMessageInfoViewController *strongSelf = weakSelf;
		if (!strongSelf || ![thread isKindOfClass:NSDictionary.class])
			return;
		strongSelf.threadChatId = [thread[@"chatId"] longLongValue];
		NSInteger replies = [thread[@"replies"] integerValue];
		NSInteger unread = [thread[@"unread"] integerValue];
		NSString *repliesText = TGLPlural(@"Conversation.MessageViewComments", replies, @"1 Comment", @"%d Comments");
		NSString *comments = unread > 0
			? [NSString stringWithFormat:TGL(@"Chat.MessageInfoCommentsUnreadFormat", @"%@, %d unread"), repliesText, (int)unread]
			: repliesText;
		NSString *open = strongSelf.threadChatId ? @"openThread" : nil;
		[strongSelf addRow:TGL(@"Conversation.TitleNoComments", @"Comments") detail:comments action:open to:@"Details"];
	}];

	if ([kind isEqualToString:@"messageVoiceNote"] ||
		[kind isEqualToString:@"messageVideoNote"])
		[self loadTranscript];

	NSArray *options = [self.message[@"pollOptions"] isKindOfClass:NSArray.class]
		? self.message[@"pollOptions"]
		: nil;
	BOOL pollCanGetVoters = [self.message[@"pollCanGetVoters"] boolValue];
	for (NSInteger i = 0; i < options.count; i++) {
		NSDictionary *option = options[i];
		id text = option[@"text"];
		NSString *label = [text isKindOfClass:NSDictionary.class]
			? [self stringOf:text[@"text"]]
			: [self stringOf:text];
		[self addRow:(label ?: TGL(@"CreatePoll.OptionPlaceholder", @"Option"))
			  detail:[NSString stringWithFormat:@"%ld%%",
						 (long)[option[@"vote_percentage"] integerValue]]
			  action:(pollCanGetVoters ? [NSString stringWithFormat:@"voters:%lu", (unsigned long)i] : nil)
				  to:@"Poll"];
	}
	BOOL pollClosed = [self.message[@"pollClosed"] boolValue];
	if (options.count)
		[[TGClient shared] propertiesOfMessage:messageId inChat:chatId
									completion:^(NSDictionary *properties) {
										TGMessageInfoViewController *strongSelf = weakSelf;
										if (!strongSelf)
											return;
										if (!pollClosed && [properties[@"canEdit"] boolValue])
											[strongSelf addRow:TGL(@"Conversation.StopPoll", @"Stop Poll") detail:nil
												action:@"stopPoll"
													to:@"Poll"];
										if ([properties[@"canGetPollVoteStatistics"] boolValue])
											[strongSelf addRow:TGL(@"PollStats.Title", @"Poll Stats") detail:nil
												action:@"pollStats"
													to:@"Poll"];
									}];

	if ([kind isEqualToString:@"messageStory"]) {
		[client storyForMessage:messageId inChat:chatId completion:^(NSDictionary *story) {
			TGMessageInfoViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (![story isKindOfClass:NSDictionary.class]) {
				[strongSelf addRow:TGL(@"Notification.Story", @"Story") detail:TGL(@"Story.TooltipExpired", @"This story is no longer available") action:nil to:@"Story"];
				return;
			}
			NSString *caption = [strongSelf stringOf:story[@"caption"]];
			if (caption.length)
				[strongSelf addRow:TGL(@"Conversation.InputTextCaptionPlaceholder", @"Caption") detail:caption action:nil to:@"Story"];
		}];
	}

	if (self.canResend)
		[self addRow:TGL(@"Conversation.MessageDialogRetry", @"Resend") detail:nil action:@"resend" to:@"Actions"];
	if (!self.group) {
		[self addRow:TGL(@"MessageCalendar.ClearHistoryForThisDay", @"Clear History For This Day") detail:nil action:@"deleteDay" to:@"Actions"];
	} else {
		[[TGClient shared] groupInfoForChat:chatId completion:^(NSDictionary *info) {
			TGMessageInfoViewController *strongSelf = weakSelf;
			if (!strongSelf || [info[@"isSupergroup"] boolValue])
				return;
			[strongSelf addRow:TGL(@"MessageCalendar.ClearHistoryForThisDay", @"Clear History For This Day") detail:nil action:@"deleteDay" to:@"Actions"];
		}];
	}
}

- (void)loadTranscript {
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client speechTranscriptForMessage:self.messageId inChat:self.chatId completion:^(NSDictionary *transcript) {
		TGMessageInfoViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf clearSection:@"Voice"];
		NSString *voice = @"Voice";
		if (![transcript isKindOfClass:NSDictionary.class]) {
			[strongSelf addRow:TGL(@"Chat.Transcript", @"Transcript") detail:TGL(@"Chat.NoneYet", @"None yet") action:nil to:voice];
			return;
		}
		NSString *state = [strongSelf stringOf:transcript[@"state"]] ?: @"";
		NSString *text = [strongSelf stringOf:transcript[@"text"]] ?: @"";
		if ([state isEqualToString:@"error"]) {
			NSString *why = [strongSelf stringOf:transcript[@"error"]] ?: TGL(@"Chat.Failed", @"Failed");
			[strongSelf addRow:TGL(@"Chat.Transcript", @"Transcript") detail:why action:nil to:voice];
			return;
		}
		if ([state isEqualToString:@"pending"]) {
			[strongSelf addRow:TGL(@"Chat.Transcript", @"Transcript") detail:TGL(@"Chat.InProgress", @"In progress") action:@"reloadTranscript" to:voice];
			return;
		}
		[strongSelf addRow:(text.length ? text : TGL(@"Cache.ClearEmpty", @"Empty")) detail:nil action:nil to:voice];
		if (!text.length)
			return;
		[strongSelf addRow:TGL(@"Chat.AudioTranscriptionRateAction", @"Rate Transcription") detail:nil action:@"rateChoice" to:voice];
	}];
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return (NSInteger)_visible.count;
}

- (NSString *)tableView:(UITableView *)tableView
	titleForHeaderInSection:(NSInteger)section {
	return TGMessageInfoSectionTitle(_visible[section]);
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderHeightForTitle:title];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (NSInteger)tableView:(UITableView *)tableView
	numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)[_rows[_visible[section]] count];
}

- (NSDictionary *)rowAt:(NSIndexPath *)path {
	NSArray *list = _rows[_visible[path.section]];
	return (path.row < (NSInteger)list.count) ? list[path.row] : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *identifier = @"info";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:identifier];
	NSDictionary *row = [self rowAt:indexPath];
	cell.textLabel.text = row[@"title"];
	cell.detailTextLabel.text = row[@"detail"];
	cell.textLabel.font = [UIFont systemFontOfSize:15];
	cell.textLabel.numberOfLines = 0;
	NSString *action = row[@"action"];
	BOOL isRateChoice = [action isEqualToString:@"rateChoice"];
	cell.selectionStyle = (action.length && !isRateChoice) ? UITableViewCellSelectionStyleBlue
										: UITableViewCellSelectionStyleNone;
	cell.accessoryType = [action isEqualToString:@"openThread"]
		? UITableViewCellAccessoryDisclosureIndicator
		: UITableViewCellAccessoryNone;
	cell.accessoryView = isRateChoice ? [self transcriptRatingAccessoryView] : nil;
	cell.textLabel.textColor = [action isEqualToString:@"deleteDay"]
		? [UIColor colorWithRed:0.78f green:0.16f blue:0.13f alpha:1.0f]
		: [UIColor blackColor];
	return cell;
}

- (UIView *)transcriptRatingAccessoryView {
	CGFloat side = 32;
	UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, side * 2 + 8, side)];
	UIButton *good = [UIButton buttonWithType:UIButtonTypeCustom];
	good.frame = CGRectMake(0, 0, side, side);
	[good setTitle:@"\U0001F44D" forState:UIControlStateNormal];
	good.titleLabel.font = [UIFont systemFontOfSize:20];
	[good addTarget:self action:@selector(rateTranscriptGood) forControlEvents:UIControlEventTouchUpInside];
	UIButton *bad = [UIButton buttonWithType:UIButtonTypeCustom];
	bad.frame = CGRectMake(side + 8, 0, side, side);
	[bad setTitle:@"\U0001F44E" forState:UIControlStateNormal];
	bad.titleLabel.font = [UIFont systemFontOfSize:20];
	[bad addTarget:self action:@selector(rateTranscriptBad) forControlEvents:UIControlEventTouchUpInside];
	[container addSubview:good];
	[container addSubview:bad];
	return container;
}

- (CGFloat)tableView:(UITableView *)tableView
	heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *row = [self rowAt:indexPath];
	if (row[@"detail"])
		return 44;
	CGSize size = [(row[@"title"] ?: @"") sizeWithFont:[UIFont systemFontOfSize:15]
									 constrainedToSize:CGSizeMake(280, 400)
										 lineBreakMode:NSLineBreakByWordWrapping];
	return MAX(44, size.height + 20);
}

- (void)tableView:(UITableView *)tableView
	didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSDictionary *row = [self rowAt:indexPath];
	NSString *action = row[@"action"];
	if (!action.length)
		return;

	if ([action isEqualToString:@"openThread"]) {
		if (self.onOpenChat && self.threadChatId)
			self.onOpenChat(self.threadChatId, @"Comments");
		return;
	}
	if ([action isEqualToString:@"seenBy"]) {
		TGSeenByViewController *seenBy = [[TGSeenByViewController alloc]
			initWithMessageId:self.messageId
					   chatId:self.chatId];
		[self.navigationController pushViewController:seenBy animated:YES];
		return;
	}
	if ([action isEqualToString:@"reloadTranscript"]) {
		[self loadTranscript];
		return;
	}
	if ([action hasPrefix:@"voters:"]) {
		[self showVotersForOption:[[action substringFromIndex:7] integerValue] title:row[@"title"]];
		return;
	}
	if ([action isEqualToString:@"stopPoll"]) {
		UIActionSheet *sheet = [[UIActionSheet alloc]
					 initWithTitle:TGL(@"Conversation.StopPollAlertText", @"Are you sure you want to stop this poll? This action cannot be undone.")
						  delegate:self
				 cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			destructiveButtonTitle:TGL(@"Conversation.StopPoll", @"Stop Poll")
				 otherButtonTitles:nil];
		sheet.tag = kInfoStopPollActionSheetTag;
		[sheet tg_showFromRect:[tableView rectForRowAtIndexPath:indexPath] inView:tableView];
		return;
	}
	if ([action isEqualToString:@"pollStats"]) {
		TGPollVoteStatisticsViewController *stats = [[TGPollVoteStatisticsViewController alloc] init];
		stats.chatId = self.chatId;
		stats.messageId = self.messageId;
		[self.navigationController pushViewController:stats animated:YES];
		return;
	}
	if ([action isEqualToString:@"editCaption"]) {
		UIAlertView *ask = [[TGAlertView alloc]
				initWithTitle:TGL(@"Conversation.InputTextCaptionPlaceholder", @"Caption")
					  message:nil
					 delegate:self
			cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			otherButtonTitles:TGL(@"Conversation.LinkDialogSave", @"Save"), nil];
		if ([ask respondsToSelector:@selector(setAlertViewStyle:)])
			ask.alertViewStyle = UIAlertViewStylePlainTextInput;
		ask.tag = kInfoCaptionAlertTag;
		[ask show];
		return;
	}
	if ([action isEqualToString:@"resend"]) {
		if ([self.message[@"needAnotherReplyQuote"] boolValue]) {
			UIAlertView *ask = [[TGAlertView alloc]
					initWithTitle:TGL(@"Conversation.QuoteOutdatedTitle", @"Quote Outdated")
							message:TGL(@"Conversation.QuoteOutdatedText", @"The quoted text has changed and can no longer be used. You can retry sending this message without the quote.")
						   delegate:self
				  cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
				  otherButtonTitles:TGL(@"Conversation.RetryWithoutQuote", @"Retry Without Quote"), nil];
			ask.tag = kInfoQuoteOutdatedAlertTag;
			[ask show];
			return;
		}
		if (_resendInFlight)
			return;
		_resendInFlight = YES;
		BOOL dropQuote = [self.message[@"needDropReply"] boolValue];
		int64_t paidStarCount = [self.message[@"requiredPaidMessageStarCount"] longLongValue];
		TGClient *client = [TGClient shared];
		__weak typeof(self) weakSelf = self;
		[client resendMessages:@[ @(self.messageId) ] inChat:self.chatId dropQuote:dropQuote
					  paidStarCount:paidStarCount completion:^(NSArray *messages) {
			TGMessageInfoViewController *strongSelf = weakSelf;
			if (strongSelf)
				strongSelf->_resendInFlight = NO;
		}];
		return;
	}
	if ([action isEqualToString:@"deleteDay"]) {
		UIActionSheet *sheet = [[UIActionSheet alloc]
					 initWithTitle:TGLPlural(@"MessageCalendar.DeleteAlertText", 1,
										 @"Are you sure you want to delete all messages for the selected day?",
										 @"Are you sure you want to delete all messages for the selected %@ days?")
						  delegate:self
				 cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			destructiveButtonTitle:TGL(@"Common.Delete", @"Delete")
				 otherButtonTitles:nil];
		[sheet tg_showFromRect:[tableView rectForRowAtIndexPath:indexPath] inView:tableView];
	}
}

- (void)showVotersForOption:(NSInteger)index title:(NSString *)title {
	TGPollOptionVotersViewController *voters = [[TGPollOptionVotersViewController alloc] init];
	voters.chatId = self.chatId;
	voters.messageId = self.messageId;
	voters.optionIndex = index;
	voters.optionTitle = title;
	[self.navigationController pushViewController:voters animated:YES];
}

- (void)rateTranscriptGood {
	[self rateTranscript:YES];
}

- (void)rateTranscriptBad {
	[self rateTranscript:NO];
}

- (void)rateTranscript:(BOOL)good {
	TGClient *client = [TGClient shared];
	[client rateSpeechRecognitionForMessage:self.messageId inChat:self.chatId good:good];
	[self say:@"" message:TGL(@"Chat.AudioTranscriptionFeedbackTip", @"Thank you for your feedback.")];
	NSMutableArray *list = _rows[@"Voice"];
	for (NSInteger i = (NSInteger)list.count - 1; i >= 0; i--)
		if ([list[i][@"action"] isEqualToString:@"rateChoice"])
			[list removeObjectAtIndex:(NSUInteger)i];
	[self refresh];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (alertView.tag == kInfoQuoteOutdatedAlertTag) {
		if (buttonIndex == alertView.cancelButtonIndex)
			return;
		TGClient *client = [TGClient shared];
		int64_t paidStarCount = [self.message[@"requiredPaidMessageStarCount"] longLongValue];
		[client resendMessages:@[ @(self.messageId) ] inChat:self.chatId dropQuote:YES
					  paidStarCount:paidStarCount completion:nil];
		return;
	}
	if (alertView.tag != kInfoCaptionAlertTag || buttonIndex == alertView.cancelButtonIndex)
		return;
	NSString *caption = @"";
	if ([alertView respondsToSelector:@selector(textFieldAtIndex:)])
		caption = [alertView textFieldAtIndex:0].text ?: @"";
	TGClient *client = [TGClient shared];
	[client editCaptionOfMessage:self.messageId inChat:self.chatId caption:caption
						 entities:nil
		  showCaptionAboveMedia:[self.message[@"captionAboveMedia"] boolValue]
					  completion:nil];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
	if (index != sheet.destructiveButtonIndex)
		return;
	if (sheet.tag == kInfoStopPollActionSheetTag) {
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] stopPoll:self.messageId
							  inChat:self.chatId
						  completion:^(BOOL ok) {
							  TGMessageInfoViewController *strongSelf = weakSelf;
							  if (!strongSelf)
								  return;
							  if (!ok) {
								  [strongSelf say:@"" message:TGL(@"Toast.CouldNotStopPoll", @"Could not stop this poll")];
								  return;
							  }
							  NSMutableArray *list = strongSelf->_rows[@"Poll"];
							  for (NSInteger i = (NSInteger)list.count - 1; i >= 0; i--)
								  if ([list[i][@"action"] isEqualToString:@"stopPoll"])
									  [list removeObjectAtIndex:(NSUInteger)i];
							  [strongSelf refresh];
						  }];
		return;
	}
	NSTimeInterval date = [self messageDate];
	if (date <= 0) {
		[self say:@"" message:TGL(@"Chat.ThisMessageHasNoDateTo", @"This message has no date to work from.")];
		return;
	}
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDateComponents *parts = [calendar components:
			(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit)
										  fromDate:[NSDate dateWithTimeIntervalSince1970:date]];
	NSTimeInterval start = [[calendar dateFromComponents:parts] timeIntervalSince1970];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] deleteMessagesInChat:self.chatId
								   fromDate:start
									 toDate:start + 86399
								forEveryone:NO
								 completion:^(BOOL ok) {
									 TGMessageInfoViewController *strongSelf = weakSelf;
									 if (!strongSelf)
										 return;
									 if (!ok) {
										 [strongSelf say:@"" message:TGL(@"Toast.CouldNotDeleteMessages", @"Could not delete these messages")];
										 return;
									 }
									 [strongSelf.navigationController popViewControllerAnimated:YES];
								 }];
}

- (void)say:(NSString *)title message:(NSString *)message {
	[[[UIAlertView alloc] initWithTitle:(title ?: @"")
								message:message
							   delegate:nil
					  cancelButtonTitle:TGL(@"Common.OK", @"OK")
					  otherButtonTitles:nil] show];
}

@end

@implementation TGPollVoteStatisticsViewController {
	TGProfileChartView *_chartView;
	UILabel *_emptyLabel;
	UIActivityIndicatorView *_spinner;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"PollStats.Title", @"Poll Stats");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];

	_spinner = [[UIActivityIndicatorView alloc]
		initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	_spinner.center = CGPointMake(self.view.bounds.size.width / 2, 120);
	_spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
		UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
	[_spinner startAnimating];
	[self.view addSubview:_spinner];

	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client pollVoteStatisticsForMessage:self.messageId inChat:self.chatId isDark:NO completion:^(NSDictionary *graph) {
		TGPollVoteStatisticsViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSString *token = [graph[@"token"] isKindOfClass:NSString.class] ? graph[@"token"] : nil;
		if (!graph[@"json"] && token.length) {
			[client statisticalGraphForChat:strongSelf.chatId token:token zoomAtX:0 completion:^(NSDictionary *loaded) {
				[strongSelf applyGraph:loaded];
			}];
			return;
		}
		[strongSelf applyGraph:graph];
	}];
}

- (void)applyGraph:(NSDictionary *)graph {
	[_spinner stopAnimating];
	[_spinner removeFromSuperview];

	NSString *json = [graph[@"json"] isKindOfClass:NSString.class] ? graph[@"json"] : nil;
	NSArray *points = nil;
	NSString *left = nil, *right = nil;
	if (json.length) {
		NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
		id parsed = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
		NSArray *columns = [parsed isKindOfClass:NSDictionary.class] ? parsed[@"columns"] : nil;
		NSArray *xColumn = nil, *yColumn = nil;
		for (id column in columns) {
			if (![column isKindOfClass:NSArray.class] || [(NSArray *)column count] < 2)
				continue;
			NSString *key = [column[0] isKindOfClass:NSString.class] ? column[0] : nil;
			if ([key isEqualToString:@"x"])
				xColumn = column;
			else if (!yColumn)
				yColumn = column;
		}
		if (yColumn.count > 1) {
			NSMutableArray *values = [NSMutableArray array];
			for (NSInteger i = 1; i < yColumn.count; i++)
				if ([yColumn[i] isKindOfClass:NSNumber.class])
					[values addObject:yColumn[i]];
			if (values.count > 30)
				[values removeObjectsInRange:NSMakeRange(0, values.count - 30)];
			points = values;
			if (xColumn.count >= 2 && [xColumn.lastObject isKindOfClass:NSNumber.class]) {
				NSInteger total = xColumn.count - 1;
				NSInteger firstIndex = total > points.count ? total - points.count + 1 : 1;
				double firstMs = [xColumn[firstIndex] doubleValue];
				double lastMs = [xColumn.lastObject doubleValue];
				left = [TGDateUtils stringForFullDate:(int)(firstMs / 1000.0)];
				right = [TGDateUtils stringForFullDate:(int)(lastMs / 1000.0)];
			}
		}
	}

	if (points.count < 2) {
		_emptyLabel = [[UILabel alloc] initWithFrame:CGRectInset(self.view.bounds, 24, 24)];
		_emptyLabel.text = TGL(@"Chat.NotEnoughVotesYet", @"Not enough votes yet for a chart.");
		_emptyLabel.textAlignment = NSTextAlignmentCenter;
		_emptyLabel.numberOfLines = 0;
		_emptyLabel.textColor = [[TGTheme shared] secondaryTextColour];
		_emptyLabel.font = [UIFont systemFontOfSize:15];
		_emptyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[self.view addSubview:_emptyLabel];
		return;
	}

	_chartView = [[TGProfileChartView alloc]
		initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 220)];
	_chartView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_chartView.points = points;
	_chartView.leftDate = left;
	_chartView.rightDate = right;
	[self.view addSubview:_chartView];
}

@end

static const NSInteger kPollOptionVotersPageSize = 50;
static const CGFloat kPollVoterAvatarSide = 40.0f;
static const CGFloat kPollVoterRowHeight = 54.0f;

@implementation TGPollOptionVotersViewController {
	NSMutableArray *_voters;
	NSMutableDictionary *_photos;
	NSMutableSet *_photosRequested;
	UIActivityIndicatorView *_spinner;
	UILabel *_statusLabel;
	BOOL _loadingMore;
	BOOL _exhausted;
	NSInteger _totalCount;
	NSInteger _votersGeneration;
}

- (id)init {
	return [super initWithStyle:UITableViewStylePlain];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.title = self.optionTitle.length ? self.optionTitle : TGL(@"AttachmentMenu.Poll", @"Poll");
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tableView.rowHeight = kPollVoterRowHeight;
	_voters = [NSMutableArray array];
	_photos = [NSMutableDictionary dictionary];
	_photosRequested = [NSMutableSet set];

	_spinner = [[UIActivityIndicatorView alloc]
		initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	_spinner.center = CGPointMake(self.view.bounds.size.width / 2, 80);
	_spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
		UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;

	[self loadFirstPage];
}

- (void)showStatusLabelWithText:(NSString *)text tappable:(BOOL)tappable {
	[_statusLabel removeFromSuperview];
	_statusLabel = [[UILabel alloc] initWithFrame:CGRectInset(self.view.bounds, 24, 24)];
	_statusLabel.text = text;
	_statusLabel.textAlignment = NSTextAlignmentCenter;
	_statusLabel.numberOfLines = 0;
	_statusLabel.textColor = [[TGTheme shared] secondaryTextColour];
	_statusLabel.font = [UIFont systemFontOfSize:15];
	_statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	if (tappable) {
		_statusLabel.userInteractionEnabled = YES;
		[_statusLabel addGestureRecognizer:[[UITapGestureRecognizer alloc]
			initWithTarget:self action:@selector(retryTapped)]];
	}
	[self.view addSubview:_statusLabel];
}

- (void)retryTapped {
	[self loadFirstPage];
}

- (void)loadFirstPage {
	[_statusLabel removeFromSuperview];
	_statusLabel = nil;
	if (!_spinner.superview) {
		[_spinner startAnimating];
		[self.view addSubview:_spinner];
	}
	__weak typeof(self) weakSelf = self;
	_loadingMore = YES;
	_votersGeneration++;
	[_voters removeAllObjects];
	_exhausted = NO;
	NSInteger generation = _votersGeneration;
	[[TGClient shared] votersForPollOption:self.optionIndex ofMessage:self.messageId
									 inChat:self.chatId offset:0 limit:kPollOptionVotersPageSize
								 completion:^(BOOL ok, NSArray *voters, NSInteger total) {
									 TGPollOptionVotersViewController *strongSelf = weakSelf;
									 if (!strongSelf || strongSelf->_votersGeneration != generation)
										 return;
									 strongSelf->_loadingMore = NO;
									 [strongSelf->_spinner stopAnimating];
									 [strongSelf->_spinner removeFromSuperview];
									 if (!ok) {
										 strongSelf->_exhausted = YES;
										 [strongSelf showStatusLabelWithText:
											 TGL(@"Chat.CouldNotLoadVoters", @"Couldn't load voters. Tap to retry.")
																	 tappable:YES];
										 [strongSelf.tableView reloadData];
										 return;
									 }
									 if ([voters isKindOfClass:NSArray.class])
										 [strongSelf->_voters addObjectsFromArray:voters];
									 strongSelf->_totalCount = total;
									 strongSelf->_exhausted = !voters.count ||
										 (total > 0 && (NSInteger)strongSelf->_voters.count >= total);
									 if (!strongSelf->_voters.count)
										 [strongSelf showStatusLabelWithText:TGL(@"Chat.NoneYet", @"None yet")
																	 tappable:NO];
									 [strongSelf.tableView reloadData];
								 }];
}

- (void)loadMoreVoters {
	if (_loadingMore || _exhausted || !_voters.count)
		return;
	_loadingMore = YES;
	NSInteger generation = _votersGeneration;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] votersForPollOption:self.optionIndex ofMessage:self.messageId
									 inChat:self.chatId offset:(NSInteger)_voters.count
									  limit:kPollOptionVotersPageSize
								 completion:^(BOOL ok, NSArray *voters, NSInteger total) {
									 TGPollOptionVotersViewController *strongSelf = weakSelf;
									 if (!strongSelf || strongSelf->_votersGeneration != generation)
										 return;
									 strongSelf->_loadingMore = NO;
									 if (!ok)
										 return;
									 if ([voters isKindOfClass:NSArray.class] && voters.count) {
										 [strongSelf->_voters addObjectsFromArray:voters];
										 [strongSelf.tableView reloadData];
									 }
									 strongSelf->_totalCount = total;
									 strongSelf->_exhausted = !voters.count ||
										 (total > 0 && (NSInteger)strongSelf->_voters.count >= total);
								 }];
}

- (void)tableView:(UITableView *)tableView
	  willDisplayCell:(UITableViewCell *)cell
	forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row < (NSInteger)_voters.count - 3)
		return;
	[self loadMoreVoters];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)_voters.count;
}

- (void)fetchPhotoForVoterId:(int64_t)voterId {
	NSNumber *key = @(voterId);
	if (_photos[key] != nil || [_photosRequested containsObject:key])
		return;
	NSNumber *fileId = voterId > 0
		? [TGSettingsService photoFileIdForUserId:voterId]
		: [TGProfileService photoFileIdForChat:voterId];
	if (![fileId isKindOfClass:NSNumber.class])
		return;
	[_photosRequested addObject:key];

	__weak typeof(self) weakSelf = self;
	[TGFileDownloadService downloadFile:[fileId longLongValue] completion:^(NSString *path) {
		TGPollOptionVotersViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!path.length) {
			[strongSelf->_photosRequested removeObject:key];
			return;
		}
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
			UIImage *thumb = TGDecodeSquareThumbnail(path, kPollVoterAvatarSide);
			dispatch_async(dispatch_get_main_queue(), ^{
				TGPollOptionVotersViewController *innerSelf = weakSelf;
				if (!innerSelf || !thumb)
					return;
				innerSelf->_photos[key] = thumb;
				[innerSelf.tableView reloadData];
			});
		});
	}];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *identifier = @"voter";
	TGReactionListCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
	if (!cell)
		cell = [[TGReactionListCell alloc] initWithStyle:UITableViewCellStyleDefault
										 reuseIdentifier:identifier];
	NSDictionary *voter = _voters[(NSUInteger)indexPath.row];
	NSString *name = [voter[@"name"] isKindOfClass:NSString.class] ? voter[@"name"] : @"";
	int64_t voterId = [voter[@"id"] longLongValue];
	cell.nameLabel.text = name;
	cell.emojiLabel.text = @"";
	UIImage *photo = _photos[@(voterId)];
	if (!photo) {
		NSString *initial = name.length
			? [TGSafeFirstCharacter(name) uppercaseString]
			: @"?";
		photo = [TGIcons avatarWithInitials:initial size:kPollVoterAvatarSide colourId:voterId];
		[self fetchPhotoForVoterId:voterId];
	}
	cell.avatarView.image = photo;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end

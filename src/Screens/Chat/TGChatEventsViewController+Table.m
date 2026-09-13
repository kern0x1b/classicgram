#import "TGChatEventsViewControllerInternal.h"
#import "TGStringTruncation.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGClient.h"
#import "TGClient+ChatManagement.h"
#import "TGClient+Messages.h"
#import "TGChatViewController.h"
#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGDateUtils.h"
#import "UIView+SafeTint.h"
#import "TGHexColour.h"

static const CGFloat kEventsHeaderHeight = 26.0f;

static NSString *TGEventsInitials(NSString *name) {
	if (![name isKindOfClass:[NSString class]] || !name.length)
		return @"?";
	NSMutableString *initials = [NSMutableString string];
	NSInteger taken = 0;
	NSArray *words = [name componentsSeparatedByString:@" "];
	for (NSString *word in words) {
		if (!word.length)
			continue;
		[initials appendString:[TGSafeFirstCharacter(word) uppercaseString]];
		if (++taken >= 2)
			break;
	}
	return initials.length ? initials : @"?";
}

@implementation TGChatEventsViewController (Table)

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section >= (NSInteger)self.sections.count)
		return 0;
	return (NSInteger)[self.sections[section][@"rows"] count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return kEventsHeaderHeight;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	if (section >= (NSInteger)self.sections.count)
		return nil;

	CGFloat width = tableView.bounds.size.width;
	UIView *container = [UIView alloc];
	container = [container initWithFrame:
			CGRectMake(0, 0, width, kEventsHeaderHeight)];
	container.backgroundColor = TGColourFromHex(0xe4e9f0);

	NSString *name = section == 0 ? @"CategoryDividerFirst.png" : @"CategoryDivider.png";
	UIImage *art = [UIImage imageNamed:name];
	if (art) {
		UIImage *stretched = [art stretchableImageWithLeftCapWidth:0 topCapHeight:0];
		UIImageView *background = [[UIImageView alloc] initWithImage:stretched];
		background.frame = CGRectMake(0, 0, width, kEventsHeaderHeight);
		background.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[container addSubview:background];
	}

	UILabel *label = [UILabel alloc];
	label = [label initWithFrame:
			CGRectMake(10, 4 + TGEventsRetinaPixel(), width - 20, 18)];
	label.backgroundColor = [UIColor clearColor];
	label.font = [UIFont boldSystemFontOfSize:13];
	label.text = self.sections[section][@"title"];
	label.textColor = TGColourFromHex(0x697487);
	label.shadowColor = [UIColor colorWithWhite:1.0f alpha:0.3f];
	label.shadowOffset = CGSizeMake(0, 1);
	[container addSubview:label];
	return container;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *event = [self eventAtIndexPath:indexPath];
	if (!event)
		return kEventsMinRowHeight;
	return [TGChatEventCell heightForText:[self summaryForEvent:event]
									width:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	TGChatEventCell *cell = (TGChatEventCell *)
		[tableView dequeueReusableCellWithIdentifier:@"event"];
	if (!cell)
		cell = [[TGChatEventCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"event"];

	NSDictionary *event = [self eventAtIndexPath:indexPath];

	NSString *name = TGEventsText(event, @"name");
	if (!name.length)
		name = TGL(@"Premium.GiftedTitle.Someone", @"Someone");

	cell.backgroundColor = [UIColor whiteColor];
	cell.contentView.backgroundColor = cell.backgroundColor;

	cell.nameLabel.text = name;
	cell.nameLabel.textColor = TGColourFromHex(0x345f8f);

	cell.bodyLabel.text = [self summaryForEvent:event];
	cell.bodyLabel.textColor = TGColourFromHex(0x536c8c);

	cell.dateLabel.text = [TGDateUtils stringForShortTime:TGEventsInt(event, @"date")];
	cell.dateLabel.textColor = TGColourFromHex(0x337acc);

	cell.hairline.backgroundColor = [[TGTheme shared] separatorColour];
	cell.selectionStyle = (TGEventsLongLong(event, @"messageId") != 0 ||
			[TGEventsNumber(event, @"isGroupHeader") boolValue])
		? UITableViewCellSelectionStyleBlue
		: UITableViewCellSelectionStyleNone;

	int64_t userId = (int64_t)TGEventsLongLong(event, @"userId");
	NSString *initials = TGEventsInitials(name);
	UIImage *avatar = [TGIcons avatarWithInitials:initials
											 size:kEventsAvatarSide
										 colourId:userId];
	cell.avatarView.image = avatar;
	[cell setNeedsLayout];
	return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell
	forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.exhausted || self.loading || !self.loaded)
		return;
	if (indexPath.section + 1 < (NSInteger)self.sections.count)
		return;
	NSInteger rows = [self tableView:tableView numberOfRowsInSection:indexPath.section];
	if (indexPath.row + 5 < rows)
		return;
	[self loadNextPage];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	NSDictionary *event = [self eventAtIndexPath:indexPath];
	if (!event)
		return;

	if ([TGEventsNumber(event, @"isGroupHeader") boolValue]) {
		[self toggleGroupExpanded:TGEventsNumber(event, @"groupKey")];
		return;
	}

	int64_t messageId = (int64_t)TGEventsLongLong(event, @"messageId");
	BOOL canReportNotSpam = [TGEventsNumber(event, @"canReportNotSpam") boolValue] && messageId != 0;
	if (messageId == 0)
		return;

	NSMutableArray *actions = [NSMutableArray array];
	TGActionSheetAction *jumpAction = [[TGActionSheetAction alloc]
		initWithTitle:TGL(@"ChatEvents.GoToMessage", @"Go to Message")
			   action:@"jump"];
	[actions addObject:jumpAction];
	if (canReportNotSpam) {
		TGActionSheetAction *notSpamAction = [[TGActionSheetAction alloc]
			initWithTitle:TGL(@"Conversation.ContextMenuReportFalsePositive", @"Report False Positive")
				   action:@"notSpam"];
		[actions addObject:notSpamAction];
	}
	TGActionSheetAction *cancelAction = [[TGActionSheetAction alloc]
		initWithTitle:TGL(@"Common.Cancel", @"Cancel")
			   action:@"cancel"
				 type:TGActionSheetActionTypeCancel];
	[actions addObject:cancelAction];

	__weak typeof(self) weakSelf = self;
	self.currentActionSheet = [[TGActionSheet alloc]
		initWithTitle:nil
			  actions:actions
		  actionBlock:^(__unused id target, NSString *action) {
			  __strong typeof(weakSelf) strongSelf = weakSelf;
			  if (!strongSelf)
				  return;
			  strongSelf.currentActionSheet = nil;
			  if ([action isEqualToString:@"jump"])
				  [strongSelf jumpToMessage:messageId];
			  else if ([action isEqualToString:@"notSpam"])
				  [strongSelf reportNotSpamForMessage:messageId];
		  }
			   target:self];
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	[self.currentActionSheet tg_showFromRect:cell.frame inView:tableView];
}

- (UIView *)sheetHostView {
	if (self.navigationController.view)
		return self.navigationController.view;
	return self.view;
}

- (void)showAlertWithMessage:(NSString *)message {
	[[[TGAlertView alloc] initWithTitle:nil message:message cancelButtonTitle:TGL(@"Common.OK", @"OK")
						  okButtonTitle:nil
						completionBlock:nil] show];
}

- (void)jumpToMessage:(int64_t)messageId {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] propertiesOfMessage:messageId inChat:self.chatId
								completion:^(NSDictionary *properties) {
									__strong typeof(weakSelf) strongSelf = weakSelf;
									if (!strongSelf)
										return;
									if (![properties isKindOfClass:[NSDictionary class]] || !properties.count) {
										[strongSelf showAlertWithMessage:
												TGL(@"ChatEvents.MessageNoLongerInChat",
													@"This message is no longer in the chat.")];
										return;
									}
									[strongSelf openChatFocusingMessage:messageId];
								}];
}

- (void)openChatFocusingMessage:(int64_t)messageId {
	for (UIViewController *existing in self.navigationController.viewControllers) {
		if (![existing isKindOfClass:[TGChatViewController class]])
			continue;
		TGChatViewController *chat = (TGChatViewController *)existing;
		if (chat.chatId != self.chatId)
			continue;
		[self.navigationController popToViewController:existing animated:YES];
		[chat scrollToMessageId:messageId];
		return;
	}

	TGChatViewController *controller = [[TGChatViewController alloc] init];
	controller.chatId = self.chatId;
	controller.chatTitle = self.chatTitle.length ? self.chatTitle : TGL(@"ChatList.UnnamedChat", @"Chat");
	controller.group = YES;
	controller.focusMessageId = messageId;
	[self.navigationController pushViewController:controller animated:YES];
}

- (void)reportNotSpamForMessage:(int64_t)messageId {
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client
		reportAntiSpamFalsePositiveForMessage:messageId
									   inChat:self.chatId
								   completion:^(BOOL ok) {
									   __strong typeof(weakSelf) strongSelf = weakSelf;
									   if (!strongSelf)
										   return;
									   if (!ok) {
										   [strongSelf showAlertWithMessage:
			TGL(@"ChatEvents.DeletionCouldNotBeReported",
				@"This deletion could not be reported as a false positive.")];
										   return;
									   }
									   [strongSelf markReported:@[ [NSNumber numberWithLongLong:messageId] ]];
									   [strongSelf showAlertWithMessage:
			TGL(@"Group.AdminLog.AntiSpamFalsePositiveReportedText",
				@"Telegram moderators will review your report. Thank you!")];
								   }];
}

@end

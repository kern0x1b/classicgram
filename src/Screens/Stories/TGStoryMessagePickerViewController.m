#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGStoryMessagePickerViewController.h"
#import "TGFlattenMessage.h"
#import "TGDateUtils.h"

#import "TGClient.h"
#import "TGClient+Stories.h"
#import "TGClient+Notifications.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGSnackbar.h"

static const NSInteger kTGStoryMessagePickerHistoryLimit = 100;

@interface TGStoryMessagePickerViewController ()
@property (nonatomic, strong) NSArray *messages;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL checkingPick;
@end

@implementation TGStoryMessagePickerViewController

- (instancetype)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.title = [[TGClient shared] titleForChatId:self.chatId] ?: @"";
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];

	UIButton *cancel = [TGIcons headerButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")
												  bold:NO
												target:self
												action:@selector(cancelPressed)];
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cancel];

	[self reload];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)cancelPressed {
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)reload {
	self.loaded = NO;
	[self.tableView reloadData];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] historyForChat:self.chatId limit:kTGStoryMessagePickerHistoryLimit
							completion:^(NSArray *found) {
								typeof(self) strongSelf = weakSelf;
								if (strongSelf == nil)
									return;
								strongSelf.messages = [found isKindOfClass:NSArray.class]
										? [found reverseObjectEnumerator].allObjects
										: @[];
								strongSelf.loaded = YES;
								[strongSelf.tableView reloadData];
							}];
}

- (NSDictionary *)messageAtRow:(NSInteger)row {
	if (row < 0 || row >= (NSInteger)self.messages.count)
		return nil;
	return self.messages[row];
}

- (NSString *)previewForMessage:(NSDictionary *)m {
	NSString *text = [m[@"text"] isKindOfClass:NSString.class] ? m[@"text"] : @"";
	if (text.length)
		return text;
	NSString *caption = [m[@"captionText"] isKindOfClass:NSString.class] ? m[@"captionText"] : @"";
	if (caption.length)
		return caption;

	NSString *kind = [m[@"kind"] isKindOfClass:NSString.class] ? m[@"kind"] : @"";
	if ([kind isEqualToString:@"messagePhoto"])
		return TGL(@"Message.Photo", @"Photo");
	if ([kind isEqualToString:@"messageVideo"])
		return TGL(@"Message.Video", @"Video");
	if ([kind isEqualToString:@"messageAnimation"])
		return TGL(@"Message.Animation", @"GIF");
	if ([kind isEqualToString:@"messageVideoNote"])
		return TGL(@"Message.VideoMessage", @"Video Message");
	if ([kind isEqualToString:@"messageVoiceNote"])
		return TGL(@"Message.Audio", @"Voice message");
	if ([kind isEqualToString:@"messageAudio"])
		return TGL(@"SharedMedia.CategoryOther", @"Audio");
	if ([kind isEqualToString:@"messageDocument"])
		return TGL(@"Message.File", @"File");
	if ([kind isEqualToString:@"messageLocation"])
		return TGL(@"Map.Location", @"Location");
	if ([kind isEqualToString:@"messageContact"])
		return TGL(@"Attachment.Contact", @"Contact");
	if ([kind isEqualToString:@"messagePoll"])
		return TGL(@"AttachmentMenu.Poll", @"Poll");
	return TGMessageKindLabel(kind) ?: @"";
}

- (NSString *)stampForMessage:(NSDictionary *)m {
	double when = [m[@"date"] isKindOfClass:NSNumber.class] ? [m[@"date"] doubleValue] : 0;
	if (when <= 0)
		return @"";
	return [TGDateUtils stringForFullDateAndTime:(int)when];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.messages.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (!self.loaded)
		return TGL(@"Story.Areas.LoadingMessages", @"Loading…");
	if (!self.messages.count)
		return TGL(@"Story.Areas.NoMessage", @"This chat has no messages yet.");
	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	CGFloat measured = [[TGTheme shared] groupedCommentHeightForText:caption width:tableView.bounds.size.width];
	return TGGroupedFooterHeight(caption, measured);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	if (!caption.length)
		return nil;
	return [[TGTheme shared] groupedCommentViewWithText:caption width:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *reuse = @"TGStoryMessagePickerCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									   reuseIdentifier:reuse];
	[[TGTheme shared] styleCell:cell];

	NSDictionary *m = [self messageAtRow:indexPath.row];
	cell.textLabel.text = [self previewForMessage:m];
	cell.textLabel.numberOfLines = 2;
	cell.detailTextLabel.text = [self stampForMessage:m];
	cell.selectionStyle = UITableViewCellSelectionStyleDefault;
	return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 56;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.checkingPick)
		return;
	NSDictionary *m = [self messageAtRow:indexPath.row];
	if (![m[@"id"] isKindOfClass:NSNumber.class]) {
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
		return;
	}
	int64_t messageId = [m[@"id"] longLongValue];
	int64_t chatId = self.chatId;

	self.checkingPick = YES;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] messageCanBeSharedInStory:messageId inChat:chatId
									   completion:^(BOOL canShare) {
										   typeof(self) strongSelf = weakSelf;
										   if (strongSelf == nil)
											   return;
										   strongSelf.checkingPick = NO;
										   [tableView deselectRowAtIndexPath:indexPath animated:YES];
										   if (!canShare) {
											   [TGSnackbar showInView:strongSelf.view
																  text:TGL(@"Story.Areas.MessageNotShareable",
																		   @"This message can't be added to your story.")
															   seconds:3
															  onCommit:nil];
											   return;
										   }
										   void (^picked)(int64_t) = strongSelf.onPicked;
										   if (picked)
											   picked(messageId);
									   }];
}

@end

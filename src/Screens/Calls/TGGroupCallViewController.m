#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGGroupCallViewController.h"
#import "TGStringTruncation.h"
#import "TGEmoji.h"
#import "TGLocalization.h"
#import "TGCallService.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGClient.h"

static NSString *TGGroupCallParticipantCountText(NSInteger participantCount) {
	return TGLPlural(@"VoiceChat.ParticipantsCount", participantCount, @"%@ participant", @"%@ participants");
}

@interface TGGroupCallSummaryView : UIView

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIView *liveDot;

@end

@implementation TGGroupCallSummaryView

- (instancetype)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (!self)
		return nil;

	self.backgroundColor = [UIColor clearColor];

	self.liveDot = [[UIView alloc] initWithFrame:CGRectMake(16, 22, 8, 8)];
	self.liveDot.layer.cornerRadius = 4;
	self.liveDot.backgroundColor = [[TGTheme shared] onlineColour];
	[self addSubview:self.liveDot];

	self.titleLabel = [[TGEmojiLabel alloc] initWithFrame:CGRectZero];
	self.titleLabel.backgroundColor = [UIColor clearColor];
	self.titleLabel.font = [UIFont boldSystemFontOfSize:20];
	self.titleLabel.textColor = [[TGTheme shared] groupedTitleColour];
	[self addSubview:self.titleLabel];

	self.statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.statusLabel.backgroundColor = [UIColor clearColor];
	self.statusLabel.font = [UIFont systemFontOfSize:14];
	self.statusLabel.textColor = [[TGTheme shared] secondaryTextColour];
	[self addSubview:self.statusLabel];

	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGFloat width = self.bounds.size.width - 32;
	self.titleLabel.frame = CGRectMake(16, 14, width, 24);
	self.statusLabel.frame = CGRectMake(30, 42, width - 14, 18);
	[self.titleLabel sizeToFit];
	self.liveDot.frame = CGRectMake(16, 46, 8, 8);
}

@end

@interface TGGroupCallViewController ()

@property (nonatomic, strong) NSDictionary *callInfo;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, strong) TGGroupCallSummaryView *summaryView;
@property (nonatomic, strong) id groupCallObserverToken;

@end

@implementation TGGroupCallViewController

- (instancetype)initWithChatId:(int64_t)chatId
				   groupCallId:(int32_t)groupCallId
						 title:(NSString *)title {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (!self)
		return nil;
	_chatId = chatId;
	_groupCallId = groupCallId;
	_fallbackTitle = title.length ? title : TGL(@"VoiceChat.Title", @"Video Chat");
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"VoiceChat.Title", @"Video Chat");
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	[self loadCallInfo];

	__weak typeof(self) weakSelf = self;
	self.groupCallObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGGroupCallDidChangeNotification
					object:nil
					 queue:[NSOperationQueue mainQueue]
				usingBlock:^(NSNotification *note) {
					TGGroupCallViewController *strongSelf = weakSelf;
					if (!strongSelf)
						return;
					if ([note.object intValue] != strongSelf.groupCallId)
						return;
					[strongSelf loadCallInfo];
				}];
}

- (void)dealloc {
	if (_groupCallObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_groupCallObserverToken];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)loadCallInfo {
	__weak typeof(self) weakSelf = self;
	[TGCallService groupCallInfo:self.groupCallId completion:^(NSDictionary *info) {
		TGGroupCallViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.loaded = YES;
		strongSelf.callInfo = info;
		[strongSelf.tableView reloadData];
	}];
}

- (NSArray *)recentSpeakers {
	NSArray *speakers = self.callInfo[@"recentSpeakers"];
	return [speakers isKindOfClass:[NSArray class]] ? speakers : @[];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)[self recentSpeakers].count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return 76;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	if (!self.summaryView)
		self.summaryView = [[TGGroupCallSummaryView alloc]
			initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 76)];

	NSString *title = self.callInfo[@"title"];
	self.summaryView.titleLabel.text = title.length ? title : self.fallbackTitle;

	BOOL active = [self.callInfo[@"isActive"] boolValue];
	self.summaryView.liveDot.hidden = !active;
	NSInteger count = [self.callInfo[@"participantCount"] integerValue];
	self.summaryView.statusLabel.text = self.loaded
		? (active ? TGGroupCallParticipantCountText(count) : TGL(@"Call.StatusEnded", @"Call Ended"))
		: TGL(@"Channel.NotificationLoading", @"Loading…");

	return self.summaryView;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (!self.loaded)
		return nil;
	if (![self recentSpeakers].count)
		return TGL(@"VoiceChat.NoParticipantsFooter", @"This build can show that a video chat is live, but it cannot join one — there is no participant list to show until you join.");
	return TGL(@"VoiceChat.RecentSpeakersFooter", @"Only the most recently speaking participants are shown here without joining. This build cannot join a video chat.");
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
	static NSString *reuse = @"TGGroupCallSpeakerCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:reuse];
	[[TGTheme shared] styleCell:cell];

	NSArray *speakers = [self recentSpeakers];
	if (indexPath.row < 0 || indexPath.row >= (NSInteger)speakers.count)
		return cell;
	NSDictionary *speaker = speakers[indexPath.row];

	NSString *name = speaker[@"name"];
	if (![name isKindOfClass:[NSString class]] || !name.length)
		name = TGL(@"Contacts.UnknownName", @"Unknown");
	cell.textLabel.text = name;
	cell.textLabel.font = [UIFont systemFontOfSize:17];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];

	BOOL speaking = [speaker[@"isSpeaking"] boolValue];
	cell.detailTextLabel.text = speaking ? TGL(@"VoiceChat.StatusSpeaking", @"Speaking") : @"";
	cell.detailTextLabel.textColor = [[TGTheme shared] onlineColour];

	NSString *initial = name.length ? TGSafeFirstCharacter(name).uppercaseString : @"?";
	cell.imageView.image = [TGIcons avatarWithInitials:initial size:36
											  colourId:[speaker[@"senderId"] longLongValue]];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	return cell;
}

@end

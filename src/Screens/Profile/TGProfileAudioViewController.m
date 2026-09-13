#import "TGGroupedCaption.h"
#import "TGClient+ChatManagement.h"
#import "TGIcons.h"
#import "TGDurationText.h"
#import "TGProfileAudioViewController.h"
#import "TGClient+Search.h"
#import "TGClient+Files.h"
#import "TGLocalization.h"
#import "TGClient+Account.h"
#import "TGTheme.h"
#import "TGSnackbar.h"

static NSString *TGProfileAudioDuration(NSInteger seconds) {
	return TGDurationText(seconds);
}

@interface TGProfileAudioPickerViewController : UITableViewController
@property (nonatomic, copy) void (^onPicked)(NSDictionary *message);
@end

@interface TGProfileAudioPickerViewController ()
@property (nonatomic, strong) NSMutableArray *candidates;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL loadFailed;
@property (nonatomic, assign) BOOL downloading;
@end

@implementation TGProfileAudioPickerViewController

- (instancetype)init {
	self = [super initWithStyle:UITableViewStylePlain];
	if (self)
		_candidates = [NSMutableArray array];
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
	self.title = TGL(@"Settings.ProfileMusicChoose", @"Choose from Saved Messages");
	self.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tableView.rowHeight = 52;
	int64_t savedId = [[TGClient shared] savedMessagesChatId];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] sharedMediaInChat:savedId
								 topicId:0
								   query:@""
							  filterName:@"searchMessagesFilterAudio"
						   fromMessageId:0
								   limit:50
							  completion:^(NSDictionary *result, int64_t nextFromMessageId) {
								  (void)nextFromMessageId;
								  __strong typeof(weakSelf) strongSelf = weakSelf;
								  if (!strongSelf)
									  return;
								  strongSelf.loaded = YES;
								  NSArray *messages = [result[@"messages"] isKindOfClass:[NSArray class]]
									  ? result[@"messages"]
									  : @[];
								  [strongSelf.candidates addObjectsFromArray:messages];
								  [strongSelf.tableView reloadData];
							  }];
}

- (NSDictionary *)audioContentAt:(NSInteger)row {
	NSDictionary *message = self.candidates[(NSUInteger)row];
	NSDictionary *content = [message[@"content"] isKindOfClass:[NSDictionary class]]
		? message[@"content"]
		: nil;
	return [content[@"audio"] isKindOfClass:[NSDictionary class]] ? content[@"audio"] : nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.candidates.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (self.loaded && self.candidates.count == 0)
		return TGL(@"Settings.ProfileMusicNoneSaved",
			@"No audio files in Saved Messages yet. Forward or send one there first, "
			@"then come back here.");
	return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"pick"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"pick"];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleDefault;
	cell.accessoryType = UITableViewCellAccessoryNone;

	NSDictionary *audio = [self audioContentAt:indexPath.row];
	NSString *title = [audio[@"title"] isKindOfClass:[NSString class]] && [audio[@"title"] length]
		? audio[@"title"]
		: [audio[@"file_name"] isKindOfClass:[NSString class]]
		? audio[@"file_name"]
		: @"Audio";
	NSString *performer = [audio[@"performer"] isKindOfClass:[NSString class]]
		? audio[@"performer"]
		: @"";
	NSInteger duration = [audio[@"duration"] integerValue];

	cell.textLabel.text = title;
	cell.detailTextLabel.text = performer.length
		? [NSString stringWithFormat:@"%@ · %@", performer, TGProfileAudioDuration(duration)]
		: TGProfileAudioDuration(duration);
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (self.downloading)
		return;

	NSDictionary *message = self.candidates[(NSUInteger)indexPath.row];
	NSDictionary *content = message[@"content"];
	NSDictionary *audio = content[@"audio"];
	NSDictionary *file = [audio[@"audio"] isKindOfClass:[NSDictionary class]] ? audio[@"audio"] : nil;
	long long fileId = [file[@"id"] longLongValue];
	if (fileId <= 0)
		return;

	self.downloading = YES;
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	NSString *previousDetail = cell.detailTextLabel.text;
	cell.detailTextLabel.text = TGL(@"DownloadList.DownloadingHeader", @"Downloading");
	cell.userInteractionEnabled = NO;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] downloadFile:fileId completion:^(NSString *path) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.downloading = NO;
		if (!path.length) {
			cell.detailTextLabel.text = previousDetail;
			cell.userInteractionEnabled = YES;
			return;
		}
		if (strongSelf.onPicked)
			strongSelf.onPicked(message);
	}];
}

@end

@interface TGProfileAudioViewController ()
@property (nonatomic, strong) NSMutableArray *audios;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL loadFailed;
@property (nonatomic, assign) int64_t myUserId;
@property (nonatomic, assign) BOOL adding;
@end

@implementation TGProfileAudioViewController

- (instancetype)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self)
		_audios = [NSMutableArray array];
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"Attachment.ProfileMusic", @"Profile Music");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tableView.rowHeight = 52;
	self.navigationItem.rightBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"Common.Add", @"Add") bold:NO
									   target:self
									   action:@selector(addTapped)];
	self.navigationItem.leftBarButtonItem = self.editButtonItem;
	[self reload];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)reload {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] accountInfoWithCompletion:^(NSDictionary *account) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.myUserId = [account[@"id"] longLongValue];
		if (!strongSelf.myUserId) {
			strongSelf.loaded = YES;
			[strongSelf.tableView reloadData];
			return;
		}
		[[TGClient shared] profileAudiosForUser:strongSelf.myUserId offset:0 limit:20
									 completion:^(NSArray *audios, BOOL failed) {
										 __strong typeof(weakSelf) innerSelf = weakSelf;
										 if (!innerSelf)
											 return;
										 innerSelf.loaded = YES;
										 innerSelf.loadFailed = failed;
										 if (!failed)
											 innerSelf.audios = [audios mutableCopy] ?: [NSMutableArray array];
										 [innerSelf.tableView reloadData];
									 }];
	}];
}

- (void)addTapped {
	TGProfileAudioPickerViewController *picker = [[TGProfileAudioPickerViewController alloc] init];
	__weak typeof(self) weakSelf = self;
	picker.onPicked = ^(NSDictionary *message) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf addFromMessage:message];
	};
	[self.navigationController pushViewController:picker animated:YES];
}

- (void)addFromMessage:(NSDictionary *)message {
	if (self.adding)
		return;

	NSDictionary *audio = message[@"content"][@"audio"];
	NSDictionary *file = audio[@"audio"];
	long long fileId = [file[@"id"] longLongValue];
	if (fileId <= 0)
		return;

	self.adding = YES;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] downloadFile:fileId completion:^(NSString *path) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!path.length) {
			strongSelf.adding = NO;
			return;
		}
		NSString *title = [audio[@"title"] isKindOfClass:[NSString class]] ? audio[@"title"] : @"";
		NSString *performer = [audio[@"performer"] isKindOfClass:[NSString class]]
			? audio[@"performer"]
			: @"";
		NSInteger duration = [audio[@"duration"] integerValue];
		void (^added)(BOOL) = ^(BOOL ok) {
			__strong typeof(weakSelf) innerSelf = weakSelf;
			if (!innerSelf)
				return;
			innerSelf.adding = NO;
			if (ok) {
				[innerSelf.navigationController popToViewController:innerSelf animated:YES];
				[innerSelf reload];
			}
		};
		TGClient *client = [TGClient shared];
		[client addProfileAudioAtPath:path title:title performer:performer duration:duration completion:added];
	}];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.audios.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (self.loadFailed)
		return TGL(@"Settings.ProfileMusicLoadFailed",
			@"The songs on your profile could not be read. What is on the profile has not "
			@"changed.");
	if (self.loaded && self.audios.count == 0)
		return TGL(@"Settings.ProfileMusicEmpty",
			@"Songs shown here play from your profile. Add one from an audio file you have "
			@"already sent to Saved Messages.");
	return TGL(@"Settings.ProfileMusicFooter",
		@"The first song is the one shown by default. Drag to reorder, swipe to remove.");
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
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"song"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"song"];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;

	NSDictionary *song = self.audios[(NSUInteger)indexPath.row];
	NSString *title = [song[@"title"] isKindOfClass:[NSString class]] && [song[@"title"] length]
		? song[@"title"]
		: @"Audio";
	NSString *performer = [song[@"performer"] isKindOfClass:[NSString class]]
		? song[@"performer"]
		: @"";
	NSInteger duration = [song[@"duration"] integerValue];
	cell.textLabel.text = title;
	cell.detailTextLabel.text = performer.length
		? [NSString stringWithFormat:@"%@ · %@", performer, TGProfileAudioDuration(duration)]
		: TGProfileAudioDuration(duration);
	return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return YES;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
	return self.audios.count > 1;
}

- (void)tableView:(UITableView *)tableView
	commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
	 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete)
		return;
	NSDictionary *song = self.audios[(NSUInteger)indexPath.row];
	long long fileId = [song[@"fileId"] longLongValue];
	[self.audios removeObjectAtIndex:(NSUInteger)indexPath.row];
	[tableView deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationFade];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] removeProfileAudioFileId:fileId completion:^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || ok)
			return;
		[TGSnackbar showInView:strongSelf.view
						  text:TGL(@"Profile.SongCouldNotBeRemoved", @"That song could not be removed.")
					   seconds:2
					  onCommit:nil];
		[strongSelf reload];
	}];
}

- (void)tableView:(UITableView *)tableView
	moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath
		   toIndexPath:(NSIndexPath *)destinationIndexPath {
	NSDictionary *song = self.audios[(NSUInteger)sourceIndexPath.row];
	[self.audios removeObjectAtIndex:(NSUInteger)sourceIndexPath.row];
	[self.audios insertObject:song atIndex:(NSUInteger)destinationIndexPath.row];

	long long movedFileId = [song[@"fileId"] longLongValue];
	long long afterFileId = destinationIndexPath.row > 0
		? [self.audios[(NSUInteger)destinationIndexPath.row - 1][@"fileId"] longLongValue]
		: 0;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setProfileAudioFileId:movedFileId
								 afterFileId:afterFileId
								  completion:^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || ok)
			return;
		[TGSnackbar showInView:strongSelf.view
						  text:TGL(@"Profile.SongsCouldNotBeReordered", @"Those songs could not be reordered.")
					   seconds:2
					  onCommit:nil];
		[strongSelf reload];
	}];
}

@end

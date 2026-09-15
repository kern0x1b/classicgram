#import "TGPaidReactorsViewController.h"
#import "TGReactionPickerViewInternal.h"
#import "TGPaidReactors.h"
#import "TGReactionService.h"
#import "TGFileDownloadService.h"
#import "TGSettingsService.h"
#import "TGProfileService.h"
#import "TGStringTruncation.h"
#import "TGTheme.h"
#import "TGLocalization.h"

@interface TGPaidReactorsViewController () <UITableViewDataSource, UITableViewDelegate> {
	int64_t _chatId;
	int64_t _messageId;
	NSArray *_rows;
	NSMutableDictionary *_photos;
	NSMutableSet *_photosRequested;
	UITableView *_tableView;
	UILabel *_statusLabel;
	UIActivityIndicatorView *_spinner;
}

@end

@implementation TGPaidReactorsViewController

- (id)initWithMessage:(int64_t)messageId chatId:(int64_t)chatId {
	self = [super init];
	if (self == nil)
		return nil;

	_messageId = messageId;
	_chatId = chatId;
	_rows = @[];
	_photos = [[NSMutableDictionary alloc] init];
	_photosRequested = [[NSMutableSet alloc] init];

	return self;
}

- (void)dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)viewDidLoad {
	[super viewDidLoad];

	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	self.title = TGL(@"Reactions.TopPaidReactors", @"Top Reactors");
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];

	UIButton *done = [TGIcons headerButtonWithTitle:TGL(@"Common.Done", @"Done") bold:YES
											 target:self
											 action:@selector(closePressed)];
	if (done != nil)
		self.navigationItem.rightBarButtonItem =
			[[UIBarButtonItem alloc] initWithCustomView:done];

	CGRect bounds = self.view.bounds;

	_tableView = [[UITableView alloc] initWithFrame:bounds style:UITableViewStylePlain];
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_tableView.dataSource = self;
	_tableView.delegate = self;
	_tableView.rowHeight = kListRowHeight;
	_tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	_tableView.separatorColor = [[TGTheme shared] separatorColour];
	_tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	[self.view addSubview:_tableView];

	_statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 60, bounds.size.width, 20)];
	_statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_statusLabel.backgroundColor = [UIColor clearColor];
	_statusLabel.textAlignment = NSTextAlignmentCenter;
	_statusLabel.font = [UIFont systemFontOfSize:14];
	_statusLabel.textColor = [[TGTheme shared] secondaryTextColour];
	_statusLabel.hidden = YES;
	[self.view addSubview:_statusLabel];

	_spinner = [[UIActivityIndicatorView alloc]
		initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	_spinner.center = CGPointMake(bounds.size.width / 2, 60);
	_spinner.autoresizingMask =
		UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	[self.view addSubview:_spinner];

	[self reload];
}

- (void)closePressed {
	if ([self respondsToSelector:@selector(dismissViewControllerAnimated:completion:)])
		[self dismissViewControllerAnimated:YES completion:nil];
	else
		[self dismissModalViewControllerAnimated:YES];
}

- (void)reload {
	[_spinner startAnimating];
	_statusLabel.hidden = YES;

	__weak typeof(self) weakSelf = self;
	[TGReactionService paidReactorsForMessage:_messageId
									   inChat:_chatId
								   completion:^(NSArray *reactors) {
									   TGPaidReactorsViewController *strongSelf = weakSelf;
									   if (strongSelf == nil)
										   return;
									   [strongSelf->_spinner stopAnimating];
									   strongSelf->_rows = TGPaidReactorsRanked(reactors);
									   [strongSelf updateTitle];
									   [strongSelf->_tableView reloadData];
									   [strongSelf updateStatus];
									   [strongSelf fetchPhotos];
								   }];
}

- (void)updateTitle {
	NSInteger total = TGPaidReactorsTotalStars(_rows);
	self.title = total > 0
		? TGPaidReactorsStarText(total)
		: TGL(@"Reactions.TopPaidReactors", @"Top Reactors");
}

- (void)updateStatus {
	if (_rows.count > 0) {
		_statusLabel.hidden = YES;
		return;
	}
	_statusLabel.text = TGL(@"ReactionPicker.NobodyHasReactedYet", @"Nobody has reacted yet");
	_statusLabel.hidden = NO;
}

- (void)fetchPhotos {
	__weak typeof(self) weakSelf = self;
	for (NSDictionary *row in _rows) {
		int64_t senderId = [[row objectForKey:@"senderId"] longLongValue];
		if (senderId == 0)
			continue;
		NSNumber *key = [NSNumber numberWithLongLong:senderId];
		if ([_photos objectForKey:key] != nil || [_photosRequested containsObject:key])
			continue;

		NSNumber *fileId = senderId > 0
			? [TGSettingsService photoFileIdForUserId:senderId]
			: [TGProfileService photoFileIdForChat:senderId];
		if (![fileId isKindOfClass:[NSNumber class]])
			continue;
		[_photosRequested addObject:key];

		[TGFileDownloadService downloadFile:[fileId longLongValue] completion:^(NSString *path) {
			if (path.length == 0) {
				TGPaidReactorsViewController *strongSelf = weakSelf;
				if (strongSelf != nil)
					[strongSelf->_photosRequested removeObject:key];
				return;
			}
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
				UIImage *thumb = TGDecodeSquareThumbnail(path, kListAvatarSide);
				dispatch_async(dispatch_get_main_queue(), ^{
					TGPaidReactorsViewController *strongSelf = weakSelf;
					if (strongSelf == nil || thumb == nil)
						return;
					[strongSelf->_photos setObject:thumb forKey:key];
					[strongSelf reloadSoon];
				});
			});
		}];
	}
}

- (void)reloadSoon {
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(reloadNow)
											   object:nil];
	[self performSelector:@selector(reloadNow) withObject:nil afterDelay:0.15f];
}

- (void)reloadNow {
	[_tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)_rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *identifier = @"TGPaidReactorCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:identifier];

	if (indexPath.row < 0 || indexPath.row >= (NSInteger)_rows.count)
		return cell;
	NSDictionary *row = [_rows objectAtIndex:(NSUInteger)indexPath.row];

	NSString *name = [row objectForKey:@"name"];
	if (![name isKindOfClass:[NSString class]] || name.length == 0)
		name = TGL(@"Reactions.UnknownReactor", @"Unknown");
	cell.textLabel.text = name;
	cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
	cell.textLabel.textColor = [[TGTheme shared] primaryTextColour];
	cell.detailTextLabel.text =
		TGPaidReactorsStarText([[row objectForKey:@"stars"] integerValue]);
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.backgroundColor = [UIColor clearColor];

	int64_t senderId = [[row objectForKey:@"senderId"] longLongValue];
	UIImage *photo = [_photos objectForKey:[NSNumber numberWithLongLong:senderId]];
	if (photo == nil)
		photo = [TGIcons avatarWithInitials:[TGSafeFirstCharacter(name) uppercaseString]
									   size:kListAvatarSide
								   colourId:senderId];
	cell.imageView.image = photo;

	return cell;
}

@end

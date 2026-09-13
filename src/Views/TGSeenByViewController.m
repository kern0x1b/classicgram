#import "TGSeenByViewController.h"
#import "TGStringTruncation.h"
#import "TGSeenByStatusText.h"
#import "TGReactionListCell.h"
#import "TGClient.h"
#import "TGClient+Messages.h"
#import "TGSettingsService.h"
#import "TGFileDownloadService.h"
#import "TGImageDecode.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGIcons.h"

static const CGFloat kSeenByAvatarSide = 40.0f;
static const CGFloat kSeenByRowHeight = 54.0f;
static const NSTimeInterval kSeenByRefreshInterval = 5.0;

@interface TGSeenByViewController () <UITableViewDataSource, UITableViewDelegate>
@end

@implementation TGSeenByViewController {
	int64_t _chatId;
	int64_t _messageId;
	NSArray *_viewers;
	NSMutableDictionary *_photos;
	NSMutableSet *_photosRequested;
	UITableView *_tableView;
	UILabel *_statusLabel;
	UIActivityIndicatorView *_spinner;
	NSTimer *_refreshTimer;
}

- (id)initWithMessageId:(int64_t)messageId chatId:(int64_t)chatId {
	self = [super init];
	if (self == nil)
		return nil;
	_messageId = messageId;
	_chatId = chatId;
	_viewers = @[];
	_photos = [[NSMutableDictionary alloc] init];
	_photosRequested = [[NSMutableSet alloc] init];
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.title = TGL(@"Chat.SeenBy", @"Seen By");
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];

	_tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
	_tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_tableView.dataSource = self;
	_tableView.delegate = self;
	_tableView.rowHeight = kSeenByRowHeight;
	_tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	_tableView.separatorColor = [[TGTheme shared] separatorColour];
	[self.view addSubview:_tableView];

	_statusLabel = [[UILabel alloc] initWithFrame:CGRectInset(self.view.bounds, 24, 24)];
	_statusLabel.textAlignment = NSTextAlignmentCenter;
	_statusLabel.numberOfLines = 0;
	_statusLabel.font = [UIFont systemFontOfSize:15];
	_statusLabel.textColor = [[TGTheme shared] secondaryTextColour];
	_statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_statusLabel.hidden = YES;
	[self.view addSubview:_statusLabel];

	_spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	_spinner.center = CGPointMake(self.view.bounds.size.width / 2, 80);
	_spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
		UIViewAutoresizingFlexibleBottomMargin;
	[_spinner startAnimating];
	[self.view addSubview:_spinner];

	[self fetchViewers];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self startRefreshTimer];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self stopRefreshTimer];
}

- (void)dealloc {
	[self stopRefreshTimer];
}

- (void)startRefreshTimer {
	[self stopRefreshTimer];
	_refreshTimer = [NSTimer scheduledTimerWithTimeInterval:kSeenByRefreshInterval
													  target:self
													selector:@selector(fetchViewers)
													userInfo:nil
													 repeats:YES];
}

- (void)stopRefreshTimer {
	[_refreshTimer invalidate];
	_refreshTimer = nil;
}

- (void)fetchViewers {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] viewersOfMessage:_messageId inChat:_chatId completion:^(NSArray *viewers, NSString *unavailableReason) {
		TGSeenByViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf->_viewers = [viewers isKindOfClass:[NSArray class]] ? viewers : @[];
		[strongSelf->_spinner stopAnimating];
		[strongSelf->_spinner removeFromSuperview];
		strongSelf->_statusLabel.hidden = strongSelf->_viewers.count > 0;
		strongSelf->_statusLabel.text = TGSeenByStatusText(unavailableReason);
		[strongSelf->_tableView reloadData];
	}];
}

- (void)fetchPhotoForUserId:(int64_t)userId {
	NSNumber *key = @(userId);
	if (_photos[key] != nil || [_photosRequested containsObject:key])
		return;
	NSNumber *fileId = [TGSettingsService photoFileIdForUserId:userId];
	if (![fileId isKindOfClass:[NSNumber class]])
		return;
	[_photosRequested addObject:key];

	__weak typeof(self) weakSelf = self;
	[TGFileDownloadService downloadFile:[fileId longLongValue] completion:^(NSString *path) {
		TGSeenByViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!path.length) {
			[strongSelf->_photosRequested removeObject:key];
			return;
		}
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
			UIImage *thumb = TGDecodeSquareThumbnail(path, kSeenByAvatarSide);
			dispatch_async(dispatch_get_main_queue(), ^{
				TGSeenByViewController *innerSelf = weakSelf;
				if (!innerSelf || !thumb)
					return;
				innerSelf->_photos[key] = thumb;
				[innerSelf->_tableView reloadData];
			});
		});
	}];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)_viewers.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *identifier = @"TGSeenByCell";
	TGReactionListCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
	if (!cell)
		cell = [[TGReactionListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];

	NSDictionary *viewer = _viewers[(NSUInteger)indexPath.row];
	int64_t userId = [viewer[@"id"] longLongValue];
	NSString *name = [viewer[@"name"] isKindOfClass:[NSString class]] ? viewer[@"name"] : @"";

	cell.nameLabel.text = name;
	cell.emojiLabel.font = [UIFont systemFontOfSize:13];
	cell.emojiLabel.textColor = [[TGTheme shared] secondaryTextColour];
	NSTimeInterval when = [viewer[@"date"] doubleValue];
	cell.emojiLabel.text = when > 0
		? [NSDateFormatter localizedStringFromDate:[NSDate dateWithTimeIntervalSince1970:when]
										  dateStyle:NSDateFormatterNoStyle
										  timeStyle:NSDateFormatterShortStyle]
		: @"";
	UIImage *photo = _photos[@(userId)];
	if (!photo) {
		NSString *initial = name.length
			? [TGSafeFirstCharacter(name) uppercaseString]
			: @"?";
		photo = [TGIcons avatarWithInitials:initial size:kSeenByAvatarSide colourId:userId];
		[self fetchPhotoForUserId:userId];
	}
	cell.avatarView.image = photo;

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end

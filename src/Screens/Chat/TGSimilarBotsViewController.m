#import "TGTableReloadCoalescer.h"
#import "TGStringTruncation.h"
#import "TGSimilarBotsViewController.h"
#import "TGClient.h"
#import "TGClient+Bots.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGFileDownloadService.h"
#import "TGImageDecode.h"
#import "TGSettingsService.h"
#import "TGContactRowMetrics.h"
#import "TGContactName.h"

@implementation TGSimilarBotsViewController {
	TGTableReloadCoalescer *_avatarReload;
	NSArray *_bots;
	NSInteger _total;
	NSMutableDictionary *_avatars;
	NSMutableSet *_avatarsRequested;
	BOOL _loading;
	UIActivityIndicatorView *_spinner;
	UILabel *_statusLabel;
}

- (id)init {
	self = [super initWithStyle:UITableViewStylePlain];
	if (!self)
		return nil;
	_avatars = [NSMutableDictionary dictionary];
	_avatarsRequested = [NSMutableSet set];
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
	self.title = TGL(@"PeerInfo.PaneRecommendedBots", @"Similar Bots");
	self.tableView.rowHeight = kContactRowHeight;
	self.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tableView.separatorColor = [[TGTheme shared] separatorColour];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];

	CGRect bounds = self.view.bounds;
	_spinner = [[UIActivityIndicatorView alloc]
		initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	_spinner.center = CGPointMake(bounds.size.width / 2, 80);
	_spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
		UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
	[self.view addSubview:_spinner];

	_statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 70, bounds.size.width - 40, 60)];
	_statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_statusLabel.backgroundColor = [UIColor clearColor];
	_statusLabel.textAlignment = NSTextAlignmentCenter;
	_statusLabel.numberOfLines = 0;
	_statusLabel.font = [UIFont systemFontOfSize:15];
	_statusLabel.textColor = [[TGTheme shared] secondaryTextColour];
	_statusLabel.hidden = YES;
	[self.view addSubview:_statusLabel];

	[self load];
}

- (void)load {
	if (_loading || !self.botUserId)
		return;
	_loading = YES;
	_statusLabel.hidden = YES;
	[_spinner startAnimating];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] similarBotsFor:self.botUserId completion:^(NSArray *bots, NSInteger total) {
		TGSimilarBotsViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf->_loading = NO;
		[strongSelf->_spinner stopAnimating];
		strongSelf->_bots = bots ?: @[];
		strongSelf->_total = total;
		[strongSelf.tableView reloadData];
		strongSelf->_statusLabel.text = bots
			? TGL(@"Chat.NoSimilarBotsWereFound", @"No similar bots were found.")
			: TGL(@"Chat.SimilarBotsLoadFailed",
				  @"The list of similar bots could not be loaded.");
		strongSelf->_statusLabel.hidden = strongSelf->_bots.count != 0;
	}];
}

- (UIImage *)avatarForUserId:(int64_t)userId name:(NSString *)name {
	NSString *initials = name.length ? TGSafeFirstCharacter(name).uppercaseString : @"#";
	UIImage *placeholder = [TGIcons avatarWithInitials:initials size:kContactAvatar colourId:userId];
	if (!userId)
		return placeholder;

	NSNumber *key = [NSNumber numberWithLongLong:userId];
	UIImage *cached = _avatars[key];
	if (cached)
		return cached;
	if ([_avatarsRequested containsObject:key])
		return placeholder;

	NSNumber *fileId = [TGSettingsService photoFileIdForUserId:userId];
	if (!fileId)
		return placeholder;

	[_avatarsRequested addObject:key];
	__weak typeof(self) weakSelf = self;
	[TGFileDownloadService downloadFile:fileId.longLongValue completion:^(NSString *path) {
		TGSimilarBotsViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf->_avatarsRequested removeObject:key];
		if (!path.length)
			return;
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			@autoreleasepool {
				UIImage *thumb = TGDecodeSquareThumbnail(path, kContactAvatar);
				dispatch_async(dispatch_get_main_queue(), ^{
					TGSimilarBotsViewController *innerSelf = weakSelf;
					if (!innerSelf || !thumb)
						return;
					innerSelf->_avatars[key] = thumb;
					if (!innerSelf->_avatarReload)
						innerSelf->_avatarReload = [[TGTableReloadCoalescer alloc]
							initWithTableView:innerSelf.tableView];
					[innerSelf->_avatarReload setNeedsReload];
				});
			}
		});
	}];
	return placeholder;
}

- (NSDictionary *)botAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row < 0 || (NSUInteger)indexPath.row >= _bots.count)
		return nil;
	return _bots[indexPath.row];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)_bots.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (!_bots.count)
		return nil;
	NSInteger count = _total > 0 ? _total : (NSInteger)_bots.count;
	return TGLPlural(@"Chat.SimilarBotsCount", count, @"%ld similar bot", @"%ld similar bots");
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *reuse = @"TGSimilarBotCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:reuse];
		cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
		cell.imageView.clipsToBounds = YES;
		cell.imageView.layer.cornerRadius = kContactAvatarCorner;
		cell.textLabel.font = [UIFont systemFontOfSize:17];
		cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
	}
	[[TGTheme shared] styleCell:cell];

	NSDictionary *bot = [self botAtIndexPath:indexPath];
	NSString *name = bot[@"name"];
	if (!name.length)
		name = bot[@"username"];
	if (!name.length)
		name = TGL(@"Attachment.Bot", @"Bot");
	cell.textLabel.text = name;

	NSString *username = bot[@"username"];
	cell.detailTextLabel.text = username.length ? [NSString stringWithFormat:@"@%@", username] : nil;

	int64_t userId = [bot[@"id"] longLongValue];
	cell.imageView.image = [self avatarForUserId:userId name:name];

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSDictionary *bot = [self botAtIndexPath:indexPath];
	if (!bot)
		return;
	void (^pick)(NSDictionary *) = self.onPick;
	[self.navigationController popViewControllerAnimated:YES];
	if (pick)
		pick(bot);
}

@end

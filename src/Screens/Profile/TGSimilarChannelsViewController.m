#import "TGTableReloadCoalescer.h"
#import "TGStringTruncation.h"
#import "TGSimilarChannelsViewController.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGFileDownloadService.h"
#import "TGImageDecode.h"
#import "TGContactRowMetrics.h"
#import "TGContactName.h"
#import "TGProfileStyle.h"

@implementation TGSimilarChannelsViewController {
	TGTableReloadCoalescer *_avatarReload;
	NSMutableDictionary *_avatars;
	NSMutableSet *_avatarsRequested;
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
	NSInteger count = MAX(self.total, (NSInteger)self.chats.count);
	self.title = [NSString stringWithFormat:TGL(@"PeerInfo.PaneRecommended", @"Similar Channels (%ld)"), (long)count];
	self.tableView.rowHeight = kContactRowHeight;
	self.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tableView.separatorColor = [[TGTheme shared] separatorColour];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (UIImage *)avatarForChat:(NSDictionary *)chat title:(NSString *)title {
	int64_t chatId = TGProfileInt64(chat[@"id"]);
	NSString *initials = title.length ? TGSafeFirstCharacter(title).uppercaseString : @"#";
	UIImage *placeholder = [TGIcons avatarWithInitials:initials size:kContactAvatar colourId:chatId];

	int64_t fileId = TGProfileInt64(chat[@"photoFileId"]);
	if (!fileId)
		return placeholder;

	NSNumber *key = [NSNumber numberWithLongLong:chatId];
	UIImage *cached = _avatars[key];
	if (cached)
		return cached;
	if ([_avatarsRequested containsObject:key])
		return placeholder;

	[_avatarsRequested addObject:key];
	__weak typeof(self) weakSelf = self;
	[TGFileDownloadService downloadFile:fileId completion:^(NSString *path) {
		TGSimilarChannelsViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf->_avatarsRequested removeObject:key];
		if (!path.length)
			return;
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			@autoreleasepool {
				UIImage *thumb = TGDecodeSquareThumbnail(path, kContactAvatar);
				dispatch_async(dispatch_get_main_queue(), ^{
					TGSimilarChannelsViewController *innerSelf = weakSelf;
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

- (NSDictionary *)chatAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row < 0 || (NSUInteger)indexPath.row >= self.chats.count)
		return nil;
	return self.chats[indexPath.row];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.chats.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *reuse = @"TGSimilarChannelCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:reuse];
		cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
		cell.imageView.clipsToBounds = YES;
		cell.imageView.layer.cornerRadius = kContactAvatarCorner;
		cell.textLabel.font = [UIFont systemFontOfSize:17];
	}
	[[TGTheme shared] styleCell:cell];

	NSDictionary *chat = [self chatAtIndexPath:indexPath];
	NSString *title = TGProfileText(chat[@"title"]) ?: TGL(@"Channel.Setup.Title", @"Channel");
	cell.textLabel.text = title;
	cell.imageView.image = [self avatarForChat:chat title:title];

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSDictionary *chat = [self chatAtIndexPath:indexPath];
	if (!chat)
		return;
	void (^pick)(NSDictionary *) = self.onPick;
	[self.navigationController popViewControllerAnimated:YES];
	if (pick)
		pick(chat);
}

@end

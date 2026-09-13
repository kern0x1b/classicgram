#import "TGListBackground.h"
#import "TGStorageViewController.h"
#import "TGStorageInternal.h"
#import "TGStorageChatViewController.h"
#import "TGStorageDownloadsViewController.h"
#import "TGLocalization.h"
#import "TGStorageService.h"
#import "TGDiskCache.h"
#import "TGRemoteImageView.h"
#import "TGTheme.h"
#import <QuartzCore/QuartzCore.h>
#import "TGActionSheetIndexBuilder.h"
#import <math.h>
#import "TGByteFormat.h"

void TGStorageApplyTableBackground(UITableView *tableView) {
	UIView *backdrop = [[UIView alloc] initWithFrame:tableView.bounds];
	backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	backdrop.backgroundColor = TGGroupedListBackground();
	tableView.backgroundView = backdrop;
	tableView.backgroundColor = [UIColor clearColor];
	tableView.opaque = NO;
}

UIView *TGStorageDisclosureIndicator(void) {
	UIImage *image = TGLocalizedDirectionalImage([UIImage imageNamed:@"MenuDisclosureIndicator.png"]);
	if (!image)
		return nil;
	UIImage *highlighted = TGLocalizedDirectionalImage([UIImage imageNamed:@"MenuDisclosureIndicator_Highlighted.png"]);
	UIImageView *view = [[UIImageView alloc] initWithImage:image highlightedImage:highlighted];
	return view;
}

NSString *const TGStorageLocalThumbnailKind = @"tgLocalThumbnails";

const NSInteger kStorageTTLValues[4] = {3 * 24 * 60 * 60,
	7 * 24 * 60 * 60,
	30 * 24 * 60 * 60,
	-1};

long long TGStorageDiskTotalBytes(void) {
	static long long total = -2;
	if (total == -2) {
		total = 0;
		NSDictionary *attributes = [[NSFileManager defaultManager]
			attributesOfFileSystemForPath:NSHomeDirectory()
									error:NULL];
		id value = [attributes objectForKey:NSFileSystemSize];
		if ([value respondsToSelector:@selector(longLongValue)])
			total = [value longLongValue];
	}
	return total;
}

long long TGStorageDiskFreeBytes(void) {
	NSDictionary *attributes = [[NSFileManager defaultManager]
		attributesOfFileSystemForPath:NSHomeDirectory()
								error:NULL];
	id value = [attributes objectForKey:NSFileSystemFreeSize];
	if ([value respondsToSelector:@selector(longLongValue)])
		return [value longLongValue];
	return 0;
}

const long long TGStorageSizeLadder[8] = {256LL * 1024 * 1024,
	512LL * 1024 * 1024,
	1LL * 1024 * 1024 * 1024,
	2LL * 1024 * 1024 * 1024,
	5LL * 1024 * 1024 * 1024,
	8LL * 1024 * 1024 * 1024,
	16LL * 1024 * 1024 * 1024,
	32LL * 1024 * 1024 * 1024};

long long TGStorageSizeValueAtIndex(NSInteger index) {
	static long long choices[4] = {0, 0, 0, -1};
	if (choices[0] == 0) {
		long long total = TGStorageDiskTotalBytes();
		long long ceiling = total > 0 ? total / 4 : 0;
		NSInteger picked = 0;
		long long found[3] = {0, 0, 0};
		for (NSInteger i = 7; i >= 0 && picked < 3; i--) {
			if (ceiling > 0 && TGStorageSizeLadder[i] > ceiling)
				continue;
			found[picked++] = TGStorageSizeLadder[i];
		}
		if (picked < 3) {
			for (NSInteger i = 0; i < 3; i++)
				found[i] = TGStorageSizeLadder[2 - i];
		}
		choices[0] = found[2];
		choices[1] = found[1];
		choices[2] = found[0];
	}
	if (index < 0 || index > 3)
		return -1;
	return choices[index];
}

NSString *TGStorageTTLName(NSInteger ttl) {
	if (ttl <= 0)
		return TGL(@"MessageTimer.Forever", @"Forever");
	if (ttl <= 3 * 24 * 60 * 60)
		return TGLPlural(@"MessageTimer.Days", 3, @"%ld day", @"%ld days");
	if (ttl <= 7 * 24 * 60 * 60)
		return TGLPlural(@"MessageTimer.Weeks", 1, @"%ld week", @"%ld weeks");
	if (ttl <= 30 * 24 * 60 * 60)
		return TGLPlural(@"MessageTimer.Months", 1, @"%ld month", @"%ld months");
	return TGLPlural(@"MessageTimer.Days", (NSInteger)(ttl / (24 * 60 * 60)), @"%ld day", @"%ld days");
}

NSString *TGStorageSizeName(long long maxBytes) {
	if (maxBytes <= 0)
		return TGL(@"Cache.NoLimit", @"No Limit");
	return TGMediaFormatBytes(maxBytes);
}

@implementation TGStorageViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"Cache.Title", @"Storage");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	TGStorageApplyTableBackground(self.tableView);
	self.tableView.separatorColor = [[TGTheme shared] bubbleBorderColour];
	TGApplyRTLTableMirroring(self.tableView);
	[self refresh];
	[self refreshDetail];
}

- (void)tableView:(UITableView *)tableView
	  willDisplayCell:(UITableViewCell *)cell
	forRowAtIndexPath:(NSIndexPath *)indexPath {
	TGApplyRTLCellMirroring(cell);
}

- (void)refresh {
	if (self.refreshing)
		return;
	self.refreshing = YES;
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(statsTimedOut)
											   object:nil];

	__weak typeof(self) weakSelf = self;
	[TGStorageService storageStatsWithCompletion:^(long long bytes, NSInteger files) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf || !strongSelf.refreshing)
			return;
		[NSObject cancelPreviousPerformRequestsWithTarget:strongSelf selector:@selector(statsTimedOut) object:nil];
		strongSelf.refreshing = NO;
		strongSelf.loaded = YES;
		strongSelf.bytes = bytes < 0 ? 0 : bytes;
		strongSelf.files = files < 0 ? 0 : files;
		[strongSelf.tableView reloadData];
	}];

	[TGStorageService storageOverviewWithCompletion:^(NSDictionary *overview) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf || !overview)
			return;
		strongSelf.overview = overview;
		[strongSelf.tableView reloadData];
	}];

	[TGStorageService downloadTotalsWithCompletion:^(NSDictionary *counts) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf || !counts)
			return;
		strongSelf.downloadCounts = counts;
		[strongSelf.tableView reloadData];
	}];

	[self performSelector:@selector(statsTimedOut) withObject:nil afterDelay:20.0];
}

- (NSString *)downloadsDetailText {
	if (!self.downloadCounts)
		return @"";
	NSInteger active = [[self.downloadCounts objectForKey:@"active"] integerValue];
	NSInteger paused = [[self.downloadCounts objectForKey:@"paused"] integerValue];
	NSInteger completed = [[self.downloadCounts objectForKey:@"completed"] integerValue];
	if (active + paused + completed == 0)
		return TGL(@"Storage.DownloadsNone", @"None");
	NSString *done = TGLPlural(@"Storage.DownloadsCompletedCount", completed, @"1 done", @"%ld done");
	if (active + paused == 0)
		return done;
	NSString *inProgress = TGLPlural(@"Storage.DownloadsInProgressCount", active + paused,
		@"1 in progress", @"%ld in progress");
	return [NSString stringWithFormat:@"%@, %@", inProgress, done];
}

- (NSInteger)summaryBaseRows {
	return self.overview ? 4 : 3;
}

- (void)openDownloads {
	TGStorageDownloadsViewController *controller =
		[[TGStorageDownloadsViewController alloc] init];
	__weak typeof(self) weakSelf = self;
	controller.didChange = ^{
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf refresh];
		[strongSelf refreshDetail];
	};
	[self.navigationController pushViewController:controller animated:YES];
}

- (void)refreshDetail {
	if (self.detailLoading)
		return;
	self.detailLoading = YES;
	[self.tableView reloadData];

	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
		long long local = (long long)[TGDiskCache imageBytesOnDisk];
		dispatch_async(dispatch_get_main_queue(), ^{
			typeof(self) strongSelf = weakSelf;
			if (!strongSelf)
				return;
			strongSelf.localThumbnailBytes = local;
			if (strongSelf.detailLoaded)
				[strongSelf.tableView reloadData];
		});
	});
	[TGStorageService storageUsageDetailWithChatLimit:24
											completion:^(NSDictionary *sizes, long long totalBytes, NSArray *chats) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[NSObject cancelPreviousPerformRequestsWithTarget:strongSelf selector:@selector(detailTimedOut) object:nil];
		strongSelf.typeRows = [strongSelf sortedTypeRowsFrom:sizes];
		strongSelf.chatRows = [strongSelf filteredChatRowsFrom:chats];
		strongSelf.detailLoading = NO;
		strongSelf.detailLoaded = YES;
		[strongSelf.tableView reloadData];
	}];

	[self performSelector:@selector(detailTimedOut) withObject:nil afterDelay:90.0];
}

- (void)detailTimedOut {
	if (!self.detailLoading)
		return;
	self.detailLoading = NO;
	self.detailLoaded = YES;
	[self.tableView reloadData];
}

- (NSArray *)sortedTypeRowsFrom:(NSDictionary *)sizes {
	NSMutableArray *rows = [NSMutableArray array];
	for (NSString *kind in sizes) {
		NSDictionary *entry = [sizes objectForKey:kind];
		if (![entry isKindOfClass:[NSDictionary class]])
			continue;
		long long size = [[entry objectForKey:@"size"] longLongValue];
		if (size <= 0)
			continue;
		[rows addObject:@{@"kind" : kind,
			@"title" : TGStorageKindName(kind),
			@"size" : [NSNumber numberWithLongLong:size],
			@"count" : [entry objectForKey:@"count"] ?: [NSNumber numberWithInt:0]}];
	}
	[rows sortUsingComparator:^NSComparisonResult(id a, id b) {
		long long sa = [[a objectForKey:@"size"] longLongValue];
		long long sb = [[b objectForKey:@"size"] longLongValue];
		if (sa == sb)
			return NSOrderedSame;
		return sa > sb ? NSOrderedAscending : NSOrderedDescending;
	}];
	return rows;
}

- (void)purgeLocalThumbnailsWithCompletion:(void (^)(long long freed))completion {
	[TGRemoteImageView tgPurgeMemoryCache];
	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
		long long before = (long long)[TGDiskCache imageBytesOnDisk];
		[TGDiskCache clearImages];
		long long after = (long long)[TGDiskCache imageBytesOnDisk];
		dispatch_async(dispatch_get_main_queue(), ^{
			typeof(self) strongSelf = weakSelf;
			if (strongSelf)
				strongSelf.localThumbnailBytes = after;
			if (completion)
				completion(before - after);
		});
	});
}

- (NSArray *)filteredChatRowsFrom:(NSArray *)chats {
	NSMutableArray *rows = [NSMutableArray array];
	for (NSDictionary *chat in chats) {
		if (![chat isKindOfClass:[NSDictionary class]])
			continue;
		long long size = [[chat objectForKey:@"size"] longLongValue];
		if (size <= 0)
			continue;
		int64_t chatId = (int64_t)[[chat objectForKey:@"chatId"] longLongValue];
		NSString *title = [chat objectForKey:@"title"];
		if (![title isKindOfClass:[NSString class]] || !title.length)
			title = chatId == 0 ? TGL(@"Storage.OtherFiles", @"Other files") : TGL(@"Storage.UnknownChat", @"Unknown chat");
		[rows addObject:@{@"chatId" : [NSNumber numberWithLongLong:chatId],
			@"title" : title,
			@"size" : [NSNumber numberWithLongLong:size]}];
		if (rows.count >= 24)
			break;
	}
	return rows;
}

- (void)statsTimedOut {
	if (!self.refreshing)
		return;
	self.refreshing = NO;
	self.working = NO;
	[self.tableView reloadData];
}

- (BOOL)cacheIsEmpty {
	return self.loaded && self.bytes <= 0 && self.files <= 0;
}

- (BOOL)canClear {
	return self.loaded && !self.working && ![self cacheIsEmpty];
}

- (void)dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	if (self.loaded && !self.working)
		[self refresh];
}

@end

#import "TGGroupedCaption.h"
#import "TGOwnedStickerSetsViewController.h"
#import "TGStringTruncation.h"
#import "TGStickerCatalogService.h"
#import "TGAccountInfoService.h"
#import "TGStickerSetEditorViewController.h"
#import "TGStickerThumbnailCache.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGOwnedSetsPresenter.h"
#import "TGOwnedSetsRowBridge.h"
#import "TGOwnedSetPageMerge.h"

static const CGFloat kSetRowHeight = 51.0f;
static const CGFloat kCoverSide = 40.0f;
static const NSInteger kOwnedSetsPageSize = 100;

@interface TGOwnedStickerSetsViewController () <UITableViewDataSource, UITableViewDelegate, TGOwnedSetsRowBridgeDelegate>

@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) NSArray *sets;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL loadingMore;
@property (nonatomic, assign) BOOL exhausted;
@property (nonatomic, assign) NSInteger generation;
@property (nonatomic, assign) int64_t userId;
@property (nonatomic, strong) TGOwnedSetsPresenter *rowPresenter;
@property (nonatomic, strong) TGOwnedSetsRowBridge *rowBridge;

@end

@implementation TGOwnedStickerSetsViewController

- (instancetype)init {
	self = [super init];
	if (self) {
		_rowPresenter = [[TGOwnedSetsPresenter alloc] init];
		_rowBridge = [[TGOwnedSetsRowBridge alloc] initWithPresenter:_rowPresenter];
		_rowBridge.delegate = self;
	}
	return self;
}

- (UIImage *)ownedSetsRowBridge:(TGOwnedSetsRowBridge *)bridge thumbnailImageForKey:(NSString *)thumbnailKey {
	return [TGStickerThumbnailCache cachedThumbnailForUniqueId:thumbnailKey side:kCoverSide];
}

- (void)ownedSetsRowBridge:(TGOwnedSetsRowBridge *)bridge
		loadThumbnailForKey:(NSString *)thumbnailKey
					 fileId:(int64_t)fileId
				 completion:(void (^)(UIImage *image))completion {
	[TGStickerThumbnailCache thumbnailForFileId:fileId
										uniqueId:thumbnailKey
											side:kCoverSide
									  completion:completion];
}

- (void)syncRowPresenter {
	[self.rowPresenter updateWithSets:self.sets];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"Stickers.MyStickerSets", @"My Sticker Sets");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];

	self.table = [[UITableView alloc] initWithFrame:self.view.bounds
											  style:UITableViewStyleGrouped];
	self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.table.dataSource = self;
	self.table.delegate = self;
	self.table.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	self.table.backgroundColor = [[TGTheme shared] listBackgroundColour];
	[self.view addSubview:self.table];

	self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:
			UIActivityIndicatorViewStyleGray];
	self.spinner.hidesWhenStopped = YES;
	[self.view addSubview:self.spinner];

	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];

	[TGAccountInfoService accountInfoWithCompletion:^(NSDictionary *account) {
		self.userId = [account[@"id"] longLongValue];
	}];

	[self reload];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	self.spinner.center = CGPointMake(floorf(self.view.bounds.size.width / 2),
		floorf(self.view.bounds.size.height / 2));
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self reload];
}

- (void)reload {
	[self.spinner startAnimating];
	self.generation++;
	self.loadingMore = NO;
	self.exhausted = NO;
	NSInteger generation = self.generation;
	__weak typeof(self) weakSelf = self;
	[TGStickerCatalogService
		ownedStickerSetsFromSetId:0
							limit:kOwnedSetsPageSize
					   completion:^(NSArray *sets, __unused NSInteger total) {
						   __strong typeof(weakSelf) strongSelf = weakSelf;
						   if (!strongSelf || strongSelf.generation != generation)
							   return;
						   [strongSelf.spinner stopAnimating];
						   strongSelf.loaded = YES;
						   strongSelf.sets = sets ?: @[];
						   strongSelf.exhausted = (NSInteger)strongSelf.sets.count < kOwnedSetsPageSize;
						   [strongSelf.table reloadData];
					   }];
}

- (void)loadMore {
	if (self.loadingMore || self.exhausted || !self.sets.count)
		return;
	NSDictionary *last = [self.sets lastObject];
	int64_t offsetSetId = [last[@"id"] longLongValue];
	if (!offsetSetId) {
		self.exhausted = YES;
		return;
	}
	self.loadingMore = YES;
	NSInteger generation = self.generation;
	__weak typeof(self) weakSelf = self;
	[TGStickerCatalogService
		ownedStickerSetsFromSetId:offsetSetId
							limit:kOwnedSetsPageSize
					   completion:^(NSArray *sets, __unused NSInteger total) {
						   __strong typeof(weakSelf) strongSelf = weakSelf;
						   if (!strongSelf || strongSelf.generation != generation)
							   return;
						   strongSelf.loadingMore = NO;
						   NSArray *merged = TGOwnedSetsWithPageAppended(strongSelf.sets, sets);
						   if (!merged || (NSInteger)sets.count < kOwnedSetsPageSize)
							   strongSelf.exhausted = YES;
						   if (!merged)
							   return;
						   strongSelf.sets = merged;
						   [strongSelf.table reloadData];
					   }];
}

- (void)tableView:(UITableView *)tableView
	willDisplayCell:(UITableViewCell *)cell
  forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section != 1 || !self.sets.count)
		return;
	if (indexPath.row >= (NSInteger)self.sets.count - 1)
		[self loadMore];
}

- (void)createTapped {
	TGStickerSetEditorViewController *editor = [[TGStickerSetEditorViewController alloc] init];
	editor.userId = self.userId;
	[self.navigationController pushViewController:editor animated:YES];
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return section == 0 ? 1 : (NSInteger)self.sets.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return indexPath.section == 0 ? TGActionRowHeight() : kSetRowHeight;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section != 1)
		return nil;
	if (!self.loaded)
		return TGL(@"Channel.NotificationLoading", @"Loading…");
	if (self.sets.count == 0)
		return TGL(@"Stickers.NoOwnedSets", @"Sticker sets you create show up here, ready to edit or delete.");
	return TGL(@"Stickers.OwnedSetsFooter", @"Tap a set to add or remove stickers, rename it, or delete it.");
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForFooterInSection:section];
	CGFloat measured = [[TGTheme shared] groupedCommentHeightForText:title width:tableView.bounds.size.width];
	return TGGroupedFooterHeight(title, measured);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	TGTheme *theme = [TGTheme shared];
	NSString *text = [self tableView:tableView titleForFooterInSection:section];
	return [theme groupedCommentViewWithText:text width:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	[self syncRowPresenter];

	if (indexPath.section == 0) {
		if ([self.rowBridge ownsCreateRow])
			return [self.rowBridge cellForCreateRowInTable:tableView];

		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"create"];
		if (!cell)
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
										  reuseIdentifier:@"create"];
		[TGIcons actionButtonInCell:cell
							  title:TGL(@"ImportStickerPack.CreateNewStickerSet", @"Create a Sticker Set")
							   kind:TGActionButtonKindNeutral
							 target:self
							 action:@selector(createTapped)];
		return cell;
	}

	if ([self.rowBridge ownsSetRowAtIndex:indexPath.row])
		return [self.rowBridge cellForSetRow:indexPath.row inTable:tableView];

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"set"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"set"];
	[[TGTheme shared] styleCell:cell];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

	if ((NSUInteger)indexPath.row >= self.sets.count)
		return cell;
	NSDictionary *set = self.sets[indexPath.row];
	cell.textLabel.text = set[@"title"];
	NSInteger count = [set[@"count"] integerValue];
	cell.detailTextLabel.text = TGLPlural(@"StickerPack.StickerCount", count, @"1 sticker", @"%d stickers");

	NSString *title = set[@"title"];
	NSString *initials = title.length ? [TGSafeFirstCharacter(title) uppercaseString] : @"?";
	cell.imageView.image = [TGIcons avatarWithInitials:initials size:kCoverSide
											  colourId:[set[@"id"] longLongValue]];
	cell.imageView.contentMode = UIViewContentModeScaleAspectFit;

	NSArray *covers = set[@"covers"];
	NSDictionary *cover = covers.count ? covers[0] : nil;
	long long thumbId = [cover[@"thumbId"] longLongValue];
	NSString *uniqueId = thumbId ? cover[@"thumbUniqueId"] : cover[@"uniqueId"];
	if (uniqueId.length) {
		UIImage *cached = [TGStickerThumbnailCache cachedThumbnailForUniqueId:uniqueId side:kCoverSide];
		if (cached) {
			cell.imageView.image = cached;
		} else {
			long long fileId = thumbId ?: [cover[@"fileId"] longLongValue];
			[TGStickerThumbnailCache
				thumbnailForFileId:fileId
						  uniqueId:uniqueId
							  side:kCoverSide
						completion:^(UIImage *image) {
							if (!image)
								return;
							UITableViewCell *fresh = [tableView cellForRowAtIndexPath:indexPath];
							fresh.imageView.image = image;
							[fresh setNeedsLayout];
						}];
		}
	}

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section == 0)
		return;
	if ((NSUInteger)indexPath.row >= self.sets.count)
		return;
	TGStickerSetEditorViewController *editor = [[TGStickerSetEditorViewController alloc] init];
	editor.userId = self.userId;
	editor.set = self.sets[indexPath.row];
	[self.navigationController pushViewController:editor animated:YES];
}

@end

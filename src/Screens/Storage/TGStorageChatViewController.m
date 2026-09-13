#import "TGGroupedCaption.h"
#import "TGIcons.h"
#import "TGStorageChatViewController.h"
#import "TGStorageInternal.h"
#import "TGLocalization.h"
#import "TGStorageService.h"
#import "TGTheme.h"
#import "TGActionSheet.h"
#import "TGActionSheetIndexBuilder.h"
#import "TGDevice.h"
#import "TGByteFormat.h"
#import "TGHexColour.h"

@interface TGStorageChatViewController ()
@property (nonatomic, assign) BOOL working;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, strong) NSArray *typeRows;
@end

static NSInteger const TGStorageChatSectionSummary = 0;
static NSInteger const TGStorageChatSectionTypes = 1;
static NSInteger const TGStorageChatSectionClear = 2;

@implementation TGStorageChatViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = self.chatTitle.length ? self.chatTitle : TGL(@"ChatList.UnnamedChat", @"Chat");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	TGStorageApplyTableBackground(self.tableView);
	self.tableView.separatorColor = [[TGTheme shared] bubbleBorderColour];
	[self reload];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)reload {
	__weak typeof(self) weakSelf = self;
	[TGStorageService storageUsageForChat:self.chatId
							   completion:^(long long bytes, NSInteger files) {
								   typeof(self) strongSelf = weakSelf;
								   if (!strongSelf)
									   return;
								   strongSelf.loaded = YES;
								   strongSelf.bytes = bytes < 0 ? 0 : bytes;
								   strongSelf.files = files < 0 ? 0 : files;
								   [strongSelf.tableView reloadData];
							   }];
	[TGStorageService storageUsageByFileTypeForChat:self.chatId
										  completion:^(NSDictionary *sizes) {
											  typeof(self) strongSelf = weakSelf;
											  if (!strongSelf)
												  return;
											  strongSelf.typeRows = [strongSelf sortedTypeRowsFrom:sizes];
											  [strongSelf.tableView reloadData];
										  }];
}

- (NSArray *)sortedTypeRowsFrom:(NSDictionary *)sizes {
	NSMutableArray *rows = [NSMutableArray array];
	for (NSString *kind in sizes) {
		NSDictionary *entry = sizes[kind];
		if (![entry isKindOfClass:[NSDictionary class]])
			continue;
		long long size = [entry[@"size"] longLongValue];
		if (size <= 0)
			continue;
		[rows addObject:@{@"title" : TGStorageKindName(kind),
			@"size" : @(size)}];
	}
	[rows sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
		long long sa = [a[@"size"] longLongValue];
		long long sb = [b[@"size"] longLongValue];
		if (sa == sb)
			return NSOrderedSame;
		return sa > sb ? NSOrderedAscending : NSOrderedDescending;
	}];
	return rows;
}

- (BOOL)canClear {
	return !self.working && self.bytes > 0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == TGStorageChatSectionSummary)
		return 2;
	if (section == TGStorageChatSectionTypes)
		return (NSInteger)self.typeRows.count;
	return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == TGStorageChatSectionClear)
		return TGActionRowHeight();
	return 44;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	if (section == TGStorageChatSectionTypes && self.typeRows.count == 0)
		return 0;
	return section == TGStorageChatSectionSummary ? 46 : 14;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	if (section == TGStorageChatSectionClear)
		return nil;
	if (section == TGStorageChatSectionTypes && self.typeRows.count == 0)
		return nil;
	TGTheme *theme = [TGTheme shared];
	NSString *title = section == TGStorageChatSectionSummary
		? TGL(@"Storage.CachedInThisChat", @"Cached in this chat")
		: TGL(@"Cache.ByTypeHeader", @"By media type");
	return [theme groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:@"row"];
	[[TGTheme shared] styleCell:cell];
	cell.accessoryView = nil;
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.textLabel.highlightedTextColor = [UIColor whiteColor];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	cell.detailTextLabel.highlightedTextColor = [UIColor whiteColor];
	cell.detailTextLabel.text = @"";

	if (indexPath.section == TGStorageChatSectionSummary) {
		if (indexPath.row == 0) {
			cell.textLabel.text = TGL(@"Storage.SizeOnDisk", @"Size on disk");
			cell.detailTextLabel.text = self.bytes > 0 ? TGMediaFormatBytes(self.bytes) : TGL(@"Cache.ClearEmpty", @"Empty");
		} else {
			cell.textLabel.text = TGL(@"PeerInfo.PaneFiles", @"Files");
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)self.files];
		}
		if (!self.loaded) {
			cell.detailTextLabel.text = @"";
			UIActivityIndicatorView *view = [[UIActivityIndicatorView alloc]
				initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
			[view startAnimating];
			cell.accessoryView = view;
		}
		return cell;
	}

	if (indexPath.section == TGStorageChatSectionTypes) {
		if (indexPath.row < (NSInteger)self.typeRows.count) {
			NSDictionary *row = self.typeRows[indexPath.row];
			cell.textLabel.text = row[@"title"];
			cell.detailTextLabel.text = TGMediaFormatBytes([row[@"size"] longLongValue]);
		}
		return cell;
	}

	UIButton *clear = [TGIcons actionButtonInCell:cell
										    title:TGL(@"Conversation.ClearCache", @"Clear Cache")
											 kind:TGActionButtonKindDestructive
										   target:self
										   action:@selector(presentClearSheet:)];
	[TGIcons setActionButton:clear enabled:[self canClear]];
	if (self.working) {
		UIActivityIndicatorView *view = [[UIActivityIndicatorView alloc]
			initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
		[view startAnimating];
		cell.accessoryView = view;
	}
	return cell;
}

- (void)presentClearSheet:(UIButton *)sender {
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:nil
					  delegate:self
				   otherTitles:@[ TGL(@"Conversation.ClearCache", @"Clear Cache") ]
			  destructiveIndex:0
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	UIView *anchor = sender.superview ?: self.view;
	[sheet tg_showFromRect:sender.frame inView:anchor];
}

- (void)actionSheet:(UIActionSheet *)actionSheet
	clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex != actionSheet.destructiveButtonIndex || ![self canClear])
		return;
	self.working = YES;
	[self.tableView reloadData];
	[self performSelector:@selector(clearTimedOut) withObject:nil afterDelay:60.0];

	__weak typeof(self) weakSelf = self;
	void (^clearFinished)(long long) = ^(long long freed) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf || !strongSelf.working)
			return;
		[NSObject cancelPreviousPerformRequestsWithTarget:strongSelf selector:@selector(clearTimedOut) object:nil];
		strongSelf.working = NO;
		strongSelf.bytes = 0;
		strongSelf.files = 0;
		strongSelf.typeRows = @[];
		[strongSelf.tableView reloadData];
		[strongSelf reload];
		if (strongSelf.didChange)
			strongSelf.didChange();

		NSString *message = freed > 0
			? [NSString stringWithFormat:TGL(@"ClearCache.Success", @"%@ freed on your %@!"),
				TGMediaFormatBytes(freed), [TGDevice modelName] ?: @"device"]
			: TGL(@"Storage.NothingToClear", @"There was nothing to clear.");
		UIAlertView *alert = [UIAlertView alloc];
		alert = [alert initWithTitle:TGL(@"Cache.Title", @"Storage")
							 message:message
							delegate:nil
				   cancelButtonTitle:TGL(@"Common.OK", @"OK")
				   otherButtonTitles:nil];
		[alert show];
	};
	[TGStorageService clearCacheForChat:self.chatId completion:clearFinished];
}

- (void)clearTimedOut {
	if (!self.working)
		return;
	self.working = NO;
	[self.tableView reloadData];
}

@end

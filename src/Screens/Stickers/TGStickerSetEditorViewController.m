#import "TGGroupedCaption.h"
#import "TGStickerSetEditorViewController.h"
#import "TGFriendlyError.h"
#import "TGClient+Stickers.h"
#import "TGStickerImagePreparer.h"
#import "TGStickerThumbnailCache.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGAlertView.h"
#import "TGActionSheetIndexBuilder.h"

static const CGFloat kFieldRowHeight = 44.0f;
static const CGFloat kStickerRowHeight = 51.0f;
static const CGFloat kThumbSide = 40.0f;

static const NSInteger kAlertEmoji = 1;
static const NSInteger kAlertKeywords = 2;
static const NSInteger kAlertRename = 3;
static const NSInteger kAlertDeleteConfirm = 4;
static const NSInteger kAlertChooseName = 5;
static const NSInteger kAlertChooseLink = 6;

static const NSInteger kSheetNavActions = 10;
static const NSInteger kSheetStickerActions = 20;

@interface TGStickerSetEditorViewController () <UITableViewDataSource, UITableViewDelegate,
	UIAlertViewDelegate, UIActionSheetDelegate,
	UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) NSMutableArray *stickers;
@property (nonatomic, strong) NSString *pendingTitle;
@property (nonatomic, strong) NSString *pendingName;
@property (nonatomic, assign) BOOL busy;
@property (nonatomic, strong) NSIndexPath *actionIndexPath;
@property (nonatomic, strong) NSString *pendingStickerPath;
@property (nonatomic, assign) BOOL promptingNewStickerEmoji;
@property (nonatomic, strong) UIBarButtonItem *createItem;
@property (nonatomic, strong) UIBarButtonItem *actionsItem;
@property (nonatomic, assign) BOOL pickingThumbnail;
@property (nonatomic, assign) NSInteger navReorderIndex;
@property (nonatomic, assign) NSInteger navThumbnailIndex;
@property (nonatomic, assign) NSInteger navDeleteIndex;

@end

@implementation TGStickerSetEditorViewController

- (BOOL)isCreated {
	return [self.set[@"name"] length] > 0;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];

	self.stickers = [NSMutableArray array];

	self.table = [[UITableView alloc] initWithFrame:self.view.bounds
											  style:UITableViewStyleGrouped];
	self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.table.dataSource = self;
	self.table.delegate = self;
	self.table.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	self.table.backgroundColor = [[TGTheme shared] listBackgroundColour];
	[self.view addSubview:self.table];

	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];

	if ([self isCreated]) {
		self.title = self.set[@"title"];
		NSArray *stickers = self.set[@"stickers"];
		if (stickers.count)
			[self.stickers addObjectsFromArray:stickers];
		[self buildActionsItem];
		[self refreshFromServer];
	} else {
		self.title = TGL(@"MediaEditor.CreateNewPack", @"New Sticker Set");
		[self buildCreateItem];
		[self updateCreateEnabled];
	}
}

- (void)buildCreateItem {
	UIBarButtonItem *item = [UIBarButtonItem alloc];
	self.createItem = [item initWithTitle:TGL(@"Common.Create", @"Create")
									style:UIBarButtonItemStyleDone
								   target:self
								   action:@selector(createTapped)];
	self.navigationItem.rightBarButtonItem = self.createItem;
}

- (void)buildActionsItem {
	UIBarButtonItem *item = [UIBarButtonItem alloc];
	self.actionsItem = [item initWithTitle:TGL(@"Common.More", @"More")
									 style:UIBarButtonItemStylePlain
									target:self
									action:@selector(actionsTapped)];
	self.navigationItem.rightBarButtonItem = self.actionsItem;
}

- (void)refreshFromServer {
	NSString *name = self.set[@"name"];
	if (!name.length)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] stickerSetWithName:name completion:^(NSDictionary *set) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || !set)
			return;
		strongSelf.set = set;
		strongSelf.title = set[@"title"];
		strongSelf.stickers = [(set[@"stickers"] ?: @[]) mutableCopy];
		[strongSelf.table reloadData];
	}];
}

#pragma mark - pack fields

- (UITableViewCell *)fieldCellForTable:(UITableView *)tableView
							identifier:(NSString *)identifier
								 label:(NSString *)label {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:identifier];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	}
	[[TGTheme shared] styleCell:cell];
	cell.textLabel.text = label;
	cell.textLabel.font = [UIFont systemFontOfSize:13];
	cell.textLabel.textColor = [[TGTheme shared] cellDetailColour];
	return cell;
}

- (UITableViewCell *)titleCellForTable:(UITableView *)tableView {
	UITableViewCell *cell = [self fieldCellForTable:tableView identifier:@"title"
											  label:TGL(@"Stickers.PackTitle", @"Title")];
	UILabel *value = [[UILabel alloc] initWithFrame:CGRectMake(90, 10, tableView.bounds.size.width - 105, 24)];
	value.font = [UIFont systemFontOfSize:16];
	value.textColor = [[TGTheme shared] cellDetailColour];
	value.textAlignment = NSTextAlignmentRight;
	value.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	value.text = self.set[@"title"] ?: @"";
	value.tag = 500;
	[cell.contentView.subviews enumerateObjectsUsingBlock:^(UIView *v, NSUInteger idx, BOOL *stop) {
		if (v.tag == 500)
			[v removeFromSuperview];
	}];
	[cell.contentView addSubview:value];
	return cell;
}

- (UITableViewCell *)nameCellForTable:(UITableView *)tableView {
	UITableViewCell *cell = [self fieldCellForTable:tableView identifier:@"name"
											  label:TGL(@"Channel.Edit.LinkItem", @"Link")];
	UILabel *value = [[UILabel alloc] initWithFrame:CGRectMake(90, 10, tableView.bounds.size.width - 105, 24)];
	value.font = [UIFont systemFontOfSize:16];
	value.textColor = [[TGTheme shared] cellDetailColour];
	value.textAlignment = NSTextAlignmentRight;
	value.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	value.text = [NSString stringWithFormat:@"t.me/addstickers/%@", self.set[@"name"] ?: @""];
	value.tag = 501;
	[cell.contentView.subviews enumerateObjectsUsingBlock:^(UIView *v, NSUInteger idx, BOOL *stop) {
		if (v.tag == 501)
			[v removeFromSuperview];
	}];
	[cell.contentView addSubview:value];
	return cell;
}

- (void)updateCreateEnabled {
	if (![self isCreated])
		self.createItem.enabled = !self.busy && self.stickers.count >= 1;
}

#pragma mark - creating

- (void)createTapped {
	if (self.busy || self.stickers.count == 0)
		return;
	[self promptChooseName];
}

- (void)promptChooseName {
	UIAlertView *alert = [[TGAlertView alloc]
			initWithTitle:TGL(@"ImportStickerPack.ChooseName", @"Choose Name")
				  message:TGL(@"ImportStickerPack.ChooseNameDescription", @"Please choose a name for your set.")
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Common.OK", @"OK"), nil];
	alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	[alert textFieldAtIndex:0].text = self.pendingTitle ?: @"";
	[alert textFieldAtIndex:0].placeholder = TGL(@"ImportStickerPack.NamePlaceholder", @"Name");
	alert.tag = kAlertChooseName;
	[alert show];
}

- (void)promptChooseLink {
	UIAlertView *alert = [[TGAlertView alloc]
			initWithTitle:TGL(@"ImportStickerPack.ChooseLink", @"Choose Link")
				  message:TGL(@"ImportStickerPack.ChooseLinkDescription", @"You can use a-z, 0-9 and underscores.")
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Common.OK", @"OK"), nil];
	alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	[alert textFieldAtIndex:0].text = self.pendingName ?: @"";
	alert.tag = kAlertChooseLink;
	[alert show];
}

- (void)finishCreatingWithTitle:(NSString *)title name:(NSString *)name {
	if (self.busy || self.stickers.count == 0)
		return;
	NSArray *pendingStickers = [self.stickers copy];
	for (NSDictionary *pending in pendingStickers) {
		if (![pending[@"path"] length])
			return;
	}

	self.busy = YES;
	self.createItem.enabled = NO;
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client createStickerSetForUser:self.userId
							  title:title
							   name:name
						   stickers:pendingStickers
						 completion:^(NSDictionary *set, NSString *errorText) {
							 __strong typeof(weakSelf) strongSelf = weakSelf;
							 if (!strongSelf)
								 return;
							 strongSelf.busy = NO;
							 if (!set) {
								 strongSelf.createItem.enabled = YES;
								 NSString *failed = TGL(@"Stickers.CouldNotCreate", @"Couldn't Create the Sticker Set");
								 [strongSelf showAlertWithTitle:failed message:TGFriendlyErrorText(errorText, nil)];
								 return;
							 }
							 for (NSDictionary *pending in pendingStickers)
								 [[NSFileManager defaultManager] removeItemAtPath:pending[@"path"] error:NULL];
							 strongSelf.pendingTitle = nil;
							 strongSelf.pendingName = nil;
							 strongSelf.set = set;
							 strongSelf.title = set[@"title"];
							 strongSelf.stickers = [(set[@"stickers"] ?: @[]) mutableCopy];
							 [strongSelf buildActionsItem];
							 [strongSelf.table reloadData];
						 }];
}

#pragma mark - actions sheet (nav bar)

- (NSInteger)reorderEligibleCount {
	NSInteger count = 0;
	for (NSDictionary *sticker in self.stickers)
		if (![sticker[@"pending"] boolValue])
			count++;
	return count;
}

- (void)actionsTapped {
	NSMutableArray *titles = [NSMutableArray array];

	self.navReorderIndex = [self reorderEligibleCount] > 1 ? (NSInteger)titles.count : -1;
	if (self.navReorderIndex >= 0)
		[titles addObject:TGL(@"StickerPack.Reorder", @"Reorder Stickers")];

	self.navThumbnailIndex = (NSInteger)titles.count;
	[titles addObject:TGL(@"Stickers.SetThumbnail", @"Set Pack Icon")];

	[titles addObject:TGL(@"PeerInfo.Gifts.RenameCollection", @"Rename")];

	self.navDeleteIndex = (NSInteger)titles.count;
	[titles addObject:TGL(@"StickerPack.Delete.Title", @"Delete Sticker Set")];

	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:nil
					  delegate:self
				   otherTitles:titles
			  destructiveIndex:self.navDeleteIndex
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = kSheetNavActions;
	[self showSheet:sheet];
}

- (void)beginReordering {
	self.table.editing = YES;
	UIBarButtonItem *done = [UIBarButtonItem alloc];
	done = [done initWithTitle:TGL(@"Common.Done", @"Done")
						 style:UIBarButtonItemStyleDone
						target:self
						action:@selector(finishReordering)];
	self.navigationItem.rightBarButtonItem = done;
}

- (void)finishReordering {
	self.table.editing = NO;
	[self buildActionsItem];
}

- (void)promptRename {
	UIAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:TGL(@"PeerInfo.Gifts.RenameCollection", @"Rename")
						 message:nil
						delegate:self
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			   otherButtonTitles:TGL(@"Common.OK", @"OK"), nil];
	alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	[alert textFieldAtIndex:0].text = self.set[@"title"];
	alert.tag = kAlertRename;
	[alert show];
}

- (void)promptDelete {
	UIAlertView *alert = [[UIAlertView alloc]
			initWithTitle:TGL(@"StickerPack.Delete.Title", @"Delete Sticker Set")
				  message:TGL(@"StickerPack.Delete.Text", @"This removes the set completely for everyone using it. This can't be undone.")
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Common.Delete", @"Delete"), nil];
	alert.tag = kAlertDeleteConfirm;
	[alert show];
}

#pragma mark - stickers

- (void)addStickerTapped {
	if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary])
		return;
	self.pickingThumbnail = NO;
	[self.view endEditing:YES];
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	picker.delegate = self;
	picker.allowsEditing = YES;
	[self presentViewController:picker animated:YES completion:nil];
}

- (void)pickThumbnailTapped {
	if (![self isCreated] || ![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary])
		return;
	self.pickingThumbnail = YES;
	[self.view endEditing:YES];
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	picker.delegate = self;
	picker.allowsEditing = YES;
	[self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
	UIImage *image = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
	[picker dismissViewControllerAnimated:YES completion:nil];
	if (!image) {
		self.pickingThumbnail = NO;
		return;
	}

	BOOL forThumbnail = self.pickingThumbnail;
	self.pickingThumbnail = NO;
	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSError *error = nil;
		NSString *path = [TGStickerImagePreparer stickerFilePathFromImage:image error:&error];
		dispatch_async(dispatch_get_main_queue(), ^{
			__strong typeof(weakSelf) strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!path) {
				[strongSelf showAlertWithTitle:TGL(@"Stickers.CouldNotPrepareImage", @"Couldn't Use That Photo")
									   message:error.localizedDescription];
				return;
			}
			if (forThumbnail) {
				[strongSelf applyThumbnailAtPath:path];
				return;
			}
			[strongSelf promptEmojiForNewStickerAtPath:path];
		});
	});
}

- (void)applyThumbnailAtPath:(NSString *)path {
	NSString *name = self.set[@"name"];
	if (!name.length) {
		[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
		return;
	}
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client setThumbnailForStickerSetNamed:name
									userId:self.userId
									atPath:path
								completion:^(BOOL ok, NSString *errorText) {
									[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
									__strong typeof(weakSelf) strongSelf = weakSelf;
									if (!strongSelf || ok)
										return;
									NSString *failed = TGL(@"Stickers.CouldNotSetThumbnail", @"Couldn't Set the Icon");
									[strongSelf showAlertWithTitle:failed message:TGFriendlyErrorText(errorText, nil)];
								}];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	[picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)promptEmojiForNewStickerAtPath:(NSString *)path {
	self.pendingStickerPath = path;
	self.promptingNewStickerEmoji = YES;
	UIAlertView *alert = [[TGAlertView alloc]
			initWithTitle:TGL(@"Stickers.PickEmojiTitle", @"What Emoji Fits This Sticker?")
				  message:TGL(@"Stickers.PickEmojiMessage", @"Type one emoji. It's how this sticker gets suggested while typing.")
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Common.OK", @"OK"), nil];
	alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	[alert textFieldAtIndex:0].text = @"🙂";
	alert.tag = kAlertEmoji;
	[alert show];
}

- (void)addPendingSticker:(NSString *)path emoji:(NSString *)emoji {
	NSDictionary *entry = @{@"pending" : @YES, @"path" : path, @"emoji" : emoji.length ? emoji : @"🙂"};
	if (![self isCreated]) {
		[self.stickers addObject:entry];
		[self.table reloadData];
		[self updateCreateEnabled];
		return;
	}

	self.busy = YES;
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client addStickerForUser:self.userId
				   toSetNamed:self.set[@"name"]
			  stickerFilePath:path
						emoji:emoji
				   completion:^(NSString *errorText) {
					   __strong typeof(weakSelf) strongSelf = weakSelf;
					   if (!strongSelf)
						   return;
					   strongSelf.busy = NO;
					   [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
					   if (errorText) {
						   NSString *failed = TGL(@"Stickers.CouldNotAddSticker", @"Couldn't Add That Sticker");
						   [strongSelf showAlertWithTitle:failed message:TGFriendlyErrorText(errorText, nil)];
						   return;
					   }
					   [strongSelf refreshFromServer];
				   }];
}

- (void)stickerRowTappedAtIndexPath:(NSIndexPath *)indexPath {
	if ((NSUInteger)indexPath.row >= self.stickers.count)
		return;
	self.actionIndexPath = indexPath;
	NSDictionary *sticker = self.stickers[indexPath.row];
	BOOL pending = [sticker[@"pending"] boolValue];

	NSArray *titles = pending
		? @[ TGL(@"Stickers.ChangeEmoji", @"Change Emoji"), TGL(@"PeerInfo.Gifts.RemoveCollectionAction", @"Remove") ]
		: @[ TGL(@"Stickers.ChangeEmoji", @"Change Emoji"), TGL(@"Stickers.SetKeywords", @"Set Keywords"),
			  TGL(@"PeerInfo.Gifts.RemoveCollectionAction", @"Remove") ];
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:nil
					  delegate:self
				   otherTitles:titles
			  destructiveIndex:(NSInteger)titles.count - 1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = kSheetStickerActions;
	[self showSheet:sheet];
}

- (void)promptEmojiForExistingStickerAtIndexPath:(NSIndexPath *)indexPath {
	if ((NSUInteger)indexPath.row >= self.stickers.count)
		return;
	NSDictionary *sticker = self.stickers[indexPath.row];
	self.promptingNewStickerEmoji = NO;
	UIAlertView *alert = [[TGAlertView alloc]
			initWithTitle:TGL(@"Stickers.ChangeEmoji", @"Change Emoji")
				  message:nil
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Common.OK", @"OK"), nil];
	alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	[alert textFieldAtIndex:0].text = sticker[@"emoji"];
	alert.tag = kAlertEmoji;
	[alert show];
}

- (void)promptKeywordsAtIndexPath:(NSIndexPath *)indexPath {
	UIAlertView *alert = [[TGAlertView alloc]
			initWithTitle:TGL(@"Stickers.SetKeywords", @"Set Keywords")
				  message:TGL(@"Stickers.SetKeywordsMessage", @"Separate words with commas.")
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Common.OK", @"OK"), nil];
	alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	alert.tag = kAlertKeywords;
	[alert show];
}

- (void)removeStickerAtIndexPath:(NSIndexPath *)indexPath {
	if ((NSUInteger)indexPath.row >= self.stickers.count)
		return;
	NSDictionary *sticker = self.stickers[indexPath.row];
	if ([sticker[@"pending"] boolValue]) {
		[[NSFileManager defaultManager] removeItemAtPath:sticker[@"path"] error:NULL];
		[self.stickers removeObjectAtIndex:indexPath.row];
		[self.table reloadData];
		[self updateCreateEnabled];
		return;
	}

	if (self.busy)
		return;
	self.busy = YES;
	long long fileId = [sticker[@"fileId"] longLongValue];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] removeStickerWithFileId:fileId completion:^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.busy = NO;
		if (!ok) {
			[strongSelf showAlertWithTitle:TGL(@"Stickers.CouldNotRemoveSticker", @"Couldn't Remove the Sticker") message:nil];
			return;
		}
		if ((NSUInteger)indexPath.row < strongSelf.stickers.count)
			[strongSelf.stickers removeObjectAtIndex:indexPath.row];
		[strongSelf.table reloadData];
	}];
}

#pragma mark - alert / sheet delegates

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex == alertView.cancelButtonIndex) {
		if (alertView.tag == kAlertEmoji) {
			if (self.pendingStickerPath.length)
				[[NSFileManager defaultManager] removeItemAtPath:self.pendingStickerPath error:NULL];
			self.pendingStickerPath = nil;
			self.promptingNewStickerEmoji = NO;
		}
		return;
	}

	if (alertView.tag == kAlertEmoji) {
		NSString *emoji = [[alertView textFieldAtIndex:0].text
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if (self.promptingNewStickerEmoji) {
			self.promptingNewStickerEmoji = NO;
			if (self.pendingStickerPath.length)
				[self addPendingSticker:self.pendingStickerPath emoji:emoji];
			self.pendingStickerPath = nil;
			return;
		}
		if (!self.actionIndexPath || (NSUInteger)self.actionIndexPath.row >= self.stickers.count)
			return;
		NSDictionary *sticker = self.stickers[self.actionIndexPath.row];
		if ([sticker[@"pending"] boolValue]) {
			NSMutableDictionary *updated = [sticker mutableCopy];
			updated[@"emoji"] = emoji.length ? emoji : @"🙂";
			[self.stickers replaceObjectAtIndex:self.actionIndexPath.row withObject:updated];
			[self.table reloadData];
			return;
		}
		long long fileId = [sticker[@"fileId"] longLongValue];
		NSIndexPath *indexPath = self.actionIndexPath;
		__weak typeof(self) weakEmojiSelf = self;
		[[TGClient shared] setEmoji:emoji forStickerWithFileId:fileId completion:^(BOOL ok) {
			__strong typeof(weakEmojiSelf) strongSelf = weakEmojiSelf;
			if (!strongSelf)
				return;
			if (!ok) {
				[strongSelf showAlertWithTitle:TGL(@"Stickers.CouldNotChangeEmoji", @"Couldn't Change the Emoji") message:nil];
				return;
			}
			if ((NSUInteger)indexPath.row >= strongSelf.stickers.count)
				return;
			NSMutableDictionary *updated = [strongSelf.stickers[indexPath.row] mutableCopy];
			updated[@"emoji"] = emoji;
			[strongSelf.stickers replaceObjectAtIndex:indexPath.row withObject:updated];
			[strongSelf.table reloadData];
		}];
		return;
	}

	if (alertView.tag == kAlertChooseName) {
		NSString *title = [[alertView textFieldAtIndex:0].text
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if (!title.length)
			return;
		self.pendingTitle = title;
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] suggestedStickerSetNameForTitle:title completion:^(NSString *name) {
			__strong typeof(weakSelf) strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (name.length)
				strongSelf.pendingName = name;
			[strongSelf promptChooseLink];
		}];
		return;
	}

	if (alertView.tag == kAlertChooseLink) {
		NSString *name = [[alertView textFieldAtIndex:0].text
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if (!name.length)
			return;
		self.pendingName = name;
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] checkStickerSetNameAvailability:name completion:^(NSString *status) {
			__strong typeof(weakSelf) strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if ([status isEqualToString:@"ok"]) {
				[strongSelf finishCreatingWithTitle:strongSelf.pendingTitle name:name];
				return;
			}
			NSString *reason = [status isEqualToString:@"occupied"]
				? TGL(@"ImportStickerPack.LinkTaken", @"That link is already taken.")
				: TGL(@"ImportStickerPack.ChooseLinkDescription", @"You can use a-z, 0-9 and underscores.");
			[strongSelf showAlertWithTitle:reason message:nil];
			[strongSelf promptChooseLink];
		}];
		return;
	}

	if (alertView.tag == kAlertKeywords) {
		if (!self.actionIndexPath || (NSUInteger)self.actionIndexPath.row >= self.stickers.count)
			return;
		NSDictionary *sticker = self.stickers[self.actionIndexPath.row];
		long long fileId = [sticker[@"fileId"] longLongValue];
		NSArray *rawParts = [[alertView textFieldAtIndex:0].text componentsSeparatedByString:@","];
		NSMutableArray *keywords = [NSMutableArray array];
		for (NSString *part in rawParts) {
			NSString *trimmed = [part stringByTrimmingCharactersInSet:
					[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			if (trimmed.length)
				[keywords addObject:trimmed];
		}
		[[TGClient shared] setKeywords:keywords forStickerWithFileId:fileId completion:nil];
		return;
	}

	if (alertView.tag == kAlertRename) {
		NSString *title = [[alertView textFieldAtIndex:0].text
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if (!title.length)
			return;
		NSString *name = self.set[@"name"];
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] renameStickerSetNamed:name title:title completion:^(BOOL ok) {
			__strong typeof(weakSelf) strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!ok) {
				[strongSelf showAlertWithTitle:TGL(@"Stickers.CouldNotRenameSet", @"Couldn't Rename the Sticker Set") message:nil];
				return;
			}
			NSMutableDictionary *updated = [strongSelf.set mutableCopy];
			updated[@"title"] = title;
			strongSelf.set = updated;
			strongSelf.title = title;
			[strongSelf.table reloadData];
		}];
		return;
	}

	if (alertView.tag == kAlertDeleteConfirm) {
		if (self.busy)
			return;
		self.busy = YES;
		NSString *name = self.set[@"name"];
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] deleteStickerSetNamed:name completion:^(BOOL ok) {
			__strong typeof(weakSelf) strongSelf = weakSelf;
			if (!strongSelf)
				return;
			strongSelf.busy = NO;
			if (!ok) {
				[strongSelf showAlertWithTitle:TGL(@"Stickers.CouldNotDeleteSet", @"Couldn't Delete the Sticker Set") message:nil];
				return;
			}
			[strongSelf.navigationController popViewControllerAnimated:YES];
		}];
	}
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex == actionSheet.cancelButtonIndex)
		return;

	if (actionSheet.tag == kSheetNavActions) {
		if (buttonIndex == self.navReorderIndex)
			[self beginReordering];
		else if (buttonIndex == self.navThumbnailIndex)
			[self pickThumbnailTapped];
		else if (buttonIndex == self.navDeleteIndex)
			[self promptDelete];
		else
			[self promptRename];
		return;
	}

	if (actionSheet.tag == kSheetStickerActions) {
		NSIndexPath *indexPath = self.actionIndexPath;
		if (!indexPath)
			return;
		if (buttonIndex == actionSheet.destructiveButtonIndex) {
			[self removeStickerAtIndexPath:indexPath];
			return;
		}
		NSString *title = [actionSheet buttonTitleAtIndex:buttonIndex];
		if ([title isEqualToString:TGL(@"Stickers.ChangeEmoji", @"Change Emoji")])
			[self promptEmojiForExistingStickerAtIndexPath:indexPath];
		else if ([title isEqualToString:TGL(@"Stickers.SetKeywords", @"Set Keywords")])
			[self promptKeywordsAtIndexPath:indexPath];
	}
}

- (void)showSheet:(UIActionSheet *)sheet {
	if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
		[sheet showInView:self.view];
		return;
	}
	[sheet showFromBarButtonItem:self.navigationItem.rightBarButtonItem animated:YES];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil
										  cancelButtonTitle:TGL(@"Common.OK", @"OK")
										  otherButtonTitles:nil];
	[alert show];
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return [self isCreated] ? 2 : 0;
	return (NSInteger)self.stickers.count + 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return indexPath.section == 0 ? kFieldRowHeight : kStickerRowHeight;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
		   editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
	return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
	return NO;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section != 1 || (NSUInteger)indexPath.row >= self.stickers.count)
		return NO;
	return ![self.stickers[indexPath.row][@"pending"] boolValue];
}

- (NSIndexPath *)tableView:(UITableView *)tableView
	targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath
						 toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath {
	if (proposedDestinationIndexPath.section != 1)
		return sourceIndexPath;
	if ((NSUInteger)proposedDestinationIndexPath.row >= self.stickers.count)
		return [NSIndexPath indexPathForRow:(NSInteger)self.stickers.count - 1 inSection:1];
	return proposedDestinationIndexPath;
}

- (void)tableView:(UITableView *)tableView
	moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath
		   toIndexPath:(NSIndexPath *)destinationIndexPath {
	if ((NSUInteger)sourceIndexPath.row >= self.stickers.count)
		return;
	NSDictionary *moved = self.stickers[sourceIndexPath.row];
	[self.stickers removeObjectAtIndex:sourceIndexPath.row];
	NSInteger target = destinationIndexPath.row;
	if (target > (NSInteger)self.stickers.count)
		target = (NSInteger)self.stickers.count;
	[self.stickers insertObject:moved atIndex:target];

	long long fileId = [moved[@"fileId"] longLongValue];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setPosition:target forStickerWithFileId:fileId completion:^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || ok)
			return;
		[strongSelf showAlertWithTitle:TGL(@"Stickers.CouldNotReorder", @"Couldn't Reorder the Stickers") message:nil];
		[strongSelf refreshFromServer];
	}];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section == 0)
		return nil;
	if (self.stickers.count == 0)
		return TGL(@"Stickers.NoStickersYet", @"Add a photo below. It's cropped to a square and resized to fit a sticker.");
	return TGL(@"Stickers.StickersFooter", @"Tap a sticker to change its emoji, set keywords, or remove it.");
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *text = [self tableView:tableView titleForFooterInSection:section];
	CGFloat measured = [[TGTheme shared] groupedCommentHeightForText:text width:tableView.bounds.size.width];
	return TGGroupedFooterHeight(text, measured);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *text = [self tableView:tableView titleForFooterInSection:section];
	TGTheme *theme = [TGTheme shared];
	return [theme groupedCommentViewWithText:text width:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 0)
		return indexPath.row == 0 ? [self titleCellForTable:tableView] : [self nameCellForTable:tableView];

	if ((NSUInteger)indexPath.row >= self.stickers.count) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"add"];
		if (!cell)
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"add"];
		[[TGTheme shared] styleCell:cell];
		cell.textLabel.text = TGL(@"StickerPack.AddSticker", @"Add a Sticker");
		cell.textLabel.textColor = [[TGTheme shared] groupedActionColour];
		cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
		cell.accessoryType = UITableViewCellAccessoryNone;
		return cell;
	}

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"sticker"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"sticker"];
	[[TGTheme shared] styleCell:cell];
	cell.accessoryType = UITableViewCellAccessoryNone;

	NSDictionary *sticker = self.stickers[indexPath.row];
	BOOL pending = [sticker[@"pending"] boolValue];
	cell.textLabel.text = sticker[@"emoji"];
	cell.textLabel.font = [UIFont systemFontOfSize:24];
	cell.detailTextLabel.text = pending
		? TGL(@"Stickers.NotUploadedYet", @"Not added yet")
		: @"";
	cell.imageView.contentMode = UIViewContentModeScaleAspectFit;

	if (pending) {
		cell.imageView.image = [UIImage imageWithContentsOfFile:sticker[@"path"]];
	} else {
		cell.imageView.image = nil;
		NSString *uniqueId = sticker[@"uniqueId"];
		UIImage *cached = uniqueId.length
			? [TGStickerThumbnailCache cachedThumbnailForUniqueId:uniqueId side:kThumbSide]
			: nil;
		if (cached) {
			cell.imageView.image = cached;
		} else if (uniqueId.length) {
			long long fileId = [sticker[@"thumbId"] longLongValue] ?: [sticker[@"fileId"] longLongValue];
			[TGStickerThumbnailCache thumbnailForFileId:fileId uniqueId:uniqueId side:kThumbSide
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
	if (tableView.editing || indexPath.section != 1)
		return;
	if ((NSUInteger)indexPath.row >= self.stickers.count) {
		[self addStickerTapped];
		return;
	}
	[self stickerRowTappedAtIndexPath:indexPath];
}

@end

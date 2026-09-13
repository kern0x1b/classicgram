#import "TGWallpaperListText.h"
#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGChatBackgroundViewController.h"
#import "TGActionSheet.h"
#import "TGLocalization.h"
#import "TGClient.h"
#import "TGClient+AppSettings.h"
#import "TGClient+Premium.h"
#import "TGTheme.h"
#import "TGHexColour.h"

static void TGCBComplain(NSString *message) {
	UIAlertView *alert = [UIAlertView alloc];
	alert = [alert initWithTitle:nil message:message
						delegate:nil
			   cancelButtonTitle:TGL(@"Common.OK", @"OK")
			   otherButtonTitles:nil];
	[alert show];
}

static NSString *TGCBTitleForRow(NSDictionary *row, NSInteger index) {
	NSString *kind = row[@"kind"];
	if ([kind isEqualToString:@"fill"]) {
		NSNumber *top = row[@"topColor"];
		NSNumber *bottom = row[@"bottomColor"];
		BOOL gradient = [top isKindOfClass:NSNumber.class] && [bottom isKindOfClass:NSNumber.class] && [top unsignedIntValue] != [bottom unsignedIntValue];
		return gradient ? TGL(@"Wallpaper.Gradient", @"Gradient") : TGL(@"Wallpaper.SolidColour", @"Solid Colour");
	}
	if ([kind isEqualToString:@"pattern"])
		return [NSString stringWithFormat:TGL(@"Wallpaper.PatternNumbered", @"Pattern %ld"), (long)(index + 1)];
	NSString *name = row[@"name"];
	if ([name isKindOfClass:NSString.class] && name.length)
		return name;
	return [NSString stringWithFormat:TGL(@"Wallpaper.PhotographNumbered", @"Photograph %ld"), (long)(index + 1)];
}

@interface TGChatBackgroundViewController () <UIActionSheetDelegate,
	UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, strong) NSArray *backgrounds;
@property (nonatomic, assign) BOOL backgroundsLoaded;
@property (nonatomic, assign) BOOL backgroundsFailed;
@property (nonatomic, strong) NSString *currentBackgroundId;
@property (nonatomic, assign) BOOL currentLoaded;
@property (nonatomic, assign) BOOL blurred;
@property (nonatomic, strong) NSDictionary *pendingRow;
@property (nonatomic, strong) NSString *pendingCustomPhotoPath;
@end

@implementation TGChatBackgroundViewController

- (instancetype)initWithChatId:(int64_t)chatId title:(NSString *)title {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		_chatId = chatId;
		self.title = TGL(@"Wallpaper.Title", @"Chat Wallpaper");
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.backgrounds = @[];
	[self reload];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)reload {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] installedBackgroundsForDarkTheme:NO completion:^(NSArray *backgrounds, BOOL failed) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (failed) {
			strongSelf.backgroundsFailed = YES;
			strongSelf.backgroundsLoaded = YES;
			[strongSelf.tableView reloadData];
			return;
		}
		strongSelf.backgroundsFailed = NO;
		strongSelf.backgrounds = [backgrounds isKindOfClass:NSArray.class] ? backgrounds : @[];
		strongSelf.backgroundsLoaded = YES;
		[strongSelf.tableView reloadData];
	}];
	[[TGClient shared] chatBackgroundRowForChat:self.chatId
									 completion:^(NSDictionary *row, NSInteger dimming) {
										 __strong typeof(weakSelf) strongSelf = weakSelf;
										 if (!strongSelf)
											 return;
										 strongSelf.currentBackgroundId = [row[@"id"] isKindOfClass:NSString.class] ? row[@"id"] : nil;
										 strongSelf.currentLoaded = YES;
										 strongSelf.blurred = [row[@"isBlurred"] boolValue];
										 [strongSelf.tableView reloadData];
									 }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return 3;
	if (self.backgroundsLoaded)
		return (NSInteger)self.backgrounds.count;
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section != 0)
		return nil;
	return TGL(@"Chat.WallpaperChatOnlyFooter",
		@"This changes the wallpaper in this one chat only, on every device where you use "
		@"Telegram. It does not change the appearance of this app.");
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

- (void)mark:(BOOL)checked on:(UITableViewCell *)cell {
	cell.accessoryType = checked ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"row"];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleDefault;
	cell.imageView.image = nil;
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.accessoryView = nil;

	if (indexPath.section == 0) {
		if (indexPath.row == 0) {
			cell.textLabel.text = TGL(@"Wallpaper.SetCustomBackground", @"Choose from library");
			cell.textLabel.textColor = [[TGTheme shared] accentColour];
			return cell;
		}
		if (indexPath.row == 1) {
			cell.textLabel.text = TGL(@"Business.Intro.ResetToDefault", @"Reset to Default");
			cell.textLabel.textColor = [[TGTheme shared] accentColour];
			return cell;
		}
		cell.textLabel.text = TGL(@"Story.Editor.Blur.Title", @"Blur");
		cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
		UISwitch *toggle = [[UISwitch alloc] init];
		toggle.on = self.blurred;
		[toggle addTarget:self action:@selector(blurredToggled:)
			forControlEvents:UIControlEventValueChanged];
		cell.accessoryView = toggle;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		return cell;
	}

	if (!self.backgrounds.count) {
		cell.textLabel.text = TGWallpaperListText(self.backgroundsLoaded, self.backgroundsFailed);
		cell.textLabel.textColor = [[TGTheme shared] secondaryTextColour];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		return cell;
	}

	NSDictionary *row = self.backgrounds[indexPath.row];
	cell.textLabel.text = TGCBTitleForRow(row, indexPath.row);
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];

	NSNumber *top = row[@"topColor"];
	if ([top isKindOfClass:NSNumber.class]) {
		CGRect rect = CGRectMake(0, 0, 28, 28);
		UIGraphicsBeginImageContextWithOptions(rect.size, YES, 0.0f);
		[TGColourFromHex((unsigned int)[top unsignedIntValue]) setFill];
		UIRectFill(rect);
		cell.imageView.image = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
	}

	BOOL checked = self.currentLoaded && self.currentBackgroundId.length && [self.currentBackgroundId isEqualToString:row[@"id"]];
	[self mark:checked on:cell];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (indexPath.section == 0 && indexPath.row == 0) {
		[self presentCustomPhotoPicker];
		return;
	}

	if (indexPath.section == 0 && indexPath.row == 1) {
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] resetChatBackgroundForChat:self.chatId completion:^(BOOL ok) {
			__strong typeof(weakSelf) strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!ok) {
				TGCBComplain(TGL(@"Chat.WallpaperCouldNotBeReset", @"That wallpaper could not be reset."));
				return;
			}
			strongSelf.currentBackgroundId = nil;
			[strongSelf.tableView reloadData];
		}];
		return;
	}

	if (indexPath.section == 0)
		return;

	if ((NSUInteger)indexPath.row >= self.backgrounds.count)
		return;

	self.pendingRow = self.backgrounds[indexPath.row];

	if (![[TGClient shared] isPremiumAccount]) {
		[self applyPendingRowOnlyForSelf:YES];
		return;
	}

	UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self
											  cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
										 destructiveButtonTitle:nil
											  otherButtonTitles:TGL(@"Wallpaper.ApplyForMe", @"Set Only for Me"),
		TGL(@"Wallpaper.ApplyForBoth", @"Set for Both of Us"), nil];
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	[sheet tg_showFromRect:cell.frame inView:tableView];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
	if (index == sheet.cancelButtonIndex) {
		self.pendingRow = nil;
		if (self.pendingCustomPhotoPath) {
			[[NSFileManager defaultManager] removeItemAtPath:self.pendingCustomPhotoPath error:NULL];
			self.pendingCustomPhotoPath = nil;
		}
		return;
	}
	[self applyPendingRowOnlyForSelf:(index == 0)];
}

- (void)blurredToggled:(UISwitch *)toggle {
	self.blurred = toggle.on;
}

- (void)applyPendingRowOnlyForSelf:(BOOL)onlyForSelf {
	NSString *customPath = self.pendingCustomPhotoPath;
	self.pendingCustomPhotoPath = nil;
	if (customPath) {
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] setChatBackgroundAtPath:customPath blurred:self.blurred forChat:self.chatId
									   onlyForSelf:onlyForSelf
										completion:^(BOOL ok, BOOL premiumRequired) {
											[[NSFileManager defaultManager] removeItemAtPath:customPath error:NULL];
											__strong typeof(weakSelf) strongSelf = weakSelf;
											if (!strongSelf)
												return;
											if (!ok) {
												NSString *complaint = premiumRequired
													? TGL(@"Chat.WallpaperBothSidesNeedsPremium", @"Telegram Premium is needed to set a wallpaper for both sides of the chat.")
													: TGL(@"Chat.WallpaperCouldNotBeSet", @"That wallpaper could not be set.");
												TGCBComplain(complaint);
												return;
											}
											strongSelf.currentBackgroundId = nil;
											[strongSelf reload];
										}];
		return;
	}

	NSDictionary *row = self.pendingRow;
	self.pendingRow = nil;
	if (!row)
		return;

	NSString *rowId = row[@"id"];
	__weak typeof(self) weakSelf = self;
	TGClient *client = [TGClient shared];
	[client setChatBackgroundRow:row blurred:self.blurred forChat:self.chatId
					 onlyForSelf:onlyForSelf
					  completion:^(BOOL ok, BOOL premiumRequired) {
						  __strong typeof(weakSelf) strongSelf = weakSelf;
						  if (!strongSelf)
							  return;
						  if (!ok) {
							  NSString *premium = TGL(@"Chat.WallpaperBothSidesNeedsPremium", @"Telegram Premium is needed to set a wallpaper for both sides of the chat.");
							  TGCBComplain(premiumRequired ? premium : TGL(@"Chat.WallpaperCouldNotBeSet", @"That wallpaper could not be set."));
							  return;
						  }
						  strongSelf.currentBackgroundId = rowId;
						  [strongSelf.tableView reloadData];
					  }];
}

- (void)presentCustomPhotoPicker {
	if (![UIImagePickerController isSourceTypeAvailable:
				UIImagePickerControllerSourceTypePhotoLibrary]) {
		TGCBComplain(TGL(@"Chat.ThereIsNoPhotoLibraryOn", @"There is no photo library on this device."));
		return;
	}
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	picker.delegate = self;
	[self presentViewController:picker animated:YES completion:nil];
}

- (UIImage *)wallpaperSizedImage:(UIImage *)image {
	CGSize size = image.size;
	if (size.width < 1 || size.height < 1)
		return image;
	CGFloat limit = 960.0f;
	CGFloat scale = MIN(1.0f, MIN(limit / size.width, limit / size.height));
	if (scale >= 1.0f)
		return image;

	CGSize target = CGSizeMake(floorf(size.width * scale), floorf(size.height * scale));
	UIGraphicsBeginImageContextWithOptions(target, YES, 1.0f);
	[image drawInRect:CGRectMake(0, 0, target.width, target.height)];
	UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return scaled ?: image;
}

- (void)imagePickerController:(UIImagePickerController *)picker
	didFinishPickingMediaWithInfo:(NSDictionary *)info {
	[picker dismissViewControllerAnimated:YES completion:nil];
	UIImage *image = info[UIImagePickerControllerOriginalImage];
	if (!image)
		return;

	UIImage *sized = [self wallpaperSizedImage:image];
	NSData *jpeg = UIImageJPEGRepresentation(sized, 0.8f);
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
			[NSString stringWithFormat:@"chat-wallpaper-%.0f.jpg",
				[[NSDate date] timeIntervalSince1970] * 1000]];
	if (!jpeg || ![jpeg writeToFile:path atomically:YES]) {
		TGCBComplain(TGL(@"Settings.ThePictureIsInPlaceOn", @"The picture is in place on this device, but Telegram would not store it on the account."));
		return;
	}

	self.pendingCustomPhotoPath = path;
	if (![[TGClient shared] isPremiumAccount]) {
		[self applyPendingRowOnlyForSelf:YES];
		return;
	}

	UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self
											  cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
										 destructiveButtonTitle:nil
											  otherButtonTitles:TGL(@"Wallpaper.ApplyForMe", @"Set Only for Me"),
		TGL(@"Wallpaper.ApplyForBoth", @"Set for Both of Us"), nil];
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.navigationController.view.bounds), CGRectGetMidY(self.navigationController.view.bounds), 1, 1) inView:self.navigationController.view];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	[picker dismissViewControllerAnimated:YES completion:nil];
}

@end

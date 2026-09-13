#import "TGActionSheet.h"
#import "TGImageDecode.h"
#import "TGFileDownloadService.h"
#import "TGAccountUsernamesViewController.h"
#import "TGAccountSettingsViewController.h"
#import "TGLocalization.h"
#import "TGNotificationManager.h"
#import "TGSettingsViewController.h"
#import "TGEmoji.h"
#import "RootViewController.h"
#import "TGTheme.h"
#import "TGSessionsViewController.h"
#import "TGDeviceViewController.h"
#import "TGWebBrowserSettingsViewController.h"
#import "TGDevice.h"
#import "TGFoldersViewController.h"
#import "TGProxyViewController.h"
#import "TGPrivacyViewController.h"
#import "TGPrivacyViewController.h"
#import "TGPrivacyViewControllerInternal.h"
#import "TGTabBar.h"
#import "TGSettingsService.h"
#import "TGCapabilities.h"
#import "TGAccountManager.h"
#import "TGPhoneFormat.h"
#import "TGIcons.h"
#import "TGByteFormat.h"
#import <QuartzCore/QuartzCore.h>
#import "TGSettingsViewControllerInternal.h"
#import "TGActionSheetIndexBuilder.h"
#import "TGWallpaperGradientViewController.h"

@implementation TGSettingsViewController (Wallpaper)

#pragma mark - wallpaper

+ (NSArray *)wallpaperColourNames {
	return @[ TGL(@"Wallpaper.ColourSlate", @"Slate"),
		TGL(@"Wallpaper.ColourSky", @"Sky"),
		TGL(@"Wallpaper.ColourSand", @"Sand"),
		TGL(@"Wallpaper.ColourMoss", @"Moss"),
		TGL(@"Wallpaper.ColourCharcoal", @"Charcoal") ];
}

+ (NSArray *)wallpaperColourValues {
	static NSArray *values = nil;
	if (!values)
		values = @[ @0x33424f, @0x6ba8d6, @0xd8c8a8, @0x6f8f6a, @0x2b2b2b ];
	return values;
}

+ (NSArray *)wallpaperGradientNames {
	return @[ TGL(@"Wallpaper.GradientDusk", @"Dusk"),
		TGL(@"Wallpaper.GradientSea", @"Sea"),
		TGL(@"Wallpaper.GradientPaper", @"Paper") ];
}

+ (NSArray *)wallpaperGradientValues {
	static NSArray *values = nil;
	if (!values)
		values = @[ @[ @0x3b4c68, @0x8a5f7a ],
			@[ @0x2f6f8f, @0x7fc3c8 ],
			@[ @0xf0e6d2, @0xcfbfa0 ] ];
	return values;
}

- (void)tapWallpaper:(NSIndexPath *)indexPath {
	if (indexPath.section == 3) {
		[self confirmClearBackgroundList];
		return;
	}

	if (indexPath.section == 0) {
		[self tapWallpaperChooserRow:indexPath.row];
		return;
	}

	if (indexPath.section == 1) {
		[self applyBuiltinWallpaperAtRow:indexPath.row];
		return;
	}

	if ((NSUInteger)indexPath.row >= self.backgrounds.count)
		return;
	NSDictionary *background = self.backgrounds[indexPath.row];
	if (![background isKindOfClass:[NSDictionary class]])
		return;
	[self applyBackground:background];
}

- (void)confirmClearBackgroundList {
	UIAlertView *confirm = [[UIAlertView alloc]
			initWithTitle:TGL(@"Wallpaper.ResetWallpapers", @"Reset Chat Backgrounds")
				  message:TGL(@"Wallpaper.ResetWallpapersInfo", @"Remove all uploaded chat backgrounds and restore pre-installed backgrounds for all themes.")
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Wallpaper.ResetWallpapersConfirmation", @"Reset Chat Backgrounds"), nil];
	confirm.tag = 406;
	[confirm show];
}

- (void)applyBuiltinWallpaperAtRow:(NSInteger)row {
	if ((NSUInteger)row >= [TGSettingsViewController builtinWallpaperNames].count)
		return;
	if (![TGCapabilities canShowWallpaper]) {
		UIAlertView *alert = [UIAlertView alloc];
		alert = [alert initWithTitle:TGL(@"Settings.ChatBackground", @"Chat Background")
							 message:TGL(@"Settings.ThisDeviceHasTooLittleMemory", @"This device has too little memory to hold a photographic wallpaper. Colours and gradients still work.")
							delegate:nil
				   cancelButtonTitle:TGL(@"Common.OK", @"OK")
				   otherButtonTitles:nil];
		[alert show];
		return;
	}

	NSString *file = [TGSettingsViewController builtinWallpaperFileAtIndex:row];
	if (![[TGTheme shared] applyBuiltinWallpaperNamed:file]) {
		self.wallpaperOriginal = nil;
		self.wallpaperBackgroundId = nil;
		UIAlertView *alert = [UIAlertView alloc];
		alert = [alert initWithTitle:TGL(@"Settings.ChatBackground", @"Chat Background")
							 message:TGL(@"Settings.ThatBackgroundIsMissingFromThis", @"That background is missing from this build.")
							delegate:nil
				   cancelButtonTitle:TGL(@"Common.OK", @"OK")
				   otherButtonTitles:nil];
		[alert show];
		return;
	}

	self.wallpaperBackgroundId = nil;
	[TGTheme shared].defaultBackgroundId = nil;
	self.wallpaperOriginal = [TGTheme shared].wallpaper;
	if (self.wallpaperBlurred)
		[self installWallpaperFromOriginal];
	[self.tableView reloadData];
	[self syncBuiltinWallpaperNamed:file];
}

- (void)syncBuiltinWallpaperNamed:(NSString *)name {
	NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"jpg"];
	if (!path.length)
		return;
	[TGSettingsService setDefaultBackgroundAtPath:path
										  blurred:self.wallpaperBlurred
									 forDarkTheme:NO
									   completion:^(NSDictionary *background) {
										   if (![background isKindOfClass:[NSDictionary class]])
											   TGPrivacyComplain(TGL(@"Chat.WallpaperCouldNotBeSet", @"That wallpaper could not be set."));
									   }];
}

- (void)tapWallpaperChooserRow:(NSInteger)row {
	if (row == 0) {
		[self presentWallpaperPicker];
		return;
	}
	if (row == 1) {
		[self showWallpaperColourSheet];
		return;
	}
	if (row == 2) {
		[self pushWallpaperGradientScreen];
		return;
	}
	if (row == 3)
		return;
	[self removeChatWallpaperPressed];
}

- (void)removeChatWallpaperPressed {
	self.wallpaperOriginal = nil;
	self.wallpaperBackgroundId = nil;
	[TGTheme shared].defaultBackgroundId = nil;
	[[TGTheme shared] setWallpaperImage:nil];
	[TGSettingsService resetDefaultBackgroundForDarkTheme:NO completion:^(BOOL success) {
		if (!success)
			TGPrivacyComplain(TGL(@"Privacy.TheSettingCouldNotBeChanged", @"That setting could not be changed."));
	}];
	[self.tableView reloadData];
}

- (void)showWallpaperColourSheet {
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:TGL(@"Wallpaper.SetColor", @"Set a Color")
					  delegate:self
				   otherTitles:[TGSettingsViewController wallpaperColourNames]
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 150;
	[self showSheet:sheet];
}

- (void)pushWallpaperGradientScreen {
	NSInteger topColor = [[TGSettingsViewController wallpaperGradientValues].firstObject[0] integerValue];
	NSInteger bottomColor = [[TGSettingsViewController wallpaperGradientValues].firstObject[1] integerValue];
	NSInteger rotation = 45;

	for (NSDictionary *background in self.backgrounds) {
		if (![background isKindOfClass:[NSDictionary class]] || ![background[@"isDefault"] boolValue])
			continue;
		NSNumber *top = background[@"topColor"];
		NSNumber *bottom = background[@"bottomColor"];
		if (![top isKindOfClass:[NSNumber class]] || ![bottom isKindOfClass:[NSNumber class]])
			continue;
		if ([top integerValue] == [bottom integerValue])
			continue;
		topColor = [top integerValue];
		bottomColor = [bottom integerValue];
		NSNumber *rot = background[@"rotation"];
		if ([rot isKindOfClass:[NSNumber class]])
			rotation = [rot integerValue];
		break;
	}

	TGWallpaperGradientViewController *screen = [[TGWallpaperGradientViewController alloc] init];
	screen.topColor = topColor;
	screen.bottomColor = bottomColor;
	screen.rotation = rotation;
	__weak typeof(self) weakSelf = self;
	screen.onApplied = ^(NSDictionary *background) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || ![background isKindOfClass:[NSDictionary class]])
			return;
		strongSelf.wallpaperOriginal = nil;
		[strongSelf adoptBackgroundLocally:background];
	};
	[self.navigationController pushViewController:screen animated:YES];
}

- (void)applyBackground:(NSDictionary *)background {
	BOOL isPhoto = [background[@"fileId"] isKindOfClass:[NSNumber class]] && ![[TGSettingsViewController kindOfBackground:background] isEqualToString:@"pattern"];
	if (isPhoto && ![TGCapabilities canShowWallpaper]) {
		UIAlertView *alert = [UIAlertView alloc];
		alert = [alert initWithTitle:TGL(@"Settings.ChatBackground", @"Chat Background")
							 message:TGL(@"Settings.ThisDeviceHasTooLittleMemory", @"This device has too little memory to hold a photographic wallpaper. Colours and gradients still work.")
							delegate:nil
				   cancelButtonTitle:TGL(@"Common.OK", @"OK")
				   otherButtonTitles:nil];
		[alert show];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[TGSettingsService setDefaultBackgroundRow:background
									   blurred:(isPhoto && self.wallpaperBlurred)
								  forDarkTheme:NO
									completion:^(NSDictionary *applied) {
										if (!applied) {
											TGPrivacyComplain(TGL(@"Chat.WallpaperCouldNotBeSet", @"That wallpaper could not be set."));
											return;
										}
										[weakSelf adoptBackgroundLocally:applied];
									}];
}

- (void)adoptBackgroundLocally:(NSDictionary *)background {
	NSNumber *fileId = background[@"fileId"];
	NSString *kind = [TGSettingsViewController kindOfBackground:background];
	BOOL isPhoto = [kind isEqualToString:@"wallpaper"];
	BOOL isPattern = [kind isEqualToString:@"pattern"];
	if ((isPhoto || isPattern) && [fileId isKindOfClass:[NSNumber class]] && [TGCapabilities canShowWallpaper]) {
		if (isPhoto) {
			self.wallpaperBackgroundId = [background[@"id"] isKindOfClass:[NSString class]]
				? background[@"id"]
				: nil;
			self.wallpaperBackgroundIsMoving = [background[@"isMoving"] boolValue];
		} else {
			self.wallpaperBackgroundId = nil;
		}
		[TGTheme shared].defaultBackgroundId = self.wallpaperBackgroundId;
		__weak typeof(self) weakSelf = self;
		[TGFileDownloadService downloadFile:fileId.longLongValue
								 completion:^(NSString *path) {
									 if (!path.length) {
										 [weakSelf.tableView reloadData];
										 return;
									 }
									 CGSize screenPoints = [UIScreen mainScreen].bounds.size;
									 CGFloat screenScale = [UIScreen mainScreen].scale;
									 if (screenScale < 1.0f)
										 screenScale = 1.0f;
									 CGFloat wallpaperPixels =
										 MAX(screenPoints.width, screenPoints.height) * screenScale;
									 dispatch_async(TGImageDecodeQueue(), ^{
										 UIImage *image = nil;
										 @autoreleasepool {
											 image = TGDecodeThumbnail(path, wallpaperPixels);
											 if (image && isPattern)
												 image = [weakSelf compositePatternImage:image
																   overBackground:background
																			 size:image.size];
										 }
										 dispatch_async(dispatch_get_main_queue(), ^{
											 if (image) {
												 weakSelf.wallpaperOriginal = [weakSelf wallpaperSizedImage:image];
												 [weakSelf installWallpaperFromOriginal];
											 }
											 [weakSelf.tableView reloadData];
										 });
									 });
								 }];
		return;
	}

	self.wallpaperBackgroundId = nil;
	[TGTheme shared].defaultBackgroundId = nil;
	CGSize screen = [UIScreen mainScreen].bounds.size;
	UIImage *fill = [self swatchForBackground:background size:screen];
	if (fill)
		[[TGTheme shared] setWallpaperImage:fill];
	[self.tableView reloadData];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
	if (index == sheet.cancelButtonIndex)
		return;

	if (sheet.tag == 180) {
		NSInteger slot = self.slotPendingSignOut;
		self.slotPendingSignOut = -1;
		[self.tableView setEditing:NO animated:YES];
		if (index == sheet.destructiveButtonIndex && slot >= 0)
			[[TGAccountManager shared] signOutOfSlot:slot];
		[self.tableView reloadData];
		return;
	}

	if (sheet.tag == 89) {
		[self handleWallpaperSheet:sheet atIndex:index];
		return;
	}

	if (sheet.tag == 141 || sheet.tag == 142) {
		[self applyReactionSourceFromSheet:sheet atIndex:index];
		return;
	}

	if (sheet.tag == 154) {
		[self toggleProxyFromSheet];
		return;
	}

	if (sheet.tag == 160) {
		if ((NSUInteger)index >= self.photoSheetActions.count)
			return;
		[self presentProfilePhotoPickerFromSource:
				[self.photoSheetActions[index] isEqualToString:@"camera"]
				? UIImagePickerControllerSourceTypeCamera
				: UIImagePickerControllerSourceTypePhotoLibrary];
		return;
	}

	if (sheet.tag == 155) {
		[self deletePressedSound];
		return;
	}

	if (sheet.tag == 150) {
		[self applyWallpaperFillFromSheet:sheet atIndex:index];
		return;
	}

	if (sheet.tag == 152) {
		[self handlePressedBackgroundSheet:sheet atIndex:index];
		return;
	}

	if (sheet.tag >= 170 && sheet.tag <= 178) {
		[self applyAutoDownloadLimitFromSheet:sheet atIndex:index];
		return;
	}

	if (sheet.tag == 179) {
		[self applyAutoDownloadPresetFromSheetAtIndex:index];
		return;
	}

	[self handleUntaggedWallpaperSheet:sheet atIndex:index];
}

- (void)handleUntaggedWallpaperSheet:(UIActionSheet *)sheet atIndex:(NSInteger)index {
	if (index == sheet.destructiveButtonIndex) {
		[[TGTheme shared] setWallpaperImage:nil];
		[self.tableView reloadData];
		return;
	}
	[self presentWallpaperPicker];
}

- (void)handleWallpaperSheet:(UIActionSheet *)sheet atIndex:(NSInteger)index {
	if (index == sheet.destructiveButtonIndex)
		[[TGTheme shared] setWallpaperImage:nil];
	else
		[self presentWallpaperPicker];
	[self.tableView reloadData];
}

- (void)applyReactionSourceFromSheet:(UIActionSheet *)sheet atIndex:(NSInteger)index {
	NSArray *sources = [TGSettingsViewController reactionSources];
	if ((NSUInteger)index >= sources.count)
		return;
	if (sheet.tag == 141)
		[self writeReactionSource:sources[index]
				   pollVoteSource:[TGSettingsViewController pollVoteSource]
						  preview:[TGSettingsViewController reactionPreview]];
	else
		[self writeReactionSource:[TGSettingsViewController reactionSource]
				   pollVoteSource:sources[index]
						  preview:[TGSettingsViewController reactionPreview]];
	[self.tableView reloadData];
}

- (void)toggleProxyFromSheet {
	BOOL enable = self.activeProxyId < 0;
	NSInteger proxyId = enable
		? [[NSUserDefaults standardUserDefaults]
			  integerForKey:TGSettingsLastProxyKey]
		: self.activeProxyId;
	__weak typeof(self) weakSelf = self;
	[TGSettingsService setProxy:proxyId
						enabled:enable
					 completion:^(BOOL ok) {
						 [weakSelf loadProxyStatus];
					 }];
}

- (void)deletePressedSound {
	long long soundId = [self.pressedSound[@"id"] longLongValue];
	if (!soundId)
		return;
	[TGSettingsService removeSavedNotificationSound:soundId];
	NSMutableArray *rest = [NSMutableArray array];
	for (NSDictionary *sound in self.savedSounds) {
		if ([sound[@"id"] longLongValue] != soundId)
			[rest addObject:sound];
	}
	self.savedSounds = rest;
	self.pressedSound = nil;
	[self.tableView reloadData];
}

- (void)applyWallpaperFillFromSheet:(UIActionSheet *)sheet atIndex:(NSInteger)index {
	NSArray *values = [TGSettingsViewController wallpaperColourValues];
	if ((NSUInteger)index >= values.count)
		return;
	__weak typeof(self) weakSelf = self;
	[TGSettingsService setDefaultBackgroundColor:[values[index] integerValue]
									 forDarkTheme:NO
									   completion:^(NSDictionary *background) {
										   if (![background isKindOfClass:[NSDictionary class]]) {
											   TGPrivacyComplain(TGL(@"Chat.WallpaperCouldNotBeSet", @"That wallpaper could not be set."));
											   return;
										   }
										   weakSelf.wallpaperOriginal = nil;
										   [weakSelf adoptBackgroundLocally:background];
									   }];
}

- (void)handlePressedBackgroundSheet:(UIActionSheet *)sheet atIndex:(NSInteger)index {
	NSDictionary *background = self.pressedBackground;
	if (![background isKindOfClass:[NSDictionary class]])
		return;
	if (index == sheet.destructiveButtonIndex) {
		NSString *backgroundId = [background[@"id"] isKindOfClass:[NSString class]]
			? background[@"id"]
			: nil;
		if (!backgroundId)
			return;
		__weak typeof(self) weakSelf = self;
		[TGSettingsService removeInstalledBackgroundId:backgroundId completion:^(BOOL success) {
			typeof(self) strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!success) {
				TGPrivacyComplain(TGL(@"Privacy.TheSettingCouldNotBeChanged", @"That setting could not be changed."));
				return;
			}
			NSMutableArray *rest = [strongSelf.backgrounds mutableCopy];
			[rest removeObject:background];
			strongSelf.backgrounds = rest;
			if ([strongSelf.wallpaperBackgroundId isEqualToString:backgroundId]) {
				strongSelf.wallpaperBackgroundId = nil;
				strongSelf.wallpaperOriginal = nil;
				[TGTheme shared].defaultBackgroundId = nil;
				[[TGTheme shared] setWallpaperImage:nil];
			}
			[strongSelf.tableView reloadData];
		}];
		return;
	}
	NSString *name = [background[@"name"] isKindOfClass:[NSString class]]
		? background[@"name"]
		: nil;
	NSString *kind = [background[@"kind"] isKindOfClass:[NSString class]]
		? background[@"kind"]
		: @"wallpaper";
	if (!name.length)
		return;
	[TGSettingsService shareUrlForBackgroundNamed:name kind:kind
									   completion:^(NSString *url) {
										   if (!url.length)
											   return;
										   [UIPasteboard generalPasteboard].string = url;
										   UIAlertView *copied = [UIAlertView alloc];
										   copied = [copied initWithTitle:TGL(@"Conversation.LinkCopied", @"Link copied to clipboard")
																  message:url
																 delegate:nil
														cancelButtonTitle:TGL(@"Common.OK", @"OK")
														otherButtonTitles:nil];
										   [copied show];
									   }];
}

- (void)presentWallpaperPicker {
	if (![UIImagePickerController isSourceTypeAvailable:
				UIImagePickerControllerSourceTypePhotoLibrary]) {
		UIAlertView *alert = [UIAlertView alloc];
		alert = [alert initWithTitle:TGL(@"Settings.ChatBackground", @"Chat Background")
							 message:TGL(@"Chat.ThereIsNoPhotoLibraryOn", @"There is no photo library on this device.")
							delegate:nil
				   cancelButtonTitle:TGL(@"Common.OK", @"OK")
				   otherButtonTitles:nil];
		[alert show];
		return;
	}
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	picker.delegate = self;
	[self showPicker:picker];
}

- (void)showPicker:(UIImagePickerController *)picker {
	if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad || picker.sourceType == UIImagePickerControllerSourceTypeCamera) {
		[self presentViewController:picker animated:YES completion:nil];
		return;
	}
	[self dismissPickerPopover];
	UIPopoverController *popover =
		[[UIPopoverController alloc] initWithContentViewController:picker];
	self.pickerPopover = popover;
	[popover presentPopoverFromRect:[self anchorRect]
							 inView:self.view
		   permittedArrowDirections:UIPopoverArrowDirectionAny
						   animated:YES];
}

- (void)showSheet:(UIActionSheet *)sheet {
	if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
		[sheet tg_showFromRect:[self anchorRect] inView:self.view];
		return;
	}
	[sheet showFromRect:[self anchorRect] inView:self.view animated:YES];
}

- (CGRect)anchorRect {
	NSIndexPath *selected = [self.tableView indexPathForSelectedRow];
	if (selected)
		return [self.view convertRect:[self.tableView rectForRowAtIndexPath:selected]
							 fromView:self.tableView];
	CGRect bounds = self.view.bounds;
	return CGRectMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds), 1, 1);
}

- (BOOL)dismissPickerPopover {
	if (!self.pickerPopover)
		return NO;
	[self.pickerPopover dismissPopoverAnimated:YES];
	self.pickerPopover = nil;
	return YES;
}

- (void)imagePickerController:(UIImagePickerController *)picker
	didFinishPickingMediaWithInfo:(NSDictionary *)info {
	if (![self dismissPickerPopover])
		[picker dismissViewControllerAnimated:YES completion:nil];
	UIImage *image = info[UIImagePickerControllerOriginalImage];
	if (self.pickingProfilePhoto) {
		self.pickingProfilePhoto = NO;
		UIImage *edited = info[UIImagePickerControllerEditedImage];
		if (edited)
			image = edited;
		if (image)
			[self takeProfilePhoto:image];
		return;
	}
	if (image) {
		self.wallpaperBackgroundId = nil;
		[TGTheme shared].defaultBackgroundId = nil;
		self.wallpaperOriginal = [self wallpaperSizedImage:image];
		[self installWallpaperFromOriginal];
		[self uploadWallpaperFromOriginal];
	}
	[self.tableView reloadData];
}

- (void)uploadWallpaperFromOriginal {
	if (!self.wallpaperOriginal)
		return;
	NSData *jpeg = UIImageJPEGRepresentation(self.wallpaperOriginal, 0.8f);
	NSString *path = [NSTemporaryDirectory()
		stringByAppendingPathComponent:@"tg-wallpaper.jpg"];
	if (!jpeg || ![jpeg writeToFile:path atomically:YES]) {
		TGPrivacyComplain(TGL(@"Settings.ThePictureIsInPlaceOn", @"The picture is in place on this device, but Telegram would not store it on the account."));
		return;
	}

	__weak typeof(self) weakSelf = self;
	[TGSettingsService setDefaultBackgroundAtPath:path
										  blurred:self.wallpaperBlurred
									 forDarkTheme:NO
									   completion:^(NSDictionary *background) {
										   [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
										   __strong typeof(weakSelf) strongSelf = weakSelf;
										   if (!strongSelf)
											   return;
										   if (![background isKindOfClass:[NSDictionary class]]) {
											   strongSelf.wallpaperBackgroundId = nil;
											   [TGTheme shared].defaultBackgroundId = nil;
											   TGPrivacyComplain(TGL(@"Chat.WallpaperCouldNotBeSet", @"That wallpaper could not be set."));
											   return;
										   }
										   strongSelf.wallpaperBackgroundId = [background[@"id"] isKindOfClass:[NSString class]]
											   ? background[@"id"]
											   : nil;
										   [TGTheme shared].defaultBackgroundId = strongSelf.wallpaperBackgroundId;
										   strongSelf.wallpaperBackgroundIsMoving = [background[@"isMoving"] boolValue];
										   [strongSelf loadForPage];
									   }];
}

- (void)installWallpaperFromOriginal {
	if (!self.wallpaperOriginal)
		return;

	NSString *builtin = [TGTheme shared].builtinWallpaperName;
	[[TGTheme shared] setWallpaperImage:self.wallpaperBlurred
			? [self blurredWallpaper:self.wallpaperOriginal]
			: self.wallpaperOriginal];
	[TGTheme shared].builtinWallpaperName = builtin;
}

- (UIImage *)blurredWallpaper:(UIImage *)image {
	return TGBoxBlurredImage(image);
}

- (void)wallpaperBlurToggled:(UISwitch *)toggle {
	self.wallpaperBlurred = toggle.on;
	[[NSUserDefaults standardUserDefaults] setBool:toggle.on
											forKey:TGSettingsWallpaperBlurKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[self installWallpaperFromOriginal];
	if (!self.wallpaperBackgroundId.length)
		return;
	[TGSettingsService setDefaultBackgroundId:self.wallpaperBackgroundId
									   blurred:toggle.on
										moving:self.wallpaperBackgroundIsMoving
								  forDarkTheme:NO
									completion:nil];
}

- (void)confirmResetUsage {
	UIAlertView *confirm = [[UIAlertView alloc]
			initWithTitle:TGL(@"NetworkUsageSettings.ResetStats", @"Reset statistics")
				  message:TGL(@"NetworkUsageSettings.ResetStatsConfirmation", @"Do you want to reset your usage statistics?")
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Notifications.Reset", @"Reset"), nil];
	confirm.tag = 405;
	[confirm show];
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

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	self.pickingProfilePhoto = NO;
	if (![self dismissPickerPopover])
		[picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex == alertView.cancelButtonIndex)
		return;
	if (alertView.tag == 401)
		[self confirmedLogOut];
	else if (alertView.tag == 402)
		[self confirmedClearLocalDatabase];
	else if (alertView.tag == 403)
		[self confirmedClearAutosaveExceptions];
	else if (alertView.tag == 406)
		[self confirmedResetInstalledBackgrounds];
	else if (alertView.tag == 405)
		[self confirmedResetUsage];
	else if (alertView.tag == 407)
		[self confirmedClearNotificationExceptions];
	else if (alertView.tag == 404)
		[self confirmedResetAllNotificationSettings];
	else if (alertView.tag == 408)
		[self confirmedDeleteSyncedContacts];
}

- (void)confirmedLogOut {
	[TGSettingsService logOutWithCompletion:^(BOOL ok) {
		[TGSettingsService forgetAutoDownloadSettingsMirror];
		[[NSUserDefaults standardUserDefaults]
			removeObjectForKey:TGSettingsPresetDefaultsKey];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}];
}

- (void)confirmedClearLocalDatabase {
	[TGSettingsService clearLocalDatabaseWithCompletion:^(long long freed) {
		NSString *message = freed > 0
			? [NSString stringWithFormat:TGL(@"ClearCache.Success", @"%@ freed on your %@!"),
				TGMediaFormatBytes(freed), [TGDevice modelName] ?: @"device"]
			: TGL(@"Storage.NothingToClear", @"There was nothing to clear.");
		UIAlertView *alert = [[UIAlertView alloc]
				initWithTitle:TGL(@"Cache.Title", @"Storage")
					  message:message
					 delegate:nil
			cancelButtonTitle:TGL(@"Common.OK", @"OK")
			otherButtonTitles:nil];
		[alert show];
	}];
}

- (void)confirmedClearAutosaveExceptions {
	__weak typeof(self) weakSelf = self;
	[TGSettingsService clearAutosaveExceptionsWithCompletion:^(BOOL ok) {
		if (!ok)
			return;
		weakSelf.autosaveExceptions = @[];
		[weakSelf.tableView reloadData];
	}];
}

- (void)confirmedResetInstalledBackgrounds {
	__weak typeof(self) weakSelf = self;
	[TGSettingsService resetInstalledBackgroundsWithCompletion:^(BOOL success) {
		if (!success) {
			TGPrivacyComplain(TGL(@"Privacy.TheSettingCouldNotBeChanged", @"That setting could not be changed."));
			return;
		}
		[weakSelf loadWallpaperPage];
	}];
}

- (void)confirmedResetUsage {
	__weak typeof(self) weakSelf = self;
	[TGSettingsService resetNetworkStatisticsWithCompletion:^(BOOL ok) {
		if (!ok)
			return;
		weakSelf.usageMedia = @[];
		weakSelf.usageNetworks = @[];
		weakSelf.usageCalls = nil;
		weakSelf.usageSent = 0;
		weakSelf.usageReceived = 0;
		[weakSelf loadUsage];
		[weakSelf.tableView reloadData];
	}];
}

- (void)confirmedClearNotificationExceptions {
	__weak typeof(self) weakSelf = self;
	[TGSettingsService clearNotificationExceptionsForScope:self.exceptionsScope
												completion:^(NSInteger resetCount) {
													weakSelf.exceptions = @[];
													weakSelf.exceptionsLoaded = YES;
													[weakSelf.tableView reloadData];
												}];
}

- (void)confirmedResetAllNotificationSettings {
	__weak typeof(self) weakSelf = self;
	[TGSettingsService resetAllNotificationSettingsWithCompletion:^(BOOL ok) {
		if (!ok)
			return;
		[weakSelf.scopeSettings removeAllObjects];
		[weakSelf.exceptionCounts removeAllObjects];
		[weakSelf loadForPage];
		[weakSelf.tableView reloadData];
	}];
}

@end

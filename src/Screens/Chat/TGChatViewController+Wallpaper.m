#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+AppSettings.h"
#import "TGTheme.h"
#import "TGCapabilities.h"
#import "TGFileDownloadService.h"
#import "TGImageDecode.h"
#import "TGAlertView.h"
#import "TGLocalization.h"
#import "TGHexColour.h"

@implementation TGChatViewController (Wallpaper)

- (void)loadChatWallpaper {
	self.chatBackgroundId = nil;
	self.wallpaperView.image = [TGCapabilities canShowWallpaper] ? [[TGTheme shared] wallpaper] : nil;

	if (!self.chatId)
		return;

	NSUInteger generation = ++self.chatWallpaperLoadGeneration;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] chatBackgroundRowForChat:self.chatId
									 completion:^(NSDictionary *row, NSInteger dimming) {
										 __strong typeof(weakSelf) strongSelf = weakSelf;
										 if (!strongSelf || strongSelf.chatWallpaperLoadGeneration != generation)
											 return;
										 [strongSelf applyChatWallpaperRow:row generation:generation];
									 }];
}

- (void)applyChatWallpaperRow:(NSDictionary *)row generation:(NSUInteger)generation {
	NSString *rowId = [row[@"id"] isKindOfClass:NSString.class] ? row[@"id"] : nil;
	self.chatBackgroundId = rowId;

	if (!row) {
		self.wallpaperView.image = [TGCapabilities canShowWallpaper] ? [[TGTheme shared] wallpaper] : nil;
		return;
	}

	NSNumber *fileId = [row[@"fileId"] isKindOfClass:NSNumber.class] ? row[@"fileId"] : nil;
	NSString *kind = [row[@"kind"] isKindOfClass:NSString.class] ? row[@"kind"] : @"wallpaper";
	BOOL isPattern = [kind isEqualToString:@"pattern"];
	BOOL isPhoto = fileId != nil && !isPattern && ![kind isEqualToString:@"fill"];

	if (isPhoto) {
		if (![TGCapabilities canShowWallpaper]) {
			self.wallpaperView.image = nil;
			return;
		}
		[self downloadChatWallpaperFile:fileId.longLongValue
								blurred:[row[@"isBlurred"] boolValue]
							 generation:generation];
		return;
	}

	CGSize size = self.wallpaperView.bounds.size;
	if (size.width < 1 || size.height < 1)
		size = self.view.bounds.size;
	UIImage *swatch = [self chatWallpaperSwatchForRow:row size:size];
	if (swatch)
		self.wallpaperView.image = swatch;

	if (isPattern && fileId != nil && swatch && [TGCapabilities canShowWallpaper])
		[self downloadChatWallpaperPattern:fileId.longLongValue overFill:swatch row:row generation:generation];
}

- (void)downloadChatWallpaperFile:(long long)fileId
						   blurred:(BOOL)blurred
						generation:(NSUInteger)generation {
	__weak typeof(self) weakSelf = self;
	[TGFileDownloadService downloadFile:fileId completion:^(NSString *path) {
		if (!path.length)
			return;
		CGSize screenPoints = [UIScreen mainScreen].bounds.size;
		CGFloat screenScale = [UIScreen mainScreen].scale;
		if (screenScale < 1.0f)
			screenScale = 1.0f;
		CGFloat wallpaperPixels = MAX(screenPoints.width, screenPoints.height) * screenScale;
		dispatch_async(TGImageDecodeQueue(), ^{
			UIImage *image = nil;
			@autoreleasepool {
				image = TGDecodeThumbnail(path, wallpaperPixels);
				if (image && blurred)
					image = TGBoxBlurredImage(image);
			}
			dispatch_async(dispatch_get_main_queue(), ^{
				__strong typeof(weakSelf) strongSelf = weakSelf;
				if (!strongSelf || strongSelf.chatWallpaperLoadGeneration != generation || !image)
					return;
				strongSelf.wallpaperView.image = image;
			});
		});
	}];
}

- (void)downloadChatWallpaperPattern:(long long)fileId
							 overFill:(UIImage *)fill
								  row:(NSDictionary *)row
						   generation:(NSUInteger)generation {
	NSInteger intensity = [row[@"intensity"] isKindOfClass:NSNumber.class]
		? [row[@"intensity"] integerValue]
		: 50;
	BOOL isInverted = [row[@"isInverted"] boolValue];
	__weak typeof(self) weakSelf = self;
	[TGFileDownloadService downloadFile:fileId completion:^(NSString *path) {
		if (!path.length)
			return;
		CGSize screenPoints = [UIScreen mainScreen].bounds.size;
		CGFloat screenScale = [UIScreen mainScreen].scale;
		if (screenScale < 1.0f)
			screenScale = 1.0f;
		CGFloat wallpaperPixels = MAX(screenPoints.width, screenPoints.height) * screenScale;
		dispatch_async(TGImageDecodeQueue(), ^{
			UIImage *composited = nil;
			@autoreleasepool {
				UIImage *pattern = TGDecodeThumbnail(path, wallpaperPixels);
				if (pattern)
					composited = TGCompositeWallpaperPattern(fill, pattern, intensity, isInverted);
			}
			dispatch_async(dispatch_get_main_queue(), ^{
				__strong typeof(weakSelf) strongSelf = weakSelf;
				if (!strongSelf || strongSelf.chatWallpaperLoadGeneration != generation || !composited)
					return;
				strongSelf.wallpaperView.image = composited;
			});
		});
	}];
}

- (UIImage *)chatWallpaperSwatchForRow:(NSDictionary *)row size:(CGSize)size {
	NSNumber *top = row[@"topColor"];
	if (![top isKindOfClass:NSNumber.class])
		return nil;
	NSNumber *bottom = [row[@"bottomColor"] isKindOfClass:NSNumber.class] ? row[@"bottomColor"] : top;
	UIColor *topColour = TGColourFromHex((unsigned int)[top unsignedIntValue]);
	UIColor *bottomColour = TGColourFromHex((unsigned int)[bottom unsignedIntValue]);
	CGFloat rotation = [row[@"rotation"] isKindOfClass:NSNumber.class] ? [row[@"rotation"] floatValue] : 0.0f;

	UIGraphicsBeginImageContextWithOptions(size, YES, 1.0f);
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (!context) {
		UIGraphicsEndImageContext();
		return nil;
	}
	CGFloat locations[2] = {0.0f, 1.0f};
	NSArray *colours = @[ (id)topColour.CGColor, (id)bottomColour.CGColor ];
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGGradientRef gradient = CGGradientCreateWithColors(space, (__bridge CFArrayRef)colours, locations);
	if (gradient) {
		CGPoint startPoint, endPoint;
		TGWallpaperGradientPoints(rotation, size, &startPoint, &endPoint);
		CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
		CGGradientRelease(gradient);
	} else {
		CGContextSetFillColorWithColor(context, topColour.CGColor);
		CGContextFillRect(context, CGRectMake(0, 0, size.width, size.height));
	}
	CGColorSpaceRelease(space);
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

- (void)chatBackgroundChanged:(NSNotification *)note {
	if (note.object && ![note.object isEqual:@(self.chatId)])
		return;
	[self loadChatWallpaper];
}

- (void)offerWallpaperRevertForMessage:(NSDictionary *)m {
	if (![self wallpaperRevertTargetFor:m])
		return;
	UIAlertView *ask = [TGAlertView alloc];
	ask = [ask initWithTitle:TGL(@"Chat.WallpaperChangedAlertTitle", @"New Wallpaper")
					  message:TGL(@"Chat.WallpaperChangedAlertMessage",
						@"Keep the new wallpaper for this chat, or revert to the one you had before?")
					 delegate:self
			cancelButtonTitle:TGL(@"Chat.WallpaperChangedKeep", @"Keep")
			otherButtonTitles:TGL(@"Chat.WallpaperChangedRevert", @"Revert"), nil];
	ask.tag = kWallpaperRevertAlertTag;
	[ask show];
}

- (void)handleWallpaperRevertAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	if (buttonIndex == alertView.cancelButtonIndex)
		return;
	int64_t chatId = self.chatId;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] deleteChatBackgroundForChat:chatId
									restorePrevious:YES
										 completion:^(BOOL success) {
											 TGChatViewController *strongSelf = weakSelf;
											 if (!strongSelf)
												 return;
											 if (!success) {
												 UIAlertView *complaint = [UIAlertView alloc];
												 complaint = [complaint initWithTitle:nil
																			  message:TGL(@"Chat.WallpaperCouldNotBeReverted", @"That wallpaper could not be reverted.")
																			 delegate:nil
																	cancelButtonTitle:TGL(@"Common.OK", @"OK")
																	otherButtonTitles:nil];
												 [complaint show];
												 return;
											 }
											 [strongSelf loadChatWallpaper];
										 }];
}

@end

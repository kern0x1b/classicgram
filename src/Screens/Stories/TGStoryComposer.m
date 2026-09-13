#import "TGStoryComposer.h"
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "TGLocalization.h"
#import "TGLazyFramework.h"
#import "TGStoryService.h"
#import "TGAccountInfoService.h"
#import "TGStoryPeriod.h"
#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "TGTheme.h"
#import "TGStoryPostOptions.h"
#import "TGStoryAreaEditorViewController.h"
#import "TGStoryComposerPrivacyReset.h"
#import "TGStoryHelpers.h"

@interface TGStoryComposer () <UIImagePickerControllerDelegate, UINavigationControllerDelegate> {
	UIViewController *_host;
	NSArray *_chats;
	int64_t _asChatId;
	NSString *_path;
	BOOL _isVideo;
	double _duration;
	UIImage *_preview;
	NSString *_stageFailure;
	TGStoryPostOptions *_options;
	UINavigationController *_optionsNavigation;
	void (^_completion)(BOOL posted);
}
@end

static NSMutableArray *TGStoryComposersInFlight(void) {
	static NSMutableArray *composers = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{ composers = [[NSMutableArray alloc] init]; });
	return composers;
}

@implementation TGStoryComposer

+ (void)presentFrom:(UIViewController *)controller
		 completion:(void (^)(BOOL posted))completion {
	if (controller == nil)
		return;
	TGStoryComposer *composer = [[TGStoryComposer alloc] init];
	composer->_host = controller;
	composer->_completion = [completion copy];
	[TGStoryComposersInFlight() addObject:composer];
	[composer chooseChat];
}

+ (void)cancelAllForAccountSwitch {
	NSArray *composers = [TGStoryComposersInFlight() copy];
	for (TGStoryComposer *composer in composers)
		[composer finishPosted:NO];
}

- (void)finishPosted:(BOOL)posted {
	void (^completion)(BOOL) = _completion;
	_completion = nil;
	_options = nil;
	_optionsNavigation = nil;
	if (completion != nil)
		completion(posted);
	[TGStoryComposersInFlight() removeObject:self];
}

- (void)showMessage:(NSString *)message {
	[[[TGAlertView alloc] initWithTitle:nil
								message:message
					  cancelButtonTitle:TGL(@"Common.OK", @"OK")
						  okButtonTitle:nil
						completionBlock:nil] show];
}

#pragma mark - who to post as

- (void)chooseChat {
	__weak TGStoryComposer *weakSelf = self;
	[TGStoryService chatsToPostStoriesWithCompletion:^(NSArray *chats) {
		TGStoryComposer *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;

		if (![chats isKindOfClass:[NSArray class]] || chats.count == 0) {
			[strongSelf showMessage:TGL(@"Stories.AccountCannotPostStories",
										@"This account cannot post stories.")];
			[strongSelf finishPosted:NO];
			return;
		}
		strongSelf->_chats = chats;

		if (chats.count == 1) {
			id chat = [chats objectAtIndex:0];
			if (![chat isKindOfClass:[NSDictionary class]]) {
				[strongSelf finishPosted:NO];
				return;
			}
			[strongSelf checkChat:TGStoryChatId(chat, @"id")];
			return;
		}

		[strongSelf presentChatChooser];
	}];
}

- (NSString *)titleForChat:(int64_t)chatId {
	for (NSDictionary *chat in _chats) {
		if (![chat isKindOfClass:[NSDictionary class]])
			continue;
		if (TGStoryChatId(chat, @"id") == chatId)
			return TGStoryString(chat, @"title");
	}
	return @"";
}

- (void)presentChatChooser {
	NSMutableArray *actions = [[NSMutableArray alloc] init];
	NSMutableDictionary *byTitle = [[NSMutableDictionary alloc] init];
	for (NSDictionary *chat in _chats) {
		if (![chat isKindOfClass:[NSDictionary class]])
			continue;
		NSString *title = TGStoryString(chat, @"title");
		if (title.length == 0)
			continue;
		[byTitle setObject:[chat objectForKey:@"id"] forKey:title];
		[actions addObject:[[TGActionSheetAction alloc] initWithTitle:title action:title]];
	}
	NSString *cancelTitle = TGL(@"Common.Cancel", @"Cancel");
	TGActionSheetAction *cancelAction = [[TGActionSheetAction alloc] initWithTitle:cancelTitle action:@"cancel" type:TGActionSheetActionTypeCancel];
	[actions addObject:cancelAction];

	BOOL reopened = (_options != nil);
	__weak TGStoryComposer *weakSelf = self;
	TGActionSheet *sheetAlloc = [TGActionSheet alloc];
	TGActionSheet *sheet =
		[sheetAlloc initWithTitle:TGL(@"Story.Privacy.PostStoryAs", @"Post As")
						  actions:actions
					  actionBlock:^(id target, NSString *action) {
						  (void)target;
						  TGStoryComposer *strongSelf = weakSelf;
						  if (strongSelf == nil)
							  return;
						  NSNumber *identifier = [byTitle objectForKey:action];
						  if (identifier == nil) {
							  if (!reopened)
								  [strongSelf finishPosted:NO];
							  return;
						  }
						  [strongSelf checkChat:(int64_t)[identifier longLongValue]];
					  }
						   target:self];
	UIView *chooserAnchorView = (_options != nil ? _options.view : _host.view);
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(chooserAnchorView.bounds), CGRectGetMidY(chooserAnchorView.bounds), 1, 1) inView:chooserAnchorView];
}

- (void)checkChat:(int64_t)chatId {
	int64_t previous = _asChatId;
	_asChatId = chatId;
	__weak TGStoryComposer *weakSelf = self;
	[TGStoryService canPostStoryAsChat:chatId completion:^(BOOL canPost, NSString *reason) {
		TGStoryComposer *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		if (!canPost) {
			NSString *message = (reason.length > 0
									  ? reason
									  : TGL(@"Stories.CannotBePostedRightNow",
											@"Stories cannot be posted right now."));
			if (strongSelf->_options != nil) {
				strongSelf->_asChatId = previous;
				[strongSelf showMessage:message];
				return;
			}
			if (strongSelf->_chats.count > 1) {
				[[[TGAlertView alloc] initWithTitle:nil
											 message:message
								   cancelButtonTitle:TGL(@"Common.OK", @"OK")
									   okButtonTitle:nil
									 completionBlock:^(bool okButtonPressed) {
					(void)okButtonPressed;
					TGStoryComposer *innerSelf = weakSelf;
					if (innerSelf != nil)
						[innerSelf presentChatChooser];
				}] show];
				return;
			}
			[strongSelf showMessage:message];
			[strongSelf finishPosted:NO];
			return;
		}
		if (strongSelf->_options != nil) {
			[strongSelf refreshOptionsForChat];
			return;
		}
		[strongSelf pickSource];
	}];
}

#pragma mark - picking the media

- (void)pickSource {
	BOOL hasCamera = [UIImagePickerController isSourceTypeAvailable:
			UIImagePickerControllerSourceTypeCamera];
	BOOL hasLibrary = [UIImagePickerController isSourceTypeAvailable:
			UIImagePickerControllerSourceTypePhotoLibrary];
	NSArray *cameraTypes = hasCamera ? [UIImagePickerController availableMediaTypesForSourceType:
											   UIImagePickerControllerSourceTypeCamera]
									 : nil;
	NSArray *libraryTypes = hasLibrary ? [UIImagePickerController availableMediaTypesForSourceType:
												 UIImagePickerControllerSourceTypePhotoLibrary]
									   : nil;
	BOOL canRecord = [cameraTypes containsObject:(NSString *)kUTTypeMovie];
	BOOL canPickMovie = [libraryTypes containsObject:(NSString *)kUTTypeMovie];

	if (!hasCamera && !hasLibrary) {
		[self showMessage:TGL(@"Settings.ThereIsNoCameraAndNo",
							  @"There is no camera and no photo library on this device.")];
		[self finishPosted:NO];
		return;
	}

	NSMutableArray *actions = [[NSMutableArray alloc] init];
	if (hasCamera) {
		NSString *cameraTitle = TGL(@"Common.TakePhoto", @"Take Photo");
		TGActionSheetAction *cameraAction = [[TGActionSheetAction alloc] initWithTitle:cameraTitle action:@"takePhoto"];
		[actions addObject:cameraAction];
	}
	if (canRecord) {
		NSString *recordTitle = TGL(@"Stories.RecordVideo", @"Record Video");
		TGActionSheetAction *recordAction = [[TGActionSheetAction alloc] initWithTitle:recordTitle action:@"recordVideo"];
		[actions addObject:recordAction];
	}
	if (hasLibrary) {
		NSString *libraryTitle = TGL(@"Common.ChoosePhoto", @"Choose Photo");
		TGActionSheetAction *libraryAction = [[TGActionSheetAction alloc] initWithTitle:libraryTitle action:@"choosePhoto"];
		[actions addObject:libraryAction];
	}
	if (canPickMovie) {
		NSString *movieTitle = TGL(@"Stories.ChooseVideo", @"Choose Video");
		TGActionSheetAction *movieAction = [[TGActionSheetAction alloc] initWithTitle:movieTitle action:@"chooseVideo"];
		[actions addObject:movieAction];
	}
	NSString *cancelTitle = TGL(@"Common.Cancel", @"Cancel");
	TGActionSheetAction *cancelAction = [[TGActionSheetAction alloc] initWithTitle:cancelTitle action:@"cancel" type:TGActionSheetActionTypeCancel];
	[actions addObject:cancelAction];

	__weak TGStoryComposer *weakSelf = self;
	TGActionSheet *sheetAlloc = [TGActionSheet alloc];
	TGActionSheet *sheet =
		[sheetAlloc initWithTitle:TGL(@"Notification.LockScreenStoryPlaceholder", @"New Story")
						  actions:actions
					  actionBlock:^(id target, NSString *action) {
						  (void)target;
						  TGStoryComposer *strongSelf = weakSelf;
						  if (strongSelf == nil)
							  return;
						  if ([action isEqualToString:@"takePhoto"])
							  [strongSelf openPickerWithSource:UIImagePickerControllerSourceTypeCamera video:NO];
						  else if ([action isEqualToString:@"recordVideo"])
							  [strongSelf openPickerWithSource:UIImagePickerControllerSourceTypeCamera video:YES];
						  else if ([action isEqualToString:@"choosePhoto"])
							  [strongSelf openPickerWithSource:UIImagePickerControllerSourceTypePhotoLibrary video:NO];
						  else if ([action isEqualToString:@"chooseVideo"])
							  [strongSelf openPickerWithSource:UIImagePickerControllerSourceTypePhotoLibrary video:YES];
						  else
							  [strongSelf finishPosted:NO];
					  }
						   target:self];
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(_host.view.bounds), CGRectGetMidY(_host.view.bounds), 1, 1) inView:_host.view];
}

- (void)openPickerWithSource:(UIImagePickerControllerSourceType)source video:(BOOL)video {
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = source;
	picker.delegate = self;
	picker.allowsEditing = YES;
	if (video) {
		picker.mediaTypes = [NSArray arrayWithObject:(NSString *)kUTTypeMovie];
		picker.videoQuality = UIImagePickerControllerQualityTypeMedium;
		picker.videoMaximumDuration = 60.0;
	} else {
		picker.mediaTypes = [NSArray arrayWithObject:(NSString *)kUTTypeImage];
	}
	[_host presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	(void)picker;
	[_host dismissViewControllerAnimated:YES completion:nil];
	[self finishPosted:NO];
}

- (void)imagePickerController:(UIImagePickerController *)picker
	didFinishPickingMediaWithInfo:(NSDictionary *)info {
	(void)picker;

	_stageFailure = nil;

	NSURL *movie = [info objectForKey:UIImagePickerControllerMediaURL];
	if ([movie isKindOfClass:[NSURL class]] && movie.path.length > 0) {
		BOOL staged = [self stageVideoAtPath:movie.path];
		[_host dismissViewControllerAnimated:YES completion:^{
			if (staged)
				[self presentOptions];
			else
				[self failStaging:TGL(@"Stories.CouldNotPrepareTheVideo",
									  @"That video could not be prepared.")];
		}];
		return;
	}

	UIImage *image = [info objectForKey:UIImagePickerControllerEditedImage];
	if (![image isKindOfClass:[UIImage class]])
		image = [info objectForKey:UIImagePickerControllerOriginalImage];

	BOOL staged = [image isKindOfClass:[UIImage class]] && [self stageImage:image];
	[_host dismissViewControllerAnimated:YES completion:^{
		if (staged)
			[self presentOptions];
		else
			[self failStaging:TGL(@"Toast.CouldNotPreparePhoto",
								  @"Could not prepare the photo")];
	}];
}

- (void)failStaging:(NSString *)fallback {
	[self showMessage:(_stageFailure.length > 0 ? _stageFailure : fallback)];
	_stageFailure = nil;
	[self finishPosted:NO];
}

- (NSString *)temporaryPathWithExtension:(NSString *)extension {
	return [NSTemporaryDirectory() stringByAppendingPathComponent:
			[NSString stringWithFormat:@"story-%.0f.%@",
				[[NSDate date] timeIntervalSince1970] * 1000.0, extension]];
}

- (BOOL)stageImage:(UIImage *)image {
	NSString *path = [self temporaryPathWithExtension:@"jpg"];
	BOOL written = NO;

	@autoreleasepool {
		CGSize canvas = CGSizeMake(720.0f, 1280.0f);
		CGSize source = image.size;
		if (source.width < 1.0f || source.height < 1.0f)
			return NO;

		BOOL portrait = source.height >= source.width;
		CGFloat scale = portrait
			? MAX(canvas.width / source.width, canvas.height / source.height)
			: MIN(canvas.width / source.width, canvas.height / source.height);
		CGSize drawn = CGSizeMake(floorf(source.width * scale), floorf(source.height * scale));
		CGRect target = CGRectMake(floorf((canvas.width - drawn.width) / 2.0f),
			floorf((canvas.height - drawn.height) / 2.0f),
			drawn.width, drawn.height);

		UIGraphicsBeginImageContextWithOptions(canvas, YES, 1.0f);
		[[UIColor blackColor] setFill];
		UIRectFill(CGRectMake(0, 0, canvas.width, canvas.height));
		[image drawInRect:target];
		UIImage *composed = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();

		NSData *data = UIImageJPEGRepresentation(composed, 0.87f);
		if (data.length != 0)
			written = [data writeToFile:path atomically:YES];
		if (written)
			_preview = composed;
	}

	if (!written)
		return NO;
	_path = path;
	_isVideo = NO;
	_duration = 0.0;
	return YES;
}

static BOOL TGVideoFrameLooksBlack(CGImageRef frame) {
	if (frame == NULL)
		return NO;

	const size_t side = 8;
	unsigned char pixels[8 * 8 * 4];
	memset(pixels, 0, sizeof(pixels));

	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(pixels, side, side, 8, side * 4, space,
		kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
	CGColorSpaceRelease(space);
	if (context == NULL)
		return NO;

	CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, side, side), frame);
	CGContextRelease(context);

	NSInteger opaque = 0;
	NSInteger dark = 0;
	for (size_t i = 0; i < side * side; i++) {
		if (pixels[i * 4 + 3] <= 16)
			continue;
		opaque++;
		if (pixels[i * 4] < 14 && pixels[i * 4 + 1] < 14 && pixels[i * 4 + 2] < 14)
			dark++;
	}
	return opaque != 0 && dark * 100 / opaque > 92;
}

static UIImage *TGVideoPosterFrame(AVAsset *asset, CGSize maximumSize) {
	AVAssetImageGenerator *generator =
		[[TGAVClass(AVAssetImageGenerator) alloc] initWithAsset:asset];
	generator.appliesPreferredTrackTransform = YES;
	generator.maximumSize = maximumSize;

	CMTime length = asset.duration;
	double duration = CMTIME_IS_NUMERIC(length) ? CMTimeGetSeconds(length) : 0.0;
	const double candidates[] = {0.0, 0.15, 0.5, 1.0};
	int32_t timescale = MAX(1, length.timescale);
	UIImage *fallback = nil;

	for (size_t i = 0; i < sizeof(candidates) / sizeof(candidates[0]); i++) {
		double seconds = candidates[i];
		if (duration > 0.01)
			seconds = MIN(seconds, MAX(0.0, duration - 0.01));

		CMTime frameTime = CMTimeMakeWithSeconds(seconds, timescale);
		CGImageRef frame = [generator copyCGImageAtTime:frameTime actualTime:NULL error:NULL];
		if (frame == NULL)
			continue;

		BOOL black = TGVideoFrameLooksBlack(frame);
		UIImage *image = [UIImage imageWithCGImage:frame];
		CGImageRelease(frame);

		if (!fallback)
			fallback = image;
		if (!black)
			return image;
	}
	return fallback;
}

- (BOOL)stageVideoAtPath:(NSString *)path {
	if (![[NSFileManager defaultManager] fileExistsAtPath:path])
		return NO;

	AVURLAsset *asset = [TGAVClass(AVURLAsset) URLAssetWithURL:[NSURL fileURLWithPath:path] options:nil];
	CMTime length = asset.duration;
	double seconds = CMTIME_IS_NUMERIC(length) ? CMTimeGetSeconds(length) : 0.0;
	if (seconds > 60.0) {
		_stageFailure = TGL(@"Stories.VideoTooLong", @"A story video can be at most one minute long.");
		return NO;
	}

	@autoreleasepool {
		_preview = TGVideoPosterFrame(asset, CGSizeMake(360.0f, 640.0f));
	}

	_path = path;
	_isVideo = YES;
	_duration = seconds;
	return YES;
}

#pragma mark - the options screen

- (void)presentOptions {
	_options = [[TGStoryPostOptions alloc] init];
	_options.preview = _preview;
	_options.privacy = @"everyone";
	_options.period = TGStoryPeriodDay;
	_options.toProfile = NO;
	_options.premium = [TGAccountInfoService isPremiumAccount];
	_options.showsPrivacy = TGStoryComposerShowsPrivacyForChat(_asChatId);
	_options.chatTitle = (_chats.count > 1) ? [self titleForChat:_asChatId] : nil;

	__weak TGStoryComposer *weakSelf = self;
	_options.onCancel = ^{
		TGStoryComposer *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		[strongSelf->_host dismissViewControllerAnimated:YES completion:nil];
		[strongSelf finishPosted:NO];
	};
	_options.onChangeChat = ^{
		TGStoryComposer *strongSelf = weakSelf;
		if (strongSelf != nil)
			[strongSelf presentChatChooser];
	};
	_options.onPost = ^{
		TGStoryComposer *strongSelf = weakSelf;
		if (strongSelf != nil)
			[strongSelf post];
	};
	_options.onEditAreas = ^(void (^applyAreas)(NSArray *areas)) {
		TGStoryComposer *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		[strongSelf pushAreaEditorWithApply:applyAreas];
	};

	_optionsNavigation = [[UINavigationController alloc] initWithRootViewController:_options];
	[[TGTheme shared] styleNavigationBar:_optionsNavigation.navigationBar];
	[_host presentViewController:_optionsNavigation animated:YES completion:nil];
}

- (void)pushAreaEditorWithApply:(void (^)(NSArray *areas))applyAreas {
	TGStoryAreaEditorViewController *editor = [[TGStoryAreaEditorViewController alloc] init];
	editor.preview = _preview;
	editor.premium = _options.premium;
	editor.existingAreas = _options.areas;
	editor.onDone = ^(NSArray *areas) {
		if (applyAreas)
			applyAreas(areas);
	};
	[_optionsNavigation pushViewController:editor animated:YES];
}

- (void)refreshOptionsForChat {
	_options.chatTitle = (_chats.count > 1) ? [self titleForChat:_asChatId] : nil;
	_options.showsPrivacy = TGStoryComposerShowsPrivacyForChat(_asChatId);
	if (!_options.showsPrivacy) {
		_options.privacy = @"everyone";
		_options.userIds = nil;
	}
	[_options rebuildSections];
}

#pragma mark - posting

- (void)post {
	__weak TGStoryComposer *weakSelf = self;
	[_options setBusy:YES];

	void (^progress)(float) = ^(float fraction) {
		TGStoryComposer *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		[strongSelf->_options setProgress:fraction];
	};

	void (^done)(NSDictionary *, NSString *) = ^(NSDictionary *story, NSString *error) {
		TGStoryComposer *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		if (story == nil) {
			[strongSelf->_options setBusy:NO];
			[strongSelf showMessage:(error.length > 0
										  ? error
										  : TGL(@"Stories.TheStoryCouldNotBePosted",
												@"The story could not be posted."))];
			return;
		}
		[strongSelf->_host dismissViewControllerAnimated:YES completion:nil];
		[strongSelf finishPosted:YES];
	};

	if (_isVideo) {
		[TGStoryService postVideoStoryAtPath:_path
									duration:_duration
									  asChat:_asChatId
									 caption:(_options.caption ?: @"")
			privacy:(_options.privacy ?: @"everyone")
			userIds:_options.userIds
								activePeriod:_options.period
									   areas:_options.areas
								   toProfile:_options.toProfile
									progress:progress
								  completion:done];
		return;
	}

	[TGStoryService postPhotoStoryAtPath:_path
								  asChat:_asChatId
								 caption:(_options.caption ?: @"")
		privacy:(_options.privacy ?: @"everyone")
		userIds:_options.userIds
							activePeriod:_options.period
								   areas:_options.areas
							   toProfile:_options.toProfile
								progress:progress
							  completion:done];
}

@end

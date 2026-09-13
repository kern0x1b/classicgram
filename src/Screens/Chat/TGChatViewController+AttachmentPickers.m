#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+Messages.h"
#import "TGLocalization.h"
#import "TGRichText.h"
#import "TGTheme.h"
#import "TGSnackbar.h"
#import "TGActionSheet.h"
#import "TGPopupMenu.h"
#import "TGForwardPicker.h"
#import "TGClient+MessageContent.h"
#import "TGReactionPickerView.h"
#import "TGMessageActionsSheet.h"
#import "TGTextSelectionOverlay.h"
#import "TGQuotePickerViewController.h"
#import "TGAlertView.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "TGLazyFramework.h"
#import "TGAssetPicker.h"
#import "TGMediaSendPreviewViewController.h"
#import "TGLiveLocationExpiry.h"
#import <float.h>
#import "TGLiveLocationFix.h"

static NSString *TGStageOriginalAssetAsDocument(ALAsset *asset) {
	ALAssetRepresentation *representation = [asset defaultRepresentation];
	if (!representation)
		return nil;

	long long size = [representation size];
	if (size <= 0)
		return nil;

	NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)size];
	NSError *error = nil;
	NSUInteger read = [representation getBytes:data.mutableBytes
									 fromOffset:0
										 length:(NSUInteger)size
										  error:&error];
	if (error || read != (NSUInteger)size)
		return nil;

	NSString *extension = [representation.filename pathExtension];
	if (!extension.length)
		extension = @"dat";
	NSString *name = [NSString stringWithFormat:@"outgoing-%.0f.%@",
		[[NSDate date] timeIntervalSince1970] * 1000, extension];
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
	if (![data writeToFile:path atomically:YES])
		return nil;
	return path;
}

@implementation TGChatViewController (AttachmentPickers)

- (void)takePhoto {
	if (![self cameraAvailable] || self.postingBlocked)
		return;

	if ([TGAVClass(AVCaptureDevice) respondsToSelector:@selector(authorizationStatusForMediaType:)]) {
		AVAuthorizationStatus status =
			[TGAVClass(AVCaptureDevice) authorizationStatusForMediaType:TGAVString(AVMediaTypeVideo)];
		if (status == AVAuthorizationStatusDenied || status == AVAuthorizationStatusRestricted) {
			[self showAlertTitle:@"" message:TGL(@"AccessDenied.Camera",
				@"Telegram needs access to your camera. Please go to Settings > Privacy > Camera and set Telegram to ON.")];
			return;
		}
		if (status == AVAuthorizationStatusNotDetermined) {
			__weak typeof(self) weakSelf = self;
			Class captureDeviceClass = TGAVClass(AVCaptureDevice);
			[captureDeviceClass requestAccessForMediaType:TGAVString(AVMediaTypeVideo)
										 completionHandler:^(BOOL granted) {
				dispatch_async(dispatch_get_main_queue(), ^{
					TGChatViewController *strongSelf = weakSelf;
					if (!strongSelf)
						return;
					if (granted)
						[strongSelf takePhoto];
					else
						[strongSelf showAlertTitle:@"" message:TGL(@"AccessDenied.Camera",
							@"Telegram needs access to your camera. Please go to Settings > Privacy > Camera and set Telegram to ON.")];
				});
			}];
			return;
		}
	}

	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = UIImagePickerControllerSourceTypeCamera;
	picker.mediaTypes = @[ (NSString *)kUTTypeImage ];
	picker.delegate = self;
	[self presentViewController:picker animated:YES completion:nil];
}

- (NSString *)stageImageForSending:(UIImage *)image {
	if (!image)
		return nil;
	NSData *jpeg = UIImageJPEGRepresentation(image, 0.85f);
	if (!jpeg.length)
		return nil;
	NSString *name = [NSString stringWithFormat:@"outgoing-%.0f.jpg",
		[[NSDate date] timeIntervalSince1970] * 1000];
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
	if (![jpeg writeToFile:path atomically:YES])
		return nil;
	return path;
}

- (void)pastePhoto {
	if (self.postingBlocked)
		return;
	UIImage *image = [self pasteboardImage];
	if (!image)
		return;
	[self presentSendPreviewForImage:image videoPath:nil videoDuration:0 videoSize:CGSizeZero];
}

- (void)sendPendingPastedImage {
	UIImage *image = self.pendingPastedImage;
	self.pendingPastedImage = nil;
	if (self.postingBlocked)
		return;
	if ([self blockSendForSlowMode])
		return;
	if (self.composeMode == TGComposeModeEdit) {
		[TGSnackbar showInView:self.view
						   text:TGL(@"Toast.CantAttachWhileEditing", @"Finish or cancel your edit before attaching media")
						seconds:3
					   onCommit:nil];
		return;
	}
	NSString *path = [self stageImageForSending:image];
	if (!path)
		return;
	[[TGClient shared] sendChatAction:@"uploadingPhoto" toChat:self.chatId thread:self.threadId];
	[[TGClient shared] sendPhotoAtPath:path
								toChat:self.chatId
								thread:self.threadId
				   directMessagesTopic:self.directMessagesTopicId
							savedTopic:self.savedTopicId
							   replyTo:self.replyToId
							   caption:@""
							   spoiler:NO
				   selfDestructSeconds:[self mediaSelfDestruct]
							   options:[self sendOptionsDictionary]];
	[self clearMediaSelfDestruct];
	[self clearComposeState];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kDeferredActionDelay * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			[[TGClient shared] sendChatAction:@"cancel" toChat:self.chatId thread:self.threadId];
			[self reload];
		});
}

- (void)pickMusic {
	if (self.postingBlocked)
		return;
	MPMediaPickerController *picker = [[TGMPClass(MPMediaPickerController) alloc]
		initWithMediaTypes:MPMediaTypeMusic];
	picker.delegate = self;
	picker.allowsPickingMultipleItems = NO;
	[self presentViewController:picker animated:YES completion:nil];
}

- (void)mediaPicker:(MPMediaPickerController *)mediaPicker
	didPickMediaItems:(MPMediaItemCollection *)collection {
	[mediaPicker dismissViewControllerAnimated:YES completion:nil];

	MPMediaItem *item = [collection.items firstObject];
	NSURL *asset = [item valueForProperty:TGMPString(MPMediaItemPropertyAssetURL)];
	if (!asset) {
		[self showAlertTitle:@"" message:TGL(@"Chat.ThisTrackCannotBeSent", @"This track cannot be sent.")];
		return;
	}

	NSString *title = [item valueForProperty:TGMPString(MPMediaItemPropertyTitle)];
	NSString *performer = [item valueForProperty:TGMPString(MPMediaItemPropertyArtist)];
	NSNumber *seconds = [item valueForProperty:TGMPString(MPMediaItemPropertyPlaybackDuration)];

	AVURLAsset *source = [TGAVClass(AVURLAsset) URLAssetWithURL:asset options:nil];
	AVAssetExportSession *export = [[TGAVClass(AVAssetExportSession) alloc]
		initWithAsset:source
		   presetName:TGAVString(AVAssetExportPresetAppleM4A)];
	if (!export) {
		[self showAlertTitle:@"" message:TGL(@"Chat.ThisTrackCannotBeSent", @"This track cannot be sent.")];
		return;
	}

	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
			[NSString stringWithFormat:@"music-%.0f.m4a",
				[[NSDate date] timeIntervalSince1970] * 1000]];
	export.outputURL = [NSURL fileURLWithPath:path];
	export.outputFileType = TGAVString(AVFileTypeAppleM4A);

	__weak typeof(self) weakSelf = self;
	[export exportAsynchronouslyWithCompletionHandler:^{
		AVAssetExportSessionStatus status = export.status;
		dispatch_async(dispatch_get_main_queue(), ^{
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (status != AVAssetExportSessionStatusCompleted) {
				[strongSelf showAlertTitle:@"" message:TGL(@"Chat.ThisTrackCannotBeSent", @"This track cannot be sent.")];
				return;
			}
			[[TGClient shared] sendAudioAtPath:path
										toChat:strongSelf.chatId
										thread:strongSelf.threadId
						   directMessagesTopic:strongSelf.directMessagesTopicId
									savedTopic:strongSelf.savedTopicId
									   replyTo:strongSelf.replyToId
										 title:title
									 performer:performer
									  duration:(NSInteger)[seconds doubleValue]
									   caption:@""
									   options:[strongSelf sendOptionsDictionary]];
			[strongSelf clearComposeState];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kDeferredActionDelay * NSEC_PER_SEC)),
				dispatch_get_main_queue(), ^{ [strongSelf reload]; });
		});
	}];
}

- (void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker {
	[mediaPicker dismissViewControllerAnimated:YES completion:nil];
}

- (void)pickMedia {
	if (![UIImagePickerController isSourceTypeAvailable:
				UIImagePickerControllerSourceTypePhotoLibrary])
		return;

	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;

	picker.mediaTypes = @[ (NSString *)kUTTypeImage, (NSString *)kUTTypeMovie ];
	picker.delegate = self;
	[self presentViewController:picker animated:YES completion:nil];
}

static CLLocationAccuracy TGHundredMeters(void) {
	CLLocationAccuracy *value = TGFrameworkSymbol(@"CoreLocation",
		"kCLLocationAccuracyHundredMeters");
	return value ? *value : 100.0;
}

static CLLocationDistance TGDistanceFilterNone(void) {
	CLLocationDistance *value = TGFrameworkSymbol(@"CoreLocation", "kCLDistanceFilterNone");
	return value ? *value : DBL_MAX;
}

static const NSInteger kLiveLocationMaxConsecutiveFailures = 3;
static const NSInteger kLiveLocationTerminalErrorCode = 400;
static const NSTimeInterval kLiveLocationRefreshInterval = 30.0;
static const NSTimeInterval kLocationFetchTimeout = 20.0;

static void TGSetAllowsBackgroundLocationUpdates(CLLocationManager *manager, BOOL allowed) {
	SEL selector = NSSelectorFromString(@"setAllowsBackgroundLocationUpdates:");
	if ([manager respondsToSelector:selector])
		[manager setValue:@(allowed) forKey:@"allowsBackgroundLocationUpdates"];
}

- (void)stopLiveLocationTrackingCleanup {
	self.liveLocationFailureCount = 0;
	[TGClient shared].hasActiveLiveLocationShare = NO;
	TGSetAllowsBackgroundLocationUpdates(self.locationManager, NO);
	self.locationManager.distanceFilter = TGDistanceFilterNone();
	[self.locationManager stopUpdatingLocation];
}

- (NSDictionary *)trackedLiveLocationMessage {
	if (!self.liveLocationMessageId)
		return nil;
	for (NSDictionary *m in self.messages)
		if ([m[@"id"] longLongValue] == self.liveLocationMessageId)
			return m;
	return nil;
}

- (BOOL)liveLocationTrackingHasExpired {
	NSDictionary *tracked = [self trackedLiveLocationMessage];
	if (!tracked)
		return NO;
	return TGLiveLocationHasExpired([tracked[@"livePeriod"] integerValue],
		[tracked[@"liveExpiresAt"] doubleValue], [NSDate timeIntervalSinceReferenceDate]);
}

- (void)stopExpiredLiveLocationTracking {
	int64_t expiredMessageId = self.liveLocationMessageId;
	self.liveLocationMessageId = 0;
	self.locationMode = nil;
	[self stopLiveLocationTrackingCleanup];
	[[TGClient shared] stopLiveLocation:expiredMessageId inChat:self.chatId completion:nil];
	[self refreshLiveLocationTimerState];
}

- (BOOL)chatHasPendingLiveLocationCountdown {
	if (self.liveLocationMessageId)
		return YES;
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	for (NSDictionary *m in self.messages) {
		if (![m[@"kind"] isEqualToString:@"messageLiveLocation"])
			continue;
		if (!TGLiveLocationHasExpired([m[@"livePeriod"] integerValue], [m[@"liveExpiresAt"] doubleValue], now))
			return YES;
	}
	return NO;
}

- (void)refreshLiveLocationTimerState {
	BOOL needed = [self chatHasPendingLiveLocationCountdown];
	if (needed == (self.liveLocationRefreshTimer != nil))
		return;
	if (needed) {
		self.liveLocationRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:kLiveLocationRefreshInterval
																		  target:self
																		selector:@selector(liveLocationRefreshTimerFired)
																		userInfo:nil
																		 repeats:YES];
	} else {
		[self.liveLocationRefreshTimer invalidate];
		self.liveLocationRefreshTimer = nil;
	}
}

- (void)liveLocationRefreshTimerFired {
	if ([self liveLocationTrackingHasExpired])
		[self stopExpiredLiveLocationTracking];
	for (NSDictionary *m in self.messages) {
		if (![m[@"kind"] isEqualToString:@"messageLiveLocation"])
			continue;
		NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
		if (messageId)
			[self tg_invalidateLayoutForMessageId:messageId.longLongValue];
	}
	[self.table reloadData];
	[self refreshLiveLocationTimerState];
}

- (void)sendCurrentLocation {
	if (!self.locationManager) {
		Class managerClass = TGFrameworkClass(@"CoreLocation", @"CLLocationManager");
		if (!managerClass) {
			[self showAlertTitle:@"" message:TGL(@"Chat.LocationIsNotAvailable", @"Location is not available.")];
			return;
		}
		self.locationManager = [[managerClass alloc] init];
		self.locationManager.delegate = self;
		self.locationManager.desiredAccuracy = TGHundredMeters();
	}
	[self startLocationUpdatesRequestingAuthorizationIfNeeded];
}

- (BOOL)startLocationUpdatesRequestingAuthorizationIfNeeded {
	Class managerClass = [self.locationManager class];
	CLAuthorizationStatus status = [managerClass respondsToSelector:@selector(authorizationStatus)]
		? [managerClass authorizationStatus]
		: kCLAuthorizationStatusAuthorizedAlways;
	if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
		self.locationMode = nil;
		[self showAlertTitle:@"" message:TGL(@"AccessDenied.Location", @"Telegram needs access to your location. Please go to Settings > Privacy > Location and set Telegram to ON.")];
		return NO;
	}
	if (status == kCLAuthorizationStatusNotDetermined) {
		if ([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)])
			[self.locationManager requestWhenInUseAuthorization];
		return NO;
	}
	[self.locationManager startUpdatingLocation];
	[self scheduleLocationFetchTimeout];
	return YES;
}

- (void)scheduleLocationFetchTimeout {
	[self cancelLocationFetchTimeout];
	if ([self.locationMode isEqualToString:@"tracking"])
		return;
	self.locationFetchTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:kLocationFetchTimeout
																	   target:self
																	 selector:@selector(locationFetchTimedOut)
																	 userInfo:nil
																	  repeats:NO];
}

- (void)cancelLocationFetchTimeout {
	[self.locationFetchTimeoutTimer invalidate];
	self.locationFetchTimeoutTimer = nil;
}

- (void)locationFetchTimedOut {
	self.locationFetchTimeoutTimer = nil;
	if ([self.locationMode isEqualToString:@"tracking"])
		return;
	[self.locationManager stopUpdatingLocation];
	self.locationMode = nil;
	self.venuePrefetchedLocation = nil;
	self.venueGeocodedAddress = nil;
	[self showAlertTitle:@"" message:TGL(@"Chat.LocationIsNotAvailable", @"Location is not available.")];
}

- (void)prefetchVenueLocation {
	self.venuePrefetchedLocation = nil;
	self.venueGeocodedAddress = nil;
	self.locationMode = @"venuePrefetch";
	[self sendCurrentLocation];
}

- (void)sendVenueWithCachedLocation:(CLLocation *)fix {
	if (!fix || !self.venueTitle.length)
		return;
	[[TGClient shared] sendVenueWithTitle:self.venueTitle
								  address:(self.venueAddress ?: @"")
				 latitude:fix.coordinate.latitude
								longitude:fix.coordinate.longitude
								   toChat:self.chatId
								  replyTo:self.replyToId
								  options:[self sendOptionsDictionary]];
	self.venueTitle = nil;
	self.venueAddress = nil;
	self.venuePrefetchedLocation = nil;
	self.venueGeocodedAddress = nil;
	self.locationMode = nil;
	[self clearComposeState];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kDeferredActionDelay * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{ [self reload]; });
}

- (void)locationManager:(CLLocationManager *)manager
	 didUpdateLocations:(NSArray *)locations {
	CLLocation *fix = [locations lastObject];
	NSString *mode = self.locationMode ?: @"point";

	if ([mode isEqualToString:@"tracking"]) {
		if ([self liveLocationTrackingHasExpired]) {
			[self stopExpiredLiveLocationTracking];
			return;
		}
		if (fix && self.liveLocationMessageId) {
			__weak typeof(self) weakSelf = self;
			int64_t trackedMessageId = self.liveLocationMessageId;
			[[TGClient shared] updateLiveLocation:trackedMessageId
										   inChat:self.chatId
										 latitude:fix.coordinate.latitude
										longitude:fix.coordinate.longitude
										  heading:TGLiveLocationHeadingFromCourse(fix.course)
										 accuracy:TGLiveLocationAccuracyFromFix(fix.horizontalAccuracy)
								   completion:^(BOOL ok, NSInteger errorCode) {
									typeof(self) strongSelf = weakSelf;
									if (!strongSelf || strongSelf.liveLocationMessageId != trackedMessageId)
										return;
									if (ok) {
										strongSelf.liveLocationFailureCount = 0;
										return;
									}
									BOOL terminal = errorCode == kLiveLocationTerminalErrorCode;
									if (!terminal) {
										strongSelf.liveLocationFailureCount++;
										if (strongSelf.liveLocationFailureCount < kLiveLocationMaxConsecutiveFailures)
											return;
									}
									strongSelf.liveLocationMessageId = 0;
									strongSelf.locationMode = nil;
									[strongSelf stopLiveLocationTrackingCleanup];
									[strongSelf refreshLiveLocationTimerState];
									[strongSelf showAlertTitle:@"" message:TGL(@"Toast.CouldNotUpdateLiveLocation", @"Live location sharing stopped due to an error")];
								   }];
		}
		return;
	}

	[manager stopUpdatingLocation];
	[self cancelLocationFetchTimeout];
	if (!fix)
		return;

	if ([mode isEqualToString:@"live"]) {
		self.locationMode = nil;
		[self chooseLiveLocationPeriodForLatitude:fix.coordinate.latitude
										 longitude:fix.coordinate.longitude
										   heading:TGLiveLocationHeadingFromCourse(fix.course)
										  accuracy:TGLiveLocationAccuracyFromFix(fix.horizontalAccuracy)];
		return;
	}

	if ([mode isEqualToString:@"venue"]) {
		[self sendVenueWithCachedLocation:fix];
		return;
	}

	if ([mode isEqualToString:@"venuePrefetch"]) {
		self.locationMode = nil;
		self.venuePrefetchedLocation = fix;
		Class geocoderClass = TGFrameworkClass(@"CoreLocation", @"CLGeocoder");
		if (!geocoderClass)
			return;
		CLGeocoder *geocoder = [[geocoderClass alloc] init];
		__weak typeof(self) weakSelf = self;
		[geocoder reverseGeocodeLocation:fix completionHandler:^(NSArray *placemarks, NSError *error) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf || error || !placemarks.count)
				return;
			CLPlacemark *place = placemarks[0];
			NSString *street = [[@[place.subThoroughfare ?: @"", place.thoroughfare ?: @""]
					componentsJoinedByString:@" "]
				stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			NSMutableArray *parts = [NSMutableArray array];
			if (street.length)
				[parts addObject:street];
			if (place.locality.length)
				[parts addObject:place.locality];
			if (parts.count)
				strongSelf.venueGeocodedAddress = [parts componentsJoinedByString:@", "];
		}];
		return;
	}

	self.locationMode = nil;
	[[TGClient shared] sendLocation:fix.coordinate.latitude
						  longitude:fix.coordinate.longitude
							 toChat:self.chatId
							options:[self sendOptionsDictionary]];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
	[manager stopUpdatingLocation];
	[self cancelLocationFetchTimeout];
	if (![error.domain isEqualToString:kCLErrorDomain] || error.code != kCLErrorDenied)
		return;
	if ([self.locationMode isEqualToString:@"tracking"] && self.liveLocationMessageId)
		[self stopExpiredLiveLocationTracking];
	else if (self.locationMode.length)
		self.locationMode = nil;
	[self showAlertTitle:@"" message:TGL(@"AccessDenied.Location", @"Telegram needs access to your location. Please go to Settings > Privacy > Location and set Telegram to ON.")];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
	if (status == kCLAuthorizationStatusNotDetermined)
		return;
	if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
		if (!self.locationMode.length)
			return;
		[self cancelLocationFetchTimeout];
		if ([self.locationMode isEqualToString:@"tracking"] && self.liveLocationMessageId)
			[self stopExpiredLiveLocationTracking];
		else
			self.locationMode = nil;
		[self showAlertTitle:@"" message:TGL(@"AccessDenied.Location", @"Telegram needs access to your location. Please go to Settings > Privacy > Location and set Telegram to ON.")];
		return;
	}
	if ([self.locationMode isEqualToString:@"tracking"]) {
		if (status == kCLAuthorizationStatusAuthorizedAlways)
			TGSetAllowsBackgroundLocationUpdates(manager, YES);
		return;
	}
	if (self.locationMode.length) {
		[manager startUpdatingLocation];
		[self scheduleLocationFetchTimeout];
	}
}

- (void)pickContact {
	ABPeoplePickerNavigationController *picker =
		[[ABPeoplePickerNavigationController alloc] init];
	picker.peoplePickerDelegate = self;
	picker.displayedProperties = @[ @(kABPersonPhoneProperty) ];
	[self presentViewController:picker animated:YES completion:nil];
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)picker
	  shouldContinueAfterSelectingPerson:(ABRecordRef)person
								 property:(ABPropertyID)property
							   identifier:(ABMultiValueIdentifier)identifier {
	if (property != kABPersonPhoneProperty) {
		[picker dismissViewControllerAnimated:YES completion:nil];
		return NO;
	}

	NSString *firstName = (__bridge_transfer NSString *)
		ABRecordCopyValue(person, kABPersonFirstNameProperty);
	NSString *lastName = (__bridge_transfer NSString *)
		ABRecordCopyValue(person, kABPersonLastNameProperty);
	if (!firstName.length && !lastName.length)
		firstName = (__bridge_transfer NSString *)ABRecordCopyCompositeName(person);

	ABMultiValueRef phones = ABRecordCopyValue(person, kABPersonPhoneProperty);
	CFIndex index = ABMultiValueGetIndexForIdentifier(phones, identifier);
	NSString *phone = index >= 0
		? (__bridge_transfer NSString *)ABMultiValueCopyValueAtIndex(phones, index)
		: nil;
	if (phones)
		CFRelease(phones);

	NSString *vcard = @"";
	if (person) {
		NSArray *people = @[ (__bridge id)person ];
		CFDataRef vcardData = ABPersonCreateVCardRepresentationWithPeople((__bridge CFArrayRef)people);
		if (vcardData) {
			NSString *vcardText = [[NSString alloc] initWithData:(__bridge NSData *)vcardData
														 encoding:NSUTF8StringEncoding];
			if (vcardText.length)
				vcard = vcardText;
			CFRelease(vcardData);
		}
	}

	[picker dismissViewControllerAnimated:YES completion:nil];
	if (phone.length)
		[[TGClient shared] sendContactFirstName:firstName
										lastName:lastName
										   phone:phone
										   vcard:vcard
										  userId:0
										  toChat:self.chatId
										 options:[self sendOptionsDictionary]];
	return NO;
}

- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)picker {
	[picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker
	didFinishPickingMediaWithInfo:(NSDictionary *)info {
	[picker dismissViewControllerAnimated:YES completion:nil];

	NSURL *movie = info[UIImagePickerControllerMediaURL];
	if (self.attachMode.length) {
		[self handleAttachPickOfMovie:movie.path
								image:info[UIImagePickerControllerOriginalImage]
							 assetURL:info[UIImagePickerControllerReferenceURL]];
		return;
	}
	if (movie) {
		AVURLAsset *source = [TGAVClass(AVURLAsset) URLAssetWithURL:movie options:nil];
		AVAssetTrack *track = [[source tracksWithMediaType:TGAVString(AVMediaTypeVideo)] firstObject];
		CGSize natural = CGSizeApplyAffineTransform(track.naturalSize, track.preferredTransform);
		[self presentSendPreviewForImage:nil
								videoPath:movie.path
							videoDuration:CMTimeGetSeconds(source.duration)
								videoSize:CGSizeMake(fabs(natural.width), fabs(natural.height))];
		return;
	}

	UIImage *image = info[UIImagePickerControllerOriginalImage];
	if (!image)
		return;

	[self presentSendPreviewForImage:image videoPath:nil videoDuration:0 videoSize:CGSizeZero];
}

- (void)presentSendPreviewForImage:(UIImage *)image
						  videoPath:(NSString *)videoPath
					  videoDuration:(NSTimeInterval)videoDuration
						  videoSize:(CGSize)videoSize {
	BOOL wantedOnce = self.sendMediaOnce;
	NSInteger wantedTimer = self.pendingSelfDestructSeconds;
	self.sendMediaOnce = NO;
	self.pendingSelfDestructSeconds = 0;

	NSString *typed = [self.input.text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (typed.length)
		self.input.text = @"";

	TGMediaSendPreviewViewController *preview = [[TGMediaSendPreviewViewController alloc] init];
	preview.image = image;
	preview.videoPath = videoPath;
	preview.videoDuration = videoDuration;
	preview.videoSize = videoSize;
	preview.allowsSendOnce = [self allowsViewOnceMedia];
	preview.initialSendOnce = wantedOnce && preview.allowsSendOnce;
	preview.initialCaption = typed;

	__weak typeof(self) weakSelf = self;
	preview.onSend = ^(NSString *caption, BOOL sendOnce, BOOL spoiler, BOOL silent) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf || strongSelf.postingBlocked)
			return;
		if ([strongSelf blockSendForSlowMode])
			return;
		NSInteger destruct = sendOnce ? kSelfDestructViewOnce : wantedTimer;
		NSMutableDictionary *sendOptions = [([strongSelf sendOptionsDictionary] ?: @{}) mutableCopy];
		if (silent)
			sendOptions[@"silent"] = @YES;
		if (sendOptions.count == 0)
			sendOptions = nil;
		if (videoPath.length) {
			[[TGClient shared] sendChatAction:@"uploadingVideo" toChat:strongSelf.chatId thread:strongSelf.threadId];
			[[TGClient shared] sendVideoAtPath:videoPath
										toChat:strongSelf.chatId
										thread:strongSelf.threadId
						   directMessagesTopic:strongSelf.directMessagesTopicId
									savedTopic:strongSelf.savedTopicId
									   replyTo:strongSelf.replyToId
									   caption:caption
									  duration:(NSInteger)videoDuration
										 width:(NSInteger)videoSize.width
										height:(NSInteger)videoSize.height
									   spoiler:spoiler
						   selfDestructSeconds:destruct
									   options:sendOptions];
			[strongSelf clearComposeState];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kDeferredActionDelay * NSEC_PER_SEC)),
				dispatch_get_main_queue(), ^{
					[[TGClient shared] sendChatAction:@"cancel" toChat:strongSelf.chatId thread:strongSelf.threadId];
				});
			return;
		}
		NSString *path = [strongSelf stageImageForSending:image];
		if (!path)
			return;
		[[TGClient shared] sendChatAction:@"uploadingPhoto" toChat:strongSelf.chatId thread:strongSelf.threadId];
		[[TGClient shared] sendPhotoAtPath:path
									toChat:strongSelf.chatId
									thread:strongSelf.threadId
					   directMessagesTopic:strongSelf.directMessagesTopicId
								savedTopic:strongSelf.savedTopicId
								   replyTo:strongSelf.replyToId
								   caption:caption
								   spoiler:spoiler
					   selfDestructSeconds:destruct
								   options:sendOptions];
		[strongSelf clearComposeState];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kDeferredActionDelay * NSEC_PER_SEC)),
			dispatch_get_main_queue(), ^{
				[[TGClient shared] sendChatAction:@"cancel" toChat:strongSelf.chatId thread:strongSelf.threadId];
				[strongSelf reload];
			});
	};
	if (videoPath.length) {
		preview.onCancel = ^{
			[[NSFileManager defaultManager] removeItemAtPath:videoPath error:nil];
		};
	}
	[self.navigationController pushViewController:preview animated:YES];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	self.attachMode = nil;
	[picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)finishSendingDocumentAtPath:(NSString *)path {
	if ([self blockSendForSlowMode])
		return;
	[[TGClient shared] sendChatAction:@"uploadingDocument" toChat:self.chatId thread:self.threadId];
	[[TGClient shared] sendDocumentAtPath:path toChat:self.chatId
								   thread:self.threadId
					  directMessagesTopic:self.directMessagesTopicId
							   savedTopic:self.savedTopicId
								  replyTo:self.replyToId
								  caption:@""
								  options:[self sendOptionsDictionary]];
	[self clearComposeState];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kDeferredActionDelay * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			[[TGClient shared] sendChatAction:@"cancel" toChat:self.chatId thread:self.threadId];
			[self reload];
		});
}

- (void)sendOriginalAssetAsDocumentAtURL:(NSURL *)assetURL fallbackImage:(UIImage *)fallbackImage {
	ALAssetsLibrary *library = [[TGALClass(ALAssetsLibrary) alloc] init];
	__weak typeof(self) weakSelf = self;
	void (^sendFallback)(void) = ^{
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSString *path = [strongSelf stageImageForSending:fallbackImage];
		if (!path.length)
			return;
		[strongSelf finishSendingDocumentAtPath:path];
	};
	[library assetForURL:assetURL resultBlock:^(ALAsset *asset) {
		if (!asset) {
			dispatch_async(dispatch_get_main_queue(), sendFallback);
			return;
		}
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			NSString *path = TGStageOriginalAssetAsDocument(asset);
			dispatch_async(dispatch_get_main_queue(), ^{
				TGChatViewController *strongSelf = weakSelf;
				if (!strongSelf)
					return;
				if (!path.length) {
					sendFallback();
					return;
				}
				[strongSelf finishSendingDocumentAtPath:path];
			});
		});
	} failureBlock:^(NSError *error) {
		dispatch_async(dispatch_get_main_queue(), sendFallback);
	}];
}

- (void)handleAttachPickOfMovie:(NSString *)moviePath image:(UIImage *)image assetURL:(NSURL *)assetURL {
	NSString *mode = self.attachMode;
	self.attachMode = nil;
	if (self.postingBlocked)
		return;
	if ([self blockSendForSlowMode])
		return;

	if ([mode isEqualToString:@"animation"]) {
		if (!moviePath.length) {
			[self showAlertTitle:@"" message:TGL(@"Chat.AGIFIsMadeFromA", @"A GIF is made from a video.")];
			return;
		}
		AVURLAsset *animationSource = [TGAVClass(AVURLAsset)
			URLAssetWithURL:[NSURL fileURLWithPath:moviePath]
					options:nil];
		AVAssetTrack *animationTrack = [[animationSource tracksWithMediaType:TGAVString(AVMediaTypeVideo)]
			firstObject];
		CGSize animationSize = CGSizeApplyAffineTransform(animationTrack.naturalSize,
			animationTrack.preferredTransform);
		[[TGClient shared] sendAnimationAtPath:moviePath toChat:self.chatId
										thread:self.threadId
						   directMessagesTopic:self.directMessagesTopicId
									savedTopic:self.savedTopicId
									   replyTo:self.replyToId
									   caption:@""
									  duration:(NSInteger)CMTimeGetSeconds(animationSource.duration)
										 width:(NSInteger)fabs(animationSize.width)
										height:(NSInteger)fabs(animationSize.height)
									   options:[self sendOptionsDictionary]];
		[self clearComposeState];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kDeferredActionDelay * NSEC_PER_SEC)),
			dispatch_get_main_queue(), ^{ [self reload]; });
		return;
	}

	if ([mode isEqualToString:@"document"]) {
		if (moviePath.length) {
			[self finishSendingDocumentAtPath:moviePath];
			return;
		}
		if (assetURL) {
			[self sendOriginalAssetAsDocumentAtURL:assetURL fallbackImage:image];
			return;
		}
		NSString *path = [self stageImageForSending:image];
		if (!path.length)
			return;
		[self finishSendingDocumentAtPath:path];
		return;
	}
}

- (void)pickPhotoAlbum {
	if (self.postingBlocked)
		return;
	if (![TGAssetPicker available]) {
		[self showAlertTitle:@""
					 message:TGL(@"AccessDenied.PhotosAndVideos", @"Telegram needs access to your photo library to send photos and videos.\n\nPlease go to Settings > Privacy > Photos and set Telegram to ON.")];
		return;
	}

	TGAssetPicker *picker = [[TGAssetPicker alloc] init];
	picker.selectionLimit = kAlbumSelectionLimit;
	__weak typeof(self) weakSelf = self;
	picker.onCancelled = ^{
		TGChatViewController *strongSelf = weakSelf;
		[strongSelf dismissViewControllerAnimated:YES completion:nil];
	};
	picker.onPicked = ^(NSArray *paths, BOOL spoiler) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf dismissViewControllerAnimated:YES completion:nil];
		[strongSelf sendPickedPhotos:paths spoiler:spoiler];
	};
	[self presentViewController:picker animated:YES completion:nil];
}

- (void)sendPickedPhotos:(NSArray *)paths spoiler:(BOOL)spoiler {
	if (self.postingBlocked)
		return;
	if ([self blockSendForSlowMode])
		return;
	if (!paths.count) {
		return;
	}
	if (self.composeMode == TGComposeModeEdit) {
		[TGSnackbar showInView:self.view
						   text:TGL(@"Toast.CantAttachWhileEditing", @"Finish or cancel your edit before attaching media")
						seconds:3
					   onCommit:nil];
		return;
	}

	NSString *caption = @"";
	NSString *typed = [self.input.text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (typed.length) {
		caption = typed;
		self.input.text = @"";
	}
	NSDictionary *sendOptions = [self sendOptionsDictionary];
	int64_t replyToId = self.replyToId;
	[self clearComposeState];

	if (paths.count == 1) {
		[[TGClient shared] sendChatAction:@"uploadingPhoto" toChat:self.chatId thread:self.threadId];
		[[TGClient shared] sendPhotoAtPath:[paths objectAtIndex:0]
									toChat:self.chatId
									thread:self.threadId
					   directMessagesTopic:self.directMessagesTopicId
								savedTopic:self.savedTopicId
								   replyTo:replyToId
								   caption:caption
								   spoiler:spoiler
					   selfDestructSeconds:[self mediaSelfDestruct]
								   options:sendOptions];
		[self clearMediaSelfDestruct];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kDeferredActionDelay * NSEC_PER_SEC)),
			dispatch_get_main_queue(), ^{
				[[TGClient shared] sendChatAction:@"cancel" toChat:self.chatId thread:self.threadId];
				[self reload];
			});
		return;
	}

	NSInteger albumSelfDestruct = [self mediaSelfDestruct];
	[self clearMediaSelfDestruct];
	[self sendAlbumBatch:paths caption:caption spoiler:spoiler
		selfDestructSeconds:albumSelfDestruct replyTo:replyToId options:sendOptions];
}

- (void)sendAlbumBatch:(NSArray *)paths caption:(NSString *)caption spoiler:(BOOL)spoiler selfDestructSeconds:(NSInteger)selfDestructSeconds replyTo:(int64_t)replyToId options:(NSDictionary *)options {
	if (!paths.count)
		return;

	NSInteger take = MIN((NSUInteger)kAlbumBatchLimit, paths.count);
	NSArray *batch = [paths subarrayWithRange:NSMakeRange(0, take)];
	NSArray *rest = [paths subarrayWithRange:NSMakeRange(take, paths.count - take)];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] sendChatAction:@"uploadingPhoto" toChat:self.chatId thread:self.threadId];
	[[TGClient shared] sendPhotoAlbumAtPaths:batch
									  toChat:self.chatId
									  thread:self.threadId
						 directMessagesTopic:self.directMessagesTopicId
								  savedTopic:self.savedTopicId
									 replyTo:replyToId
									 caption:(caption ?: @"")
		spoiler:spoiler
						 selfDestructSeconds:selfDestructSeconds
									 options:options
								  completion:^(NSInteger sent) {
									  TGChatViewController *strongSelf = weakSelf;
									  if (!strongSelf)
										  return;
									  if (!sent) {
										  [[TGClient shared] sendChatAction:@"cancel" toChat:strongSelf.chatId thread:strongSelf.threadId];
										  [TGSnackbar showInView:strongSelf.view
															text:TGL(@"Toast.CouldNotSendPhotos", @"Could not send the photos")
														 seconds:3
														onCommit:nil];
										  [strongSelf reload];
										  return;
									  }
									  if (rest.count) {
										  [strongSelf sendAlbumBatch:rest caption:@"" spoiler:spoiler
												 selfDestructSeconds:selfDestructSeconds
															 replyTo:0
															 options:options];
										  return;
									  }
									  [[TGClient shared] sendChatAction:@"cancel" toChat:strongSelf.chatId thread:strongSelf.threadId];
									  [strongSelf reload];
								  }];
}

- (void)chooseLiveLocationPeriodForLatitude:(double)latitude
								   longitude:(double)longitude
									 heading:(NSInteger)heading
									accuracy:(double)accuracy {
	NSArray *actions = @[
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Map.LiveLocationFor15Minutes", @"for 15 minutes") action:@"900"],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Map.LiveLocationFor1Hour", @"for 1 hour") action:@"3600"],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Map.LiveLocationFor8Hours", @"for 8 hours") action:@"28800"],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Common.Cancel", @"Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel],
	];

	__weak typeof(self) weakSelf = self;
	TGActionSheet *sheet = [[TGActionSheet alloc]
		initWithTitle:TGL(@"Map.ShareLiveLocation", @"Share My Live Location for...")
			  actions:actions
		  actionBlock:^(__unused id target, NSString *action) {
			  TGChatViewController *strongSelf = weakSelf;
			  if (!strongSelf || [action isEqualToString:@"cancel"])
				  return;
			  [strongSelf startLiveLocationWithLatitude:latitude
											   longitude:longitude
												 heading:heading
												accuracy:accuracy
												  period:[action integerValue]];
		  }
			   target:self];
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)startLiveLocationWithLatitude:(double)latitude
							 longitude:(double)longitude
							   heading:(NSInteger)heading
							  accuracy:(double)accuracy
								period:(NSInteger)period {
	NSString *durationText;
	switch (period) {
		case 900:
			durationText = TGL(@"Map.LiveLocationFor15Minutes", @"for 15 minutes");
			break;
		case 28800:
			durationText = TGL(@"Map.LiveLocationFor8Hours", @"for 8 hours");
			break;
		default:
			durationText = TGL(@"Map.LiveLocationFor1Hour", @"for 1 hour");
			break;
	}
	NSString *sharingText = [NSString stringWithFormat:TGL(@"Chat.SharingYourLocationFormat", @"Sharing your location %@"), durationText];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] sendLiveLocationWithLatitude:latitude
										   longitude:longitude
											 heading:heading
											accuracy:accuracy
											  period:period
											  toChat:self.chatId
											 replyTo:self.replyToId
										  completion:^(int64_t messageId) {
											  TGChatViewController *strongSelf = weakSelf;
											  if (!strongSelf)
												  return;
											  if (!messageId) {
												  [TGSnackbar showInView:strongSelf.view
																	 text:TGL(@"Toast.CouldNotShareLiveLocation", @"Could not share your live location")
																  seconds:3
																 onCommit:nil];
												  return;
											  }
											  strongSelf.liveLocationMessageId = messageId;
											  strongSelf.locationMode = @"tracking";
											  strongSelf.liveLocationFailureCount = 0;
											  strongSelf.locationManager.desiredAccuracy = TGHundredMeters();
											  strongSelf.locationManager.distanceFilter = 50;
											  Class managerClass = [strongSelf.locationManager class];
											  CLAuthorizationStatus authStatus = [managerClass respondsToSelector:@selector(authorizationStatus)]
												  ? [managerClass authorizationStatus]
												  : kCLAuthorizationStatusAuthorizedAlways;
											  if (authStatus == kCLAuthorizationStatusAuthorizedAlways)
												  TGSetAllowsBackgroundLocationUpdates(strongSelf.locationManager, YES);
											  else if ([strongSelf.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)])
												  [strongSelf.locationManager requestAlwaysAuthorization];
											  [TGClient shared].hasActiveLiveLocationShare = YES;
											  [strongSelf.locationManager startUpdatingLocation];
											  [strongSelf refreshLiveLocationTimerState];
											  [TGSnackbar showInView:strongSelf.view text:sharingText seconds:3 onCommit:nil];
											  [strongSelf reload];
										  }];
}

@end

#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+Messages.h"
#import "TGFileDownloadService.h"
#import "TGUserDisplayNameStore.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGVoiceRecorder.h"
#import "TGStickerSuggestionStrip.h"
#import "TGMusicPlayer.h"
#import "TGLazyFramework.h"
#import "TGVideoNoteRingResume.h"

@implementation TGChatViewController (VoiceVideo)

#pragma mark - voice

- (void)inputChanged {
	[self updateComposerButtons];
	[self updateStickerSuggestions];
	[self updateMentionSuggestions];
	if (self.input.text.length > 0) {
		[self sendTypingAction];
		return;
	}
	if (self.lastTypingSent) {
		self.lastTypingSent = nil;
		[[TGClient shared] sendChatAction:@"cancel" toChat:self.chatId thread:self.threadId];
	}
}

- (void)updateStickerSuggestions {
	NSString *text = self.input.text ?: @"";
	if (self.stickerSuggestions == nil) {
		if (self.inputBar == nil)
			return;
		BOOL worthBuilding = NO;
		for (NSInteger i = 0; i < text.length && !worthBuilding; i++)
			worthBuilding = ([text characterAtIndex:i] > 0x2000);
		if (!worthBuilding)
			return;
		[self buildStickerSuggestions];
	}
	[self.stickerSuggestions updateForText:text];
}

- (void)buildStickerSuggestions {
	CGRect b = self.view.bounds;
	CGFloat height = [TGStickerSuggestionStrip preferredHeight];
	TGStickerSuggestionStrip *strip = [[TGStickerSuggestionStrip alloc]
		initWithFrame:CGRectMake(0, CGRectGetMinY(self.inputBar.frame) - height,
						  b.size.width, height)];
	strip.autoresizingMask = UIViewAutoresizingFlexibleWidth |
		UIViewAutoresizingFlexibleTopMargin;

	__weak typeof(self) weakSelf = self;
	strip.onStickerPicked = ^(NSDictionary *sticker) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf || strongSelf.postingBlocked)
			return;
		NSNumber *fileId = sticker[@"fileId"];
		if (![fileId isKindOfClass:NSNumber.class])
			return;
		if ([strongSelf blockSendForSlowMode])
			return;
		[[TGClient shared] sendStickerWithFileId:fileId.longLongValue
										  toChat:strongSelf.chatId
										  thread:strongSelf.threadId
									  savedTopic:strongSelf.savedTopicId
										 replyTo:strongSelf.replyToId
										 options:[strongSelf sendOptionsDictionary]];
		strongSelf.input.text = @"";
		[strongSelf clearComposeState];
	};
	strip.onVisibilityChanged = ^(__unused BOOL visible) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf layoutChatStackAnimated:NO duration:0 curve:UIViewAnimationCurveEaseInOut];
	};

	[self.view addSubview:strip];
	self.stickerSuggestions = strip;
}

- (void)updateComposerButtons {
	BOOL hasText = self.input.text.length > 0;
	if (self.sendButton.hidden == hasText) {
		UIButton *arriving = hasText ? self.sendButton : self.micButton;
		UIButton *leaving = hasText ? self.micButton : self.sendButton;
		arriving.alpha = 0.0f;
		arriving.hidden = NO;
		[UIView animateWithDuration:0.15 delay:0.0
			options:UIViewAnimationOptionBeginFromCurrentState
			animations:^{
				arriving.alpha = 1.0f;
				leaving.alpha = 0.0f;
			} completion:^(BOOL finished) {
				if (!finished)
					return;
				leaving.hidden = YES;
				leaving.alpha = 1.0f;
			}];
	}
}

- (void)sendTypingAction {
	if (self.postingBlocked || self.editingId != 0)
		return;
	NSDate *now = [NSDate date];
	if (self.lastTypingSent &&
		[now timeIntervalSinceDate:self.lastTypingSent] < 4.0)
		return;
	self.lastTypingSent = now;
	[[TGClient shared] sendChatAction:@"typing" toChat:self.chatId thread:self.threadId];
}

- (void)showRecordPanel {
	CGRect bar = CGRectMake(0, CGRectGetMaxY(self.inputBar.frame) - kInputHeight,
		self.inputBar.frame.size.width, kInputHeight);
	if (!self.recordPanel) {
		self.recordPanel = [[UIView alloc] initWithFrame:bar];
		[self paintBannerGround:self.recordPanel];
		self.recordPanel.autoresizingMask = UIViewAutoresizingFlexibleWidth |
			UIViewAutoresizingFlexibleTopMargin;

		UIView *hair = [[UIView alloc] initWithFrame:CGRectMake(0, 0, bar.size.width, 1)];
		hair.backgroundColor = [[TGTheme shared] separatorColour];
		hair.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[self.recordPanel addSubview:hair];

		self.recordDot = [[UIView alloc] initWithFrame:
				CGRectMake(14, (kInputHeight - 9) / 2, 9, 9)];
		UIColor *dotColour = [UIColor colorWithRed:0.878f green:0.329f blue:0.341f alpha:1.0f];
		self.recordDot.backgroundColor = dotColour;
		self.recordDot.layer.cornerRadius = 4.5f;
		[self.recordPanel addSubview:self.recordDot];

		self.recordClock = [[UILabel alloc] initWithFrame:
				CGRectMake(32, (kInputHeight - 20) / 2, 62, 20)];
		self.recordClock.font = [UIFont systemFontOfSize:16];
		UIColor *clockColour = [UIColor colorWithRed:0.557f green:0.584f blue:0.608f alpha:1.0f];
		self.recordClock.textColor = clockColour;
		self.recordClock.backgroundColor = [UIColor clearColor];
		[self.recordPanel addSubview:self.recordClock];

		UILabel *cancel = [[UILabel alloc] initWithFrame:
				CGRectMake(100, (kInputHeight - 20) / 2, bar.size.width - 180, 20)];
		cancel.text = TGL(@"Conversation.SlideToCancel", @"‹ Slide to cancel");
		cancel.font = [UIFont systemFontOfSize:15];
		cancel.textColor = [UIColor colorWithRed:0.565f green:0.592f
											blue:0.616f
										   alpha:1.0f];
		cancel.backgroundColor = [UIColor clearColor];
		cancel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[self.recordPanel addSubview:cancel];

		CGFloat halo = kInputHeight + 12, disc = 44;
		UIView *ring = [[UIView alloc] initWithFrame:
				CGRectMake(bar.size.width - halo + 4, (kInputHeight - halo) / 2, halo, halo)];
		ring.backgroundColor = [[TGTheme shared] accentColour];
		ring.alpha = 0.25f;
		ring.layer.cornerRadius = halo / 2;
		ring.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[self.recordPanel addSubview:ring];

		CGRect buttonFrame = CGRectMake(CGRectGetMidX(ring.frame) - disc / 2,
			(kInputHeight - disc) / 2, disc, disc);
		UIImageView *button = [[UIImageView alloc] initWithFrame:buttonFrame];
		UIColor *buttonColour = [UIColor colorWithRed:0.369f green:0.655f blue:0.871f alpha:1.0f];
		button.backgroundColor = buttonColour;
		button.layer.cornerRadius = disc / 2;
		button.image = [TGIcons microphoneOfSide:disc colour:[UIColor whiteColor]];
		button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[self.recordPanel addSubview:button];
	}

	self.recordPanel.frame = bar;
	self.recordClock.text = @"0:00,0";
	self.recordDot.alpha = 1.0f;
	[self.view addSubview:self.recordPanel];
}

- (void)hideRecordPanel {
	[self.recordPanel removeFromSuperview];
}

- (void)recordStart {
	TGVoiceRecorder *recorder = [TGVoiceRecorder shared];
	if ([recorder microphoneAccessDenied]) {
		[self showAlertTitle:@"" message:TGL(@"AccessDenied.Microphone", @"Telegram needs access to your microphone. Please go to Settings > Privacy > Microphone and set Telegram to ON.")];
		return;
	}
	BOOL wasUndetermined = [recorder microphoneAccessUndetermined];
	recorder.delegate = self;
	if (![recorder start]) {
		if (!wasUndetermined)
			[self showRecordingFailure];
		return;
	}
	[self showRecordPanel];
	[[TGClient shared] sendChatAction:@"recordingVoice" toChat:self.chatId
							   thread:self.threadId];
	self.recordTimer = [NSTimer
		scheduledTimerWithTimeInterval:0.5
								target:self
							  selector:@selector(recordTick)
							  userInfo:nil
							   repeats:YES];
}

- (void)voiceRecorder:(TGVoiceRecorder *)recorder didFailWithError:(NSError *)error {
	[self.recordTimer invalidate];
	self.recordTimer = nil;
	[self hideRecordPanel];
	self.lastTypingSent = nil;
	[[TGClient shared] sendChatAction:@"cancel" toChat:self.chatId thread:self.threadId];
	[self clearComposeState];

	if ([error.domain isEqualToString:TGVoiceRecorderErrorDomain] &&
		error.code == TGVoiceRecorderErrorMicrophoneAccessDenied)
		[self showAlertTitle:@"" message:TGL(@"AccessDenied.Microphone", @"Telegram needs access to your microphone. Please go to Settings > Privacy > Microphone and set Telegram to ON.")];
}

- (void)voiceRecorderWasInterrupted:(TGVoiceRecorder *)recorder {
	[self recordCancel];
}

- (void)recordTick {
	NSTimeInterval d = [TGVoiceRecorder shared].duration;

	self.recordClock.text = [NSString stringWithFormat:@"%ld:%02ld,%ld",
		(long)(d / 60), (long)((NSInteger)d % 60), (long)((NSInteger)(d * 10) % 10)];
	self.recordDot.alpha = (self.recordDot.alpha < 1.0f) ? 1.0f : 0.25f;
	NSDate *now = [NSDate date];
	if (self.lastTypingSent &&
		[now timeIntervalSinceDate:self.lastTypingSent] < 4.0)
		return;
	self.lastTypingSent = now;
	[[TGClient shared] sendChatAction:@"recordingVoice" toChat:self.chatId
							   thread:self.threadId];
}

- (void)recordFinish {
	[self.recordTimer invalidate];
	self.recordTimer = nil;
	[self hideRecordPanel];
	self.lastTypingSent = nil;
	[[TGClient shared] sendChatAction:@"uploadingVoice" toChat:self.chatId
							   thread:self.threadId];

	__weak typeof(self) weakSelf = self;
	[[TGVoiceRecorder shared] stopWithCompletion:^(NSString *path, NSTimeInterval seconds, NSData *waveform) {
		TGChatViewController *strongSelf = weakSelf;
		[strongSelf clearComposeState];
		if (!strongSelf || strongSelf.postingBlocked) {
			if (path)
				[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
			return;
		}
		if ([strongSelf blockSendForSlowMode]) {
			if (path)
				[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
			return;
		}
		if (!path || seconds < 0.5) {
			if (path)
				[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
			return;
		}
		[[TGClient shared] sendVoiceAtPath:path
								  duration:(NSInteger)seconds
								  waveform:waveform
									toChat:strongSelf.chatId
									thread:strongSelf.threadId
								savedTopic:strongSelf.savedTopicId
								   options:[strongSelf sendOptionsDictionary]];
	}];
}

- (void)recordCancel {
	[self.recordTimer invalidate];
	self.recordTimer = nil;
	[self hideRecordPanel];
	[[TGVoiceRecorder shared] cancel];
	self.lastTypingSent = nil;
	[[TGClient shared] sendChatAction:@"cancel" toChat:self.chatId thread:self.threadId];
	[self clearComposeState];
}

#pragma mark - video notes

const NSInteger kVideoNoteOverlayTag = 0xF119;
const NSInteger kRoundNoteRimTag = 0xF11A;
const NSInteger kRoundNoteBadgeTag = 0xF11B;
const NSInteger kRoundNoteMuteTag = 0xF11C;

const CGFloat kRoundNoteRimInset = 2.5f;
const CGFloat kRoundNoteRingWidth = 4.0f;
const CGFloat kRoundNoteBadgeSide = 24.0f;

CGFloat TGRoundNoteRimWidth(void) {
	return 1.0f / [UIScreen mainScreen].scale;
}

UIColor *TGRoundNoteRimColour(void) {
	return [UIColor colorWithRed:0x7d / 255.0f green:0xb4 / 255.0f
							blue:0xe9 / 255.0f
						   alpha:0.4f];
}

UIImage *TGRoundNoteMuteBadge(void) {
	static UIImage *badge = nil;
	if (badge)
		return badge;

	CGFloat side = kRoundNoteBadgeSide;
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0.0f);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0 alpha:0.4f].CGColor);
	CGContextFillEllipseInRect(ctx, CGRectMake(0, 0, side, side));

	[[UIColor whiteColor] setFill];
	UIBezierPath *speaker = [UIBezierPath bezierPath];
	[speaker moveToPoint:CGPointMake(6.5f, 10.0f)];
	[speaker addLineToPoint:CGPointMake(9.5f, 10.0f)];
	[speaker addLineToPoint:CGPointMake(13.0f, 6.0f)];
	[speaker addLineToPoint:CGPointMake(13.0f, 18.0f)];
	[speaker addLineToPoint:CGPointMake(9.5f, 14.0f)];
	[speaker addLineToPoint:CGPointMake(6.5f, 14.0f)];
	[speaker closePath];
	[speaker fill];

	UIBezierPath *slash = [UIBezierPath bezierPath];
	slash.lineWidth = 1.5f;
	slash.lineCapStyle = kCGLineCapRound;
	[slash moveToPoint:CGPointMake(15.5f, 9.0f)];
	[slash addLineToPoint:CGPointMake(19.5f, 15.0f)];
	[slash moveToPoint:CGPointMake(19.5f, 9.0f)];
	[slash addLineToPoint:CGPointMake(15.5f, 15.0f)];
	[[UIColor whiteColor] setStroke];
	[slash stroke];

	badge = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return badge;
}

- (NSDictionary *)videoNoteTrackForMessage:(NSDictionary *)m {
	if (![m isKindOfClass:NSDictionary.class])
		return nil;
	NSString *sender = [m[@"outgoing"] boolValue]
		? TGL(@"DialogList.You", @"You")
		: [TGUserDisplayNameStore nameForUserId:[m[@"senderId"] longLongValue]];
	if (!sender.length)
		sender = self.chatTitle;
	NSString *fallback = TGL(@"VoiceOver.Chat.RecordModeVideoMessage", @"Video message");
	return @{
		TGMusicTrackMessageId : m[@"id"] ?: @(0),
		TGMusicTrackChatId : [NSNumber numberWithLongLong:self.chatId],
		TGMusicTrackFileId : m[@"docId"] ?: @(0),
		TGMusicTrackTitle : sender.length ? sender : fallback,
		TGMusicTrackPerformer : @"",
		TGMusicTrackFileName : m[@"docName"] ?: @"",
		TGMusicTrackDuration : m[@"duration"] ?: @(0),
		TGMusicTrackIsVoice : @YES,
		TGMusicTrackSender : sender.length ? sender : fallback,
		TGMusicTrackDate : m[@"date"] ?: @(0),
	};
}

- (void)rebuildVideoNotePlaylistAround:(int64_t)messageId {
	NSMutableArray *ids = [NSMutableArray array];
	for (NSDictionary *m in self.messages) {
		if (![m[@"kind"] isEqualToString:@"messageVideoNote"])
			continue;
		if (![m[@"id"] isKindOfClass:NSNumber.class])
			continue;
		[ids addObject:m[@"id"]];
	}
	[ids sortUsingSelector:@selector(compare:)];

	self.videoNotePlaylist = ids;
	self.videoNoteIndex = NSNotFound;
	for (NSInteger i = 0; i < ids.count; i++) {
		if ([ids[i] longLongValue] == messageId) {
			self.videoNoteIndex = (NSInteger)i;
			break;
		}
	}
	if (self.videoNoteIndex == NSNotFound) {
		self.videoNoteIndex = 0;
		self.videoNotePlaylist = @[ [NSNumber numberWithLongLong:messageId] ];
	}
	[[TGMusicPlayer shared] externalDidUpdatePosition:self.videoNoteIndex
												count:(NSInteger)self.videoNotePlaylist.count];
}

- (void)playVideoNoteAtPlaylistIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)self.videoNotePlaylist.count)
		return;
	int64_t messageId = [self.videoNotePlaylist[index] longLongValue];
	NSInteger row = [self rowForMessageId:messageId];
	if (row == NSNotFound)
		return;
	NSDictionary *m = [self messageAtRow:row];
	NSNumber *docId = m[@"docId"];
	if (![docId isKindOfClass:NSNumber.class])
		return;

	[self cancelPendingVideoNoteDownload];

	self.videoNoteIndex = index;
	long long fileId = [docId longLongValue];
	self.videoNoteDownloadingFileId = fileId;
	[self scrollRowIntoViewIfNeeded:row];

	__weak typeof(self) weakSelf = self;
	[TGFileDownloadService downloadFile:fileId completion:^(NSString *path) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (strongSelf.videoNoteDownloadingFileId == fileId)
			strongSelf.videoNoteDownloadingFileId = 0;
		if (!path.length)
			return;
		if ([strongSelf rowForMessageId:messageId] == NSNotFound)
			return;
		[strongSelf playVideoNoteAtPath:path row:[strongSelf rowForMessageId:messageId]];
	}];
}

- (void)cancelPendingVideoNoteDownload {
	if (self.videoNoteDownloadingFileId <= 0)
		return;
	[TGFileDownloadService cancelDownloadOfFile:self.videoNoteDownloadingFileId onlyIfPending:NO];
	self.videoNoteDownloadingFileId = 0;
}

- (void)scrollRowIntoViewIfNeeded:(NSInteger)row {
	NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:0];
	CGRect rect = [self.table rectForRowAtIndexPath:path];
	if (CGRectIntersectsRect(rect, self.table.bounds))
		return;
	[self.table scrollToRowAtIndexPath:path
					  atScrollPosition:UITableViewScrollPositionMiddle
							  animated:YES];
}

- (void)startVideoNoteTicker {
	[self.videoNoteTicker invalidate];
	self.videoNoteTicker = [NSTimer
		scheduledTimerWithTimeInterval:0.2
								target:self
							  selector:@selector(videoNoteTicked)
							  userInfo:nil
							   repeats:YES];
}

- (void)videoNoteTicked {
	AVPlayer *player = self.videoNotePlayer;
	if (!player) {
		[self.videoNoteTicker invalidate];
		self.videoNoteTicker = nil;
		return;
	}
	NSTimeInterval now = CMTimeGetSeconds(player.currentTime);
	if (isnan(now) || now < 0)
		now = 0;
	[[TGMusicPlayer shared] externalDidUpdateTime:now
										 duration:self.videoNoteLength
										  playing:(player.rate > 0.01f)];
}

- (void)playVideoNoteAtPath:(NSString *)path row:(NSInteger)row {
	[self stopVideoNoteKeepingBar:YES];

	CGRect rect = [self.table rectForRowAtIndexPath:
			[NSIndexPath indexPathForRow:row inSection:0]];
	CGRect inView = [self.table convertRect:rect toView:self.view];
	CGFloat side = MIN(inView.size.height - 20, inView.size.width);
	NSDictionary *m = [self messageAtRow:row];
	CGFloat x = [m[@"outgoing"] boolValue]
		? CGRectGetMaxX(inView) - side - 8
		: 8;

	UIView *plate = [[UIView alloc] initWithFrame:
			CGRectMake(x, CGRectGetMinY(inView) + 3, side, side)];
	plate.backgroundColor = [UIColor whiteColor];
	plate.layer.cornerRadius = side / 2;
	plate.layer.borderWidth = TGRoundNoteRimWidth();
	plate.layer.borderColor = TGRoundNoteRimColour().CGColor;
	plate.tag = kVideoNoteOverlayTag;

	CGFloat inner = side - kRoundNoteRimInset * 2;
	UIView *circle = [[UIView alloc] initWithFrame:
			CGRectMake(kRoundNoteRimInset, kRoundNoteRimInset, inner, inner)];
	circle.layer.cornerRadius = inner / 2;
	circle.clipsToBounds = YES;
	circle.backgroundColor = [UIColor blackColor];
	[plate addSubview:circle];

	AVPlayer *player = [TGAVClass(AVPlayer) playerWithURL:[NSURL fileURLWithPath:path]];
	player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
	AVPlayerLayer *layer = [TGAVClass(AVPlayerLayer) playerLayerWithPlayer:player];
	layer.videoGravity = TGAVString(AVLayerVideoGravityResizeAspectFill);
	layer.frame = circle.bounds;
	[circle.layer addSublayer:layer];

	self.videoNotePlayer = player;
	self.videoNoteLayer = layer;
	self.videoNoteMuted = !self.videoNoteAutoUnmute;
	self.videoNoteAutoUnmute = NO;
	self.videoNoteLength = MAX(1.0, (NSTimeInterval)[m[@"duration"] doubleValue]);
	[self applyVideoNoteVolume:self.videoNoteMuted ? 0.0f : 1.0f];

	CAShapeLayer *ring = [CAShapeLayer layer];
	ring.frame = circle.frame;
	CGRect ringRect = CGRectInset(circle.bounds, kRoundNoteRingWidth / 2, kRoundNoteRingWidth / 2);
	ring.path = [UIBezierPath bezierPathWithOvalInRect:ringRect].CGPath;
	ring.fillColor = [UIColor clearColor].CGColor;
	ring.strokeColor = [UIColor colorWithWhite:1.0f alpha:0.6f].CGColor;
	ring.lineWidth = kRoundNoteRingWidth;
	ring.lineCap = kCALineCapRound;
	ring.strokeEnd = 0.0f;
	ring.transform = CATransform3DMakeRotation(-M_PI_2, 0, 0, 1);
	[plate.layer addSublayer:ring];
	self.videoNoteRing = ring;

	self.videoNoteMute = [[UIImageView alloc] initWithImage:TGRoundNoteMuteBadge()];
	self.videoNoteMute.frame = CGRectMake(
		floorf(CGRectGetMidX(circle.bounds) - kRoundNoteBadgeSide / 2),
		CGRectGetMaxY(circle.bounds) - kRoundNoteBadgeSide - 8,
		kRoundNoteBadgeSide, kRoundNoteBadgeSide);
	self.videoNoteMute.hidden = !self.videoNoteMuted;
	[circle addSubview:self.videoNoteMute];

	[plate addGestureRecognizer:[[UITapGestureRecognizer alloc]
									initWithTarget:self
											action:@selector(videoNoteTapped)]];
	[self.view addSubview:plate];

	__weak typeof(self) weakSelf = self;
	self.videoNoteReachedEndObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGAVString(AVPlayerItemDidPlayToEndTimeNotification)
					object:player.currentItem
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf videoNoteReachedEnd:note];
				}];
	self.videoNoteInterruptionObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGAVString(AVAudioSessionInterruptionNotification)
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf videoNoteAudioSessionInterruptionDidChange:note];
				}];
	self.videoNoteMessageId = [m[@"id"] longLongValue];

	[[TGMusicPlayer shared] attachExternalTrack:[self videoNoteTrackForMessage:m]
									   delegate:self];
	[self rebuildVideoNotePlaylistAround:self.videoNoteMessageId];
	[self startVideoNoteTicker];

	[player play];
	player.rate = [TGMusicPlayer shared].voiceRate;
	[self startVideoNoteRing];
}

- (void)startVideoNoteRing {
	[self startVideoNoteRingFromFraction:0.0
								 duration:self.videoNoteLength / MAX(0.5f, [TGMusicPlayer shared].voiceRate)];
}

- (void)startVideoNoteRingResumingAtCurrentPosition {
	NSTimeInterval elapsed = CMTimeGetSeconds(self.videoNotePlayer.currentTime);
	TGVideoNoteRingResumeAnimation resume = TGVideoNoteRingResumeAnimationForPosition(
			elapsed, self.videoNoteLength, [TGMusicPlayer shared].voiceRate);
	[self startVideoNoteRingFromFraction:resume.fromFraction duration:resume.duration];
}

- (void)startVideoNoteRingFromFraction:(double)fromFraction duration:(NSTimeInterval)duration {
	CABasicAnimation *fill = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
	fill.fromValue = @(fromFraction);
	fill.toValue = @1.0f;
	fill.duration = duration;
	fill.timingFunction = [CAMediaTimingFunction
		functionWithName:kCAMediaTimingFunctionLinear];
	fill.fillMode = kCAFillModeForwards;
	fill.removedOnCompletion = NO;
	[self.videoNoteRing addAnimation:fill forKey:@"fill"];
}

- (void)pauseVideoNoteRing {
	CALayer *layer = self.videoNoteRing;
	if (!layer || layer.speed == 0.0f)
		return;
	CFTimeInterval pausedTime = [layer convertTime:CACurrentMediaTime() fromLayer:nil];
	layer.speed = 0.0f;
	layer.timeOffset = pausedTime;
}

- (void)resumeVideoNoteRing {
	CALayer *layer = self.videoNoteRing;
	if (!layer || layer.speed != 0.0f)
		return;
	CFTimeInterval pausedTime = layer.timeOffset;
	layer.speed = 1.0f;
	layer.timeOffset = 0.0;
	layer.beginTime = 0.0;
	CFTimeInterval timeSincePause = [layer convertTime:CACurrentMediaTime() fromLayer:nil] - pausedTime;
	layer.beginTime = timeSincePause;
}

- (void)videoNoteAudioSessionInterruptionDidChange:(NSNotification *)note {
	if (!self.videoNotePlayer)
		return;
	NSNumber *typeValue = note.userInfo[TGAVString(AVAudioSessionInterruptionTypeKey)];
	if (typeValue.unsignedIntegerValue == AVAudioSessionInterruptionTypeBegan) {
		[self.videoNotePlayer pause];
		[self pauseVideoNoteRing];
		return;
	}
	if (typeValue.unsignedIntegerValue != AVAudioSessionInterruptionTypeEnded)
		return;
	NSNumber *optionsValue = note.userInfo[TGAVString(AVAudioSessionInterruptionOptionKey)];
	if (optionsValue.unsignedIntegerValue & AVAudioSessionInterruptionOptionShouldResume) {
		[self.videoNotePlayer play];
		self.videoNotePlayer.rate = [TGMusicPlayer shared].voiceRate;
		[self resumeVideoNoteRing];
	}
}

- (void)applyVideoNoteVolume:(float)volume {
	AVPlayerItem *item = self.videoNotePlayer.currentItem;
	AVAssetTrack *track = [[item.asset tracksWithMediaType:TGAVString(AVMediaTypeAudio)] firstObject];
	if (!track)
		return;
	AVMutableAudioMixInputParameters *parameters =
		[TGAVClass(AVMutableAudioMixInputParameters) audioMixInputParametersWithTrack:track];
	[parameters setVolume:volume atTime:kCMTimeZero];
	AVMutableAudioMix *mix = [TGAVClass(AVMutableAudioMix) audioMix];
	mix.inputParameters = @[ parameters ];
	item.audioMix = mix;
}

- (void)videoNoteTapped {
	if (!self.videoNotePlayer)
		return;

	if (!self.videoNoteMuted) {
		[self stopVideoNote];
		return;
	}

	self.videoNoteMuted = NO;
	[self applyVideoNoteVolume:1.0f];

	UIImageView *badge = self.videoNoteMute;
	[badge.layer removeAllAnimations];
	[UIView animateWithDuration:0.3 animations:^{
		badge.transform = CGAffineTransformMakeScale(0.01f, 0.01f);
	} completion:nil];
	[UIView animateWithDuration:0.2 animations:^{
		badge.alpha = 0.0f;
	} completion:nil];

	[self.videoNotePlayer seekToTime:kCMTimeZero];
	[self.videoNotePlayer play];
	self.videoNotePlayer.rate = [TGMusicPlayer shared].voiceRate;
	[self startVideoNoteRing];
	[self videoNoteTicked];
}

- (void)videoNoteReachedEnd:(NSNotification *)note {
	if (!self.videoNotePlayer)
		return;
	if (!self.videoNoteMuted) {
		if (self.videoNoteIndex != NSNotFound &&
			self.videoNoteIndex + 1 < (NSInteger)self.videoNotePlaylist.count) {
			[self externalPlaybackNext];
			return;
		}
		[self stopVideoNote];
		return;
	}
	[self.videoNotePlayer seekToTime:kCMTimeZero];
	[self.videoNotePlayer play];
	self.videoNotePlayer.rate = [TGMusicPlayer shared].voiceRate;
	[self startVideoNoteRing];
}

- (void)stopVideoNote {
	[self stopVideoNoteKeepingBar:NO];
}

- (void)stopVideoNoteKeepingBar:(BOOL)keepBar {
	[self cancelPendingVideoNoteDownload];
	[self.videoNoteTicker invalidate];
	self.videoNoteTicker = nil;

	if (self.videoNotePlayer) {
		if (self.videoNoteReachedEndObserverToken) {
			[[NSNotificationCenter defaultCenter] removeObserver:self.videoNoteReachedEndObserverToken];
			self.videoNoteReachedEndObserverToken = nil;
		}
		if (self.videoNoteInterruptionObserverToken) {
			[[NSNotificationCenter defaultCenter] removeObserver:self.videoNoteInterruptionObserverToken];
			self.videoNoteInterruptionObserverToken = nil;
		}
		[self.videoNotePlayer pause];
		[self.videoNoteRing removeAnimationForKey:@"fill"];
		[[self.view viewWithTag:kVideoNoteOverlayTag] removeFromSuperview];
		self.videoNoteLayer = nil;
		self.videoNoteRing = nil;
		self.videoNoteMute = nil;
		self.videoNotePlayer = nil;
	}

	if (!keepBar) {
		self.videoNoteMessageId = 0;
		self.videoNotePlaylist = nil;
		self.videoNoteIndex = NSNotFound;
		[[TGMusicPlayer shared] detachExternal:self];
	}
}

@end

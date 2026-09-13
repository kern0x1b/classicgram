#import "TGMediaFullscreenControllerInternal.h"
#import "TGClient+Files.h"
#import "TGMusicPlayer.h"
#import "TGLazyFramework.h"
#import "TGMediaViewControllerInternal.h"
#import "TGLocalization.h"

@implementation TGMediaFullscreenController (Playback)

- (void)playTapped {
	if (_currentIndex < 0 || _currentIndex >= (NSInteger)_items.count)
		return;

	if (_inlinePlayer && _inlinePlayerIndex == _currentIndex) {
		[self toggleInlinePlayback];
		return;
	}

	NSDictionary *item = _items[_currentIndex];
	NSNumber *fileId = item[@"fullId"];
	if (![fileId isKindOfClass:NSNumber.class])
		return;

	[_spinner startAnimating];
	_playButton.enabled = NO;
	_busyPageIndex = _currentIndex;
	[[TGClient shared] startDownloadingFile:[fileId longLongValue]
								   priority:32
								 completion:nil];

	NSInteger requestedIndex = _currentIndex;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] downloadFile:[fileId longLongValue] completion:^(NSString *path) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf.spinner stopAnimating];
		strongSelf.playButton.enabled = YES;
		if (strongSelf.busyPageIndex == requestedIndex)
			strongSelf.busyPageIndex = NSNotFound;
		[strongSelf updateLoadingChrome];
		if (path.length == 0) {
			[strongSelf showMessage:TGL(@"Media.CouldNotStartDownload", @"Could not start the download.")];
			return;
		}
		if (strongSelf.currentIndex != requestedIndex)
			return;
		[strongSelf startInlinePlaybackAtPath:path];
	}];
}

- (void)startInlinePlaybackAtPath:(NSString *)path {
	[self stopInlinePlayer];

	MPMoviePlayerController *player = [[TGMPClass(MPMoviePlayerController) alloc]
		initWithContentURL:[NSURL fileURLWithPath:path]];
	if (!player)
		return;

	player.controlStyle = MPMovieControlStyleNone;
	player.scalingMode = MPMovieScalingModeAspectFit;
	player.shouldAutoplay = NO;
	player.view.frame = self.view.bounds;
	player.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	player.view.userInteractionEnabled = NO;
	[self.view insertSubview:player.view aboveSubview:_pagingView];

	__weak typeof(self) weakSelf = self;
	_inlinePlaybackDidFinishObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:@"MPMoviePlayerPlaybackDidFinishNotification"
					object:player
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf inlinePlaybackDidFinish:note];
				}];

	_inlinePlayer = player;
	_inlinePlayerIndex = _currentIndex;
	_inlinePlaying = YES;
	[player prepareToPlay];
	[player play];
	[self updatePlayButtonPlaying:YES];
}

- (void)toggleInlinePlayback {
	if (!_inlinePlayer)
		return;
	if (_inlinePlaying) {
		[_inlinePlayer pause];
		_inlinePlaying = NO;
	} else {
		[_inlinePlayer play];
		_inlinePlaying = YES;
	}
	[self updatePlayButtonPlaying:_inlinePlaying];
}

- (void)stopInlinePlayer {
	if (!_inlinePlayer)
		return;
	if (_inlinePlaybackDidFinishObserverToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:_inlinePlaybackDidFinishObserverToken];
		_inlinePlaybackDidFinishObserverToken = nil;
	}
	[_inlinePlayer stop];
	[_inlinePlayer.view removeFromSuperview];
	_inlinePlayer = nil;
	_inlinePlayerIndex = NSNotFound;
	_inlinePlaying = NO;
	[self updatePlayButtonPlaying:NO];
}

- (void)inlinePlaybackDidFinish:(NSNotification *)note {
	if (note.object != _inlinePlayer)
		return;
	[self stopInlinePlayer];
}

- (void)updatePlayButtonPlaying:(BOOL)playing {
	if (playing) {
		[_playButton setBackgroundImage:TGMediaPauseGlyph(_playButton.bounds.size)
							   forState:UIControlStateNormal];
		[_playButton setTitle:TGL(@"Conversation.StopVoiceMessagePauseAction", @"Pause") forState:UIControlStateNormal];
	} else {
		UIImage *playImage = [UIImage imageNamed:@"VideoPanelPlay.png"];
		[_playButton setBackgroundImage:playImage forState:UIControlStateNormal];
		[_playButton setTitle:TGL(@"VoiceOver.Media.PlaybackPlay", @"Play") forState:UIControlStateNormal];
	}
}

@end

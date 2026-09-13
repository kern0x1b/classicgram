#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGMusicPlayer.h"
#import "TGVoiceBubbleCell.h"
#import "TGFileBubbleCell.h"
#import "TGTheme.h"
#import "TGIcons.h"

@implementation TGChatViewController (Playback)

#pragma mark - TGExternalPlayback

- (void)externalPlaybackToggle {
	AVPlayer *player = self.videoNotePlayer;
	if (!player)
		return;
	if (player.rate > 0.01f) {
		[player pause];
		[self pauseVideoNoteRing];
	} else {
		[player play];
		player.rate = [TGMusicPlayer shared].voiceRate;
		[self resumeVideoNoteRing];
	}
	[self videoNoteTicked];
}

- (void)externalPlaybackSeekToSeconds:(NSTimeInterval)seconds {
	AVPlayer *player = self.videoNotePlayer;
	if (!player)
		return;
	[player seekToTime:CMTimeMakeWithSeconds(seconds, 600)];
	[self videoNoteTicked];
}

- (void)externalPlaybackSetRate:(float)rate {
	AVPlayer *player = self.videoNotePlayer;
	if (player && player.rate > 0.01f) {
		player.rate = rate;
		[self startVideoNoteRingResumingAtCurrentPosition];
	}
}

- (void)externalPlaybackNext {
	if (self.videoNoteIndex == NSNotFound ||
		self.videoNoteIndex + 1 >= (NSInteger)self.videoNotePlaylist.count)
		return;
	NSInteger next = self.videoNoteIndex + 1;
	BOOL wasAudible = !self.videoNoteMuted;
	[self stopVideoNoteKeepingBar:YES];
	self.videoNoteIndex = next;
	self.videoNoteAutoUnmute = wasAudible;
	[self playVideoNoteAtPlaylistIndex:next];
}

- (void)externalPlaybackPrevious {
	if (self.videoNoteIndex == NSNotFound || self.videoNoteIndex == 0)
		return;
	NSInteger previous = self.videoNoteIndex - 1;
	BOOL wasAudible = !self.videoNoteMuted;
	[self stopVideoNoteKeepingBar:YES];
	self.videoNoteIndex = previous;
	self.videoNoteAutoUnmute = wasAudible;
	[self playVideoNoteAtPlaylistIndex:previous];
}

- (void)externalPlaybackStop {
	[self stopVideoNoteKeepingBar:YES];
	self.videoNoteMessageId = 0;
	self.videoNotePlaylist = nil;
	self.videoNoteIndex = NSNotFound;
}

#pragma mark - playback

- (int64_t)playingMessageId {
	TGMusicPlayer *player = [TGMusicPlayer shared];
	return (player.currentChatId == self.chatId) ? player.currentMessageId : 0;
}

- (CGFloat)playedFraction {
	return [self playingMessageId] ? [TGMusicPlayer shared].playedFraction : 0;
}

- (void)audioTagsArrived:(NSNotification *)note {
	if (!self.isViewLoaded || !self.view.window)
		return;
	NSNumber *fileId = [note.userInfo[TGAudioMetadataFileIdKey] isKindOfClass:NSNumber.class]
		? note.userInfo[TGAudioMetadataFileIdKey]
		: nil;
	for (NSDictionary *m in self.messages) {
		NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
		NSNumber *docId = [m[@"docId"] isKindOfClass:NSNumber.class] ? m[@"docId"] : nil;
		if (!messageId || !docId)
			continue;
		if (fileId && ![docId isEqualToNumber:fileId])
			continue;
		[self tg_invalidateLayoutForMessageId:messageId.longLongValue];
	}
	[self.table reloadData];
}

- (void)musicPlayerStateChanged {
	if (!self.isViewLoaded || !self.view.window)
		return;
	[self.table reloadData];
}

- (void)musicPlayerProgressed {
	int64_t playing = [self playingMessageId];
	if (!playing)
		return;
	CGFloat played = [self playedFraction];
	for (UITableViewCell *cell in self.table.visibleCells) {
		if ([cell isKindOfClass:TGVoiceBubbleCell.class]) {
			TGVoiceBubbleCell *voiceCell = (TGVoiceBubbleCell *)cell;
			if (voiceCell.voiceMessageId != playing)
				continue;
			NSDictionary *track = [TGMusicPlayer shared].currentTrack;
			NSInteger duration = [track[TGMusicTrackDuration] integerValue];
			[voiceCell updateVoicePlaybackText:[self audioLiveClockTextWithDuration:duration]];
			if (!voiceCell.wave.hidden) {
				UIImage *image = [TGIcons waveform:voiceCell.waveformData
											  size:voiceCell.wave.bounds.size
											played:played
											colour:[[TGTheme shared] mediaCircleColour]];
				voiceCell.wave.image = image;
			}
			continue;
		}
		if ([cell isKindOfClass:TGFileBubbleCell.class]) {
			TGFileBubbleCell *fileCell = (TGFileBubbleCell *)cell;
			if (fileCell.audioMessageId != playing || fileCell.audioTime.hidden)
				continue;
			NSDictionary *track = [TGMusicPlayer shared].currentTrack;
			fileCell.audioTime.text = [self audioLiveClockTextWithDuration:
					[track[TGMusicTrackDuration] integerValue]];
			if (!fileCell.audioProgress.hidden) {
				CGSize size = fileCell.audioProgress.bounds.size;
				UIColor *colour = [[TGTheme shared] accentColour];
				UIImage *image = [TGIcons progressLineOfSize:size played:played colour:colour];
				fileCell.audioProgress.image = image;
			}
			continue;
		}
	}
}

@end

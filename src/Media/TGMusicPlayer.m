#import "TGMusicPlayer.h"
#import "TGLocalization.h"
#import "TGMusicPlayerBar.h"
#import "TGClient.h"
#import "TGClient+Search.h"
#import "TGFileDownloadService.h"
#import "TGUserDisplayNameStore.h"
#import "TGVoiceDecoder.h"
#import "TGCall.h"
#import "TGPreferenceFlags.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "TGLazyFramework.h"

NSString *const TGMusicPlayerStateChangedNotification = @"TGMusicPlayerStateChanged";
NSString *const TGMusicPlayerProgressNotification = @"TGMusicPlayerProgress";

NSString *const TGMusicTrackMessageId = @"messageId";
NSString *const TGMusicTrackChatId = @"chatId";
NSString *const TGMusicTrackFileId = @"fileId";
NSString *const TGMusicTrackTitle = @"title";
NSString *const TGMusicTrackPerformer = @"performer";
NSString *const TGMusicTrackFileName = @"fileName";
NSString *const TGMusicTrackDuration = @"duration";
NSString *const TGMusicTrackIsVoice = @"voice";
NSString *const TGMusicTrackSender = @"sender";
NSString *const TGMusicTrackDate = @"date";
NSString *const TGMusicTrackAlbumCoverId = @"albumCoverId";

static const NSInteger kPlaylistLimit = 100;

static AVAudioPlayer *TGMusicOpenPlayer(NSString *path, NSString *fileName, BOOL voice);

static NSString *TGMusicString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

static BOOL TGMusicNeedsOpusDecode(NSString *path, NSString *fileName) {
	NSString *ext = path.pathExtension.lowercaseString;
	if (!ext.length)
		ext = fileName.pathExtension.lowercaseString;
	return [ext isEqualToString:@"ogg"] || [ext isEqualToString:@"oga"] || [ext isEqualToString:@"opus"];
}

static NSString *TGMusicPathWithExtension(NSString *path, NSString *fileName) {
	if (path.pathExtension.length)
		return path;
	NSString *ext = fileName.pathExtension.lowercaseString;
	if (!ext.length)
		ext = @"mp3";
	NSString *linked = [NSTemporaryDirectory() stringByAppendingPathComponent:
			[NSString stringWithFormat:@"tgmusic-%@.%@", path.lastPathComponent, ext]];
	NSFileManager *files = [NSFileManager defaultManager];
	if (![files fileExistsAtPath:linked])
		[files createSymbolicLinkAtPath:linked withDestinationPath:path error:nil];
	return [files fileExistsAtPath:linked] ? linked : path;
}

@interface TGMusicPlayer () <AVAudioPlayerDelegate>
@end

@implementation TGMusicPlayer {
	NSMutableArray *_playlist;
	NSInteger _index;
	AVAudioPlayer *_player;
	NSTimer *_tick;
	BOOL _loading;
	BOOL _sessionActive;
	NSUInteger _token;
	NSTimeInterval _pendingOffset;
	NSTimeInterval _lastNowPlayingUpdate;
	NSString *_chatTitle;
	float _voiceRate;
	__weak id<TGExternalPlayback> _external;
	NSDictionary *_externalTrack;
	NSTimeInterval _externalTime;
	NSTimeInterval _externalDuration;
	BOOL _externalPlaying;
	NSInteger _externalIndex;
	NSInteger _externalCount;
	NSMutableDictionary *_artwork;
	NSMutableSet *_artworkRequested;
	BOOL _playlistLoading;
	BOOL _endedAwaitingPlaylist;
	NSDictionary *_playerTrack;
	id _applicationBackgroundedObserverToken;
	id _applicationForegroundedObserverToken;
}

+ (instancetype)shared {
	static TGMusicPlayer *shared = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ shared = [[TGMusicPlayer alloc] init]; });
	return shared;
}

+ (void)resetForAccountSwitch {
	TGMusicPlayer *player = [TGMusicPlayer shared];
	[player stop];
	player->_artwork = nil;
	player->_artworkRequested = nil;
}

- (instancetype)init {
	if (!(self = [super init]))
		return nil;
	_playlist = [NSMutableArray array];
	_index = NSNotFound;
	_voiceRate = [TGPreferenceFlags voicePlaybackRate];
	NSNotificationCenter *centre = [NSNotificationCenter defaultCenter];
	__weak typeof(self) weakSelf = self;
	_applicationBackgroundedObserverToken = [centre
		addObserverForName:UIApplicationDidEnterBackgroundNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf applicationBackgrounded:note];
				}];
	_applicationForegroundedObserverToken = [centre
		addObserverForName:UIApplicationWillEnterForegroundNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf applicationForegrounded:note];
				}];
	return self;
}

- (void)dealloc {
	if (_applicationBackgroundedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_applicationBackgroundedObserverToken];
	if (_applicationForegroundedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_applicationForegroundedObserverToken];
}

#pragma mark - tracks

static NSString *TGMusicSenderName(int64_t senderId, BOOL outgoing) {
	if (outgoing)
		return TGL(@"DialogList.You", @"You");
	NSString *name = senderId ? [TGUserDisplayNameStore nameForUserId:senderId] : nil;
	return name.length ? name : @"";
}

+ (NSDictionary *)trackFromMessage:(NSDictionary *)message chatId:(int64_t)chatId {
	if (![message isKindOfClass:NSDictionary.class])
		return nil;
	NSString *kind = TGMusicString(message[@"kind"]);
	BOOL voice = [kind isEqualToString:@"messageVoiceNote"];
	if (!voice && ![kind isEqualToString:@"messageAudio"])
		return nil;
	if (![message[@"docId"] isKindOfClass:NSNumber.class] ||
		![message[@"id"] isKindOfClass:NSNumber.class])
		return nil;

	NSString *fileName = TGMusicString(message[@"docName"]);
	NSString *title = TGMusicString(message[@"audioTitle"]);
	if (title.length && fileName.length &&
		([title isEqualToString:fileName] ||
			[title isEqualToString:fileName.lastPathComponent]))
		title = [fileName.lastPathComponent stringByDeletingPathExtension];
	if (!title.length)
		title = voice ? TGL(@"Message.Audio", @"Voice message")
					  : (fileName.length
								? [fileName.lastPathComponent stringByDeletingPathExtension]
								: TGL(@"Attachment.Audio", @"Audio"));

	return @{
		TGMusicTrackMessageId : message[@"id"],
		TGMusicTrackChatId : [NSNumber numberWithLongLong:chatId],
		TGMusicTrackFileId : message[@"docId"],
		TGMusicTrackTitle : title,
		TGMusicTrackPerformer : TGMusicString(message[@"audioPerformer"]),
		TGMusicTrackFileName : fileName,
		TGMusicTrackDuration : message[@"duration"] ?: @0,
		TGMusicTrackIsVoice : [NSNumber numberWithBool:voice],
		TGMusicTrackSender : TGMusicSenderName([message[@"senderId"] longLongValue],
			[message[@"outgoing"] boolValue]),
		TGMusicTrackDate : message[@"date"] ?: @0,
		TGMusicTrackAlbumCoverId : ([message[@"albumCoverId"] isKindOfClass:NSNumber.class]
				? message[@"albumCoverId"]
				: @0),
	};
}

static NSString *TGMusicRawMessageSenderName(NSDictionary *sender, BOOL outgoing, NSString *chatTitle) {
	if (outgoing)
		return TGL(@"DialogList.You", @"You");
	if ([TGTDLibTypeOf(sender) isEqualToString:@"messageSenderChat"])
		return chatTitle.length ? chatTitle : @"";
	return TGMusicSenderName([sender[@"user_id"] longLongValue], NO);
}

static NSDictionary *TGMusicTrackFromRawMessage(NSDictionary *m, NSString *chatTitle) {
	if (![m isKindOfClass:NSDictionary.class])
		return nil;
	NSDictionary *content = m[@"content"];
	if (![content isKindOfClass:NSDictionary.class])
		return nil;
	NSString *kind = TGTDLibTypeOf(content);
	BOOL voice = [kind isEqualToString:@"messageVoiceNote"];
	NSDictionary *media = voice ? content[@"voice_note"] : content[@"audio"];
	if (![media isKindOfClass:NSDictionary.class])
		return nil;

	NSDictionary *file = voice ? media[@"voice"] : media[@"audio"];
	NSNumber *fileId = [file isKindOfClass:NSDictionary.class] ? file[@"id"] : nil;
	if (![fileId isKindOfClass:NSNumber.class] || ![m[@"id"] isKindOfClass:NSNumber.class])
		return nil;

	NSString *fileName = TGMusicString(media[@"file_name"]);
	NSString *title = TGMusicString(media[@"title"]);
	if (!title.length)
		title = voice ? TGL(@"Message.Audio", @"Voice message")
					  : (fileName.length
								? [fileName.lastPathComponent stringByDeletingPathExtension]
								: TGL(@"Attachment.Audio", @"Audio"));

	NSDictionary *sender = [m[@"sender_id"] isKindOfClass:NSDictionary.class]
		? m[@"sender_id"]
		: nil;

	id cover = media[@"album_cover_thumbnail"][@"file"][@"id"];
	NSNumber *coverId = (!voice && [cover isKindOfClass:NSNumber.class]) ? cover : @0;

	return @{
		TGMusicTrackMessageId : m[@"id"],
		TGMusicTrackChatId : m[@"chat_id"] ?: @0,
		TGMusicTrackFileId : fileId,
		TGMusicTrackTitle : title,
		TGMusicTrackPerformer : TGMusicString(media[@"performer"]),
		TGMusicTrackFileName : fileName,
		TGMusicTrackDuration : media[@"duration"] ?: @0,
		TGMusicTrackIsVoice : [NSNumber numberWithBool:voice],
		TGMusicTrackSender : TGMusicRawMessageSenderName(sender,
			[m[@"is_outgoing"] boolValue], chatTitle),
		TGMusicTrackDate : m[@"date"] ?: @0,
		TGMusicTrackAlbumCoverId : coverId,
	};
}

#pragma mark - state

- (NSArray *)playlist {
	return _playlist;
}

- (BOOL)external {
	return _external != nil && _externalTrack != nil;
}

- (NSDictionary *)currentTrack {
	if (self.external)
		return _externalTrack;
	if (_index == NSNotFound || _index >= (NSInteger)_playlist.count)
		return nil;
	return _playlist[_index];
}

- (int64_t)currentMessageId {
	return [self.currentTrack[TGMusicTrackMessageId] longLongValue];
}

- (int64_t)currentChatId {
	return [self.currentTrack[TGMusicTrackChatId] longLongValue];
}

- (NSString *)chatTitle {
	return _chatTitle;
}

- (BOOL)voice {
	return [self.currentTrack[TGMusicTrackIsVoice] boolValue];
}

- (float)voiceRate {
	return _voiceRate;
}

- (BOOL)playing {
	if (self.external)
		return _externalPlaying;
	return _player != nil && _player.playing;
}

- (BOOL)loading {
	return _loading;
}

- (NSTimeInterval)currentTime {
	if (self.external)
		return _externalTime;
	return _player ? _player.currentTime : 0;
}

- (NSTimeInterval)duration {
	if (self.external) {
		if (_externalDuration > 0)
			return _externalDuration;
		return [_externalTrack[TGMusicTrackDuration] doubleValue];
	}
	if (_player && _player.duration > 0)
		return _player.duration;
	return [self.currentTrack[TGMusicTrackDuration] doubleValue];
}

- (CGFloat)playedFraction {
	NSTimeInterval total = self.duration;
	if (total <= 0)
		return 0;
	return (CGFloat)(self.currentTime / total);
}

- (BOOL)isCurrentMessage:(int64_t)messageId inChat:(int64_t)chatId {
	NSDictionary *track = self.currentTrack;
	if (!track)
		return NO;
	return [track[TGMusicTrackMessageId] longLongValue] == messageId &&
		[track[TGMusicTrackChatId] longLongValue] == chatId;
}

#pragma mark - starting

- (void)playMessage:(NSDictionary *)message
			 inChat:(int64_t)chatId
		  chatTitle:(NSString *)chatTitle
		fromSeconds:(NSTimeInterval)seconds {
	NSDictionary *track = [TGMusicPlayer trackFromMessage:message chatId:chatId];
	if (!track)
		return;
	int64_t messageId = [track[TGMusicTrackMessageId] longLongValue];

	if ([self isCurrentMessage:messageId inChat:chatId] && (_player || _loading)) {
		if (_loading && !_player && seconds <= 0) {
			[self stop];
			return;
		}
		if (seconds > 0) {
			[self seekToSeconds:seconds];
			if (!self.playing)
				[self toggle];
			return;
		}
		[self toggle];
		return;
	}

	_chatTitle = [chatTitle copy];
	[_playlist removeAllObjects];
	[_playlist addObject:[self named:track]];
	_index = 0;
	[self startCurrentFromSeconds:seconds];
	[self loadPlaylistAround:track];
}

- (void)playVoiceMessageId:(int64_t)messageId
					chatId:(int64_t)chatId
					fileId:(long long)fileId
				  duration:(NSInteger)duration
					sender:(NSString *)sender
					  date:(int64_t)date {
	if (messageId == 0 || fileId <= 0)
		return;

	if ([self isCurrentMessage:messageId inChat:chatId] && (_player || _loading)) {
		if (_loading && !_player) {
			[self stop];
			return;
		}
		[self toggle];
		return;
	}

	NSDictionary *track = @{
		TGMusicTrackMessageId : @(messageId),
		TGMusicTrackChatId : @(chatId),
		TGMusicTrackFileId : @(fileId),
		TGMusicTrackTitle : TGL(@"Message.Audio", @"Voice message"),
		TGMusicTrackPerformer : @"",
		TGMusicTrackFileName : @"",
		TGMusicTrackDuration : @(duration),
		TGMusicTrackIsVoice : @YES,
		TGMusicTrackSender : sender ?: @"",
		TGMusicTrackDate : @(date),
		TGMusicTrackAlbumCoverId : @0,
	};

	_chatTitle = nil;
	[_playlist removeAllObjects];
	[_playlist addObject:[self named:track]];
	_index = 0;
	[self startCurrentFromSeconds:0];
}

- (NSDictionary *)named:(NSDictionary *)track {
	if (![track[TGMusicTrackIsVoice] boolValue] || !_chatTitle.length)
		return track;
	if ([track[TGMusicTrackSender] length])
		return track;
	NSMutableDictionary *named = [track mutableCopy];
	named[TGMusicTrackSender] = _chatTitle;
	return named;
}

- (void)loadPlaylistAround:(NSDictionary *)track {
	int64_t chatId = [track[TGMusicTrackChatId] longLongValue];
	int64_t messageId = [track[TGMusicTrackMessageId] longLongValue];
	BOOL voice = [track[TGMusicTrackIsVoice] boolValue];
	NSString *filter = voice ? @"searchMessagesFilterVoiceNote" : @"searchMessagesFilterAudio";

	_playlistLoading = YES;
	NSString *chatTitle = _chatTitle;
	__weak TGMusicPlayer *weakSelf = self;
	[[TGClient shared] sharedMediaInChat:chatId
								 topicId:0
								   query:@""
							  filterName:filter
						   fromMessageId:0
								   limit:kPlaylistLimit
							  completion:^(NSDictionary *result, int64_t nextFromMessageId) {
								  (void)nextFromMessageId;
								  TGMusicPlayer *strongSelf = weakSelf;
								  if (!strongSelf)
									  return;
								  strongSelf->_playlistLoading = NO;
								  if (![strongSelf isCurrentMessage:messageId inChat:chatId]) {
									  [strongSelf resumeAfterPlaylistArrived];
									  return;
								  }
								  NSArray *messages = [result[@"messages"] isKindOfClass:NSArray.class]
									  ? result[@"messages"]
									  : nil;
								  if (!messages.count)
									  return;

								  NSMutableArray *tracks = [NSMutableArray arrayWithCapacity:messages.count];
								  for (NSDictionary *raw in [messages reverseObjectEnumerator]) {
									  NSDictionary *entry = TGMusicTrackFromRawMessage(raw, chatTitle);
									  if (!entry)
										  continue;
									  [tracks addObject:[strongSelf named:entry]];
								  }

								  NSInteger found = NSNotFound;
								  for (NSInteger i = 0; i < tracks.count; i++)
									  if ([tracks[i][TGMusicTrackMessageId] longLongValue] == messageId)
										  found = (NSInteger)i;
								  if (found == NSNotFound) {
									  [tracks addObject:strongSelf.currentTrack];
									  found = (NSInteger)tracks.count - 1;
								  }

								  [strongSelf adoptPlaylist:tracks index:found];
								  [strongSelf resumeAfterPlaylistArrived];
							  }];
}

- (void)resumeAfterPlaylistArrived {
	if (!_endedAwaitingPlaylist)
		return;
	_endedAwaitingPlaylist = NO;
	NSInteger next = [self indexAfterCurrentWrapping:(_repeatMode == TGMusicRepeatAll)];
	if (next == NSNotFound) {
		[self stop];
		return;
	}
	_index = next;
	[self startCurrentFromSeconds:0];
}

- (void)adoptPlaylist:(NSArray *)tracks index:(NSInteger)index {
	[_playlist setArray:tracks];
	_index = index;
	[self postStateChanged];
}

- (void)startCurrentFromSeconds:(NSTimeInterval)seconds {
	NSDictionary *track = self.currentTrack;
	if (!track) {
		[self stop];
		return;
	}

	[self teardownPlayer];
	_playerTrack = track;
	_loading = YES;
	_pendingOffset = seconds;
	NSInteger token = ++_token;
	[TGMusicPlayerBar activate];
	[self postStateChanged];

	long long fileId = [track[TGMusicTrackFileId] longLongValue];
	BOOL voice = [track[TGMusicTrackIsVoice] boolValue];
	NSString *fileName = track[TGMusicTrackFileName];

	__weak TGMusicPlayer *weakSelf = self;
	[TGFileDownloadService downloadFile:fileId completion:^(NSString *path) {
		TGMusicPlayer *strongSelf = weakSelf;
		if (!strongSelf || token != strongSelf->_token)
			return;
		if (!path.length) {
			[strongSelf failedWithMessage:TGL(@"Music.DownloadFailed", @"This track could not be downloaded")];
			return;
		}
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			AVAudioPlayer *ready = TGMusicOpenPlayer(path, fileName, voice);
			dispatch_async(dispatch_get_main_queue(), ^{
				TGMusicPlayer *innerSelf = weakSelf;
				if (!innerSelf || token != innerSelf->_token)
					return;
				if (!ready) {
					[innerSelf failedWithMessage:TGL(@"Music.PlaybackFailed", @"This track cannot be played")];
					return;
				}
				[innerSelf beginPlaybackWith:ready];
			});
		});
	}];
}

static AVAudioPlayer *TGMusicOpenPlayer(NSString *path, NSString *fileName, BOOL voice) {
	AVAudioPlayer *player = nil;
	if (!voice && !TGMusicNeedsOpusDecode(path, fileName)) {
		NSString *usable = TGMusicPathWithExtension(path, fileName);
		NSURL *url = [NSURL fileURLWithPath:usable];
		player = [[TGAVClass(AVAudioPlayer) alloc] initWithContentsOfURL:url error:nil];
		if (player)
			return player;
	}
	NSString *wav = [TGVoiceDecoder wavFromOpusFile:path];
	if (!wav.length)
		return nil;
	NSURL *wavUrl = [NSURL fileURLWithPath:wav];
	return [[TGAVClass(AVAudioPlayer) alloc] initWithContentsOfURL:wavUrl error:nil];
}

- (void)beginPlaybackWith:(AVAudioPlayer *)player {
	_loading = NO;
	_player = player;
	_player.delegate = self;
	if (self.voice) {
		_player.enableRate = YES;
		[_player prepareToPlay];
	}
	[self activateSession];
	if (_pendingOffset > 0) {
		_player.currentTime = MIN(_pendingOffset, _player.duration);
		_pendingOffset = 0;
	}
	[_player play];
	[self applyVoiceRate];
	[self startTick];
	[self updateNowPlaying];
	[self postStateChanged];
}

- (void)failedWithMessage:(NSString *)message {
	_loading = NO;
	[self stop];
	UIAlertView *alert = [UIAlertView alloc];
	alert = [alert initWithTitle:@""
						 message:message
						delegate:nil
			   cancelButtonTitle:TGL(@"Common.OK", @"OK")
			   otherButtonTitles:nil];
	[alert show];
}

#pragma mark - transport

- (void)toggle {
	if (self.external) {
		[_external externalPlaybackToggle];
		return;
	}
	if (_loading)
		return;
	if (!_player) {
		if (self.currentTrack)
			[self startCurrentFromSeconds:0];
		return;
	}
	if (_player.playing) {
		[_player pause];
		[self stopTick];
	} else {
		[self activateSession];
		[_player play];
		[self applyVoiceRate];
		[self startTick];
	}
	[self updateNowPlaying];
	[self postStateChanged];
}

- (NSInteger)currentIndex {
	return self.external ? _externalIndex : _index;
}

- (NSInteger)indexAfterCurrentWrapping:(BOOL)wrapping {
	NSInteger count = (NSInteger)_playlist.count;
	if (_index == NSNotFound || count == 0)
		return NSNotFound;
	if (_shuffleEnabled && count > 1) {
		NSInteger pick = _index;
		while (pick == _index)
			pick = (NSInteger)arc4random_uniform((u_int32_t)count);
		return pick;
	}
	if (_index + 1 < count)
		return _index + 1;
	return wrapping ? 0 : NSNotFound;
}

- (void)playNext {
	if (self.external) {
		[_external externalPlaybackNext];
		return;
	}
	NSInteger next = [self indexAfterCurrentWrapping:YES];
	if (next == NSNotFound)
		return;
	_index = next;
	[self startCurrentFromSeconds:0];
}

- (void)playPrevious {
	if (self.external) {
		if (_externalTime > 3.0) {
			[_external externalPlaybackSeekToSeconds:0];
			return;
		}
		[_external externalPlaybackPrevious];
		return;
	}
	if (_index == NSNotFound)
		return;
	if (_player && _player.currentTime > 3.0) {
		[self seekToSeconds:0];
		return;
	}
	if (_index == 0) {
		[self seekToSeconds:0];
		return;
	}
	_index -= 1;
	[self startCurrentFromSeconds:0];
}

- (void)playTrackAtIndex:(NSInteger)index {
	if (self.external)
		return;
	if (index < 0 || index >= (NSInteger)_playlist.count)
		return;
	if (index == _index && _player) {
		[self toggle];
		return;
	}
	_index = index;
	[self startCurrentFromSeconds:0];
}

- (void)seekToFraction:(CGFloat)fraction {
	NSTimeInterval total = self.duration;
	if (total <= 0)
		return;
	[self seekToSeconds:total * MAX((CGFloat)0, MIN((CGFloat)1, fraction))];
}

- (void)seekToSeconds:(NSTimeInterval)seconds {
	if (self.external) {
		[_external externalPlaybackSeekToSeconds:MAX((NSTimeInterval)0, seconds)];
		return;
	}
	if (!_player) {
		_pendingOffset = seconds;
		return;
	}
	_player.currentTime = MAX((NSTimeInterval)0, MIN(seconds, _player.duration));
	[self updateNowPlaying];
	[self postProgress];
}

- (void)applyVoiceRate {
	if (!_player || !self.voice)
		return;
	_player.enableRate = YES;
	_player.rate = _voiceRate;
}

- (void)cycleVoiceRate {
	if (!self.voice)
		return;
	if (_voiceRate < 1.25f)
		_voiceRate = 1.5f;
	else if (_voiceRate < 1.75f)
		_voiceRate = 2.0f;
	else
		_voiceRate = 1.0f;
	[TGPreferenceFlags setVoicePlaybackRate:_voiceRate];
	if (self.external)
		[_external externalPlaybackSetRate:_voiceRate];
	else
		[self applyVoiceRate];
	[self postStateChanged];
}

#pragma mark - external playback

- (void)attachExternalTrack:(NSDictionary *)track
				   delegate:(id<TGExternalPlayback>)delegate {
	if (!track || !delegate)
		return;

	id<TGExternalPlayback> previous = _external;
	_external = nil;
	_externalTrack = nil;
	if (previous && previous != delegate)
		[previous externalPlaybackStop];
	[self teardownPlayer];
	[_playlist removeAllObjects];
	_index = NSNotFound;
	_loading = NO;
	_token++;

	_external = delegate;
	_externalTrack = [track copy];
	_externalTime = 0;
	_externalDuration = [track[TGMusicTrackDuration] doubleValue];
	_externalPlaying = YES;
	_externalIndex = 0;
	_externalCount = 1;

	[TGMusicPlayerBar activate];
	[self clearNowPlaying];
	[self postStateChanged];
}

- (void)externalDidUpdateTime:(NSTimeInterval)time
					 duration:(NSTimeInterval)duration
					  playing:(BOOL)playing {
	if (!self.external)
		return;
	BOOL wasPlaying = _externalPlaying;
	_externalTime = MAX((NSTimeInterval)0, time);
	if (duration > 0)
		_externalDuration = duration;
	_externalPlaying = playing;
	[self postProgress];
	if (wasPlaying != playing)
		[self postStateChanged];
}

- (void)externalDidUpdatePosition:(NSInteger)index count:(NSInteger)count {
	if (!self.external)
		return;
	_externalIndex = index;
	_externalCount = count;
	[self postStateChanged];
}

- (void)detachExternal:(id<TGExternalPlayback>)delegate {
	if (!self.external)
		return;
	if (delegate && delegate != _external)
		return;
	_external = nil;
	_externalTrack = nil;
	_externalTime = 0;
	_externalDuration = 0;
	_externalPlaying = NO;
	_externalIndex = 0;
	_externalCount = 0;
	[self deactivateSession];
	[self postStateChanged];
}

- (void)chatClosed:(int64_t)chatId {
	NSDictionary *track = self.currentTrack;
	if (!track || ![track[TGMusicTrackIsVoice] boolValue])
		return;
	if ([track[TGMusicTrackChatId] longLongValue] != chatId)
		return;
	[self stop];
}

- (void)chatOpened:(int64_t)chatId {
	NSDictionary *track = self.currentTrack;
	if (!track || ![track[TGMusicTrackIsVoice] boolValue])
		return;
	if ([track[TGMusicTrackChatId] longLongValue] == chatId)
		return;
	[self stop];
}

- (BOOL)hasNext {
	if (self.external)
		return _externalIndex + 1 < _externalCount;
	if (_index == NSNotFound)
		return NO;
	if (_repeatMode != TGMusicRepeatOff || _shuffleEnabled)
		return _playlist.count > 1;
	return _index + 1 < (NSInteger)_playlist.count;
}

- (BOOL)hasPrevious {
	if (self.external)
		return YES;
	return _index != NSNotFound;
}

- (void)stop {
	if (self.external) {
		[_external externalPlaybackStop];
		[self detachExternal:nil];
		return;
	}
	[self teardownPlayer];
	[_playlist removeAllObjects];
	_index = NSNotFound;
	_loading = NO;
	_endedAwaitingPlaylist = NO;
	_token++;
	[self clearNowPlaying];
	[self deactivateSession];
	[self postStateChanged];
}

- (void)teardownPlayer {
	[self reportListenedForPlayerTrack];
	if (_loading && !_player) {
		long long pendingFileId = [_playerTrack[TGMusicTrackFileId] longLongValue];
		if (pendingFileId > 0)
			[TGFileDownloadService cancelDownloadOfFile:pendingFileId onlyIfPending:NO];
	}
	[self stopTick];
	_player.delegate = nil;
	[_player stop];
	_player = nil;
	_playerTrack = nil;
}

- (void)reportListenedForPlayerTrack {
	if (!_player || !_playerTrack)
		return;
	long long fileId = [_playerTrack[TGMusicTrackFileId] longLongValue];
	NSInteger listened = (NSInteger)llround(_player.currentTime);
	if (fileId <= 0 || listened <= 0)
		return;
	[TGFileDownloadService reportAudioListened:fileId durationSeconds:listened];
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
	if (player != _player)
		return;
	if (_repeatMode == TGMusicRepeatOne) {
		[self startCurrentFromSeconds:0];
		return;
	}
	NSInteger next = [self indexAfterCurrentWrapping:(_repeatMode == TGMusicRepeatAll)];
	if (next != NSNotFound) {
		_index = next;
		[self startCurrentFromSeconds:0];
		return;
	}
	if (_playlistLoading) {
		_endedAwaitingPlaylist = YES;
		[self stopTick];
		[self postStateChanged];
		return;
	}
	[self stop];
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error {
	if (player == _player)
		[self stop];
}

- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)player {
	[self stopTick];
	[self postStateChanged];
}

- (void)audioPlayerEndInterruption:(AVAudioPlayer *)player withOptions:(NSUInteger)flags {
	if (player != _player)
		return;
	[self activateSession];
	if (flags & AVAudioSessionInterruptionOptionShouldResume) {
		[_player play];
		[self applyVoiceRate];
		[self startTick];
	}
	[self postStateChanged];
}

#pragma mark - session, remote control, lock screen

- (void)activateSession {
	AVAudioSession *session = [TGAVClass(AVAudioSession) sharedInstance];
	[session setCategory:TGAVString(AVAudioSessionCategoryPlayback) error:nil];
	[session setActive:YES error:nil];
	if (!_sessionActive) {
		_sessionActive = YES;
		[[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
	}
}

- (void)deactivateSession {
	if (!_sessionActive)
		return;
	_sessionActive = NO;
	[[UIApplication sharedApplication] endReceivingRemoteControlEvents];
	TGCallState call = [TGCall shared].state;
	if (call == TGCallStateNone || call == TGCallStateEnded || call == TGCallStateFailed)
		[[TGAVClass(AVAudioSession) sharedInstance] setActive:NO error:nil];
}

- (void)handleRemoteControlEvent:(UIEvent *)event {
	if (event.type != UIEventTypeRemoteControl)
		return;
	switch (event.subtype) {
		case UIEventSubtypeRemoteControlPlay:
		case UIEventSubtypeRemoteControlPause:
		case UIEventSubtypeRemoteControlTogglePlayPause:
			[self toggle];
			break;
		case UIEventSubtypeRemoteControlNextTrack:
			if (!self.voice)
				[self playNext];
			break;
		case UIEventSubtypeRemoteControlPreviousTrack:
			if (!self.voice)
				[self playPrevious];
			break;
		case UIEventSubtypeRemoteControlStop:
			[self stop];
			break;
		default:
			break;
	}
}

- (void)setShuffleEnabled:(BOOL)shuffleEnabled {
	if (_shuffleEnabled == shuffleEnabled)
		return;
	_shuffleEnabled = shuffleEnabled;
	[self postStateChanged];
}

- (void)setRepeatMode:(TGMusicRepeatMode)repeatMode {
	if (_repeatMode == repeatMode)
		return;
	_repeatMode = repeatMode;
	[self postStateChanged];
}

- (UIImage *)currentArtwork {
	long long coverId = [self.currentTrack[TGMusicTrackAlbumCoverId] longLongValue];
	if (coverId <= 0)
		return nil;
	UIImage *cached = _artwork[[NSNumber numberWithLongLong:coverId]];
	if (cached)
		return cached;

	if ([_artworkRequested containsObject:[NSNumber numberWithLongLong:coverId]])
		return nil;
	if (!_artworkRequested)
		_artworkRequested = [NSMutableSet set];
	[_artworkRequested addObject:[NSNumber numberWithLongLong:coverId]];

	__weak TGMusicPlayer *weakSelf = self;
	[TGFileDownloadService downloadFile:coverId completion:^(NSString *path) {
		TGMusicPlayer *strongSelf = weakSelf;
		if (!strongSelf || !path.length)
			return;
		UIImage *image = [UIImage imageWithContentsOfFile:path];
		if (!image)
			return;
		if (!strongSelf->_artwork)
			strongSelf->_artwork = [NSMutableDictionary dictionary];
		strongSelf->_artwork[[NSNumber numberWithLongLong:coverId]] = image;
		[strongSelf updateNowPlaying];
		[strongSelf postStateChanged];
	}];
	return nil;
}

- (Class)nowPlayingCentre {
	return TGMPClass(MPNowPlayingInfoCenter);
}

- (void)updateNowPlaying {
	NSDictionary *track = self.currentTrack;
	if (!track)
		return;
	if ([track[TGMusicTrackIsVoice] boolValue]) {
		[self clearNowPlaying];
		_lastNowPlayingUpdate = [NSDate timeIntervalSinceReferenceDate];
		return;
	}
	Class centre = [self nowPlayingCentre];
	if (!centre)
		return;
	NSMutableDictionary *info = [NSMutableDictionary dictionary];
	info[TGMPString(MPMediaItemPropertyTitle)] = track[TGMusicTrackTitle] ?: @"Audio";
	NSString *performer = track[TGMusicTrackPerformer];
	if (performer.length)
		info[TGMPString(MPMediaItemPropertyArtist)] = performer;
	info[TGMPString(MPMediaItemPropertyPlaybackDuration)] = [NSNumber numberWithDouble:self.duration];
	info[TGMPString(MPNowPlayingInfoPropertyElapsedPlaybackTime)] =
		[NSNumber numberWithDouble:self.currentTime];
	info[TGMPString(MPNowPlayingInfoPropertyPlaybackRate)] =
		[NSNumber numberWithDouble:(self.playing ? 1.0 : 0.0)];

	UIImage *cover = self.currentArtwork;
	Class artworkClass = TGMPClass(MPMediaItemArtwork);
	NSString *artworkKey = TGMPString(MPMediaItemPropertyArtwork);
	if (cover && artworkClass && artworkKey.length) {
		id artwork = [[artworkClass alloc] initWithImage:cover];
		if (artwork)
			info[artworkKey] = artwork;
	}

	[(MPNowPlayingInfoCenter *)[centre defaultCenter] setNowPlayingInfo:info];
	_lastNowPlayingUpdate = [NSDate timeIntervalSinceReferenceDate];
}

- (void)clearNowPlaying {
	Class centre = NSClassFromString(@"MPNowPlayingInfoCenter");
	if (centre)
		[(MPNowPlayingInfoCenter *)[centre defaultCenter] setNowPlayingInfo:nil];
}

#pragma mark - ticking

- (void)startTick {
	[self stopTick];
	_tick = [NSTimer scheduledTimerWithTimeInterval:0.2
											 target:self
										   selector:@selector(ticked)
										   userInfo:nil
											repeats:YES];
}

- (void)stopTick {
	[_tick invalidate];
	_tick = nil;
}

- (void)ticked {
	[self postProgress];
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	if (now - _lastNowPlayingUpdate > 2.0)
		[self updateNowPlaying];
}

- (void)applicationBackgrounded:(NSNotification *)note {
	[self stopTick];
}

- (void)applicationForegrounded:(NSNotification *)note {
	if (self.playing)
		[self startTick];
}

#pragma mark - notifications

- (void)postStateChanged {
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGMusicPlayerStateChangedNotification
					  object:self];
}

- (void)postProgress {
	[[NSNotificationCenter defaultCenter]
		postNotificationName:TGMusicPlayerProgressNotification
					  object:self];
}

@end

#import <UIKit/UIKit.h>

extern NSString *const TGMusicPlayerStateChangedNotification;
extern NSString *const TGMusicPlayerProgressNotification;

extern NSString *const TGMusicTrackMessageId;
extern NSString *const TGMusicTrackChatId;
extern NSString *const TGMusicTrackFileId;
extern NSString *const TGMusicTrackTitle;
extern NSString *const TGMusicTrackPerformer;
extern NSString *const TGMusicTrackFileName;
extern NSString *const TGMusicTrackDuration;
extern NSString *const TGMusicTrackIsVoice;
extern NSString *const TGMusicTrackSender;
extern NSString *const TGMusicTrackDate;
extern NSString *const TGMusicTrackAlbumCoverId;

typedef NS_ENUM(NSInteger, TGMusicRepeatMode) {
	TGMusicRepeatOff = 0,
	TGMusicRepeatAll,
	TGMusicRepeatOne,
};

@protocol TGExternalPlayback <NSObject>
- (void)externalPlaybackToggle;
- (void)externalPlaybackSeekToSeconds:(NSTimeInterval)seconds;
- (void)externalPlaybackSetRate:(float)rate;
- (void)externalPlaybackNext;
- (void)externalPlaybackPrevious;
- (void)externalPlaybackStop;
@end

@interface TGMusicPlayer : NSObject

+ (instancetype)shared;
+ (void)resetForAccountSwitch;

@property (nonatomic, readonly) NSArray *playlist;
@property (nonatomic, readonly) NSDictionary *currentTrack;
@property (nonatomic, readonly) int64_t currentMessageId;
@property (nonatomic, readonly) int64_t currentChatId;
@property (nonatomic, readonly, copy) NSString *chatTitle;
@property (nonatomic, readonly) BOOL voice;
@property (nonatomic, readonly) float voiceRate;
@property (nonatomic, readonly) BOOL playing;
@property (nonatomic, readonly) BOOL loading;
@property (nonatomic, readonly) NSTimeInterval currentTime;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) CGFloat playedFraction;
@property (nonatomic, assign) BOOL shuffleEnabled;
@property (nonatomic, assign) TGMusicRepeatMode repeatMode;
@property (nonatomic, readonly) NSInteger currentIndex;

+ (NSDictionary *)trackFromMessage:(NSDictionary *)message chatId:(int64_t)chatId;

- (UIImage *)currentArtwork;

- (void)playMessage:(NSDictionary *)message
			 inChat:(int64_t)chatId
		  chatTitle:(NSString *)chatTitle
		fromSeconds:(NSTimeInterval)seconds;

- (void)playVoiceMessageId:(int64_t)messageId
					chatId:(int64_t)chatId
					fileId:(long long)fileId
				  duration:(NSInteger)duration
					sender:(NSString *)sender
					  date:(int64_t)date;

- (void)toggle;
- (void)playNext;
- (void)playPrevious;
- (void)playTrackAtIndex:(NSInteger)index;
- (void)seekToFraction:(CGFloat)fraction;
- (void)seekToSeconds:(NSTimeInterval)seconds;
- (void)cycleVoiceRate;
- (void)stop;

- (BOOL)isCurrentMessage:(int64_t)messageId inChat:(int64_t)chatId;

- (BOOL)hasNext;
- (BOOL)hasPrevious;

- (void)chatClosed:(int64_t)chatId;
- (void)chatOpened:(int64_t)chatId;

- (void)handleRemoteControlEvent:(UIEvent *)event;

#pragma mark - external playback

@property (nonatomic, readonly) BOOL external;

- (void)attachExternalTrack:(NSDictionary *)track
				   delegate:(id<TGExternalPlayback>)delegate;

- (void)externalDidUpdateTime:(NSTimeInterval)time
					 duration:(NSTimeInterval)duration
					  playing:(BOOL)playing;

- (void)externalDidUpdatePosition:(NSInteger)index count:(NSInteger)count;

- (void)detachExternal:(id<TGExternalPlayback>)delegate;

@end

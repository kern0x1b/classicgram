#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TGChatComposerState : NSObject

@property (nonatomic, readonly, assign) BOOL canPost;
@property (nonatomic, readonly, assign) BOOL channel;
@property (nonatomic, readonly, assign) BOOL canSendPhotos;
@property (nonatomic, readonly, assign) BOOL canSendVideos;
@property (nonatomic, readonly, assign) BOOL canSendVideoNotes;
@property (nonatomic, readonly, assign) BOOL canSendVoiceNotes;
@property (nonatomic, readonly, assign) BOOL canSendAudios;
@property (nonatomic, readonly, assign) BOOL canSendDocuments;
@property (nonatomic, readonly, assign) BOOL canSendPolls;
@property (nonatomic, readonly, assign) BOOL canSendOtherMessages;
@property (nonatomic, readonly, assign) NSInteger slowModeDelay;
@property (nonatomic, readonly, assign) NSInteger slowModeSecondsRemaining;
@property (nonatomic, readonly, assign) BOOL slowModeBlocked;
@property (nonatomic, readonly, assign) BOOL topicClosed;
@property (nonatomic, readonly, assign) BOOL isMember;

+ (instancetype)stateWithCanSend:(BOOL)canSend
						isChannel:(BOOL)isChannel
					  permissions:(nullable NSDictionary *)permissions;

@end

NS_ASSUME_NONNULL_END

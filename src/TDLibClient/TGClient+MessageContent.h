#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const TGAnimatedEmojiClickedNotification;
extern NSString *const TGAnimatedEmojiClickedChatIdKey;
extern NSString *const TGAnimatedEmojiClickedStickerFileIdKey;
extern NSString *const TGAnimatedEmojiClickedIsAnimatedKey;

extern const NSInteger kSelfDestructViewOnce;

@interface TGClient (MessageContent)

#pragma mark - text entities

- (void)parseMarkdown:(NSString *)text
		   completion:(void (^ _Nullable)(NSString *plainText, NSArray *entities))completion;

- (void)formattedTextFromMarkdown:(NSString *)text
						completion:(void (^ _Nullable)(NSString *text, NSArray *entities))completion;

NSDictionary *TGCustomEmojiEntity(NSInteger offset, NSInteger length, long long customEmojiId);
NSDictionary *TGMentionNameEntity(NSInteger offset, NSInteger length, int64_t userId);

- (void)entitiesInText:(NSString *)text
			completion:(void (^ _Nullable)(NSArray *entities))completion;

- (void)sendMarkdown:(NSString *)text
				 toChat:(int64_t)chatId
				 thread:(int64_t)threadId
	directMessagesTopic:(int64_t)directMessagesTopicId
			 savedTopic:(int64_t)savedTopicId
				replyTo:(int64_t)replyToId;

- (void)editCaptionOfMessage:(int64_t)messageId
					  inChat:(int64_t)chatId
					 caption:(NSString *)caption
					entities:(nullable NSArray *)entities
	  showCaptionAboveMedia:(BOOL)showCaptionAboveMedia
				  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)editMessageWithMarkdown:(int64_t)messageId
						 inChat:(int64_t)chatId
						   text:(NSString *)text
			 linkPreviewOptions:(nullable NSDictionary *)linkPreviewOptions
					 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)actualAuthorOfMessage:(int64_t)messageId
					   inChat:(int64_t)chatId
				   completion:(void (^ _Nullable)(NSString *name, int64_t userId))completion;

#pragma mark - inspecting media

- (void)mediaInfoForMessage:(int64_t)messageId
					 inChat:(int64_t)chatId
				 completion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)openContentOfMessage:(int64_t)messageId inChat:(int64_t)chatId;

- (NSString *)placeholderTextForContentKind:(NSString *)kind;

#pragma mark - sending media

- (void)sendPhotoAtPath:(NSString *)path
				 toChat:(int64_t)chatId
				 thread:(int64_t)threadId
	directMessagesTopic:(int64_t)directMessagesTopicId
			 savedTopic:(int64_t)savedTopicId
				replyTo:(int64_t)replyToId
				caption:(NSString *)caption
				spoiler:(BOOL)spoiler
	selfDestructSeconds:(NSInteger)selfDestructSeconds
				options:(nullable NSDictionary *)options;

- (void)sendVideoAtPath:(NSString *)path
				 toChat:(int64_t)chatId
				 thread:(int64_t)threadId
	directMessagesTopic:(int64_t)directMessagesTopicId
			 savedTopic:(int64_t)savedTopicId
				replyTo:(int64_t)replyToId
				caption:(NSString *)caption
			   duration:(NSInteger)duration
				  width:(NSInteger)width
				 height:(NSInteger)height
				spoiler:(BOOL)spoiler
	selfDestructSeconds:(NSInteger)selfDestructSeconds
				options:(nullable NSDictionary *)options;

- (void)sendVideoNoteAtPath:(NSString *)path
					 toChat:(int64_t)chatId
					 thread:(int64_t)threadId
		directMessagesTopic:(int64_t)directMessagesTopicId
				 savedTopic:(int64_t)savedTopicId
					replyTo:(int64_t)replyToId
				   duration:(NSInteger)duration
					   side:(NSInteger)side
					options:(nullable NSDictionary *)options;

- (void)sendAnimationAtPath:(NSString *)path
					 toChat:(int64_t)chatId
					 thread:(int64_t)threadId
		directMessagesTopic:(int64_t)directMessagesTopicId
				 savedTopic:(int64_t)savedTopicId
					replyTo:(int64_t)replyToId
					caption:(NSString *)caption
				   duration:(NSInteger)duration
					  width:(NSInteger)width
					 height:(NSInteger)height
					options:(nullable NSDictionary *)options;

- (void)sendAudioAtPath:(NSString *)path
				 toChat:(int64_t)chatId
				 thread:(int64_t)threadId
	directMessagesTopic:(int64_t)directMessagesTopicId
			 savedTopic:(int64_t)savedTopicId
				replyTo:(int64_t)replyToId
				  title:(NSString *)title
			  performer:(NSString *)performer
			   duration:(NSInteger)duration
				caption:(NSString *)caption
				options:(nullable NSDictionary *)options;

- (void)sendDocumentAtPath:(NSString *)path
					toChat:(int64_t)chatId
					thread:(int64_t)threadId
	   directMessagesTopic:(int64_t)directMessagesTopicId
				savedTopic:(int64_t)savedTopicId
				   replyTo:(int64_t)replyToId
				   caption:(NSString *)caption
				   options:(nullable NSDictionary *)options;

- (void)sendPhotoAlbumAtPaths:(NSArray *)paths
					   toChat:(int64_t)chatId
					   thread:(int64_t)threadId
		  directMessagesTopic:(int64_t)directMessagesTopicId
				   savedTopic:(int64_t)savedTopicId
					  replyTo:(int64_t)replyToId
					  caption:(NSString *)caption
					  spoiler:(BOOL)spoiler
		  selfDestructSeconds:(NSInteger)selfDestructSeconds
					  options:(nullable NSDictionary *)options
				   completion:(void (^ _Nullable)(NSInteger sent))completion;

- (void)sendVenueWithTitle:(NSString *)title
				   address:(NSString *)address
				  latitude:(double)latitude
				 longitude:(double)longitude
					toChat:(int64_t)chatId
				   replyTo:(int64_t)replyToId
				   options:(nullable NSDictionary *)options;

- (void)sendLiveLocationWithLatitude:(double)latitude
						   longitude:(double)longitude
							 heading:(NSInteger)heading
							accuracy:(double)accuracy
							  period:(NSInteger)period
							  toChat:(int64_t)chatId
							 replyTo:(int64_t)replyToId
						  completion:(void (^ _Nullable)(int64_t messageId))completion;

- (void)updateLiveLocation:(int64_t)messageId
					inChat:(int64_t)chatId
				  latitude:(double)latitude
				 longitude:(double)longitude
				   heading:(NSInteger)heading
				  accuracy:(double)accuracy
				completion:(void (^ _Nullable)(BOOL ok, NSInteger errorCode))completion;

- (void)stopLiveLocation:(int64_t)messageId
				   inChat:(int64_t)chatId
			   completion:(void (^ _Nullable)(BOOL ok, NSInteger errorCode))completion;

- (void)sendDice:(NSString *)emoji
				 toChat:(int64_t)chatId
				 thread:(int64_t)threadId
	directMessagesTopic:(int64_t)directMessagesTopicId
			 savedTopic:(int64_t)savedTopicId;

#pragma mark - polls

- (void)sendPollWithQuestion:(NSString *)question
					 options:(NSArray * _Nullable)options
				   anonymous:(BOOL)anonymous
			 multipleAnswers:(BOOL)multipleAnswers
		   quizCorrectOption:(NSInteger)quizCorrectOption
			 quizExplanation:(NSString *)quizExplanation
					  toChat:(int64_t)chatId
					  thread:(int64_t)threadId
		 directMessagesTopic:(int64_t)directMessagesTopicId
				  savedTopic:(int64_t)savedTopicId
					 replyTo:(int64_t)replyToId
				 sendOptions:(nullable NSDictionary *)sendOptions
				  completion:(void (^ _Nullable)(int64_t messageId))completion;

- (void)stopPoll:(int64_t)messageId inChat:(int64_t)chatId;

- (void)stopPoll:(int64_t)messageId
		  inChat:(int64_t)chatId
	  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)votersForPollOption:(NSInteger)optionIndex
				  ofMessage:(int64_t)messageId
					 inChat:(int64_t)chatId
					 offset:(NSInteger)offset
					  limit:(NSInteger)limit
				 completion:(void (^ _Nullable)(BOOL ok, NSArray *voters, NSInteger total))completion;

- (void)propertiesOfPollOption:(NSString *)optionId
					 ofMessage:(int64_t)messageId
						inChat:(int64_t)chatId
					completion:(void (^ _Nullable)(BOOL found, BOOL canReply,
								   BOOL canReplyInAnotherChat, BOOL canGetLink))completion;

#pragma mark - links

- (void)linkForMessage:(int64_t)messageId
				inChat:(int64_t)chatId
		mediaTimestamp:(NSInteger)mediaTimestamp
			  forAlbum:(BOOL)forAlbum
			completion:(void (^ _Nullable)(NSString *link))completion;

- (void)resolveMessageLink:(NSString *)url
				completion:(void (^ _Nullable)(NSDictionary *info))completion;

- (void)linkPreviewForText:(NSString *)text
				completion:(void (^ _Nullable)(NSDictionary *preview))completion;

#pragma mark - odds and ends

- (void)bankCardInfoForNumber:(NSString *)cardNumber
				   completion:(void (^ _Nullable)(NSString *title, NSArray *actions))completion;

- (void)translateMessage:(int64_t)messageId
				  inChat:(int64_t)chatId
			  toLanguage:(NSString *)languageCode
			  completion:(void (^ _Nullable)(NSString *text))completion;

- (void)mapThumbnailForLatitude:(double)latitude
					  longitude:(double)longitude
						   zoom:(NSInteger)zoom
						  width:(NSInteger)width
						 height:(NSInteger)height
						  scale:(NSInteger)scale
						 inChat:(int64_t)chatId
					 completion:(void (^ _Nullable)(long long fileId))completion;

- (void)clickAnimatedEmojiInMessage:(int64_t)messageId
							 inChat:(int64_t)chatId
						 completion:(void (^ _Nullable)(long long stickerFileId, BOOL isAnimated))completion;

- (void)storyForMessage:(int64_t)messageId
				 inChat:(int64_t)chatId
			 completion:(void (^ _Nullable)(NSDictionary *story))completion;

@end

NS_ASSUME_NONNULL_END

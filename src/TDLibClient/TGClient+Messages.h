#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const TGQuickReplyShortcutsUpdatedNotification;
extern NSString *const TGQuickReplyShortcutMessagesUpdatedNotification;

NSArray * _Nullable TGWireEntitiesFromFlattened(NSArray * _Nullable flattened);

@interface TGClient (Messages)

#pragma mark - sending

- (void)sendText:(NSString *)text
		  toChat:(int64_t)chatId
		  thread:(int64_t)threadId
	  savedTopic:(int64_t)savedTopicId
		 replyTo:(int64_t)replyToId
		 options:(NSDictionary * _Nullable)options
	  completion:(void (^ _Nullable)(NSDictionary *message))completion;

- (void)sendText:(NSString *)text
		   toChat:(int64_t)chatId
		   thread:(int64_t)threadId
		  replyTo:(int64_t)replyToId
		quoteText:(NSString *)quoteText
	quotePosition:(NSInteger)quotePosition
	   completion:(void (^ _Nullable)(NSDictionary *message))completion;

- (void)sendText:(NSString *)text
		   toChat:(int64_t)chatId
		   thread:(int64_t)threadId
	   savedTopic:(int64_t)savedTopicId
		  replyTo:(int64_t)replyToId
		quoteText:(NSString *)quoteText
	quotePosition:(NSInteger)quotePosition
		  options:(NSDictionary * _Nullable)options
	   completion:(void (^ _Nullable)(NSDictionary *message))completion;

- (void)sendText:(NSString *)text
			toChat:(int64_t)chatId
	replyToMessage:(int64_t)messageId
		  fromChat:(int64_t)sourceChatId
		completion:(void (^ _Nullable)(NSDictionary *message))completion;

- (void)addLocalTextMessage:(NSString *)text
					 toChat:(int64_t)chatId
			   senderUserId:(int64_t)senderUserId
					replyTo:(int64_t)replyToId
				 completion:(void (^ _Nullable)(NSDictionary *message))completion;

- (void)resendMessages:(NSArray *)messageIds
				inChat:(int64_t)chatId
			completion:(void (^ _Nullable)(NSArray *messages))completion;

- (void)resendMessages:(NSArray *)messageIds
				inChat:(int64_t)chatId
			 dropQuote:(BOOL)dropQuote
			completion:(void (^ _Nullable)(NSArray *messages))completion;

- (void)resendMessages:(NSArray *)messageIds
				inChat:(int64_t)chatId
			 dropQuote:(BOOL)dropQuote
		 paidStarCount:(int64_t)paidStarCount
			completion:(void (^ _Nullable)(NSArray *messages))completion;

- (void)sendingStateOfMessage:(int64_t)messageId
					   inChat:(int64_t)chatId
				   completion:(void (^ _Nullable)(NSString *state, BOOL canRetry))completion;

#pragma mark - editing

- (void)replacePhotoInMessage:(int64_t)messageId
					   inChat:(int64_t)chatId
						 path:(NSString *)path
					  caption:(NSString *)caption
					  spoiler:(BOOL)spoiler
				   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)replaceVideoInMessage:(int64_t)messageId
					   inChat:(int64_t)chatId
						 path:(NSString *)path
					  caption:(NSString *)caption
					  spoiler:(BOOL)spoiler
				   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)propertiesOfMessage:(int64_t)messageId
					 inChat:(int64_t)chatId
				 completion:(void (^ _Nullable)(NSDictionary *properties))completion;

- (void)notificationSoundPathForMessage:(int64_t)messageId
								 inChat:(int64_t)chatId
							 completion:(void (^ _Nullable)(NSString *path, NSString *error))completion;

#pragma mark - suggested posts

- (void)approveSuggestedPost:(int64_t)messageId
					  inChat:(int64_t)chatId
				  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)declineSuggestedPost:(int64_t)messageId
					  inChat:(int64_t)chatId
					 comment:(NSString *)comment
				  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)addOfferForMessage:(int64_t)messageId
					inChat:(int64_t)chatId
				 starCount:(int64_t)starCount
				  sendDate:(int64_t)sendDate
				completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - pinning a message

- (void)pinMessage:(int64_t)messageId
			inChat:(int64_t)chatId
		  silently:(BOOL)silently
		 onlyForMe:(BOOL)onlyForMe
		completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)unpinMessage:(int64_t)messageId
			  inChat:(int64_t)chatId
		  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)unpinAllMessagesInChat:(int64_t)chatId
					completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)isMessagePinned:(int64_t)messageId
				 inChat:(int64_t)chatId
			 completion:(void (^ _Nullable)(BOOL pinned))completion;

#pragma mark - deleting

- (void)deleteMessages:(NSArray *)messageIds
				inChat:(int64_t)chatId
		   forEveryone:(BOOL)forEveryone
			completion:(nullable void (^)(BOOL ok))completion;

- (void)deleteMessagesFromUser:(int64_t)userId
						inChat:(int64_t)chatId
					completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)deleteMessagesInChat:(int64_t)chatId
					fromDate:(NSTimeInterval)minDate
					  toDate:(NSTimeInterval)maxDate
				 forEveryone:(BOOL)forEveryone
				  completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - forwarding

- (void)forwardMessages:(NSArray *)messageIds
			   fromChat:(int64_t)fromChatId
				 toChat:(int64_t)toChatId
				 thread:(int64_t)threadId
				 asCopy:(BOOL)asCopy
		 removeCaptions:(BOOL)removeCaptions
				 silent:(BOOL)silent
			 completion:(nullable void (^)(NSArray *messages))completion;

#pragma mark - drafts

- (void)setDraftText:(NSString *)text
			entities:(NSArray *)entities
			 replyTo:(int64_t)replyToId
		   quoteText:(NSString *)quoteText
	   quoteEntities:(NSArray *)quoteEntities
	   quotePosition:(NSInteger)quotePosition
			  inChat:(int64_t)chatId
			  thread:(int64_t)threadId
 directMessagesTopic:(int64_t)directMessagesTopicId
		  savedTopic:(int64_t)savedTopicId;

- (void)clearDraftInChat:(int64_t)chatId
				   thread:(int64_t)threadId
	 directMessagesTopic:(int64_t)directMessagesTopicId
			   savedTopic:(int64_t)savedTopicId;

- (void)draftForChat:(int64_t)chatId
			  thread:(int64_t)threadId
 directMessagesTopic:(int64_t)directMessagesTopicId
		  savedTopic:(int64_t)savedTopicId
		  completion:(void (^ _Nullable)(NSString *text, int64_t replyToId, NSArray *customEmojiRuns,
			  NSArray *mentionRuns, NSString *quoteText, NSArray *quoteEntities,
			  NSInteger quotePosition))completion;

#pragma mark - scheduling

- (void)scheduledMessagesInChat:(int64_t)chatId
					 completion:(void (^ _Nullable)(NSArray *messages, BOOL failed))completion;

- (void)rescheduleMessage:(int64_t)messageId
				   inChat:(int64_t)chatId
				 sendDate:(NSTimeInterval)sendDate
			   whenOnline:(BOOL)whenOnline
			   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)sendScheduledMessageNow:(int64_t)messageId
						 inChat:(int64_t)chatId
					 completion:(void (^ _Nullable)(BOOL ok))completion;

#pragma mark - read state

- (void)markRead:(NSArray *)messageIds
		  inChat:(int64_t)chatId
		  source:(NSString *)source;

- (void)readAllMentionsInChat:(int64_t)chatId;

- (void)readAllMentionsInChat:(int64_t)chatId forumTopicId:(int64_t)topicId;

- (void)readAllReactionsInChat:(int64_t)chatId;

- (void)readAllPollVotesInChat:(int64_t)chatId;

- (void)readDateOfMessage:(int64_t)messageId
				   inChat:(int64_t)chatId
			   completion:(void (^ _Nullable)(NSString *status, NSTimeInterval date))completion;

- (void)viewersOfMessage:(int64_t)messageId
				  inChat:(int64_t)chatId
			  completion:(void (^ _Nullable)(NSArray *viewers, NSString *unavailableReason))completion;

- (void)sendViewMetricsForMessage:(int64_t)messageId
						   inChat:(int64_t)chatId
					 timeInViewMs:(int32_t)timeInViewMs
			   activeTimeInViewMs:(int32_t)activeTimeInViewMs
			  heightRatioPerMille:(int32_t)heightRatioPerMille
				seenRangePerMille:(int32_t)seenRangePerMille;

#pragma mark - typing indicator

- (void)sendChatAction:(NSString *)action toChat:(int64_t)chatId thread:(int64_t)threadId;

#pragma mark - links

- (void)linkForMessage:(int64_t)messageId
				inChat:(int64_t)chatId
			  inThread:(BOOL)inThread
			completion:(void (^ _Nullable)(NSString *link, BOOL isPublic))completion;

- (void)linkForMessage:(int64_t)messageId
				inChat:(int64_t)chatId
		  pollOptionId:(NSString *)pollOptionId
			completion:(void (^ _Nullable)(NSString *link, BOOL isPublic))completion;

#pragma mark - threads

- (void)threadForMessage:(int64_t)messageId
				  inChat:(int64_t)chatId
			  completion:(void (^ _Nullable)(NSDictionary *thread))completion;

#pragma mark - translation

- (void)translateText:(NSString *)text
		   toLanguage:(NSString *)languageCode
		   completion:(void (^ _Nullable)(NSString *text))completion;

#pragma mark - bot buttons

#pragma mark - reporting

- (void)reportMessages:(NSArray *)messageIds
				inChat:(int64_t)chatId
			  optionId:(nullable NSString *)optionId
				  text:(NSString *)text
			completion:(void (^ _Nullable)(NSDictionary *result))completion;

#pragma mark - quick replies

- (void)resetQuickReplyCachesForAccountSwitch;

- (void)addQuickReplyShortcutNamed:(NSString *)name
							  text:(NSString *)text
						  entities:(NSArray *)entities
						completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)editQuickReplyMessage:(int64_t)messageId
					inShortcut:(NSInteger)shortcutId
						  text:(NSString *)text
					  entities:(NSArray *)entities
					completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)sendQuickReplyShortcut:(NSInteger)shortcutId
						toChat:(int64_t)chatId
					completion:(void (^ _Nullable)(NSArray *messages, BOOL ok))completion;

- (void)loadQuickReplyShortcuts;

- (void)checkQuickReplyShortcutName:(NSString *)name completion:(void (^ _Nullable)(BOOL valid))completion;

- (NSArray *)quickReplyShortcuts;

- (void)loadQuickReplyShortcutMessages:(NSInteger)shortcutId;

- (NSArray *)cachedQuickReplyShortcutMessages:(NSInteger)shortcutId;

- (void)deleteQuickReplyShortcutMessages:(NSArray *)messageIds
							  inShortcut:(NSInteger)shortcutId
							  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)retryQuickReplyShortcutMessages:(NSArray *)messageIds
						   shortcutName:(NSString *)shortcutName
							 completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)deleteQuickReplyShortcut:(NSInteger)shortcutId
					  completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)setQuickReplyShortcutName:(NSInteger)shortcutId
							 name:(NSString *)name
					   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)reorderQuickReplyShortcuts:(NSArray *)orderedShortcutIds
						completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)handleQuickReplyUpdate:(NSDictionary *)obj type:(NSString *)type;

- (void)repliedMessageOf:(int64_t)messageId
				  inChat:(int64_t)chatId
			  completion:(void (^ _Nullable)(int64_t repliedMessageId))completion;

- (void)editMessage:(int64_t)messageId inChat:(int64_t)chatId text:(NSString *)text
			entities:(NSArray *)entities
  linkPreviewOptions:(nullable NSDictionary *)linkPreviewOptions
		  completion:(void (^ _Nullable)(BOOL ok))completion;
- (void)setFactCheck:(NSString *)text
		  forMessage:(int64_t)messageId
			  inChat:(int64_t)chatId
		  completion:(void (^ _Nullable)(BOOL ok))completion;
- (void)messageWithId:(int64_t)messageId
			   inChat:(int64_t)chatId
		   completion:(void (^ _Nullable)(NSDictionary *message))completion;
- (void)fetchMessageId:(int64_t)messageId
				 inChat:(int64_t)chatId
			 completion:(void (^ _Nullable)(NSDictionary *message, BOOL confirmedNotFound))completion;
- (void)recentStickersWithCompletion:(void (^ _Nullable)(NSArray *stickers))completion;
- (void)sendStickerWithFileId:(long long)fileId
						toChat:(int64_t)chatId
						thread:(int64_t)threadId
					savedTopic:(int64_t)savedTopicId
					   replyTo:(int64_t)replyToId
					   options:(NSDictionary * _Nullable)options;
- (void)sendVoiceAtPath:(NSString *)path duration:(NSInteger)seconds
			   waveform:(NSData *)waveform
				 toChat:(int64_t)chatId
				 thread:(int64_t)threadId
			 savedTopic:(int64_t)savedTopicId
				options:(NSDictionary * _Nullable)options;
- (void)sendVideoAtPath:(NSString *)path toChat:(int64_t)chatId;
- (void)sendLocation:(double)latitude longitude:(double)longitude toChat:(int64_t)chatId options:(NSDictionary * _Nullable)options;
- (void)sendContactFirstName:(NSString *)firstName
					 lastName:(NSString *)lastName
						phone:(NSString *)phone
						vcard:(NSString *)vcard
					   userId:(int64_t)userId
					   toChat:(int64_t)chatId
					  options:(NSDictionary * _Nullable)options;
- (void)sendPhotoAtPath:(NSString *)path toChat:(int64_t)chatId;
- (void)votePoll:(int64_t)messageId inChat:(int64_t)chatId options:(NSArray *)optionIds;
- (void)votePoll:(int64_t)messageId
		  inChat:(int64_t)chatId
		 options:(NSArray *)optionIds
	  completion:(void (^ _Nullable)(BOOL ok))completion;
- (void)addPollOptionText:(NSString *)text inMessage:(int64_t)messageId chat:(int64_t)chatId;
- (void)addPollOptionText:(NSString *)text
				inMessage:(int64_t)messageId
					 chat:(int64_t)chatId
			   completion:(void (^ _Nullable)(BOOL ok))completion;
- (void)markChecklistTask:(int32_t)taskId
					 done:(BOOL)done
				inMessage:(int64_t)messageId
					 chat:(int64_t)chatId
			   completion:(void (^ _Nullable)(BOOL ok))completion;
- (void)addChecklistTaskId:(int32_t)taskId
					  text:(NSString *)text
				 inMessage:(int64_t)messageId
					  chat:(int64_t)chatId
				completion:(void (^ _Nullable)(BOOL ok))completion;
- (void)replaceChecklistTasks:(NSArray *)tasks
						title:(NSString *)title
				 othersCanAdd:(BOOL)othersCanAdd
				othersCanMark:(BOOL)othersCanMark
					inMessage:(int64_t)messageId
						 chat:(int64_t)chatId
				   completion:(void (^ _Nullable)(BOOL ok))completion;

- (void)sendText:(NSString *)text toChat:(int64_t)chatId;
- (void)sendText:(NSString *)text toChat:(int64_t)chatId thread:(int64_t)threadId;
- (void)sendText:(NSString *)text toChat:(int64_t)chatId
		  thread:(int64_t)threadId
	  savedTopic:(int64_t)savedTopicId
		 replyTo:(int64_t)replyToId;
- (void)markRead:(NSArray *)messageIds inChat:(int64_t)chatId;

@end

NS_ASSUME_NONNULL_END

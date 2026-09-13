#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TGFlattenContext : NSObject

@property (nonatomic, assign) int64_t myUserId;
@property (nonatomic, assign) BOOL ignoresSensitiveContentRestrictions;
@property (nonatomic, copy) NSDictionary *chatsById;

@property (nonatomic, copy) NSString * (^userName)(int64_t userId);
@property (nonatomic, copy) NSString * (^botServiceText)(NSDictionary *message);
@property (nonatomic, copy) NSString * (^secretServiceText)(NSDictionary *message);
@property (nonatomic, copy) NSString * (^localizedFallback)(NSString *key, NSString *fallback);
@property (nonatomic, copy) void (^rememberFileState)(NSDictionary *file);
@property (nonatomic, copy) NSDictionary * (^fileState)(NSDictionary *file);
@property (nonatomic, copy) NSArray * (^reactionChips)(NSDictionary *interactionInfo, int64_t chatId);
@property (nonatomic, copy) NSString * (^reactionSummary)(NSArray *chips);
@property (nonatomic, copy) NSArray * (^flattenedPageBlocks)(NSArray *rawBlocks);

@end

NSData *TGCliBase64(id value);

NSDictionary *TGFlattenPollFields(NSDictionary *poll, NSDictionary * _Nullable content);

NSTimeInterval TGDestructDeadlineFromRemaining(NSTimeInterval remainingSeconds, NSTimeInterval now);
NSTimeInterval TGRemainingSecondsUntilDestruct(NSTimeInterval deadline, NSTimeInterval now);

NSDictionary *TGFlattenMessage(NSDictionary *message, TGFlattenContext *context);
NSString *TGMessagePreview(NSDictionary *message, TGFlattenContext *context);
NSArray *TGFlattenEntities(id raw);

NSString *_Nullable TGMessageContentKindLabel(NSDictionary *_Nullable content);
NSString *_Nullable TGMessageKindLabel(NSString *_Nullable kind);

NSString *TGServiceCallTitle(NSDictionary *content, BOOL mine);
NSString *TGServiceGroupCallTitle(NSDictionary *content, BOOL mine);
NSNumber *TGPollQuizCorrectOptionId(id rawCorrectOptionIds);
BOOL TGMessageIsScheduled(NSDictionary *message);

NSString *_Nullable TGPinnedDescriptorForContentKind(NSString *kind);
NSString *_Nullable TGComposePinnedNotice(NSString *actor, NSString *_Nullable descriptor);

NS_ASSUME_NONNULL_END

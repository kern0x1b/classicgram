#import "TGMessageContent.h"

@class TGPollOption;

@interface TGPollContent : TGMessageContent

@property (nonatomic, readonly, copy) NSString *question;
@property (nonatomic, readonly, copy) NSArray<TGPollOption *> *options;
@property (nonatomic, readonly) NSInteger totalVoterCount;
@property (nonatomic, readonly) BOOL closed;
@property (nonatomic, readonly) BOOL anonymous;
@property (nonatomic, readonly) BOOL canAddOption;
@property (nonatomic, readonly) BOOL quiz;
@property (nonatomic, readonly) BOOL allowsMultipleAnswers;
@property (nonatomic, readonly) BOOL allowsRevoting;
@property (nonatomic, readonly) NSInteger correctOptionId;
@property (nonatomic, readonly, copy) NSString *explanation;
@property (nonatomic, readonly, copy) NSArray *explanationEntities;

- (instancetype)initWithQuestion:(NSString *)question
						 options:(NSArray<TGPollOption *> *)options
				 totalVoterCount:(NSInteger)totalVoterCount
						isClosed:(BOOL)isClosed
					 isAnonymous:(BOOL)isAnonymous
					canAddOption:(BOOL)canAddOption
						  isQuiz:(BOOL)isQuiz
		   allowsMultipleAnswers:(BOOL)allowsMultipleAnswers
				  allowsRevoting:(BOOL)allowsRevoting
				 correctOptionId:(NSInteger)correctOptionId
					 explanation:(NSString *)explanation
			 explanationEntities:(NSArray *)explanationEntities NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

#import "TGPollContent.h"

@implementation TGPollContent

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
			 explanationEntities:(NSArray *)explanationEntities {
	self = [super init];
	if (self != nil) {
		_question = [question copy];
		_options = [options copy];
		_totalVoterCount = totalVoterCount;
		_closed = isClosed;
		_anonymous = isAnonymous;
		_canAddOption = canAddOption;
		_quiz = isQuiz;
		_allowsMultipleAnswers = allowsMultipleAnswers;
		_allowsRevoting = allowsRevoting;
		_correctOptionId = correctOptionId;
		_explanation = [explanation copy];
		_explanationEntities = [explanationEntities copy];
	}
	return self;
}

@end

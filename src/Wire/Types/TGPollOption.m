#import "TGPollOption.h"

@implementation TGPollOption

- (instancetype)initWithOptionId:(NSString *)optionId
							text:(NSString *)text
				  votePercentage:(NSInteger)votePercentage
						isChosen:(BOOL)isChosen {
	self = [super init];
	if (self != nil) {
		_optionId = [optionId copy];
		_text = [text copy];
		_votePercentage = votePercentage;
		_chosen = isChosen;
	}
	return self;
}

@end

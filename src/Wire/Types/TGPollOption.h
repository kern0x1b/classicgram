#import <Foundation/Foundation.h>

@interface TGPollOption : NSObject

@property (nonatomic, readonly, copy) NSString *optionId;
@property (nonatomic, readonly, copy) NSString *text;
@property (nonatomic, readonly) NSInteger votePercentage;
@property (nonatomic, readonly) BOOL chosen;

- (instancetype)initWithOptionId:(NSString *)optionId
							text:(NSString *)text
				  votePercentage:(NSInteger)votePercentage
						isChosen:(BOOL)isChosen NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

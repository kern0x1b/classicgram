#import <UIKit/UIKit.h>

@interface TGMentionSuggestionStrip : UIView

@property (nonatomic, copy) void (^onCandidatePicked)(NSDictionary *candidate);

@property (nonatomic, copy) void (^onVisibilityChanged)(BOOL visible);

+ (CGFloat)heightForCandidateCount:(NSUInteger)count;

- (void)showCandidates:(NSArray *)candidates;

- (void)clear;

@end

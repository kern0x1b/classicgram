#import "TGMessageContent.h"

@interface TGRichMessageContent : TGMessageContent

@property (nonatomic, readonly, copy) NSArray *rawBlocks;
@property (nonatomic, readonly) BOOL fullView;
@property (nonatomic, readonly) BOOL rightToLeft;
@property (nonatomic, readonly, copy) NSString *kicker;
@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly, copy) NSString *subtitle;
@property (nonatomic, readonly, copy) NSString *snippet;
@property (nonatomic, readonly) int64_t coverFileId;
@property (nonatomic, readonly) NSInteger coverWidth;
@property (nonatomic, readonly) NSInteger coverHeight;

- (instancetype)initWithRawBlocks:(NSArray *)rawBlocks
					   isFullView:(BOOL)isFullView
					isRightToLeft:(BOOL)isRightToLeft
						   kicker:(NSString *)kicker
							title:(NSString *)title
						 subtitle:(NSString *)subtitle
						  snippet:(NSString *)snippet
					  coverFileId:(int64_t)coverFileId
					   coverWidth:(NSInteger)coverWidth
					  coverHeight:(NSInteger)coverHeight NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

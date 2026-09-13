#import "TGMessageContent.h"

@interface TGLocationContent : TGMessageContent

@property (nonatomic, readonly) double latitude;
@property (nonatomic, readonly) double longitude;

- (instancetype)initWithLatitude:(double)latitude
					   longitude:(double)longitude NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

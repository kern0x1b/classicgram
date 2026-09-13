#import "TGLocationContent.h"

@interface TGLiveLocationContent : TGLocationContent

@property (nonatomic, readonly) NSInteger period;
@property (nonatomic, readonly) NSInteger expiresIn;
@property (nonatomic, readonly) NSInteger heading;

- (instancetype)initWithLatitude:(double)latitude
					   longitude:(double)longitude
						  period:(NSInteger)period
					   expiresIn:(NSInteger)expiresIn
						 heading:(NSInteger)heading NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithLatitude:(double)latitude
					   longitude:(double)longitude NS_UNAVAILABLE;

@end

#import "TGLiveLocationContent.h"

@implementation TGLiveLocationContent

- (instancetype)initWithLatitude:(double)latitude
					   longitude:(double)longitude
						  period:(NSInteger)period
					   expiresIn:(NSInteger)expiresIn
						 heading:(NSInteger)heading {
	self = [super initWithLatitude:latitude longitude:longitude];
	if (self != nil) {
		_period = period;
		_expiresIn = expiresIn;
		_heading = heading;
	}
	return self;
}

@end

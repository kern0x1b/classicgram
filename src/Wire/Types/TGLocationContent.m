#import "TGLocationContent.h"

@implementation TGLocationContent

- (instancetype)initWithLatitude:(double)latitude
					   longitude:(double)longitude {
	self = [super init];
	if (self != nil) {
		_latitude = latitude;
		_longitude = longitude;
	}
	return self;
}

@end

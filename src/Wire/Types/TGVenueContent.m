#import "TGVenueContent.h"

@implementation TGVenueContent

- (instancetype)initWithLatitude:(double)latitude
					   longitude:(double)longitude
						   title:(NSString *)title
						 address:(NSString *)address {
	self = [super initWithLatitude:latitude longitude:longitude];
	if (self != nil) {
		_title = [title copy];
		_address = [address copy];
	}
	return self;
}

@end

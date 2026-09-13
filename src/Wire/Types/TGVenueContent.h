#import "TGLocationContent.h"

@interface TGVenueContent : TGLocationContent

@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly, copy) NSString *address;

- (instancetype)initWithLatitude:(double)latitude
					   longitude:(double)longitude
						   title:(NSString *)title
						 address:(NSString *)address NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithLatitude:(double)latitude
					   longitude:(double)longitude NS_UNAVAILABLE;

@end

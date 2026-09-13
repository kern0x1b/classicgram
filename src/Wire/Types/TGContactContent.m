#import "TGContactContent.h"

@implementation TGContactContent

- (instancetype)initWithFirstName:(NSString *)firstName
						 lastName:(NSString *)lastName
					  phoneNumber:(NSString *)phoneNumber
						   userId:(int64_t)userId
							vcard:(NSString *)vcard {
	self = [super init];
	if (self != nil) {
		_firstName = [firstName copy];
		_lastName = [lastName copy];
		_phoneNumber = [phoneNumber copy];
		_userId = userId;
		_vcard = [vcard copy];
	}
	return self;
}

@end

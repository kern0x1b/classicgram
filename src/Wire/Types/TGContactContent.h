#import "TGMessageContent.h"

@interface TGContactContent : TGMessageContent

@property (nonatomic, readonly, copy) NSString *firstName;
@property (nonatomic, readonly, copy) NSString *lastName;
@property (nonatomic, readonly, copy) NSString *phoneNumber;
@property (nonatomic, readonly) int64_t userId;
@property (nonatomic, readonly, copy) NSString *vcard;

- (instancetype)initWithFirstName:(NSString *)firstName
						 lastName:(NSString *)lastName
					  phoneNumber:(NSString *)phoneNumber
						   userId:(int64_t)userId
							vcard:(NSString *)vcard NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

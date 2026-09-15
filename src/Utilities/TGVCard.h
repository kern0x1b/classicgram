#import <Foundation/Foundation.h>

NSString *TGVCardEscaped(NSString *value);

NSString *TGVCardForContact(NSString *firstName, NSString *lastName, NSString *phoneNumber,
	NSString *username);

NSString *TGVCardFileNameForContact(NSString *firstName, NSString *lastName);

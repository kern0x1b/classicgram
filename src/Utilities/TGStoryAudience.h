#import <Foundation/Foundation.h>

BOOL TGStoryAudienceAllowsExceptions(NSString *privacy);

NSArray *TGStoryAudienceExceptionsAfterChange(NSString *fromPrivacy,
	NSString *toPrivacy,
	NSArray *userIds);

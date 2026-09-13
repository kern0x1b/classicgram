#import "TGFlattenSecretChats.h"
#import "TGBase64.h"

static NSDictionary *TGFSCDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSString *TGFSCString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

NSString *TGScStateName(NSDictionary *secretChat) {
	NSString *type = TGFSCString(TGFSCDict(secretChat[@"state"])[@"@type"]);
	if ([type isEqualToString:@"secretChatStateReady"])
		return @"ready";
	if ([type isEqualToString:@"secretChatStateClosed"])
		return @"closed";
	return @"pending";
}

NSData *TGScBase64Decode(NSString *string) {
	return TGBase64Decode(string);
}

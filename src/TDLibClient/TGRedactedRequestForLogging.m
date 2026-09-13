#import "TGRedactedRequestForLogging.h"

static NSSet *TGSensitiveFieldNames(void) {
	static NSSet *fieldNames = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		fieldNames = [NSSet setWithObjects:
			@"password", @"old_password", @"new_password", @"secret",
			@"code", @"recovery_code", @"phone_number",
			@"api_hash", @"database_encryption_key",
			@"email_address", @"new_login_email_address", @"new_recovery_email_address", nil];
	});
	return fieldNames;
}

static id TGRedactedValueForLogging(id value) {
	if ([value isKindOfClass:NSDictionary.class])
		return TGRedactedRequestForLogging(value);
	if ([value isKindOfClass:NSArray.class]) {
		NSMutableArray *redacted = [NSMutableArray arrayWithCapacity:[(NSArray *)value count]];
		for (id item in (NSArray *)value)
			[redacted addObject:TGRedactedValueForLogging(item)];
		return redacted;
	}
	return value;
}

NSDictionary *TGRedactedRequestForLogging(NSDictionary *request) {
	if (![request isKindOfClass:NSDictionary.class])
		return request;

	NSSet *fieldNames = TGSensitiveFieldNames();
	NSMutableDictionary *redacted = [NSMutableDictionary dictionaryWithCapacity:request.count];
	[request enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
		if ([fieldNames containsObject:key] && [value isKindOfClass:NSString.class])
			redacted[key] = @"<redacted>";
		else
			redacted[key] = TGRedactedValueForLogging(value);
	}];
	return redacted;
}

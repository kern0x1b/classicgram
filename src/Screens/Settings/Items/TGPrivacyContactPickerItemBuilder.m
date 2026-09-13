#import "TGPrivacyContactPickerItemBuilder.h"
#import "TGPrivacyContactPickerCellCatalogue.h"
#import "TGLocalization.h"

@implementation TGPrivacyContactPickerItemBuilder

+ (NSString *)nameOfUser:(NSDictionary *)user {
	NSMutableString *name = [NSMutableString string];
	id first = user[@"first_name"];
	id last = user[@"last_name"];
	if ([first isKindOfClass:[NSString class]])
		[name appendString:first];
	if ([last isKindOfClass:[NSString class]] && [last length]) {
		if (name.length)
			[name appendString:@" "];
		[name appendString:last];
	}
	if (!name.length) {
		id username = user[@"username"];
		if ([username isKindOfClass:[NSString class]] && [username length])
			return username;
		return TGL(@"Contacts.UnknownName", @"Unknown");
	}
	return name;
}

+ (TGPrivacyContactPickerItem *)itemFromUser:(NSDictionary *)user chosen:(NSArray *)chosen {
	id userId = user[@"id"];
	int64_t resolvedUserId = [userId isKindOfClass:[NSNumber class]] ? [userId longLongValue] : 0;
	BOOL isChosen = userId && [chosen containsObject:userId];

	TGPrivacyContactPickerItem *bareItem = [TGPrivacyContactPickerItem alloc];
	return [bareItem initWithKind:TGPrivacyContactPickerRowKindContact
				  reuseIdentifier:[TGPrivacyContactPickerCellCatalogue reuseIdentifierForKind:TGPrivacyContactPickerRowKindContact]
						cellClass:[TGPrivacyContactPickerCellCatalogue cellClassForKind:TGPrivacyContactPickerRowKindContact]
						   userId:resolvedUserId
						titleText:[self nameOfUser:user]
						 isChosen:isChosen];
}

@end

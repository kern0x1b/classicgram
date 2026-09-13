#import "TGSupergroupUsernamesItemBuilder.h"
#import "TGSupergroupUsernamesCellCatalogue.h"

@implementation TGSupergroupUsernamesItemBuilder

+ (TGSupergroupUsernamesItem *)itemFromUsername:(NSString *)username badgeText:(NSString *)badgeText {
	NSString *displayText = [NSString stringWithFormat:@"@%@", username];

	TGSupergroupUsernamesItem *item = [TGSupergroupUsernamesItem alloc];
	return [item initWithKind:TGSupergroupUsernamesRowKindUsername
			  reuseIdentifier:[TGSupergroupUsernamesCellCatalogue reuseIdentifierForKind:TGSupergroupUsernamesRowKindUsername]
					cellClass:[TGSupergroupUsernamesCellCatalogue cellClassForKind:TGSupergroupUsernamesRowKindUsername]
					 username:username
				  displayText:displayText
					badgeText:badgeText];
}

@end

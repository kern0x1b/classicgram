#import "TGAccountUsernamesItemBuilder.h"
#import "TGAccountUsernamesCellCatalogue.h"

@implementation TGAccountUsernamesItemBuilder

+ (TGAccountUsernamesItem *)itemFromUsername:(NSString *)username
						  showsEditableBadge:(BOOL)showsEditableBadge {
	NSString *displayText = [NSString stringWithFormat:@"@%@", username];

	return [[TGAccountUsernamesItem alloc] initWithKind:TGAccountUsernamesRowKindUsername
										reuseIdentifier:[TGAccountUsernamesCellCatalogue reuseIdentifierForKind:TGAccountUsernamesRowKindUsername]
											  cellClass:[TGAccountUsernamesCellCatalogue cellClassForKind:TGAccountUsernamesRowKindUsername]
											   username:username
											displayText:displayText
									 showsEditableBadge:showsEditableBadge];
}

@end

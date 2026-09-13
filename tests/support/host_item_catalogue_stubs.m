#import "UIKit.h"
#import "TGAccountUsernamesCellCatalogue.h"
#import "TGConnectedWebsitesCellCatalogue.h"
#import "TGHiddenStoriesCellCatalogue.h"
#import "TGNewGroupMembersCellCatalogue.h"
#import "TGOwnedSetsCellCatalogue.h"
#import "TGPrivacyContactPickerCellCatalogue.h"
#import "TGStarsListCellCatalogue.h"
#import "TGStorageDownloadsCellCatalogue.h"
#import "TGStoryViewersCellCatalogue.h"
#import "TGSupergroupUsernamesCellCatalogue.h"

static NSString *TGHostCatalogueIdentifier(NSString *screen, NSInteger kind) {
	return [NSString stringWithFormat:@"%@.%ld", screen, (long)kind];
}

@implementation TGAccountUsernamesCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGAccountUsernamesRowKind)kind {
	return TGHostCatalogueIdentifier(@"AccountUsernames", kind);
}

+ (Class)cellClassForKind:(TGAccountUsernamesRowKind)kind {
	return [NSObject class];
}

@end

@implementation TGConnectedWebsitesCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGConnectedWebsitesRowKind)kind {
	return TGHostCatalogueIdentifier(@"ConnectedWebsites", kind);
}

+ (Class)cellClassForKind:(TGConnectedWebsitesRowKind)kind {
	return [NSObject class];
}

@end

@implementation TGHiddenStoriesCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGHiddenStoriesRowKind)kind {
	return TGHostCatalogueIdentifier(@"HiddenStories", kind);
}

+ (Class)cellClassForKind:(TGHiddenStoriesRowKind)kind {
	return [NSObject class];
}

@end

@implementation TGNewGroupMembersCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGNewGroupMembersRowKind)kind {
	return TGHostCatalogueIdentifier(@"NewGroupMembers", kind);
}

+ (Class)cellClassForKind:(TGNewGroupMembersRowKind)kind {
	return [NSObject class];
}

@end

@implementation TGOwnedSetsCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGOwnedSetsRowKind)kind {
	return TGHostCatalogueIdentifier(@"OwnedSets", kind);
}

+ (Class)cellClassForKind:(TGOwnedSetsRowKind)kind {
	return [NSObject class];
}

+ (UITableViewCellStyle)cellStyleForKind:(TGOwnedSetsRowKind)kind {
	return UITableViewCellStyleDefault;
}

@end

@implementation TGPrivacyContactPickerCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGPrivacyContactPickerRowKind)kind {
	return TGHostCatalogueIdentifier(@"PrivacyContactPicker", kind);
}

+ (Class)cellClassForKind:(TGPrivacyContactPickerRowKind)kind {
	return [NSObject class];
}

@end

@implementation TGStarsListCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGStarsListRowKind)kind {
	return TGHostCatalogueIdentifier(@"StarsList", kind);
}

+ (Class)cellClassForKind:(TGStarsListRowKind)kind {
	return [NSObject class];
}

+ (UITableViewCellStyle)cellStyleForKind:(TGStarsListRowKind)kind {
	return UITableViewCellStyleDefault;
}

@end

@implementation TGStorageDownloadsCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGStorageDownloadsRowKind)kind {
	return TGHostCatalogueIdentifier(@"StorageDownloads", kind);
}

+ (Class)cellClassForKind:(TGStorageDownloadsRowKind)kind {
	return [NSObject class];
}

+ (UITableViewCellStyle)cellStyleForKind:(TGStorageDownloadsRowKind)kind {
	return UITableViewCellStyleDefault;
}

@end

@implementation TGStoryViewersCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGStoryViewersRowKind)kind {
	return TGHostCatalogueIdentifier(@"StoryViewers", kind);
}

+ (Class)cellClassForKind:(TGStoryViewersRowKind)kind {
	return [NSObject class];
}

@end

@implementation TGSupergroupUsernamesCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGSupergroupUsernamesRowKind)kind {
	return TGHostCatalogueIdentifier(@"SupergroupUsernames", kind);
}

+ (Class)cellClassForKind:(TGSupergroupUsernamesRowKind)kind {
	return [NSObject class];
}

@end

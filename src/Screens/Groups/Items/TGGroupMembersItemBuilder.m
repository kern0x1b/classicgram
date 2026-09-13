#import "TGGroupMembersItemBuilder.h"
#import "TGStringTruncation.h"
#import "TGGroupMemberCell.h"
#import "TGMembersStatusText.h"
#import "TGMembersStatusText.h"
#import "TGIcons.h"
#import "TGLocalization.h"

static NSString *TGGroupMembersReuseIdentifierForKind(TGGroupMembersRowKind kind) {
	switch (kind) {
		case TGGroupMembersRowKindMember:
			return @"TGGroupMembersRow.Member";
	}
	return nil;
}

static Class TGGroupMembersCellClassForKind(TGGroupMembersRowKind kind) {
	switch (kind) {
		case TGGroupMembersRowKindMember:
			return [TGGroupMemberCell class];
	}
	return nil;
}

@implementation TGGroupMembersItemBuilder

+ (TGGroupMembersItem *)itemFromMember:(NSDictionary *)member {
	NSString *name = TGMembersString(member, @"name");
	if (!name.length)
		name = TGL(@"Contacts.UnknownName", @"Unknown");
	long long userId = TGMembersUserId(member);

	UIImage *avatarPlaceholder =
		[TGIcons avatarWithInitials:TGSafeFirstCharacter(name).uppercaseString
							   size:kMemberAvatar
						   colourId:userId];

	return [[TGGroupMembersItem alloc] initWithKind:TGGroupMembersRowKindMember
									reuseIdentifier:TGGroupMembersReuseIdentifierForKind(TGGroupMembersRowKindMember)
										  cellClass:TGGroupMembersCellClassForKind(TGGroupMembersRowKindMember)
											 userId:userId
										  titleText:name
									   subtitleText:TGMembersStatusText(member)
							   subtitleIsOnline:TGMembersStatusIsOnline(member)
								       roleText:TGMembersRoleText(member)
								  avatarPlaceholder:avatarPlaceholder];
}

@end

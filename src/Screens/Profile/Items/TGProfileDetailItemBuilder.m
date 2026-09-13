#import "TGProfileDetailItemBuilder.h"
#import "TGProfileDetailCellCatalogue.h"
#import "TGLocalization.h"
#import "TGHexColour.h"

@implementation TGProfileDetailItemBuilder

+ (NSString *)displayLabelForKind:(NSString *)kind {
	if ([kind isEqualToString:@"mobile"])
		return TGL(@"Profile.LabelMobile", @"mobile");
	if ([kind isEqualToString:@"about"])
		return TGL(@"Profile.LabelBio", @"bio");
	if ([kind isEqualToString:@"username"])
		return TGL(@"Profile.LabelUsername", @"username");
	if ([kind isEqualToString:@"groups in common"])
		return TGL(@"Profile.LabelGroups", @"groups");
	if ([kind isEqualToString:@"invite link"])
		return TGL(@"Profile.LabelLink", @"link");
	if ([kind isEqualToString:@"song"])
		return TGL(@"Profile.SongLabel", @"song");
	if ([kind isEqualToString:@"note"])
		return TGL(@"Profile.LabelNotes", @"notes");
	if ([kind isEqualToString:@"members"])
		return TGL(@"Profile.LabelMembers", @"members");
	if ([kind isEqualToString:@"admins"])
		return TGL(@"Profile.LabelAdmins", @"admins");
	if ([kind isEqualToString:@"subscription"])
		return TGL(@"Profile.SubscriptionLabel", @"subscription");
	if ([kind isEqualToString:@"birthday"])
		return TGL(@"Profile.LabelBirthday", @"birthday");
	if ([kind isEqualToString:@"status"])
		return TGL(@"Profile.LabelStatus", @"status");
	if ([kind isEqualToString:@"restricted"])
		return TGL(@"Profile.RestrictedLabel", @"restricted");
	if ([kind isEqualToString:@"contact"])
		return TGL(@"Profile.ContactLabel", @"contact");
	if ([kind isEqualToString:@"gift"])
		return TGL(@"Profile.LabelGift", @"gift");
	return kind;
}

+ (TGProfileDetailItem *)itemFromPair:(NSArray *)pair isSongPlaying:(BOOL)isSongPlaying {
	if (pair.count < 2)
		return nil;

	NSString *label = pair[0];
	NSString *value = pair[1];

	BOOL opens = [label isEqualToString:@"note"] || [label isEqualToString:@"groups in common"] || [label isEqualToString:@"invite link"] || [label isEqualToString:@"username"];
	BOOL isPhone = [label isEqualToString:@"mobile"];
	BOOL hiddenPhone = isPhone && pair.count > 2 && [pair[2] boolValue];
	BOOL isSong = [label isEqualToString:@"song"];
	BOOL isSelectable = opens || isSong || (isPhone && !hiddenPhone);

	if (isSong)
		value = [NSString stringWithFormat:@"%@  %@", (isSongPlaying ? @"⏸" : @"▶"), value ?: @""];

	UIColor *valueTextColor = hiddenPhone ? TGColourFromHex(0xaaaaaa)
										  : (isPhone ? TGColourFromHex(0x347fd4) : [UIColor blackColor]);

	return [[TGProfileDetailItem alloc] initWithKind:TGProfileDetailRowKindPlain
									 reuseIdentifier:[TGProfileDetailCellCatalogue reuseIdentifierForKind:TGProfileDetailRowKindPlain]
										   cellClass:[TGProfileDetailCellCatalogue cellClassForKind:TGProfileDetailRowKindPlain]
										   labelText:[self displayLabelForKind:label]
										   valueText:value
									  valueTextColor:valueTextColor
									 showsDisclosure:opens
										isSelectable:isSelectable
								  interactionEnabled:!hiddenPhone];
}

@end

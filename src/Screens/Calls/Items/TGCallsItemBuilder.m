#import "TGCallsItemBuilder.h"
#import "TGCallsRowText.h"
#import "TGCallListCell.h"
#import "TGDateUtils.h"
#import "TGIcons.h"
#import "TGLocalization.h"

static NSString *TGCallsReuseIdentifierForKind(TGCallsRowKind kind) {
	switch (kind) {
		case TGCallsRowKindGroup:
			return @"TGCallsRow.Group";
	}
	return nil;
}

@implementation TGCallsItemBuilder

+ (TGCallsItem *)itemFromGroup:(NSDictionary *)group {
	NSString *name = TGCallsDisplayName(group);
	NSInteger count = [group[@"calls"] count];
	NSDictionary *newest = [group[@"calls"] firstObject] ?: group;

	UIColor *nameColour = TGCallsWasMissedByMe(group)
		? TGCallsMissedColour()
		: [UIColor blackColor];
	NSString *countText = count > 1
		? [NSString stringWithFormat:@"(%d)", (int)count]
		: nil;
	NSString *dateText = [TGDateUtils stringForMessageListDate:[group[@"date"] intValue]];
	NSString *subtitleText = count > 1
		? TGCallsKindText(newest)
		: TGCallsSubtitleText(newest);
	UIImage *arrowImage = [TGIcons callArrowOutgoing:[group[@"outgoing"] boolValue]
											  missed:TGCallsWasMissedByMe(group)];

	NSNumber *avatarKey = [group[@"userId"] isKindOfClass:NSNumber.class] ? group[@"userId"] : nil;
	UIImage *avatarPlaceholder =
		[TGIcons avatarWithInitials:TGCallsInitials(name)
							   size:kCallAvatarSide
						   colourId:[avatarKey longLongValue]];

	return [[TGCallsItem alloc] initWithKind:TGCallsRowKindGroup
							 reuseIdentifier:TGCallsReuseIdentifierForKind(TGCallsRowKindGroup)
								   cellClass:[TGCallListCell class]
									nameText:name
								  nameColour:nameColour
								   countText:countText
									dateText:dateText
								subtitleText:subtitleText
								  arrowImage:arrowImage
								   avatarKey:avatarKey
						   avatarPlaceholder:avatarPlaceholder];
}

@end

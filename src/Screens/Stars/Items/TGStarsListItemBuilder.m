#import "TGStarsListItemBuilder.h"
#import "TGStarsListCellCatalogue.h"
#import "TGLocalization.h"

@implementation TGStarsListItemBuilder

+ (TGStarsListItem *)itemFromRow:(NSDictionary *)row {
	NSString *badge = row[@"badge"];
	if (badge.length > 0)
		return nil;

	NSString *subtitle = row[@"subtitle"];
	BOOL hasSubtitle = subtitle.length > 0;
	TGStarsListRowKind kind = hasSubtitle ? TGStarsListRowKindSubtitle : TGStarsListRowKindValue;
	NSString *detailText = hasSubtitle ? subtitle : row[@"value"];
	BOOL isTappable = row[@"block"] != nil;
	BOOL isDestructive = [row[@"destructive"] boolValue];

	return [[TGStarsListItem alloc] initWithKind:kind
								 reuseIdentifier:[TGStarsListCellCatalogue reuseIdentifierForKind:kind]
									   cellClass:[TGStarsListCellCatalogue cellClassForKind:kind]
									   titleText:row[@"title"]
									  detailText:detailText
								   isDestructive:isDestructive
									  isTappable:isTappable
								 statusIsLoading:NO
									statusIsMore:NO];
}

+ (TGStarsListItem *)itemForStatusLoading:(BOOL)loading isMoreRow:(BOOL)isMoreRow emptyText:(NSString *)emptyText {
	NSString *titleText;
	if (loading)
		titleText = TGL(@"Channel.NotificationLoading", @"Loading…");
	else if (isMoreRow)
		titleText = TGL(@"Chat.RichText.ShowMore", @"Show more");
	else
		titleText = emptyText;

	return [[TGStarsListItem alloc] initWithKind:TGStarsListRowKindStatus
								 reuseIdentifier:[TGStarsListCellCatalogue reuseIdentifierForKind:TGStarsListRowKindStatus]
									   cellClass:[TGStarsListCellCatalogue cellClassForKind:TGStarsListRowKindStatus]
									   titleText:titleText
									  detailText:nil
								   isDestructive:NO
									  isTappable:NO
								 statusIsLoading:loading
									statusIsMore:isMoreRow];
}

@end

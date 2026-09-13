#import "TGStoryViewersItemBuilder.h"
#import "TGStoryViewersCellCatalogue.h"
#import "TGStoryHelpers.h"

@implementation TGStoryViewersItemBuilder

+ (TGStoryViewersItem *)itemFromRow:(NSDictionary *)row {
	NSString *name = TGStoryString(row, @"name");
	NSString *emoji = TGStoryString(row, @"emoji");
	NSString *titleText = emoji.length > 0
		? [NSString stringWithFormat:@"%@  %@", name, emoji]
		: name;
	NSString *detailText = TGStoryAgeText((int)TGStoryNumber(row, @"date"));

	return [[TGStoryViewersItem alloc] initWithKind:TGStoryViewersRowKindViewer
									reuseIdentifier:[TGStoryViewersCellCatalogue reuseIdentifierForKind:TGStoryViewersRowKindViewer]
										  cellClass:[TGStoryViewersCellCatalogue cellClassForKind:TGStoryViewersRowKindViewer]
										  titleText:titleText
										 detailText:detailText];
}

@end

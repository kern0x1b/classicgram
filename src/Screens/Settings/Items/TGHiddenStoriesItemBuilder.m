#import "TGHiddenStoriesItemBuilder.h"
#import "TGHiddenStoriesCellCatalogue.h"
#import "TGLocalization.h"

@implementation TGHiddenStoriesItemBuilder

+ (TGHiddenStoriesItem *)itemFromPoster:(NSDictionary *)poster {
	id name = poster[@"name"];
	NSString *titleText = [name isKindOfClass:[NSString class]] ? name : TGL(@"User.DeletedAccount", @"Deleted Account");

	id posterId = poster[@"id"];
	int64_t resolvedPosterId = [posterId isKindOfClass:[NSNumber class]] ? [posterId longLongValue] : 0;
	BOOL posterIsChat = [poster[@"isChat"] boolValue];

	return [[TGHiddenStoriesItem alloc] initWithKind:TGHiddenStoriesRowKindPoster
									 reuseIdentifier:[TGHiddenStoriesCellCatalogue reuseIdentifierForKind:TGHiddenStoriesRowKindPoster]
										   cellClass:[TGHiddenStoriesCellCatalogue cellClassForKind:TGHiddenStoriesRowKindPoster]
											posterId:resolvedPosterId
										posterIsChat:posterIsChat
										   titleText:titleText];
}

@end

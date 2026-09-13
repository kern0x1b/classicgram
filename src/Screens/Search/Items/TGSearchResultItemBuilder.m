#import "TGSearchResultItemBuilder.h"
#import "TGStringTruncation.h"
#import "TGSearchResultCellCatalogue.h"
#import "TGSearchRowMetrics.h"
#import "TGIcons.h"

@implementation TGSearchResultItemBuilder

+ (TGSearchResultItem *)itemFromRow:(NSDictionary *)row isMessage:(BOOL)isMessage {
	if (isMessage)
		return [self itemFromMessageRow:row];
	return [self itemFromGenericRow:row];
}

+ (TGSearchResultItem *)itemFromMessageRow:(NSDictionary *)row {
	NSString *title = [row[@"title"] isKindOfClass:NSString.class] ? row[@"title"] : @"";
	NSString *author = [row[@"author"] isKindOfClass:NSString.class] ? row[@"author"] : @"";
	NSString *subtitle = [row[@"subtitle"] isKindOfClass:NSString.class] ? row[@"subtitle"] : @"";
	NSString *date = [row[@"date"] isKindOfClass:NSString.class] ? row[@"date"] : @"";
	int64_t chatId = [row[@"chatId"] longLongValue];
	NSNumber *fileId = [row[@"fileId"] isKindOfClass:NSNumber.class] ? row[@"fileId"] : nil;

	return [[TGSearchResultItem alloc] initWithKind:TGSearchRowKindMessage
									reuseIdentifier:[TGSearchResultCellCatalogue reuseIdentifierForKind:TGSearchRowKindMessage]
										  cellClass:[TGSearchResultCellCatalogue cellClassForKind:TGSearchRowKindMessage]
										 titleFirst:title
										titleSecond:nil
										 authorText:author
									   subtitleText:subtitle
										   dateText:date
									 avatarColourId:chatId
										avatarTitle:title
									   avatarFileId:fileId
								avatarIsPrecomputed:NO
								  avatarPrecomputed:nil];
}

+ (TGSearchResultItem *)itemFromGenericRow:(NSDictionary *)row {
	NSString *title = [row[@"title"] isKindOfClass:NSString.class] ? row[@"title"] : @"";
	NSString *subtitle = [row[@"subtitle"] isKindOfClass:NSString.class] ? row[@"subtitle"] : @"";
	NSString *date = [row[@"date"] isKindOfClass:NSString.class] ? row[@"date"] : @"";
	int64_t colourId = [row[@"chatId"] longLongValue];
	if (!colourId)
		colourId = [row[@"userId"] longLongValue];

	NSString *nameFirst = [row[@"firstName"] isKindOfClass:NSString.class] ? row[@"firstName"] : @"";
	NSString *nameLast = [row[@"lastName"] isKindOfClass:NSString.class] ? row[@"lastName"] : @"";
	NSString *titleFirst;
	NSString *titleSecond;
	if (nameFirst.length || nameLast.length) {
		titleFirst = nameFirst.length ? nameFirst : nameLast;
		titleSecond = nameFirst.length ? nameLast : nil;
	} else {
		titleFirst = title;
		titleSecond = nil;
	}

	NSString *hashtagRow = [row[@"hashtag"] isKindOfClass:NSString.class] ? row[@"hashtag"] : nil;
	if (hashtagRow.length) {
		NSString *initial = TGSafeFirstCharacter(hashtagRow);
		UIImage *avatar = [TGIcons avatarWithInitials:initial
												 size:kSearchAvatar
											 colourId:(int64_t)hashtagRow.hash];
		return [[TGSearchResultItem alloc] initWithKind:TGSearchRowKindGeneric
										reuseIdentifier:[TGSearchResultCellCatalogue reuseIdentifierForKind:TGSearchRowKindGeneric]
											  cellClass:[TGSearchResultCellCatalogue cellClassForKind:TGSearchRowKindGeneric]
											 titleFirst:titleFirst
											titleSecond:titleSecond
											 authorText:nil
										   subtitleText:subtitle
											   dateText:date
										 avatarColourId:0
											avatarTitle:nil
										   avatarFileId:nil
									avatarIsPrecomputed:YES
									  avatarPrecomputed:avatar];
	}

	NSNumber *fileId = [row[@"fileId"] isKindOfClass:NSNumber.class] ? row[@"fileId"] : nil;

	return [[TGSearchResultItem alloc] initWithKind:TGSearchRowKindGeneric
									reuseIdentifier:[TGSearchResultCellCatalogue reuseIdentifierForKind:TGSearchRowKindGeneric]
										  cellClass:[TGSearchResultCellCatalogue cellClassForKind:TGSearchRowKindGeneric]
										 titleFirst:titleFirst
										titleSecond:titleSecond
										 authorText:nil
									   subtitleText:subtitle
										   dateText:date
									 avatarColourId:colourId
										avatarTitle:title
									   avatarFileId:fileId
								avatarIsPrecomputed:NO
								  avatarPrecomputed:nil];
}

@end

#import "TGOwnedSetsItemBuilder.h"
#import "TGStringTruncation.h"
#import "TGOwnedSetsCellCatalogue.h"
#import "TGLocalization.h"
#import "TGIcons.h"

static const CGFloat kOwnedSetsCoverSide = 40.0f;

@implementation TGOwnedSetsItemBuilder

+ (TGOwnedSetsItem *)itemForCreateRow {
	return [[TGOwnedSetsItem alloc]
				initWithKind:TGOwnedSetsRowKindCreate
			 reuseIdentifier:[TGOwnedSetsCellCatalogue reuseIdentifierForKind:TGOwnedSetsRowKindCreate]
				   cellClass:[TGOwnedSetsCellCatalogue cellClassForKind:TGOwnedSetsRowKindCreate]
				   titleText:TGL(@"ImportStickerPack.CreateNewStickerSet", @"Create a Sticker Set")
				   countText:nil
				thumbnailKey:nil
			 thumbnailFileId:0
		thumbnailPlaceholder:nil];
}

+ (TGOwnedSetsItem *)itemFromSet:(NSDictionary *)set {
	NSString *title = set[@"title"];
	NSInteger count = [set[@"count"] integerValue];
	NSString *countText = TGLPlural(@"StickerPack.StickerCount", count, @"1 sticker", @"%d stickers");

	NSString *initials = title.length ? [TGSafeFirstCharacter(title) uppercaseString] : @"?";
	UIImage *placeholder = [TGIcons avatarWithInitials:initials size:kOwnedSetsCoverSide
											  colourId:[set[@"id"] longLongValue]];

	NSArray *covers = set[@"covers"];
	NSDictionary *cover = covers.count ? covers[0] : nil;
	int64_t thumbId = [cover[@"thumbId"] longLongValue];
	int64_t thumbnailFileId = thumbId ?: [cover[@"fileId"] longLongValue];
	NSString *thumbnailKey = thumbId ? cover[@"thumbUniqueId"] : cover[@"uniqueId"];

	return [[TGOwnedSetsItem alloc]
				initWithKind:TGOwnedSetsRowKindSet
			 reuseIdentifier:[TGOwnedSetsCellCatalogue reuseIdentifierForKind:TGOwnedSetsRowKindSet]
				   cellClass:[TGOwnedSetsCellCatalogue cellClassForKind:TGOwnedSetsRowKindSet]
				   titleText:title
				   countText:countText
				thumbnailKey:thumbnailKey
			 thumbnailFileId:thumbnailFileId
		thumbnailPlaceholder:placeholder];
}

@end

#import "TGChatPositions.h"

static NSDictionary *TGPositionDictionary(id value) {
	return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

static BOOL TGPositionIsInList(NSDictionary *position, NSString *listType) {
	NSDictionary *list = TGPositionDictionary(position[@"list"]);
	return [list[@"@type"] isKindOfClass:[NSString class]] &&
		[list[@"@type"] isEqualToString:listType];
}

int64_t TGOrderInList(NSArray *positions, NSString *listType) {
	if (![positions isKindOfClass:[NSArray class]])
		return 0;
	for (id entry in positions) {
		NSDictionary *position = TGPositionDictionary(entry);
		if (position && TGPositionIsInList(position, listType))
			return (int64_t)[position[@"order"] longLongValue];
	}
	return 0;
}

int64_t TGMainListOrder(NSArray *positions) {
	return TGOrderInList(positions, @"chatListMain");
}

int64_t TGArchiveOrder(NSArray *positions) {
	return TGOrderInList(positions, @"chatListArchive");
}

static BOOL TGPinnedInListType(NSArray *positions, NSString *listType) {
	if (![positions isKindOfClass:[NSArray class]])
		return NO;
	for (id entry in positions) {
		NSDictionary *position = TGPositionDictionary(entry);
		if (position && TGPositionIsInList(position, listType))
			return [position[@"is_pinned"] boolValue];
	}
	return NO;
}

BOOL TGPinnedInMain(NSArray *positions) {
	return TGPinnedInListType(positions, @"chatListMain");
}

BOOL TGPinnedInArchive(NSArray *positions) {
	return TGPinnedInListType(positions, @"chatListArchive");
}

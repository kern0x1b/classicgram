#import "TGContactPhotoMatch.h"

BOOL TGContactRowWantsPhotoFileId(NSDictionary *user, NSNumber *fileId) {
	if (![user isKindOfClass:[NSDictionary class]] || ![fileId isKindOfClass:[NSNumber class]])
		return NO;
	id own = user[@"photoFileId"];
	if (![own isKindOfClass:[NSNumber class]])
		return NO;
	return [own longLongValue] == [fileId longLongValue] && [fileId longLongValue] != 0;
}

BOOL TGContactRowIsUserId(NSDictionary *user, NSNumber *userId) {
	if (![user isKindOfClass:[NSDictionary class]] || ![userId isKindOfClass:[NSNumber class]])
		return NO;
	id own = user[@"id"];
	if (![own isKindOfClass:[NSNumber class]])
		return NO;
	return [own longLongValue] == [userId longLongValue] && [userId longLongValue] != 0;
}

#import "TGFlattenBots.h"

static NSDictionary *TGFBDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSArray *TGFBArray(id value) {
	return [value isKindOfClass:NSArray.class] ? value : nil;
}

NSDictionary *TGBMarkup(NSDictionary *message) {
	NSDictionary *m = TGFBDict(message);
	if (!m)
		return nil;
	NSDictionary *markup = TGFBDict(m[@"reply_markup"]);
	if (!markup)
		markup = TGFBDict(m[@"replyMarkup"]);
	return markup;
}

NSNumber *TGBFileIdOfPhoto(NSDictionary *photo) {
	NSArray *sizes = TGFBArray(TGFBDict(photo)[@"sizes"]);
	NSDictionary *chosen = nil;
	for (id entry in sizes) {
		NSDictionary *size = TGFBDict(entry);
		if (size)
			chosen = size;
	}
	NSNumber *fileId = TGFBDict(chosen[@"photo"])[@"id"];
	return [fileId isKindOfClass:NSNumber.class] ? fileId : nil;
}

NSNumber *TGBFileIdOfThumbnail(NSDictionary *owner) {
	NSDictionary *thumb = TGFBDict(TGFBDict(owner)[@"thumbnail"]);
	NSNumber *fileId = TGFBDict(thumb[@"file"])[@"id"];
	return [fileId isKindOfClass:NSNumber.class] ? fileId : nil;
}

NSNumber *TGBFileIdOfDocument(NSDictionary *owner, NSString *key) {
	NSNumber *fileId = TGFBDict(TGFBDict(owner)[key])[@"id"];
	return [fileId isKindOfClass:NSNumber.class] ? fileId : nil;
}

#import "TGMediaPreviewName.h"

static NSString *TGMediaPreviewString(id value) {
	return [value isKindOfClass:[NSString class]] && [value length] ? value : nil;
}

NSString *TGMediaPreviewName(NSDictionary *content) {
	if (![content isKindOfClass:[NSDictionary class]])
		return nil;
	NSString *type = TGMediaPreviewString(content[@"@type"]);
	if ([type isEqualToString:@"messageDocument"]) {
		NSDictionary *document = content[@"document"];
		if (![document isKindOfClass:[NSDictionary class]])
			return nil;
		return TGMediaPreviewString(document[@"file_name"]);
	}
	if (![type isEqualToString:@"messageAudio"])
		return nil;
	NSDictionary *audio = content[@"audio"];
	if (![audio isKindOfClass:[NSDictionary class]])
		return nil;
	NSString *title = TGMediaPreviewString(audio[@"title"]);
	NSString *performer = TGMediaPreviewString(audio[@"performer"]);
	if (title && performer)
		return [NSString stringWithFormat:@"%@ — %@", title, performer];
	if (title)
		return title;
	if (performer)
		return performer;
	return TGMediaPreviewString(audio[@"file_name"]);
}

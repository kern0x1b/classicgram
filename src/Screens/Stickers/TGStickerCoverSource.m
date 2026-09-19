#import "TGStickerCoverSource.h"

@interface TGStickerCoverSource ()

@property (nonatomic, assign) TGStickerCoverKind kind;
@property (nonatomic, assign) long long fileId;
@property (nonatomic, copy) NSString *uniqueId;

@end

@implementation TGStickerCoverSource

+ (instancetype)noneSource {
	return [[self alloc] init];
}

+ (instancetype)kind:(TGStickerCoverKind)kind fileId:(long long)fileId uniqueId:(NSString *)uniqueId {
	if (fileId <= 0)
		return [self noneSource];
	if (kind == TGStickerCoverKindThumbnail && uniqueId.length == 0)
		return [self noneSource];
	TGStickerCoverSource *source = [[self alloc] init];
	source.kind = kind;
	source.fileId = fileId;
	source.uniqueId = uniqueId;
	return source;
}

+ (BOOL)stickerIsStill:(NSDictionary *)sticker {
	return !([sticker[@"isAnimated"] boolValue] || [sticker[@"isVideo"] boolValue]);
}

+ (instancetype)thumbnailSourceFor:(NSDictionary *)item {
	return [self kind:TGStickerCoverKindThumbnail
			   fileId:[item[@"thumbId"] longLongValue]
			 uniqueId:item[@"thumbUniqueId"]];
}

+ (instancetype)sourceForSticker:(NSDictionary *)sticker {
	if (![sticker isKindOfClass:[NSDictionary class]])
		return [self noneSource];
	if ([self stickerIsStill:sticker])
		return [self kind:TGStickerCoverKindSticker
				   fileId:[sticker[@"fileId"] longLongValue]
				 uniqueId:sticker[@"uniqueId"]];
	return [self thumbnailSourceFor:sticker];
}

+ (instancetype)sourceForSet:(NSDictionary *)set {
	if (![set isKindOfClass:[NSDictionary class]])
		return [self noneSource];
	NSArray *covers = set[@"covers"];
	if ([covers isKindOfClass:[NSArray class]]) {
		for (NSDictionary *sticker in covers) {
			if (![sticker isKindOfClass:[NSDictionary class]])
				continue;
			if (![self stickerIsStill:sticker])
				continue;
			TGStickerCoverSource *still = [self sourceForSticker:sticker];
			if (still.kind != TGStickerCoverKindNone)
				return still;
		}
	}
	TGStickerCoverSource *own = [self thumbnailSourceFor:set];
	if (own.kind != TGStickerCoverKindNone)
		return own;
	if (![covers isKindOfClass:[NSArray class]])
		return [self noneSource];
	for (NSDictionary *sticker in covers) {
		if (![sticker isKindOfClass:[NSDictionary class]])
			continue;
		TGStickerCoverSource *thumbnail = [self thumbnailSourceFor:sticker];
		if (thumbnail.kind != TGStickerCoverKindNone)
			return thumbnail;
	}
	return [self noneSource];
}

@end

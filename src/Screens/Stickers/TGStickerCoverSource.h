#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, TGStickerCoverKind) {
	TGStickerCoverKindNone,
	TGStickerCoverKindSticker,
	TGStickerCoverKindThumbnail
};

@interface TGStickerCoverSource : NSObject

@property (nonatomic, readonly) TGStickerCoverKind kind;
@property (nonatomic, readonly) long long fileId;
@property (nonatomic, readonly, copy) NSString *uniqueId;

+ (instancetype)sourceForSticker:(NSDictionary *)sticker;
+ (instancetype)sourceForSet:(NSDictionary *)set;

@end

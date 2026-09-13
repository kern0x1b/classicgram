#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, TGChatRowKind) {
	TGChatRowKindService = 0,
	TGChatRowKindText,
	TGChatRowKindPhoto,
	TGChatRowKindFile,
	TGChatRowKindVoice,
	TGChatRowKindSticker,
	TGChatRowKindAnimatedSticker,
	TGChatRowKindBareEmoji,
	TGChatRowKindVideoNote,
	TGChatRowKindAlbum,
	TGChatRowKindPoll,
	TGChatRowKindChecklist,
	TGChatRowKindCall,
	TGChatRowKindRichMessage,
	TGChatRowKindLocation
};

@interface TGBubbleCellCatalogue : NSObject

+ (NSString *)reuseIdentifierForKind:(TGChatRowKind)kind;
+ (Class)cellClassForReuseIdentifier:(NSString *)identifier;

@end

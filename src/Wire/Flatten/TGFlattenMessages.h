#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSDictionary * _Nullable TGMsgBrief(NSDictionary * _Nullable m);

BOOL TGMsgLooksLikeMp3(NSString *mimeType, NSString *fileName);
NSString * _Nullable TGMsgNotificationSoundPathFromRaw(NSDictionary *message);

NSDictionary *TGMsgSendOptions(NSDictionary * _Nullable options);

BOOL TGMsgCanReactTo(NSDictionary *reactions);

NSString *TGQuickReplyContentLabel(NSString *kind);
NSDictionary * _Nullable TGQuickReplyShortcutFromUpdate(NSDictionary * _Nullable shortcut);

NSArray *TGCustomEmojiRunsFromEntities(NSArray * _Nullable entities, NSString *text);
NSArray *TGMentionNameRunsFromEntities(NSArray * _Nullable entities, NSString *text);

NSString * _Nullable TGSendFailureMessage(NSDictionary * _Nullable sendingState, BOOL slowModeActiveForChat);

NS_ASSUME_NONNULL_END

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSString *TGScopeType(NSString * _Nullable scope);
NSString *TGScopeName(NSString * _Nullable scopeType);
NSString *TGScopeForChatFlags(BOOL isChannel, BOOL isGroup);
BOOL TGEffectiveChatMuted(BOOL useDefaultMuteFor, long long chatMuteFor, long long scopeDefaultMuteFor);
NSDictionary *_Nullable TGFlattenFileObjectState(NSDictionary * _Nullable file);

NS_ASSUME_NONNULL_END

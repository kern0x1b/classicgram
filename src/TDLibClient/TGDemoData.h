#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString *_Nullable (^TGDemoAssetProvider)(NSString *key);

void TGDemoSetAssetProvider(TGDemoAssetProvider _Nullable provider);

NSArray<NSDictionary *> *TGDemoUsers(void);
NSArray<NSDictionary *> *TGDemoChats(void);
NSArray<NSDictionary *> *TGDemoHistoryForChat(long long chatId);
NSDictionary *TGDemoMe(void);

NSArray<NSDictionary *> *TGDemoStartupUpdates(void);
NSDictionary *_Nullable TGDemoResponseForRequest(NSDictionary *request);
NSDictionary *_Nullable TGDemoFileUpdateForRequest(NSDictionary *_Nullable request);

NS_ASSUME_NONNULL_END

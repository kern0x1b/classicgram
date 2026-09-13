#import "TGClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface TGClient (UpdateHandling)

- (void)failPendingRequests:(NSString *)reason;
- (void)sweepPendingRequests;
- (void)startPendingSweepTimer;
- (void)handleUpdate:(NSDictionary *)obj;
- (void)handleMeUser:(NSDictionary *)obj;
- (void)handleUpdateUser:(NSDictionary *)obj;
- (void)handleUpdateUserFullInfo:(NSDictionary *)obj;
- (void)handleUpdateChatBlockList:(NSDictionary *)obj;
- (void)handleUpdateMessageInteractionInfo:(NSDictionary *)obj;
- (void)handleUpdateNewMessage:(NSDictionary *)obj;
- (void)handleUpdateMessageSent:(NSDictionary *)obj;
- (void)handleUpdateMessageContent:(NSDictionary *)obj;
- (void)handleUpdateDeleteMessages:(NSDictionary *)obj;
- (void)handleUpdatePoll:(NSDictionary *)obj;
- (void)handleUpdateDownloads:(NSDictionary *)obj;
- (void)handleUpdateConnectionState:(NSDictionary *)obj;
- (NSDictionary *)knownStateOfFile:(long long)fileId;
- (void)rememberStateOfFileObject:(NSDictionary *)file notify:(BOOL)notify;
- (void)handleUpdateFile:(NSDictionary *)obj;
- (void)handleUpdateChatAction:(NSDictionary *)obj;
- (void)invalidateAllChatActionTimers;
- (void)expireChatActionTimer:(NSTimer *)timer;
- (void)handleUpdateSupergroup:(NSDictionary *)obj;
- (void)handleUpdateSupergroupFullInfo:(NSDictionary *)obj;
- (void)handleUpdateUserStatus:(NSDictionary *)obj;
- (void)handleUpdateChatFolders:(NSDictionary *)obj;
- (void)handleErrorObject:(NSDictionary *)obj;
- (void)handleAuthState:(NSDictionary *)state;
- (void)flushPreInitRequests;
- (void)sendTdlibParameters;

@end

NS_ASSUME_NONNULL_END

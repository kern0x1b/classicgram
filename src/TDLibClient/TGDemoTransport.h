#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

void *TGDemoTransportCreate(void);
void TGDemoTransportSend(void *client, const char *request);
const char *_Nullable TGDemoTransportReceive(void *client, double timeout);
void TGDemoTransportDestroy(void *client);

NSString *TGDemoTransportReplyForRequestJSON(NSString *requestJSON);

NS_ASSUME_NONNULL_END

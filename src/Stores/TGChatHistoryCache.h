#import <Foundation/Foundation.h>

@interface TGChatHistoryCache : NSObject

+ (instancetype)shared;

- (NSArray *)messagesForChat:(int64_t)chatId thread:(int64_t)threadId;
- (void)setMessages:(NSArray *)messages forChat:(int64_t)chatId thread:(int64_t)threadId;
- (void)persist;
- (void)clear;
- (void)setAccountScope:(NSString *)accountScope;

@end

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const TGNotificationManagerDidRequestOpenChatNotification;
extern NSString *const TGNotificationManagerChatIdKey;

@interface TGNotificationManager : NSObject

+ (instancetype)shared;

- (void)start;

- (void)clearNotificationsForChat:(int64_t)chatId;

- (void)discardEverythingForAccountSwitch;

- (void)applicationDidBecomeActive;
- (void)applicationDidEnterBackground;

- (int64_t)chatIdForLocalNotification:(UILocalNotification *)notification;
- (int64_t)threadIdForLocalNotification:(UILocalNotification *)notification;

+ (NSArray *)builtInToneIds;
+ (NSArray *)builtInToneNames;
+ (long long)selectedToneId;
+ (void)setSelectedToneId:(long long)toneId;
+ (NSString *)nameForToneId:(long long)toneId;
+ (void)previewToneId:(long long)toneId;

@end

NS_ASSUME_NONNULL_END

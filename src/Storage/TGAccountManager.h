#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const TGAccountsDidChangeNotification;
extern NSString *const TGAccountWillSwitchNotification;
extern NSString *const TGAccountDidSwitchNotification;
extern NSString *const TGAccountSignOutFailedNotification;

extern const NSInteger kAccountSlotLimit;

@interface TGAccountManager : NSObject

+ (instancetype)shared;

- (void)prepareForLaunch;

@property (nonatomic, readonly) NSArray *accounts;
@property (nonatomic, readonly) NSInteger currentSlot;
@property (nonatomic, readonly) NSDictionary *currentAccount;
@property (nonatomic, readonly) BOOL switching;
@property (nonatomic, readonly) BOOL addingAccount;

- (BOOL)canAddAccount;
- (NSInteger)firstFreeSlot;

- (NSDictionary *)accountForSlot:(NSInteger)slot;

- (void)rememberCurrentAccount;
- (void)noteUnreadCount:(NSInteger)unread;

- (void)switchToSlot:(NSInteger)slot;
- (void)switchToSlotAbandoningAdd:(NSInteger)slot;
- (void)beginAddingAccount;
- (void)cancelAddingAccount;
- (void)signOutOfSlot:(NSInteger)slot;

- (BOOL)handleLogOutOfCurrentAccount;

+ (NSString *)scopeForSlot:(NSInteger)slot;
+ (NSString *)defaultsKey:(NSString *)base;

@end

NS_ASSUME_NONNULL_END

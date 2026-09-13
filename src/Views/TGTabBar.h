#import <UIKit/UIKit.h>

@protocol TGTabBarDelegate <NSObject>
- (void)tabBarSelectedItem:(int)index;
@end

extern const int kTabIndexContacts;
extern const int kTabIndexCalls;
extern const int kTabIndexChats;
extern const int kTabIndexSettings;
extern const int kTabCount;

extern NSString *const TGCallsTabVisibilityChangedNotification;

@interface TGTabBar : UIView

@property (nonatomic, weak) id<TGTabBarDelegate> tabDelegate;
@property (nonatomic) int selectedIndex;
@property (nonatomic, copy) NSArray *visibleTabs;

+ (BOOL)callsTabEnabled;
+ (void)setCallsTabEnabled:(BOOL)enabled;
+ (NSArray *)defaultVisibleTabs;

- (void)setUnreadCount:(int)unreadCount;

@end

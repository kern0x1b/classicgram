#import <Foundation/Foundation.h>

extern NSString *const TGSettingsInAppSoundsKey;
extern NSString *const TGSettingsInAppVibrateKey;
extern NSString *const TGSettingsInAppPreviewKey;
extern NSString *const TGSettingsShowTranslateKey;

@interface TGInAppNotificationPreferences : NSObject

+ (BOOL)inAppSoundsEnabled;
+ (BOOL)inAppVibrateEnabled;
+ (BOOL)inAppPreviewEnabled;
+ (BOOL)showTranslateButton;

@end

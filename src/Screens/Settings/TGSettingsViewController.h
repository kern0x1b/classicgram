#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, TGSettingsPage) {
	TGSettingsPageRoot = 0,
	TGSettingsPageAppearance,
	TGSettingsPageData,
	TGSettingsPageNotifications,
	TGSettingsPageLanguage
};

@interface TGSettingsViewController : UITableViewController

@property (nonatomic, assign) TGSettingsPage page;
@end

@interface TGSettingsViewController (Public)

+ (void)resetAutoDownloadPresetCacheForAccountSwitch;

+ (void)resetDataSaverCacheForAccountSwitch;

@end

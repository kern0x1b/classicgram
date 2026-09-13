#import "TGImageDecode.h"
#import "TGAccountUsernamesViewController.h"
#import "TGAccountSettingsViewController.h"
#import "TGLocalization.h"
#import "TGNotificationManager.h"
#import "TGSettingsViewController.h"
#import "TGEmoji.h"
#import "RootViewController.h"
#import "TGTheme.h"
#import "TGSessionsViewController.h"
#import "TGDeviceViewController.h"
#import "TGWebBrowserSettingsViewController.h"
#import "TGDevice.h"
#import "TGFoldersViewController.h"
#import "TGProxyViewController.h"
#import "TGPrivacyViewController.h"
#import "TGPrivacyViewController.h"
#import "TGTabBar.h"
#import "TGCapabilities.h"
#import "TGAccountManager.h"
#import "TGPhoneFormat.h"
#import "TGIcons.h"
#import <QuartzCore/QuartzCore.h>
#import "TGSettingsViewControllerInternal.h"

@implementation TGSettingsViewController (AutoDownloadActions)

#pragma mark - auto-download

- (void)tapAutoDownload:(NSIndexPath *)indexPath {
	if (indexPath.section != 0)
		return;
	if ((NSUInteger)indexPath.row >= [TGSettingsViewController networkKinds].count)
		return;
	TGSettingsViewController *next = [[TGSettingsViewController alloc] init];
	next.page = (TGSettingsPage)TGSettingsPageAutoDownloadKind;
	next.autoDownloadKind = [TGSettingsViewController networkKinds][indexPath.row];
	[self openViewController:next];
}

- (void)confirmClearAutosaveExceptions {
	UIAlertView *confirm = [[UIAlertView alloc]
			initWithTitle:TGL(@"Autosave.DeleteAllExceptions", @"Delete All Exceptions")
				  message:TGL(@"Notification.Exceptions.DeleteAllConfirmation", @"Are you sure you want to delete all exceptions?")
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Notification.Exceptions.DeleteAll", @"Delete All"), nil];
	confirm.tag = 403;
	[confirm show];
}

@end

#import <UIKit/UIKit.h>

@class TGResendCountdown;

@interface TGAccountSettingsViewController : UITableViewController <UIActionSheetDelegate, UIAlertViewDelegate,
												 UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) NSDictionary *account;
@property (nonatomic, strong) NSString *phoneDetail;
@property (nonatomic, strong) NSDictionary *usernames;
@property (nonatomic, strong) NSString *publicLink;
@property (nonatomic, assign) NSInteger publicLinkExpiry;
@property (nonatomic, strong) NSArray *photos;
@property (nonatomic, assign) BOOL photosLoaded;
@property (nonatomic, assign) BOOL photosFailed;
@property (nonatomic, strong) NSString *birthdayText;
@property (nonatomic, strong) NSString *personalChatTitle;
@property (nonatomic, strong) NSString *colourDetail;
@property (nonatomic, strong) NSString *emojiStatusDetail;
@property (nonatomic, strong) NSArray *chatPicks;
@property (nonatomic, strong) NSArray *usernamePicks;
@property (nonatomic, strong) UIPopoverController *pickerPopover;
@property (nonatomic, assign) BOOL pickingPublicPhoto;
@property (nonatomic, strong) UIActionSheet *birthdaySheet;
@property (nonatomic, strong) UIDatePicker *birthdayPicker;
@property (nonatomic, strong) UISwitch *birthdayHideYearSwitch;
@property (nonatomic, strong) id userProfileObserverToken;
@property (nonatomic, strong) TGResendCountdown *numberCodeResendCountdown;
@property (nonatomic, assign) NSInteger numberCodeResendSeconds;
@property (nonatomic, strong) NSString *numberCodeDescription;
@property (nonatomic, strong) NSString *numberCodeNextTitle;
@end

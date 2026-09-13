#import <UIKit/UIKit.h>
#import "TGNewContactViewController.h"

extern const CGFloat kNewContactAvatarSide;
extern const CGFloat kNewContactAvatarGap;
extern const CGFloat kNewContactHeaderTop;
extern const CGFloat kNewContactHeaderBottom;
extern const CGFloat kNewContactNameRow;
extern const CGFloat kNewContactCaptionInset;
extern const CGFloat kNewContactCaptionPadding;
extern const CGFloat kNewContactNarrowInset;
extern const CGFloat kNewContactWideInsetMin;
extern const CGFloat kNewContactWideInsetMax;

UIColor *TGNewContactColour(int rgb, CGFloat alpha);
void TGNewContactApplyMinimumWidth(UIButton *button, CGFloat minimumWidth);
CGFloat TGNewContactGroupedInset(CGFloat width);
UIImage *TGNewContactStretchedImage(NSString *name);

@interface TGNewContactPhoneCell : UITableViewCell
@property (nonatomic, strong) UILabel *labelView;
@property (nonatomic, strong) UIImageView *verticalSeparator;
@property (nonatomic, strong) UITextField *field;
@property (nonatomic, strong) UIButton *removeButton;
@property (nonatomic, strong) UILabel *staticValueLabel;
@property (nonatomic, assign) BOOL lastInGroup;
- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier;
- (void)setShowsRemoveControl:(BOOL)shows;
@end

@interface TGPhoneLabelPickerController : UITableViewController
@property (nonatomic, strong) NSArray *labels;
@property (nonatomic, copy) NSString *selectedLabel;
@property (nonatomic, copy) void (^onPick)(NSString *label);
@property (nonatomic, copy) void (^onCancel)(void);
@end

@interface TGNewContactViewController () <UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIActionSheetDelegate>
@property (nonatomic, strong) UITextField *firstNameField;
@property (nonatomic, strong) UITextField *lastNameField;
@property (nonatomic, strong) NSMutableArray *phoneEntries;
@property (nonatomic, strong) UIButton *doneButton;
@property (nonatomic, strong) UIButton *addPhotoButton;
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UIImage *avatarImage;
@property (nonatomic, strong) NSArray *photoSheetActions;
@property (nonatomic, strong) UIView *editNameContainer;
@property (nonatomic, strong) NSArray *labelDisplayNames;
@property (nonatomic, strong) NSArray *labelIdentifiers;
@property (nonatomic, assign) BOOL saving;
@property (nonatomic, assign) BOOL didFocusNameField;
@property (nonatomic, assign) BOOL syncToPhone;
@property (nonatomic, assign) BOOL sharePhoneNumber;
@property (nonatomic, assign) int64_t resolvedUserId;
@property (nonatomic, assign) BOOL resolving;
@property (nonatomic, assign) BOOL resolveFinished;
@property (nonatomic, copy) NSString *resolvedName;
@property (nonatomic, copy) NSString *resolvedForPhone;
@property (nonatomic, strong) UILabel *phoneFooterLabel;
@property (nonatomic, strong) UIView *phoneFooterView;
@property (nonatomic, strong) UIView *firstNameBackground;
@property (nonatomic, strong) UIView *lastNameBackground;
@property (nonatomic, assign) CGFloat headerLaidOutForWidth;
@property (nonatomic, strong) id textChangedObserverToken;

- (BOOL)hasKnownPeer;
- (BOOL)writesAddressBookRecord;
- (BOOL)updatesAddressBookRecord;
- (UITextField *)makeFieldWithPlaceholder:(NSString *)placeholder font:(UIFont *)font;
@end

@interface TGNewContactViewController (Actions)

- (void)updateAddressBookRecordFirst:(NSString *)first last:(NSString *)last phone:(NSString *)phone;

@end

@interface TGNewContactViewController (Header)

- (CGFloat)headerWidth;
- (void)buildTableHeader;
- (void)layoutTableHeader;

@end

@interface TGNewContactViewController (PhoneEntries)

- (NSMutableDictionary *)makePhoneEntry;
- (NSString *)trimmed:(NSString *)text;
- (NSString *)digitsOf:(NSString *)text;
- (NSArray *)enteredPhones;
- (BOOL)isFormValid;
- (void)updateDoneEnabled;
- (NSString *)primaryPhone;
- (BOOL)rowCarriesNumber:(NSIndexPath *)indexPath;
- (void)presentLabelPickerForRow:(NSInteger)row;
- (void)textChanged:(NSNotification *)note;

@end

@interface TGNewContactViewController (PhoneLookup)

- (NSString *)phoneStatusText;
- (void)schedulePhoneLookup;

@end

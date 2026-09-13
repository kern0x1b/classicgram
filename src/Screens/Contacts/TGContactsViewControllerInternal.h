#import <UIKit/UIKit.h>
#import <AddressBook/AddressBook.h>
#import "TGContactsViewController.h"
#import "TGContactName.h"
#import "TGContactRowMetrics.h"

@class TGContactsProgressWindow;

extern const NSUInteger kContactPhotoCacheCount;
extern const NSUInteger kContactPhotoCacheBytes;

extern NSString *const TGContactsSortByLastSeenKey;
NSString *TGContactsSortedByPresenceTitle(void);
extern NSString *const TGContactActionInvite;
extern NSString *const TGContactActionNewGroup;
extern NSString *const TGContactActionNewChannel;
extern NSString *const TGContactActionLink;

NSUInteger TGContactPhotoCost(UIImage *image);
BOOL TGContactsTabletLayout(void);
BOOL TGContactsShowInDetailPane(UIViewController *sender, UIViewController *target);
CGFloat TGContactsScreenWidth(void);
UIImage *TGContactsScaledImage(NSString *name, CGFloat side);
NSString *TGContactSortKey(NSDictionary *u, BOOL byFirstName);
NSString *TGContactSectionLetter(NSDictionary *u, BOOL byFirstName);

@interface TGContactsViewController () <UISearchBarDelegate, UIActionSheetDelegate, UIAlertViewDelegate>
@property (nonatomic, strong) NSArray *users;
@property (nonatomic, strong) NSArray *filteredUsers;
@property (nonatomic, strong) NSArray *sectionTitles;
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) NSCache *photos;
@property (nonatomic, strong) NSMutableSet *photosRequested;
@property (nonatomic, strong) NSMutableSet *photosFailed;
@property (nonatomic, strong) NSMutableSet *photosLoading;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSString *searchQuery;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, strong) UIView *phonebookAccessOverlay;
@property (nonatomic, strong) UIView *headerContainer;
@property (nonatomic, strong) UIButton *phonebookDeniedBanner;
@property (nonatomic, strong) UIButton *addButton;
@property (nonatomic, strong) NSMutableSet *closeFriendIds;
@property (nonatomic, strong) NSMutableDictionary *badges;
@property (nonatomic, strong) NSMutableSet *badgesRequested;
@property (nonatomic, strong) NSMutableDictionary *emojiStatusIcons;
@property (nonatomic, strong) NSMutableSet *emojiStatusIconsRequested;
@property (nonatomic, strong) NSCache *emojiStatusImages;
@property (nonatomic, strong) NSMutableSet *emojiStatusImagesRequested;
@property (nonatomic, assign) NSInteger importedCount;
@property (nonatomic, assign) BOOL importedCountKnown;
@property (nonatomic, strong) NSDictionary *actionUser;
@property (nonatomic, strong) NSString *actionBirthdate;
@property (nonatomic, assign) BOOL actionSheetShown;
@property (nonatomic, strong) NSMutableDictionary *birthdays;
@property (nonatomic, strong) TGContactsProgressWindow *progress;
@property (nonatomic, assign) BOOL importing;
@property (nonatomic, copy) NSString *contactLink;
@property (nonatomic, assign) NSInteger contactLinkExpiresIn;
@property (nonatomic, strong) NSDate *contactLinkFetchedAt;
@property (nonatomic, assign) BOOL contactLinkRequested;
@property (nonatomic, assign) BOOL buildingInviteList;
@property (nonatomic, strong) NSMutableDictionary *contactFlags;
@property (nonatomic, strong) NSDictionary *actionFlags;
@property (nonatomic, assign) BOOL actionBirthdateReady;
@property (nonatomic, assign) BOOL actionFlagsReady;
@property (nonatomic, strong) NSArray *actionKeys;
@property (nonatomic, strong) NSArray *serverUsers;
@property (nonatomic, copy) NSString *serverQuery;
@property (nonatomic, strong) UIDatePicker *birthdayPicker;
@property (nonatomic, strong) UIActionSheet *birthdaySheet;
@property (nonatomic, strong) NSDictionary *birthdayUser;
@property (nonatomic, strong) NSDictionary *phoneShareUser;
@property (nonatomic, strong) NSDictionary *pendingDeleteUser;
@property (nonatomic, assign) BOOL creatingChannel;
@property (nonatomic, copy) NSString *myUsernameLink;
@property (nonatomic, assign) BOOL sortByFirstName;
@property (nonatomic, assign) BOOL displayFirstNameFirst;
@property (nonatomic, assign) BOOL sortByLastSeen;
@property (nonatomic, strong) UIButton *sortButton;
@property (nonatomic, strong) NSMutableArray *reusableSectionHeaders;
@property (nonatomic, strong) UIView *emptyPlaceholder;
@property (nonatomic, strong) UILabel *emptyTitleLabel;
@property (nonatomic, strong) UILabel *emptyHelpLabel;
@property (nonatomic, strong) id userStatusChangedObserverToken;
@property (nonatomic, strong) id addressBookOrderMayHaveChangedObserverToken;
@property (nonatomic, strong) id contactsDidChangeObserverToken;
@property (nonatomic, assign) ABAddressBookRef addressBookRef;
- (void)updateContactSortOrder;
- (void)sortUsers;
- (BOOL)isCloseFriend:(NSDictionary *)u;
- (void)reloadCloseFriends;
- (void)addressBookOrderMayHaveChanged;
@end

@interface TGContactsViewController (Layout)

- (void)updateEmptyState;
- (void)updatePhonebookAccess;
- (BOOL)phonebookAccessDenied;
- (void)reloadContacts;
- (void)startObservingAddressBookExternalChanges;
- (void)stopObservingAddressBookExternalChanges;
- (void)resyncAddressBookAfterExternalChange;
- (void)handleSortSheetAtIndex:(NSInteger)index;
- (void)newGroupTapped;

@end

@interface TGContactsViewController (Filtering)

- (void)refreshTable;
- (void)reloadTableSoon;
- (NSString *)letterForSection:(NSInteger)section;
- (NSString *)actionIdentifierAtIndexPath:(NSIndexPath *)indexPath;
- (void)userStatusChanged:(NSNotification *)note;

@end

@interface TGContactsViewController (Birthdays)

- (NSString *)birthdayTextFrom:(NSDictionary *)birthdate;
- (void)showBirthdayPickerForUser:(NSDictionary *)u;

@end

@interface TGContactsViewController (ContactLink)

- (NSString *)shareableLink;
- (void)reloadMyUsernames;
- (void)reloadContactLink;
- (void)contactLinkTapped;
- (void)presentSheet:(UIActionSheet *)sheet;
- (void)handleLinkSheetAtIndex:(NSInteger)index;

@end

@interface TGContactsViewController (Actions)

- (void)deleteContact:(NSDictionary *)u;
- (void)confirmDeleteContact:(NSDictionary *)u;
- (void)newChannelTapped;

@end

@interface TGContactsViewController (Photos)

- (void)requestPhotoForUser:(NSDictionary *)u;
- (void)fetchMissingPhotos;

@end

@interface TGContactsViewController (Import)

- (void)reloadImportedCount;
- (void)startAddressBookImport;
- (void)inviteFriendsTapped;

@end

@interface TGContactsViewController (TableView)

- (NSArray *)rowsForSection:(NSInteger)section;
- (NSDictionary *)userAtIndexPath:(NSIndexPath *)indexPath;
- (void)openTarget:(UIViewController *)target;

@end

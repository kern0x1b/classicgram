#import "TGTableReloadCoalescer.h"
#import "TGFoldersViewController.h"

static const CGFloat kRowHeight = 44.0f;
static const CGFloat kChatRowHeight = 51.0f;
static const CGFloat kCaptionInset = 20.0f;

static const NSInteger kLinkSheetTag = 201;
static const NSInteger kRenameLinkAlertTag = 202;

static const unsigned int kFolderTagColours[7] = {
	0xe15052, 0xe0802b, 0xa05ff3, 0x27a910, 0x27acce, 0x3391d4, 0xdd4371};

@interface TGFoldersViewController () <UITextFieldDelegate, UIAlertViewDelegate,
	UIActionSheetDelegate>

@property (nonatomic, strong) TGTableReloadCoalescer *avatarReload;
@property (nonatomic, strong) id chatsDidChangeObserverToken;
@property (nonatomic, strong) id archivedChatsDidChangeObserverToken;
@property (nonatomic, assign) NSInteger mainListPosition;
@property (nonatomic, assign) NSInteger folderLimit;
@property (nonatomic, assign) NSInteger chosenChatLimit;
@property (nonatomic, assign) NSInteger pickerLimit;
@property (nonatomic, strong) NSMutableArray *inviteLinks;
@property (nonatomic, assign) BOOL linksLoaded;
@property (nonatomic, assign) NSInteger activeLinkIndex;

@property (nonatomic, strong) NSMutableArray *folders;
@property (nonatomic, strong) NSMutableDictionary *counts;
@property (nonatomic, strong) NSMutableDictionary *icons;
@property (nonatomic, strong) NSMutableArray *recommended;
@property (nonatomic, assign) BOOL listLoaded;
@property (nonatomic, assign) BOOL orderDirty;
@property (nonatomic, assign) BOOL observingFolders;
@property (nonatomic, strong) id foldersDidChangeObserverToken;

@property (nonatomic, strong) NSMutableDictionary *draft;
@property (nonatomic, assign) BOOL draftLoaded;
@property (nonatomic, assign) BOOL draftFailed;
@property (nonatomic, assign) BOOL savingDraft;
@property (nonatomic, strong) UITextField *nameField;

@property (nonatomic, strong) NSMutableArray *pickerChats;
@property (nonatomic, strong) NSMutableSet *pickerSelection;
@property (nonatomic, assign) BOOL pickerLoaded;
@property (nonatomic, copy) void (^pickerCompletion)(NSArray *chatIds);
@property (nonatomic, strong) NSArray *pickerFixedChats;
@property (nonatomic, assign) NSInteger pickerMainLimit;
@property (nonatomic, assign) NSInteger pickerArchiveLimit;
@property (nonatomic, assign) BOOL pickerMainExhausted;
@property (nonatomic, assign) BOOL pickerArchiveExhausted;
@property (nonatomic, assign) BOOL pickerLoadingMore;

@property (nonatomic, strong) NSMutableDictionary *avatarImages;
@property (nonatomic, strong) NSMutableSet *avatarsRequested;

@property (nonatomic, strong) NSArray *iconNames;
@property (nonatomic, strong) NSString *currentIcon;
@property (nonatomic, strong) NSString *defaultIconName;
@property (nonatomic, copy) void (^iconCompletion)(NSString *iconName);

@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, assign) NSInteger pendingDeleteIndex;

@end

@interface TGFoldersViewController (Internal)

- (UIImage *)avatarForChatId:(int64_t)chatId title:(NSString *)title;
@end

@interface TGFoldersViewController (Private) <UITextFieldDelegate, UIAlertViewDelegate,
	UIActionSheetDelegate>

- (id)init;
- (id)initWithStyle:(UITableViewStyle)style;
- (void)viewDidLoad;
- (void)observeFolderChanges;
- (void)foldersDidChange;
- (void)dealloc;
- (void)viewWillAppear:(BOOL)animated;
- (void)viewWillDisappear:(BOOL)animated;
- (void)viewWillLayoutSubviews;
- (void)applyTheme;
- (void)buildListButtons;
- (void)buildEditorButtons;
- (void)buildPickerButtons;
- (void)toggleEditing;
- (void)buildStatusLabel;
- (void)layoutStatusLabel;
- (void)showStatus:(NSString *)text;
- (void)loadFolders;
- (void)refreshCounts;
- (void)reloadRowForFolderId:(NSNumber *)identifier;
- (void)loadRecommended;
- (void)addRecommendedAtIndex:(NSInteger)index;
- (void)loadFolderLimit;
- (void)loadChosenChatLimit;
- (BOOL)folderLimitReached;
- (void)folderTagsToggled:(UISwitch *)toggle;
- (void)showFolderLimitAlert;
- (NSInteger)listRowCount;
- (NSInteger)folderIndexForRow:(NSInteger)row;
- (NSMutableArray *)combinedListRows;
- (void)adoptCombinedListRows:(NSArray *)combined;
- (void)commitOrder;
- (void)openFolder:(NSInteger)identifier;
- (void)loadDraft;
- (void)refreshDefaultIcon;
- (NSMutableArray *)mutableIdsFrom:(id)value;
- (void)saveDraft;
- (NSArray *)includeKeys;
- (NSArray *)includeTitles;
- (NSArray *)excludeKeys;
- (NSArray *)excludeTitles;
- (void)toggleChanged:(UISwitch *)sender;
- (void)nameChanged:(UITextField *)field;
- (BOOL)textFieldShouldReturn:(UITextField *)field;
- (void)confirmDeleteFolder;
- (void)offerToLeaveChatsThenDelete;
- (void)offerToLeaveChatsForFolder:(NSInteger)identifier completion:(void (^)(NSArray *leaveChatIds))completion;
- (void)finishDeletingFolder:(NSInteger)identifier leavingChats:(NSArray *)chatIds;
- (void)pushPickerForKey:(NSString *)key title:(NSString *)title;
- (void)pushChatPickerWithFixedChats:(NSArray *)chats selected:(NSArray *)selectedChatIds title:(NSString *)title completion:(void (^)(NSArray *chatIds))completion;
- (void)loadPickerChats;
- (void)adoptFixedPickerChats;
- (void)refreshPickerChats;
- (void)loadMorePickerChatsIfNeeded;
- (void)appendPickerChats:(NSArray *)chats;
- (void)finishPickerLoad;
- (void)finishPicking;
- (NSString *)titleForChatId:(NSNumber *)identifier;
- (NSString *)initialsForTitle:(NSString *)title;
- (void)pushIconPicker;
- (NSInteger)draftColourId;
- (void)selectDraftColourId:(NSInteger)colourId;
- (void)loadInviteLinks;
- (void)showNoChatsSelectedAlert;
- (BOOL)draftHasExcludeOrFilterSet;
- (void)showInviteLinkFiltersUnsupportedAlert;
- (void)createInviteLink;
- (void)finishCreatingInviteLinkWithChatIds:(NSArray *)chatIds;
- (NSDictionary *)activeLink;
- (void)openLinkActionsAtIndex:(NSInteger)index;
- (void)renameActiveLink;
- (void)pushChatPickerForEditingLink:(NSDictionary *)link withName:(NSString *)name;
- (void)finishEditingLink:(NSDictionary *)link name:(NSString *)name chatIds:(NSArray *)chatIds;
- (void)deleteLinkAtIndex:(NSInteger)index;
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;
- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index;
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
- (NSString *)captionForSection:(NSInteger)section;
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section;
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section;
- (UIView *)disclosureAccessory;
- (void)markDisclosure:(UITableViewCell *)cell;
- (void)markChecked:(BOOL)checked on:(UITableViewCell *)cell;
- (NSString *)glyphForIconName:(NSString *)name;
- (UITableViewCell *)listCellFor:(UITableView *)tableView at:(NSIndexPath *)indexPath;
- (UITableViewCell *)editorCellFor:(UITableView *)tableView at:(NSIndexPath *)indexPath;
- (UITableViewCell *)pickerCellFor:(UITableView *)tableView at:(NSIndexPath *)indexPath;
- (UITableViewCell *)iconCellFor:(UITableView *)tableView at:(NSIndexPath *)indexPath;
- (void)layoutColourSwatchesInCell:(UITableViewCell *)cell width:(CGFloat)width;
- (void)colourSwatchTapped:(UIButton *)sender;
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath;
- (UITableViewCell *)plainCellFor:(UITableView *)tableView identifier:(NSString *)identifier style:(UITableViewCellStyle)style;
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)from toIndexPath:(NSIndexPath *)to;
- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)from toProposedIndexPath:(NSIndexPath *)proposed;
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)indexPath;
- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath;

@end

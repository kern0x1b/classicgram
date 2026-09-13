#import "TGListBackground.h"
#import "TGContactsViewController.h"
#import "TGContactsViewControllerInternal.h"
#import "TGFlatActionCell.h"
#import "TGContactRowCell.h"
#import "TGInviteFriendsViewController.h"
#import "TGNewGroupMembersViewController.h"
#import "TGContactsService.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGImageDecode.h"
#import "TGNewContactViewController.h"
#import "TGProfileViewController.h"
#import "RootViewController.h"
#import "UIView+SafeTint.h"
#import "TGEmoji.h"
#import <QuartzCore/QuartzCore.h>
#import <AddressBook/AddressBook.h>
#import <dlfcn.h>
#import "TGAlertView.h"
#import "TGSnackbar.h"
#import "TGActionSheetIndexBuilder.h"
#import "TGHexColour.h"

static void TGContactsAddressBookExternalChangeCallback(ABAddressBookRef addressBook, CFDictionaryRef info, void *context) {
	(void)addressBook;
	(void)info;
	TGContactsViewController *controller = (__bridge TGContactsViewController *)context;
	dispatch_async(dispatch_get_main_queue(), ^{
		[controller resyncAddressBookAfterExternalChange];
	});
}

@implementation TGContactsViewController (Layout)

- (BOOL)phonebookAccessDenied {
	ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
	return status == kABAuthorizationStatusDenied || status == kABAuthorizationStatusRestricted;
}

- (BOOL)phonebookAccessUndetermined {
	return ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusNotDetermined;
}

- (void)layoutPhonebookAccessOverlay {
	if (!self.phonebookAccessOverlay)
		return;
	UIView *container = [self.phonebookAccessOverlay viewWithTag:100];
	UIImageView *iconView = (UIImageView *)[self.phonebookAccessOverlay viewWithTag:200];
	UILabel *titleLabel = (UILabel *)[self.phonebookAccessOverlay viewWithTag:300];
	UILabel *subtitleLabel = (UILabel *)[self.phonebookAccessOverlay viewWithTag:400];
	UIButton *allowButton = (UIButton *)[self.phonebookAccessOverlay viewWithTag:500];

	CGSize overlaySize = self.phonebookAccessOverlay.bounds.size;
	container.frame = CGRectMake((CGFloat)(int)((overlaySize.width - 40) / 2),
		(CGFloat)(int)((overlaySize.height - 4) / 2), 40, 4);
	CGFloat containerWidth = container.frame.size.width;
	CGFloat additionalOffset = ([UIScreen mainScreen].bounds.size.height > 480.5f) ? -20 : -15;

	CGSize iconSize = iconView.image ? iconView.image.size : CGSizeZero;
	iconView.frame = CGRectMake((CGFloat)(int)((containerWidth - iconSize.width) / 2),
		-113 + additionalOffset, iconSize.width, iconSize.height);

	CGFloat textLimit = MAX(200.0f, overlaySize.width - 55.0f);
	CGSize titleSize = [titleLabel sizeThatFits:CGSizeMake(MIN(420.0f, textLimit), 1000)];
	titleLabel.frame = CGRectMake((CGFloat)(int)((containerWidth - titleSize.width) / 2),
		-10 + additionalOffset, titleSize.width, titleSize.height);

	CGSize subtitleSize = [subtitleLabel sizeThatFits:
			CGSizeMake(MIN(340.0f, textLimit * 210.0f / 265.0f), 1000)];
	subtitleLabel.frame = CGRectMake((CGFloat)(int)((containerWidth - subtitleSize.width) / 2),
		41 + additionalOffset, subtitleSize.width, subtitleSize.height);

	if (allowButton) {
		CGSize buttonTextSize = [[allowButton titleForState:UIControlStateNormal]
			sizeWithFont:allowButton.titleLabel.font];
		CGFloat buttonWidth = buttonTextSize.width + 40;
		allowButton.frame = CGRectMake((CGFloat)(int)((containerWidth - buttonWidth) / 2),
			CGRectGetMaxY(subtitleLabel.frame) + 20, buttonWidth, 40);
	}
}

- (void)updatePhonebookAccess {
	BOOL deniedRaw = [self phonebookAccessDenied];
	BOOL showDeniedOverlay = deniedRaw && !self.users.count;
	BOOL askingForAccess = !deniedRaw && [self phonebookAccessUndetermined] && self.loaded && !self.users.count;
	[self updatePhonebookDeniedBanner];
	if (!showDeniedOverlay && !askingForAccess) {
		if (self.phonebookAccessOverlay) {
			[self.phonebookAccessOverlay removeFromSuperview];
			self.phonebookAccessOverlay = nil;
			self.tableView.scrollEnabled = YES;
			self.addButton.hidden = NO;
			self.sortButton.hidden = NO;
		}
		return;
	}
	if (self.phonebookAccessOverlay)
		return;

	UIView *overlay = [self buildPhonebookAccessOverlayAskingForAccess:askingForAccess];
	[self.view addSubview:overlay];
	self.phonebookAccessOverlay = overlay;
	self.tableView.scrollEnabled = NO;
	self.addButton.hidden = YES;
	self.sortButton.hidden = YES;
	[self layoutPhonebookAccessOverlay];
}

- (void)phonebookDeniedBannerPressed {
	[[[UIAlertView alloc] initWithTitle:TGL(@"AccessDenied.Title", @"Access Denied")
								message:TGL(@"AccessDenied.Contacts", @"Telegram needs access to your contacts. Please go to Settings > Privacy > Contacts and turn it on.")
							   delegate:nil
					  cancelButtonTitle:TGL(@"Common.OK", @"OK")
					  otherButtonTitles:nil] show];
}

- (void)updatePhonebookDeniedBanner {
	if (!self.phonebookDeniedBanner)
		return;
	BOOL show = [self phonebookAccessDenied] && self.users.count > 0;
	if (self.phonebookDeniedBanner.hidden == !show)
		return;
	self.phonebookDeniedBanner.hidden = !show;
	[self layoutHeaderContainer];
}

- (void)requestPhonebookAccess {
	[self startAddressBookImport];
}

- (void)resyncAddressBookAfterExternalChange {
	if (self.pickerMode)
		return;
	if ([self phonebookAccessDenied] || [self phonebookAccessUndetermined])
		return;
	[self startAddressBookImport];
}

- (void)startObservingAddressBookExternalChanges {
	if (self.addressBookRef)
		return;
	ABAddressBookRef book = ABAddressBookCreateWithOptions(NULL, NULL);
	if (!book)
		return;
	ABAddressBookRegisterExternalChangeCallback(book, TGContactsAddressBookExternalChangeCallback, (__bridge void *)self);
	self.addressBookRef = book;
}

- (void)stopObservingAddressBookExternalChanges {
	if (!self.addressBookRef)
		return;
	ABAddressBookUnregisterExternalChangeCallback(self.addressBookRef, TGContactsAddressBookExternalChangeCallback, (__bridge void *)self);
	CFRelease(self.addressBookRef);
	self.addressBookRef = NULL;
}

- (UILabel *)buildPhonebookAccessSubtitleLabelAskingForAccess:(BOOL)askingForAccess {
	CGFloat bodySize = ([UIScreen mainScreen].scale > 1.5f) ? 14.5f : 15.0f;
	NSString *body = askingForAccess
		? TGL(@"Contacts.PermissionsText", @"Please allow Telegram access to your phonebook to seamlessly find all your friends.")
		: TGL(@"Contacts.AccessDeniedText", @"Please go to your iPhone Settings — Privacy — Contacts. Then select ON for Telegram.");
	UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	subtitleLabel.tag = 400;
	subtitleLabel.backgroundColor = [UIColor clearColor];
	subtitleLabel.font = [UIFont boldSystemFontOfSize:bodySize];
	subtitleLabel.textColor = TGColourFromHex(0x697487);
	subtitleLabel.shadowColor = [UIColor colorWithWhite:1.0f alpha:0.3f];
	subtitleLabel.shadowOffset = CGSizeMake(0, 1);
	subtitleLabel.numberOfLines = 0;
	subtitleLabel.textAlignment = NSTextAlignmentCenter;
	if (!askingForAccess && [UILabel instancesRespondToSelector:@selector(setAttributedText:)]) {
		NSMutableAttributedString *text = [[NSMutableAttributedString alloc]
			initWithString:body
				attributes:@{NSFontAttributeName : [UIFont systemFontOfSize:bodySize],
					NSForegroundColorAttributeName : TGColourFromHex(0x697487)}];
		NSRange range = [body rangeOfString:@"ON"];
		if (range.length)
			[text addAttribute:NSFontAttributeName
						 value:[UIFont boldSystemFontOfSize:bodySize]
						 range:range];
		subtitleLabel.attributedText = text;
	} else {
		subtitleLabel.text = body;
	}
	return subtitleLabel;
}

- (UIView *)buildPhonebookAccessOverlayAskingForAccess:(BOOL)askingForAccess {
	UIView *overlay = [[UIView alloc] initWithFrame:self.view.bounds];
	overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	overlay.backgroundColor = TGGroupedListBackground();

	UIView *container = [[UIView alloc] initWithFrame:CGRectZero];
	container.tag = 100;
	container.backgroundColor = [UIColor clearColor];
	container.clipsToBounds = NO;
	container.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
	[overlay addSubview:container];

	UIImageView *iconView = [[UIImageView alloc] initWithImage:
			[UIImage imageNamed:@"ContactsIcon"]];
	iconView.tag = 200;
	[container addSubview:iconView];

	UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	titleLabel.tag = 300;
	titleLabel.backgroundColor = [UIColor clearColor];
	titleLabel.font = [UIFont boldSystemFontOfSize:17];
	titleLabel.textColor = TGColourFromHex(0x697487);
	titleLabel.shadowColor = [UIColor colorWithWhite:1.0f alpha:0.3f];
	titleLabel.shadowOffset = CGSizeMake(0, 1);
	titleLabel.numberOfLines = 0;
	titleLabel.textAlignment = NSTextAlignmentCenter;
	titleLabel.text = askingForAccess
		? TGL(@"Contacts.PermissionsTitle", @"Access to Contacts")
		: TGL(@"Contacts.AccessDeniedError", @"Telegram does not have access to your contacts");
	[container addSubview:titleLabel];

	[container addSubview:[self buildPhonebookAccessSubtitleLabelAskingForAccess:askingForAccess]];

	if (askingForAccess) {
		UIButton *allow = [UIButton buttonWithType:UIButtonTypeCustom];
		allow.tag = 500;
		[allow setTitle:TGL(@"Contacts.PermissionsAllow", @"Allow Access") forState:UIControlStateNormal];
		[allow setTitleColor:TGColourFromHex(0x2f99c9) forState:UIControlStateNormal];
		allow.titleLabel.font = [UIFont boldSystemFontOfSize:16];
		[allow addTarget:self action:@selector(requestPhonebookAccess) forControlEvents:UIControlEventTouchUpInside];
		[container addSubview:allow];
	}

	return overlay;
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	if (self.phonebookAccessOverlay) {
		self.phonebookAccessOverlay.frame = CGRectMake(self.tableView.contentOffset.x,
			self.tableView.contentOffset.y,
			self.tableView.bounds.size.width, self.tableView.bounds.size.height);
		[self layoutPhonebookAccessOverlay];
	}
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self updatePhonebookAccess];
	if (!self.users.count)
		[self reloadContacts];
	if (!self.pickerMode && ![self phonebookAccessDenied] && ![self phonebookAccessUndetermined])
		[self startAddressBookImport];
}

- (void)reloadContacts {
	__weak typeof(self) weakSelf = self;
	[TGContactsService contactsWithCompletion:^(NSArray *users) {
		TGContactsViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (![users isKindOfClass:NSArray.class]) {
			if ([strongSelf respondsToSelector:@selector(refreshControl)])
				[strongSelf.refreshControl endRefreshing];
			return;
		}
		strongSelf.loaded = YES;
		strongSelf.users = users;
		strongSelf.serverUsers = nil;
		strongSelf.serverQuery = nil;
		[strongSelf updatePhonebookAccess];
		[strongSelf refreshTable];
		[strongSelf fetchMissingPhotos];
		if (!strongSelf.pickerMode) {
			[strongSelf reloadCloseFriends];
			[strongSelf reloadImportedCount];
		}
		if ([strongSelf respondsToSelector:@selector(refreshControl)])
			[strongSelf.refreshControl endRefreshing];
	}];
}

- (void)styleSearchField:(UIView *)view {
	if ([view isKindOfClass:UITextField.class]) {
		UITextField *field = (UITextField *)view;
		field.background = nil;
		field.clipsToBounds = NO;
		UIImage *inputImage = [UIImage imageNamed:@"SearchInputField"];
		if (inputImage) {
			int leftCap = (int)(inputImage.size.width / 2);
			inputImage = [inputImage stretchableImageWithLeftCapWidth:leftCap topCapHeight:0];
			UIImageView *inputView = [[UIImageView alloc] initWithFrame:
					CGRectMake(0, ([UIScreen mainScreen].scale > 1.5f) ? 0.5f : 0,
						field.frame.size.width, inputImage.size.height)];
			inputView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
			inputView.image = inputImage;
			[field addSubview:inputView];
			[field sendSubviewToBack:inputView];
		}
		UIImage *icon = [UIImage imageNamed:@"SearchBarIcon"];
		if (icon && [field.leftView isKindOfClass:UIImageView.class]) {
			UIImageView *iconView = (UIImageView *)field.leftView;
			iconView.image = icon;
			[iconView sizeToFit];
		}
	}
	for (UIView *child in view.subviews)
		[self styleSearchField:child];
}

- (void)hideStripe:(UIView *)view {
	if ([view isKindOfClass:UIImageView.class] && view.frame.size.height == 1)
		view.hidden = YES;
	for (UIView *child in view.subviews)
		[self hideStripe:child];
}

- (void)viewDidLoad {
	[super viewDidLoad];

	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	if (!self.title.length)
		self.title = TGL(@"Contacts.Title", @"Contacts");
	[self updateContactSortOrder];
	[self loadContactSortMode];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	self.users = @[];
	self.photos = [[NSCache alloc] init];
	self.photos.countLimit = kContactPhotoCacheCount;
	self.photos.totalCostLimit = kContactPhotoCacheBytes;
	self.photosRequested = [NSMutableSet set];
	self.photosFailed = [NSMutableSet set];
	self.photosLoading = [NSMutableSet set];
	self.closeFriendIds = [NSMutableSet set];
	self.badges = [NSMutableDictionary dictionary];
	self.badgesRequested = [NSMutableSet set];
	self.emojiStatusIcons = [NSMutableDictionary dictionary];
	self.emojiStatusIconsRequested = [NSMutableSet set];
	self.emojiStatusImages = [[NSCache alloc] init];
	self.emojiStatusImagesRequested = [NSMutableSet set];
	self.birthdays = [NSMutableDictionary dictionary];
	self.contactFlags = [NSMutableDictionary dictionary];
	self.tableView.rowHeight = kContactRowHeight;
	self.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tableView.separatorColor = [[TGTheme shared] separatorColour];
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

	[self buildOverscrollView];
	[self buildSearchBar];
	[self buildPhonebookDeniedBanner];
	[self buildHeaderContainer];
	[self buildTableBackground];

	if (!self.pickerMode && [self respondsToSelector:@selector(setRefreshControl:)] && NSClassFromString(@"UIRefreshControl")) {
		UIRefreshControl *refresh = [[NSClassFromString(@"UIRefreshControl") alloc] init];
		[refresh addTarget:self action:@selector(reloadContacts)
			forControlEvents:UIControlEventValueChanged];
		self.refreshControl = refresh;
	}

	if (!self.pickerMode) {
		[self buildAddButton];
		[self buildSortButton];
	}

	self.tableView.tableFooterView = [[UIView alloc] init];

	if (!self.pickerMode) {
		UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc]
			initWithTarget:self
					action:@selector(longPressed:)];
		press.minimumPressDuration = 0.5f;
		[self.tableView addGestureRecognizer:press];
	}

	__weak typeof(self) weakSelf = self;
	self.userStatusChangedObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:[TGContactsService userStatusDidChangeNotificationName]
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf userStatusChanged:note];
				}];
	self.addressBookOrderMayHaveChangedObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:UIApplicationWillEnterForegroundNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf addressBookOrderMayHaveChanged];
				}];
	self.contactsDidChangeObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:[TGContactsService contactsDidChangeNotificationName]
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf reloadContacts];
				}];
	[self startObservingAddressBookExternalChanges];

	[self updatePhonebookAccess];
	[self loadInitialContactData];
}

- (void)loadInitialContactData {
	[self refreshTable];
	[self reloadContacts];
	if (!self.pickerMode) {
		[self reloadCloseFriends];
		[self reloadImportedCount];
		[self reloadContactLink];
		[self reloadMyUsernames];
	}
}

- (void)buildOverscrollView {
	UIView *overscroll = [[UIView alloc] initWithFrame:
			CGRectMake(0, -500, self.tableView.bounds.size.width, 500)];
	overscroll.backgroundColor = TGColourFromHex(0xe4e9f0);
	overscroll.opaque = YES;
	overscroll.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.tableView addSubview:overscroll];
}

- (void)buildSearchBar {
	self.searchBar = [[UISearchBar alloc] initWithFrame:
			CGRectMake(0, 0, self.tableView.bounds.size.width, 44)];
	self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.searchBar.delegate = self;
	self.searchBar.placeholder = TGL(@"Common.Search", @"Search");
	UIImage *searchBackground = [UIImage imageNamed:@"SearchBarBackground"];
	if (searchBackground && [self.searchBar respondsToSelector:@selector(setBackgroundImage:)])
		[self.searchBar setBackgroundImage:searchBackground];
	else if (![self.searchBar respondsToSelector:@selector(setBackgroundImage:)])
		[self.searchBar tg_setTintColor:[UIColor colorWithWhite:0.68f alpha:1.0f]];
	[self styleSearchField:self.searchBar];
	[self hideStripe:self.searchBar];
}

- (void)buildPhonebookDeniedBanner {
	self.phonebookDeniedBanner = [UIButton buttonWithType:UIButtonTypeCustom];
	self.phonebookDeniedBanner.frame = CGRectMake(0, 44, self.tableView.bounds.size.width, 40);
	self.phonebookDeniedBanner.hidden = YES;
	self.phonebookDeniedBanner.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.phonebookDeniedBanner.backgroundColor = TGColourFromHex(0xf3f6fa);
	self.phonebookDeniedBanner.titleLabel.font = [UIFont systemFontOfSize:12];
	self.phonebookDeniedBanner.titleLabel.numberOfLines = 0;
	self.phonebookDeniedBanner.titleLabel.textAlignment = NSTextAlignmentCenter;
	self.phonebookDeniedBanner.contentEdgeInsets = UIEdgeInsetsMake(4, 14, 4, 14);
	[self.phonebookDeniedBanner setTitleColor:TGColourFromHex(0x697487) forState:UIControlStateNormal];
	[self.phonebookDeniedBanner setTitle:TGL(@"Contacts.AccessDeniedError", @"Telegram does not have access to your contacts")
								 forState:UIControlStateNormal];
	[self.phonebookDeniedBanner addTarget:self action:@selector(phonebookDeniedBannerPressed)
						  forControlEvents:UIControlEventTouchUpInside];
}

- (void)buildHeaderContainer {
	self.headerContainer = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, self.tableView.bounds.size.width, 44)];
	self.headerContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.headerContainer addSubview:self.searchBar];
	[self.headerContainer addSubview:self.phonebookDeniedBanner];
	self.tableView.tableHeaderView = self.headerContainer;
	[self layoutHeaderContainer];
}

- (void)layoutHeaderContainer {
	CGFloat width = self.tableView.bounds.size.width;
	if (width <= 0)
		width = self.view.bounds.size.width;

	CGFloat searchHeight = CGRectGetHeight(self.searchBar.frame);
	self.searchBar.frame = CGRectMake(0, 0, width, searchHeight);

	CGFloat bannerHeight = self.phonebookDeniedBanner.hidden ? 0 : CGRectGetHeight(self.phonebookDeniedBanner.frame);
	self.phonebookDeniedBanner.frame = CGRectMake(0, searchHeight, width,
		CGRectGetHeight(self.phonebookDeniedBanner.frame));

	self.headerContainer.frame = CGRectMake(0, 0, width, searchHeight + bannerHeight);
	self.tableView.tableHeaderView = self.headerContainer;
}

- (void)buildTableBackground {
	UIView *background = [[UIView alloc] initWithFrame:self.tableView.bounds];
	background.backgroundColor = [[TGTheme shared] listBackgroundColour];
	background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.tableView.backgroundView = background;

	self.emptyPlaceholder = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, background.bounds.size.width, 70)];
	self.emptyPlaceholder.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
	self.emptyPlaceholder.backgroundColor = [UIColor clearColor];
	self.emptyPlaceholder.hidden = YES;

	UIColor *placeholderColour = [[TGTheme shared] emptyStateColour];

	self.emptyTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.emptyTitleLabel.backgroundColor = [UIColor clearColor];
	self.emptyTitleLabel.font = [UIFont boldSystemFontOfSize:14];
	self.emptyTitleLabel.textColor = placeholderColour;
	self.emptyTitleLabel.textAlignment = NSTextAlignmentCenter;
	self.emptyTitleLabel.shadowColor = [UIColor colorWithWhite:1.0f alpha:0.5f];
	self.emptyTitleLabel.shadowOffset = CGSizeMake(0, 1);
	[self.emptyPlaceholder addSubview:self.emptyTitleLabel];

	self.emptyHelpLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.emptyHelpLabel.backgroundColor = [UIColor clearColor];
	self.emptyHelpLabel.font = [UIFont systemFontOfSize:14];
	self.emptyHelpLabel.textColor = placeholderColour;
	self.emptyHelpLabel.textAlignment = NSTextAlignmentCenter;
	self.emptyHelpLabel.numberOfLines = 0;
	self.emptyHelpLabel.shadowColor = [UIColor colorWithWhite:1.0f alpha:0.5f];
	self.emptyHelpLabel.shadowOffset = CGSizeMake(0, 1);
	[self.emptyPlaceholder addSubview:self.emptyHelpLabel];

	[background addSubview:self.emptyPlaceholder];
}

- (void)updateEmptyState {
	if (!self.emptyPlaceholder)
		return;
	NSString *query = [self.searchQuery
		stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	BOOL searching = query.length && self.filteredUsers;
	BOOL noResults = searching && !self.filteredUsers.count;
	if (!noResults) {
		self.emptyPlaceholder.hidden = YES;
		self.tableView.scrollEnabled = YES;
		return;
	}

	CGFloat width = self.emptyPlaceholder.bounds.size.width;
	CGFloat helpWidth = MIN(260.0f, MAX(160.0f, width - 40.0f));

	self.emptyTitleLabel.text = TGL(@"ChatList.Search.NoResults", @"No Results");
	CGSize titleSize = [self.emptyTitleLabel.text sizeWithFont:self.emptyTitleLabel.font];
	self.emptyTitleLabel.frame = CGRectMake(0, 0, width, titleSize.height);

	self.emptyHelpLabel.text = TGL(@"Contacts.Search.NoResults", @"No contact or Telegram user matches that name.");
	CGSize helpSize = [self.emptyHelpLabel.text sizeWithFont:self.emptyHelpLabel.font
										   constrainedToSize:CGSizeMake(helpWidth, 1000)
											   lineBreakMode:NSLineBreakByWordWrapping];
	self.emptyHelpLabel.frame = CGRectMake((CGFloat)(int)((width - helpWidth) / 2), 26,
		helpWidth, helpSize.height);

	self.tableView.scrollEnabled = noResults;
	CGFloat totalHeight = 26 + helpSize.height;
	UIView *host = self.emptyPlaceholder.superview;
	CGFloat hostHeight = host ? host.bounds.size.height : totalHeight;
	CGRect frame = self.emptyPlaceholder.frame;
	frame.size.height = totalHeight;
	frame.origin.y = (CGFloat)(int)((hostHeight - totalHeight) / 2) - 40;
	if (frame.origin.y < 0)
		frame.origin.y = 0;
	self.emptyPlaceholder.frame = frame;
	self.emptyPlaceholder.hidden = NO;
}

- (void)buildAddButton {
	UIButton *add = [UIButton buttonWithType:UIButtonTypeCustom];
	[TGIcons styleHeaderButton:add];
	[add addTarget:self action:@selector(addContactTapped) forControlEvents:UIControlEventTouchUpInside];
	add.frame = CGRectMake(0, 0, 30, 30);
	UILabel *plus = [[UILabel alloc] initWithFrame:CGRectOffset(add.bounds, 0, -2)];
	plus.text = @"+";
	plus.textColor = [UIColor whiteColor];
	plus.textAlignment = NSTextAlignmentCenter;
	plus.backgroundColor = [UIColor clearColor];
	plus.font = [UIFont boldSystemFontOfSize:18];
	plus.userInteractionEnabled = NO;
	UIImage *addIcon = [UIImage imageNamed:@"AddIcon"];
	if (addIcon) {
		plus.hidden = YES;
		[add setImage:addIcon forState:UIControlStateNormal];
		add.frame = CGRectMake(0, 0, MAX(35.0f, addIcon.size.width + 12), 30);
	}
	[add addSubview:plus];
	self.addButton = add;
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:add];
}

- (void)buildSortButton {
	UIButton *sort = [TGIcons headerButtonWithTitle:TGL(@"Contacts.Sort", @"Sort") bold:NO
											 target:self
											 action:@selector(sortTapped)];
	if (!sort) {
		sort = [UIButton buttonWithType:UIButtonTypeCustom];
		[TGIcons styleHeaderButton:sort];
		[sort setTitle:TGL(@"Contacts.Sort", @"Sort") forState:UIControlStateNormal];
		sort.titleLabel.font = [UIFont boldSystemFontOfSize:13];
		[sort addTarget:self action:@selector(sortTapped)
			forControlEvents:UIControlEventTouchUpInside];
		sort.frame = CGRectMake(0, 0, 51, 30);
	}
	if (sort.frame.size.width < 51) {
		CGRect frame = sort.frame;
		frame.size.width = 51;
		sort.frame = frame;
		for (UIView *sub in sort.subviews) {
			CGRect subFrame = sub.frame;
			subFrame.origin.x = 0;
			subFrame.size.width = 51;
			sub.frame = subFrame;
		}
	}
	self.sortButton = sort;
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:sort];
}

- (void)loadContactSortMode {
	id stored = [[NSUserDefaults standardUserDefaults]
		objectForKey:TGContactsSortByLastSeenKey];
	self.sortByLastSeen = stored ? [stored boolValue] : YES;
}

- (void)sortTapped {
	NSString *nameTitle = TGL(@"Contacts.SortByName", @"Name");
	NSString *lastSeenTitle = TGL(@"Contacts.SortByPresence", @"Last Seen");
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:TGL(@"Contacts.SortBy", @"Sort Contacts By")
					  delegate:self
				   otherTitles:@[ self.sortByLastSeen ? nameTitle : [@"✓ " stringByAppendingString:nameTitle],
					   self.sortByLastSeen ? [@"✓ " stringByAppendingString:lastSeenTitle] : lastSeenTitle ]
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 5;
	[self presentSheet:sheet];
}

- (void)handleSortSheetAtIndex:(NSInteger)index {
	if (index != 0 && index != 1)
		return;
	BOOL byLastSeen = (index == 1);
	[[NSUserDefaults standardUserDefaults] setBool:byLastSeen
											forKey:TGContactsSortByLastSeenKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
	if (byLastSeen == self.sortByLastSeen)
		return;
	self.sortByLastSeen = byLastSeen;
	[self refreshTable];
	if (self.tableView.numberOfSections > 0)
		[self.tableView setContentOffset:CGPointMake(0, -self.tableView.contentInset.top)
								animated:NO];
}

- (void)newGroupTapped {
	TGNewGroupMembersViewController *vc = [[TGNewGroupMembersViewController alloc] init];
	vc.contacts = self.users;
	[self.navigationController pushViewController:vc animated:YES];
}

- (void)addContactTapped {
	ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
	if (status == kABAuthorizationStatusDenied || status == kABAuthorizationStatusRestricted) {
		[[[UIAlertView alloc] initWithTitle:TGL(@"AccessDenied.Title", @"Access Denied")
									message:TGL(@"AccessDenied.Contacts",
												@"Telegram needs access to your contacts. Please go to Settings > Privacy > Contacts and turn it on.")
								   delegate:nil
						  cancelButtonTitle:TGL(@"Common.OK", @"OK")
						  otherButtonTitles:nil] show];
		return;
	}
	if (status == kABAuthorizationStatusNotDetermined) {
		ABAddressBookRef book = ABAddressBookCreateWithOptions(NULL, NULL);
		if (book) {
			__weak typeof(self) weakSelf = self;
			ABAddressBookRequestAccessWithCompletion(book, ^(bool granted, CFErrorRef error) {
				CFRelease(book);
				dispatch_async(dispatch_get_main_queue(), ^{
					if (granted)
						[weakSelf presentNewContactScreen];
				});
			});
			return;
		}
	}
	[self presentNewContactScreen];
}

- (void)openProfileForUserId:(int64_t)userId {
	__weak typeof(self) weakSelf = self;
	[TGContactsService privateChatWithUser:userId completion:^(int64_t chatId) {
		TGContactsViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSString *name = @"";
		for (NSDictionary *u in strongSelf.users) {
			if ([u[@"id"] longLongValue] == userId) {
				name = TGContactName(u);
				break;
			}
		}
		TGProfileViewController *vc = [[TGProfileViewController alloc]
			initWithChatId:chatId
					userId:userId
					 title:name];
		[strongSelf openTarget:vc];
	}];
}

- (void)presentNewContactScreen {
	TGNewContactViewController *vc = [[TGNewContactViewController alloc] init];
	__weak typeof(self) weakSelf = self;
	vc.onDone = ^(BOOL saved, int64_t userId) {
		TGContactsViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf reloadContacts];
		if (!saved) {
			[TGSnackbar showInView:strongSelf.view
							   text:TGL(@"Toast.CouldNotSaveContact", @"Could not save the contact")
							seconds:2
						   onCommit:nil];
			return;
		}
		if (userId) {
			[strongSelf openProfileForUserId:userId];
			return;
		}
		[TGSnackbar showInView:strongSelf.view
						   text:TGL(@"Toast.ContactAdded", @"Added to contacts")
						seconds:2
					   onCommit:nil];
	};
	UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
	[self presentModalViewController:nav animated:YES];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	[self.photos removeAllObjects];
}

@end

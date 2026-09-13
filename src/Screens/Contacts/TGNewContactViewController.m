#import "TGTextFieldStyle.h"
#import "TGListBackground.h"
#import "TGNewContactViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGIcons.h"

UIColor *TGNewContactColour(int rgb, CGFloat alpha) {
	return [UIColor colorWithRed:((rgb >> 16) & 0xff) / 255.0f
						   green:((rgb >> 8) & 0xff) / 255.0f
							blue:(rgb & 0xff) / 255.0f
						   alpha:alpha];
}

void TGNewContactApplyMinimumWidth(UIButton *button, CGFloat minimumWidth) {
	if (!button || button.frame.size.width >= minimumWidth)
		return;
	CGRect frame = button.frame;
	frame.size.width = minimumWidth;
	button.frame = frame;
	for (UIView *sub in button.subviews) {
		CGRect subFrame = sub.frame;
		subFrame.origin.x = 0;
		subFrame.size.width = minimumWidth;
		sub.frame = subFrame;
	}
}

const CGFloat kNewContactAvatarSide = 70.0f;
const CGFloat kNewContactAvatarGap = 14.0f;
const CGFloat kNewContactHeaderTop = 14.0f;
const CGFloat kNewContactHeaderBottom = 10.0f;
const CGFloat kNewContactNameRow = 44.0f;
const CGFloat kNewContactCaptionInset = 12.0f;
const CGFloat kNewContactCaptionPadding = 7.0f;
const CGFloat kNewContactNarrowInset = 10.0f;
const CGFloat kNewContactWideInsetMin = 31.0f;
const CGFloat kNewContactWideInsetMax = 45.0f;

CGFloat TGNewContactGroupedInset(CGFloat width) {
	if (width <= 20.0f)
		return 0.0f;
	if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad || width <= 400.0f)
		return kNewContactNarrowInset;
	return MAX(kNewContactWideInsetMin, MIN(kNewContactWideInsetMax, width * 0.06f));
}

UIImage *TGNewContactStretchedImage(NSString *name) {
	UIImage *raw = [UIImage imageNamed:name];
	if (!raw)
		return nil;
	return [raw stretchableImageWithLeftCapWidth:(int)(raw.size.width / 2) topCapHeight:0];
}

@implementation TGNewContactViewController

- (id)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (!self)
		return nil;
	self.phoneEntries = [[NSMutableArray alloc] init];
	self.syncToPhone = YES;
	return self;
}

- (BOOL)hasKnownPeer {
	return self.peerUserId != 0;
}

- (BOOL)writesAddressBookRecord {
	return self.syncToPhone && !self.editingExistingContact && ![self hasKnownPeer];
}

- (BOOL)updatesAddressBookRecord {
	return self.syncToPhone && self.editingExistingContact;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	self.title = self.editingExistingContact ? TGL(@"NewContact.EditTitle", @"Edit Contact") : TGL(@"NewContact.Title", @"New Contact");
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.rowHeight = 44.0f;
	self.tableView.sectionFooterHeight = 0.0f;
	self.tableView.allowsSelectionDuringEditing = YES;

	UIButton *cancel = [TGIcons headerButtonWithTitle:TGL(@"Common.Cancel", @"Cancel") bold:NO
											   target:self
											   action:@selector(cancelTapped)];
	TGNewContactApplyMinimumWidth(cancel, 59.0f);
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cancel];

	self.doneButton = [TGIcons headerButtonWithTitle:TGL(@"Common.Done", @"Done") bold:YES
											  target:self
											  action:@selector(doneTapped)];
	TGNewContactApplyMinimumWidth(self.doneButton, 51.0f);
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.doneButton];

	self.firstNameField = [self makeFieldWithPlaceholder:TGL(@"UserInfo.FirstNamePlaceholder", @"First") font:[UIFont boldSystemFontOfSize:16]];
	self.firstNameField.returnKeyType = UIReturnKeyNext;
	self.firstNameField.text = self.prefillFirstName ?: @"";
	self.lastNameField = [self makeFieldWithPlaceholder:TGL(@"UserInfo.LastNamePlaceholder", @"Last") font:[UIFont boldSystemFontOfSize:16]];
	self.lastNameField.returnKeyType = UIReturnKeyDefault;
	self.lastNameField.text = self.prefillLastName ?: @"";

	if ([self hasKnownPeer]) {
		self.resolvedUserId = self.peerUserId;
		self.resolveFinished = YES;
	} else {
		[self.phoneEntries addObject:[self makePhoneEntry]];
		[self.phoneEntries addObject:[self makePhoneEntry]];
		if (self.prefillPhone.length) {
			UITextField *first = [[self.phoneEntries objectAtIndex:0] objectForKey:@"field"];
			first.text = [self.prefillPhone hasPrefix:@"+"]
				? self.prefillPhone
				: [@"+" stringByAppendingString:self.prefillPhone];
		}
	}

	[self buildTableHeader];

	__weak typeof(self) weakSelf = self;
	self.textChangedObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:UITextFieldTextDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf textChanged:note];
				}];
	[self.tableView setEditing:YES animated:NO];
	[self updateDoneEnabled];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	if (self.didFocusNameField)
		return;
	self.didFocusNameField = YES;
	[self.firstNameField becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self.view endEditing:YES];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	[self layoutTableHeader];
}

- (void)dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (self.textChangedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.textChangedObserverToken];
	self.firstNameField.delegate = nil;
	self.lastNameField.delegate = nil;
	for (NSMutableDictionary *entry in self.phoneEntries)
		((UITextField *)[entry objectForKey:@"field"]).delegate = nil;
}

- (void)focusOnFirstNameField {
	[self.firstNameField becomeFirstResponder];
}

- (void)focusOnLastNameField {
	[self.lastNameField becomeFirstResponder];
}

- (UITextField *)makeFieldWithPlaceholder:(NSString *)placeholder font:(UIFont *)font {
	UITextField *field = [[UITextField alloc] init];
	field.placeholder = placeholder;
	field.font = font;
	field.backgroundColor = [UIColor clearColor];
	TGStyleTextField(field);
	field.contentMode = UIViewContentModeLeft;
	field.clearButtonMode = UITextFieldViewModeWhileEditing;
	field.delegate = self;
	field.autocorrectionType = UITextAutocorrectionTypeNo;
	return field;
}

@end

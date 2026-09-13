#import "TGIcons.h"
#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGWebBrowserSettingsViewController.h"
#import "TGSectionHeaderTitle.h"
#import "TGLocalization.h"
#import "TGClient+AppSettings.h"
#import "TGTheme.h"
#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "TGPrivacyViewControllerInternal.h"
#import "TGWebBrowserExceptionURL.h"

static const NSInteger kAddExceptionAlertTag = 1;
static const NSInteger kDeleteAllExceptionsAlertTag = 2;

@interface TGWebBrowserSettingsViewController () <UIAlertViewDelegate>

@property (nonatomic, strong) NSArray *inAppExceptions;
@property (nonatomic, strong) NSArray *externalExceptions;
@property (nonatomic, copy) NSString *pendingExceptionUrl;
@property (nonatomic, strong) id settingsChangedObserverToken;

@end

@implementation TGWebBrowserSettingsViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.title = TGL(@"WebBrowser.Title", @"Web Browser");
	__weak typeof(self) weakSelf = self;
	self.settingsChangedObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGWebBrowserSettingsDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf settingsChanged];
				}];
	[self reload];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (self.settingsChangedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.settingsChangedObserverToken];
}

- (void)settingsChanged {
	[self reload];
}

- (void)reload {
	NSDictionary *settings = [[TGClient shared] cachedWebBrowserSettings];
	self.inAppExceptions = settings[@"inAppExceptions"] ?: @[];
	self.externalExceptions = settings[@"externalExceptions"] ?: @[];
	[self.tableView reloadData];
}

- (NSUInteger)totalExceptionsCount {
	return self.inAppExceptions.count + self.externalExceptions.count;
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return 1;
	if (section == 1)
		return (NSInteger)self.inAppExceptions.count;
	if (section == 2)
		return (NSInteger)self.externalExceptions.count;
	return [self totalExceptionsCount] > 0 ? 2 : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 1)
		return TGSectionHeaderTitle(TGL(@"WebBrowser.Exceptions.OpenInApp", @"OPEN IN-APP"),
			(NSInteger)self.inAppExceptions.count);
	if (section == 2)
		return TGSectionHeaderTitle(TGL(@"WebBrowser.Exceptions.DontOpenInApp", @"DON'T OPEN IN-APP"),
			(NSInteger)self.externalExceptions.count);
	return nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderHeightForTitle:title];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section == 0)
		return TGL(@"WebBrowser.OpenLinksInfo", @"Links you tap in Telegram open here, unless a website below is set to always open the other way.");
	if (section == 1 && self.inAppExceptions.count)
		return TGL(@"WebBrowser.Exceptions.InAppInfo", @"These sites will still be opened in-app.");
	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	CGFloat measured = [[TGTheme shared] groupedCommentHeightForText:caption width:tableView.bounds.size.width];
	return TGGroupedFooterHeight(caption, measured);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	if (!caption.length)
		return nil;
	return [[TGTheme shared] groupedCommentViewWithText:caption width:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 0) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"default"];
		if (!cell)
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"default"];
		[[TGTheme shared] styleCell:cell];
		cell.textLabel.font = TGGroupedRowTitleFont();
		cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
		cell.textLabel.text = TGL(@"WebBrowser.OpenLinksIn.Title", @"Open Links in External Browser");
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		UISwitch *toggle = [[UISwitch alloc] init];
		toggle.on = [[[TGClient shared] cachedWebBrowserSettings][@"openExternalBrowser"] boolValue];
		[toggle addTarget:self action:@selector(defaultToggled:) forControlEvents:UIControlEventValueChanged];
		cell.accessoryView = toggle;
		return cell;
	}

	if (indexPath.section == 1 || indexPath.section == 2) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"exception"];
		if (!cell)
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"exception"];
		[[TGTheme shared] styleCell:cell];
		NSArray *entries = indexPath.section == 1 ? self.inAppExceptions : self.externalExceptions;
		NSDictionary *entry = entries[(NSUInteger)indexPath.row];
		cell.textLabel.font = TGGroupedRowTitleFont();
		cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
		cell.textLabel.text = entry[@"domain"];
		cell.detailTextLabel.text = nil;
		cell.accessoryType = UITableViewCellAccessoryNone;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		return cell;
	}

	if (indexPath.row == 0) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"add"];
		if (!cell)
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"add"];
		[[TGTheme shared] styleCell:cell];
		cell.textLabel.font = TGGroupedRowTitleFont();
		cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
		cell.textLabel.text = TGL(@"WebBrowser.Exceptions.AddException", @"Add an Exception...");
		cell.textLabel.textColor = [[TGTheme shared] groupedInfoColour];
		cell.accessoryType = UITableViewCellAccessoryNone;
		return cell;
	}

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"deleteAll"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"deleteAll"];
	[TGIcons actionButtonInCell:cell
						  title:TGL(@"WebBrowser.Exceptions.DeleteAll", @"Delete All Exceptions")
						   kind:TGActionButtonKindDestructive
						 target:self
						 action:@selector(confirmDeleteAllExceptions)];
	return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 1)
		return (NSUInteger)indexPath.row < self.inAppExceptions.count;
	if (indexPath.section == 2)
		return (NSUInteger)indexPath.row < self.externalExceptions.count;
	return NO;
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
	return TGL(@"Common.Delete", @"Delete");
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
	 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete)
		return;
	if (indexPath.section != 1 && indexPath.section != 2)
		return;
	NSArray *entries = indexPath.section == 1 ? self.inAppExceptions : self.externalExceptions;
	if ((NSUInteger)indexPath.row >= entries.count)
		return;
	NSDictionary *entry = entries[(NSUInteger)indexPath.row];
	NSString *url = entry[@"url"];
	if (!url.length)
		url = entry[@"domain"];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] removeWebBrowserSettingsExceptionForUrl:url completion:^(BOOL success) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!success)
			TGPrivacyComplain(TGL(@"Privacy.TheSettingCouldNotBeChanged", @"That setting could not be changed."));
		[strongSelf reload];
	}];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 3 && indexPath.row == 1)
		return TGActionRowHeight();
	return 44;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section != 3)
		return;
	if (indexPath.row == 0)
		[self promptForNewException];
}

- (void)defaultToggled:(UISwitch *)toggle {
	BOOL closeButton = [[[TGClient shared] cachedWebBrowserSettings][@"displayCloseButton"] boolValue];
	BOOL requested = toggle.on;
	[[TGClient shared] changeWebBrowserSettingsOpenExternal:requested
										 displayCloseButton:closeButton
												 completion:^(BOOL success) {
		if (success)
			return;
		toggle.on = !requested;
		TGPrivacyComplain(TGL(@"Privacy.TheSettingCouldNotBeChanged", @"That setting could not be changed."));
	}];
}

- (void)promptForNewException {
	TGAlertView *ask = [TGAlertView alloc];
	ask = [ask initWithTitle:TGL(@"WebBrowser.Exceptions.AddException", @"Add an Exception...")
					 message:TGL(@"WebBrowser.Exceptions.Create.Placeholder", @"Website address")
					delegate:self
		   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		   otherButtonTitles:TGL(@"Common.Next", @"Next"), nil];
	if ([ask respondsToSelector:@selector(setAlertViewStyle:)])
		ask.alertViewStyle = UIAlertViewStylePlainTextInput;
	ask.tag = kAddExceptionAlertTag;
	[ask show];
}

- (void)confirmDeleteAllExceptions {
	TGAlertView *confirm = [TGAlertView alloc];
	confirm = [confirm initWithTitle:TGL(@"WebBrowser.Exceptions.DeleteAll", @"Delete All Exceptions")
							 message:nil
							delegate:self
				   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
				   otherButtonTitles:TGL(@"Common.Delete", @"Delete"), nil];
	confirm.tag = kDeleteAllExceptionsAlertTag;
	[confirm show];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if (alertView.tag == kDeleteAllExceptionsAlertTag) {
		if (buttonIndex == alertView.cancelButtonIndex)
			return;
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] removeAllWebBrowserSettingsExceptionsWithCompletion:^(BOOL success) {
			__strong typeof(weakSelf) strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!success)
				TGPrivacyComplain(TGL(@"Privacy.TheSettingCouldNotBeChanged", @"That setting could not be changed."));
			[strongSelf reload];
		}];
		return;
	}

	if (alertView.tag != kAddExceptionAlertTag || buttonIndex == alertView.cancelButtonIndex)
		return;
	NSString *entered = [alertView textFieldAtIndex:0].text;
	entered = TGWebBrowserNormalizeExceptionURL(entered);
	if (!entered.length)
		return;
	self.pendingExceptionUrl = entered;

	NSArray *actions = @[
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"WebBrowser.Exception.OpenInBrowser", @"Always Open Externally") action:@"external"],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"WebBrowser.Exception.OpenInApp", @"Always Open In-App") action:@"inApp"],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Common.Cancel", @"Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel],
	];
	__weak typeof(self) weakSelf = self;
	void (^chosen)(id, NSString *) = ^(id target, NSString *action) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || [action isEqualToString:@"cancel"])
			return;
		NSString *url = strongSelf.pendingExceptionUrl;
		strongSelf.pendingExceptionUrl = nil;
		TGClient *client = [TGClient shared];
		[client addWebBrowserSettingsExceptionForUrl:url
									 openExternally:[action isEqualToString:@"external"]
										 completion:^(BOOL success) {
			__strong typeof(weakSelf) innerSelf = weakSelf;
			if (!innerSelf)
				return;
			if (!success)
				TGPrivacyComplain(TGL(@"Privacy.TheSettingCouldNotBeChanged", @"That setting could not be changed."));
			[innerSelf reload];
		}];
	};
	TGActionSheet *sheet = [[TGActionSheet alloc] initWithTitle:nil actions:actions actionBlock:chosen target:self];
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1)
					 inView:self.view];
}

@end

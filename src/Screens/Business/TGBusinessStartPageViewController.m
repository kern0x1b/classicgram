#import "TGFormSaveState.h"
#import "TGTextFieldStyle.h"
#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGBusinessStartPageViewController.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGBusinessService.h"
#import "TGBusinessStartPageStickerPickerViewController.h"
#import "TGTheme.h"
#import "TGSnackbar.h"

static const NSInteger TGBusinessStartPageSectionTitle = 0;
static const NSInteger TGBusinessStartPageSectionMessage = 1;
static const NSInteger TGBusinessStartPageSectionSticker = 2;
static const NSInteger TGBusinessStartPageSectionRemoveSticker = 3;

@interface TGBusinessStartPageViewController () <UITextFieldDelegate>

@property (nonatomic, strong) UITextField *titleField;
@property (nonatomic, strong) UITextField *messageField;
@property (nonatomic, strong) id sticker;
@property (nonatomic, assign) BOOL loaded;

@end

@implementation TGBusinessStartPageViewController

- (instancetype)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self)
		self.title = TGL(@"Business.Intro.Title", @"Start Page");
	return self;
}

- (UITextField *)makeFieldWithPlaceholder:(NSString *)placeholder {
	UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(15, 12, 290, 22)];
	field.placeholder = placeholder;
	field.font = TGTextFieldFont();
	field.backgroundColor = [UIColor clearColor];
	field.clearButtonMode = UITextFieldViewModeWhileEditing;
	field.returnKeyType = UIReturnKeyNext;
	field.textColor = [[TGTheme shared] primaryTextColour];
	field.delegate = self;
	field.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	TGStyleTextField(field);
	return field;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.navigationItem.rightBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"Common.Save", @"Save") bold:YES
									   target:self
									   action:@selector(save)];

	self.titleField = [self makeFieldWithPlaceholder:TGL(@"Business.Intro.IntroTitlePlaceholder", @"Title")];
	self.messageField = [self makeFieldWithPlaceholder:TGL(@"Business.Intro.IntroTextPlaceholder", @"Message")];
	self.messageField.returnKeyType = UIReturnKeyDone;

	__weak typeof(self) weakSelf = self;
	[TGBusinessService businessSettingsWithCompletion:^(NSDictionary *settings, BOOL failed) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (failed) {
			strongSelf.navigationItem.rightBarButtonItem.enabled = TGFormCanSave(YES, YES, NO);
			[TGSnackbar showInView:strongSelf.navigationController.view
							  text:TGL(@"Toast.CouldNotLoadBusinessSettings", @"Could not read your business settings")
						   seconds:2
						  onCommit:nil];
			return;
		}
		NSDictionary *page = settings[@"startPage"];
		strongSelf.titleField.text = [page[@"title"] isKindOfClass:NSString.class] ? page[@"title"] : @"";
		strongSelf.messageField.text = [page[@"message"] isKindOfClass:NSString.class] ? page[@"message"] : @"";
		id sticker = page[@"sticker"];
		strongSelf.sticker = [sticker isKindOfClass:NSDictionary.class] ? sticker : nil;
		strongSelf.loaded = YES;
		[strongSelf.tableView reloadData];
	}];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

#pragma mark - table

- (BOOL)hasSticker {
	return self.sticker != nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == TGBusinessStartPageSectionRemoveSticker)
		return [self hasSticker] ? 1 : 0;
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == TGBusinessStartPageSectionTitle)
		return TGL(@"Business.Intro.IntroTitlePlaceholder", @"Title");
	if (section == TGBusinessStartPageSectionMessage)
		return TGL(@"Conversation.InputTextPlaceholder", @"Message");
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
	if (section == TGBusinessStartPageSectionMessage)
		return TGL(@"Business.IntroInfo", @"Shown to new customers instead of an empty chat when they open a conversation with you for the first time.");
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
	if (indexPath.section == TGBusinessStartPageSectionSticker) {
		UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
		[[TGTheme shared] styleCell:cell];
		cell.selectionStyle = UITableViewCellSelectionStyleDefault;
		cell.textLabel.text = TGL(@"Message.Sticker", @"Sticker");
		NSString *emoji = [self.sticker[@"emoji"] isKindOfClass:NSString.class] ? self.sticker[@"emoji"] : nil;
		cell.detailTextLabel.text = emoji.length ? emoji : TGL(@"GroupInfo.SharedMediaNone", @"None");
		cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		return cell;
	}

	if (indexPath.section == TGBusinessStartPageSectionRemoveSticker) {
		UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
		[[TGTheme shared] styleCell:cell];
		[TGIcons actionButtonInCell:cell
							  title:TGL(@"Business.Intro.RemoveSticker", @"Remove Sticker")
							   kind:TGActionButtonKindDestructive
							 target:self
							 action:@selector(removeStickerPressed)];
		return cell;
	}

	UITableViewCell *cell =
		[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	UITextField *field = indexPath.section == TGBusinessStartPageSectionTitle ? self.titleField : self.messageField;
	CGFloat width = tableView.bounds.size.width - 40;
	field.frame = CGRectMake(15, 12, width, 22);
	[cell.contentView addSubview:field];
	return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == TGBusinessStartPageSectionRemoveSticker)
		return TGActionRowHeight();
	return 44;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:(indexPath.section == TGBusinessStartPageSectionSticker ||
			indexPath.section == TGBusinessStartPageSectionRemoveSticker)];
	if (indexPath.section == TGBusinessStartPageSectionSticker) {
		[self openStickerPicker];
		return;
	}
	[(indexPath.section == TGBusinessStartPageSectionTitle ? self.titleField : self.messageField) becomeFirstResponder];
}

- (void)removeStickerPressed {
	self.sticker = nil;
	[self.tableView reloadData];
}

- (void)openStickerPicker {
	TGBusinessStartPageStickerPickerViewController *picker = [[TGBusinessStartPageStickerPickerViewController alloc] init];
	__weak typeof(self) weakSelf = self;
	picker.onPicked = ^(NSDictionary *sticker) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.sticker = sticker;
		[strongSelf.tableView reloadData];
	};
	[self.navigationController pushViewController:picker animated:YES];
}

#pragma mark - text field

- (BOOL)textField:(UITextField *)field shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
	NSInteger limit = field == self.titleField ? 32 : 70;
	NSString *current = field.text ?: @"";
	if (range.location > current.length)
		return NO;
	NSString *next = [current stringByReplacingCharactersInRange:range withString:string];
	return next.length <= limit;
}

- (BOOL)textFieldShouldReturn:(UITextField *)field {
	if (field == self.titleField) {
		[self.messageField becomeFirstResponder];
		return NO;
	}
	[field resignFirstResponder];
	return NO;
}

#pragma mark - save

- (void)save {
	[self.view endEditing:YES];
	NSString *title = [self.titleField.text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSString *message = [self.messageField.text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (title.length == 0 && message.length == 0) {
		[self commitTitle:nil message:nil];
		return;
	}
	[self commitTitle:title message:message];
}

- (void)commitTitle:(NSString *)title message:(NSString *)message {
	__weak typeof(self) weakSelf = self;
	[TGBusinessService setBusinessStartPageTitle:title message:message sticker:self.sticker completion:^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[TGSnackbar showInView:strongSelf.navigationController.view
							  text:TGL(@"Toast.CouldNotSaveStartPage", @"Could not save the start page")
						   seconds:2
						  onCommit:nil];
			return;
		}
		[TGSnackbar showInView:strongSelf.navigationController.view
						  text:TGL(@"Toast.StartPageSaved", @"Saved")
					   seconds:2
					  onCommit:nil];
		[strongSelf.navigationController popViewControllerAnimated:YES];
	}];
}

@end

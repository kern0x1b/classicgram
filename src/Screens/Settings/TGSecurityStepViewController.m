#import "TGTextFieldStyle.h"
#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGSecurityStepViewController.h"
#import "TGPrivacyViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGIcons.h"

@interface TGSecurityStepViewController ()
@property (nonatomic, strong) UITextField *field;
@property (nonatomic, assign) BOOL busy;
@end

@implementation TGSecurityStepViewController

- (instancetype)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		_actionTitle = TGL(@"Common.Next", @"Next");
		_secure = YES;
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = self.stepTitle;
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.rowHeight = 44;
	self.tableView.scrollEnabled = NO;

	self.field = [[UITextField alloc] initWithFrame:CGRectZero];
	self.field.placeholder = self.placeholder;
	self.field.font = TGTextFieldFont();
	self.field.backgroundColor = [UIColor clearColor];
	self.field.textColor = [[TGTheme shared] primaryTextColour];
	self.field.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.field.secureTextEntry = self.secure;
	self.field.autocapitalizationType = UITextAutocapitalizationTypeNone;
	self.field.autocorrectionType = UITextAutocorrectionTypeNo;
	self.field.returnKeyType = UIReturnKeyDone;
	self.field.delegate = self;
	TGStyleTextField(self.field);
	if (self.numeric)
		self.field.keyboardType = UIKeyboardTypeNumberPad;
	else if (self.email)
		self.field.keyboardType = UIKeyboardTypeEmailAddress;

	[self installActionButton];
}

- (void)installActionButton {
	UIButton *button = [TGIcons headerButtonWithTitle:self.actionTitle bold:YES
											   target:self
											   action:@selector(submit)];
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:button];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[self.field becomeFirstResponder];
}

- (NSString *)text {
	NSString *text = self.field.text ?: @"";
	if (self.secure)
		return text;
	return [text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)setBusy:(BOOL)busy {
	_busy = busy;
	if (busy) {
		UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
			initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
		[spinner startAnimating];
		self.navigationItem.rightBarButtonItem =
			[[UIBarButtonItem alloc] initWithCustomView:spinner];
		[self.field resignFirstResponder];
		self.field.enabled = NO;
	} else {
		[self installActionButton];
		self.field.enabled = YES;
		[self.field becomeFirstResponder];
	}
}

- (void)refuseWithMessage:(NSString *)message {
	[self setBusy:NO];
	TGPrivacyComplain(message);
}

- (void)submit {
	if (self.busy)
		return;
	if (self.onSubmit)
		self.onSubmit(self, [self text]);
}

- (void)skip {
	if (self.busy)
		return;
	if (self.onSkip)
		self.onSkip();
}

- (BOOL)textFieldShouldReturn:(UITextField *)field {
	[self submit];
	return NO;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return self.skipTitle.length ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 0)
		return self.stepCaption;
	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return [[TGTheme shared] groupedHeaderHeightForTitle:
			[self tableView:tableView titleForHeaderInSection:section]];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section == 0)
		return self.footerText;
	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	CGFloat measured = [[TGTheme shared] groupedCommentHeightForText:caption width:tableView.bounds.size.width];
	return TGGroupedFooterHeight(caption, measured);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	return [[TGTheme shared] groupedCommentViewWithText:caption width:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 1) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"skip"];
		if (!cell)
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
										  reuseIdentifier:@"skip"];
		[TGIcons actionButtonInCell:cell
							  title:self.skipTitle
							   kind:TGActionButtonKindNeutral
							 target:self
							 action:@selector(skip)];
		return cell;
	}

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"field"];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"field"];
		[cell.contentView addSubview:self.field];
	}
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	self.field.frame = CGRectMake(15, 11, tableView.bounds.size.width - 50, 22);
	return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 1)
		return TGActionRowHeight();
	return 44;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end

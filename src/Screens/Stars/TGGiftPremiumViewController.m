#import "TGGroupedCaption.h"
#import "TGTextFieldStyle.h"
#import "TGListBackground.h"
#import "TGGiftPremiumViewController.h"
#import "TGIcons.h"
#import "TGFriendlyError.h"
#import "TGLocalization.h"
#import "TGClient+Premium.h"
#import "TGClient+Payments.h"
#import "TGTheme.h"
#import "TGAlertView.h"
#import "TGSnackbar.h"
#import "TGStarsViewController.h"

@interface TGGiftPremiumViewController () <UITextFieldDelegate>

@property (nonatomic, assign) int64_t userId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSArray *options;
@property (nonatomic, assign) NSInteger selectedIndex;
@property (nonatomic, strong) UITextField *messageField;
@property (nonatomic, copy) NSString *messageText;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, assign) BOOL sending;

@end

@implementation TGGiftPremiumViewController

- (instancetype)initWithUserId:(int64_t)userId name:(NSString *)name {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		_userId = userId;
		_name = name.length ? name : TGL(@"Stars.GiftCatalogue.ThisContactLowercase", @"this contact");
		_options = [NSArray array];
		_selectedIndex = -1;
		_messageText = @"";
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.title = TGL(@"Premium.Gift.ContactSelection.Title", @"Gift Premium");
	self.navigationItem.rightBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"MediaPicker.Send", @"Send") bold:YES
									   target:self
									   action:@selector(send)];

	self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.emptyLabel.backgroundColor = [UIColor clearColor];
	self.emptyLabel.font = [UIFont systemFontOfSize:15];
	self.emptyLabel.textColor = [[TGTheme shared] secondaryTextColour];
	self.emptyLabel.textAlignment = NSTextAlignmentCenter;
	self.emptyLabel.numberOfLines = 0;
	self.emptyLabel.text = TGL(@"Premium.GiftOptionsUnavailable", @"Gift options are unavailable right now.");
	self.emptyLabel.hidden = YES;
	[self.view addSubview:self.emptyLabel];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] premiumGiftPaymentOptionsWithCompletion:^(NSArray *options) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.options = options ?: @[];
		strongSelf.emptyLabel.hidden = strongSelf.options.count != 0;
		if (strongSelf.options.count)
			strongSelf.selectedIndex = 0;
		[strongSelf.tableView reloadData];
		[strongSelf.view setNeedsLayout];
	}];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)viewDidLayoutSubviews {
	if ([[UIViewController class] instancesRespondToSelector:@selector(viewDidLayoutSubviews)])
		[super viewDidLayoutSubviews];
	if (!self.emptyLabel.hidden) {
		CGSize size = [self.emptyLabel.text sizeWithFont:self.emptyLabel.font
									   constrainedToSize:CGSizeMake(self.view.bounds.size.width - 48, 1000)
										   lineBreakMode:NSLineBreakByWordWrapping];
		self.emptyLabel.frame = CGRectMake(24,
			floorf((self.view.bounds.size.height - size.height) / 2),
			self.view.bounds.size.width - 48, ceilf(size.height));
	}
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return self.options.count ? 2 : 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return section == 0 ? (NSInteger)self.options.count : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 0)
		return [NSString stringWithFormat:TGL(@"Premium.GiftDurationFor", @"Duration, for %@"), self.name];
	return TGL(@"Gift.Send.Customize.MessagePlaceholder", @"Message (optional)");
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderHeightForTitle:title];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 0) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"tier"];
		if (!cell)
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"tier"];
		[[TGTheme shared] styleCell:cell];
		NSDictionary *option = self.options[(NSUInteger)indexPath.row];
		NSInteger months = [option[@"months"] integerValue];
		long long stars = [option[@"stars"] longLongValue];
		cell.textLabel.font = TGGroupedRowTitleFont();
		cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
		cell.textLabel.text = TGLPlural(@"Premium.Gift.Months", months, @"%@ Month", @"%@ Months");
		cell.detailTextLabel.text = TGLPlural(@"Premium.Gift.Stars", (NSInteger)stars, @"%@ Star", @"%@ Stars");
		cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
		cell.accessoryType = indexPath.row == self.selectedIndex
			? UITableViewCellAccessoryCheckmark
			: UITableViewCellAccessoryNone;
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		return cell;
	}

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"message"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"message"];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	if (!self.messageField) {
		self.messageField = [[UITextField alloc] initWithFrame:CGRectMake(15, 12, cell.bounds.size.width - 30, 22)];
		self.messageField.placeholder = TGL(@"Gift.Send.Customize.MessageFieldPlaceholder", @"Say something nice");
		self.messageField.font = TGTextFieldFont();
		self.messageField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		self.messageField.delegate = self;
		self.messageField.returnKeyType = UIReturnKeyDone;
		self.messageField.textColor = [[TGTheme shared] primaryTextColour];
		TGStyleTextField(self.messageField);
		[self.messageField addTarget:self action:@selector(messageChanged)
					forControlEvents:UIControlEventEditingChanged];
	}
	[cell.contentView addSubview:self.messageField];
	return cell;
}

- (void)messageChanged {
	self.messageText = self.messageField.text ?: @"";
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
	return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section != 0)
		return;
	self.selectedIndex = indexPath.row;
	[tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - send

- (void)send {
	if (self.sending)
		return;
	if (self.selectedIndex < 0 || self.selectedIndex >= (NSInteger)self.options.count)
		return;
	NSDictionary *option = self.options[(NSUInteger)self.selectedIndex];
	NSInteger months = [option[@"months"] integerValue];
	long long stars = [option[@"stars"] longLongValue];
	NSString *priceText = TGLPlural(@"Premium.Gift.Stars", (NSInteger)stars, @"%@ Star", @"%@ Stars");
	NSString *message = TGL(@"Gift.Send.Premium.Confirmation.Text", @"Are you sure you want to gift Telegram Premium to %1$@ for %2$@?");
	NSString *text = [NSString stringWithFormat:message, self.name, priceText];

	self.sending = YES;
	self.navigationItem.rightBarButtonItem.enabled = NO;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] starBalanceWithCompletion:^(long long balance) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (balance < stars) {
			strongSelf.sending = NO;
			strongSelf.navigationItem.rightBarButtonItem.enabled = YES;
			[TGStarsViewController presentNotEnoughStarsAlertFromViewController:strongSelf];
			return;
		}
		void (^confirmed)(bool) = ^(bool okButtonPressed) {
			__strong typeof(weakSelf) innerSelf = weakSelf;
			if (!innerSelf)
				return;
			if (!okButtonPressed) {
				innerSelf.sending = NO;
				innerSelf.navigationItem.rightBarButtonItem.enabled = YES;
				return;
			}
			[innerSelf commitGiftWithMonths:months stars:stars];
		};
		TGAlertView *alert = [TGAlertView alloc];
		alert = [alert initWithTitle:TGL(@"Premium.Gift.ContactSelection.Title", @"Gift Premium")
							 message:text
				   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
					   okButtonTitle:TGL(@"MediaPicker.Send", @"Send")
					 completionBlock:confirmed];
		[alert show];
	}];
}

- (void)commitGiftWithMonths:(NSInteger)months stars:(long long)stars {
	__weak typeof(self) weakSelf = self;
	void (^giftSent)(BOOL, NSString *) = ^(BOOL ok, NSString *error) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			strongSelf.sending = NO;
			strongSelf.navigationItem.rightBarButtonItem.enabled = YES;
			NSString *failText = TGFriendlyErrorText(error, TGL(@"Premium.GiftCouldNotBeSent", @"This gift could not be sent."));
			TGAlertView *fail = [TGAlertView alloc];
			fail = [fail initWithTitle:nil
							   message:failText
					 cancelButtonTitle:TGL(@"Common.OK", @"OK")
						 okButtonTitle:nil
					   completionBlock:nil];
			[fail show];
			return;
		}
		NSString *sentText = TGL(@"Gift.View.Resale.Success.Title", @"Gift sent");
		[TGSnackbar showInView:strongSelf.navigationController.view text:sentText seconds:2 onCommit:nil];
		[strongSelf.navigationController popViewControllerAnimated:YES];
	};
	[[TGClient shared] giftPremiumToUser:self.userId
								  months:months
								   stars:stars
								 message:self.messageText
							  completion:giftSent];
}

@end

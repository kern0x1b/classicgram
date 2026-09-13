#import "TGGroupedCaption.h"
#import "TGDirectMessagesSettingsViewController.h"
#import "TGListBackground.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGAlertView.h"
#import "TGClient+Network.h"

enum {
	TGDMSectionEnable = 0,
	TGDMSectionDetails,
	TGDMSectionCount
};

static const NSInteger kTGDMPricePromptTag = 501;
static const NSInteger kTGDMDefaultCommissionPercent = 85;

@interface TGDirectMessagesSettingsViewController ()
@property (nonatomic, assign) NSInteger commissionPercent;
@end

@implementation TGDirectMessagesSettingsViewController

- (instancetype)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self)
		_commissionPercent = kTGDMDefaultCommissionPercent;
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = self.chatTitle.length ? self.chatTitle
									   : TGL(@"Chat.Monoforum.Subtitle", @"Direct Messages");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	self.tableView.rowHeight = 44;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] optionNamed:@"paid_message_earnings_per_mille" completion:^(id value) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || ![value isKindOfClass:[NSNumber class]])
			return;
		NSInteger percent = [value integerValue] / 10;
		if (percent <= 0)
			return;
		strongSelf.commissionPercent = percent;
		[strongSelf reloadTable];
	}];
}

- (NSString *)priceFooterText {
	return [NSString stringWithFormat:
			TGL(@"ChannelMessages.PriceSectionFooterValue",
				@"You will receive %1$@% of the selected fee for each incoming message."),
			@(self.commissionPercent)];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (BOOL)hasDetailSection {
	return self.enabled;
}

- (NSString *)priceRowDetailText {
	return self.starCount > 0
		? TGLPlural(@"Privacy.Messages.Stars", self.starCount, @"%@ Star", @"%@ Stars")
		: TGL(@"Chat.PostSuggestion.PriceFree", @"Free");
}

- (void)reloadTable {
	[self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return [self hasDetailSection] ? TGDMSectionCount : TGDMSectionDetails;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == TGDMSectionEnable)
		return 1;
	if (section == TGDMSectionDetails)
		return self.topicsChatId ? 2 : 1;
	return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section == TGDMSectionDetails)
		return [self priceFooterText];
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

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == TGDMSectionEnable) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"enable"];
		if (!cell) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
										  reuseIdentifier:@"enable"];
			UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectZero];
			[toggle addTarget:self action:@selector(toggleChanged:)
				forControlEvents:UIControlEventValueChanged];
			cell.accessoryView = toggle;
		}
		[[TGTheme shared] styleCell:cell];
		cell.textLabel.text = TGL(@"DirectMessages.Accept", @"Accept Direct Messages");
		cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
		cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
		cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		[(UISwitch *)cell.accessoryView setOn:self.enabled animated:NO];
		return cell;
	}

	if (indexPath.row == 0) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"price"];
		if (!cell)
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
										  reuseIdentifier:@"price"];
		[[TGTheme shared] styleCell:cell];
		cell.textLabel.text = TGL(@"GroupInfo.Permissions.ChargeForMessages", @"Charge for Messages");
		cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
		cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
		cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
		cell.detailTextLabel.text = [self priceRowDetailText];
		cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
		cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		return cell;
	}

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"opentopics"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"opentopics"];
	[[TGTheme shared] styleCell:cell];
	cell.textLabel.text = TGL(@"DirectMessages.OpenDirectMessages", @"Open Direct Messages");
	cell.textLabel.font = TGGroupedRowTitleFont();
	cell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section != TGDMSectionDetails)
		return;
	if (indexPath.row == 0) {
		[self promptForPrice];
		return;
	}
	if (self.onOpenTopics)
		self.onOpenTopics();
}

- (void)toggleChanged:(UISwitch *)toggle {
	BOOL newEnabled = toggle.on;
	BOOL previous = self.enabled;
	self.enabled = newEnabled;
	[self reloadTable];
	if (!self.onChange)
		return;
	__weak typeof(self) weakSelf = self;
	self.onChange(newEnabled, self.starCount, ^(BOOL ok) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf || ok)
			return;
		strongSelf.enabled = previous;
		[strongSelf reloadTable];
	});
}

- (void)promptForPrice {
	UIAlertView *alert = [[TGAlertView alloc]
			initWithTitle:TGL(@"ChannelMessages.PriceSectionTitle", @"Direct Messages Price")
				  message:[self priceFooterText]
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Conversation.LinkDialogSave", @"Save"), nil];
	alert.tag = kTGDMPricePromptTag;
	if ([alert respondsToSelector:@selector(setAlertViewStyle:)]) {
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
		[alert textFieldAtIndex:0].keyboardType = UIKeyboardTypeNumberPad;
		[alert textFieldAtIndex:0].text = self.starCount > 0
			? [NSString stringWithFormat:@"%ld", (long)self.starCount]
			: @"0";
	}
	[alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (alertView.tag != kTGDMPricePromptTag)
		return;
	if (buttonIndex == alertView.cancelButtonIndex)
		return;
	NSInteger newStarCount = MAX(0, [[alertView textFieldAtIndex:0].text integerValue]);
	NSInteger previous = self.starCount;
	self.starCount = newStarCount;
	[self reloadTable];
	if (!self.onChange)
		return;
	__weak typeof(self) weakSelf = self;
	self.onChange(self.enabled, newStarCount, ^(BOOL ok) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf || ok)
			return;
		strongSelf.starCount = previous;
		[strongSelf reloadTable];
	});
}

@end

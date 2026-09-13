#import "TGTextFieldStyle.h"
#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGGroupPublicLinkViewController.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGClient+Groups.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGPopupMenu.h"
#import "TGAlertView.h"
#import "TGImageDecode.h"
#import "UIView+SafeTint.h"
#import <QuartzCore/QuartzCore.h>
#import "TGGroupMembersViewControllerInternal.h"

@implementation TGGroupPublicLinkViewController

- (id)initWithChatId:(int64_t)chatId username:(NSString *)username isChannel:(BOOL)isChannel {
	self = [super init];
	if (!self)
		return nil;
	_chatId = chatId;
	self.channel = isChannel;
	self.existingUsername = username.length ? username : nil;
	self.publicChats = [NSArray array];
	return self;
}

- (void)dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)viewDidLoad {
	[super viewDidLoad];

	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;

	self.title = TGL(@"GroupInfo.PublicLink", @"Public Link");
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];

	self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
	self.tableView.autoresizingMask =
		UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.tableView.dataSource = self;
	self.tableView.delegate = self;
	self.tableView.rowHeight = 44;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	[self.view addSubview:self.tableView];

	self.footerView = [[UIView alloc] initWithFrame:
			CGRectMake(0, 0, self.view.bounds.size.width, 44)];
	self.footerView.backgroundColor = [UIColor clearColor];
	self.footerLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 6,
			self.view.bounds.size.width - 40, 30)];
	self.footerLabel.backgroundColor = [UIColor clearColor];
	self.footerLabel.font = [UIFont systemFontOfSize:13];
	self.footerLabel.textColor = [[TGTheme shared] secondaryTextColour];
	self.footerLabel.numberOfLines = 0;
	[self.footerView addSubview:self.footerLabel];

	self.field = [[UITextField alloc] initWithFrame:CGRectMake(65, 0,
			self.view.bounds.size.width - 75, 43)];
	self.field.delegate = self;
	self.field.font = TGTextFieldFont();
	self.field.textColor = [[TGTheme shared] primaryTextColour];
	self.field.placeholder = TGL(@"Group.PublicLink.Placeholder", @"link");
	self.field.text = self.existingUsername ?: @"";
	self.field.autocapitalizationType = UITextAutocapitalizationTypeNone;
	self.field.autocorrectionType = UITextAutocorrectionTypeNo;
	self.field.clearButtonMode = UITextFieldViewModeWhileEditing;
	self.field.returnKeyType = UIReturnKeyDone;
	TGStyleTextField(self.field);
	[self.field addTarget:self action:@selector(fieldChanged)
		 forControlEvents:UIControlEventEditingChanged];

	self.navigationItem.rightBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"Conversation.LinkDialogSave", @"Save") bold:YES
									   target:self
									   action:@selector(save)];
	self.navigationItem.rightBarButtonItem.enabled = NO;

	[self rebuildSections];
	[self setFooterText:(self.channel
								? TGL(@"Channel.Username.CreatePublicLinkHelp", @"People can share this link with others and find your channel using Telegram search.")
								: TGL(@"Group.Username.CreatePublicLinkHelp", @"People can share this link with others and find your group using Telegram search."))
					 ok:NO];
	[self.field becomeFirstResponder];
}

- (void)rebuildSections {
	NSMutableArray *sections = [NSMutableArray arrayWithObject:@"link"];
	if (self.existingUsername.length)
		[sections addObject:@"remove"];
	if (self.publicChats.count)
		[sections addObject:@"chats"];
	self.sections = sections;
}

- (NSString *)kindOfSection:(NSInteger)section {
	if (section < 0 || section >= (NSInteger)self.sections.count)
		return @"";
	return [self.sections objectAtIndex:(NSUInteger)section];
}

- (CGFloat)footerHeight {
	CGFloat width = self.tableView.bounds.size.width - 40;
	if (width < 1)
		width = self.view.bounds.size.width - 40;
	CGSize size = [self.footerLabel.text sizeWithFont:self.footerLabel.font
									constrainedToSize:CGSizeMake(width, 400)
										lineBreakMode:NSLineBreakByWordWrapping];
	self.footerLabel.frame = CGRectMake(20, 6, width, size.height);
	return size.height + 16;
}

- (void)setFooterText:(NSString *)text ok:(BOOL)ok {
	self.footerLabel.text = text ?: @"";
	self.footerLabel.textColor = ok
		? [UIColor colorWithRed:0.16f green:0.55f blue:0.16f alpha:1.0f]
		: [[TGTheme shared] secondaryTextColour];
	[self footerHeight];
	[self.tableView beginUpdates];
	[self.tableView endUpdates];
}

- (NSString *)cleanedText {
	NSMutableString *clean = [NSMutableString string];
	NSString *raw = self.field.text ?: @"";
	for (NSInteger i = 0; i < raw.length; i++) {
		unichar c = [raw characterAtIndex:i];
		if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_')
			[clean appendFormat:@"%C", c];
	}
	return clean;
}

- (void)fieldChanged {
	NSString *clean = [self cleanedText];
	if (![clean isEqualToString:self.field.text ?: @""])
		self.field.text = clean;

	self.checkOk = NO;
	self.checkedUsername = nil;
	self.navigationItem.rightBarButtonItem.enabled = NO;
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(runCheck)
											   object:nil];

	if (clean.length == 0) {
		[self setFooterText:(self.channel
									? TGL(@"Channel.Username.CreatePublicLinkHelp", @"People can share this link with others and find your channel using Telegram search.")
									: TGL(@"Group.Username.CreatePublicLinkHelp", @"People can share this link with others and find your group using Telegram search."))
						 ok:NO];
		return;
	}
	if (clean.length < 5) {
		[self setFooterText:(self.channel
									? TGL(@"Channel.Username.InvalidTooShort", @"Channel names must have at least 5 characters.")
									: TGL(@"Group.Username.InvalidTooShort", @"Group names must have at least 5 characters."))
						 ok:NO];
		return;
	}
	[self setFooterText:TGL(@"CreateBot.UsernameStatus.Checking", @"Checking...") ok:NO];
	[self performSelector:@selector(runCheck) withObject:nil afterDelay:0.4f];
}

- (void)runCheck {
	NSString *name = [self cleanedText];
	if (name.length < 5)
		return;
	self.checkGeneration++;
	NSInteger generation = self.checkGeneration;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] checkGroupUsername:name
								  forChat:_chatId
							   completion:^(NSString *status) {
								   TGGroupPublicLinkViewController *strongSelf = weakSelf;
								   if (!strongSelf || strongSelf.checkGeneration != generation)
									   return;
								   NSString *value = [status isKindOfClass:NSString.class] ? status : @"error";
								   [strongSelf handleCheckStatus:value forName:name];
							   }];
}

- (void)handleCheckStatus:(NSString *)status forName:(NSString *)name {
	if ([status isEqualToString:@"ok"]) {
		self.checkOk = YES;
		self.checkedUsername = name;
		self.navigationItem.rightBarButtonItem.enabled = !self.saving;
		[self setFooterText:[NSString stringWithFormat:TGL(@"Channel.Username.UsernameIsAvailable", @"%@ is available."), name]
						 ok:YES];
		return;
	}
	if ([status isEqualToString:@"too-many"]) {
		[self setFooterText:TGL(@"Group.Username.RemoveExistingUsernamesInfo", @"Sorry, you have reserved too many public usernames. You can revoke the link from one of your older groups or channels, or create a private entity instead.")
						 ok:NO];
		[self loadCreatedPublicChats];
		return;
	}
	if ([status isEqualToString:@"unavailable"]) {
		[self setFooterText:TGL(@"Group.PublicLink.PublicGroupsUnavailable", @"You can't be a member of a public group or channel right now. This is a restriction on your account, not a problem with the name you chose.")
						 ok:NO];
		return;
	}
	NSString *text = TGL(@"Group.PublicLink.NotAvailable", @"This link is not available.");
	if ([status isEqualToString:@"occupied"])
		text = TGL(@"Channel.Username.InvalidTaken", @"Sorry, this name is already taken.");
	else if ([status isEqualToString:@"invalid"])
		text = TGL(@"Channel.Username.InvalidCharacters", @"Sorry, this name is invalid.");
	else if ([status isEqualToString:@"purchasable"])
		text = TGL(@"EditProfile.UsernameHintPurchasable", @"That username is only available for purchase.");
	else if ([status isEqualToString:@"error"])
		text = TGL(@"Group.PublicLink.CheckError", @"Could not check this link. Try again.");
	[self setFooterText:text ok:NO];
}

- (void)loadCreatedPublicChats {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] createdPublicChatsWithCompletion:^(NSArray *chats, BOOL failed) {
		TGGroupPublicLinkViewController *strongSelf = weakSelf;
		if (!strongSelf || failed)
			return;
		NSArray *list = [chats isKindOfClass:NSArray.class] ? chats : [NSArray array];
		if (list.count == 0)
			return;
		strongSelf.publicChats = list;
		[strongSelf rebuildSections];
		[strongSelf.field resignFirstResponder];
		[strongSelf.tableView reloadData];
	}];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if ([[self kindOfSection:section] isEqualToString:@"chats"])
		return (NSInteger)self.publicChats.count;
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	NSString *kind = [self kindOfSection:section];
	if ([kind isEqualToString:@"link"])
		return TGL(@"Channel.Edit.LinkItem", @"Link");
	if ([kind isEqualToString:@"chats"])
		return TGL(@"Group.PublicLink.YourPublicLinks", @"Your public links");
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

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	if ([[self kindOfSection:section] isEqualToString:@"link"])
		return [self footerHeight];
	return 10;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	if ([[self kindOfSection:section] isEqualToString:@"link"])
		return self.footerView;
	return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSString *kind = [self kindOfSection:indexPath.section];

	if ([kind isEqualToString:@"link"]) {
		static NSString *reuse = @"TGGroupLinkFieldCell";
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
		if (!cell) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
										  reuseIdentifier:reuse];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			cell.textLabel.font = TGGroupedRowTitleFont();
			cell.textLabel.textColor = [[TGTheme shared] secondaryTextColour];
		}
		cell.textLabel.text = @"t.me/";
		if (self.field.superview != cell.contentView)
			[cell.contentView addSubview:self.field];
		self.field.frame = CGRectMake(65, 0,
			cell.contentView.bounds.size.width - 75, 43);
		self.field.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		return cell;
	}

	if ([kind isEqualToString:@"remove"]) {
		static NSString *removeReuse = @"TGGroupLinkRemoveCell";
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:removeReuse];
		if (!cell) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
										  reuseIdentifier:removeReuse];
		}
		[TGIcons actionButtonInCell:cell
							  title:TGL(@"GroupInfo.RemovePublicLink", @"Remove Public Link")
							   kind:TGActionButtonKindDestructive
							 target:self
							 action:@selector(removePublicLinkPressed)];
		return cell;
	}

	static NSString *chatReuse = @"TGGroupLinkChatCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:chatReuse];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:chatReuse];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.textLabel.font = [UIFont systemFontOfSize:16];
		cell.textLabel.textColor = [[TGTheme shared] primaryTextColour];
	}
	NSDictionary *chat = nil;
	if (indexPath.row >= 0 && indexPath.row < (NSInteger)self.publicChats.count) {
		id entry = [self.publicChats objectAtIndex:(NSUInteger)indexPath.row];
		chat = [entry isKindOfClass:NSDictionary.class] ? entry : nil;
	}
	cell.textLabel.text = chat ? TGMembersString(chat, @"title") : @"";
	return cell;
}

- (void)removePublicLinkPressed {
	[self.field resignFirstResponder];
	__weak typeof(self) weakSelf = self;
	TGAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:nil
						 message:TGL(@"GroupInfo.RemovePublicLinkConfirmation", @"Remove the public link? The group becomes private and the old link stops working.")
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
				   okButtonTitle:TGL(@"Appearance.RemoveTheme", @"Remove")
				 completionBlock:^(bool okPressed) {
					 TGGroupPublicLinkViewController *strongSelf = weakSelf;
					 if (!strongSelf)
						 return;
					 if (okPressed)
						 [strongSelf applyUsername:@""];
				 }];
	[alert show];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([[self kindOfSection:indexPath.section] isEqualToString:@"remove"])
		return TGActionRowHeight();
	return 44;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSString *kind = [self kindOfSection:indexPath.section];

	if ([kind isEqualToString:@"chats"])
		[self confirmRevokeUsernameForOtherChatAtRow:indexPath.row];
}

- (void)confirmRevokeUsernameForOtherChatAtRow:(NSInteger)row {
	if (row < 0 || row >= (NSInteger)self.publicChats.count)
		return;
	id entry = [self.publicChats objectAtIndex:(NSUInteger)row];
	NSDictionary *chat = [entry isKindOfClass:NSDictionary.class] ? entry : nil;
	int64_t otherChatId = [chat[@"id"] longLongValue];
	if (!otherChatId)
		return;
	NSString *title = TGMembersString(chat, @"title");

	[self.field resignFirstResponder];
	__weak typeof(self) weakSelf = self;
	TGAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:nil
						 message:[NSString stringWithFormat:
							TGL(@"Group.PublicLink.RevokeOtherLinkConfirmation", @"Revoke the public link from %@?"),
							title.length ? title : @""]
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
				   okButtonTitle:TGL(@"Appearance.RemoveTheme", @"Remove")
				 completionBlock:^(bool okPressed) {
					 TGGroupPublicLinkViewController *strongSelf = weakSelf;
					 if (!strongSelf || !okPressed)
						 return;
					 [strongSelf revokeUsernameForOtherChat:otherChatId atRow:row];
				 }];
	[alert show];
}

- (void)revokeUsernameForOtherChat:(int64_t)otherChatId atRow:(NSInteger)row {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setGroupChat:otherChatId username:@"" completion:^(BOOL ok) {
		TGGroupPublicLinkViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[[[UIAlertView alloc] initWithTitle:nil
										message:TGL(@"Login.UnknownError", @"An error occurred, please try again later.")
									   delegate:nil
							  cancelButtonTitle:TGL(@"Common.OK", @"OK")
							  otherButtonTitles:nil] show];
			return;
		}
		NSMutableArray *chats = [strongSelf.publicChats mutableCopy];
		if (row >= 0 && row < (NSInteger)chats.count)
			[chats removeObjectAtIndex:(NSUInteger)row];
		strongSelf.publicChats = chats;
		[strongSelf rebuildSections];
		[strongSelf.tableView reloadData];
		if ([strongSelf cleanedText].length >= 5) {
			[strongSelf setFooterText:TGL(@"CreateBot.UsernameStatus.Checking", @"Checking...") ok:NO];
			[strongSelf runCheck];
		}
	}];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
	return NO;
}

- (void)save {
	if (self.saving || !self.checkOk || !self.checkedUsername.length)
		return;
	[self applyUsername:self.checkedUsername];
}

- (void)applyUsername:(NSString *)username {
	if (self.saving)
		return;
	self.saving = YES;
	self.navigationItem.rightBarButtonItem.enabled = NO;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setGroupChat:_chatId username:username completion:^(BOOL ok) {
		TGGroupPublicLinkViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.saving = NO;
		strongSelf.navigationItem.rightBarButtonItem.enabled = strongSelf.checkOk;
		if (!ok) {
			[[[UIAlertView alloc] initWithTitle:nil
										message:TGL(@"Login.UnknownError", @"An error occurred, please try again later.")
									   delegate:nil
							  cancelButtonTitle:TGL(@"Common.OK", @"OK")
							  otherButtonTitles:nil] show];
			return;
		}
		if (strongSelf.onChanged)
			strongSelf.onChanged();
		[strongSelf.navigationController popViewControllerAnimated:YES];
	}];
}

@end

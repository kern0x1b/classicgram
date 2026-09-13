#import "TGTextFieldStyle.h"
#import "TGListBackground.h"
#import "TGProxyViewController.h"
#import "TGFriendlyError.h"
#import "TGLocalization.h"
#import "TGClient+Network.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "TGQRViewController.h"
#import "TGProxyLinkInText.h"

static NSString *TGProxyTypeTitle(NSString *type) {
	if ([type isEqualToString:@"mtproto"])
		return TGL(@"SocksProxySetup.ProxyTelegram", @"MTProto");
	if ([type isEqualToString:@"http"])
		return TGL(@"SocksProxySetup.ProxyHTTP", @"HTTP");
	return TGL(@"ChatSettings.ConnectionType.UseSocks5", @"SOCKS5");
}

static NSString *TGProxyPasteboardLink(void) {
	UIPasteboard *board = [UIPasteboard generalPasteboard];
	NSString *link = TGProxyLinkInText(board.string);
	if (link)
		return link;
	for (NSURL *url in board.URLs) {
		if (![url isKindOfClass:[NSURL class]])
			continue;
		link = TGProxyLinkInText([url absoluteString]);
		if (link)
			return link;
	}
	return nil;
}

static NSString *TGProxyServerLine(NSDictionary *proxy) {
	NSString *server = [proxy[@"server"] isKindOfClass:[NSString class]]
		? proxy[@"server"]
		: @"";
	NSInteger port = [proxy[@"port"] integerValue];
	if (!server.length)
		return TGL(@"SocksProxySetup.UnnamedProxy", @"proxy");
	if (port <= 0)
		return server;
	return [NSString stringWithFormat:@"%@:%d", server, (int)port];
}

#pragma mark - the add / edit form

@interface TGProxyEditViewController : UITableViewController <UITextFieldDelegate>
@property (nonatomic, strong) NSDictionary *existing;
@property (nonatomic, copy) void (^onSaved)(void);
@property (nonatomic, strong) NSString *type;
@property (nonatomic, strong) UITextField *serverField;
@property (nonatomic, strong) UITextField *portField;
@property (nonatomic, strong) UITextField *secretField;
@property (nonatomic, strong) UITextField *usernameField;
@property (nonatomic, strong) UITextField *passwordField;
@property (nonatomic, assign) BOOL saving;
@property (nonatomic, strong) NSString *pasteboardLink;
@property (nonatomic, strong) NSString *initialLink;
@property (nonatomic, assign) BOOL parsingLink;
@end

static UIView *TGProxyCheckAccessory(void) {
	UIImage *art = [UIImage imageNamed:@"ListCheck.png"];
	if (!art)
		return nil;
	UIImageView *view = [[UIImageView alloc] initWithImage:art
										  highlightedImage:
											  [UIImage imageNamed:@"ListCheck_Highlighted.png"]];
	view.frame = CGRectMake(0, 0, art.size.width, art.size.height);
	return view;
}

@implementation TGProxyEditViewController

- (instancetype)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self)
		self.type = @"mtproto";
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = self.existing ? TGL(@"SocksProxySetup.AddProxyTitle", @"Edit Proxy") : TGL(@"SocksProxySetup.AddProxy", @"Add Proxy");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];

	UIButton *done = [TGIcons headerButtonWithTitle:TGL(@"Common.Done", @"Done") bold:YES
											 target:self
											 action:@selector(save)];
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:done];

	self.serverField = [self fieldWithPlaceholder:TGL(@"SocksProxySetup.Hostname", @"Server") text:self.existing[@"server"]];
	self.serverField.keyboardType = UIKeyboardTypeURL;
	self.serverField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	self.serverField.autocorrectionType = UITextAutocorrectionTypeNo;

	NSString *port = nil;
	if ([self.existing[@"port"] respondsToSelector:@selector(integerValue)] && [self.existing[@"port"] integerValue] > 0)
		port = [NSString stringWithFormat:@"%d", (int)[self.existing[@"port"] integerValue]];
	self.portField = [self fieldWithPlaceholder:TGL(@"SocksProxySetup.Port", @"Port") text:port];
	self.portField.keyboardType = UIKeyboardTypeNumberPad;

	self.secretField = [self fieldWithPlaceholder:TGL(@"SocksProxySetup.Secret", @"Secret") text:self.existing[@"secret"]];
	self.secretField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	self.secretField.autocorrectionType = UITextAutocorrectionTypeNo;

	self.usernameField = [self fieldWithPlaceholder:TGL(@"SocksProxySetup.UsernamePlaceholder", @"Username")
											   text:self.existing[@"username"]];
	self.usernameField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	self.usernameField.autocorrectionType = UITextAutocorrectionTypeNo;

	self.passwordField = [self fieldWithPlaceholder:TGL(@"SocksProxySetup.PasswordPlaceholder", @"Password")
											   text:self.existing[@"password"]];
	self.passwordField.secureTextEntry = YES;

	NSString *existingType = self.existing[@"type"];
	if ([existingType isKindOfClass:[NSString class]] && existingType.length)
		self.type = existingType;

	if (self.initialLink.length)
		[self applyLink:self.initialLink announce:NO];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	if (!self.existing) {
		NSString *link = TGProxyPasteboardLink();
		if (![link isEqualToString:self.pasteboardLink]) {
			self.pasteboardLink = link;
			[self.tableView reloadData];
		}
	}
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	if (!self.existing && !self.serverField.text.length)
		[self.serverField becomeFirstResponder];
}

- (BOOL)showsPasteRow {
	return !self.existing && self.pasteboardLink.length > 0;
}

- (void)applyLink:(NSString *)link announce:(BOOL)announce {
	if (!link.length || self.parsingLink)
		return;
	self.parsingLink = YES;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] proxyFromLink:link completion:^(NSDictionary *proxy) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.parsingLink = NO;
		if (![proxy isKindOfClass:[NSDictionary class]] || !proxy.count)
			return;
		[strongSelf fillFromProxy:proxy];
	}];
}

- (void)fillFromProxy:(NSDictionary *)proxy {
	[self.view endEditing:YES];

	NSString *type = proxy[@"type"];
	if ([type isKindOfClass:[NSString class]] && type.length)
		self.type = type;

	NSString *server = [proxy[@"server"] isKindOfClass:[NSString class]]
		? proxy[@"server"]
		: @"";
	self.serverField.text = server;

	NSInteger port = [proxy[@"port"] respondsToSelector:@selector(integerValue)]
		? [proxy[@"port"] integerValue]
		: 0;
	self.portField.text = port > 0
		? [NSString stringWithFormat:@"%d", (int)port]
		: @"";

	self.secretField.text = [proxy[@"secret"] isKindOfClass:[NSString class]]
		? proxy[@"secret"]
		: @"";
	self.usernameField.text = [proxy[@"username"] isKindOfClass:[NSString class]]
		? proxy[@"username"]
		: @"";
	self.passwordField.text = [proxy[@"password"] isKindOfClass:[NSString class]]
		? proxy[@"password"]
		: @"";

	self.pasteboardLink = nil;
	[self.tableView reloadData];
}

- (void)pasteLink {
	NSString *link = self.pasteboardLink ?: TGProxyPasteboardLink();
	if (!link.length)
		return;
	[self applyLink:link announce:YES];
}

- (UITextField *)fieldWithPlaceholder:(NSString *)placeholder text:(id)text {
	UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(15, 12, 290, 22)];
	field.placeholder = placeholder;
	field.text = [text isKindOfClass:[NSString class]] ? text : @"";
	field.font = TGTextFieldFont();
	field.backgroundColor = [UIColor clearColor];
	field.clearButtonMode = UITextFieldViewModeWhileEditing;
	field.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	field.textColor = [[TGTheme shared] primaryTextColour];
	field.returnKeyType = UIReturnKeyDone;
	field.delegate = self;
	TGStyleTextField(field);
	return field;
}

- (BOOL)textFieldShouldReturn:(UITextField *)field {
	[field resignFirstResponder];
	return NO;
}

- (BOOL)isMtproto {
	return [self.type isEqualToString:@"mtproto"];
}

- (NSArray *)fields {
	NSMutableArray *fields = [NSMutableArray array];
	[fields addObject:self.serverField];
	[fields addObject:self.portField];
	if ([self isMtproto]) {
		[fields addObject:self.secretField];
	} else {
		[fields addObject:self.usernameField];
		[fields addObject:self.passwordField];
	}
	return fields;
}

- (NSString *)headerTitleForSection:(NSInteger)section {
	if (section == 0)
		return TGL(@"SocksProxySetup.ProxyType", @"TYPE");
	if (section == 1)
		return TGL(@"SocksProxySetup.Connection", @"CONNECTION");
	return nil;
}

- (NSString *)footerTitleForSection:(NSInteger)section {
	if (section == 2)
		return TGL(@"SocksProxySetup.PasteLinkFooter", @"A copied tg://proxy or t.me/proxy link fills this form in for you.");
	if (section != 1)
		return nil;
	if ([self isMtproto])
		return TGL(@"SocksProxySetup.MTProtoFormFooter",
			@"An MTProto proxy needs the secret handed out with it. "
			@"Paste the server, port and secret exactly as you received them.");
	return TGL(@"SocksProxySetup.Socks5FormFooter", @"Leave the username and password empty if the SOCKS5 proxy does not ask for them.");
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	NSString *title = [self headerTitleForSection:section];
	if (!title)
		return 12;
	return [[TGTheme shared] groupedHeaderHeightForTitle:title];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	TGTheme *theme = [TGTheme shared];
	return [theme groupedHeaderViewWithTitle:[self headerTitleForSection:section]
									   width:tableView.bounds.size.width];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *title = [self footerTitleForSection:section];
	if (!title)
		return 1;
	TGTheme *theme = [TGTheme shared];
	return [theme groupedCommentHeightForText:title
										width:tableView.bounds.size.width];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	TGTheme *theme = [TGTheme shared];
	return [theme groupedCommentViewWithText:[self footerTitleForSection:section]
									   width:tableView.bounds.size.width];
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return [self showsPasteRow] ? 3 : 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return 2;
	if (section == 2)
		return 1;
	return (NSInteger)[self fields].count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 44;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 0) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"type"];
		if (!cell)
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
										  reuseIdentifier:@"type"];
		[[TGTheme shared] styleCell:cell];
		cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
		cell.textLabel.text = indexPath.row == 0 ? TGL(@"SocksProxySetup.ProxyTelegram", @"MTProto") : TGL(@"ChatSettings.ConnectionType.UseSocks5", @"SOCKS5");
		BOOL chosen = (indexPath.row == 0) == [self isMtproto];
		cell.textLabel.textColor = chosen ? [[TGTheme shared] groupedInfoColour]
										  : [[TGTheme shared] groupedTitleColour];
		UIView *check = chosen ? TGProxyCheckAccessory() : nil;
		if (chosen && !check)
			cell.accessoryType = UITableViewCellAccessoryCheckmark;
		else
			cell.accessoryType = UITableViewCellAccessoryNone;
		cell.accessoryView = check;
		return cell;
	}

	if (indexPath.section == 2) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"paste"];
		if (!cell)
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
										  reuseIdentifier:@"paste"];
		[[TGTheme shared] styleCell:cell];
		cell.accessoryType = UITableViewCellAccessoryNone;
		cell.accessoryView = nil;
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
		cell.textLabel.textColor = [[TGTheme shared] groupedActionColour];
		cell.textLabel.text = TGL(@"SocksProxySetup.PasteFromClipboard", @"Paste Proxy Link");
		return cell;
	}

	UITableViewCell *bareCell = [UITableViewCell alloc];
	UITableViewCell *cell = [bareCell initWithStyle:UITableViewCellStyleDefault
									reuseIdentifier:nil];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	UITextField *field = [self fields][indexPath.row];
	field.frame = CGRectMake(15, 11, tableView.bounds.size.width - 50, 22);
	[cell.contentView addSubview:field];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section == 2) {
		[self pasteLink];
		return;
	}
	if (indexPath.section != 0)
		return;
	NSString *picked = indexPath.row == 0 ? @"mtproto" : @"socks5";
	if ([picked isEqualToString:self.type])
		return;
	[self.view endEditing:YES];
	self.type = picked;
	[tableView reloadData];
}

#pragma mark - saving

- (NSString *)trimmed:(UITextField *)field {
	return [field.text stringByTrimmingCharactersInSet:
				   [NSCharacterSet whitespaceAndNewlineCharacterSet]]
		?: @"";
}

- (void)complain:(NSString *)message field:(UITextField *)field {
	UIAlertView *alert = [UIAlertView alloc];
	alert = [alert initWithTitle:TGL(@"SocksProxySetup.Title", @"Proxy") message:message
						delegate:nil
			   cancelButtonTitle:TGL(@"Common.OK", @"OK")
			   otherButtonTitles:nil];
	[alert show];
	[field becomeFirstResponder];
}

- (NSDictionary *)proxyFromForm {
	NSString *server = [self trimmed:self.serverField];
	if (!server.length) {
		[self complain:TGL(@"SocksProxySetup.ErrorNoServer", @"Please enter the proxy server.") field:self.serverField];
		return nil;
	}
	NSInteger port = [[self trimmed:self.portField] integerValue];
	if (port <= 0 || port > 65535) {
		[self complain:TGL(@"SocksProxySetup.ErrorInvalidPort", @"Please enter a port between 1 and 65535.") field:self.portField];
		return nil;
	}

	NSMutableDictionary *proxy = [NSMutableDictionary dictionary];
	proxy[@"server"] = server;
	proxy[@"port"] = [NSNumber numberWithInteger:port];
	proxy[@"type"] = self.type;

	if ([self isMtproto]) {
		NSString *secret = [self trimmed:self.secretField];
		if (!secret.length) {
			[self complain:TGL(@"SocksProxySetup.ErrorNoSecret", @"An MTProto proxy needs a secret.") field:self.secretField];
			return nil;
		}
		proxy[@"secret"] = secret;
	} else {
		NSString *username = [self trimmed:self.usernameField];
		NSString *password = self.passwordField.text ?: @"";
		if (username.length)
			proxy[@"username"] = username;
		if (password.length)
			proxy[@"password"] = password;
	}
	return proxy;
}

- (void)save {
	if (self.saving)
		return;
	[self.view endEditing:YES];

	NSDictionary *proxy = [self proxyFromForm];
	if (!proxy)
		return;

	self.saving = YES;
	self.navigationItem.rightBarButtonItem.customView.userInteractionEnabled = NO;
	[self storeProxy:proxy];
}

- (void)storeProxy:(NSDictionary *)proxy {
	__weak typeof(self) weakSelf = self;
	void (^done)(NSDictionary *, NSString *) = ^(NSDictionary *stored, NSString *errorMessage) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.saving = NO;
		strongSelf.navigationItem.rightBarButtonItem.customView.userInteractionEnabled = YES;
		if (!stored) {
			UIAlertView *alert = [UIAlertView alloc];
			alert = [alert initWithTitle:TGL(@"SocksProxySetup.Title", @"Proxy")
								  message:TGFriendlyErrorText(errorMessage,
											  TGL(@"Login.UnknownError",
												  @"An error occurred, please try again later."))
								 delegate:nil
						cancelButtonTitle:TGL(@"Common.OK", @"OK")
						otherButtonTitles:nil];
			[alert show];
			return;
		}
		if (strongSelf.onSaved)
			strongSelf.onSaved();
		[strongSelf.navigationController popViewControllerAnimated:YES];
	};

	NSInteger existingId = [self.existing[@"id"] integerValue];
	if (self.existing && existingId > 0) {
		[[TGClient shared] activeProxyIdWithCompletion:^(NSInteger activeId) {
			[[TGClient shared] editProxy:existingId to:proxy enable:activeId == existingId completion:done];
		}];
	} else {
		[[TGClient shared] proxiesWithCompletion:^(NSArray *proxies) {
			[[TGClient shared] addProxy:proxy enable:proxies.count == 0 completion:done];
		}];
	}
}

@end

#pragma mark - the list

@interface TGProxyViewController ()
@property (nonatomic, strong) NSArray *proxies;
@property (nonatomic, strong) NSMutableDictionary *pings;
@property (nonatomic, strong) NSNumber *directPing;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL pinging;
@property (nonatomic, strong) NSTimer *statusTimer;
@property (nonatomic, strong) TGActionSheet *currentActionSheet;
@property (nonatomic, assign) NSInteger pendingProxyId;
@property (nonatomic, assign) BOOL broadcasting;
@property (nonatomic, strong) NSString *pasteboardLink;
@property (nonatomic, strong) id connectionStateObserverToken;
@property (nonatomic, strong) id proxyListChangedObserverToken;
@end

@implementation TGProxyViewController

- (instancetype)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		self.proxies = [NSArray array];
		self.pings = [NSMutableDictionary dictionary];
		self.pendingProxyId = 0;
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"SocksProxySetup.Title", @"Proxy");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];

	UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(handleHold:)];
	hold.minimumPressDuration = 0.5;
	[self.tableView addGestureRecognizer:hold];

	[self reload];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	self.pasteboardLink = TGProxyPasteboardLink();
	[self.tableView reloadData];

	if (!self.broadcasting) {
		self.broadcasting = YES;
		NSNotificationCenter *centre = [NSNotificationCenter defaultCenter];
		__weak typeof(self) weakSelf = self;
		self.connectionStateObserverToken = [centre
			addObserverForName:TGConnectionStateDidChangeNotification
						object:nil
						 queue:nil
					usingBlock:^(NSNotification *note) {
						__strong typeof(weakSelf) strongSelf = weakSelf;
						if (!strongSelf)
							return;
						[strongSelf refreshStatus];
					}];
		self.proxyListChangedObserverToken = [centre
			addObserverForName:TGProxyListDidChangeNotification
						object:nil
						 queue:nil
					usingBlock:^(NSNotification *note) {
						__strong typeof(weakSelf) strongSelf = weakSelf;
						if (!strongSelf)
							return;
						[strongSelf proxyListChanged];
					}];
		[[TGClient shared] beginBroadcastingConnectionState];
	}
	[self refreshStatus];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self.statusTimer invalidate];
	self.statusTimer = nil;
	if (self.broadcasting) {
		self.broadcasting = NO;
		if (self.connectionStateObserverToken) {
			[[NSNotificationCenter defaultCenter] removeObserver:self.connectionStateObserverToken];
			self.connectionStateObserverToken = nil;
		}
		if (self.proxyListChangedObserverToken) {
			[[NSNotificationCenter defaultCenter] removeObserver:self.proxyListChangedObserverToken];
			self.proxyListChangedObserverToken = nil;
		}
		[[TGClient shared] endBroadcastingConnectionState];
	}
	if (self.currentActionSheet) {
		TGActionSheet *sheet = self.currentActionSheet;
		[sheet dismissWithClickedButtonIndex:sheet.cancelButtonIndex animated:NO];
		self.currentActionSheet = nil;
	}
}

- (void)dealloc {
	[_statusTimer invalidate];
	if (_broadcasting) {
		[[NSNotificationCenter defaultCenter] removeObserver:self];
		if (_connectionStateObserverToken)
			[[NSNotificationCenter defaultCenter] removeObserver:_connectionStateObserverToken];
		if (_proxyListChangedObserverToken)
			[[NSNotificationCenter defaultCenter] removeObserver:_proxyListChangedObserverToken];
		[[TGClient shared] endBroadcastingConnectionState];
	}
}

- (void)proxyListChanged {
	if (self.isViewLoaded && self.view.window)
		[self reload];
}

#pragma mark - data

- (void)reload {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] proxiesWithCompletion:^(NSArray *proxies) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.loaded = YES;
		strongSelf.proxies = proxies ?: [NSArray array];
		[strongSelf.tableView reloadData];
		[strongSelf measurePings];
	}];
}

- (void)measurePings {
	if (self.pinging)
		return;
	self.pinging = YES;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] pingProxy:nil completion:^(double seconds) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.directPing = [NSNumber numberWithDouble:seconds];
		[strongSelf.tableView reloadData];
	}];

	if (!self.proxies.count) {
		self.pinging = NO;
		return;
	}

	[[TGClient shared] pingAllProxiesWithCompletion:^(NSDictionary *secondsByProxyId) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.pinging = NO;
		if ([secondsByProxyId isKindOfClass:[NSDictionary class]])
			[strongSelf.pings addEntriesFromDictionary:secondsByProxyId];
		[strongSelf.tableView reloadData];
	}];
}

- (NSDictionary *)enabledProxy {
	for (NSDictionary *proxy in self.proxies)
		if ([proxy[@"isEnabled"] boolValue])
			return proxy;
	return nil;
}

- (NSDictionary *)proxyAtRow:(NSInteger)row {
	NSInteger index = row - 1;
	if (index < 0 || index >= (NSInteger)self.proxies.count)
		return nil;
	return self.proxies[index];
}

- (NSString *)pingTextForProxy:(NSDictionary *)proxy {
	id key = proxy[@"id"];
	NSNumber *seconds = proxy ? (key ? self.pings[key] : nil) : self.directPing;
	if (![seconds isKindOfClass:[NSNumber class]])
		seconds = nil;
	if (!seconds)
		return self.pinging ? TGL(@"SocksProxySetup.ProxyStatusChecking", @"checking...") : nil;
	double value = [seconds doubleValue];
	if (value < 0)
		return TGL(@"SocksProxySetup.ProxyStatusUnavailable", @"unavailable");
	return [NSString stringWithFormat:TGL(@"SocksProxySetup.ProxyStatusPing", @"%@ ms ping"),
		@((int)(value * 1000.0 + 0.5))];
}

- (NSString *)statusText {
	NSString *title = [[TGClient shared] connectionStateTitle];
	if (title.length)
		return title;
	return TGL(@"SocksProxySetup.ProxyStatusConnected", @"Connected");
}

- (NSString *)statusDetail {
	NSDictionary *enabled = [self enabledProxy];
	if (!enabled)
		return TGL(@"SocksProxySetup.DirectConnection", @"Direct");
	return [NSString stringWithFormat:@"%@ - %@",
		TGProxyTypeTitle(enabled[@"type"]), TGProxyServerLine(enabled)];
}

- (void)refreshStatus {
	if (!self.isViewLoaded || !self.view.window)
		return;
	NSIndexPath *path = [NSIndexPath indexPathForRow:0 inSection:0];
	UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:path];
	if (!cell)
		return;
	cell.textLabel.text = [self statusText];
	cell.detailTextLabel.text = [self statusDetail];
	[cell setNeedsLayout];
}

- (NSString *)headerTitleForSection:(NSInteger)section {
	if (section == 0)
		return TGL(@"SocksProxySetup.Connection", @"CONNECTION");
	if (section == 1)
		return TGL(@"SocksProxySetup.SavedProxies", @"SAVED PROXIES");
	return nil;
}

- (NSString *)footerTitleForSection:(NSInteger)section {
	if (section != 1)
		return nil;
	if (!self.loaded)
		return TGL(@"Channel.NotificationLoading", @"Loading…");
	if (!self.proxies.count)
		return TGL(@"SocksProxySetup.NoProxiesFooter",
			@"You have no proxies set up. Add one to reach Telegram from a "
			@"network that blocks it.");
	return TGL(@"SocksProxySetup.ProxiesListFooter",
		@"Tap a proxy to connect through it. Touch and hold one to edit, share "
		@"or delete it.");
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	NSString *title = [self headerTitleForSection:section];
	if (!title)
		return 12;
	return [[TGTheme shared] groupedHeaderHeightForTitle:title];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	TGTheme *theme = [TGTheme shared];
	return [theme groupedHeaderViewWithTitle:[self headerTitleForSection:section]
									   width:tableView.bounds.size.width];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *title = [self footerTitleForSection:section];
	if (!title)
		return 1;
	TGTheme *theme = [TGTheme shared];
	return [theme groupedCommentHeightForText:title
										width:tableView.bounds.size.width];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	TGTheme *theme = [TGTheme shared];
	return [theme groupedCommentViewWithText:[self footerTitleForSection:section]
									   width:tableView.bounds.size.width];
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return 1;
	if (section == 1)
		return 1 + (NSInteger)self.proxies.count;
	return (NSInteger)[self actionTitles].count;
}

- (NSArray *)actionTitles {
	NSMutableArray *titles = [NSMutableArray array];
	[titles addObject:TGL(@"SocksProxySetup.AddProxy", @"Add Proxy")];
	[titles addObject:TGL(@"SocksProxySetup.ScanProxyQRCode", @"Scan Proxy QR Code")];
	if (self.pasteboardLink.length)
		[titles addObject:TGL(@"SocksProxySetup.AddProxyFromLink", @"Add Proxy from Link")];
	return titles;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return indexPath.section == 1 && indexPath.row > 0 ? 52 : 44;
}

- (void)mark:(BOOL)checked on:(UITableViewCell *)cell {
	cell.textLabel.textColor = checked ? [[TGTheme shared] groupedInfoColour]
									   : [[TGTheme shared] groupedTitleColour];
	UIView *check = checked ? TGProxyCheckAccessory() : nil;
	if (checked && !check) {
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
		cell.accessoryView = nil;
		return;
	}
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.accessoryView = check;
}

- (UITableViewCell *)statusCellForTable:(UITableView *)tableView {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"status"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:@"status"];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.accessoryView = nil;
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	cell.textLabel.text = [self statusText];
	cell.detailTextLabel.text = [self statusDetail];
	return cell;
}

- (UITableViewCell *)actionCellForTable:(UITableView *)tableView title:(NSString *)title {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"action"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"action"];
	[[TGTheme shared] styleCell:cell];
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.accessoryView = nil;
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textColor = [[TGTheme shared] groupedActionColour];
	cell.textLabel.text = title;
	return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 0)
		return [self statusCellForTable:tableView];

	if (indexPath.section == 2) {
		NSArray *titles = [self actionTitles];
		NSString *title = indexPath.row < (NSInteger)titles.count
			? titles[indexPath.row]
			: @"";
		return [self actionCellForTable:tableView title:title];
	}

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"proxy"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:@"proxy"];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
	cell.detailTextLabel.textColor = [[TGTheme shared] groupedDisabledColour];

	NSDictionary *proxy = [self proxyAtRow:indexPath.row];
	if (!proxy) {
		cell.textLabel.text = TGL(@"SocksProxySetup.TypeNone", @"Without Proxy");
		cell.detailTextLabel.text = [self pingTextForProxy:nil];
		[self mark:[self enabledProxy] == nil on:cell];
		return cell;
	}

	cell.textLabel.text = TGProxyServerLine(proxy);
	NSString *ping = [self pingTextForProxy:proxy];
	cell.detailTextLabel.text = ping.length
		? [NSString stringWithFormat:@"%@ - %@", TGProxyTypeTitle(proxy[@"type"]), ping]
		: TGProxyTypeTitle(proxy[@"type"]);
	[self mark:[proxy[@"isEnabled"] boolValue] on:cell];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (indexPath.section == 2) {
		if (indexPath.row == 0)
			[self presentFormForProxy:nil];
		else if (indexPath.row == 1)
			[self scanProxyCode];
		else if (indexPath.row == 2 && self.pasteboardLink.length)
			[self addFromPasteboardLink];
		return;
	}
	if (indexPath.section != 1)
		return;

	NSDictionary *proxy = [self proxyAtRow:indexPath.row];
	if (!proxy) {
		[self disable];
		return;
	}
	[self enableProxy:proxy];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return indexPath.section == 1 && [self proxyAtRow:indexPath.row] != nil;
}

- (NSString *)tableView:(UITableView *)tableView
	titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
	return TGL(@"Common.Delete", @"Delete");
}

- (void)tableView:(UITableView *)tableView
	commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
	 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete)
		return;
	[self deleteProxy:[self proxyAtRow:indexPath.row]];
}

#pragma mark - actions

- (void)enableProxy:(NSDictionary *)proxy {
	NSInteger proxyId = [proxy[@"id"] integerValue];
	if (proxyId <= 0)
		return;

	NSMutableArray *updated = [NSMutableArray array];
	for (NSDictionary *candidate in self.proxies) {
		NSMutableDictionary *copy = [NSMutableDictionary dictionaryWithDictionary:candidate];
		copy[@"isEnabled"] = [NSNumber numberWithBool:
				[candidate[@"id"] integerValue] == proxyId];
		[updated addObject:copy];
	}
	self.proxies = updated;
	[self.tableView reloadData];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] enableProxy:proxyId completion:^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf reload];
	}];
}

- (void)disable {
	NSMutableArray *updated = [NSMutableArray array];
	for (NSDictionary *candidate in self.proxies) {
		NSMutableDictionary *copy = [NSMutableDictionary dictionaryWithDictionary:candidate];
		copy[@"isEnabled"] = [NSNumber numberWithBool:NO];
		[updated addObject:copy];
	}
	self.proxies = updated;
	[self.tableView reloadData];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] disableProxyWithCompletion:^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		[strongSelf reload];
	}];
}

- (void)deleteProxy:(NSDictionary *)proxy {
	NSInteger proxyId = [proxy[@"id"] integerValue];
	if (proxyId <= 0)
		return;

	NSMutableArray *remaining = [NSMutableArray arrayWithArray:self.proxies];
	[remaining removeObject:proxy];
	self.proxies = remaining;
	if (proxy[@"id"])
		[self.pings removeObjectForKey:proxy[@"id"]];
	[self.tableView reloadData];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] removeProxy:proxyId completion:^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		[strongSelf reload];
	}];
}

- (void)shareLinkForProxy:(NSDictionary *)proxy {
	[[TGClient shared] proxyLinkFor:proxy completion:^(NSString *link) {
		if (!link.length)
			return;
		[UIPasteboard generalPasteboard].string = link;
		UIAlertView *alert = [UIAlertView alloc];
		alert = [alert initWithTitle:TGL(@"Story.ToastLinkCopied", @"Link Copied")
							 message:link
							delegate:nil
				   cancelButtonTitle:TGL(@"Common.OK", @"OK")
				   otherButtonTitles:nil];
		[alert show];
	}];
}

- (BOOL)looksLikeProxyLink:(NSString *)payload {
	NSString *text = [payload stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!text.length)
		return NO;
	if ([text rangeOfString:@"tg://proxy"].location == 0)
		return YES;
	if ([text rangeOfString:@"tg://socks"].location == 0)
		return YES;
	if ([text rangeOfString:@"t.me/proxy"].location != NSNotFound)
		return YES;
	return [text rangeOfString:@"t.me/socks"].location != NSNotFound;
}

- (void)openProxyFormForScannedLink:(NSString *)link scanner:(TGQRViewController *)scanner {
	__weak typeof(self) weakSelf = self;
	__weak TGQRViewController *weakScanner = scanner;
	[[TGClient shared] proxyFromLink:link completion:^(NSDictionary *proxy) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (![proxy isKindOfClass:[NSDictionary class]] || !proxy.count) {
			[weakScanner resumeScanning];
			return;
		}
		[strongSelf.navigationController popToViewController:strongSelf animated:NO];
		[strongSelf presentFormForProxy:nil withLink:link];
	}];
}

- (void)scanProxyCode {
	TGQRViewController *scanner = [[TGQRViewController alloc] init];
	__weak typeof(self) weakSelf = self;
	__weak TGQRViewController *weakScanner = scanner;
	scanner.onCode = ^BOOL(NSString *payload) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf || ![strongSelf looksLikeProxyLink:payload])
			return NO;
		[strongSelf openProxyFormForScannedLink:payload scanner:weakScanner];
		return YES;
	};
	[self.navigationController pushViewController:scanner animated:YES];
}

- (void)addFromPasteboardLink {
	NSString *link = TGProxyPasteboardLink();
	if (!link.length) {
		self.pasteboardLink = nil;
		[self.tableView reloadData];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] proxyFromLink:link completion:^(NSDictionary *proxy) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (![proxy isKindOfClass:[NSDictionary class]] || !proxy.count) {
			strongSelf.pasteboardLink = nil;
			[strongSelf.tableView reloadData];
			return;
		}
		[strongSelf presentFormForProxy:nil withLink:link];
	}];
}

- (void)presentFormForProxy:(NSDictionary *)proxy {
	[self presentFormForProxy:proxy withLink:nil];
}

- (void)presentFormForProxy:(NSDictionary *)proxy withLink:(NSString *)link {
	TGProxyEditViewController *form = [[TGProxyEditViewController alloc] init];
	form.existing = proxy;
	form.initialLink = link;
	__weak typeof(self) weakSelf = self;
	form.onSaved = ^{
		__strong typeof(weakSelf) strongSelf = weakSelf;
		[strongSelf reload];
	};
	[self.navigationController pushViewController:form animated:YES];
}

+ (void)presentFormForProxyLink:(NSString *)link inNavigationController:(UINavigationController *)navigationController {
	TGProxyEditViewController *form = [[TGProxyEditViewController alloc] init];
	form.initialLink = link;
	[navigationController pushViewController:form animated:YES];
}

#pragma mark - the per-proxy sheet

- (UIView *)sheetHostView {
	return self.navigationController.view ?: self.view;
}

- (void)handleHold:(UILongPressGestureRecognizer *)recogniser {
	if (recogniser.state != UIGestureRecognizerStateBegan)
		return;
	CGPoint point = [recogniser locationInView:self.tableView];
	NSIndexPath *path = [self.tableView indexPathForRowAtPoint:point];
	if (!path || path.section != 1)
		return;
	NSDictionary *proxy = [self proxyAtRow:path.row];
	if (proxy)
		[self showSheetForProxy:proxy atIndexPath:path];
}

- (void)showSheetForProxy:(NSDictionary *)proxy atIndexPath:(NSIndexPath *)indexPath {
	self.pendingProxyId = [proxy[@"id"] integerValue];

	NSMutableArray *actions = [NSMutableArray array];
	if (![proxy[@"isEnabled"] boolValue]) {
		TGActionSheetAction *useAction = [TGActionSheetAction alloc];
		[actions addObject:[useAction initWithTitle:TGL(@"SocksProxySetup.UseProxy", @"Use This Proxy")
											 action:@"use"]];
	}
	[actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGL(@"Common.Edit", @"Edit") action:@"edit"]];
	TGActionSheetAction *linkAction = [TGActionSheetAction alloc];
	[actions addObject:[linkAction initWithTitle:TGL(@"GroupInfo.InviteLink.CopyLink", @"Copy Link")
										  action:@"link"]];
	TGActionSheetAction *delAction = [TGActionSheetAction alloc];
	[actions addObject:[delAction initWithTitle:TGL(@"Common.Delete", @"Delete")
										 action:@"delete"
										   type:TGActionSheetActionTypeDestructive]];
	TGActionSheetAction *cancelAction = [TGActionSheetAction alloc];
	[actions addObject:[cancelAction initWithTitle:TGL(@"Common.Cancel", @"Cancel")
											action:@"cancel"
											  type:TGActionSheetActionTypeCancel]];

	__weak typeof(self) weakSelf = self;
	TGActionSheet *sheet = [TGActionSheet alloc];
	self.currentActionSheet = [sheet initWithTitle:TGProxyServerLine(proxy)
										   actions:actions
									   actionBlock:^(__unused id target, NSString *action) {
										   __strong typeof(weakSelf) strongSelf = weakSelf;
										   if (!strongSelf)
											   return;
										   strongSelf.currentActionSheet = nil;
										   NSDictionary *current = [strongSelf proxyWithId:strongSelf.pendingProxyId];
										   strongSelf.pendingProxyId = 0;
										   if (!current)
											   return;
										   if ([action isEqualToString:@"use"])
											   [strongSelf enableProxy:current];
										   else if ([action isEqualToString:@"edit"])
											   [strongSelf presentFormForProxy:current];
										   else if ([action isEqualToString:@"link"])
											   [strongSelf shareLinkForProxy:current];
										   else if ([action isEqualToString:@"delete"])
											   [strongSelf deleteProxy:current];
									   }
											target:self];
	UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
	[self.currentActionSheet tg_showFromRect:cell.frame inView:self.tableView];
}

- (NSDictionary *)proxyWithId:(NSInteger)proxyId {
	if (proxyId <= 0)
		return nil;
	for (NSDictionary *proxy in self.proxies)
		if ([proxy[@"id"] integerValue] == proxyId)
			return proxy;
	return nil;
}

@end

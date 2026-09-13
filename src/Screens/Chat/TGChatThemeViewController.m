#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGChatThemeViewController.h"
#import "TGLocalization.h"
#import "TGClient.h"
#import "TGClient+AppSettings.h"
#import "TGTheme.h"

static void TGCTComplain(NSString *message) {
	UIAlertView *alertAlloc = [UIAlertView alloc];
	UIAlertView *alert = [alertAlloc initWithTitle:nil
										   message:message
										  delegate:nil
								 cancelButtonTitle:TGL(@"Common.OK", @"OK")
								 otherButtonTitles:nil];
	[alert show];
}

@interface TGChatThemeViewController ()
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, copy) NSString *peerTitle;
@property (nonatomic, strong) NSArray *themes;
@property (nonatomic, strong) NSString *currentThemeName;
@property (nonatomic, assign) BOOL currentLoaded;
@property (nonatomic, strong) id catalogChangedObserverToken;
@end

@implementation TGChatThemeViewController

- (instancetype)initWithChatId:(int64_t)chatId title:(NSString *)title {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		_chatId = chatId;
		_peerTitle = [title copy];
	}
	return self;
}

- (void)buildTitleView {
	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 36)];

	UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(0, self.peerTitle.length ? 1 : 8, 200, 20)];
	name.text = TGL(@"Conversation.Theme.Title", @"Select Theme");
	name.font = [UIFont boldSystemFontOfSize:16];
	name.textColor = [[TGTheme shared] barTitleColour];
	name.backgroundColor = [UIColor clearColor];
	name.textAlignment = NSTextAlignmentCenter;
	[header addSubview:name];

	if (self.peerTitle.length) {
		UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 21, 200, 14)];
		subtitle.font = [UIFont boldSystemFontOfSize:12];
		subtitle.textColor = [UIColor colorWithRed:0xe0 / 255.0f green:0xee / 255.0f
											  blue:0xfd / 255.0f
											 alpha:1.0f];
		subtitle.backgroundColor = [UIColor clearColor];
		subtitle.textAlignment = NSTextAlignmentCenter;
		subtitle.adjustsFontSizeToFitWidth = YES;
		subtitle.minimumScaleFactor = 0.7f;
		subtitle.text = [NSString stringWithFormat:TGL(@"Conversation.Theme.Subtitle", @"Theme will be also applied for %@"), self.peerTitle];
		[header addSubview:subtitle];
	}

	self.navigationItem.titleView = header;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.rowHeight = 44;
	[self buildTitleView];
	self.themes = @[];
	__weak typeof(self) weakSelf = self;
	self.catalogChangedObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:TGChatAppearanceCatalogDidChangeNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf catalogChanged];
				}];
	[self reload];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (self.catalogChangedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.catalogChangedObserverToken];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)catalogChanged {
	self.themes = [[TGClient shared] emojiChatThemeRows];
	[self.tableView reloadData];
}

- (void)reload {
	self.themes = [[TGClient shared] emojiChatThemeRows];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] chatThemeEmojiForChat:self.chatId completion:^(NSString *emoji) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.currentThemeName = emoji;
		strongSelf.currentLoaded = YES;
		[strongSelf.tableView reloadData];
	}];
	[self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 1 + (NSInteger)self.themes.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	return TGL(@"Conversation.Theme.Footer",
		@"A chat theme also changes the wallpaper and colours for this one chat on every "
		@"device where you use Telegram. It does not change the appearance of this app.");
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *text = [self tableView:tableView titleForFooterInSection:section];
	TGTheme *theme = [TGTheme shared];
	return [theme groupedCommentHeightForText:text width:tableView.bounds.size.width];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *text = [self tableView:tableView titleForFooterInSection:section];
	TGTheme *theme = [TGTheme shared];
	return [theme groupedCommentViewWithText:text width:tableView.bounds.size.width];
}

- (void)mark:(BOOL)checked on:(UITableViewCell *)cell {
	cell.accessoryType = checked ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"theme"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"theme"];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleDefault;

	if (indexPath.row == 0) {
		cell.textLabel.text = TGL(@"Conversation.Theme.NoTheme", @"No Theme");
		cell.textLabel.font = TGGroupedRowTitleFont();
		[self mark:self.currentLoaded && !self.currentThemeName.length on:cell];
		return cell;
	}

	NSDictionary *theme = self.themes[indexPath.row - 1];
	NSString *name = theme[@"name"];
	cell.textLabel.text = name;
	cell.textLabel.font = [UIFont systemFontOfSize:24];
	[self mark:self.currentLoaded && [self.currentThemeName isEqualToString:name] on:cell];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (!self.currentLoaded)
		return;

	NSString *name = indexPath.row == 0 ? @"" : self.themes[indexPath.row - 1][@"name"];
	if ([name isEqualToString:self.currentThemeName ?: @""])
		return;

	NSString *previous = self.currentThemeName;
	self.currentThemeName = name;
	[self.tableView reloadData];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setChatThemeName:name forChat:self.chatId completion:^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (ok || !strongSelf)
			return;
		strongSelf.currentThemeName = previous;
		[strongSelf.tableView reloadData];
		TGCTComplain(TGL(@"Conversation.Theme.CouldNotBeSet", @"That theme could not be set."));
	}];
}

@end

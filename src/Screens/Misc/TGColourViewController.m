#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGColourViewController.h"
#import "TGLocalization.h"
#import "TGSettingsService.h"
#import "TGTheme.h"

static void TGColourComplain(NSString *message) {
	UIAlertView *alert =
		[[UIAlertView alloc] initWithTitle:nil
								   message:message
								  delegate:nil
						 cancelButtonTitle:TGL(@"Common.OK", @"OK")
						 otherButtonTitles:nil];
	[alert show];
}

static NSString *TGColourName(NSInteger colorId) {
	if (colorId < 0)
		colorId = 0;
	switch (colorId) {
		case 0: return TGL(@"Misc.ColourNameRed", @"Red");
		case 1: return TGL(@"Misc.ColourNameOrange", @"Orange");
		case 2: return TGL(@"Misc.ColourNameViolet", @"Violet");
		case 3: return TGL(@"Misc.ColourNameGreen", @"Green");
		case 4: return TGL(@"Misc.ColourNameCyan", @"Cyan");
		case 5: return TGL(@"Misc.ColourNameBlue", @"Blue");
		case 6: return TGL(@"Misc.ColourNamePink", @"Pink");
		default: return [NSString stringWithFormat:TGL(@"Misc.ColourNumbered", @"Colour %ld"), (long)(colorId + 1)];
	}
}

static UIImage *TGColourSwatch(UIColor *colour) {
	CGRect rect = CGRectMake(0, 0, 28, 28);
	UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0.0f);
	UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:rect];
	[colour setFill];
	[path fill];
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

@interface TGColourViewController ()
@property (nonatomic, assign) NSInteger accentColorId;
@property (nonatomic, assign) NSInteger profileColorId;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL settingBusy;
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, strong) id catalogChangedObserverToken;
@end

@implementation TGColourViewController

- (instancetype)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	return self;
}

- (instancetype)initForChat:(int64_t)chatId {
	self = [self init];
	if (self)
		_chatId = chatId;
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = self.chatId ? TGL(@"NameColor.Title.Channel", @"Your Channel Color")
							  : TGL(@"NameColor.Title.Account", @"Your Name Color");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.rowHeight = 44;
	self.accentColorId = -1;
	self.profileColorId = -1;
	[self reload];
	__weak typeof(self) weakSelf = self;
	self.catalogChangedObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:[TGSettingsService accentColorCatalogDidChangeNotificationName]
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf catalogChanged:note];
				}];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (self.catalogChangedObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.catalogChangedObserverToken];
}

- (void)catalogChanged:(NSNotification *)note {
	[self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)reload {
	__weak typeof(self) weakSelf = self;
	void (^apply)(NSDictionary *) = ^(NSDictionary *colors) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.loaded = YES;
		if ([colors isKindOfClass:[NSDictionary class]]) {
			strongSelf.accentColorId = [colors[@"colorId"] integerValue];
			strongSelf.profileColorId = [colors[@"profileColorId"] integerValue];
		}
		[strongSelf.tableView reloadData];
	};
	if (self.chatId)
		[TGSettingsService accentColorsForChat:self.chatId completion:apply];
	else
		[TGSettingsService myAccentColorsWithCompletion:apply];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return section == 0 ? (NSInteger)[TGSettingsService pickableAccentColorIds].count
						: (NSInteger)[TGSettingsService pickableProfileAccentColorIds].count + 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return section == 0 ? TGL(@"Misc.NameColourSectionTitle", @"Name Colour")
						 : TGL(@"Misc.ProfileColourSectionTitle", @"Profile Colour");
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
	if (section != 1)
		return nil;
	if (self.chatId)
		return TGL(@"Misc.ChatColourFooterBoosts",
			@"The colour behind the chat's name and on its profile page. Changing it needs enough boosts.");
	return TGL(@"Misc.MyColourFooterPremium",
		@"The colour behind your name and on your profile page. Telegram Premium is required to change it.");
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

- (void)mark:(BOOL)checked on:(UITableViewCell *)cell {
	cell.textLabel.textColor = checked ? [[TGTheme shared] groupedInfoColour]
									   : [[TGTheme shared] groupedTitleColour];
	cell.accessoryType = checked ? UITableViewCellAccessoryCheckmark
								 : UITableViewCellAccessoryNone;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"colour"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"colour"];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleDefault;

	if (indexPath.section == 1 && indexPath.row == 0) {
		cell.textLabel.text = TGL(@"Stickers.SuggestNone", @"None");
		cell.imageView.image = nil;
		[self mark:self.profileColorId < 0 on:cell];
		return cell;
	}

	NSArray *ids = indexPath.section == 0 ? [TGSettingsService pickableAccentColorIds]
										  : [TGSettingsService pickableProfileAccentColorIds];
	NSInteger row = indexPath.section == 1 ? indexPath.row - 1 : indexPath.row;
	NSInteger colorId = row >= 0 && row < (NSInteger)ids.count
		? [ids[row] integerValue]
		: row;
	cell.textLabel.text = TGColourName(colorId);
	UIColor *swatch;
	if (indexPath.section == 0) {
		NSInteger rgb = [[TGSettingsService rgbForAccentColorId:colorId] integerValue];
		swatch = [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0f
								 green:((rgb >> 8) & 0xFF) / 255.0f
								  blue:(rgb & 0xFF) / 255.0f
								 alpha:1.0f];
	} else {
		NSArray *gradient = [TGSettingsService profileGradientForColorId:colorId];
		NSInteger rgb = [gradient.firstObject integerValue];
		swatch = [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0f
								 green:((rgb >> 8) & 0xFF) / 255.0f
								  blue:(rgb & 0xFF) / 255.0f
								 alpha:1.0f];
	}
	cell.imageView.image = TGColourSwatch(swatch);

	BOOL checked = indexPath.section == 0 ? colorId == self.accentColorId
										  : colorId == self.profileColorId;
	[self mark:checked on:cell];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (!self.loaded || self.settingBusy)
		return;

	if (indexPath.section == 0) {
		NSArray *ids = [TGSettingsService pickableAccentColorIds];
		NSInteger colorId = indexPath.row < (NSInteger)ids.count
			? [ids[indexPath.row] integerValue]
			: indexPath.row;
		NSInteger previous = self.accentColorId;
		self.accentColorId = colorId;
		self.settingBusy = YES;
		[self.tableView reloadData];
		__weak typeof(self) weakSelf = self;
		void (^done)(BOOL) = ^(BOOL ok) {
			__strong typeof(weakSelf) strongSelf = weakSelf;
			if (!strongSelf)
				return;
			strongSelf.settingBusy = NO;
			if (ok)
				return;
			strongSelf.accentColorId = previous;
			[strongSelf.tableView reloadData];
			TGColourComplain(strongSelf.chatId
				? TGL(@"Misc.NameColourRejectedBoosts",
					@"Telegram would not take that colour. Changing the name colour needs enough boosts.")
				: TGL(@"Misc.NameColourRejectedPremium",
					@"Telegram would not take that colour. Changing the name colour needs Telegram Premium."));
		};
		if (self.chatId)
			[TGSettingsService setChatAccentColorId:colorId backgroundCustomEmojiId:0
											forChat:self.chatId
										 completion:done];
		else
			[TGSettingsService setMyAccentColorId:colorId backgroundCustomEmojiId:0
									   completion:done];
		return;
	}

	NSArray *profileIds = [TGSettingsService pickableProfileAccentColorIds];
	NSInteger profileRow = indexPath.row - 1;
	NSInteger colorId = profileRow >= 0 && profileRow < (NSInteger)profileIds.count
		? [profileIds[profileRow] integerValue]
		: profileRow;

	if (!self.chatId && colorId >= 0 && ![TGSettingsService isPremiumAccount]) {
		TGColourComplain(TGL(@"Misc.ProfileColourRejectedPremium",
			@"Telegram would not take that colour. Changing the profile colour needs Telegram Premium."));
		return;
	}

	NSInteger previous = self.profileColorId;
	self.profileColorId = colorId;
	self.settingBusy = YES;
	[self.tableView reloadData];
	__weak typeof(self) weakSelf = self;
	void (^done)(BOOL) = ^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.settingBusy = NO;
		if (ok)
			return;
		strongSelf.profileColorId = previous;
		[strongSelf.tableView reloadData];
		TGColourComplain(strongSelf.chatId
			? TGL(@"Misc.ProfileColourRejectedBoosts",
				@"Telegram would not take that colour. Changing the profile colour needs enough boosts.")
			: TGL(@"Misc.ProfileColourRejectedPremium",
				@"Telegram would not take that colour. Changing the profile colour needs Telegram Premium."));
	};
	if (self.chatId)
		[TGSettingsService setChatProfileAccentColorId:colorId backgroundCustomEmojiId:0
											   forChat:self.chatId
											completion:done];
	else
		[TGSettingsService setMyProfileAccentColorId:colorId backgroundCustomEmojiId:0
										  completion:done];
}

@end

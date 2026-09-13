#import "TGListBackground.h"
#import "TGProfilePermissionsController.h"
#import "TGProfileViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGPopupMenu.h"
#import "TGActionSheet.h"
#import "TGForwardPicker.h"
#import "UIView+SafeTint.h"
#import "TGImageDecode.h"
#import "TGClient+ChatManagement.h"
#import "TGLazyFramework.h"
#import <AVFoundation/AVFoundation.h>
#import <AddressBook/AddressBook.h>
#import <ImageIO/ImageIO.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>
#import "TGEmoji.h"
#import "TGDateLabel.h"
#import "TGDateUtils.h"
#import "TGAlertView.h"
#import "TGSnackbar.h"

@interface TGProfilePermissionsController ()
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL saving;
@property (nonatomic, strong) UIButton *doneButton;
@end

@implementation TGProfilePermissionsController

+ (NSString *)titleForKey:(NSString *)key {
	static NSDictionary *titles = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		titles = @{@"sendMessages" : TGL(@"Channel.AdminLog.BanSendMessages", @"Send Messages"),
			@"sendAudios" : TGL(@"Channel.BanUser.PermissionSendMusic", @"Send Music"),
			@"sendDocuments" : TGL(@"Channel.BanUser.PermissionSendFile", @"Send Files"),
			@"sendPhotos" : TGL(@"Channel.BanUser.PermissionSendPhoto", @"Send Photos"),
			@"sendVideos" : TGL(@"Channel.BanUser.PermissionSendVideo", @"Send Videos"),
			@"sendVideoNotes" : TGL(@"Channel.BanUser.PermissionSendVideoMessage", @"Send Video Messages"),
			@"sendVoiceNotes" : TGL(@"Channel.BanUser.PermissionSendVoiceMessage", @"Send Audio Messages"),
			@"sendPolls" : TGL(@"Channel.BanUser.PermissionSendPolls", @"Send Polls"),
			@"sendOther" : TGL(@"Channel.AdminLog.BanSendStickersAndGifs", @"Send Stickers & GIFs"),
			@"addLinkPreviews" : TGL(@"Channel.AdminLog.BanEmbedLinks", @"Embed Links"),
			@"reactToMessages" : TGL(@"Channel.BanUser.PermissionSendReactions", @"Send Reactions"),
			@"editTag" : TGL(@"GroupPermission.EditTag", @"Change Own Tag"),
			@"changeInfo" : TGL(@"Group.EditAdmin.PermissionChangeInfo", @"Change Group Info"),
			@"inviteUsers" : TGL(@"Channel.AdminLog.CanInviteUsers", @"Add Users"),
			@"pinMessages" : TGL(@"Channel.EditAdmin.PermissionPinMessages", @"Pin Messages"),
			@"createTopics" : TGL(@"Channel.EditAdmin.PermissionCreateTopics", @"Create Topics")};
	});
	return titles[key] ?: key;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"GroupInfo.Permissions", @"Permissions");
	self.permissions = [NSMutableDictionary dictionary];
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];

	UIButton *done = [TGIcons headerButtonWithTitle:TGL(@"Common.Done", @"Done") bold:YES
											 target:self
											 action:@selector(saveTapped)];
	done.enabled = NO;
	self.doneButton = done;
	if (done)
		self.navigationItem.rightBarButtonItem =
			[[UIBarButtonItem alloc] initWithCustomView:done];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] permissionsForChat:self.chatId
							   completion:^(NSDictionary *permissions, BOOL failed) {
								   TGProfilePermissionsController *strongSelf = weakSelf;
								   if (!strongSelf)
									   return;
								   if (failed) {
									   [TGSnackbar showInView:strongSelf.navigationController.view
														 text:TGL(@"Toast.CouldNotLoadPermissions", @"Could not read the permissions of this group")
													  seconds:2
													 onCommit:nil];
									   return;
								   }
								   if ([permissions isKindOfClass:[NSDictionary class]])
									   strongSelf.permissions = [permissions mutableCopy];
								   strongSelf.loaded = YES;
								   strongSelf.doneButton.enabled = YES;
								   [strongSelf.tableView reloadData];
							   }];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)saveTapped {
	if (!self.loaded || self.saving)
		return;
	self.saving = YES;
	self.doneButton.enabled = NO;
	NSMutableDictionary *full = [NSMutableDictionary dictionary];
	for (NSString *key in [TGClient permissionKeys])
		full[key] = @([self.permissions[key] boolValue]);
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] setPermissions:full forChat:self.chatId completion:^(BOOL ok) {
		TGProfilePermissionsController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			strongSelf.saving = NO;
			strongSelf.doneButton.enabled = YES;
			[TGSnackbar showInView:strongSelf.navigationController.view
							   text:TGL(@"Toast.CouldNotSavePermissions", @"Could not save permissions")
							seconds:2
						   onCommit:nil];
			return;
		}
		[strongSelf.navigationController popViewControllerAnimated:YES];
	}];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [[TGClient permissionKeys] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return TGL(@"GroupInfo.Permissions.SectionTitle", @"WHAT CAN MEMBERS OF THIS GROUP DO?");
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return [[TGTheme shared] groupedHeaderHeightForTitle:
			[self tableView:tableView titleForHeaderInSection:section]];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"permission"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"permission"];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];

	NSArray *keys = [TGClient permissionKeys];
	NSString *key = indexPath.row < (NSInteger)keys.count ? keys[indexPath.row] : @"";
	cell.textLabel.text = [TGProfilePermissionsController titleForKey:key];

	UISwitch *toggle = [[UISwitch alloc] init];
	toggle.on = [self.permissions[key] boolValue];
	toggle.tag = indexPath.row;
	[toggle addTarget:self action:@selector(permissionToggled:)
		forControlEvents:UIControlEventValueChanged];
	cell.accessoryView = toggle;
	return cell;
}

- (void)permissionToggled:(UISwitch *)toggle {
	NSArray *keys = [TGClient permissionKeys];
	if (toggle.tag >= (NSInteger)keys.count)
		return;
	self.permissions[keys[toggle.tag]] = @(toggle.on);
}

@end

#import "TGListBackground.h"
#import "TGChatIdPickerViewController.h"
#import "TGLocalization.h"
#import "TGClient.h"
#import "TGClient+ChatList.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGChatListHelpers.h"
#import "TGSimpleAvatarCache.h"

@implementation TGChatIdPickerViewController {
	NSMutableSet *_selected;
	TGSimpleAvatarCache *_avatarCache;
	UIButton *_confirmButton;
	BOOL _confirmed;
}

- (id)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	_selected = [NSMutableSet setWithArray:(self.chatIds ?: @[])];
	_avatarCache = [[TGSimpleAvatarCache alloc] initWithAvatarSide:40];
	_avatarCache.tableView = self.tableView;

	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];

	_confirmButton = [TGIcons headerButtonWithTitle:(self.confirmTitle.length ? self.confirmTitle : TGL(@"Contacts.AddContact", @"Add"))
												bold:YES
											  target:self
											  action:@selector(confirmTapped)];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_confirmButton];

	if (!self.titles.count && self.chatIds.count) {
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] titlesForChatIds:self.chatIds completion:^(NSDictionary *reply) {
			TGChatIdPickerViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			strongSelf.titles = TGReplyDictionary(reply) ?: @{};
			[strongSelf.tableView reloadData];
		}];
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return self.prompt.length ? self.prompt : nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderHeightForTitle:title];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.chatIds.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *reuse = @"TGChatIdPickerCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:reuse];

	NSNumber *key = self.chatIds[indexPath.row];
	NSString *title = TGReplyString(self.titles[key]);
	if (!title.length)
		title = [[TGClient shared] cachedTitleForChatId:[key longLongValue]];
	NSString *shownTitle = title.length ? title : TGL(@"ChatList.UnnamedChat", @"Chat");
	cell.textLabel.text = shownTitle;
	cell.textLabel.textColor = [[TGTheme shared] primaryTextColour];
	cell.imageView.image = [_avatarCache avatarForChatId:[key longLongValue] title:shownTitle];
	cell.accessoryType = [_selected containsObject:key]
		? UITableViewCellAccessoryCheckmark
		: UITableViewCellAccessoryNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSNumber *key = self.chatIds[indexPath.row];
	if ([_selected containsObject:key])
		[_selected removeObject:key];
	else
		[_selected addObject:key];
	[tableView reloadRowsAtIndexPaths:@[ indexPath ]
					 withRowAnimation:UITableViewRowAnimationNone];
}

- (void)confirmTapped {
	if (_confirmed)
		return;
	_confirmed = YES;
	_confirmButton.enabled = NO;

	NSMutableArray *picked = [NSMutableArray array];
	for (NSNumber *key in (self.chatIds ?: @[]))
		if ([_selected containsObject:key])
			[picked addObject:key];
	void (^confirm)(NSArray *) = self.onConfirm;
	[self.navigationController popViewControllerAnimated:YES];
	if (confirm)
		confirm(picked);
}

@end

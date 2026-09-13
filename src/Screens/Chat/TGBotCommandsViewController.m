#import "TGListBackground.h"
#import "TGBotCommandsViewController.h"
#import "TGLocalization.h"
#import "TGTheme.h"

@implementation TGBotCommandsViewController {
	BOOL _picked;
}

- (id)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"Chat.Commands", @"Commands");
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.commands.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *reuse = @"TGBotCommandCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:reuse];
	[[TGTheme shared] styleCell:cell];

	NSDictionary *entry = self.commands[indexPath.row];
	cell.textLabel.text = [NSString stringWithFormat:@"/%@", entry[@"command"] ?: @""];
	cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	NSString *description = entry[@"description"];
	cell.detailTextLabel.text = description.length ? description : nil;
	cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	cell.accessoryType = UITableViewCellAccessoryNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (_picked)
		return;
	if ((NSUInteger)indexPath.row >= self.commands.count)
		return;
	NSString *command = self.commands[indexPath.row][@"command"];
	if (!command.length || !self.onPick)
		return;
	_picked = YES;
	void (^pick)(NSString *) = self.onPick;
	[self.navigationController popViewControllerAnimated:YES];
	pick(command);
}

@end

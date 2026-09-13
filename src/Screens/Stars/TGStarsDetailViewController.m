#import "TGListBackground.h"
#import "TGStarsDetailViewController.h"
#import "TGStarsViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGHexColour.h"

@implementation TGStarsDetailViewController

- (id)initWithTitle:(NSString *)title
			  pairs:(NSArray *)pairs
			comment:(NSString *)comment {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		self.title = title;
		self.pairs = pairs;
		self.comment = comment;
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	if (self.navigationController.navigationBar)
		[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if (self.busy) {
		self.busy = NO;
		[self.tableView reloadData];
	}
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return self.actions.count ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return (NSInteger)self.pairs.count;
	return (NSInteger)self.actions.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 44;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return 8;
}

- (NSString *)commentForSection:(NSInteger)section {
	if (section == 0)
		return self.comment;
	return self.actionsComment;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *comment = [self commentForSection:section];
	if (!comment.length)
		return (section == 0 && self.actions.count) ? 1 : 8;
	return TGStarsCommentHeight(comment, self.tableView.bounds.size.width ?: [UIScreen mainScreen].bounds.size.width);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	return TGStarsCommentViewWithText([self commentForSection:section],
		self.tableView.bounds.size.width ?: [UIScreen mainScreen].bounds.size.width);
}

- (UITableViewCell *)actionCellInTable:(UITableView *)tableView row:(NSInteger)row {
	static NSString *reuseId = @"TGStarsDetailAction";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseId];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:reuseId];
	NSDictionary *action = self.actions[row];
	cell.textLabel.text = action[@"title"];
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textAlignment = NSTextAlignmentLeft;
	cell.detailTextLabel.text = action[@"value"];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	cell.accessoryType = UITableViewCellAccessoryNone;
	[[TGTheme shared] styleCell:cell];
	if (self.busy) {
		cell.textLabel.textColor = [[TGTheme shared] secondaryTextColour];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	} else {
		cell.textLabel.textColor = [action[@"destructive"] boolValue]
			? [[TGTheme shared] groupedDestructiveColour]
			: [[TGTheme shared] groupedActionColour];
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	}
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section != 1 || self.busy)
		return;
	if (indexPath.row >= (NSInteger)self.actions.count)
		return;
	void (^block)(void) = self.actions[indexPath.row][@"block"];
	if (block)
		block();
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 1)
		return [self actionCellInTable:tableView row:indexPath.row];

	static NSString *reuseId = @"TGStarsDetailPair";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseId];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:reuseId];
	NSArray *pair = self.pairs[indexPath.row];
	cell.textLabel.text = pair[0];
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.detailTextLabel.text = pair[1];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.accessoryType = UITableViewCellAccessoryNone;
	[[TGTheme shared] styleCell:cell];
	return cell;
}

@end

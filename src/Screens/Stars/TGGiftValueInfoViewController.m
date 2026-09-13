#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGGiftValueInfoViewController.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGWebViewController.h"

NSString *const TGGiftValueInfoFragmentRowKind = @"fragment";

@interface TGGiftValueInfoViewController ()
@property (nonatomic, copy) NSArray *rows;
@property (nonatomic, copy) NSString *fragmentUrl;
@end

@implementation TGGiftValueInfoViewController

- (instancetype)initWithRows:(NSArray *)rows fragmentUrl:(NSString *)fragmentUrl {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self) {
		_rows = [rows copy];
		_fragmentUrl = [fragmentUrl copy];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"Gift.View.Value", @"Value");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.rowHeight = 44;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.rows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	return TGL(@"Stars.UpgradedGiftInfoFooter",
		@"Values are estimates based on recent sales and are not an offer to buy or sell.");
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
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:@"row"];
	[[TGTheme shared] styleCell:cell];

	NSArray *pair = (NSUInteger)indexPath.row < self.rows.count ? self.rows[(NSUInteger)indexPath.row] : nil;
	BOOL isLink = self.fragmentUrl.length && pair.count > 2 && [pair[2] isEqualToString:TGGiftValueInfoFragmentRowKind];

	cell.textLabel.text = pair.firstObject ?: @"";
	cell.detailTextLabel.text = pair.count > 1 ? pair[1] : @"";
	cell.textLabel.textColor = isLink ? [[TGTheme shared] accentColour]
									  : [[TGTheme shared] groupedTitleColour];
	cell.detailTextLabel.textColor = [[TGTheme shared] groupedInfoColour];
	cell.selectionStyle = isLink ? UITableViewCellSelectionStyleDefault
								 : UITableViewCellSelectionStyleNone;
	cell.accessoryType = UITableViewCellAccessoryNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSArray *pair = (NSUInteger)indexPath.row < self.rows.count ? self.rows[(NSUInteger)indexPath.row] : nil;
	if (!self.fragmentUrl.length || pair.count <= 2 || ![pair[2] isEqualToString:TGGiftValueInfoFragmentRowKind])
		return;
	[TGWebViewController openURLString:self.fragmentUrl fromViewController:self];
}

@end

#import "TGTimeZonePickerViewController.h"
#import "TGLocalization.h"
#import "TGTheme.h"

static NSString *TGTimeZoneOffsetText(NSTimeZone *zone) {
	NSInteger seconds = zone.secondsFromGMT;
	NSInteger hours = seconds / 3600;
	NSInteger minutes = labs(seconds % 3600) / 60;
	return minutes == 0
		? [NSString stringWithFormat:@"UTC%+ld", (long)hours]
		: [NSString stringWithFormat:@"UTC%+ld:%02ld", (long)hours, (long)minutes];
}

@interface TGTimeZonePickerViewController ()
@property (nonatomic, strong) NSArray *timeZoneIds;
@end

@implementation TGTimeZonePickerViewController {
	BOOL _picked;
}

- (instancetype)init {
	self = [super initWithStyle:UITableViewStylePlain];
	if (self) {
		_timeZoneIds = [[NSTimeZone knownTimeZoneNames] sortedArrayUsingSelector:@selector(compare:)];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"TimeZoneSelection.Title", @"Time Zone");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tableView.rowHeight = 44;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	NSInteger index = [self.timeZoneIds indexOfObject:self.selectedTimeZoneId ?: @""];
	if (index != NSNotFound)
		[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:(NSInteger)index inSection:0]
							   atScrollPosition:UITableViewScrollPositionMiddle
									   animated:NO];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.timeZoneIds.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"timeZone"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"timeZone"];
	[[TGTheme shared] styleCell:cell];

	NSString *identifier = self.timeZoneIds[(NSUInteger)indexPath.row];
	NSTimeZone *zone = [NSTimeZone timeZoneWithName:identifier];
	cell.textLabel.text = identifier;
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];
	cell.detailTextLabel.text = zone ? TGTimeZoneOffsetText(zone) : @"";
	cell.accessoryType = [identifier isEqualToString:self.selectedTimeZoneId]
		? UITableViewCellAccessoryCheckmark
		: UITableViewCellAccessoryNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (_picked)
		return;
	if ((NSUInteger)indexPath.row >= self.timeZoneIds.count)
		return;
	_picked = YES;
	NSString *identifier = self.timeZoneIds[(NSUInteger)indexPath.row];
	void (^picked)(NSString *) = self.onPicked;
	[self.navigationController popViewControllerAnimated:YES];
	if (picked)
		picked(identifier);
}

@end

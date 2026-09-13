#import "TGListBackground.h"
#import "TGDeviceViewController.h"
#import "TGLocalization.h"
#import "TGDevice.h"
#import "TGCapabilities.h"
#import "TGTheme.h"

@interface TGDeviceViewController ()
@property (nonatomic, strong) NSArray *capabilities;
@property (nonatomic, strong) NSIndexPath *copiedIndexPath;
@end

@implementation TGDeviceViewController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"AuthSessions.View.Device", @"Device");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	self.tableView.rowHeight = 44;
	self.capabilities = [TGCapabilities all] ?: @[];
}

- (NSString *)freeSpaceText {
	NSString *path = NSHomeDirectory();
	if (!path)
		return @"?";
	NSError *error = nil;
	NSDictionary *attributes = [[NSFileManager defaultManager]
		attributesOfFileSystemForPath:path
								error:&error];
	NSNumber *free = attributes[NSFileSystemFreeSize];
	if (!free)
		return @"?";
	double megabytes = [free doubleValue] / (1024.0 * 1024.0);
	if (megabytes >= 1024.0)
		return [NSString stringWithFormat:@"%.1f GB", megabytes / 1024.0];
	return [NSString stringWithFormat:@"%.0f MB", megabytes];
}

- (NSString *)screenText {
	CGRect bounds = [UIScreen mainScreen].bounds;
	CGFloat scale = 1;
	if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)])
		scale = [UIScreen mainScreen].scale;
	return [NSString stringWithFormat:@"%.0f x %.0f @%.0fx",
		bounds.size.width * scale, bounds.size.height * scale, scale];
}

- (NSString *)titleForHardwareRow:(NSInteger)row {
	switch (row) {
		case 0:
			return TGL(@"Device.Model", @"Model");
		case 1:
			return TGL(@"Device.Identifier", @"Identifier");
		case 2:
			return TGL(@"Device.ChipAndMemory", @"Chip and memory");
		case 3:
			return TGL(@"Device.Screen", @"Screen");
		case 4:
			return TGL(@"AuthSessions.View.OS", @"Operating System");
		case 5:
			return TGL(@"Device.FreeSpace", @"Free space");
		default:
			return TGL(@"Device.Tier", @"Tier");
	}
}

- (NSString *)valueForHardwareRow:(NSInteger)row {
	switch (row) {
		case 0:
			return [TGDevice modelName] ?: TGL(@"Device.UnknownModel", @"Unknown");
		case 1:
			return [TGDevice machine] ?: @"?";
		case 2:
			return [NSString stringWithFormat:@"%@, %lu MB",
				[TGDevice chip] ?: @"?", (unsigned long)[TGDevice memoryMB]];
		case 3:
			return [self screenText];
		case 4:
			return [UIDevice currentDevice].systemVersion ?: @"?";
		case 5:
			return [self freeSpaceText];
		default:
			return [TGDevice tierName] ?: @"?";
	}
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	self.capabilities = [TGCapabilities all] ?: @[];
	self.copiedIndexPath = nil;
	[self.tableView reloadData];
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 2;
}

- (NSString *)headerTitleForSection:(NSInteger)section {
	return section == 0 ? TGL(@"Device.Hardware", @"Hardware") : TGL(@"Device.Features", @"Features");
}

- (NSString *)footerTextForSection:(NSInteger)section {
	if (section == 0)
		return TGL(@"Device.HardwareFooter",
			@"Vintage: iPhone 3GS and 4, iPod touch 4. Legacy: iPhone 4S, 5 and 5c, "
			@"iPad 2 and later armv7 iPads, iPod touch 5. Modern: iPhone 5s and 6. "
			@"Full: 6s and later. Tap a row to copy it.");
	if (self.capabilities.count == 0)
		return TGL(@"Device.NoFeaturesFooter", @"Nothing to report for this device.");
	return TGL(@"Device.FeaturesFooter",
		@"Features off here are not missing from the app - this device "
		@"cannot run them.");
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return 46;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *title = [self headerTitleForSection:section];
	return [[TGTheme shared] groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (CGFloat)footerTextHeightForSection:(NSInteger)section width:(CGFloat)width {
	NSString *footerText = [self footerTextForSection:section];
	return [[TGTheme shared] groupedCommentHeightForText:footerText width:width];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	CGFloat height = [self footerTextHeightForSection:section
												width:tableView.bounds.size.width];
	return height > 0 ? height : 12;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *footerText = [self footerTextForSection:section];
	return [[TGTheme shared] groupedCommentViewWithText:footerText width:tableView.bounds.size.width];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return section == 0 ? 7 : (NSInteger)self.capabilities.count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section != 0)
		return;
	NSString *line = [NSString stringWithFormat:@"%@: %@",
		[self titleForHardwareRow:indexPath.row],
		[self valueForHardwareRow:indexPath.row]];
	[[UIPasteboard generalPasteboard] setString:line];
	self.copiedIndexPath = indexPath;
	[tableView reloadRowsAtIndexPaths:@[ indexPath ]
					 withRowAnimation:UITableViewRowAnimationNone];
	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			typeof(self) strongSelf = weakSelf;
			if (!strongSelf || ![strongSelf.copiedIndexPath isEqual:indexPath])
				return;
			strongSelf.copiedIndexPath = nil;
			if (indexPath.row < [strongSelf.tableView numberOfRowsInSection:0])
				[strongSelf.tableView reloadRowsAtIndexPaths:@[ indexPath ]
											withRowAnimation:UITableViewRowAnimationNone];
		});
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
									  reuseIdentifier:@"row"];
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:16];
	[[TGTheme shared] styleCell:cell];
	cell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];
	cell.detailTextLabel.textColor = [[TGTheme shared] cellDetailColour];

	if (indexPath.section == 0) {
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		cell.textLabel.text = [self titleForHardwareRow:indexPath.row];
		if (self.copiedIndexPath && self.copiedIndexPath.row == indexPath.row)
			cell.detailTextLabel.text = TGL(@"Device.Copied", @"copied");
		else
			cell.detailTextLabel.text = [self valueForHardwareRow:indexPath.row];
		return cell;
	}

	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	if (indexPath.row >= (NSInteger)self.capabilities.count) {
		cell.textLabel.text = @"";
		cell.detailTextLabel.text = @"";
		return cell;
	}
	TGCapability *capability = self.capabilities[indexPath.row];
	cell.textLabel.text = capability.name ?: @"";
	cell.detailTextLabel.text = capability.available
		? TGL(@"Device.CapabilityOn", @"on")
		: (capability.requirement ?: TGL(@"Device.CapabilityOff", @"off"));
	cell.detailTextLabel.textColor = capability.available
		? [[TGTheme shared] cellDetailColour]
		: [[TGTheme shared] secondaryTextColour];
	cell.textLabel.textColor = capability.available
		? [[TGTheme shared] primaryTextColour]
		: [[TGTheme shared] secondaryTextColour];
	return cell;
}

@end

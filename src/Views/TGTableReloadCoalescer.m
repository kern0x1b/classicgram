#import "TGTableReloadCoalescer.h"

@interface TGTableReloadCoalescer ()
@property (nonatomic, weak) UITableView *tableView;
@property (nonatomic, assign) BOOL reloadPending;
@end

@implementation TGTableReloadCoalescer

- (instancetype)initWithTableView:(UITableView *)tableView {
	self = [super init];
	if (self)
		_tableView = tableView;
	return self;
}

- (void)setNeedsReload {
	if (self.reloadPending || !self.tableView)
		return;
	self.reloadPending = YES;
	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		TGTableReloadCoalescer *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.reloadPending = NO;
		[strongSelf.tableView reloadData];
	});
}

@end

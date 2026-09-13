#import "TGInlineQueryResultStrip.h"
#import "TGTheme.h"
#import "TGInlineResultCell.h"
#import "TGFileDownloadService.h"
#import "TGImageDecode.h"

static const CGFloat kInlineResultRowHeight = 44.0f;
static const NSUInteger kInlineResultMaxVisibleRows = 4;

@interface TGInlineQueryResultStrip () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *topRule;
@property (nonatomic, strong) NSArray *results;
@property (nonatomic, strong) NSMutableDictionary *thumbnails;
@property (nonatomic, copy) NSString *buttonText;

@end

@implementation TGInlineQueryResultStrip

+ (CGFloat)heightForResultCount:(NSUInteger)count {
	NSInteger visible = MIN(count, kInlineResultMaxVisibleRows);
	if (visible == 0)
		visible = 1;
	return visible * kInlineResultRowHeight;
}

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self != nil) {
		_results = @[];
		_thumbnails = [NSMutableDictionary dictionary];
		self.hidden = YES;
		self.backgroundColor = [[TGTheme shared] listBackgroundColour];
		self.clipsToBounds = YES;

		_topRule = [[UIView alloc] initWithFrame:CGRectZero];
		_topRule.backgroundColor = [[TGTheme shared] separatorColour];
		[self addSubview:_topRule];

		_tableView = [[UITableView alloc] initWithFrame:self.bounds style:UITableViewStylePlain];
		_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
			UIViewAutoresizingFlexibleHeight;
		_tableView.dataSource = self;
		_tableView.delegate = self;
		_tableView.rowHeight = kInlineResultRowHeight;
		_tableView.separatorColor = [[TGTheme shared] separatorColour];
		_tableView.backgroundColor = [UIColor clearColor];
		_tableView.showsVerticalScrollIndicator = NO;
		[self addSubview:_tableView];
	}
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGFloat pixel = 1.0f / [UIScreen mainScreen].scale;
	self.topRule.frame = CGRectMake(0, 0, self.bounds.size.width, pixel);
	self.tableView.frame = self.bounds;
}

#pragma mark - content

- (void)clear {
	if (self.hidden && self.results.count == 0 && !self.buttonText.length)
		return;
	self.results = @[];
	self.buttonText = nil;
	[self.thumbnails removeAllObjects];
	[self.tableView reloadData];
	[self setVisible:NO];
}

- (void)showResults:(NSArray *)results {
	NSArray *safe = [results isKindOfClass:NSArray.class] ? results : @[];
	self.results = safe;
	[self.tableView reloadData];
	self.tableView.contentOffset = CGPointZero;
	[self setVisible:(safe.count > 0 || self.buttonText.length > 0)];
}

- (void)appendResults:(NSArray *)results {
	NSArray *addition = [results isKindOfClass:NSArray.class] ? results : @[];
	if (!addition.count)
		return;
	self.results = [self.results arrayByAddingObjectsFromArray:addition];
	[self.tableView reloadData];
}

- (void)setButtonText:(NSString *)buttonText {
	_buttonText = buttonText.length ? [buttonText copy] : nil;
}

- (void)setVisible:(BOOL)visible {
	if (self.hidden == !visible)
		return;
	self.hidden = !visible;
	if (self.onVisibilityChanged)
		self.onVisibilityChanged(visible);
}

#pragma mark - table view

- (BOOL)hasButtonRow {
	return self.buttonText.length > 0;
}

- (NSInteger)resultIndexForRow:(NSInteger)row {
	return [self hasButtonRow] ? row - 1 : row;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.results.count + ([self hasButtonRow] ? 1 : 0);
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSString *reuse = [TGInlineResultCell reuseIdentifier];
	TGInlineResultCell *cell = (TGInlineResultCell *)[tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGInlineResultCell alloc] initWithReuseIdentifier:reuse];

	if ([self hasButtonRow] && indexPath.row == 0) {
		[cell configureAsButtonWithText:self.buttonText];
		return cell;
	}

	NSInteger resultIndex = [self resultIndexForRow:indexPath.row];
	NSDictionary *result = self.results[(NSUInteger)resultIndex];
	[cell configureWithResult:result];
	[self loadThumbnailForResult:result intoCell:cell];

	if (resultIndex + 5 >= (NSInteger)self.results.count && self.onNeedsMoreResults)
		self.onNeedsMoreResults();

	return cell;
}

- (void)loadThumbnailForResult:(NSDictionary *)result intoCell:(UITableViewCell *)cell {
	NSNumber *thumbId = result[@"thumbId"];
	if (!thumbId)
		return;
	UIImage *cached = self.thumbnails[thumbId];
	if (cached) {
		cell.imageView.image = cached;
		return;
	}
	NSString *resultId = result[@"id"];
	__weak typeof(self) weakSelf = self;
	__weak UITableViewCell *weakCell = cell;
	[TGFileDownloadService downloadFile:[thumbId longLongValue] completion:^(NSString *path) {
		TGInlineQueryResultStrip *strongSelf = weakSelf;
		if (!strongSelf || !path.length)
			return;
		dispatch_async(TGImageDecodeQueue(), ^{
			UIImage *image = [UIImage imageWithContentsOfFile:path];
			if (!image)
				return;
			dispatch_async(dispatch_get_main_queue(), ^{
				TGInlineQueryResultStrip *innerSelf = weakSelf;
				UITableViewCell *stillVisible = weakCell;
				if (!innerSelf)
					return;
				innerSelf.thumbnails[thumbId] = image;
				NSIndexPath *current = [innerSelf.tableView indexPathForCell:stillVisible];
				if (!stillVisible || !current)
					return;
				NSInteger resultIndex = [innerSelf resultIndexForRow:current.row];
				if (resultIndex < 0 || (NSUInteger)resultIndex >= innerSelf.results.count)
					return;
				NSDictionary *stillShowing = innerSelf.results[(NSUInteger)resultIndex];
				if (![stillShowing[@"id"] isEqual:resultId])
					return;
				stillVisible.imageView.image = image;
				[stillVisible setNeedsLayout];
			});
		});
	}];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if ([self hasButtonRow] && indexPath.row == 0) {
		void (^onButtonPicked)(void) = self.onButtonPicked;
		[self clear];
		if (onButtonPicked)
			onButtonPicked();
		return;
	}

	NSInteger resultIndex = [self resultIndexForRow:indexPath.row];
	if (resultIndex < 0 || (NSUInteger)resultIndex >= self.results.count)
		return;
	NSDictionary *result = self.results[(NSUInteger)resultIndex];
	[self clear];
	if (self.onResultPicked)
		self.onResultPicked(result);
}

@end

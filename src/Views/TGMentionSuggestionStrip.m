#import "TGMentionSuggestionStrip.h"
#import "TGTheme.h"

static const CGFloat kMentionSuggestionRowHeight = 44.0f;
static const NSUInteger kMentionSuggestionMaxVisibleRows = 4;

@interface TGMentionSuggestionStrip () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *topRule;
@property (nonatomic, strong) NSArray *candidates;

@end

@implementation TGMentionSuggestionStrip

+ (CGFloat)heightForCandidateCount:(NSUInteger)count {
	NSInteger visible = MIN(count, kMentionSuggestionMaxVisibleRows);
	if (visible == 0)
		visible = 1;
	return visible * kMentionSuggestionRowHeight;
}

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self != nil) {
		_candidates = @[];
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
		_tableView.rowHeight = kMentionSuggestionRowHeight;
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
	if (self.hidden && self.candidates.count == 0)
		return;
	self.candidates = @[];
	[self.tableView reloadData];
	[self setVisible:NO];
}

- (void)showCandidates:(NSArray *)candidates {
	NSArray *safe = [candidates isKindOfClass:NSArray.class] ? candidates : @[];
	self.candidates = safe;
	[self.tableView reloadData];
	self.tableView.contentOffset = CGPointZero;
	[self setVisible:(safe.count > 0)];
}

- (void)setVisible:(BOOL)visible {
	if (self.hidden == !visible)
		return;
	self.hidden = !visible;
	if (self.onVisibilityChanged)
		self.onVisibilityChanged(visible);
}

#pragma mark - table view

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.candidates.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *reuse = @"TGMentionSuggestionCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									   reuseIdentifier:reuse];
	[[TGTheme shared] styleCell:cell];

	NSDictionary *candidate = self.candidates[(NSUInteger)indexPath.row];
	NSString *name = candidate[@"name"];
	NSString *username = candidate[@"username"];
	BOOL hasUsername = [username isKindOfClass:NSString.class] && username.length > 0;

	cell.textLabel.text = name.length ? name
		: (hasUsername ? [NSString stringWithFormat:@"@%@", username] : @"");
	cell.textLabel.font = [UIFont systemFontOfSize:15];
	cell.textLabel.textColor = [[TGTheme shared] primaryTextColour];
	cell.detailTextLabel.text = (name.length && hasUsername)
		? [NSString stringWithFormat:@"@%@", username]
		: nil;
	cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if ((NSUInteger)indexPath.row >= self.candidates.count)
		return;
	NSDictionary *candidate = self.candidates[(NSUInteger)indexPath.row];
	[self clear];
	if (self.onCandidatePicked)
		self.onCandidatePicked(candidate);
}

@end

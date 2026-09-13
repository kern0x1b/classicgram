#import "TGStoryStatisticsViewController.h"
#import "TGStoryChartView.h"
#import "TGLocalization.h"
#import "TGClient+Stories.h"
#import "TGClient+Channels.h"
#import "TGTheme.h"

@implementation TGStoryStatisticsViewController {
	NSArray *_graphs;
	NSMutableDictionary *_charts;
	UILabel *_emptyLabel;
	BOOL _loaded;
}

- (void)loadView {
	CGRect bounds = [UIScreen mainScreen].bounds;
	UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:bounds];
	scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.view = scrollView;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"Stats.StoryTitle", @"Story Statistics");
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];
	_charts = [NSMutableDictionary dictionary];

	_emptyLabel = [[UILabel alloc] initWithFrame:
			CGRectMake(0, 40, self.view.bounds.size.width, 22)];
	_emptyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_emptyLabel.backgroundColor = [UIColor clearColor];
	_emptyLabel.textAlignment = NSTextAlignmentCenter;
	_emptyLabel.font = [UIFont systemFontOfSize:15];
	_emptyLabel.textColor = [[TGTheme shared] secondaryTextColour];
	_emptyLabel.text = TGL(@"Channel.NotificationLoading", @"Loading…");
	[self.view addSubview:_emptyLabel];

	[self load];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)load {
	if (self.chatId == 0 || self.storyId == 0)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] statisticsForStory:self.storyId inChat:self.chatId isDark:NO
							   completion:^(NSArray *graphs) {
								   typeof(self) strongSelf = weakSelf;
								   if (!strongSelf)
									   return;
								   strongSelf->_loaded = YES;
								   strongSelf->_graphs = graphs ?: @[];
								   if (!strongSelf->_graphs.count) {
									   strongSelf->_emptyLabel.text = TGL(@"Stories.NoStatisticsYet", @"No statistics yet.");
									   return;
								   }
								   strongSelf->_emptyLabel.hidden = YES;
								   [strongSelf buildCharts];
								   for (NSDictionary *graph in strongSelf->_graphs)
									   [strongSelf loadGraphIfAsync:graph];
							   }];
}

- (void)buildCharts {
	CGFloat width = self.view.bounds.size.width;
	CGFloat y = 12;
	for (NSDictionary *graph in _graphs) {
		NSString *title = graph[@"title"];
		UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(16, y, width - 32, 20)];
		label.backgroundColor = [UIColor clearColor];
		label.font = [UIFont boldSystemFontOfSize:15];
		label.textColor = [[TGTheme shared] primaryTextColour];
		label.text = title;
		[self.view addSubview:label];
		y += 24;

		TGStoryChartView *chart = [[TGStoryChartView alloc] initWithFrame:
				CGRectMake(8, y, width - 16, 140)];
		chart.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[self.view addSubview:chart];
		if ([graph[@"key"] isKindOfClass:[NSString class]])
			_charts[graph[@"key"]] = chart;
		[self applyGraph:graph toChart:chart];
		y += 156;
	}
	((UIScrollView *)self.view).contentSize = CGSizeMake(width, y);
}

- (void)loadGraphIfAsync:(NSDictionary *)graph {
	NSString *token = graph[@"token"];
	if (![token isKindOfClass:[NSString class]] || !token.length)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] statisticalGraphForChat:self.chatId token:token zoomAtX:0
									completion:^(NSDictionary *loaded) {
										typeof(self) strongSelf = weakSelf;
										if (!strongSelf || ![loaded[@"json"] isKindOfClass:[NSString class]])
											return;
										TGStoryChartView *chart = strongSelf->_charts[graph[@"key"]];
										if (!chart)
											return;
										[strongSelf applyGraphJson:loaded[@"json"] toChart:chart];
									}];
}

- (void)applyGraph:(NSDictionary *)graph toChart:(TGStoryChartView *)chart {
	NSString *json = graph[@"json"];
	if ([json isKindOfClass:[NSString class]] && json.length)
		[self applyGraphJson:json toChart:chart];
}

- (void)applyGraphJson:(NSString *)json toChart:(TGStoryChartView *)chart {
	NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
	if (!data.length)
		return;
	id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
	if (![parsed isKindOfClass:[NSDictionary class]])
		return;
	id columns = [(NSDictionary *)parsed objectForKey:@"columns"];
	if (![columns isKindOfClass:[NSArray class]])
		return;

	NSMutableArray *dataColumns = [NSMutableArray array];
	for (id column in columns) {
		if (![column isKindOfClass:[NSArray class]] || [column count] < 2)
			continue;
		NSString *key = [[column objectAtIndex:0] isKindOfClass:[NSString class]]
			? [column objectAtIndex:0]
			: nil;
		if ([key isEqualToString:@"x"])
			continue;
		[dataColumns addObject:column];
	}
	if (!dataColumns.count)
		return;

	NSUInteger length = 0;
	for (NSArray *column in dataColumns)
		length = MAX(length, column.count);
	if (length < 2)
		return;

	NSMutableArray *points = [NSMutableArray array];
	for (NSUInteger i = 1; i < length; i++) {
		double sum = 0;
		BOOL any = NO;
		for (NSArray *column in dataColumns) {
			if (i >= column.count)
				continue;
			id value = column[i];
			if ([value isKindOfClass:[NSNumber class]]) {
				sum += [value doubleValue];
				any = YES;
			}
		}
		if (any)
			[points addObject:@(sum)];
	}
	if (points.count > 60)
		[points removeObjectsInRange:NSMakeRange(0, points.count - 60)];
	chart.points = points;
}

@end

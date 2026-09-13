#import "TGMessageStatisticsViewController.h"
#import "TGDateUtils.h"
#import "TGProfileChartView.h"
#import "TGProfileStyle.h"
#import "TGFlattenChannels.h"
#import "TGClient+Channels.h"
#import "TGLocalization.h"
#import "TGTheme.h"

@implementation TGMessageStatisticsViewController {
	NSMutableDictionary *_charts;
	UILabel *_emptyLabel;
	UIActivityIndicatorView *_spinner;
}

- (void)loadView {
	CGRect bounds = [UIScreen mainScreen].bounds;
	UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:bounds];
	scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.view = scrollView;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"Stats.MessageTitle", @"Message Statistics");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];
	_charts = [NSMutableDictionary dictionary];

	_spinner = [[UIActivityIndicatorView alloc]
		initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	_spinner.center = CGPointMake(self.view.bounds.size.width / 2, 120);
	_spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
		UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
	[_spinner startAnimating];
	[self.view addSubview:_spinner];

	[self load];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)load {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] statisticsForMessage:self.messageId
									  inChat:self.chatId
									  isDark:NO
								  completion:^(NSArray *graphs) {
									  typeof(self) strongSelf = weakSelf;
									  if (!strongSelf)
										  return;
									  [strongSelf->_spinner stopAnimating];
									  [strongSelf->_spinner removeFromSuperview];
									  NSArray *list = [graphs isKindOfClass:[NSArray class]] ? graphs : @[];
									  if (!list.count) {
										  [strongSelf showEmpty];
										  return;
									  }
									  [strongSelf buildCharts:list];
								  }];
}

- (void)showEmpty {
	_emptyLabel = [[UILabel alloc] initWithFrame:CGRectInset(self.view.bounds, 24, 24)];
	_emptyLabel.text = TGL(@"Stats.Graph.LoadFailed", @"Could not load graph");
	_emptyLabel.textAlignment = NSTextAlignmentCenter;
	_emptyLabel.numberOfLines = 0;
	_emptyLabel.backgroundColor = [UIColor clearColor];
	_emptyLabel.textColor = [[TGTheme shared] secondaryTextColour];
	_emptyLabel.font = [UIFont systemFontOfSize:15];
	_emptyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:_emptyLabel];
}

- (void)buildCharts:(NSArray *)graphs {
	CGFloat width = self.view.bounds.size.width;
	CGFloat y = 12;
	for (NSDictionary *graph in graphs) {
		if (![graph isKindOfClass:[NSDictionary class]])
			continue;
		NSString *title = TGProfileText(graph[@"title"]) ?: @"";

		UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(16, y, width - 32, 20)];
		label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		label.backgroundColor = [UIColor clearColor];
		label.font = [UIFont boldSystemFontOfSize:15];
		label.textColor = [[TGTheme shared] primaryTextColour];
		label.text = title;
		[self.view addSubview:label];
		y += 24;

		TGProfileChartView *chart = [[TGProfileChartView alloc] initWithFrame:
				CGRectMake(0, y, width, 140)];
		chart.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[self.view addSubview:chart];
		if ([graph[@"key"] isKindOfClass:[NSString class]])
			_charts[graph[@"key"]] = chart;
		[self resolveGraph:graph intoChart:chart];
		y += 156;
	}
	((UIScrollView *)self.view).contentSize = CGSizeMake(width, y);
}

- (void)resolveGraph:(NSDictionary *)graph intoChart:(TGProfileChartView *)chart {
	NSString *error = TGProfileText(graph[@"error"]);
	if (error) {
		[self applyError:error toChart:chart];
		return;
	}
	NSString *json = TGProfileText(graph[@"json"]);
	if (json) {
		[self applyJson:json toChart:chart];
		return;
	}
	NSString *token = TGProfileText(graph[@"token"]);
	if (!token.length) {
		[self applyError:TGL(@"Stats.Graph.LoadFailed", @"Could not load graph") toChart:chart];
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] statisticalGraphForChat:self.chatId
										 token:token
									   zoomAtX:0
									completion:^(NSDictionary *loaded) {
										typeof(self) strongSelf = weakSelf;
										if (!strongSelf)
											return;
										NSString *loadedJson = [loaded isKindOfClass:[NSDictionary class]]
											? TGProfileText(loaded[@"json"])
											: nil;
										NSString *loadedError = [loaded isKindOfClass:[NSDictionary class]]
											? TGProfileText(loaded[@"error"])
											: nil;
										if (loadedJson) {
											[strongSelf applyJson:loadedJson toChart:chart];
											return;
										}
										[strongSelf applyError:(loadedError ?: TGL(@"Stats.Graph.LoadFailed", @"Could not load graph"))
													  toChart:chart];
									}];
}

- (void)applyJson:(NSString *)json toChart:(TGProfileChartView *)chart {
	NSDictionary *resolved = TGChPointsFromGraphJson(json, 30);
	NSArray *points = [resolved[@"points"] isKindOfClass:[NSArray class]] ? resolved[@"points"] : nil;
	if (!points.count) {
		[self applyError:TGL(@"Stats.Graph.LoadFailed", @"Could not load graph") toChart:chart];
		return;
	}
	chart.errorText = nil;
	chart.points = points;
	NSNumber *firstX = [resolved[@"firstX"] isKindOfClass:[NSNumber class]] ? resolved[@"firstX"] : nil;
	NSNumber *lastX = [resolved[@"lastX"] isKindOfClass:[NSNumber class]] ? resolved[@"lastX"] : nil;
	chart.leftDate = firstX ? [self dayTextFor:firstX] : nil;
	chart.rightDate = lastX ? [self dayTextFor:lastX] : nil;
}

- (void)applyError:(NSString *)error toChart:(TGProfileChartView *)chart {
	chart.points = @[];
	chart.errorText = [NSString stringWithFormat:
			TGL(@"Stats.Graph.CouldNotLoad", @"Could not load: %@"), error];
}

- (NSString *)dayTextFor:(NSNumber *)milliseconds {
	return [TGDateUtils stringForDayOfMonth:(int)([milliseconds doubleValue] / 1000.0)
								 dayOfMonth:NULL];
}

@end

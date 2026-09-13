#import "TGDayCalendarView.h"
#import "TGDateUtils.h"
#import "TGLocalization.h"

#import <QuartzCore/QuartzCore.h>

#import "TGMessageCalendarService.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGDevice.h"

static const CGFloat kCalendarHeaderHeight = 44.0f;
static const CGFloat kCalendarWeekdayHeight = 24.0f;
static const CGFloat kCalendarCellHeight = 34.0f;
static const CGFloat kCalendarPanelMargin = 12.0f;
static const CGFloat kCalendarPanelMaxWidth = 320.0f;
static const NSInteger kCalendarRows = 6;
static const NSInteger kCalendarColumns = 7;

static UIColor *TGCalendarRuleColour(void) {
	static UIColor *colour = nil;
	if (!colour)
		colour = [UIColor colorWithRed:0xc3 / 255.0f green:0xc9 / 255.0f
								  blue:0xcf / 255.0f
								 alpha:1.0f];
	return colour;
}

static UIColor *TGCalendarWeekdayStripColour(void) {
	static UIColor *colour = nil;
	if (!colour)
		colour = [UIColor colorWithRed:0xd3 / 255.0f green:0xd8 / 255.0f
								  blue:0xdd / 255.0f
								 alpha:1.0f];
	return colour;
}

static UIColor *TGCalendarDayColour(void) {
	static UIColor *colour = nil;
	if (!colour)
		colour = [UIColor colorWithRed:0x2b / 255.0f green:0x3d / 255.0f
								  blue:0x4f / 255.0f
								 alpha:1.0f];
	return colour;
}

static UIColor *TGCalendarQuietDayColour(void) {
	static UIColor *colour = nil;
	if (!colour)
		colour = [UIColor colorWithRed:0xb0 / 255.0f green:0xb6 / 255.0f
								  blue:0xbc / 255.0f
								 alpha:1.0f];
	return colour;
}

static UIImage *TGCalendarChevronImage(BOOL pointsLeft, BOOL faded) {
	CGFloat side = 26.0f;
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0.0f);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	if (faded)
		CGContextSetAlpha(ctx, 0.35f);

	CGRect disc = CGRectMake(0, 0, side, side);
	static const CGFloat faceColours[8] = {
		222 / 255.0f, 229 / 255.0f, 237 / 255.0f, 1.0f,
		198 / 255.0f, 207 / 255.0f, 219 / 255.0f, 1.0f};

	CGContextSaveGState(ctx);
	CGContextAddEllipseInRect(ctx, disc);
	CGContextClip(ctx);
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGGradientRef face = CGGradientCreateWithColorComponents(space, faceColours, NULL, 2);
	CGContextDrawLinearGradient(ctx, face, CGPointMake(0, 0), CGPointMake(0, side), 0);
	CGGradientRelease(face);
	CGColorSpaceRelease(space);
	CGContextRestoreGState(ctx);

	CGContextSetLineWidth(ctx, 1.0f);
	CGContextSetRGBStrokeColor(ctx, 0x8b / 255.0f, 0x99 / 255.0f, 0xab / 255.0f, 1.0f);
	CGContextStrokeEllipseInRect(ctx, CGRectInset(disc, 0.5f, 0.5f));

	CGFloat mid = side / 2;
	CGFloat arm = side * 0.17f;
	CGContextSetRGBStrokeColor(ctx, 0x5c / 255.0f, 0x70 / 255.0f, 0x8b / 255.0f, 1.0f);
	CGContextSetLineWidth(ctx, MAX(1.5f, side * 0.055f));
	CGContextSetLineCap(ctx, kCGLineCapRound);
	CGContextSetLineJoin(ctx, kCGLineJoinRound);
	if (pointsLeft) {
		CGContextMoveToPoint(ctx, mid + arm * 0.5f, mid - arm);
		CGContextAddLineToPoint(ctx, mid - arm * 0.55f, mid);
		CGContextAddLineToPoint(ctx, mid + arm * 0.5f, mid + arm);
	} else {
		CGContextMoveToPoint(ctx, mid - arm * 0.5f, mid - arm);
		CGContextAddLineToPoint(ctx, mid + arm * 0.55f, mid);
		CGContextAddLineToPoint(ctx, mid - arm * 0.5f, mid + arm);
	}
	CGContextStrokePath(ctx);

	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

@interface TGDayCalendarGridView : UIView
@property (nonatomic, assign) CGFloat cellWidth;
@property (nonatomic, assign) CGFloat cellHeight;
@end

@implementation TGDayCalendarGridView

- (void)drawRect:(CGRect)rect {
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGFloat pixel = 1.0f / [[UIScreen mainScreen] scale];
	CGContextSetFillColorWithColor(ctx, TGCalendarRuleColour().CGColor);
	for (NSInteger column = 1; column < kCalendarColumns; column++)
		CGContextFillRect(ctx, CGRectMake(floorf(column * _cellWidth), 0, pixel, self.bounds.size.height));
	for (NSInteger row = 1; row < kCalendarRows; row++)
		CGContextFillRect(ctx, CGRectMake(0, floorf(row * _cellHeight), self.bounds.size.width, pixel));
}

@end

@interface TGDayCalendarTitleView : UIView
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UIButton *previous;
@property (nonatomic, strong) UIButton *next;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation TGDayCalendarTitleView

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		self.backgroundColor = [UIColor clearColor];

		_label = [[UILabel alloc] initWithFrame:CGRectZero];
		_label.backgroundColor = [UIColor clearColor];
		_label.textAlignment = NSTextAlignmentCenter;
		_label.font = [UIFont boldSystemFontOfSize:17];
		_label.textColor = [[TGTheme shared] barTitleColour];
		[self addSubview:_label];

		_spinner = [[UIActivityIndicatorView alloc]
			initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
		_spinner.hidesWhenStopped = YES;
		[self addSubview:_spinner];
	}
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGFloat w = self.bounds.size.width;
	CGFloat h = self.bounds.size.height;
	_previous.frame = CGRectMake(0, 0, 32, h);
	_next.frame = CGRectMake(w - 32, 0, 32, h);
	_label.frame = CGRectMake(32, 0, w - 64, h);
	_spinner.center = CGPointMake(w - 46, h / 2);
}

@end

@interface TGDayCalendarWindowController : UIViewController
@property (nonatomic, strong) UIView *contentView;
@end

@implementation TGDayCalendarWindowController

- (void)loadView {
	self.view = self.contentView;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
	if ([TGDevice isPadIdiom])
		return YES;
	return UIInterfaceOrientationIsPortrait(orientation);
}

- (BOOL)shouldAutorotate {
	return [TGDevice isPadIdiom];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return [TGDevice isPadIdiom] ? UIInterfaceOrientationMaskAll
								 : UIInterfaceOrientationMaskPortrait;
}

@end

@interface TGDayCalendarChatCache : NSObject
@property (nonatomic, strong) NSMutableSet *daysWithMessages;
@property (nonatomic, assign) NSTimeInterval earliestSeededDayStart;
@property (nonatomic, assign) BOOL calendarStarted;
@property (nonatomic, assign) NSTimeInterval calendarCoveredFromDayStart;
@property (nonatomic, assign) int64_t calendarCursorMessageId;
@property (nonatomic, assign) BOOL calendarExhausted;
@end

@implementation TGDayCalendarChatCache

- (instancetype)init {
	self = [super init];
	if (self) {
		_daysWithMessages = [NSMutableSet set];
	}
	return self;
}

@end

static NSMutableDictionary *sCalendarCachesByChat = nil;

static TGDayCalendarChatCache *TGCalendarCacheForChat(int64_t chatId) {
	if (!sCalendarCachesByChat)
		sCalendarCachesByChat = [NSMutableDictionary dictionary];
	NSNumber *key = [NSNumber numberWithLongLong:chatId];
	TGDayCalendarChatCache *cache = [sCalendarCachesByChat objectForKey:key];
	if (!cache) {
		cache = [[TGDayCalendarChatCache alloc] init];
		[sCalendarCachesByChat setObject:cache forKey:key];
	}
	return cache;
}

static TGDayCalendarView *sOpenCalendar = nil;
static UIWindow *sCalendarWindow = nil;
static UIWindow *sPreviousKeyWindow = nil;

@implementation TGDayCalendarView {
	int64_t _chatId;
	void (^_pick)(NSTimeInterval, NSTimeInterval);

	NSCalendar *_calendar;
	NSDate *_shownMonth;
	NSInteger _pickedDayKey;
	NSInteger _todayKey;

	TGDayCalendarChatCache *_cache;
	BOOL _loading;
	NSInteger _probeToken;

	UIView *_shadow;
	UIView *_panel;
	UINavigationBar *_navBar;
	UINavigationItem *_navItem;
	TGDayCalendarTitleView *_titleView;
	UIView *_weekdayStrip;
	NSMutableArray *_weekdayLabels;
	TGDayCalendarGridView *_grid;
	NSMutableArray *_dayButtons;

	BOOL _dismissed;
	id _backgroundDismissObserverToken;
}

#pragma mark - lifetime

+ (void)dismiss {
	TGDayCalendarView *open = sOpenCalendar;
	sOpenCalendar = nil;
	[open teardownAnimated:YES];
}

+ (void)resetForAccountSwitch {
	[self dismiss];
	[sCalendarCachesByChat removeAllObjects];
}

+ (void)showForChat:(int64_t)chatId
		 aroundDate:(NSTimeInterval)date
		loadedDates:(NSArray *)loadedMessageDates
	 reachesPresent:(BOOL)reachesPresent
		  onPickDay:(void (^)(NSTimeInterval, NSTimeInterval))pick {
	if (chatId == 0)
		return;

	[self dismiss];

	CGRect bounds = [[UIScreen mainScreen] bounds];
	TGDayCalendarView *view = [[TGDayCalendarView alloc] initWithFrame:bounds];
	view->_chatId = chatId;
	view->_pick = [pick copy];
	[view buildAroundDate:date loadedDates:loadedMessageDates reachesPresent:reachesPresent];

	TGDayCalendarWindowController *controller = [[TGDayCalendarWindowController alloc] init];
	controller.contentView = view;

	UIWindow *window = [[UIWindow alloc] initWithFrame:bounds];
	window.windowLevel = UIWindowLevelStatusBar + 1.0f;
	window.backgroundColor = [UIColor clearColor];
	window.rootViewController = controller;

	UIWindow *key = [UIApplication sharedApplication].keyWindow;
	[key endEditing:YES];
	sPreviousKeyWindow = key;
	window.hidden = NO;
	[window makeKeyAndVisible];
	sCalendarWindow = window;
	sOpenCalendar = view;

	__weak TGDayCalendarView *weakView = view;
	view->_backgroundDismissObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:UIApplicationDidEnterBackgroundNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong TGDayCalendarView *strongView = weakView;
					if (!strongView)
						return;
					[strongView externalDismiss];
				}];
	[view present];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (_backgroundDismissObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_backgroundDismissObserverToken];
}

- (void)externalDismiss {
	if (sOpenCalendar == self)
		sOpenCalendar = nil;
	[self teardownAnimated:YES];
}

- (void)teardownAnimated:(BOOL)animated {
	if (_dismissed)
		return;
	_dismissed = YES;
	_pick = nil;
	_probeToken++;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (_backgroundDismissObserverToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:_backgroundDismissObserverToken];
		_backgroundDismissObserverToken = nil;
	}
	self.userInteractionEnabled = NO;

	UIWindow *myWindow = sCalendarWindow;
	UIWindow *myPreviousKey = sPreviousKeyWindow;
	sCalendarWindow = nil;
	sPreviousKeyWindow = nil;
	if (myPreviousKey)
		[myPreviousKey makeKeyAndVisible];

	void (^finish)(void) = ^{
		myWindow.rootViewController = nil;
		myWindow.hidden = YES;
	};

	if (!animated) {
		finish();
		return;
	}
	UIView *shadow = _shadow;
	[UIView animateWithDuration:0.18 delay:0
		options:UIViewAnimationOptionBeginFromCurrentState
		animations:^{
			self.backgroundColor = [UIColor clearColor];
			shadow.alpha = 0.0f;
			shadow.transform = CGAffineTransformMakeScale(0.9f, 0.9f);
		} completion:^(BOOL finished) {
			finish();
		}];
}

- (void)present {
	_shadow.alpha = 0.0f;
	_shadow.transform = CGAffineTransformMakeScale(0.88f, 0.88f);
	UIColor *dim = self.backgroundColor;
	self.backgroundColor = [UIColor clearColor];
	UIView *shadow = _shadow;
	[UIView animateWithDuration:0.2 delay:0
						options:UIViewAnimationOptionCurveEaseOut |
		UIViewAnimationOptionBeginFromCurrentState
					 animations:^{
						 self.backgroundColor = dim;
						 shadow.alpha = 1.0f;
						 shadow.transform = CGAffineTransformIdentity;
					 }
					 completion:nil];
}

#pragma mark - dates

- (NSDate *)startOfDay:(NSDate *)date {
	NSDateComponents *parts = [_calendar components:
			(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit)
										   fromDate:date];
	return [_calendar dateFromComponents:parts];
}

- (NSDate *)startOfMonth:(NSDate *)date {
	NSDateComponents *parts = [_calendar components:
			(NSYearCalendarUnit | NSMonthCalendarUnit)
										   fromDate:date];
	return [_calendar dateFromComponents:parts];
}

- (NSDate *)monthByAdding:(NSInteger)months to:(NSDate *)date {
	NSDateComponents *step = [[NSDateComponents alloc] init];
	step.month = months;
	return [_calendar dateByAddingComponents:step toDate:date options:0];
}

- (NSDate *)dayAfter:(NSDate *)date {
	NSDateComponents *step = [[NSDateComponents alloc] init];
	step.day = 1;
	return [_calendar dateByAddingComponents:step toDate:date options:0];
}

- (NSInteger)dayKeyOf:(NSDate *)date {
	NSDateComponents *parts = [_calendar components:
			(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit)
										   fromDate:date];
	return parts.year * 10000 + parts.month * 100 + parts.day;
}

- (NSInteger)monthKeyOf:(NSDate *)date {
	NSDateComponents *parts = [_calendar components:
			(NSYearCalendarUnit | NSMonthCalendarUnit)
										   fromDate:date];
	return parts.year * 100 + parts.month;
}

- (NSInteger)daysInMonth:(NSDate *)month {
	return [_calendar rangeOfUnit:NSDayCalendarUnit inUnit:NSMonthCalendarUnit
						  forDate:month]
		.length;
}

- (NSInteger)leadingBlanksForMonth:(NSDate *)month {
	NSDateComponents *parts = [_calendar components:NSWeekdayCalendarUnit fromDate:month];
	NSInteger offset = parts.weekday - _calendar.firstWeekday;
	if (offset < 0)
		offset += 7;
	return offset;
}

#pragma mark - building

- (void)buildAroundDate:(NSTimeInterval)date loadedDates:(NSArray *)loadedMessageDates
		 reachesPresent:(BOOL)reachesPresent {
	_calendar = [NSCalendar currentCalendar];
	_cache = TGCalendarCacheForChat(_chatId);
	_dayButtons = [NSMutableArray array];
	_weekdayLabels = [NSMutableArray array];

	NSTimeInterval earliestLoadedDayStart = 0;
	for (id value in loadedMessageDates) {
		if (![value isKindOfClass:NSNumber.class])
			continue;
		NSTimeInterval when = [value doubleValue];
		if (when <= 0)
			continue;
		NSDate *day = [self startOfDay:[NSDate dateWithTimeIntervalSince1970:when]];
		NSTimeInterval dayStart = [day timeIntervalSince1970];
		[_cache.daysWithMessages addObject:[NSNumber numberWithInteger:[self dayKeyOf:day]]];
		if (earliestLoadedDayStart == 0 || dayStart < earliestLoadedDayStart)
			earliestLoadedDayStart = dayStart;
	}
	if (reachesPresent && earliestLoadedDayStart > 0 &&
		(_cache.earliestSeededDayStart == 0 ||
			earliestLoadedDayStart < _cache.earliestSeededDayStart))
		_cache.earliestSeededDayStart = earliestLoadedDayStart;

	NSDate *anchor = date > 0 ? [NSDate dateWithTimeIntervalSince1970:date] : [NSDate date];
	_shownMonth = [self startOfMonth:anchor];
	_pickedDayKey = [self dayKeyOf:anchor];
	_todayKey = [self dayKeyOf:[NSDate date]];

	self.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.4f];
	self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

	_shadow = [[UIView alloc] initWithFrame:CGRectZero];
	_shadow.backgroundColor = [UIColor whiteColor];
	_shadow.layer.cornerRadius = 6.0f;
	_shadow.layer.shadowColor = [UIColor blackColor].CGColor;
	_shadow.layer.shadowOffset = CGSizeMake(0, 2);
	_shadow.layer.shadowOpacity = 0.45f;
	_shadow.layer.shadowRadius = 5.0f;
	[self addSubview:_shadow];

	_panel = [[UIView alloc] initWithFrame:CGRectZero];
	_panel.backgroundColor = [UIColor whiteColor];
	_panel.layer.cornerRadius = 6.0f;
	_panel.layer.borderWidth = 1.0f;
	_panel.layer.borderColor = [UIColor colorWithRed:0x24 / 255.0f green:0x42 / 255.0f
												blue:0x5f / 255.0f
											   alpha:1.0f]
								   .CGColor;
	_panel.clipsToBounds = YES;
	[_shadow addSubview:_panel];

	_navBar = [[UINavigationBar alloc] initWithFrame:CGRectZero];
	[[TGTheme shared] styleNavigationBar:_navBar];
	_navItem = [[UINavigationItem alloc] init];
	NSString *cancel = TGL(@"Common.Cancel", @"Cancel");
	SEL dismiss = @selector(externalDismiss);
	_navItem.leftBarButtonItem = [TGIcons headerBarButtonItemWithTitle:cancel bold:NO target:self action:dismiss];
	_titleView = [[TGDayCalendarTitleView alloc] initWithFrame:CGRectMake(0, 0, 160, 32)];
	_titleView.previous = [self headerButtonPointingLeft:YES action:@selector(showPreviousMonth)];
	_titleView.next = [self headerButtonPointingLeft:NO action:@selector(showNextMonth)];
	[_titleView addSubview:_titleView.previous];
	[_titleView addSubview:_titleView.next];
	_navItem.titleView = _titleView;
	_navBar.items = [NSArray arrayWithObject:_navItem];
	[_panel addSubview:_navBar];

	_weekdayStrip = [[UIView alloc] initWithFrame:CGRectZero];
	_weekdayStrip.backgroundColor = TGCalendarWeekdayStripColour();
	[_panel addSubview:_weekdayStrip];

	NSArray *symbols = [self weekdaySymbols];
	for (NSInteger i = 0; i < symbols.count; i++) {
		UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
		label.backgroundColor = [UIColor clearColor];
		label.textAlignment = NSTextAlignmentCenter;
		label.font = [UIFont boldSystemFontOfSize:11];
		label.textColor = [UIColor colorWithRed:0x4a / 255.0f green:0x5a / 255.0f
										   blue:0x6a / 255.0f
										  alpha:1.0f];
		label.shadowColor = [UIColor colorWithWhite:1.0f alpha:0.7f];
		label.shadowOffset = CGSizeMake(0, 1);
		label.text = symbols[i];
		[_weekdayStrip addSubview:label];
		[_weekdayLabels addObject:label];
	}

	UIView *stripRule = [[UIView alloc] initWithFrame:CGRectZero];
	stripRule.backgroundColor = TGCalendarRuleColour();
	stripRule.tag = 0x7101;
	[_weekdayStrip addSubview:stripRule];

	_grid = [[TGDayCalendarGridView alloc] initWithFrame:CGRectZero];
	_grid.backgroundColor = [UIColor whiteColor];
	_grid.opaque = YES;
	[_panel addSubview:_grid];

	for (NSInteger i = 0; i < kCalendarRows * kCalendarColumns; i++) {
		UIButton *day = [UIButton buttonWithType:UIButtonTypeCustom];
		day.tag = i;
		day.titleLabel.font = [UIFont boldSystemFontOfSize:15];
		day.backgroundColor = [UIColor clearColor];
		[day setTitleColor:TGCalendarDayColour() forState:UIControlStateNormal];
		[day setTitleColor:TGCalendarQuietDayColour() forState:UIControlStateDisabled];
		[day setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
		[day addTarget:self action:@selector(dayTapped:)
			forControlEvents:UIControlEventTouchUpInside];
		[_grid addSubview:day];
		[_dayButtons addObject:day];
	}

	[self refreshChrome];
}

- (UIButton *)headerButtonPointingLeft:(BOOL)pointsLeft action:(SEL)action {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	[button setImage:TGCalendarChevronImage(pointsLeft, NO) forState:UIControlStateNormal];
	[button setImage:TGCalendarChevronImage(pointsLeft, YES) forState:UIControlStateDisabled];
	[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
	return button;
}

- (NSArray *)weekdaySymbols {
	NSMutableArray *ordered = [NSMutableArray arrayWithCapacity:7];
	for (NSInteger i = 0; i < 7; i++) {
		NSInteger index = (_calendar.firstWeekday - 1 + i) % 7;
		NSString *name = [TGDateUtils shortWeekdayNameForTmWday:(int)index];
		[ordered addObject:[name uppercaseString]];
	}
	return ordered;
}

#pragma mark - layout

- (void)layoutSubviews {
	[super layoutSubviews];
	if (_dismissed)
		return;

	CGSize size = self.bounds.size;
	CGFloat widest = MIN(kCalendarPanelMaxWidth, size.width - 2 * kCalendarPanelMargin);
	CGFloat cellWidth = floorf((widest - 2) / kCalendarColumns);
	if (cellWidth < 24)
		cellWidth = 24;
	CGFloat panelWidth = cellWidth * kCalendarColumns + 2;

	CGFloat chrome = kCalendarHeaderHeight + kCalendarWeekdayHeight;
	CGFloat roomForGrid = size.height - 2 * kCalendarPanelMargin - chrome;
	CGFloat cellHeight = floorf(roomForGrid / kCalendarRows);
	if (cellHeight > kCalendarCellHeight)
		cellHeight = kCalendarCellHeight;
	if (cellHeight < 22)
		cellHeight = 22;
	CGFloat gridHeight = cellHeight * kCalendarRows;
	CGFloat panelHeight = chrome + gridHeight;

	CGRect frame = CGRectMake(floorf((size.width - panelWidth) / 2),
		floorf((size.height - panelHeight) / 2),
		panelWidth, panelHeight);
	if (frame.origin.y < kCalendarPanelMargin)
		frame.origin.y = kCalendarPanelMargin;
	_shadow.frame = frame;
	CGRect panelRect = CGRectMake(0, 0, panelWidth, panelHeight);
	_shadow.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:panelRect cornerRadius:6.0f].CGPath;
	_panel.frame = panelRect;

	_navBar.frame = CGRectMake(0, 0, panelWidth, kCalendarHeaderHeight);
	_titleView.frame = CGRectMake(0, 0, MAX(120, panelWidth - 150), 32);

	_weekdayStrip.frame = CGRectMake(0, kCalendarHeaderHeight,
		panelWidth, kCalendarWeekdayHeight);
	CGFloat pixel = 1.0f / [[UIScreen mainScreen] scale];
	[_weekdayStrip viewWithTag:0x7101].frame =
		CGRectMake(0, kCalendarWeekdayHeight - pixel, panelWidth, pixel);
	for (NSInteger i = 0; i < _weekdayLabels.count; i++)
		((UILabel *)_weekdayLabels[i]).frame =
			CGRectMake(1 + i * cellWidth, 0, cellWidth, kCalendarWeekdayHeight);

	CGFloat gridTop = kCalendarHeaderHeight + kCalendarWeekdayHeight;
	_grid.frame = CGRectMake(1, gridTop, cellWidth * kCalendarColumns, gridHeight);
	if (fabs(_grid.cellWidth - cellWidth) > 0.5f ||
		fabs(_grid.cellHeight - cellHeight) > 0.5f) {
		_grid.cellWidth = cellWidth;
		_grid.cellHeight = cellHeight;
		[_grid setNeedsDisplay];
	}

	for (NSInteger i = 0; i < _dayButtons.count; i++) {
		NSInteger column = i % kCalendarColumns;
		NSInteger row = i / kCalendarColumns;
		((UIButton *)_dayButtons[i]).frame =
			CGRectMake(column * cellWidth, row * cellHeight, cellWidth, cellHeight);
	}
}

#pragma mark - contents

- (void)refreshChrome {
	_titleView.label.text = [TGDateUtils stringForMonthAndYear:
			(int)[_shownMonth timeIntervalSince1970]];

	[self ensureMonthResolved:_shownMonth];

	if (_loading)
		[_titleView.spinner startAnimating];
	else
		[_titleView.spinner stopAnimating];

	NSDate *thisMonth = [self startOfMonth:[NSDate date]];
	_titleView.next.enabled = ([_shownMonth compare:thisMonth] == NSOrderedAscending);
	_titleView.previous.enabled = !(_cache.calendarExhausted &&
		[self monthKeyOf:_shownMonth] <= [self monthKeyOf:
												 [NSDate dateWithTimeIntervalSince1970:[self earliestKnownDayStart]]]);

	[self refreshDays];
}

- (void)refreshDays {
	NSInteger blanks = [self leadingBlanksForMonth:_shownMonth];
	NSInteger length = [self daysInMonth:_shownMonth];
	NSDateComponents *monthParts = [_calendar components:
			(NSYearCalendarUnit | NSMonthCalendarUnit)
												fromDate:_shownMonth];

	for (NSInteger i = 0; i < _dayButtons.count; i++) {
		UIButton *button = _dayButtons[i];
		NSInteger day = (NSInteger)i - blanks + 1;
		if (day < 1 || day > length) {
			button.hidden = YES;
			button.selected = NO;
			button.backgroundColor = [UIColor clearColor];
			continue;
		}
		button.hidden = NO;
		[button setTitle:[NSString stringWithFormat:@"%d", (int)day]
				forState:UIControlStateNormal];

		NSInteger key = monthParts.year * 10000 + monthParts.month * 100 + day;
		BOOL usable = key <= _todayKey &&
			[_cache.daysWithMessages containsObject:[NSNumber numberWithInteger:key]];
		button.enabled = usable;

		BOOL picked = usable && (key == _pickedDayKey);
		button.selected = picked;
		button.backgroundColor = picked
			? [[TGTheme shared] accentColour]
			: [UIColor clearColor];
		if (!picked && key == _todayKey)
			[button setTitleColor:[[TGTheme shared] accentColour]
						 forState:UIControlStateNormal];
		else
			[button setTitleColor:TGCalendarDayColour() forState:UIControlStateNormal];
	}
}

#pragma mark - navigation

- (void)showPreviousMonth {
	_shownMonth = [self monthByAdding:-1 to:_shownMonth];
	[self refreshChrome];
}

- (void)showNextMonth {
	_shownMonth = [self monthByAdding:1 to:_shownMonth];
	[self refreshChrome];
}

#pragma mark - calendar batch fetch

- (NSTimeInterval)earliestKnownDayStart {
	NSTimeInterval earliest = _cache.earliestSeededDayStart;
	if (_cache.calendarStarted && (earliest == 0 || _cache.calendarCoveredFromDayStart < earliest))
		earliest = _cache.calendarCoveredFromDayStart;
	return earliest;
}

- (BOOL)monthIsResolved:(NSDate *)month {
	NSTimeInterval monthStart = [[self startOfMonth:month] timeIntervalSince1970];
	if (_cache.earliestSeededDayStart > 0 && monthStart >= _cache.earliestSeededDayStart)
		return YES;
	if (_cache.calendarStarted && monthStart >= _cache.calendarCoveredFromDayStart)
		return YES;
	return _cache.calendarExhausted;
}

- (void)ensureMonthResolved:(NSDate *)month {
	if (_loading || [self monthIsResolved:month])
		return;

	_loading = YES;
	NSInteger token = ++_probeToken;
	int64_t fromMessageId = _cache.calendarStarted ? _cache.calendarCursorMessageId : 0;

	__weak typeof(self) weakSelf = self;
	void (^apply)(NSArray *, NSInteger) = ^(NSArray *days, NSInteger totalCount) {
		TGDayCalendarView *strongSelf = weakSelf;
		if (!strongSelf || strongSelf->_probeToken != token)
			return;
		[strongSelf applyCalendarBatch:days];
		strongSelf->_loading = NO;
		[strongSelf refreshChrome];
	};
	[TGMessageCalendarService messageCalendarForChat:_chatId filter:nil fromMessageId:fromMessageId completion:apply];
}

- (void)applyCalendarBatch:(NSArray *)days {
	_cache.calendarStarted = YES;

	NSTimeInterval oldestDayStart = 0;
	int64_t oldestMessageId = 0;
	for (NSDictionary *entry in days) {
		if (![entry isKindOfClass:NSDictionary.class])
			continue;
		NSTimeInterval when = [entry[@"date"] doubleValue];
		if (when <= 0)
			continue;
		NSDate *day = [self startOfDay:[NSDate dateWithTimeIntervalSince1970:when]];
		NSTimeInterval dayStart = [day timeIntervalSince1970];
		[_cache.daysWithMessages addObject:[NSNumber numberWithInteger:[self dayKeyOf:day]]];
		if (oldestDayStart == 0 || dayStart < oldestDayStart) {
			oldestDayStart = dayStart;
			oldestMessageId = [entry[@"messageId"] longLongValue];
		}
	}

	if (oldestDayStart == 0) {
		_cache.calendarExhausted = YES;
		return;
	}

	_cache.calendarCoveredFromDayStart = (_cache.calendarCoveredFromDayStart == 0)
		? oldestDayStart
		: MIN(_cache.calendarCoveredFromDayStart, oldestDayStart);
	_cache.calendarCursorMessageId = oldestMessageId;
}

#pragma mark - picking

- (void)dayTapped:(UIButton *)button {
	if (_dismissed)
		return;
	NSInteger blanks = [self leadingBlanksForMonth:_shownMonth];
	NSInteger day = button.tag - blanks + 1;
	if (day < 1 || day > [self daysInMonth:_shownMonth])
		return;

	NSDateComponents *parts = [_calendar components:
			(NSYearCalendarUnit | NSMonthCalendarUnit)
										   fromDate:_shownMonth];
	parts.day = day;
	NSDate *chosen = [_calendar dateFromComponents:parts];
	if (!chosen)
		return;

	NSTimeInterval dayStart = [chosen timeIntervalSince1970];
	NSDate *nextDayStart = [self dayAfter:chosen];
	NSTimeInterval seek = nextDayStart ? [nextDayStart timeIntervalSince1970] - 1 : dayStart + 86399;

	_pickedDayKey = [self dayKeyOf:chosen];
	[self refreshDays];

	void (^pick)(NSTimeInterval, NSTimeInterval) = _pick;
	[self externalDismiss];
	if (pick)
		pick(seek, dayStart);
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
	if (![self pointInside:point withEvent:event])
		return nil;
	if (_dismissed)
		return self;
	UIView *found = [super hitTest:point withEvent:event];
	if (found == self)
		[self externalDismiss];
	return found ? found : self;
}

@end

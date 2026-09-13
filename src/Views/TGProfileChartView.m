#import "TGProfileChartView.h"
#import "TGProfileStyle.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGHexColour.h"

@implementation TGProfileChartView

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		self.backgroundColor = [UIColor clearColor];
		self.contentMode = UIViewContentModeRedraw;
		self.points = @[];
		for (NSInteger i = 0; i < 4; i++) {
			UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
			label.tag = 200 + i;
			label.backgroundColor = [UIColor clearColor];
			label.font = [UIFont systemFontOfSize:10];
			label.textColor = TGColourFromHex(0x888888);
			if (i == 0 || i == 1) {
				label.adjustsFontSizeToFitWidth = YES;
				label.minimumScaleFactor = 0.6f;
			}
			[self addSubview:label];
		}
		UILabel *errorLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		errorLabel.tag = 210;
		errorLabel.numberOfLines = 2;
		errorLabel.textAlignment = NSTextAlignmentCenter;
		errorLabel.backgroundColor = [UIColor clearColor];
		errorLabel.font = [UIFont systemFontOfSize:14];
		errorLabel.textColor = [[TGTheme shared] secondaryTextColour];
		errorLabel.hidden = YES;
		[self addSubview:errorLabel];
	}
	return self;
}

- (UILabel *)errorLabel {
	return (UILabel *)[self viewWithTag:210];
}

- (UILabel *)labelAt:(NSInteger)index {
	return (UILabel *)[self viewWithTag:200 + index];
}

- (void)setPoints:(NSArray *)points {
	_points = points ?: @[];
	[self layoutLabels];
	[self setNeedsDisplay];
}

- (void)setLeftDate:(NSString *)leftDate {
	_leftDate = leftDate;
	[self layoutLabels];
}

- (void)setRightDate:(NSString *)rightDate {
	_rightDate = rightDate;
	[self layoutLabels];
}

- (void)setErrorText:(NSString *)errorText {
	_errorText = [errorText copy];
	[self layoutLabels];
	[self setNeedsDisplay];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	[self layoutLabels];
}

- (void)layoutLabels {
	CGFloat width = self.bounds.size.width;
	CGFloat height = self.bounds.size.height;
	BOOL hasError = self.errorText.length > 0;

	UILabel *top = [self labelAt:0];
	UILabel *bottom = [self labelAt:1];
	UILabel *left = [self labelAt:2];
	UILabel *right = [self labelAt:3];
	top.hidden = hasError;
	bottom.hidden = hasError;
	left.hidden = hasError;
	right.hidden = hasError;

	UILabel *error = [self errorLabel];
	error.hidden = !hasError;
	if (hasError) {
		error.text = self.errorText;
		error.frame = CGRectMake(15, 0, width - 30, height);
		return;
	}

	double maximum = 0, minimum = 0;
	[self scanMaximum:&maximum minimum:&minimum];

	top.frame = CGRectMake(0, 6, 26, 12);
	top.textAlignment = NSTextAlignmentRight;
	top.text = self.points.count ? [self shortNumber:maximum] : @"";

	bottom.frame = CGRectMake(0, height - 34, 26, 12);
	bottom.textAlignment = NSTextAlignmentRight;
	bottom.text = self.points.count ? [self shortNumber:minimum] : @"";

	left.frame = CGRectMake(30, height - 18, 100, 12);
	left.textAlignment = NSTextAlignmentLeft;
	left.text = self.leftDate ?: @"";

	right.frame = CGRectMake(width - 110, height - 18, 100, 12);
	right.textAlignment = NSTextAlignmentRight;
	right.text = self.rightDate ?: @"";
}

- (NSString *)shortNumber:(double)value {
	if (fabs(value) >= 1000000)
		return [NSString stringWithFormat:@"%.1fM", value / 1000000.0];
	if (fabs(value) >= 1000)
		return [NSString stringWithFormat:@"%.1fK", value / 1000.0];
	return [NSString stringWithFormat:@"%lld", (long long)value];
}

- (void)scanMaximum:(double *)maximum minimum:(double *)minimum {
	double high = 0, low = 0;
	BOOL first = YES;
	for (id point in self.points) {
		if (![point isKindOfClass:[NSNumber class]])
			continue;
		double value = [point doubleValue];
		if (first) {
			high = low = value;
			first = NO;
			continue;
		}
		if (value > high)
			high = value;
		if (value < low)
			low = value;
	}
	if (maximum)
		*maximum = high;
	if (minimum)
		*minimum = low;
}

- (void)drawRect:(CGRect)rect {
	if (self.errorText.length)
		return;
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (!context)
		return;
	CGFloat width = self.bounds.size.width;
	CGFloat height = self.bounds.size.height;
	CGFloat leftInset = 30, rightInset = 10, topInset = 12, bottomInset = 26;
	CGFloat plotHeight = height - topInset - bottomInset;
	CGFloat pixel = [UIScreen mainScreen].scale > 1.5f ? 0.5f : 1.0f;

	CGContextSetLineWidth(context, pixel);
	for (NSInteger i = 0; i <= 4; i++) {
		CGFloat y = topInset + plotHeight * i / 4.0f;
		UIColor *colour = (i == 0 || i == 4)
			? TGColourFromHex(0xd5dee5)
			: TGColourFromHex(0xe5e5e5);
		CGContextSetStrokeColorWithColor(context, colour.CGColor);
		CGContextBeginPath(context);
		CGContextMoveToPoint(context, leftInset, y);
		CGContextAddLineToPoint(context, width - rightInset, y);
		CGContextStrokePath(context);
	}

	NSInteger count = self.points.count;
	if (count < 2)
		return;

	double maximum = 0, minimum = 0;
	[self scanMaximum:&maximum minimum:&minimum];
	double span = maximum - minimum;
	if (span <= 0)
		span = 1;

	CGFloat plotWidth = width - leftInset - rightInset;
	CGContextSetLineWidth(context, 1.5f);
	CGContextSetLineJoin(context, kCGLineJoinRound);
	CGContextSetStrokeColorWithColor(context, TGColourFromHex(0x337acc).CGColor);
	CGContextBeginPath(context);
	for (NSInteger i = 0; i < count; i++) {
		id point = self.points[i];
		double value = [point isKindOfClass:[NSNumber class]] ? [point doubleValue] : 0;
		CGFloat x = leftInset + plotWidth * i / (CGFloat)(count - 1);
		CGFloat y = topInset + plotHeight * (1.0f - (value - minimum) / span);
		if (i == 0)
			CGContextMoveToPoint(context, x, y);
		else
			CGContextAddLineToPoint(context, x, y);
	}
	CGContextStrokePath(context);
}

@end

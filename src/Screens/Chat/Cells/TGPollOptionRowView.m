#import "TGPollOptionRowView.h"
#import "TGTheme.h"

@interface TGPollOptionRowView ()

@property (nonatomic, strong, readwrite) UIView *fillBar;
@property (nonatomic, strong, readwrite) UILabel *titleLabel;
@property (nonatomic, strong, readwrite) UILabel *percentLabel;
@property (nonatomic, strong, readwrite) UIView *dot;
@property (nonatomic, strong, readwrite) UILabel *markLabel;

@end

@implementation TGPollOptionRowView

- (instancetype)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (!self)
		return nil;

	self.dot = [[UIView alloc] init];
	self.dot.layer.cornerRadius = 4;
	self.dot.layer.borderWidth = 1.0f;
	self.dot.layer.borderColor = [[TGTheme shared] accentColour].CGColor;
	[self addSubview:self.dot];

	self.markLabel = [[UILabel alloc] init];
	self.markLabel.font = [UIFont boldSystemFontOfSize:11];
	self.markLabel.textColor = [UIColor whiteColor];
	self.markLabel.textAlignment = NSTextAlignmentCenter;
	self.markLabel.layer.cornerRadius = 7;
	self.markLabel.layer.masksToBounds = YES;
	self.markLabel.hidden = YES;
	[self addSubview:self.markLabel];

	self.fillBar = [[UIView alloc] init];
	self.fillBar.hidden = YES;
	self.fillBar.backgroundColor = [[TGTheme shared] accentColour];
	[self addSubview:self.fillBar];

	self.titleLabel = [[UILabel alloc] init];
	self.titleLabel.font = [UIFont systemFontOfSize:14];
	self.titleLabel.backgroundColor = [UIColor clearColor];
	[self addSubview:self.titleLabel];

	self.percentLabel = [[UILabel alloc] init];
	self.percentLabel.font = [UIFont systemFontOfSize:12];
	self.percentLabel.backgroundColor = [UIColor clearColor];
	self.percentLabel.hidden = YES;
	[self addSubview:self.percentLabel];

	return self;
}

- (void)setFraction:(CGFloat)fraction percentValue:(NSInteger)percentValue chosen:(BOOL)chosen closed:(BOOL)closed resultsVisible:(BOOL)resultsVisible {
	[self setFraction:fraction percentValue:percentValue chosen:chosen closed:closed resultsVisible:resultsVisible markState:TGPollOptionMarkStateNone];
}

- (void)setFraction:(CGFloat)fraction percentValue:(NSInteger)percentValue chosen:(BOOL)chosen closed:(BOOL)closed resultsVisible:(BOOL)resultsVisible markState:(TGPollOptionMarkState)markState {
	self.enabled = !closed;
	self.alpha = closed ? 0.4f : 1.0f;

	self.fillBar.hidden = fraction <= 0;
	self.percentLabel.hidden = !resultsVisible;
	if (fraction > 0) {
		CGRect bounds = self.bounds;
		CGFloat barX = 16;
		self.fillBar.frame = CGRectMake(barX, bounds.size.height - 2,
			(bounds.size.width - barX) * fraction, 2);
	}
	if (resultsVisible)
		self.percentLabel.text = [NSString stringWithFormat:@"%ld%%", (long)percentValue];

	if (markState == TGPollOptionMarkStateNone) {
		self.dot.hidden = NO;
		self.dot.backgroundColor = chosen ? [[TGTheme shared] accentColour] : [UIColor clearColor];
		self.markLabel.hidden = YES;
		return;
	}

	self.dot.hidden = YES;
	self.markLabel.hidden = NO;
	if (markState == TGPollOptionMarkStateCorrect) {
		self.markLabel.text = @"✓";
		self.markLabel.backgroundColor = [UIColor colorWithRed:0.30f green:0.69f blue:0.31f alpha:1.0f];
	} else {
		self.markLabel.text = @"✕";
		self.markLabel.backgroundColor = [UIColor colorWithRed:0.86f green:0.20f blue:0.18f alpha:1.0f];
	}
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGRect bounds = self.bounds;
	self.dot.frame = CGRectMake(0, (bounds.size.height - 8) / 2, 8, 8);
	self.markLabel.frame = CGRectMake(0, (bounds.size.height - 14) / 2, 14, 14);
	self.titleLabel.frame = CGRectMake(16, 0, bounds.size.width - 60, bounds.size.height - 4);
	self.percentLabel.frame = CGRectMake(bounds.size.width - 40, 0, 40, bounds.size.height - 4);
}

@end

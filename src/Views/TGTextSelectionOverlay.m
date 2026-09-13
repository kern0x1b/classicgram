#import "TGTextSelectionOverlay.h"
#import "TGRichText.h"
#import "TGPopupMenu.h"
#import "TGTheme.h"
#import "TGTextSelectionWordRange.h"
#import "TGLocalization.h"

@interface TGSelHandleView : UIView
@property (nonatomic, assign) BOOL start;
@end

@implementation TGSelHandleView

- (instancetype)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		self.backgroundColor = [UIColor clearColor];
		self.opaque = NO;
	}
	return self;
}

- (void)drawRect:(CGRect)rect {
	UIColor *tint = [[TGTheme shared] accentColour];
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetFillColorWithColor(context, tint.CGColor);

	CGFloat stemHeight = MAX(0.0f, rect.size.height - 13.0f);
	CGRect stem = CGRectMake(floorf(rect.size.width / 2) - 1, 0, 2, stemHeight);
	CGContextFillRect(context, stem);

	CGRect knob = CGRectMake(rect.size.width / 2 - 6.5f, stemHeight, 13, 13);
	CGContextFillEllipseInRect(context, knob);
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
	return CGRectContainsPoint(CGRectInset(self.bounds, -14, -14), point);
}

@end

@interface TGTextSelectionOverlay () <UIGestureRecognizerDelegate>
@property (nonatomic, assign) NSRange selection;
@property (nonatomic, strong) TGSelHandleView *startHandle;
@property (nonatomic, strong) TGSelHandleView *endHandle;
@end

@implementation TGTextSelectionOverlay

- (instancetype)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		self.backgroundColor = [UIColor clearColor];
		self.opaque = NO;
	}
	return self;
}

- (void)presentInView:(UIView *)host {
	if (!host || !self.text.length || !self.layout)
		return;

	self.frame = host.bounds;
	self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.selection = NSMakeRange(0, self.text.length);

	self.startHandle = [[TGSelHandleView alloc] initWithFrame:CGRectZero];
	self.startHandle.start = YES;
	UIPanGestureRecognizer *startPanAlloc = [UIPanGestureRecognizer alloc];
	UIPanGestureRecognizer *startPan = [startPanAlloc initWithTarget:self action:@selector(handlePan:)];
	[self.startHandle addGestureRecognizer:startPan];
	[self addSubview:self.startHandle];

	self.endHandle = [[TGSelHandleView alloc] initWithFrame:CGRectZero];
	self.endHandle.start = NO;
	UIPanGestureRecognizer *endPanAlloc = [UIPanGestureRecognizer alloc];
	UIPanGestureRecognizer *endPan = [endPanAlloc initWithTarget:self action:@selector(handlePan:)];
	[self.endHandle addGestureRecognizer:endPan];
	[self addSubview:self.endHandle];

	UITapGestureRecognizer *background = [[UITapGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(backgroundTapped:)];
	background.delegate = self;
	[self addGestureRecognizer:background];

	[host addSubview:self];
	[self layoutHandles];
	[self setNeedsDisplay];
	[self scheduleCopyCallout];
}

- (void)dismiss {
	[TGPopupMenu dismiss];
	[self removeFromSuperview];
}

#pragma mark - word boundaries

- (NSRange)wordRangeAtIndex:(NSUInteger)index {
	return TGTextSelectionWordRangeInText(self.text, index);
}

#pragma mark - handles

- (void)layoutHandles {
	NSArray *rects = [self.layout rectsForRange:self.selection inRect:self.bodyFrame];
	if (!rects.count) {
		self.startHandle.hidden = YES;
		self.endHandle.hidden = YES;
		return;
	}
	self.startHandle.hidden = NO;
	self.endHandle.hidden = NO;

	CGRect first = [[rects firstObject] CGRectValue];
	CGRect last = [[rects lastObject] CGRectValue];

	CGFloat startX = CGRectGetMinX(first);
	self.startHandle.frame = CGRectMake(startX - 15, first.origin.y - 2, 30,
		first.size.height + 16);

	CGFloat endX = CGRectGetMaxX(last);
	self.endHandle.frame = CGRectMake(endX - 15, last.origin.y - 2, 30,
		last.size.height + 16);
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
	TGSelHandleView *handle = (TGSelHandleView *)pan.view;
	if (![handle isKindOfClass:TGSelHandleView.class])
		return;

	if (pan.state == UIGestureRecognizerStateBegan) {
		[TGPopupMenu dismiss];
		return;
	}
	if (pan.state == UIGestureRecognizerStateEnded ||
		pan.state == UIGestureRecognizerStateCancelled) {
		[self scheduleCopyCallout];
		return;
	}
	if (pan.state != UIGestureRecognizerStateChanged)
		return;

	CGPoint point = [pan locationInView:self];
	NSInteger index = [self.layout stringIndexAtPoint:point inRect:self.bodyFrame];
	index = MIN(index, self.text.length);
	NSRange word = [self wordRangeAtIndex:index];

	NSRange current = self.selection;
	if (handle.start) {
		NSInteger end = current.location + current.length;
		NSInteger maxStart = end > 0 ? end - 1 : 0;
		NSInteger newStart = MIN(word.location, maxStart);
		self.selection = NSMakeRange(newStart, end - newStart);
	} else {
		NSInteger minEnd = current.location + 1;
		NSInteger newEnd = MAX(word.location + word.length, minEnd);
		newEnd = MIN(newEnd, self.text.length);
		self.selection = NSMakeRange(current.location, newEnd - current.location);
	}

	[self layoutHandles];
	[self setNeedsDisplay];
}

#pragma mark - copy callout

- (void)scheduleCopyCallout {
	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			__strong typeof(weakSelf) strongSelf = weakSelf;
			if (strongSelf && strongSelf.superview)
				[strongSelf showCopyCallout];
		});
}

- (void)showCopyCallout {
	NSArray *rects = [self.layout rectsForRange:self.selection inRect:self.bodyFrame];
	if (!rects.count)
		return;
	CGRect first = [[rects firstObject] CGRectValue];
	CGPoint point = CGPointMake(CGRectGetMidX(first), first.origin.y - 8);

	NSArray *items = @[ @{@"title" : TGL(@"Conversation.LinkDialogCopy", @"Copy")} ];
	__weak typeof(self) weakSelf = self;
	[TGPopupMenu showItems:items atPoint:point inView:self
				  onChoice:^(NSInteger index, __unused NSString *title) {
					  __strong typeof(weakSelf) strongSelf = weakSelf;
					  if (!strongSelf || index != 0)
						  return;
					  NSString *selected = [strongSelf.text substringWithRange:strongSelf.selection];
					  if (strongSelf.onCopy)
						  strongSelf.onCopy(selected);
				  }];
}

- (void)backgroundTapped:(UITapGestureRecognizer *)tap {
	[TGPopupMenu dismiss];
	if (self.onDismiss)
		self.onDismiss();
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
	   shouldReceiveTouch:(UITouch *)touch {
	UIView *view = touch.view;
	if ([view isDescendantOfView:self.startHandle] || [view isDescendantOfView:self.endHandle])
		return NO;
	for (UIView *ancestor = view; ancestor; ancestor = ancestor.superview) {
		if ([ancestor isKindOfClass:TGPopupMenu.class])
			return NO;
	}
	return YES;
}

#pragma mark - drawing

- (void)drawRect:(CGRect)rect {
	if (!self.layout || self.selection.length == 0)
		return;
	NSArray *rects = [self.layout rectsForRange:self.selection inRect:self.bodyFrame];
	if (!rects.count)
		return;

	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetFillColorWithColor(context,
		[[[TGTheme shared] accentColour] colorWithAlphaComponent:0.25f].CGColor);
	for (NSValue *value in rects)
		CGContextFillRect(context, [value CGRectValue]);
}

@end

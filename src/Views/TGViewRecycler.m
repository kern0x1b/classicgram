#import "TGViewRecycler.h"

static const NSUInteger kViewRecyclerMaxPoolSize = 32;
static const NSUInteger kViewRecyclerMaxTotalPoolSize = 96;

@interface TGViewRecycler ()

@property (nonatomic, strong) NSMutableDictionary *reusableViews;
@property (nonatomic, assign) NSUInteger pooledViewCount;
@property (nonatomic, strong) id memoryWarningObserverToken;
@property (nonatomic, strong) id backgroundObserverToken;

@end

@implementation TGViewRecycler

- (id)init {
	self = [super init];
	if (self != nil) {
		__weak typeof(self) weakSelf = self;
		dispatch_async(dispatch_get_main_queue(), ^{
			__strong typeof(weakSelf) strongSelf = weakSelf;
			if (!strongSelf)
				return;
			NSNotificationCenter *centre = [NSNotificationCenter defaultCenter];
			strongSelf.memoryWarningObserverToken = [centre
				addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
							object:nil
							 queue:nil
						usingBlock:^(NSNotification *note) {
							__strong typeof(weakSelf) innerSelf = weakSelf;
							if (!innerSelf)
								return;
							[innerSelf didReceiveMemoryWarning];
						}];
			strongSelf.backgroundObserverToken = [centre
				addObserverForName:UIApplicationDidEnterBackgroundNotification
							object:nil
							 queue:nil
						usingBlock:^(NSNotification *note) {
							__strong typeof(weakSelf) innerSelf = weakSelf;
							if (!innerSelf)
								return;
							[innerSelf didReceiveMemoryWarning];
						}];
		});
		self.reusableViews = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (self.memoryWarningObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.memoryWarningObserverToken];
	if (self.backgroundObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.backgroundObserverToken];
}

- (void)didReceiveMemoryWarning {
	[self removeAllViews];
}

- (UIView<TGReusableView> *)dequeueReusableViewWithIdentifier:(NSString *)reuseIdentifier {
	if (reuseIdentifier == nil)
		return nil;

	NSMutableArray *views = self.reusableViews[reuseIdentifier];
	if (views == nil)
		return nil;

	UIView<TGReusableView> *view = [views lastObject];
	if (view != nil) {
		[views removeLastObject];
		if (self.pooledViewCount > 0)
			self.pooledViewCount--;
		if (views.count == 0)
			[self.reusableViews removeObjectForKey:reuseIdentifier];
		[view prepareForReuse];
	}
	return view;
}

- (void)recycleView:(UIView<TGReusableView> *)view {
	if (view == nil)
		return;

	NSString *reuseIdentifier = nil;
	if ([view respondsToSelector:@selector(reuseIdentifier)])
		reuseIdentifier = [view reuseIdentifier];
	if (reuseIdentifier == nil)
		reuseIdentifier = NSStringFromClass([view class]);

	if (view.superview != nil)
		[view removeFromSuperview];

	[view prepareForRecycle:self];

	NSMutableArray *views = self.reusableViews[reuseIdentifier];

	if (views != nil && [views indexOfObjectIdenticalTo:view] != NSNotFound)
		return;

	if (views.count >= kViewRecyclerMaxPoolSize)
		return;

	if (self.pooledViewCount >= kViewRecyclerMaxTotalPoolSize)
		return;

	if (views == nil) {
		views = [[NSMutableArray alloc] init];
		self.reusableViews[reuseIdentifier] = views;
	}

	[views addObject:view];
	self.pooledViewCount++;
}

- (void)removeAllViews {
	[self.reusableViews removeAllObjects];
	self.pooledViewCount = 0;
}

@end

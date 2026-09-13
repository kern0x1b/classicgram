#import "TGCoordinator.h"

@interface TGCoordinator ()

@property (nonatomic, strong, readwrite) NSMutableArray<id<TGCoordinator>> *childCoordinators;

@end

@implementation TGCoordinator

- (instancetype)init {
	self = [super init];
	if (self)
		_childCoordinators = [NSMutableArray array];
	return self;
}

- (void)start {
}

@end

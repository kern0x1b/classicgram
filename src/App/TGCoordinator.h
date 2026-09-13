#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TGCoordinator <NSObject>

- (void)start;

@end

@interface TGCoordinator : NSObject <TGCoordinator>

@property (nonatomic, strong, readonly) NSMutableArray<id<TGCoordinator>> *childCoordinators;

@end

NS_ASSUME_NONNULL_END

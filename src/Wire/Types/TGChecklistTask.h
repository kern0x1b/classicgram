#import <Foundation/Foundation.h>

@interface TGChecklistTask : NSObject

@property (nonatomic, readonly) int64_t taskId;
@property (nonatomic, readonly, copy) NSString *text;
@property (nonatomic, readonly) BOOL done;

- (instancetype)initWithTaskId:(int64_t)taskId
						  text:(NSString *)text
						isDone:(BOOL)isDone NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

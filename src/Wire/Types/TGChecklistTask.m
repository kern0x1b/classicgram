#import "TGChecklistTask.h"

@implementation TGChecklistTask

- (instancetype)initWithTaskId:(int64_t)taskId
						  text:(NSString *)text
						isDone:(BOOL)isDone {
	self = [super init];
	if (self != nil) {
		_taskId = taskId;
		_text = [text copy];
		_done = isDone;
	}
	return self;
}

@end

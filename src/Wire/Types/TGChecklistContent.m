#import "TGChecklistContent.h"

@implementation TGChecklistContent

- (instancetype)initWithTitle:(NSString *)title
						tasks:(NSArray<TGChecklistTask *> *)tasks
				  canAddTasks:(BOOL)canAddTasks
		   canMarkTasksAsDone:(BOOL)canMarkTasksAsDone
			othersCanAddTasks:(BOOL)othersCanAddTasks
	 othersCanMarkTasksAsDone:(BOOL)othersCanMarkTasksAsDone {
	self = [super init];
	if (self != nil) {
		_title = [title copy];
		_tasks = [tasks copy];
		_canAddTasks = canAddTasks;
		_canMarkTasksAsDone = canMarkTasksAsDone;
		_othersCanAddTasks = othersCanAddTasks;
		_othersCanMarkTasksAsDone = othersCanMarkTasksAsDone;
	}
	return self;
}

@end

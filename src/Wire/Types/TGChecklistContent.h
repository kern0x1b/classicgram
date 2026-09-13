#import "TGMessageContent.h"

@class TGChecklistTask;

@interface TGChecklistContent : TGMessageContent

@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly, copy) NSArray<TGChecklistTask *> *tasks;
@property (nonatomic, readonly) BOOL canAddTasks;
@property (nonatomic, readonly) BOOL canMarkTasksAsDone;
@property (nonatomic, readonly) BOOL othersCanAddTasks;
@property (nonatomic, readonly) BOOL othersCanMarkTasksAsDone;

- (instancetype)initWithTitle:(NSString *)title
						tasks:(NSArray<TGChecklistTask *> *)tasks
				  canAddTasks:(BOOL)canAddTasks
		   canMarkTasksAsDone:(BOOL)canMarkTasksAsDone
			othersCanAddTasks:(BOOL)othersCanAddTasks
	 othersCanMarkTasksAsDone:(BOOL)othersCanMarkTasksAsDone NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

#import "TGChecklistTasks.h"

int32_t TGNextChecklistTaskId(NSArray *tasks) {
	int32_t nextId = 1;
	for (id item in tasks) {
		if (![item isKindOfClass:[NSDictionary class]])
			continue;
		int32_t taskId = [item[@"id"] intValue];
		if (taskId >= nextId)
			nextId = taskId + 1;
	}
	return nextId;
}

static NSDictionary *TGChecklistTask(id taskId, NSString *text) {
	return @{@"id" : taskId ?: @0, @"text" : text ?: @""};
}

NSArray *TGChecklistTasksByReplacingTaskId(NSArray *tasks, int32_t taskId, NSString *text) {
	NSMutableArray *updated = [NSMutableArray arrayWithCapacity:tasks.count];
	for (id item in tasks) {
		if (![item isKindOfClass:[NSDictionary class]])
			continue;
		if ([item[@"id"] intValue] == taskId)
			[updated addObject:TGChecklistTask(item[@"id"], text)];
		else
			[updated addObject:TGChecklistTask(item[@"id"], item[@"text"])];
	}
	return updated;
}

NSArray *TGChecklistTasksByRemovingTaskId(NSArray *tasks, int32_t taskId) {
	NSMutableArray *updated = [NSMutableArray arrayWithCapacity:tasks.count];
	for (id item in tasks) {
		if (![item isKindOfClass:[NSDictionary class]])
			continue;
		if ([item[@"id"] intValue] != taskId)
			[updated addObject:TGChecklistTask(item[@"id"], item[@"text"])];
	}
	return updated;
}

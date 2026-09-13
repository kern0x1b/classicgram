#import <Foundation/Foundation.h>

int32_t TGNextChecklistTaskId(NSArray *tasks);
NSArray *TGChecklistTasksByReplacingTaskId(NSArray *tasks, int32_t taskId, NSString *text);
NSArray *TGChecklistTasksByRemovingTaskId(NSArray *tasks, int32_t taskId);

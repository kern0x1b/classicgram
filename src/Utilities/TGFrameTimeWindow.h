#import <Foundation/Foundation.h>

extern const double TGFrameTimeBudgetSeconds;

typedef struct {
	NSInteger frames;
	NSInteger framesOverBudget;
	double worstDelta;
	double totalDelta;
} TGFrameTimeWindow;

void TGFrameTimeWindowReset(TGFrameTimeWindow *window);
void TGFrameTimeWindowAdd(TGFrameTimeWindow *window, double delta);
double TGFrameTimeWindowAverageFps(TGFrameTimeWindow window);

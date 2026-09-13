#import "TGFrameTimeWindow.h"

const double TGFrameTimeBudgetSeconds = 0.033;

static const double kFrameTimeIgnoreAbove = 2.0;

void TGFrameTimeWindowReset(TGFrameTimeWindow *window) {
	if (!window)
		return;
	window->frames = 0;
	window->framesOverBudget = 0;
	window->worstDelta = 0;
	window->totalDelta = 0;
}

void TGFrameTimeWindowAdd(TGFrameTimeWindow *window, double delta) {
	if (!window || delta <= 0 || delta > kFrameTimeIgnoreAbove)
		return;
	window->frames += 1;
	window->totalDelta += delta;
	if (delta > window->worstDelta)
		window->worstDelta = delta;
	if (delta > TGFrameTimeBudgetSeconds)
		window->framesOverBudget += 1;
}

double TGFrameTimeWindowAverageFps(TGFrameTimeWindow window) {
	if (window.frames < 1 || window.totalDelta <= 0)
		return 0;
	return (double)window.frames / window.totalDelta;
}

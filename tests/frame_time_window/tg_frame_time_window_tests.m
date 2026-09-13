#import "tg_frame_time_window_tests.h"
#import "../../src/Utilities/TGFrameTimeWindow.h"

TGTestOutcome TGFrameTimeWindowTestASteadyRunReportsItsRate(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGFrameTimeWindow window;
	TGFrameTimeWindowReset(&window);
	for (NSInteger i = 0; i < 60; i++)
		TGFrameTimeWindowAdd(&window, 1.0 / 60.0);

	TGTestExpectTrue(&outcome, window.frames == 60, "every frame must be counted");
	TGTestExpectTrue(&outcome, window.framesOverBudget == 0,
			"a frame inside the budget must not count as late");
	TGTestExpectTrue(&outcome, TGFrameTimeWindowAverageFps(window) > 59.9 &&
			TGFrameTimeWindowAverageFps(window) < 60.1,
			"sixty even frames must report sixty frames a second");
	TGTestExpectTrue(&outcome, window.worstDelta < 0.017,
			"the worst frame of an even run is one frame long");

	return outcome;
}

TGTestOutcome TGFrameTimeWindowTestALateFrameIsCountedAndKept(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGFrameTimeWindow window;
	TGFrameTimeWindowReset(&window);
	TGFrameTimeWindowAdd(&window, 1.0 / 60.0);
	TGFrameTimeWindowAdd(&window, 0.100);
	TGFrameTimeWindowAdd(&window, 1.0 / 60.0);

	TGTestExpectTrue(&outcome, window.framesOverBudget == 1,
			"one frame past the 33 ms budget must be counted once");
	TGTestExpectTrue(&outcome, window.worstDelta > 0.0999 && window.worstDelta < 0.1001,
			"the worst frame must be kept exactly, not averaged away");
	TGTestExpectTrue(&outcome, TGFrameTimeWindowAverageFps(window) < 30.0,
			"one long stall must pull the reported rate down");

	TGFrameTimeWindow budget;
	TGFrameTimeWindowReset(&budget);
	TGFrameTimeWindowAdd(&budget, TGFrameTimeBudgetSeconds);
	TGTestExpectTrue(&outcome, budget.framesOverBudget == 0,
			"a frame exactly at the budget is not over it");

	return outcome;
}

TGTestOutcome TGFrameTimeWindowTestNonsenseDeltasAreIgnored(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	TGFrameTimeWindow window;
	TGFrameTimeWindowReset(&window);
	TGFrameTimeWindowAdd(&window, 0);
	TGFrameTimeWindowAdd(&window, -0.5);
	TGFrameTimeWindowAdd(&window, 30.0);

	TGTestExpectTrue(&outcome, window.frames == 0,
			"a zero, a negative and a gap longer than any stall must all be dropped");
	TGTestExpectTrue(&outcome, TGFrameTimeWindowAverageFps(window) == 0,
			"an empty window reports no rate rather than dividing by zero");

	return outcome;
}

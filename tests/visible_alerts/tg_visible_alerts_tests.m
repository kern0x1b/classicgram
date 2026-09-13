#import "tg_visible_alerts_tests.h"
#import "../../src/Views/TGVisibleAlerts.h"

TGTestOutcome TGVisibleAlertsTestFindsAlertsAnywhereInTheWindows(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	UIView *window = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
	UIView *dimming = [[UIView alloc] initWithFrame:CGRectZero];
	UIActionSheet *sheet = [[UIActionSheet alloc] initWithFrame:CGRectZero];
	[dimming addSubview:sheet];
	[window addSubview:dimming];

	UIView *alertWindow = [[UIView alloc] initWithFrame:CGRectZero];
	UIAlertView *alert = [[UIAlertView alloc] initWithFrame:CGRectZero];
	[alertWindow addSubview:alert];

	UIView *plain = [[UIView alloc] initWithFrame:CGRectZero];
	[plain addSubview:[[UILabel alloc] initWithFrame:CGRectZero]];

	NSArray *found = TGVisibleAlertsInWindows(@[ window, alertWindow, plain, @"not a window" ]);

	TGTestExpectEqualLongLong(&outcome, (long long)found.count, 2,
			"both the nested action sheet and the alert in its own window are found");
	TGTestExpectTrue(&outcome, [found containsObject:sheet] && [found containsObject:alert],
			"the two found views are the sheet and the alert themselves");
	TGTestExpectEqualLongLong(&outcome, (long long)TGVisibleAlertsInViewTree(plain).count, 0,
			"a window holding no alert contributes nothing");
	TGTestExpectEqualLongLong(&outcome, (long long)TGVisibleAlertsInViewTree(nil).count, 0,
			"a missing view tree is not a crash");

	return outcome;
}

TGTestOutcome TGVisibleAlertsTestDismissesThemAndDropsTheirDelegates(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	UIView *window = [[UIView alloc] initWithFrame:CGRectZero];
	UIAlertView *alert = [[UIAlertView alloc] initWithFrame:CGRectZero];
	UIActionSheet *sheet = [[UIActionSheet alloc] initWithFrame:CGRectZero];
	NSObject *doomedDelegate = [[NSObject alloc] init];
	alert.delegate = doomedDelegate;
	sheet.delegate = doomedDelegate;
	[window addSubview:alert];
	[window addSubview:sheet];

	TGDismissVisibleAlertsInWindows(@[ window ]);

	TGTestExpectTrue(&outcome, alert.delegate == nil && sheet.delegate == nil,
			"a delegate that is about to be freed is dropped before it can be called back");
	TGTestExpectTrue(&outcome, alert.dismissed && sheet.dismissed,
			"both are taken off the screen as well, so nothing outlives the controller tree");

	return outcome;
}

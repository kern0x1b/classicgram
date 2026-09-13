#import "TGVisibleAlerts.h"

static void TGCollectVisibleAlerts(UIView *view, NSMutableArray *found) {
	if (!view)
		return;
	if ([view isKindOfClass:[UIAlertView class]] || [view isKindOfClass:[UIActionSheet class]]) {
		[found addObject:view];
		return;
	}
	for (UIView *sub in view.subviews)
		TGCollectVisibleAlerts(sub, found);
}

NSArray *TGVisibleAlertsInViewTree(UIView *root) {
	NSMutableArray *found = [NSMutableArray array];
	TGCollectVisibleAlerts(root, found);
	return found;
}

NSArray *TGVisibleAlertsInWindows(NSArray *windows) {
	NSMutableArray *found = [NSMutableArray array];
	for (id window in windows) {
		if (![window isKindOfClass:[UIView class]])
			continue;
		[found addObjectsFromArray:TGVisibleAlertsInViewTree(window)];
	}
	return found;
}

void TGDismissVisibleAlertsInWindows(NSArray *windows) {
	for (id alert in TGVisibleAlertsInWindows(windows)) {
		if ([alert isKindOfClass:[UIAlertView class]]) {
			UIAlertView *view = alert;
			view.delegate = nil;
			[view dismissWithClickedButtonIndex:view.cancelButtonIndex animated:NO];
			continue;
		}
		UIActionSheet *sheet = alert;
		sheet.delegate = nil;
		[sheet dismissWithClickedButtonIndex:sheet.cancelButtonIndex animated:NO];
	}
}

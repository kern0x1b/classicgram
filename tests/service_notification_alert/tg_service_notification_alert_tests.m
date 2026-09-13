#import "tg_service_notification_alert_tests.h"
#import "../../src/Wire/Flatten/TGServiceNotificationAlert.h"

TGTestOutcome TGServiceNotificationAlertTestServerNoticesReachTheUser(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSDictionary *login = @{
		@"@type" : @"updateServiceNotification",
		@"type" : @"",
		@"content" : @{@"@type" : @"messageText",
			@"text" : @{@"text" : @"New login from an unrecognised device."}},
	};
	NSDictionary *alert = TGServiceNotificationAlert(login);
	TGTestExpectTrue(&outcome,
			[alert[TGServiceNotificationTextKey]
					isEqualToString:@"New login from an unrecognised device."],
			"a service notice from the server carries its text to the alert");
	TGTestExpectTrue(&outcome, ![alert[TGServiceNotificationNeedsLogOutKey] boolValue],
			"an ordinary notice offers no log-out button");

	NSDictionary *keyDrop = @{
		@"@type" : @"updateServiceNotification",
		@"type" : @"AUTH_KEY_DROP_DUPLICATE",
		@"content" : @{@"@type" : @"messageText", @"text" : @{@"text" : @"  Session revoked.  "}},
	};
	NSDictionary *dropAlert = TGServiceNotificationAlert(keyDrop);
	TGTestExpectTrue(&outcome,
			[dropAlert[TGServiceNotificationTextKey] isEqualToString:@"Session revoked."],
			"surrounding whitespace is not part of the message");
	TGTestExpectTrue(&outcome, [dropAlert[TGServiceNotificationNeedsLogOutKey] boolValue],
			"an AUTH_KEY_DROP notice is the one that offers to log out");

	NSDictionary *photo = @{
		@"@type" : @"updateServiceNotification",
		@"type" : @"",
		@"content" : @{@"@type" : @"messagePhoto", @"caption" : @{@"text" : @"Look at this"}},
	};
	TGTestExpectTrue(&outcome,
			[TGServiceNotificationAlert(photo)[TGServiceNotificationTextKey]
					isEqualToString:@"Look at this"],
			"a notice sent as a captioned photo still reads as its caption");

	TGTestExpectTrue(&outcome,
			TGServiceNotificationAlert(@{@"@type" : @"updateServiceNotification", @"type" : @"",
				@"content" : @{@"@type" : @"messageText", @"text" : @{@"text" : @"   "}}}) == nil,
			"a notice with nothing to say raises no alert");
	TGTestExpectTrue(&outcome, TGServiceNotificationAlert(nil) == nil,
			"no update at all raises no alert");
	TGTestExpectTrue(&outcome,
			TGServiceNotificationAlert(@{@"@type" : @"updateServiceNotification",
				@"type" : @"", @"content" : @{@"@type" : @"messageContactRegistered"}}) == nil,
			"a content kind with no text of its own raises no alert either");

	return outcome;
}

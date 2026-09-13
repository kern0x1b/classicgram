#import "TGPushExtraLine.h"

#import "TGLocalization.h"

static NSString *TGPushExtraString(NSDictionary *content, NSString *key) {
	id value = content[key];
	return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSInteger TGPushExtraCount(NSDictionary *content, NSString *key) {
	id value = content[key];
	return [value isKindOfClass:NSNumber.class] ? [value integerValue] : 0;
}

static NSString *TGPushExtraActor(NSString *actorName) {
	return actorName.length ? actorName
							: TGL(@"Notification.UnknownUserListLowercase", @"someone");
}

static NSString *TGPushExtraDistance(NSInteger metres) {
	return metres >= 1000 ? [NSString stringWithFormat:@"%.1f km", metres / 1000.0]
						  : [NSString stringWithFormat:@"%ld m", (long) metres];
}

BOOL TGPushExtraLineIsSelfNarrating(NSString *type) {
	static NSSet *narrating = nil;
	if (!narrating)
		narrating = [[NSSet alloc] initWithObjects:@"pushMessageContentHidden",
			@"pushMessageContentPaidMedia", @"pushMessageContentPremiumGiftCode",
			@"pushMessageContentGiveaway", @"pushMessageContentGift",
			@"pushMessageContentUpgradedGift", @"pushMessageContentStory",
			@"pushMessageContentInviteVideoChatParticipants",
			@"pushMessageContentChatSetBackground", @"pushMessageContentChatSetTheme",
			@"pushMessageContentRecurringPayment",
			@"pushMessageContentProximityAlertTriggered",
			@"pushMessageContentChecklistTasksAdded", @"pushMessageContentChecklistTasksDone",
			@"pushMessageContentPollOptionAdded", nil];
	return type.length && [narrating containsObject:type];
}

NSString *TGPushExtraLine(NSDictionary *content, NSString *actorName) {
	if (![content isKindOfClass:NSDictionary.class])
		return nil;
	NSString *type = content[@"@type"];
	if (![type isKindOfClass:NSString.class])
		return nil;
	NSString *actor = TGPushExtraActor(actorName);

	if ([type isEqualToString:@"pushMessageContentHidden"])
		return [NSString stringWithFormat:
					TGL(@"PUSH_LOCKED_MESSAGE", @"You have a new message%1$@"), @""];

	if ([type isEqualToString:@"pushMessageContentPaidMedia"]) {
		NSInteger stars = TGPushExtraCount(content, @"star_count");
		return [NSString stringWithFormat:TGL(@"Notification.PaidPost",
									@"%@ sent you a paid post for %@"),
			actor,
			TGLPlural(@"Notification.StarsCount", stars, @"%lld Star", @"%lld Stars")];
	}

	if ([type isEqualToString:@"pushMessageContentPremiumGiftCode"]) {
		NSInteger months = TGPushExtraCount(content, @"month_count");
		return [NSString stringWithFormat:TGL(@"Notification.PremiumGift.Sent",
									@"%@ sent you a gift for %@"),
			actor, TGLPlural(@"MessageTimer.Months", months, @"%ld month", @"%ld months")];
	}

	if ([type isEqualToString:@"pushMessageContentGiveaway"])
		return [NSString stringWithFormat:
					TGL(@"Notification.GiveawayStarted",
						@"%@ just started a giveaway of Telegram Premium subscriptions for its followers."
						 "for its followers."),
			actor];

	if ([type isEqualToString:@"pushMessageContentGift"]) {
		NSInteger stars = TGPushExtraCount(content, @"star_count");
		if (stars > 0)
			return [NSString stringWithFormat:TGL(@"Notification.StarsGift.Sent",
										@"%@ sent you a gift for %@"),
				actor,
				TGLPlural(@"Notification.StarsCount", stars, @"%lld Star", @"%lld Stars")];
		return [NSString stringWithFormat:TGL(@"Notification.Gift.Sent",
									@"%@ sent you a gift"),
			actor];
	}

	if ([type isEqualToString:@"pushMessageContentUpgradedGift"]) {
		if ([content[@"is_upgrade"] boolValue])
			return [NSString stringWithFormat:TGL(@"Notification.StarsGift.Upgrade",
										@"%@ turned a gift into a unique collectible"),
				actor];
		return [NSString stringWithFormat:TGL(@"Notification.Gift.Sent",
									@"%@ sent you a gift"),
			actor];
	}

	if ([type isEqualToString:@"pushMessageContentStory"]) {
		if ([content[@"is_mention"] boolValue])
			return [NSString stringWithFormat:TGL(@"Notification.StoryMention",
										@"%@ mentioned you in a story"),
				actor];
		return [NSString stringWithFormat:TGL(@"Notification.StoryShared",
									@"%@ shared a story with you"),
			actor];
	}

	if ([type isEqualToString:@"pushMessageContentInviteVideoChatParticipants"]) {
		if ([content[@"is_current_user"] boolValue])
			return [NSString stringWithFormat:TGL(@"Notification.VideoChatInvitedYou",
										@"%@ invited you to a video chat"),
				actor];
		return [NSString stringWithFormat:TGL(@"Notification.VideoChatInvitedOthers",
									@"%@ invited participants to a video chat"),
			actor];
	}

	if ([type isEqualToString:@"pushMessageContentChatSetBackground"]) {
		if ([content[@"is_same"] boolValue])
			return [NSString stringWithFormat:TGL(@"Notification.SameWallpaper",
										@"%@ set the same wallpaper for this chat"),
				actor];
		return [NSString stringWithFormat:TGL(@"Notification.ChangedWallpaper",
									@"%@ set a new wallpaper for this chat"),
			actor];
	}

	if ([type isEqualToString:@"pushMessageContentChatSetTheme"]) {
		NSString *theme = TGPushExtraString(content, @"name");
		if (!theme.length)
			return [NSString stringWithFormat:TGL(@"Notification.DisabledTheme",
										@"%@ disabled chat theme"),
				actor];
		return [NSString stringWithFormat:TGL(@"Notification.ChangedTheme",
									@"%@ changed chat theme to %@"),
			actor, theme];
	}

	if ([type isEqualToString:@"pushMessageContentRecurringPayment"])
		return [NSString stringWithFormat:TGL(@"Notification.RecurringPayment",
									@"You were charged %@"),
			TGPushExtraString(content, @"amount")];

	if ([type isEqualToString:@"pushMessageContentSuggestProfilePhoto"])
		return TGL(@"Notification.SuggestedProfilePhoto", @"Suggested Profile Photo");

	if ([type isEqualToString:@"pushMessageContentSuggestBirthdate"])
		return TGL(@"Notification.SuggestBirthdate", @"Suggested Date of Birth");

	if ([type isEqualToString:@"pushMessageContentProximityAlertTriggered"])
		return [NSString stringWithFormat:TGL(@"Notification.ProximityReachedYou",
									@"%@ is now within %@ from you"),
			actor, TGPushExtraDistance(TGPushExtraCount(content, @"distance"))];

	if ([type isEqualToString:@"pushMessageContentChecklistTasksAdded"])
		return [NSString stringWithFormat:TGL(@"Notification.ChecklistTasksAdded",
									@"%@ added %@ to the checklist"),
			actor,
			TGLPlural(@"Notification.TodoTasks", TGPushExtraCount(content, @"task_count"),
				@"%ld task", @"%ld tasks")];

	if ([type isEqualToString:@"pushMessageContentChecklistTasksDone"])
		return [NSString stringWithFormat:TGL(@"Notification.TodoMultipleCompleted",
									@"%@ marked %@ as done."),
			actor,
			TGLPlural(@"Notification.TodoTasks", TGPushExtraCount(content, @"task_count"),
				@"%ld task", @"%ld tasks")];

	if ([type isEqualToString:@"pushMessageContentPollOptionAdded"])
		return [NSString stringWithFormat:TGL(@"Notification.PollAddedOption",
									@"%@ added the poll option \"%@\""),
			actor, TGPushExtraString(content, @"text")];

	return nil;
}

#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+Messages.h"
#import "TGMentionSuggestionStrip.h"
#import "TGQuickReplyTrigger.h"

@implementation TGChatViewController (QuickReplyAutocomplete)

- (BOOL)quickReplyAutocompleteEligible {
	return self.chatId != 0 && self.composeMode != TGComposeModeEdit;
}

- (BOOL)updateQuickReplySuggestions {
	if (![self quickReplyAutocompleteEligible]) {
		self.quickReplySuggestionsActive = NO;
		return NO;
	}
	NSString *text = self.input.text ?: @"";
	NSRange trigger = TGQuickReplyTriggerRangeInText(text, self.input.selectedRange.location);
	if (trigger.location == NSNotFound) {
		if (self.quickReplySuggestionsActive) {
			self.quickReplySuggestionsActive = NO;
			[self clearMentionSuggestions];
		}
		return NO;
	}

	NSArray *shortcuts = [[TGClient shared] quickReplyShortcuts];
	if (!shortcuts.count) {
		[[TGClient shared] loadQuickReplyShortcuts];
		return NO;
	}
	NSArray *matches = TGQuickReplyMatches(shortcuts,
		[text substringWithRange:NSMakeRange(1, trigger.length - 1)]);
	if (!matches.count) {
		if (self.quickReplySuggestionsActive) {
			self.quickReplySuggestionsActive = NO;
			[self clearMentionSuggestions];
		}
		return NO;
	}

	NSMutableArray *candidates = [NSMutableArray arrayWithCapacity:matches.count];
	for (NSDictionary *shortcut in matches)
		[candidates addObject:@{
			@"name" : shortcut[@"name"] ?: @"",
			@"username" : @"",
			@"quickReplyShortcutId" : shortcut[@"id"] ?: @(0),
		}];
	self.quickReplySuggestionsActive = YES;
	[self showMentionCandidates:candidates];
	return YES;
}

- (void)sendQuickReplyCandidate:(NSDictionary *)candidate {
	NSInteger shortcutId = [candidate[@"quickReplyShortcutId"] integerValue];
	if (shortcutId <= 0 || !self.chatId)
		return;
	self.quickReplySuggestionsActive = NO;
	[self clearMentionSuggestions];
	self.input.text = @"";
	[self inputChanged];
	[[TGClient shared] sendQuickReplyShortcut:shortcutId toChat:self.chatId completion:nil];
}

@end

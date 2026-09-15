#import "TGClient+ChatManagement.h"
#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+Groups.h"
#import "TGMentionSuggestionStrip.h"
#import "TGMentionTrigger.h"

static const NSInteger kMentionSuggestionLimit = 24;
static const NSTimeInterval kMentionSuggestionDebounce = 0.35;

@implementation TGChatViewController (MentionAutocomplete)

- (BOOL)mentionAutocompleteEligible {
	return self.group && self.chatId != 0 &&
		self.chatId != [[TGClient shared] savedMessagesChatId];
}

- (void)textViewDidChangeSelection:(UITextView *)textView {
	if (textView == self.input)
		[self updateMentionSuggestions];
}

- (void)updateMentionSuggestions {
	if ([self updateQuickReplySuggestions])
		return;

	if ([self updateInlineBotQueryTrigger])
		return;

	if (![self mentionAutocompleteEligible]) {
		[self clearMentionSuggestions];
		return;
	}

	NSString *text = self.input.text ?: @"";
	NSRange caret = self.input.selectedRange;
	NSRange trigger = TGMentionTriggerRangeInText(text, caret.location);
	if (trigger.location == NSNotFound) {
		[self clearMentionSuggestions];
		return;
	}
	if (NSEqualRanges(trigger, self.mentionTriggerRange))
		return;

	self.mentionTriggerRange = trigger;
	NSString *query = [text substringWithRange:
			NSMakeRange(trigger.location + 1, trigger.length - 1)];

	self.mentionQueryGeneration++;
	NSUInteger generation = self.mentionQueryGeneration;
	int64_t chatId = self.chatId;

	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kMentionSuggestionDebounce * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf || generation != strongSelf.mentionQueryGeneration)
				return;
			[[TGClient shared] mentionCandidatesInGroup:chatId
												  query:query
												  limit:kMentionSuggestionLimit
											 completion:^(NSArray *candidates) {
				TGChatViewController *innerSelf = weakSelf;
				if (!innerSelf || generation != innerSelf.mentionQueryGeneration)
					return;
				if (![innerSelf mentionAutocompleteEligible])
					return;
				NSRange stillTrigger = TGMentionTriggerRangeInText(
						innerSelf.input.text ?: @"", innerSelf.input.selectedRange.location);
				if (stillTrigger.location == NSNotFound ||
					!NSEqualRanges(stillTrigger, innerSelf.mentionTriggerRange))
					return;
				[innerSelf showMentionCandidates:candidates];
			}];
		});
}

- (void)showMentionCandidates:(NSArray *)candidates {
	if (!self.mentionSuggestions) {
		if (!self.inputBar)
			return;
		[self buildMentionSuggestions];
	}
	CGFloat height = [TGMentionSuggestionStrip heightForCandidateCount:candidates.count];
	CGRect frame = self.mentionSuggestions.frame;
	frame.size.height = height;
	self.mentionSuggestions.frame = frame;
	[self.mentionSuggestions showCandidates:candidates];
	[self layoutChatStackAnimated:NO duration:0 curve:UIViewAnimationCurveEaseInOut];
}

- (void)buildMentionSuggestions {
	CGRect b = self.view.bounds;
	CGFloat height = [TGMentionSuggestionStrip heightForCandidateCount:1];
	TGMentionSuggestionStrip *strip = [[TGMentionSuggestionStrip alloc]
		initWithFrame:CGRectMake(0, CGRectGetMinY(self.inputBar.frame) - height,
						  b.size.width, height)];
	strip.autoresizingMask = UIViewAutoresizingFlexibleWidth |
		UIViewAutoresizingFlexibleTopMargin;

	__weak typeof(self) weakSelf = self;
	strip.onCandidatePicked = ^(NSDictionary *candidate) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (strongSelf.quickReplySuggestionsActive) {
			[strongSelf sendQuickReplyCandidate:candidate];
			return;
		}
		[strongSelf insertMentionCandidate:candidate];
	};
	strip.onVisibilityChanged = ^(__unused BOOL visible) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf layoutChatStackAnimated:NO duration:0 curve:UIViewAnimationCurveEaseInOut];
	};

	[self.view addSubview:strip];
	self.mentionSuggestions = strip;
}

- (void)clearMentionSuggestions {
	self.mentionTriggerRange = NSMakeRange(NSNotFound, 0);
	self.mentionQueryGeneration++;
	if (self.mentionSuggestions)
		[self.mentionSuggestions clear];
}

- (void)insertMentionCandidate:(NSDictionary *)candidate {
	NSRange trigger = self.mentionTriggerRange;
	NSString *text = self.input.text ?: @"";
	if (trigger.location == NSNotFound || NSMaxRange(trigger) > text.length) {
		[self clearMentionSuggestions];
		return;
	}

	NSString *username = [candidate[@"username"] isKindOfClass:NSString.class]
		? candidate[@"username"]
		: nil;
	NSString *name = [candidate[@"name"] isKindOfClass:NSString.class]
		? candidate[@"name"]
		: nil;
	int64_t userId = [candidate[@"id"] longLongValue];

	NSString *replacement = nil;
	NSString *mentionText = nil;
	if (username.length) {
		replacement = [NSString stringWithFormat:@"@%@ ", username];
	} else if (name.length && userId != 0) {
		mentionText = name;
		replacement = [name stringByAppendingString:@" "];
	}

	if (!replacement.length) {
		[self clearMentionSuggestions];
		return;
	}

	NSInteger insertionStart = trigger.location;
	NSString *replaced = [text stringByReplacingCharactersInRange:trigger withString:replacement];

	[self adjustPendingCustomEmojiForRange:trigger replacementLength:(NSInteger)replacement.length];
	[self adjustPendingMentionRunsForRange:trigger replacementLength:(NSInteger)replacement.length];

	if (mentionText.length) {
		[self.pendingMentionRuns addObject:@{
			@"range" : [NSValue valueWithRange:NSMakeRange(insertionStart, mentionText.length)],
			@"userId" : @(userId),
			@"text" : mentionText,
		}];
	}

	self.input.text = replaced;
	self.input.selectedRange = NSMakeRange(insertionStart + replacement.length, 0);
	[self clearMentionSuggestions];
	[self inputChanged];
}

@end

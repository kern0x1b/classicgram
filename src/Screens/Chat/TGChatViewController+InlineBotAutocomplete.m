#import "TGChatViewController.h"
#import "TGFriendlyError.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+Bots.h"
#import "TGClient+Contacts.h"
#import "TGClient+DirectMessages.h"
#import "TGClient+Gifs.h"
#import "TGLocalization.h"
#import "TGInlineQueryResultStrip.h"
#import "TGMentionTrigger.h"

static const NSTimeInterval kInlineBotQueryDebounce = 0.35;

@implementation TGChatViewController (InlineBotAutocomplete)

- (int64_t)cachedInlineBotIdForUsername:(NSString *)username {
	if (!username.length)
		return 0;
	for (NSDictionary *bot in self.recentInlineBotList) {
		NSString *botUsername = bot[@"username"];
		if ([botUsername isKindOfClass:NSString.class] &&
			[botUsername caseInsensitiveCompare:username] == NSOrderedSame)
			return [bot[@"id"] longLongValue];
	}
	return 0;
}

- (BOOL)updateInlineBotQueryTrigger {
	NSString *text = self.input.text ?: @"";
	NSRange usernameRange = TGInlineBotUsernameRangeInText(text);
	if (usernameRange.location == NSNotFound) {
		[self clearInlineBotQuery];
		return NO;
	}

	NSString *username = [text substringWithRange:usernameRange];
	NSRange caret = self.input.selectedRange;
	NSRange queryRange = TGInlineBotQueryRangeInText(text, caret.location);
	int64_t botId = [self cachedInlineBotIdForUsername:username];

	if (!botId) {
		[self clearInlineBotQuery];
		if (queryRange.location != NSNotFound)
			[self resolveInlineBotUsername:username];
		return NO;
	}

	if (queryRange.location == NSNotFound) {
		[self clearInlineBotQuery];
		return NO;
	}

	[self clearMentionSuggestions];

	NSString *query = [text substringWithRange:queryRange];
	if ([self.inlineQueryActiveUsername isEqualToString:username] &&
		[self.inlineQueryActiveQuery isEqualToString:query])
		return YES;

	self.inlineQueryActiveUsername = username;
	self.inlineQueryActiveQuery = query;
	self.inlineQueryBotId = botId;
	[self scheduleInlineQueryForBot:botId query:query];
	return YES;
}

- (void)resolveInlineBotUsername:(NSString *)username {
	if (!username.length)
		return;
	NSString *key = username.lowercaseString;
	if (!self.inlineQueryUnresolvedUsernames)
		self.inlineQueryUnresolvedUsernames = [NSMutableSet set];
	if ([self.inlineQueryUnresolvedUsernames containsObject:key])
		return;
	if ([self.inlineQueryResolvingUsername isEqualToString:username])
		return;

	self.inlineQueryResolvingUsername = username;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] userIdForUsername:username completion:^(int64_t userId, BOOL failed) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!userId) {
			if ([strongSelf.inlineQueryResolvingUsername isEqualToString:username])
				strongSelf.inlineQueryResolvingUsername = nil;
			[strongSelf.inlineQueryUnresolvedUsernames addObject:key];
			return;
		}

		[[TGClient shared] businessBotEligibilityForUserId:userId
												  completion:^(BOOL isBot, BOOL canConnectToBusiness) {
			TGChatViewController *innerSelf = weakSelf;
			if (!innerSelf)
				return;
			if ([innerSelf.inlineQueryResolvingUsername isEqualToString:username])
				innerSelf.inlineQueryResolvingUsername = nil;
			if (!isBot) {
				[innerSelf.inlineQueryUnresolvedUsernames addObject:key];
				return;
			}

			NSMutableArray *cache = [(innerSelf.recentInlineBotList ?: @[]) mutableCopy];
			[cache addObject:@{ @"id" : @(userId), @"username" : username }];
			innerSelf.recentInlineBotList = cache;

			[innerSelf updateMentionSuggestions];
		}];
	}];
}

- (void)scheduleInlineQueryForBot:(int64_t)botId query:(NSString *)query {
	NSInteger generation = ++self.inlineQueryGeneration;
	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kInlineBotQueryDebounce * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf || generation != strongSelf.inlineQueryGeneration)
				return;
			[strongSelf runInlineQueryForBot:botId query:query offset:nil];
		});
}

- (void)showInlineQueryResults:(NSArray *)results buttonText:(NSString *)buttonText {
	if (!results.count && !buttonText.length) {
		[self clearInlineBotQuery];
		return;
	}
	if (!self.inlineQueryStrip) {
		if (!self.inputBar)
			return;
		[self buildInlineQueryStrip];
	}
	NSUInteger rowCount = results.count + (buttonText.length ? 1 : 0);
	CGFloat height = [TGInlineQueryResultStrip heightForResultCount:rowCount];
	CGRect frame = self.inlineQueryStrip.frame;
	frame.size.height = height;
	self.inlineQueryStrip.frame = frame;
	[self.inlineQueryStrip setButtonText:buttonText];
	[self.inlineQueryStrip showResults:results];
	[self layoutChatStackAnimated:NO duration:0 curve:UIViewAnimationCurveEaseInOut];
}

- (void)appendInlineQueryResults:(NSArray *)results {
	if (!self.inlineQueryStrip)
		return;
	[self.inlineQueryStrip appendResults:results];
}

- (void)loadMoreInlineQueryResults {
	if (self.inlineQueryLoadingMore)
		return;
	NSString *nextOffset = self.inlineQueryNextOffset;
	int64_t botId = self.inlineQueryBotId;
	if (!nextOffset.length || !botId)
		return;
	[self runInlineQueryForBot:botId query:self.inlineQueryActiveQuery offset:nextOffset];
}

- (void)buildInlineQueryStrip {
	CGRect b = self.view.bounds;
	CGFloat height = [TGInlineQueryResultStrip heightForResultCount:1];
	TGInlineQueryResultStrip *strip = [[TGInlineQueryResultStrip alloc]
		initWithFrame:CGRectMake(0, CGRectGetMinY(self.inputBar.frame) - height,
						  b.size.width, height)];
	strip.autoresizingMask = UIViewAutoresizingFlexibleWidth |
		UIViewAutoresizingFlexibleTopMargin;

	__weak typeof(self) weakSelf = self;
	strip.onResultPicked = ^(NSDictionary *result) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf sendInlineQueryResult:result];
	};
	strip.onVisibilityChanged = ^(__unused BOOL visible) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf layoutChatStackAnimated:NO duration:0 curve:UIViewAnimationCurveEaseInOut];
	};
	strip.onButtonPicked = ^{
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf || !strongSelf.inlineQueryBotId)
			return;
		[[TGClient shared] startBot:strongSelf.inlineQueryBotId
							  inChat:strongSelf.chatId
						   parameter:strongSelf.inlineQueryButtonParameter
						  completion:^(BOOL ok, NSString *errorMessage) {
							  TGChatViewController *innerSelf = weakSelf;
							  if (!innerSelf || ok)
								  return;
							  [innerSelf showAlertTitle:@"" message:TGFriendlyErrorText(errorMessage, TGL(@"Login.UnknownError", @"An error occurred, please try again later."))];
						  }];
		[strongSelf clearInlineBotQuery];
	};
	strip.onNeedsMoreResults = ^{
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf loadMoreInlineQueryResults];
	};

	[self.view addSubview:strip];
	self.inlineQueryStrip = strip;
}

- (void)sendInlineQueryResult:(NSDictionary *)result {
	if ([result[@"kind"] isEqualToString:@"animation"]) {
		long long fileId = [result[@"fileId"] longLongValue];
		if (fileId != 0)
			[[TGClient shared] saveGifWithFileId:fileId completion:nil];
	}
	[[TGClient shared] sendInlineResult:result[@"id"]
								queryId:self.inlineQueryId
								 toChat:self.chatId
								 thread:self.threadId
					directMessagesTopic:self.directMessagesTopicId
							 savedTopic:self.savedTopicId
								replyTo:self.replyToId
								hideVia:NO];
	[self clearComposeState];
	self.input.text = @"";
	[self inputChanged];
	[self clearInlineBotQuery];
	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{ [weakSelf reload]; });
}

- (void)clearInlineBotQuery {
	self.inlineQueryGeneration++;
	self.inlineQueryActiveUsername = nil;
	self.inlineQueryActiveQuery = nil;
	self.inlineQueryBotId = 0;
	self.inlineQueryNextOffset = nil;
	self.inlineQueryButtonParameter = nil;
	self.inlineQueryLoadingMore = NO;
	if (self.inlineQueryStrip)
		[self.inlineQueryStrip clear];
}

@end

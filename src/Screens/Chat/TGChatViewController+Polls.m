#import "TGClient+Messages.h"
#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+MessageContent.h"
#import "TGAlertView.h"
#import "TGLocalization.h"
#import "TGPollComposerViewController.h"
#import "TGSnackbar.h"
#import "TGTheme.h"

@implementation TGChatViewController (Polls)

- (void)showPollComposer {
	if (self.postingBlocked)
		return;
	if (self.composerState && !self.composerState.canSendPolls)
		return;

	TGPollComposerViewController *composer = [[TGPollComposerViewController alloc] init];
	__weak typeof(self) weakSelf = self;
	composer.onSend = ^(NSString *question, NSArray *options, BOOL anonymous,
		BOOL multipleAnswers, NSInteger correctOption,
		NSString *explanation, void (^completion)(BOOL success)) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf) {
			if (completion)
				completion(NO);
			return;
		}
		[strongSelf sendComposedPollQuestion:question
							 options:options
						   anonymous:anonymous
					 multipleAnswers:multipleAnswers
				   quizCorrectOption:correctOption
					 quizExplanation:explanation
						  completion:completion];
	};
	UINavigationController *nav =
		[[UINavigationController alloc] initWithRootViewController:composer];
	if (TGChatIsPad())
		nav.modalPresentationStyle = UIModalPresentationFormSheet;
	[self presentModalViewController:nav animated:YES];
}

- (void)sendComposedPollQuestion:(NSString *)question
						 options:(NSArray *)options
					   anonymous:(BOOL)anonymous
				 multipleAnswers:(BOOL)multipleAnswers
			   quizCorrectOption:(NSInteger)quizCorrectOption
				 quizExplanation:(NSString *)quizExplanation
					  completion:(void (^)(BOOL success))completion {
	if (self.postingBlocked) {
		if (completion)
			completion(NO);
		return;
	}
	if ([self blockSendForSlowMode]) {
		if (completion)
			completion(NO);
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] sendPollWithQuestion:question
									options:options
								  anonymous:anonymous
							multipleAnswers:multipleAnswers
						  quizCorrectOption:quizCorrectOption
							quizExplanation:quizExplanation
									 toChat:self.chatId
									 thread:self.threadId
						directMessagesTopic:self.directMessagesTopicId
								 savedTopic:self.savedTopicId
									replyTo:self.replyToId
								sendOptions:[self sendOptionsDictionary]
								 completion:^(int64_t messageId) {
									 TGChatViewController *strongSelf = weakSelf;
									 if (!strongSelf) {
										 if (completion)
											 completion(messageId != 0);
										 return;
									 }
									 if (!messageId) {
										 [TGSnackbar showInView:strongSelf.view
															text:TGL(@"Toast.CouldNotSendPoll", @"Could not send the poll")
														 seconds:3
														onCommit:nil];
										 if (completion)
											 completion(NO);
										 return;
									 }
									 [strongSelf clearComposeState];
									 [strongSelf reload];
									 if (completion)
										 completion(YES);
								 }];
}

- (NSString *)bubbleCell:(TGMessageRowCell *)__unused cell
	pollOptionTitleAtIndex:(NSUInteger)index
					 atRow:(NSInteger)row {
	NSDictionary *m = [self messageAtRow:row];
	NSArray *options = m[@"pollOptions"];
	if (index >= options.count)
		return @"";
	id optionText = options[index][@"text"];
	if ([optionText isKindOfClass:NSDictionary.class])
		optionText = optionText[@"text"];
	return [optionText isKindOfClass:NSString.class] ? optionText : @"";
}

- (CGFloat)bubbleCell:(TGMessageRowCell *)__unused cell
	pollOptionFractionAtIndex:(NSUInteger)index
						atRow:(NSInteger)row {
	NSDictionary *m = [self messageAtRow:row];
	NSArray *options = m[@"pollOptions"];
	if (index >= options.count)
		return 0;
	return [options[index][@"vote_percentage"] integerValue] / 100.0f;
}

- (NSInteger)bubbleCell:(TGMessageRowCell *)__unused cell
	pollOptionPercentValueAtIndex:(NSUInteger)index
							atRow:(NSInteger)row {
	NSDictionary *m = [self messageAtRow:row];
	NSArray *options = m[@"pollOptions"];
	if (index >= options.count)
		return 0;
	return [options[index][@"vote_percentage"] integerValue];
}

- (BOOL)bubbleCell:(TGMessageRowCell *)__unused cell
	pollOptionIsChosenAtIndex:(NSUInteger)index
						atRow:(NSInteger)row {
	NSDictionary *m = [self messageAtRow:row];
	NSArray *options = m[@"pollOptions"];
	if (index >= options.count)
		return NO;
	int64_t messageId = [m[@"id"] longLongValue];
	NSMutableSet *pendingSelection = messageId ? self.pollPendingSelections[@(messageId)] : nil;
	if (pendingSelection)
		return [pendingSelection containsObject:@(index)];
	return [options[index][@"is_chosen"] boolValue];
}

- (NSString *)pollSubtitleFor:(NSDictionary *)m {
	BOOL closed = [m[@"pollClosed"] boolValue];
	NSInteger total = [m[@"pollTotal"] integerValue];
	NSString *count = total == 0
		? (closed ? TGL(@"Chat.Poll.NoVotes", @"No votes") : TGL(@"Chat.Poll.NoVotesYet", @"No votes yet"))
		: TGLPlural(@"Chat.Poll.VotedCount", total, @"%ld voted", @"%ld voted");
	if (closed)
		return [NSString stringWithFormat:TGL(@"Chat.Poll.FinalResults", @"Final results  ·  %@"), count];
	NSString *kind = [m[@"pollAnonymous"] boolValue] ? TGL(@"Chat.Poll.Anonymous", @"Anonymous Poll") : TGL(@"Chat.Poll.Public", @"Public Poll");
	return [NSString stringWithFormat:@"%@  ·  %@", kind, count];
}

- (void)bubbleCell:(TGMessageRowCell *)__unused cell
	didTapPollOptionAtIndex:(NSUInteger)index
					  atRow:(NSInteger)row {
	NSDictionary *m = [self messageAtRow:row];
	if ([m[@"pollClosed"] boolValue])
		return;
	int64_t messageId = [m[@"id"] longLongValue];
	if (!messageId)
		return;
	NSArray *options = m[@"pollOptions"];
	if (index >= options.count)
		return;

	NSNumber *messageKey = @(messageId);
	if ([self.pollVotesInFlight containsObject:messageKey]) {
		[TGSnackbar showInView:self.view
						   text:TGL(@"Toast.PollVoteInProgress", @"Your vote is still being submitted")
						seconds:2
					   onCommit:nil];
		return;
	}

	BOOL isQuiz = [m[@"pollIsQuiz"] boolValue];
	BOOL allowsRevoting = [m[@"pollAllowsRevoting"] boolValue];
	BOOL alreadyAnswered = NO;
	for (NSDictionary *option in options) {
		if ([option[@"is_chosen"] boolValue]) {
			alreadyAnswered = YES;
			break;
		}
	}
	if ((isQuiz || !allowsRevoting) && alreadyAnswered)
		return;

	NSArray *voteOptions;
	if ([m[@"pollAllowsMultipleAnswers"] boolValue]) {
		NSMutableSet *selected = self.pollPendingSelections[messageKey];
		if (!selected) {
			selected = [NSMutableSet set];
			for (NSUInteger i = 0; i < options.count; i++) {
				if ([options[i][@"is_chosen"] boolValue])
					[selected addObject:@(i)];
			}
		}
		if ([selected containsObject:@(index)])
			[selected removeObject:@(index)];
		else
			[selected addObject:@(index)];
		self.pollPendingSelections[messageKey] = selected;
		voteOptions = [selected.allObjects sortedArrayUsingSelector:@selector(compare:)];
	} else {
		voteOptions = @[ @(index) ];
	}

	[self tg_castPollVote:voteOptions forMessageId:messageId];
}

- (void)retractPollVoteForRow:(NSInteger)row {
	NSDictionary *m = [self messageAtRow:row];
	int64_t messageId = [m[@"id"] longLongValue];
	if (!messageId)
		return;
	NSNumber *messageKey = @(messageId);
	if ([self.pollVotesInFlight containsObject:messageKey])
		return;

	[self.pollPendingSelections removeObjectForKey:messageKey];
	[self tg_castPollVote:@[] forMessageId:messageId];
}

- (void)tg_castPollVote:(NSArray *)voteOptions forMessageId:(int64_t)messageId {
	NSNumber *messageKey = @(messageId);
	[self.pollVotesInFlight addObject:messageKey];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] votePoll:messageId
						  inChat:self.chatId
						 options:voteOptions
					  completion:^(BOOL ok) {
						  TGChatViewController *strongSelf = weakSelf;
						  if (!strongSelf)
							  return;
						  [strongSelf.pollVotesInFlight removeObject:messageKey];
						  [strongSelf.pollPendingSelections removeObjectForKey:messageKey];
						  if (!ok) {
							  [TGSnackbar showInView:strongSelf.view
												 text:TGL(@"Toast.CouldNotVotePoll", @"Could not submit your vote")
											  seconds:3
											 onCommit:nil];
						  }
						  [strongSelf tg_invalidateLayoutForMessageId:messageId];
						  [strongSelf.table reloadData];
					  }];
	[self tg_invalidateLayoutForMessageId:messageId];
	[self.table reloadData];
}

- (void)promptAddPollOptionForRow:(NSInteger)row {
	NSDictionary *m = [self messageAtRow:row];
	int64_t messageId = [m[@"id"] longLongValue];
	if (!messageId)
		return;

	self.pollAddMessageId = messageId;
	UIAlertView *ask = [[TGAlertView alloc]
			initWithTitle:TGL(@"CreatePoll.AddOption", @"Add an Option")
				  message:nil
				 delegate:self
		cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
		otherButtonTitles:TGL(@"Common.OK", @"OK"), nil];
	if ([ask respondsToSelector:@selector(setAlertViewStyle:)])
		ask.alertViewStyle = UIAlertViewStylePlainTextInput;
	ask.tag = kPollAddOptionAlertTag;
	[ask show];
}

- (void)handlePollAddOptionAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex {
	int64_t messageId = self.pollAddMessageId;
	self.pollAddMessageId = 0;
	if (buttonIndex == alertView.cancelButtonIndex || !messageId)
		return;
	NSString *text = [self textInAlert:alertView];
	if (!text.length)
		return;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] addPollOptionText:text
								inMessage:messageId
									 chat:self.chatId
							   completion:^(BOOL ok) {
								   TGChatViewController *strongSelf = weakSelf;
								   if (!strongSelf)
									   return;
								   if (!ok) {
									   [TGSnackbar showInView:strongSelf.view
														  text:TGL(@"Toast.CouldNotAddPollOption", @"Could not add the option")
													   seconds:3
													  onCommit:nil];
									   return;
								   }
								   [strongSelf reload];
							   }];
}

@end

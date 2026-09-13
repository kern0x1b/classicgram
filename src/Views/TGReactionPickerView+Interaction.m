#import "TGReactionPickerView.h"
#import "TGReactionPickerViewInternal.h"

#import "TGReactionService.h"
#import "TGSnackbar.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGActionSheet.h"
#import "TGLocalization.h"

@implementation TGReactionPickerView (Interaction)

#pragma mark interaction

- (void)emojiTapped:(TGReactionStripButton *)button {
	if (_dismissed)
		return;

	NSString *emoji = button.emoji;
	if (emoji.length == 0)
		return;

	if (button.paid) {
		[self showPaidSheet];
		return;
	}

	TGReactionPickedBlock picked = self.onReactionPicked;

	if (sOpenPicker == self)
		sOpenPicker = nil;
	[self teardownAnimated:YES];

	if (self.chatId == 0 || self.messageId == 0) {
		if (picked != nil)
			picked(emoji, YES);
		return;
	}

	UIView *host = self.window ? (UIView *)self.window : nil;
	[TGReactionService toggleReaction:emoji
							onMessage:self.messageId
							   inChat:self.chatId
								  big:NO
						   completion:^(BOOL nowChosen, BOOL succeeded) {
							   if (!succeeded) {
								   if (host)
									   [TGSnackbar showInView:host
														  text:TGL(@"Toast.CouldNotUpdateReaction", @"Could not update the reaction")
													   seconds:2
													  onCommit:nil];
								   return;
							   }
							   if (picked != nil)
								   picked(emoji, nowChosen);
						   }];
}

- (void)longPressedReactionButton:(UILongPressGestureRecognizer *)recognizer {
	if (recognizer.state != UIGestureRecognizerStateBegan)
		return;
	if (_dismissed)
		return;

	TGReactionStripButton *button = (TGReactionStripButton *)recognizer.view;
	NSString *emoji = button.emoji;
	if (emoji.length == 0 || button.paid)
		return;

	UIView *host = self.window ? (UIView *)self.window : nil;
	[TGReactionService setQuickReactionEmoji:emoji
								  completion:^(BOOL ok) {
		if (!host)
			return;
		if (!ok) {
			[TGSnackbar showInView:host
							   text:TGL(@"Toast.CouldNotSetQuickReaction", @"Could not set your quick reaction")
							seconds:2
						   onCommit:nil];
			return;
		}
		[TGSnackbar showInView:host
						   text:[NSString stringWithFormat:
									TGL(@"ReactionPicker.QuickReactionSet", @"%@ is now your quick reaction"),
									emoji]
						seconds:2
					   onCommit:nil];
	}];
}

- (void)showPaidSheet {
	if (_dismissed || _starBalance <= 0 || _paidSheetPresented)
		return;

	NSMutableArray *actions = [[NSMutableArray alloc] init];
	long long amounts[3] = {1, 10, 50};
	for (NSInteger i = 0; i < 3; i++) {
		long long amount = amounts[i];
		if (amount > _starBalance)
			continue;
		NSString *title = TGLPlural(@"SendStarReactions.SendButtonTitle", (NSInteger)amount, @"Send %@ Star", @"Send %@ Stars");
		[actions addObject:[[TGActionSheetAction alloc]
							   initWithTitle:title
									  action:[NSString stringWithFormat:@"send%d", (int)amount]]];
	}
	if (actions.count == 0)
		return;

	[actions addObject:[[TGActionSheetAction alloc]
						   initWithTitle:(_paidAnonymous ? TGL(@"ReactionPicker.ShowMyName", @"Show My Name") : TGL(@"Conversation.InputTextAnonymousPlaceholder", @"Send Anonymously"))
								  action:@"anonymous"]];
	[actions addObject:[[TGActionSheetAction alloc]
						   initWithTitle:TGL(@"Common.Cancel", @"Cancel")
								  action:@"cancel"
									type:TGActionSheetActionTypeCancel]];

	NSString *title = [NSString stringWithFormat:
			  TGL(@"ReactionPicker.YourStarBalance", @"Your Balance: %d Stars"),
		(int)_starBalance];
	_paidSheetPresented = YES;
	__weak TGReactionPickerView *weakSelf = self;
	void (^actionBlock)(id, NSString *) = ^(id target, NSString *action) {
		TGReactionPickerView *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		[strongSelf handlePaidAction:action];
	};
	TGActionSheet *sheet = [[TGActionSheet alloc] initWithTitle:title actions:actions actionBlock:actionBlock target:self];
	UIView *sheetHost = (self.window != nil) ? (UIView *)self.window : (UIView *)self;
	[sheet tg_showFromRect:sheetHost.bounds inView:sheetHost];
}

- (void)handlePaidAction:(NSString *)action {
	_paidSheetPresented = NO;
	if ([action isEqualToString:@"anonymous"]) {
		_paidAnonymous = !_paidAnonymous;
		[self showPaidSheet];
		return;
	}
	if (![action hasPrefix:@"send"])
		return;
	long long stars = [[action substringFromIndex:4] longLongValue];
	if (stars <= 0)
		return;
	[self sendPaidStars:stars];
}

- (void)sendPaidStars:(long long)stars {
	int64_t chatId = self.chatId;
	int64_t messageId = self.messageId;
	BOOL anonymous = _paidAnonymous;
	UIView *host = self.superview;

	if (sOpenPicker == self)
		sOpenPicker = nil;
	[self teardownAnimated:YES];

	if (chatId == 0 || messageId == 0)
		return;

	void (^send)(void) = ^{
		[TGReactionService addPaidReactionToMessage:messageId
											 inChat:chatId
										  starCount:stars
										  anonymous:anonymous
										 completion:^(BOOL addOk) {
											 if (!addOk) {
												 if (host)
													 [TGSnackbar showInView:host
																	   text:TGL(@"Toast.CouldNotSendPaidReaction", @"Could not send the Stars reaction")
																	seconds:2
																   onCommit:nil];
												 return;
											 }
											 [TGReactionService commitPaidReactionsOnMessage:messageId
																					  inChat:chatId
																				  completion:^(BOOL commitOk) {
																					  if (commitOk)
																						  return;
																					  [TGReactionService cancelPaidReactionsOnMessage:messageId inChat:chatId];
																					  if (host)
																						  [TGSnackbar showInView:host
																											text:TGL(@"Toast.CouldNotSendPaidReaction", @"Could not send the Stars reaction")
																										 seconds:2
																										onCommit:nil];
																				  }];
										 }];
	};

	if (host == nil) {
		send();
		return;
	}

	NSString *text = (stars == 1)
		? TGL(@"Stars.Sending1Star", @"Sending 1 Star")
		: [NSString stringWithFormat:TGL(@"Stars.SendingStarsCount", @"Sending %d Stars"), (int)stars];
	[TGSnackbar showInView:host text:text seconds:kPaidUndoSeconds onCommit:send];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	[super touchesEnded:touches withEvent:event];
	CGPoint point = [[touches anyObject] locationInView:self];
	if (!CGRectContainsPoint(_card.frame, point)) {
		if (sOpenPicker == self)
			sOpenPicker = nil;
		[self teardownAnimated:YES];
	}
}

- (void)externalDismiss {
	if (sOpenPicker == self)
		sOpenPicker = nil;
	[self teardownAnimated:YES];
}

- (void)teardownAnimated:(BOOL)animated {
	if (_dismissed)
		return;
	_dismissed = YES;
	_paidPending = NO;
	_paidSheetPresented = NO;
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(paidLookupTimedOut)
											   object:nil];
	self.onReactionPicked = nil;
	sLastHideTime = [NSDate timeIntervalSinceReferenceDate];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (_backgroundDismissObserverToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:_backgroundDismissObserverToken];
		_backgroundDismissObserverToken = nil;
	}
	if (_orientationDismissObserverToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:_orientationDismissObserverToken];
		_orientationDismissObserverToken = nil;
	}
	[_spinner stopAnimating];

	self.userInteractionEnabled = NO;

	if (!animated) {
		[self removeFromSuperview];
		return;
	}

	UIView *card = _card;
	[UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState
		animations:^{
			card.alpha = 0.0f;
		} completion:^(BOOL finished) {
			card.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
			[self removeFromSuperview];
		}];
}

- (void)present {
	_card.alpha = 1.0f;
	_card.transform = CGAffineTransformMakeScale(0.1f, 0.1f);

	if ([_card.layer respondsToSelector:@selector(setRasterizationScale:)])
		_card.layer.rasterizationScale = [[UIScreen mainScreen] scale];
	_card.layer.shouldRasterize = YES;

	UIView *card = _card;
	[UIView animateWithDuration:0.142 delay:0
		options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
		animations:^{
			card.transform = CGAffineTransformMakeScale(1.07f, 1.07f);
		} completion:^(BOOL finished) {
			[UIView animateWithDuration:0.08 delay:0
				options:UIViewAnimationOptionBeginFromCurrentState
				animations:^{
					card.transform = CGAffineTransformMakeScale(0.967f, 0.967f);
				} completion:^(BOOL finished2) {
					[UIView animateWithDuration:0.06 delay:0
						options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
						animations:^{
							card.transform = CGAffineTransformIdentity;
						} completion:^(BOOL finished3) {
							card.layer.shouldRasterize = NO;
						}];
				}];
		}];
}

@end

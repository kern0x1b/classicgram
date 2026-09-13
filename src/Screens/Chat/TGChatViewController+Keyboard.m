#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGStickerPanelView.h"
#import "TGStickerSuggestionStrip.h"
#import "TGMentionSuggestionStrip.h"
#import "TGInlineQueryResultStrip.h"

@implementation TGChatViewController (Keyboard)

- (void)adoptKeyboardTiming:(NSNotification *)note {
	NSNumber *duration = note.userInfo[UIKeyboardAnimationDurationUserInfoKey];
	NSNumber *curve = note.userInfo[UIKeyboardAnimationCurveUserInfoKey];
	self.keyboardDuration = duration ? duration.doubleValue : 0.25;
	self.keyboardCurve = curve ? (UIViewAnimationCurve)curve.integerValue
							   : UIViewAnimationCurveEaseInOut;
}

- (void)keyboardWillShow:(NSNotification *)note {
	CGRect kb = [[note.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
	CGRect viewBounds = self.view.bounds;
	[TGStickerPanelView noteSystemKeyboardHeight:MIN(kb.size.width, kb.size.height)
									   landscape:(viewBounds.size.width > viewBounds.size.height)];

	if (self.stickerPanel && !self.stickerPanelSearching) {
		[self.stickerPanel removeFromSuperview];
		self.stickerPanel = nil;
	}
	self.keyboardOnScreen = YES;
	[self adoptKeyboardTiming:note];
	[self shiftForKeyboardHeight:kb.size.height];
}

- (void)keyboardWillHide:(NSNotification *)note {
	self.keyboardOnScreen = NO;
	[self adoptKeyboardTiming:note];

	[self shiftForKeyboardHeight:[self stickerPanelDockHeight]];
}

- (void)keyboardWillChangeFrame:(NSNotification *)note {
	if (!self.keyboardOnScreen)
		return;

	CGRect kb = [[note.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
	CGRect viewBounds = self.view.bounds;
	[TGStickerPanelView noteSystemKeyboardHeight:MIN(kb.size.width, kb.size.height)
									   landscape:(viewBounds.size.width > viewBounds.size.height)];
	[self adoptKeyboardTiming:note];
	[self shiftForKeyboardHeight:kb.size.height];
}

- (CGFloat)stickerPanelDockHeight {
	if (!self.stickerPanel)
		return 0;
	CGRect b = self.view.bounds;
	return [TGStickerPanelView preferredHeightForLandscape:
			(b.size.width > b.size.height)];
}

- (void)shiftForKeyboardHeight:(CGFloat)height {
	self.keyboardInset = height;

	if (self.input && self.composerLineHeight > 0)
		self.composerTextHeight =
			[self composerTextHeightForContent:self.input.contentSize.height];
	[self layoutChatStackAnimated:YES
						 duration:(self.keyboardDuration > 0 ? self.keyboardDuration : 0.25)
							curve:self.keyboardCurve];
}

- (void)layoutChatStackAnimated:(BOOL)animated
					   duration:(NSTimeInterval)duration
						  curve:(UIViewAnimationCurve)curve {
	CGRect b = self.view.bounds;
	CGFloat height = self.keyboardInset;
	CGFloat barHeight = [self inputBarHeight];
	BOOL wasAtBottom = [self historyIsAtBottom];

	void (^place)(void) = ^{
		self.inputBar.frame = CGRectMake(0, b.size.height - barHeight - height,
			b.size.width, barHeight);
		self.table.frame = CGRectMake(0, 0, b.size.width,
			b.size.height - barHeight - height);
		[self layoutComposerSubviews];
		CGFloat top = CGRectGetMinY(self.inputBar.frame);
		CGFloat stackTop = top;
		if (self.actionBarView && !self.actionBarView.hidden) {
			CGRect actionBar = self.actionBarView.frame;
			actionBar.origin.y = stackTop - actionBar.size.height;
			self.actionBarView.frame = actionBar;
			stackTop = actionBar.origin.y;
		}
		if (self.composeBanner && !self.composeBanner.hidden) {
			CGRect banner = self.composeBanner.frame;
			banner.origin.y = stackTop - banner.size.height;
			self.composeBanner.frame = banner;
			stackTop = banner.origin.y;
		}
		if (self.stickerSuggestions && !self.stickerSuggestions.hidden) {
			CGRect strip = self.stickerSuggestions.frame;
			strip.origin.y = stackTop - strip.size.height;
			strip.size.width = b.size.width;
			self.stickerSuggestions.frame = strip;
			[self.view bringSubviewToFront:self.stickerSuggestions];
			stackTop = strip.origin.y;
		}
		if (self.mentionSuggestions && !self.mentionSuggestions.hidden) {
			CGRect strip = self.mentionSuggestions.frame;
			strip.origin.y = stackTop - strip.size.height;
			strip.size.width = b.size.width;
			self.mentionSuggestions.frame = strip;
			[self.view bringSubviewToFront:self.mentionSuggestions];
			stackTop = strip.origin.y;
		}
		if (self.inlineQueryStrip && !self.inlineQueryStrip.hidden) {
			CGRect strip = self.inlineQueryStrip.frame;
			strip.origin.y = stackTop - strip.size.height;
			strip.size.width = b.size.width;
			self.inlineQueryStrip.frame = strip;
			[self.view bringSubviewToFront:self.inlineQueryStrip];
		}
		if (self.stickerPanel) {
			CGFloat dock = [self stickerPanelDockHeight];
			self.stickerPanel.frame = (self.stickerPanelSearching && self.keyboardOnScreen)
				? CGRectMake(0, 0, b.size.width, b.size.height - height)
				: CGRectMake(0, top + barHeight, b.size.width, dock);
		}
		[self layoutFloatingButtons];
		[self centreEmptyPlate];
		if (self.selectionPanel) {
			CGRect panel = self.selectionPanel.frame;
			panel.origin.y = CGRectGetMaxY(self.inputBar.frame) - panel.size.height;
			self.selectionPanel.frame = panel;
		}
		if (self.recordPanel.superview) {
			CGRect strip = self.recordPanel.frame;
			strip.origin.y = CGRectGetMaxY(self.inputBar.frame) - strip.size.height;
			self.recordPanel.frame = strip;
		}
	};
	void (^settle)(BOOL) = ^(BOOL done) {
		if (wasAtBottom)
			[self scrollToBottomAnimated:NO];
		[self updateScrollDownButton];
	};

	if (!animated) {
		place();
		settle(YES);
		return;
	}
	[UIView animateWithDuration:duration delay:0.0
						options:((UIViewAnimationOptions)(curve << 16) |
									UIViewAnimationOptionBeginFromCurrentState)
					 animations:place
					 completion:settle];
}

@end

#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGEmoji.h"

@implementation TGChatViewController (ComposeBanner)

- (TGComposeMode)composeMode {
	if (self.editingId != 0)
		return TGComposeModeEdit;
	if (self.replyToId != 0)
		return TGComposeModeReply;
	return TGComposeModeNew;
}

- (void)setComposeMode:(TGComposeMode)mode messageId:(int64_t)messageId {
	self.replyToId = (mode == TGComposeModeReply) ? messageId : 0;
	self.editingId = (mode == TGComposeModeEdit) ? messageId : 0;
	if (mode != TGComposeModeEdit) {
		self.editingIsCaption = NO;
		self.editingCaptionAboveMedia = NO;
		self.editingLinkPreviewOptions = nil;
	}
	self.replyQuoteText = nil;
	self.replyQuoteEntities = nil;
	self.replyQuotePosition = 0;
}

- (void)clearComposeState {
	if (self.composeMode == TGComposeModeEdit)
		self.input.text = @"";
	self.preEditDraftText = nil;
	[self.pendingCustomEmojiRuns removeAllObjects];
	[self.pendingMentionRuns removeAllObjects];
	[self.pendingStyleEntities removeAllObjects];
	[self clearMentionSuggestions];
	[self setComposeMode:TGComposeModeNew messageId:0];
	self.scheduledSendDate = 0;
	self.scheduleWhenOnline = NO;
	[self.sendButton setTitle:TGL(@"MediaPicker.Send", @"Send") forState:UIControlStateNormal];
	[self refreshSendAsPlaceholder];
	[self setComposeBannerShown:NO];
	[self inputChanged];
}

- (void)cancelComposeState {
	NSString *restoredDraft = (self.composeMode == TGComposeModeEdit) ? self.preEditDraftText : nil;
	[self clearComposeState];
	if (restoredDraft.length) {
		self.input.text = restoredDraft;
		[self inputChanged];
	}
}

- (void)setComposeBannerShown:(BOOL)shown {
	if (!self.composeBanner)
		return;
	BOOL onScreen = (!self.composeBanner.hidden && self.composeBanner.alpha > 0.01f);
	if (onScreen == shown)
		return;

	UIEdgeInsets insets = self.table.contentInset;
	insets.bottom += shown ? kComposeBannerHeight : -self.composeBannerInset;
	self.composeBannerInset = shown ? kComposeBannerHeight : 0.0f;
	self.table.contentInset = insets;
	self.table.scrollIndicatorInsets = insets;

	if (shown) {
		self.composeBanner.frame = CGRectMake(0,
			CGRectGetMinY(self.inputBar.frame) - self.actionBarInset - kComposeBannerHeight,
			self.view.bounds.size.width, kComposeBannerHeight);
		self.composeBanner.alpha = 0.0f;
		self.composeBanner.hidden = NO;
		[self.view bringSubviewToFront:self.composeBanner];
	}
	[self layoutFloatingButtons];

	[UIView animateWithDuration:0.2 delay:0.0
		options:UIViewAnimationOptionBeginFromCurrentState
		animations:^{ self.composeBanner.alpha = shown ? 1.0f : 0.0f; }
		completion:^(BOOL finished) {
			if (finished && self.composeBanner.alpha < 0.01f)
				self.composeBanner.hidden = YES;
		}];
}

- (void)showComposeBanner:(NSString *)text {
	if (!self.composeBanner) {
		CGRect b = self.view.bounds;
		self.composeBanner = [[UIView alloc] initWithFrame:
				CGRectMake(0, CGRectGetMinY(self.inputBar.frame) - self.actionBarInset - kComposeBannerHeight, b.size.width, kComposeBannerHeight)];
		self.composeBanner.backgroundColor = [[TGTheme shared] inputBarColour];
		self.composeBanner.alpha = 0.0f;
		self.composeBanner.hidden = YES;
		self.composeBanner.autoresizingMask = UIViewAutoresizingFlexibleWidth |
			UIViewAutoresizingFlexibleTopMargin;

		UILabel *label = [[TGEmojiLabel alloc] initWithFrame:
				CGRectMake(10, 4, b.size.width - 56, 20)];
		label.font = [UIFont systemFontOfSize:13];
		label.textColor = [[TGTheme shared] accentColour];
		label.backgroundColor = [UIColor clearColor];
		label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[self.composeBanner addSubview:label];

		UIView *hair = [[UIView alloc] initWithFrame:
				CGRectMake(0, 0, b.size.width, kRetinaPixel)];
		hair.backgroundColor = [[TGTheme shared] separatorColour];
		hair.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		hair.userInteractionEnabled = NO;
		[self.composeBanner addSubview:hair];

		UIButton *cancel = [UIButton buttonWithType:UIButtonTypeCustom];
		cancel.frame = CGRectMake(b.size.width - 44, 0, 44, kComposeBannerHeight);
		cancel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[cancel setTitle:TGL(@"Chat.ComposeBannerClose", @"×") forState:UIControlStateNormal];
		[cancel setTitleColor:[[TGTheme shared] secondaryTextColour]
					 forState:UIControlStateNormal];
		[cancel setTitleColor:[[TGTheme shared] accentColour]
					 forState:UIControlStateHighlighted];
		cancel.titleLabel.font = [UIFont systemFontOfSize:22];
		cancel.titleEdgeInsets = UIEdgeInsetsMake(0, 4, 0, 0);
		[cancel addTarget:self action:@selector(cancelComposeState)
			forControlEvents:UIControlEventTouchUpInside];
		[self.composeBanner addSubview:cancel];

		[self.view addSubview:self.composeBanner];
	}

	UILabel *label = (UILabel *)[self.composeBanner.subviews firstObject];
	if ([label isKindOfClass:UILabel.class])
		label.text = text;
	[self setComposeBannerShown:YES];
}
@end

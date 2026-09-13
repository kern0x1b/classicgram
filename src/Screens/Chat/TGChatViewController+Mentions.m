#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGClient+Messages.h"
#import "TGClient+Reactions.h"
#import "TGClient+Search.h"

@implementation TGChatViewController (Mentions)

#pragma mark - mentions

- (void)loadUnreadMentions {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] searchMessagesInChat:self.chatId
									  query:@""
							   senderUserId:0
									 filter:@"searchMessagesFilterUnreadMention"
									threadId:self.threadId
						directMessagesTopic:self.directMessagesTopicId
								 savedTopic:self.savedTopicId
							  fromMessageId:0
									  limit:30
								 completion:^(NSArray *messages, int64_t next, NSInteger total) {
									 TGChatViewController *strongSelf = weakSelf;
									 if (!strongSelf)
										 return;
									 NSMutableArray *ids = [NSMutableArray array];
									 for (NSDictionary *m in messages)
										 if ([m[@"id"] isKindOfClass:NSNumber.class])
											 [ids addObject:m[@"id"]];
									 strongSelf.mentionIds = ids;
									 [strongSelf updateMentionButton];
								 }];
}

static UIImage *TGFloatingBadgeDisc(UIColor *fill, UIColor *border) {
	CGSize size = CGSizeMake(kFloatingButtonSide, kFloatingButtonSide);
	UIGraphicsBeginImageContextWithOptions(size, NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGRect disc = CGRectInset(CGRectMake(0, 0, size.width, size.height), 0.5f, 0.5f);
	[fill setFill];
	CGContextFillEllipseInRect(ctx, disc);
	[border setStroke];
	CGContextSetLineWidth(ctx, 1.0f);
	CGContextStrokeEllipseInRect(ctx, disc);
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

- (UIButton *)buildFloatingBadgeWithAction:(SEL)action font:(UIFont *)font {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.frame = CGRectMake(0, 0, kFloatingButtonSide, kFloatingButtonSide);
	UIColor *border = [[TGTheme shared] separatorColour];
	[button setBackgroundImage:
			TGFloatingBadgeDisc([UIColor colorWithWhite:1.0f alpha:0.9f], border)
					  forState:UIControlStateNormal];
	[button setBackgroundImage:
			TGFloatingBadgeDisc([UIColor colorWithWhite:0.85f alpha:0.95f], border)
					  forState:UIControlStateHighlighted];
	button.adjustsImageWhenHighlighted = NO;
	button.titleLabel.font = font;
	[button setTitleColor:[[TGTheme shared] accentColour] forState:UIControlStateNormal];
	button.layer.shadowColor = [UIColor blackColor].CGColor;
	button.layer.shadowOffset = CGSizeMake(0, 1);
	button.layer.shadowRadius = 1.0f;
	button.layer.shadowOpacity = 0.25f;
	button.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:
								   CGRectMake(0, 0, kFloatingButtonSide, kFloatingButtonSide)]
								  .CGPath;
	button.hidden = YES;
	button.alpha = 0.0f;
	button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
		UIViewAutoresizingFlexibleTopMargin;
	[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:button];
	return button;
}

- (void)updateMentionButton {
	BOOL wanted = (self.mentionIds.count > 0);
	if (!wanted && !self.mentionButton)
		return;
	if (!self.mentionButton)
		self.mentionButton =
			[self buildFloatingBadgeWithAction:@selector(mentionTapped)
										  font:[UIFont boldSystemFontOfSize:15]];
	if (wanted)
		[self.mentionButton setTitle:[NSString stringWithFormat:@"@%lu",
										 (unsigned long)self.mentionIds.count]
							forState:UIControlStateNormal];
	[self setFloatingButton:self.mentionButton shown:wanted];
	[self layoutFloatingButtons];
}

- (void)unreadMentionsUpdateReceived:(NSNotification *)note {
	if ([note.object longLongValue] != self.chatId)
		return;
	[self loadUnreadMentions];
}

- (void)mentionTapped {
	NSNumber *next = [self.mentionIds lastObject];
	if (!next) {
		[self updateMentionButton];
		return;
	}
	[self.mentionIds removeLastObject];
	[[TGClient shared] markRead:@[ next ] inChat:self.chatId source:@"history"];
	if (![self scrollToMessageId:next.longLongValue])
		[self showAlertTitle:@"" message:TGL(@"Conversation.MessageDoesntExist", @"Message doesn't exist")];
	if (self.mentionIds.count)
		[self updateMentionButton];
	else
		[self loadUnreadMentions];
}

#pragma mark - unread reactions

- (void)loadUnreadReactions {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] unreadReactionsInChat:self.chatId
									 threadId:self.threadId
						  directMessagesTopic:self.directMessagesTopicId
								   savedTopic:self.savedTopicId
								fromMessageId:0
										limit:30
								   completion:^(NSArray *messageIds) {
									  TGChatViewController *strongSelf = weakSelf;
									  if (!strongSelf)
										  return;
									  strongSelf.reactionMessageIds = [(messageIds ?: @[]) mutableCopy];
									  [strongSelf updateReactionButton];
								  }];
}

- (void)updateReactionButton {
	BOOL wanted = (self.reactionMessageIds.count > 0);
	if (!wanted && !self.reactionButton)
		return;
	if (!self.reactionButton)
		self.reactionButton =
			[self buildFloatingBadgeWithAction:@selector(reactionBadgeTapped)
										  font:[UIFont boldSystemFontOfSize:13]];
	if (wanted)
		[self.reactionButton setTitle:[NSString stringWithFormat:@"♥%lu",
										  (unsigned long)self.reactionMessageIds.count]
							 forState:UIControlStateNormal];
	[self setFloatingButton:self.reactionButton shown:wanted];
	[self layoutFloatingButtons];
}

- (void)unreadReactionsUpdateReceived:(NSNotification *)note {
	if ([note.object longLongValue] != self.chatId)
		return;
	[self loadUnreadReactions];
}

- (void)reactionBadgeTapped {
	NSNumber *next = [self.reactionMessageIds firstObject];
	if (!next) {
		[self updateReactionButton];
		return;
	}
	[self.reactionMessageIds removeObjectAtIndex:0];
	[[TGClient shared] markRead:@[ next ] inChat:self.chatId source:@"history"];
	if (![self scrollToMessageId:next.longLongValue])
		[self showAlertTitle:@"" message:TGL(@"Conversation.MessageDoesntExist", @"Message doesn't exist")];
	if (self.reactionMessageIds.count)
		[self updateReactionButton];
	else
		[self loadUnreadReactions];
}

@end

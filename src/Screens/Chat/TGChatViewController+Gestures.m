#import "TGClient+Contacts.h"
#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+ChatState.h"
#import "TGLocalization.h"
#import "TGBubbleCellBase.h"
#import "TGActionSheet.h"
#import "TGRichText.h"
#import "TGTheme.h"
#import "TGSnackbar.h"
#import "TGForwardPicker.h"
#import "TGClient+Bots.h"
#import "TGReactionPickerView.h"
#import "TGMessageActionsSheet.h"
#import "TGTextSelectionOverlay.h"
#import "TGQuotePickerViewController.h"
#import "TGAlertView.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <MediaPlayer/MediaPlayer.h>
#import "TGLazyFramework.h"
#import "TGAssetPicker.h"

@implementation TGChatViewController (Gestures)

static const CGFloat kInputSwipeDismissDistance = 18.0f;
static const CGFloat kInputSwipeDismissVelocity = 260.0f;

static const CGFloat kReplySwipeIconSize = 33.0f;
static const CGFloat kReplySwipeIncomingTrigger = 45.0f;
static const CGFloat kReplySwipeOutgoingTrigger = 60.0f;
static const CGFloat kReplySwipeIncomingInset = -24.0f;
static const CGFloat kReplySwipeOutgoingInset = 10.0f;
static const CGFloat kReplySwipeBandRange = 100.0f;
static const CGFloat kReplySwipeBandCoefficient = 0.4f;
static const CGFloat kReplySwipeMaxOffset = 180.0f;

static CGFloat TGReplySwipeBandedOffset(CGFloat offset, CGFloat bandingStart) {
	if (offset < bandingStart)
		return offset;
	CGFloat banded = offset - bandingStart;
	CGFloat eased = 1.0f - (1.0f / ((banded * kReplySwipeBandCoefficient / kReplySwipeBandRange) + 1.0f));
	return bandingStart + eased * kReplySwipeBandRange;
}

static UIImage *TGReplySwipeArrowImage(void) {
	static UIImage *image = nil;
	if (image)
		return image;
	const CGFloat s = 28.0f;
	const CGFloat m = s * 0.18f;
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(s, s), NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextSetLineWidth(ctx, 1.8f);
	CGContextSetLineCap(ctx, kCGLineCapRound);
	CGContextSetLineJoin(ctx, kCGLineJoinRound);
	CGContextSetRGBStrokeColor(ctx, 1, 1, 1, 1);
	CGContextMoveToPoint(ctx, m + 5, s * 0.30f);
	CGContextAddLineToPoint(ctx, m, s * 0.45f);
	CGContextAddLineToPoint(ctx, m + 5, s * 0.60f);
	CGContextStrokePath(ctx);
	CGContextMoveToPoint(ctx, m, s * 0.45f);
	CGContextAddLineToPoint(ctx, s - m - 5, s * 0.45f);
	CGContextAddArc(ctx, s - m - 5, s * 0.62f, s * 0.17f, -M_PI_2, 0, 0);
	CGContextStrokePath(ctx);
	image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

- (void)showPeerMenuForUserId:(int64_t)userId fromView:(UIView *)view {
	if (userId <= 0 || self.selecting)
		return;
	self.peerMenuUserId = userId;
	self.peerMenuName = [[TGClient shared] nameForUserId:userId] ?: @"";
	UIActionSheet *sheet =
		[[UIActionSheet alloc] initWithTitle:(self.peerMenuName.length ? self.peerMenuName : nil)
									delegate:self
						   cancelButtonTitle:nil
					  destructiveButtonTitle:nil
						   otherButtonTitles:nil];
	[sheet addButtonWithTitle:TGL(@"Conversation.ContextMenuOpenProfile", @"Open Profile")];
	[sheet addButtonWithTitle:TGL(@"UserInfo.SendMessage", @"Send Message")];
	if (!self.postingBlocked)
		[sheet addButtonWithTitle:TGL(@"Conversation.ContextMenuMention", @"Mention")];
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
	sheet.tag = kPeerMenuSheetTag;
	UIView *anchor = view ?: self.view;
	[sheet tg_showFromRect:anchor.bounds inView:anchor];
}

- (void)runPeerMenuOption:(NSString *)chosen {
	int64_t userId = self.peerMenuUserId;
	NSString *name = self.peerMenuName;
	self.peerMenuUserId = 0;
	self.peerMenuName = nil;
	if (userId <= 0)
		return;

	if ([chosen isEqualToString:TGL(@"Conversation.ContextMenuOpenProfile", @"Open Profile")]) {
		[self openProfileForUserId:userId];
		return;
	}
	if ([chosen isEqualToString:TGL(@"UserInfo.SendMessage", @"Send Message")]) {
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] privateChatWithUser:userId completion:^(int64_t chatId) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf || !chatId)
				return;
			[strongSelf openChatId:chatId title:(name.length ? name : @"Chat")isGroup:NO];
		}];
		return;
	}
	if ([chosen isEqualToString:TGL(@"Conversation.ContextMenuMention", @"Mention")])
		[self insertMentionOfUser:userId name:name];
}

- (void)insertMentionOfUser:(int64_t)userId name:(NSString *)name {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] userInfo:userId completion:^(NSDictionary *user) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSString *username = [strongSelf publicUsernameIn:user];
		NSString *mentionText = nil;
		NSString *insert = nil;
		if (username.length) {
			insert = [NSString stringWithFormat:@"@%@ ", username];
		} else if (name.length && userId != 0) {
			mentionText = name;
			insert = [name stringByAppendingString:@" "];
		}
		if (insert.length < 2)
			return;

		NSString *text = strongSelf.input.text ?: @"";
		NSString *padding = (text.length && ![text hasSuffix:@" "]) ? @" " : @"";
		NSInteger insertionStart = (NSInteger)(text.length + padding.length);
		NSRange trigger = NSMakeRange(text.length, 0);
		NSString *replacement = [padding stringByAppendingString:insert];

		[strongSelf adjustPendingCustomEmojiForRange:trigger replacementLength:(NSInteger)replacement.length];
		[strongSelf adjustPendingMentionRunsForRange:trigger replacementLength:(NSInteger)replacement.length];

		if (mentionText.length) {
			[strongSelf.pendingMentionRuns addObject:@{
				@"range" : [NSValue valueWithRange:NSMakeRange((NSUInteger)insertionStart, mentionText.length)],
				@"userId" : @(userId),
				@"text" : mentionText,
			}];
		}

		strongSelf.input.text = [text stringByAppendingString:replacement];
		[strongSelf inputChanged];
		[strongSelf.input becomeFirstResponder];
	}];
}

- (NSString *)publicUsernameIn:(NSDictionary *)user {
	if (![user isKindOfClass:NSDictionary.class])
		return nil;
	NSString *plain = user[@"username"];
	if ([plain isKindOfClass:NSString.class] && plain.length)
		return plain;
	NSDictionary *usernames = user[@"usernames"];
	if (![usernames isKindOfClass:NSDictionary.class])
		return nil;
	NSArray *active = usernames[@"active_usernames"];
	if ([active isKindOfClass:NSArray.class]) {
		NSString *first = [active firstObject];
		if ([first isKindOfClass:NSString.class] && first.length)
			return first;
	}
	NSString *editable = usernames[@"editable_username"];
	return ([editable isKindOfClass:NSString.class] && editable.length) ? editable : nil;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer {
	if (recognizer == self.inputBarDismissSwipe) {
		if (![self hasDismissableInput])
			return NO;
		CGPoint moved = [self.inputBarDismissSwipe translationInView:self.inputBar];
		return (moved.y > 0 && moved.y > fabs(moved.x));
	}
	return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer
	shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
	if ((recognizer == self.backgroundTap && other == self.messageHold) ||
		(recognizer == self.messageHold && other == self.backgroundTap))
		return NO;
	return (recognizer == self.backgroundTap || other == self.backgroundTap ||
		recognizer == self.inputBarDismissSwipe || other == self.inputBarDismissSwipe);
}

- (BOOL)hasDismissableInput {
	return ([self.input isFirstResponder] || [self.chatSearchBar isFirstResponder] ||
		self.stickerPanel != nil);
}

- (void)messageBackgroundTapped:(UITapGestureRecognizer *)tap {
	if (tap.state != UIGestureRecognizerStateEnded)
		return;
	if (!self.selecting)
		[self touchedMessageBackground];
}

- (void)inputBarSwiped:(UIPanGestureRecognizer *)pan {
	if (pan.state != UIGestureRecognizerStateChanged &&
		pan.state != UIGestureRecognizerStateEnded)
		return;

	CGPoint moved = [pan translationInView:self.inputBar];
	if (moved.y <= 0 || moved.y <= fabs(moved.x))
		return;

	BOOL farEnough = (moved.y >= kInputSwipeDismissDistance);
	BOOL flicked = (pan.state == UIGestureRecognizerStateEnded &&
		[pan velocityInView:self.inputBar].y >= kInputSwipeDismissVelocity);
	if (!farEnough && !flicked)
		return;

	if (pan.state == UIGestureRecognizerStateChanged) {
		pan.enabled = NO;
		pan.enabled = YES;
	}
	[self touchedMessageBackground];
}

- (BOOL)canReplyToRow:(NSInteger)row {
	NSDictionary *m = [self messageAtRow:row];
	if (!m)
		return NO;
	if ([m[@"service"] boolValue] || ![m[@"id"] isKindOfClass:NSNumber.class])
		return NO;
	return ([m[@"id"] longLongValue] != 0);
}

- (void)attachReplySwipeToRowCell:(UITableViewCell<TGReplySwipeCell> *)cell {
	TGReplySwipeRecognizer *pan = cell.replySwipe;
	if (!pan)
		return;
	__weak TGChatViewController *weakSelf = self;
	__weak UITableViewCell<TGReplySwipeCell> *weakCell = cell;
	pan.shouldBegin = ^BOOL {
		TGChatViewController *strongSelf = weakSelf;
		return strongSelf ? [strongSelf canBeginReplySwipeOnCell:weakCell] : NO;
	};
	[pan addTarget:self action:@selector(replySwiped:)];
	cell.contentView.clipsToBounds = NO;
}

- (BOOL)canBeginReplySwipeOnCell:(UITableViewCell<TGReplySwipeCell> *)cell {
	if (!cell || self.selecting || self.postingBlocked)
		return NO;
	NSIndexPath *path = [self.table indexPathForCell:cell];
	return (path != nil && [self canReplyToRow:path.row]);
}

- (void)stopReplySwipeAnimationsInCell:(UITableViewCell<TGReplySwipeCell> *)cell {
	if (cell.contentView.layer.animationKeys.count)
		[cell.contentView.layer removeAllAnimations];
	if (cell.replyArrow.layer.animationKeys.count)
		[cell.replyArrow.layer removeAllAnimations];
	if (cell.replyArrowPlate.layer.animationKeys.count)
		[cell.replyArrowPlate.layer removeAllAnimations];
}

- (void)applyReplySwipeOffset:(CGFloat)offset toCell:(UITableViewCell<TGReplySwipeCell> *)cell {
	CGRect box = cell.contentView.bounds;
	if (box.origin.x == offset)
		return;
	box.origin.x = offset;
	cell.contentView.bounds = box;
}

- (void)resetReplySwipeOnCell:(UITableViewCell<TGReplySwipeCell> *)cell {
	[self stopReplySwipeAnimationsInCell:cell];
	[self applyReplySwipeOffset:0.0f toCell:cell];
	cell.replyArrow.hidden = YES;
	cell.replyArrowPlate.alpha = 0.0f;
}

- (CGFloat)replySwipeTriggerForRow:(NSInteger)row {
	NSDictionary *m = [self messageAtRow:row];
	return [m[@"outgoing"] boolValue] ? kReplySwipeOutgoingTrigger
									  : kReplySwipeIncomingTrigger;
}

- (CGFloat)replySwipeArrowInsetForRow:(NSInteger)row {
	NSDictionary *m = [self messageAtRow:row];
	return [m[@"outgoing"] boolValue] ? kReplySwipeOutgoingInset
									  : kReplySwipeIncomingInset;
}

- (void)placeReplyArrowInCell:(UITableViewCell<TGReplySwipeCell> *)cell forRow:(NSInteger)row {
	if (!cell.replyArrowPlate) {
		UIView *carrier = cell.replyArrow;
		BOOL carrierIsNew = (carrier == nil);
		if (carrierIsNew)
			carrier = [[UIView alloc] init];
		carrier.backgroundColor = [UIColor clearColor];
		carrier.userInteractionEnabled = NO;
		carrier.bounds = CGRectMake(0, 0, kReplySwipeIconSize, kReplySwipeIconSize);

		UIView *plate = [[UIView alloc] initWithFrame:carrier.bounds];
		plate.backgroundColor = TGSystemPlateColour();
		plate.layer.cornerRadius = kReplySwipeIconSize / 2.0f;
		plate.userInteractionEnabled = NO;

		UIImageView *glyph = [[UIImageView alloc] initWithFrame:plate.bounds];
		glyph.contentMode = UIViewContentModeCenter;
		glyph.image = TGReplySwipeArrowImage();
		[plate addSubview:glyph];
		[carrier addSubview:plate];

		cell.replyArrow = carrier;
		cell.replyArrowPlate = plate;
		if (carrierIsNew)
			[cell.contentView addSubview:carrier];
	}

	[self stopReplySwipeAnimationsInCell:cell];

	CGRect box = cell.contentView.bounds;
	cell.replyArrow.transform = CGAffineTransformIdentity;
	cell.replyArrow.center = CGPointMake(
		box.size.width + [self replySwipeArrowInsetForRow:row] +
			kReplySwipeIconSize / 2.0f,
		(box.size.height + box.origin.y) / 2.0f);
	cell.replyArrowPlate.transform = CGAffineTransformMakeScale(0.65f, 0.65f);
	cell.replyArrowPlate.alpha = 0.0f;
	cell.replyArrow.hidden = NO;
	[cell.contentView bringSubviewToFront:cell.replyArrow];
}

- (void)updateReplyArrowInCell:(UITableViewCell<TGReplySwipeCell> *)cell progress:(CGFloat)progress {
	UIView *plate = cell.replyArrowPlate;
	if (!plate)
		return;
	progress = MAX(0.0f, MIN(1.0f, progress));
	CGFloat shown = MIN(1.0f, progress * 1.2f);
	CGFloat scale = 0.65f + shown * 0.35f;
	plate.alpha = shown;
	plate.transform = CGAffineTransformMakeScale(scale, scale);

	if (progress < 1.0f || self.swipeArmed)
		return;
	self.swipeArmed = YES;
	[self popReplyArrowInCell:cell];
}

- (void)popReplyArrowInCell:(UITableViewCell<TGReplySwipeCell> *)cell {
	UIView *carrier = cell.replyArrow;
	if (!carrier)
		return;
	[UIView animateWithDuration:0.2 delay:0.0
		options:UIViewAnimationOptionCurveEaseOut |
		UIViewAnimationOptionBeginFromCurrentState
		animations:^{
			carrier.transform = CGAffineTransformMakeScale(1.1f, 1.1f);
		} completion:^(BOOL finished) {
			if (!finished)
				return;
			[UIView animateWithDuration:0.15 delay:0.0
								options:UIViewAnimationOptionCurveEaseInOut |
				UIViewAnimationOptionBeginFromCurrentState
							 animations:^{
								 carrier.transform = CGAffineTransformIdentity;
							 }
							 completion:nil];
		}];
}

- (void)springReplySwipeBackInCell:(UITableViewCell<TGReplySwipeCell> *)cell from:(CGFloat)offset {
	UIView *carrier = cell.replyArrow;
	UIView *plate = cell.replyArrowPlate;
	CGFloat overshoot = MIN(5.0f, offset * 0.12f);
	__weak TGChatViewController *weakSelf = self;

	[UIView animateWithDuration:0.19 delay:0.0
		options:UIViewAnimationOptionCurveEaseOut |
		UIViewAnimationOptionBeginFromCurrentState
		animations:^{
			CGRect box = cell.contentView.bounds;
			box.origin.x = -overshoot;
			cell.contentView.bounds = box;
			plate.alpha = 0.0f;
			plate.transform = CGAffineTransformMakeScale(0.2f, 0.2f);
		} completion:^(BOOL finished) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf || cell == strongSelf.swipingCell)
				return;
			carrier.hidden = YES;
			[UIView animateWithDuration:0.13 delay:0.0
								options:UIViewAnimationOptionCurveEaseInOut |
				UIViewAnimationOptionBeginFromCurrentState
							 animations:^{
								 CGRect box = cell.contentView.bounds;
								 box.origin.x = 0.0f;
								 cell.contentView.bounds = box;
							 }
							 completion:nil];
		}];
}

- (void)replySwiped:(TGReplySwipeRecognizer *)pan {
	if (![pan.view conformsToProtocol:@protocol(TGReplySwipeCell)])
		return;
	UITableViewCell<TGReplySwipeCell> *cell = (UITableViewCell<TGReplySwipeCell> *)pan.view;

	if (pan.state == UIGestureRecognizerStateBegan) {
		NSIndexPath *path = [self.table indexPathForCell:cell];
		self.swipingRow = (path && [self canReplyToRow:path.row]) ? path.row : -1;
		if (self.swipingRow < 0)
			return;
		self.swipingCell = cell;
		self.swipeArmed = NO;
		self.swipeOffset = 0.0f;
		[self applyReplySwipeOffset:0.0f toCell:cell];
		[self placeReplyArrowInCell:cell forRow:self.swipingRow];
		return;
	}

	if (self.swipingRow < 0 || cell != self.swipingCell)
		return;

	CGFloat trigger = [self replySwipeTriggerForRow:self.swipingRow];
	CGFloat dragged = MAX(0.0f, -[pan translationInView:cell].x);

	if (pan.state == UIGestureRecognizerStateChanged) {
		CGFloat offset = MIN(kReplySwipeMaxOffset,
			TGReplySwipeBandedOffset(dragged, trigger));
		self.swipeOffset = offset;
		[self applyReplySwipeOffset:offset toCell:cell];
		[self updateReplyArrowInCell:cell progress:offset / trigger];
		return;
	}

	if (pan.state == UIGestureRecognizerStateEnded ||
		pan.state == UIGestureRecognizerStateCancelled ||
		pan.state == UIGestureRecognizerStateFailed) {
		NSInteger row = self.swipingRow;
		CGFloat travelled = self.swipeOffset;
		BOOL fired = (pan.state == UIGestureRecognizerStateEnded && dragged > trigger);

		self.swipingRow = -1;
		self.swipingCell = nil;
		self.swipeArmed = NO;
		self.swipeOffset = 0.0f;

		[self springReplySwipeBackInCell:cell from:travelled];
		if (fired)
			[self beginReplyToRow:row];
	}
}

- (void)beginReplyToRow:(NSInteger)row {
	if (![self canReplyToRow:row])
		return;
	NSDictionary *m = [self messageAtRow:row];
	[self setComposeMode:TGComposeModeReply messageId:[m[@"id"] longLongValue]];
	[self.sendButton setTitle:TGL(@"MediaPicker.Send", @"Send") forState:UIControlStateNormal];
	NSString *bodyText = [self textOf:m];
	[self showComposeBanner:[NSString stringWithFormat:TGL(@"Chat.ReplyPanel.ReplyTo", @"Reply to: %@"),
								bodyText.length ? bodyText : (m[@"kind"] ?: @"message")]];
	[self.input becomeFirstResponder];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] viaBotForMessage:m completion:^(NSString *username) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf || !username.length || strongSelf.replyToId != [m[@"id"] longLongValue])
			return;
		[strongSelf showComposeBanner:[NSString stringWithFormat:TGL(@"Chat.ReplyPanel.ReplyToBot", @"Reply to @%@: %@"),
								  username, bodyText.length ? bodyText : (m[@"kind"] ?: @"message")]];
	}];
}

- (UIView *)bubbleViewForMessageId:(int64_t)messageId {
	for (NSIndexPath *path in [self.table indexPathsForVisibleRows]) {
		NSDictionary *m = [self messageAtRow:path.row];
		if (!m || ![m[@"id"] isKindOfClass:NSNumber.class] ||
			[m[@"id"] longLongValue] != messageId)
			continue;
		UITableViewCell *cell = [self.table cellForRowAtIndexPath:path];
		if ([cell isKindOfClass:TGBubbleCellBase.class])
			return ((TGBubbleCellBase *)cell).bubble;
	}
	return self.table;
}

static const NSInteger kPeerTapTag = 0x9300;

- (UILongPressGestureRecognizer *)peerHoldRecognizer {
	UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(peerHeld:)];
	hold.minimumPressDuration = 0.24;
	hold.allowableMovement = 10.0f;
	return hold;
}

- (void)attachPeerGesturesTo:(UIView *)view {
	if (!view || view.tag == kPeerTapTag)
		return;
	[view addGestureRecognizer:[[UITapGestureRecognizer alloc]
								   initWithTarget:self
										   action:@selector(peerTapped:)]];
	[view addGestureRecognizer:[self peerHoldRecognizer]];
	view.tag = kPeerTapTag;
}

- (void)attachPeerGesturesToRowCell:(TGMessageRowCell *)cell {
	if (![cell isKindOfClass:[TGBubbleCellBase class]])
		return;
	TGBubbleCellBase *bubble = (TGBubbleCellBase *)cell;
	[self attachPeerGesturesTo:bubble.senderAvatar];
	[self attachPeerGesturesTo:bubble.sender];
}

- (void)refreshPeerGesturesInCell:(TGMessageRowCell *)cell {
	if (![cell isKindOfClass:[TGBubbleCellBase class]])
		return;
	TGBubbleCellBase *bubble = (TGBubbleCellBase *)cell;
	BOOL live = bubble.avatarUserId > 0 && !self.selecting;
	bubble.senderAvatar.userInteractionEnabled = live;
	bubble.sender.userInteractionEnabled = live;
}

- (int64_t)peerOfGestureView:(UIView *)view {
	while (view && ![view isKindOfClass:[TGBubbleCellBase class]])
		view = view.superview;
	TGBubbleCellBase *cell = (TGBubbleCellBase *)view;
	if (!cell || self.selecting)
		return 0;
	return cell.avatarUserId;
}

- (void)peerTapped:(UITapGestureRecognizer *)tap {
	[self openProfileForUserId:[self peerOfGestureView:tap.view]];
}

- (void)peerHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state != UIGestureRecognizerStateBegan)
		return;
	[self showPeerMenuForUserId:[self peerOfGestureView:hold.view] fromView:hold.view];
}

@end

#import "TGReactionPickerView.h"
#import "TGReactionPickerViewInternal.h"

#import "TGReactionService.h"
#import "TGSnackbar.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGActionSheet.h"
#import "TGLocalization.h"
#import "TGFlattenReactions.h"

@implementation TGReactionPickerView (Loading)

#pragma mark loading

- (void)loadReactions {
	if (_dismissed)
		return;
	if (self.chatId == 0 || self.messageId == 0) {
		[self setEmoji:nil reason:TGL(@"ReactionPicker.NotAvailable", @"Reactions are not available here")];
		return;
	}

	_loading = YES;
	__weak TGReactionPickerView *weakSelf = self;
	[TGReactionService availableReactionsForMessage:self.messageId
											 inChat:self.chatId
										 completion:^(NSDictionary *info) {
											 TGReactionPickerView *strongSelf = weakSelf;
											 if (strongSelf == nil || strongSelf->_dismissed)
												 return;
											 strongSelf->_loading = NO;

											 if (![info isKindOfClass:[NSDictionary class]]) {
												 [strongSelf setEmoji:nil reason:TGL(@"ReactionPicker.LoadFailed", @"Could not load reactions")];
												 return;
											 }

											 NSString *reason = [info objectForKey:@"reason"];
											 if (![reason isKindOfClass:[NSString class]])
												 reason = @"";

											 NSArray *emoji = [info objectForKey:@"allEmoji"];
											 if (![emoji isKindOfClass:[NSArray class]])
												 emoji = nil;

											 NSArray *premiumEmoji = [info objectForKey:@"needsPremiumEmoji"];
											 strongSelf->_needsPremiumEmoji = [premiumEmoji isKindOfClass:[NSArray class]]
												 ? [NSSet setWithArray:premiumEmoji]
												 : nil;

											 if (reason.length > 0) {
												 [strongSelf setEmoji:nil reason:reason];
												 return;
											 }
											 if (emoji.count == 0) {
												 [strongSelf setEmoji:nil reason:TGL(@"ReactionPicker.NoneAllowed", @"No reactions are allowed here")];
												 return;
											 }

											 [strongSelf applyChatRestrictionsTo:emoji];
										 }];
}

- (void)applyChatRestrictionsTo:(NSArray *)emoji {
	__weak TGReactionPickerView *weakSelf = self;
	void (^completion)(NSArray *, BOOL, NSInteger, BOOL) =
		^(NSArray *emojis, BOOL allowsAll, NSInteger maxCount, BOOL hasAnyReactionsAllowed) {
		TGReactionPickerView *strongSelf = weakSelf;
		if (strongSelf == nil || strongSelf->_dismissed)
			return;

		NSArray *allowed = emoji;
		if (!allowsAll) {
			NSMutableSet *permitted = [[NSMutableSet alloc] init];
			for (id raw in emojis) {
				if ([raw isKindOfClass:[NSString class]] && [(NSString *)raw length] > 0)
					[permitted addObject:raw];
			}
			if (permitted.count == 0) {
				NSString *reason = hasAnyReactionsAllowed
					? TGL(@"Chat.SendReactionRestricted", @"You cannot send reactions in this chat.")
					: TGL(@"ReactionPicker.SwitchedOff", @"Reactions are switched off in this chat");
				[strongSelf setEmoji:nil reason:reason];
				return;
			}
			NSMutableArray *filtered = [[NSMutableArray alloc] init];
			for (id raw in emoji) {
				if ([permitted containsObject:raw])
					[filtered addObject:raw];
			}
			if (filtered.count == 0) {
				[strongSelf setEmoji:nil reason:TGL(@"ReactionPicker.NoneAllowed", @"No reactions are allowed here")];
				return;
			}
			allowed = filtered;
		}

		[strongSelf applyUsageTo:allowed maxCount:maxCount];
	};
	[TGReactionService availableReactionsInChat:self.chatId completion:completion];
}

- (void)applyUsageTo:(NSArray *)emoji maxCount:(NSInteger)__unused maxCount {
	__weak TGReactionPickerView *weakSelf = self;
	[TGReactionService reactionUsageForMessage:self.messageId
										inChat:self.chatId
									completion:^(NSArray *chosenEmoji,
										NSArray *existingReactionTypes,
										NSInteger usedCount,
										NSInteger limit,
										BOOL canAddMore) {
										TGReactionPickerView *strongSelf = weakSelf;
										if (strongSelf == nil || strongSelf->_dismissed)
											return;

										[strongSelf preparePaidWithEmoji:emoji
																  chosen:chosenEmoji
												   existingReactionTypes:existingReactionTypes
															  canAddMore:canAddMore];
									}];
}

- (void)preparePaidWithEmoji:(NSArray *)emoji
					   chosen:(NSArray *)chosen
		existingReactionTypes:(NSArray *)existingReactionTypes
				   canAddMore:(BOOL)room {
	if (self.chatId >= 0) {
		[self setEmoji:emoji reason:nil chosen:chosen canAddMore:room existingReactionTypes:existingReactionTypes];
		return;
	}

	_pendingEmoji = emoji;
	_pendingChosen = chosen;
	_pendingExistingReactionTypes = existingReactionTypes;
	_pendingCanAddMore = room;
	_paidPending = YES;
	[self performSelector:@selector(paidLookupTimedOut) withObject:nil afterDelay:2.5];

	__weak TGReactionPickerView *weakSelf = self;
	[TGReactionService paidReactionSendersInChat:self.chatId completion:^(NSArray *senders) {
		TGReactionPickerView *strongSelf = weakSelf;
		if (strongSelf == nil || strongSelf->_dismissed || !strongSelf->_paidPending)
			return;
		if (senders.count == 0) {
			[strongSelf finishPaidLookupAllowed:NO balance:0];
			return;
		}
		[TGReactionService starBalanceWithCompletion:^(long long stars) {
			TGReactionPickerView *innerSelf = weakSelf;
			if (innerSelf == nil || innerSelf->_dismissed || !innerSelf->_paidPending)
				return;
			[innerSelf finishPaidLookupAllowed:(stars > 0) balance:stars];
		}];
	}];
}

- (void)paidLookupTimedOut {
	if (!_paidPending)
		return;
	[self finishPaidLookupAllowed:NO balance:0];
}

- (void)finishPaidLookupAllowed:(BOOL)allowed balance:(long long)balance {
	if (!_paidPending)
		return;
	_paidPending = NO;
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(paidLookupTimedOut)
											   object:nil];
	_paidAllowed = allowed;
	_starBalance = balance;

	NSArray *emoji = _pendingEmoji;
	NSArray *chosen = _pendingChosen;
	NSArray *existingReactionTypes = _pendingExistingReactionTypes;
	BOOL room = _pendingCanAddMore;
	_pendingEmoji = nil;
	_pendingChosen = nil;
	_pendingExistingReactionTypes = nil;

	[self setEmoji:emoji reason:nil chosen:chosen canAddMore:room existingReactionTypes:existingReactionTypes];
}

- (CGFloat)clampedWidth:(CGFloat)width {
	CGFloat maximumWidth = MAX(60.0f, self.bounds.size.width - 8.0f);
	width = MIN(width, maximumWidth);
	if (width < 40.0f)
		width = 40.0f;
	return width;
}

- (void)addPlateOfWidth:(CGFloat)width {
	UIImage *leftImage = TGReactionStretch(@"MenuButtonLeft.png", -2);
	UIImage *rightImage = TGReactionStretch(@"MenuButtonRight.png", 0);
	UIImage *centerImage = TGReactionStretch(@"MenuButtonCenter.png", -1);
	if (centerImage == nil)
		return;

	CGFloat leftWidth = leftImage != nil ? leftImage.size.width : 0.0f;
	CGFloat rightWidth = rightImage != nil ? rightImage.size.width : 0.0f;
	if (leftWidth + rightWidth > width) {
		leftWidth = 0;
		rightWidth = 0;
	}

	UIImageView *center = [[UIImageView alloc] initWithImage:centerImage];
	center.frame = CGRectMake(leftWidth, 0, MAX(0.0f, width - leftWidth - rightWidth), kStripHeight);
	[_scrollView addSubview:center];

	if (leftWidth > 0) {
		UIImageView *left = [[UIImageView alloc] initWithImage:leftImage];
		left.frame = CGRectMake(0, 0, leftWidth, kStripHeight);
		[_scrollView addSubview:left];
	}
	if (rightWidth > 0) {
		UIImageView *right = [[UIImageView alloc] initWithImage:rightImage];
		right.frame = CGRectMake(width - rightWidth, 0, rightWidth, kStripHeight);
		[_scrollView addSubview:right];
	}
}

- (void)showSpinner {
	[self clearContent];
	_loading = YES;

	CGFloat width = [self clampedWidth:64.0f];
	[self addPlateOfWidth:width];

	_spinner = [[UIActivityIndicatorView alloc]
		initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
	[_scrollView addSubview:_spinner];
	[_spinner startAnimating];

	_scrollView.contentSize = CGSizeMake(width, kStripHeight);
	_scrollView.scrollEnabled = NO;

	[self buildPlainCardOfWidth:width];
	_spinner.center = CGPointMake(floorf(width / 2), floorf(kStripHeight / 2));
}

- (void)setEmoji:(NSArray *)emoji reason:(NSString *)reason {
	[self setEmoji:emoji reason:reason chosen:nil canAddMore:YES existingReactionTypes:nil];
}

- (void)setEmoji:(NSArray *)emoji
		  reason:(NSString *)reason
		  chosen:(NSArray *)chosen
	  canAddMore:(BOOL)canAddMore
existingReactionTypes:(NSArray *)existingReactionTypes {
	if (_dismissed)
		return;

	NSMutableSet *chosenSet = [[NSMutableSet alloc] init];
	for (id raw in chosen) {
		if ([raw isKindOfClass:[NSString class]] && [(NSString *)raw length] > 0)
			[chosenSet addObject:raw];
	}
	_chosenEmoji = chosenSet;
	_existingReactionTypes = existingReactionTypes;
	_canAddMore = canAddMore;

	_loading = NO;
	[self clearContent];

	if ([reason isKindOfClass:[NSString class]] && reason.length > 0) {
		[self buildNoticeWithText:reason];
		return;
	}

	NSMutableArray *usable = [[NSMutableArray alloc] init];
	for (id raw in emoji) {
		if ([raw isKindOfClass:[NSString class]] && [(NSString *)raw length] > 0)
			[usable addObject:raw];
	}
	if (usable.count == 0) {
		[self buildNoticeWithText:TGL(@"ReactionPicker.NoneAllowed", @"No reactions are allowed here")];
		return;
	}

	NSString *quick = [TGReactionService quickReactionEmoji];

	UIImage *leftImage = TGReactionStretch(@"MenuButtonLeft.png", -2);
	UIImage *rightImage = TGReactionStretch(@"MenuButtonRight.png", 0);
	UIImage *centerImage = TGReactionStretch(@"MenuButtonCenter.png", -1);
	UIImage *leftHighlighted = TGReactionStretch(@"MenuButtonLeft_Highlighted.png", -2);
	UIImage *rightHighlighted = TGReactionStretch(@"MenuButtonRight_Highlighted.png", 0);
	UIImage *centerHighlighted = TGReactionStretch(@"MenuButtonCenter_Highlighted.png", -1);
	UIImage *separatorImage = [UIImage imageNamed:@"MenuButtonSeparator.png"];

	if (_paidAllowed)
		[usable insertObject:kPaidStarGlyph atIndex:0];

	CGFloat x = 0;
	for (NSInteger i = 0; i < usable.count; i++) {
		NSString *value = [usable objectAtIndex:i];
		BOOL isPaid = (_paidAllowed && i == 0);

		TGReactionStripButton *button = [[TGReactionStripButton alloc] initWithFrame:
				CGRectMake(x, 0, kStripButtonWidth, kStripHeight)];
		button.emoji = value;
		button.paid = isPaid;
		button.emojiLabel.text = value;
		button.tag = (NSInteger)i;

		button.centerView.image = centerImage;
		button.centerView.highlightedImage = centerHighlighted;
		button.leftView.image = centerImage;
		button.leftView.highlightedImage = centerHighlighted;
		button.rightView.image = centerImage;
		button.rightView.highlightedImage = centerHighlighted;

		if (i == 0) {
			button.leftView.image = leftImage;
			button.leftView.highlightedImage = leftHighlighted;
		}
		if (i == usable.count - 1) {
			button.rightView.image = rightImage;
			button.rightView.highlightedImage = rightHighlighted;
		}

		if ([value isEqualToString:quick])
			button.emojiLabel.font = TGEmojiFontOfSize(kStripEmojiFontSize + 2);

		if (!isPaid)
			button.tagLabel = [TGReactionService savedMessagesTagLabelForEmoji:value inChat:self.chatId];

		BOOL premiumLocked = !isPaid && [_needsPremiumEmoji containsObject:value]
			&& ![TGReactionService isPremiumAccount];
		BOOL isChosen = (!isPaid && [_chosenEmoji containsObject:value]);
		if (isChosen) {
			button.centerView.image = centerHighlighted;
			button.leftView.image = (i == 0) ? leftHighlighted : centerHighlighted;
			button.rightView.image = (i == usable.count - 1) ? rightHighlighted : centerHighlighted;
		} else if (premiumLocked || (!_canAddMore && !isPaid && _chosenEmoji.count == 0
				&& !TGReactionTypeExistsOnMessage(value, _existingReactionTypes))) {
			button.enabled = NO;
			button.alpha = 0.45f;
		}

		if (!isPaid) {
			__weak TGReactionStripButton *weakButton = button;
			TGReactionIconForEmoji(value, kReactionIconSide, ^(UIImage *icon) {
				TGReactionStripButton *strongButton = weakButton;
				if (strongButton == nil || icon == nil)
					return;
				strongButton.iconView.image = icon;
				strongButton.iconView.hidden = NO;
				strongButton.emojiLabel.hidden = YES;
				[strongButton setNeedsLayout];
			});
		}

		[button addTarget:self action:@selector(emojiTapped:) forControlEvents:UIControlEventTouchUpInside];
		if (!isPaid) {
			UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc]
				initWithTarget:self action:@selector(longPressedReactionButton:)];
			[button addGestureRecognizer:longPress];
		}
		[_scrollView addSubview:button];
		[_buttons addObject:button];

		if (i > 0 && separatorImage != nil) {
			UIImageView *separator = [[UIImageView alloc] initWithImage:separatorImage];
			separator.frame = CGRectMake(x - 1, 2, separatorImage.size.width, 36);
			[_scrollView addSubview:separator];
			[_separators addObject:separator];
		}

		x += kStripButtonWidth;
	}

	CGFloat visible = MIN(x, kStripVisibleButtons * kStripButtonWidth);
	_scrollView.contentSize = CGSizeMake(x, kStripHeight);
	_scrollView.scrollEnabled = (x > visible + 0.5f);

	[self buildPlainCardOfWidth:visible];
}

- (void)buildNoticeWithText:(NSString *)text {
	UIFont *font = [UIFont boldSystemFontOfSize:14];
	CGFloat width = [self clampedWidth:[text sizeWithFont:font].width + 34.0f];

	[self addPlateOfWidth:width];

	_noticeLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, MAX(10.0f, width - 24), kStripHeight)];
	_noticeLabel.backgroundColor = [UIColor clearColor];
	_noticeLabel.font = font;
	_noticeLabel.textColor = [UIColor whiteColor];
	_noticeLabel.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.8f];
	_noticeLabel.shadowOffset = CGSizeMake(0, -1);
	_noticeLabel.textAlignment = NSTextAlignmentCenter;
	_noticeLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	_noticeLabel.text = text;

	[_scrollView addSubview:_noticeLabel];

	_scrollView.contentSize = CGSizeMake(width, kStripHeight);
	_scrollView.scrollEnabled = NO;

	[self buildPlainCardOfWidth:width];
}

- (void)buildPlainCardOfWidth:(CGFloat)width {
	width = [self clampedWidth:width];

	CGRect cardFrame = _card.frame;
	cardFrame.size = CGSizeMake(width, kStripHeight);
	_card.frame = cardFrame;
	_scrollView.frame = CGRectMake(0, 0, width, kStripHeight);

	[self positionCard];
	[self layoutCard];
}

- (void)clearContent {
	for (UIView *view in _buttons)
		[view removeFromSuperview];
	for (UIView *view in _separators)
		[view removeFromSuperview];
	[_buttons removeAllObjects];
	[_separators removeAllObjects];

	for (UIView *view in [_scrollView.subviews copy])
		[view removeFromSuperview];

	_spinner = nil;
	_noticeLabel = nil;
	_scrollView.contentOffset = CGPointZero;
}

@end

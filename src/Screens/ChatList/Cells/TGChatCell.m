#import "TGChatCell.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGSwipeGestureRecognizer.h"
#import "TGChatListHelpers.h"
#import "TGChatBadgeSlots.h"
#import "TGChatTitlePremium.h"

static const CGFloat kPendingSide = 12.0f;
static const CGFloat kErrorBadgeWidth = 26.0f;
static const CGFloat kErrorBadgeHeight = 20.0f;

@implementation TGChatCell {
	NSMutableArray *_swipeButtons;
	BOOL _swipeActionsVisible;
	CGFloat _dateWidth;
	NSString *_dateMain;
	NSString *_dateSuffix;
	BOOL _dateBold;
	UIColor *_dateBaseColor;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	[self buildAvatar];
	[self buildTextLabels];
	[self buildBadge];
	[self buildRowIcons];
	[self buildPlates];

	_swipeButtons = [NSMutableArray array];
	TGSwipeGestureRecognizer *swipe = [[TGSwipeGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(swipeRecognised:)];
	[self addGestureRecognizer:swipe];

	return self;
}

- (void)buildAvatar {
	self.avatar = [[UIImageView alloc] initWithFrame:CGRectMake(kAvatarLeft, 8, kAvatar, kAvatar)];
	self.avatar.layer.cornerRadius = kAvatarRadius;
	self.avatar.backgroundColor = [UIColor colorWithWhite:0.85f alpha:1.0f];
	self.avatar.contentMode = UIViewContentModeScaleAspectFill;
	[self.contentView addSubview:self.avatar];
}

- (void)applyTextSize {
	CGFloat delta = [TGTheme shared].listFontDelta;
	self.titleLabel.font = [UIFont boldSystemFontOfSize:16 + delta];
	self.previewLabel.font = [UIFont systemFontOfSize:14 + delta];
	self.authorLabel.font = [UIFont boldSystemFontOfSize:14 + delta];
	self.draftLabel.font = [UIFont systemFontOfSize:14 + delta];
}

- (void)buildTextLabels {
	self.titleLabel = [[TGEmojiLabel alloc] init];
	self.titleLabel.font = [UIFont boldSystemFontOfSize:16];
	self.titleLabel.textColor = TGChatListTitleColour();
	self.titleLabel.highlightedTextColor = [UIColor whiteColor];

	self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	[self.contentView addSubview:self.titleLabel];

	self.previewLabel = [[TGEmojiLabel alloc] init];
	self.previewLabel.font = [UIFont systemFontOfSize:14];
	self.previewLabel.textColor = TGChatListMessageColour();
	self.previewLabel.highlightedTextColor = [UIColor whiteColor];
	self.previewLabel.numberOfLines = 2;
	self.previewLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	[self.contentView addSubview:self.previewLabel];

	self.authorLabel = [[UILabel alloc] init];
	self.authorLabel.font = [UIFont boldSystemFontOfSize:14];
	self.authorLabel.backgroundColor = [UIColor clearColor];
	self.authorLabel.textColor = TGChatListAuthorColour();
	self.authorLabel.highlightedTextColor = [UIColor whiteColor];
	self.authorLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	self.authorLabel.hidden = YES;
	[self.contentView addSubview:self.authorLabel];

	self.draftLabel = [[UILabel alloc] init];
	self.draftLabel.font = [UIFont systemFontOfSize:14];
	self.draftLabel.backgroundColor = [UIColor clearColor];
	self.draftLabel.textColor = [UIColor colorWithRed:0xC4 / 255.0f green:0x2B / 255.0f
												 blue:0x1E / 255.0f
												alpha:1.0f];
	self.draftLabel.text = TGL(@"DialogList.Draft", @"Draft:");
	self.draftLabel.hidden = YES;
	[self.contentView addSubview:self.draftLabel];

	self.dateLabel = [[UILabel alloc] init];
	self.dateLabel.font = [UIFont systemFontOfSize:13];
	self.dateLabel.textColor = [UIColor colorWithRed:0x33 / 255.0f green:0x7a / 255.0f blue:0xcc / 255.0f alpha:1.0f];
	self.dateLabel.textAlignment = NSTextAlignmentRight;
	self.dateLabel.backgroundColor = [UIColor clearColor];
	self.dateLabel.highlightedTextColor = [UIColor whiteColor];
	[self.contentView addSubview:self.dateLabel];

	[self applyTextSize];
}

- (void)buildBadge {
	self.badgeBackground = [[UIImageView alloc] initWithImage:TGDialogListBadgeImage(NO)
											 highlightedImage:TGDialogListBadgeImage(YES)];
	self.badgeBackground.hidden = YES;
	[self.contentView addSubview:self.badgeBackground];

	self.badge = [[UILabel alloc] init];
	self.badge.font = [UIFont boldSystemFontOfSize:14];
	self.badge.textColor = [UIColor whiteColor];
	self.badge.backgroundColor = [UIColor clearColor];
	self.badge.shadowColor = [UIColor colorWithRed:0x80 / 255.0f green:0x91 / 255.0f blue:0xa6 / 255.0f alpha:1.0f];
	self.badge.shadowOffset = CGSizeMake(0, -1);
	self.badge.highlightedTextColor = [UIColor colorWithRed:0x23 / 255.0f green:0x71 / 255.0f blue:0xc2 / 255.0f alpha:1.0f];
	self.badge.textAlignment = NSTextAlignmentCenter;
	self.badge.hidden = YES;
	[self.contentView addSubview:self.badge];
}

- (void)buildRowIcons {
	self.onlineDot = [[UIView alloc] initWithFrame:
			CGRectMake(kAvatarLeft + kAvatar - 10, 8 + kAvatar - 10, 14, 14)];
	self.onlineDot.backgroundColor = [[TGTheme shared] onlineColour];
	self.onlineDot.layer.cornerRadius = 7;
	self.onlineDot.layer.borderWidth = 2;
	self.onlineDot.hidden = YES;
	[self.contentView addSubview:self.onlineDot];

	self.tick = [[UIImageView alloc] init];
	self.tick.hidden = YES;
	[self.contentView addSubview:self.tick];

	self.pin = [[UIImageView alloc] initWithImage:TGDialogListPinBadgeImage(NO)
								 highlightedImage:TGDialogListPinBadgeImage(YES)];
	self.pin.hidden = YES;
	[self.contentView addSubview:self.pin];

	self.mentionBadge = [[UIImageView alloc] initWithImage:TGDialogListMentionBadgeImage(NO)
										  highlightedImage:TGDialogListMentionBadgeImage(YES)];
	self.mentionBadge.hidden = YES;
	[self.contentView addSubview:self.mentionBadge];

	self.reactionBadge = [[UIImageView alloc] initWithImage:TGDialogListReactionBadgeImage(NO)
										   highlightedImage:TGDialogListReactionBadgeImage(YES)];
	self.reactionBadge.hidden = YES;
	[self.contentView addSubview:self.reactionBadge];

	self.muteIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"DialogList_Muted.png"]];
	self.muteIcon.hidden = YES;
	[self.contentView addSubview:self.muteIcon];

	self.premiumIcon = [[UIImageView alloc] initWithImage:TGChatTitlePremiumImage()];
	self.premiumIcon.hidden = YES;
	[self.contentView addSubview:self.premiumIcon];

	self.pendingIndicator = [[UIImageView alloc]
		   initWithImage:[UIImage imageNamed:@"DialogListPending.png"]
		highlightedImage:[UIImage imageNamed:@"DialogListPending_Highlighted.png"]];
	self.pendingIndicator.hidden = YES;
	[self.contentView addSubview:self.pendingIndicator];

	self.errorBadge = [[UIImageView alloc]
		   initWithImage:[UIImage imageNamed:@"DialogErrorBadge.png"]
		highlightedImage:[UIImage imageNamed:@"DialogErrorBadge_Highlighted.png"]];
	self.errorBadge.hidden = YES;
	[self.contentView addSubview:self.errorBadge];

	self.groupIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"DialogListGroupChatIcon.png"]];
	self.groupIcon.hidden = YES;
	[self.contentView addSubview:self.groupIcon];

	self.folderTag = [[UILabel alloc] init];
	self.folderTag.font = [UIFont boldSystemFontOfSize:11];
	self.folderTag.textColor = [UIColor whiteColor];
	self.folderTag.textAlignment = NSTextAlignmentCenter;
	self.folderTag.layer.cornerRadius = 6;
	self.folderTag.layer.masksToBounds = YES;
	self.folderTag.hidden = YES;
	[self.contentView addSubview:self.folderTag];

	self.arrow = [[UIImageView alloc] initWithImage:TGLocalizedDirectionalImage([UIImage imageNamed:@"DialogListArrow.png"])
								   highlightedImage:TGLocalizedDirectionalImage([UIImage imageNamed:@"DialogListArrow_Highlighted.png"])];
	[self.contentView addSubview:self.arrow];
}

- (void)buildPlates {
	UIImage *plate = [[UIImage imageNamed:@"DialogListCell.png"]
		stretchableImageWithLeftCapWidth:1
							topCapHeight:0];
	UIImage *platePressed = [[UIImage imageNamed:@"DialogListCellHighlighted.png"]
		stretchableImageWithLeftCapWidth:1
							topCapHeight:0];
	self.backgroundView = [[UIImageView alloc] initWithImage:plate];
	self.selectedBackgroundView = [[UIImageView alloc] initWithImage:platePressed];

	self.accessoryType = UITableViewCellAccessoryNone;
	self.selectionStyle = UITableViewCellSelectionStyleBlue;
}

#pragma mark - swipe actions

- (BOOL)swipeActionsVisible {
	return _swipeActionsVisible;
}

- (void)swipeRecognised:(TGSwipeGestureRecognizer *)recogniser {
	if (recogniser.state != UIGestureRecognizerStateRecognized || self.editing)
		return;
	if (!self.swipeActions.count || _swipeActionsVisible)
		return;

	[self setSelected:NO];
	[self setHighlighted:NO];
	if (self.onSwipeOpen)
		self.onSwipeOpen();
	[self setSwipeActionsVisible:YES animated:YES];
}

- (void)buildSwipeButtons {
	for (UIButton *button in _swipeButtons)
		[button removeFromSuperview];
	[_swipeButtons removeAllObjects];

	UIFont *font = [UIFont boldSystemFontOfSize:13];
	for (NSInteger i = 0; i < self.swipeActions.count; i++) {
		NSDictionary *action = self.swipeActions[i];
		BOOL destructive = [action[@"destructive"] boolValue];
		NSString *title = action[@"title"] ?: @"";

		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.exclusiveTouch = YES;
		button.adjustsImageWhenHighlighted = NO;
		button.titleLabel.font = font;
		[button setTitle:title forState:UIControlStateNormal];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];

		UIImage *plate = TGSwipePlateImage(destructive, NO);
		UIImage *pressed = TGSwipePlateImage(destructive, YES);
		if (plate) {
			[button setBackgroundImage:plate forState:UIControlStateNormal];
			[button setBackgroundImage:(pressed ?: plate) forState:UIControlStateHighlighted];
			if (!destructive) {
				UIColor *titleColour = [UIColor colorWithRed:0x4a / 255.0f green:0x65 / 255.0f blue:0x87 / 255.0f alpha:1.0f];
				[button setTitleColor:titleColour forState:UIControlStateNormal];
				[button setTitleShadowColor:[UIColor colorWithWhite:1.0f alpha:0.45f]
								   forState:UIControlStateNormal];
				button.titleLabel.shadowOffset = CGSizeMake(0, 1);
			} else {
				UIColor *titleShadowColour = [UIColor colorWithRed:0xa3 / 255.0f green:0x0f / 255.0f blue:0x0a / 255.0f alpha:0.2f];
				[button setTitleShadowColor:titleShadowColour forState:UIControlStateNormal];
				button.titleLabel.shadowOffset = CGSizeMake(0, -1);
			}
		} else {
			button.backgroundColor = destructive
				? [UIColor colorWithRed:0xC4 / 255.0f green:0x2B / 255.0f
								   blue:0x1E / 255.0f
								  alpha:1.0f]
				: [UIColor colorWithRed:0x8E / 255.0f green:0x9C / 255.0f
								   blue:0xAE / 255.0f
								  alpha:1.0f];
			button.layer.cornerRadius = 4;
		}

		button.tag = (NSInteger)i;
		[button addTarget:self action:@selector(swipeButtonPressed:)
			forControlEvents:UIControlEventTouchUpInside];
		[self.contentView addSubview:button];
		[_swipeButtons addObject:button];
	}
}

- (CGFloat)swipeButtonWidthForIndex:(NSUInteger)index {
	if (index >= _swipeButtons.count)
		return kSwipeButtonMinWidth;
	UIButton *button = _swipeButtons[index];
	NSString *title = [button titleForState:UIControlStateNormal] ?: @"";
	CGFloat text = [title sizeWithFont:button.titleLabel.font].width;
	return MAX(kSwipeButtonMinWidth, (int)text + 22);
}

- (void)layoutSwipeButtonsCollapsed:(BOOL)collapsed {
	CGFloat width = self.contentView.bounds.size.width;
	CGFloat top = kSwipeButtonTop;
	CGFloat right = width - kSwipeEdgeDistance;
	for (NSInteger i = _swipeButtons.count; i > 0; i--) {
		UIButton *button = _swipeButtons[i - 1];
		CGFloat buttonWidth = [self swipeButtonWidthForIndex:i - 1];
		if (collapsed)
			button.frame = TGLocalizedMirroredRect(
				CGRectMake(width - kSwipeEdgeDistance - 2, top, 2, kSwipeButtonHeight), width);
		else
			button.frame = TGLocalizedMirroredRect(
				CGRectMake(right - buttonWidth, top, buttonWidth, kSwipeButtonHeight), width);
		right -= buttonWidth + kSwipeButtonGap;
	}
}

- (void)setCoveredContentAlpha:(CGFloat)alpha {
	self.dateLabel.alpha = alpha;
	self.tick.alpha = alpha;
	self.badge.alpha = alpha;
	self.badgeBackground.alpha = alpha;
	self.pin.alpha = alpha;
	self.arrow.alpha = alpha;
	self.previewLabel.alpha = alpha;
	self.authorLabel.alpha = alpha;
	self.draftLabel.alpha = alpha;
}

- (void)setSwipeActionsVisible:(BOOL)visible animated:(BOOL)animated {
	if (visible && !self.swipeActions.count)
		return;
	if (visible == _swipeActionsVisible && (!visible || _swipeButtons.count))
		return;
	_swipeActionsVisible = visible;

	if (visible) {
		[self buildSwipeButtons];
		[self layoutSwipeButtonsCollapsed:YES];
		for (UIButton *button in _swipeButtons)
			button.alpha = 0.0f;

		__weak typeof(self) weakSelf = self;
		NSArray *coming = [_swipeButtons copy];
		void (^reveal)(void) = ^{
			[weakSelf layoutSwipeButtonsCollapsed:NO];
			for (UIButton *button in coming)
				button.alpha = 1.0f;
			[weakSelf setCoveredContentAlpha:0.0f];
		};
		if (animated)
			[UIView animateWithDuration:0.25 delay:0
								options:UIViewAnimationOptionBeginFromCurrentState
							 animations:reveal
							 completion:nil];
		else
			reveal();
		return;
	}

	__weak typeof(self) weakSelf = self;
	NSArray *going = [_swipeButtons copy];
	CGFloat rowWidth = self.contentView.bounds.size.width;
	CGFloat collapsedX = rowWidth - kSwipeEdgeDistance - 2;
	CGFloat collapsedY = kSwipeButtonTop;
	[_swipeButtons removeAllObjects];
	void (^conceal)(void) = ^{
		for (UIButton *button in going) {
			button.alpha = 0.0f;
			button.frame = TGLocalizedMirroredRect(
				CGRectMake(collapsedX, collapsedY, 2, kSwipeButtonHeight), rowWidth);
		}
		[weakSelf setCoveredContentAlpha:1.0f];
	};
	void (^drop)(BOOL) = ^(BOOL finished) {
		for (UIButton *button in going)
			[button removeFromSuperview];
	};
	if (animated)
		[UIView animateWithDuration:0.25 delay:0
							options:UIViewAnimationOptionBeginFromCurrentState
						 animations:conceal
						 completion:drop];
	else {
		conceal();
		drop(YES);
	}
}

- (void)swipeButtonPressed:(UIButton *)button {
	NSInteger index = button.tag;
	if (index < 0 || index >= (NSInteger)self.swipeActions.count)
		return;
	NSString *kind = self.swipeActions[index][@"kind"];
	if (self.onSwipeAction && kind.length)
		self.onSwipeAction(kind);
}

- (void)prepareForReuse {
	[super prepareForReuse];
	[self setSwipeActionsVisible:NO animated:NO];
	[self setCoveredContentAlpha:1.0f];
	self.chatId = 0;
	self.swipeActions = nil;
	self.onSwipeOpen = nil;
	self.onSwipeAction = nil;
}

- (void)applyHighlightAppearance:(BOOL)highlighted {
	self.badge.shadowColor = highlighted
		? [UIColor clearColor]
		: [UIColor colorWithRed:0x80 / 255.0f green:0x91 / 255.0f
						   blue:0xa6 / 255.0f
						  alpha:1.0f];
	self.badgeBackground.highlighted = highlighted;
	self.pin.highlighted = highlighted;
	self.mentionBadge.highlighted = highlighted;
	self.reactionBadge.highlighted = highlighted;
	self.titleLabel.highlighted = highlighted;
	self.previewLabel.highlighted = highlighted;
	self.authorLabel.highlighted = highlighted;
	self.arrow.highlighted = highlighted;
	self.pendingIndicator.highlighted = highlighted;
	self.errorBadge.highlighted = highlighted;
	self.muteIcon.highlighted = highlighted;
	self.tick.highlighted = highlighted;
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
	[super setHighlighted:highlighted animated:animated];
	[self applyHighlightAppearance:highlighted];
	[self applyDateAppearance];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
	[super setSelected:selected animated:animated];
	[self applyHighlightAppearance:selected || self.highlighted];
	[self applyDateAppearance];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
	if (editing && _swipeActionsVisible)
		[self setSwipeActionsVisible:NO animated:animated];
	[super setEditing:editing animated:animated];
}

- (void)applyDateAppearance {
	UIFont *main = _dateBold ? [UIFont boldSystemFontOfSize:13] : [UIFont systemFontOfSize:13];
	self.dateLabel.font = main;
	NSString *text = _dateMain ?: @"";
	UIColor *ink = (self.highlighted || self.selected) && self.dateLabel.highlightedTextColor
		? self.dateLabel.highlightedTextColor
		: (_dateBaseColor ?: self.dateLabel.textColor);

	if (!_dateSuffix.length || ![self.dateLabel respondsToSelector:@selector(setAttributedText:)]) {
		self.dateLabel.text = text;
		if (ink)
			self.dateLabel.textColor = ink;
		_dateWidth = (int)[text sizeWithFont:main].width;
		return;
	}

	NSString *whole = [text stringByAppendingString:_dateSuffix];
	NSMutableAttributedString *line = [[NSMutableAttributedString alloc] initWithString:whole];
	[line addAttribute:NSFontAttributeName value:main range:NSMakeRange(0, text.length)];
	[line addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:11]
				 range:NSMakeRange(text.length, _dateSuffix.length)];
	if (ink)
		[line addAttribute:NSForegroundColorAttributeName value:ink
					 range:NSMakeRange(0, whole.length)];
	self.dateLabel.attributedText = line;
	_dateWidth = (int)ceilf([line size].width);
}

- (void)setDateText:(NSString *)text suffix:(NSString *)suffix bold:(BOOL)bold {
	_dateMain = [text copy];
	_dateSuffix = [suffix copy];
	_dateBold = bold;
	_dateBaseColor = self.dateLabel.textColor;
	[self applyDateAppearance];
}

- (CGFloat)layoutBadgeInWidth:(CGFloat)w {
	if (!self.errorBadge.hidden) {
		self.errorBadge.frame = TGLocalizedMirroredRect(
			CGRectMake(w - 28 - kErrorBadgeWidth, 29, kErrorBadgeWidth, kErrorBadgeHeight), w);
		return kErrorBadgeWidth + 7;
	}

	CGFloat countWidth = (int)[self.badge.text sizeWithFont:self.badge.font].width;
	TGChatBadgeSlots slots = TGChatBadgeSlotsInWidth(w, countWidth, !self.badge.hidden,
		!self.mentionBadge.hidden, !self.reactionBadge.hidden, !self.pin.hidden);

	self.badgeBackground.frame = TGLocalizedMirroredRect(slots.count, w);
	self.badge.frame = TGLocalizedMirroredRect(
		CGRectMake(slots.count.origin.x, slots.count.origin.y, slots.count.size.width, 20), w);
	if (!self.mentionBadge.hidden)
		self.mentionBadge.frame = TGLocalizedMirroredRect(slots.mention, w);
	if (!self.reactionBadge.hidden)
		self.reactionBadge.frame = TGLocalizedMirroredRect(slots.reaction, w);
	if (!self.pin.hidden)
		self.pin.frame = TGLocalizedMirroredRect(slots.pin, w);

	return slots.consumedWidth;
}

- (CGFloat)layoutDraftLabelAtLeft:(CGFloat)left top:(CGFloat)top inWidth:(CGFloat)w {
	if (self.draftLabel.hidden)
		return 0;
	CGFloat draftWidth = (int)[self.draftLabel.text sizeWithFont:self.draftLabel.font].width;
	CGRect draftFrame = CGRectMake(left, top, draftWidth, MAX(18.0f, ceilf(self.draftLabel.font.lineHeight)));
	self.draftLabel.frame = TGLocalizedMirroredRect(draftFrame, w);
	return draftWidth + 4;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGFloat w = self.contentView.bounds.size.width;
	CGFloat left = kTextLeft;
	CGFloat retinaPixel = ([UIScreen mainScreen].scale > 1.5f) ? 0.5f : 0.0f;
	CGFloat rightPadding = 16;

	self.avatar.frame = TGLocalizedMirroredRect(
		CGRectMake(kAvatarLeft, 8, kAvatar, kAvatar), w);
	self.onlineDot.frame = TGLocalizedMirroredRect(
		CGRectMake(kAvatarLeft + kAvatar - 10, 8 + kAvatar - 10, 14, 14), w);

	rightPadding += [self layoutBadgeInWidth:w];

	CGFloat dateWidth = _dateWidth;
	CGFloat dateX = w - dateWidth - 9;
	self.dateLabel.frame = TGLocalizedMirroredRect(
		CGRectMake(dateX - (75 - dateWidth), 9, 75, 15), w);

	CGFloat titleX = left;
	CGFloat iconWidth = 0;
	if (!self.groupIcon.hidden) {
		iconWidth = 21;
		CGRect groupIconFrame = CGRectMake(left, 10, self.groupIcon.image.size.width, self.groupIcon.image.size.height);
		self.groupIcon.frame = TGLocalizedMirroredRect(groupIconFrame, w);
		titleX += iconWidth;
	}

	CGFloat titleWidth = (int)(dateX - 4 - left - 18) - iconWidth;
	if (!self.muteIcon.hidden)
		titleWidth -= 12;
	CGFloat premiumWidth = self.premiumIcon.hidden ? 0 : kTGChatTitlePremiumSide + 4;
	titleWidth -= premiumWidth;
	CGFloat tagWidth = 0;
	if (!self.folderTag.hidden) {
		CGFloat tagTextWidth = ceilf([self.folderTag.text sizeWithFont:self.folderTag.font].width);
		tagWidth = MIN(64, tagTextWidth + 10);
		titleWidth -= tagWidth + 6;
	}
	titleWidth = MIN(titleWidth, TGEmojiTextSize(self.titleLabel.text, self.titleLabel.font, CGSizeMake(10000, 40), NSLineBreakByWordWrapping, 1).width);
	if (titleWidth < 0)
		titleWidth = 0;
	CGFloat titleHeight = MAX(20.0f, ceilf(self.titleLabel.font.lineHeight));
	self.titleLabel.frame = TGLocalizedMirroredRect(
		CGRectMake(titleX, 6, titleWidth, titleHeight), w);

	CGFloat afterTitleX = titleX + titleWidth;
	if (!self.premiumIcon.hidden) {
		CGRect premiumFrame = CGRectMake(afterTitleX + 4,
			6 + (titleHeight - kTGChatTitlePremiumSide) / 2,
			kTGChatTitlePremiumSide, kTGChatTitlePremiumSide);
		self.premiumIcon.frame = TGLocalizedMirroredRect(premiumFrame, w);
		afterTitleX += premiumWidth;
	}
	if (!self.folderTag.hidden) {
		self.folderTag.frame = TGLocalizedMirroredRect(
			CGRectMake(afterTitleX + 6, 8, tagWidth, 16), w);
		afterTitleX += tagWidth + 6;
	}
	if (!self.muteIcon.hidden) {
		CGRect muteIconFrame = CGRectMake(afterTitleX + 3, 12, self.muteIcon.image.size.width, self.muteIcon.image.size.height);
		self.muteIcon.frame = TGLocalizedMirroredRect(muteIconFrame, w);
	}

	CGFloat previewTop = 6 + titleHeight + 3;
	CGFloat previewLeft = left + [self layoutDraftLabelAtLeft:left top:previewTop inWidth:w];
	CGRect previewFrame = CGRectMake(previewLeft, previewTop,
		w - previewLeft - 10 - rightPadding, 40);
	if (!self.authorLabel.hidden) {
		CGFloat authorHeight = MAX(20.0f, ceilf(self.authorLabel.font.lineHeight));
		CGRect authorFrame = CGRectMake(left, previewTop, w - left - 10 - rightPadding, authorHeight);
		self.authorLabel.frame = TGLocalizedMirroredRect(authorFrame, w);
		previewFrame.origin.y += authorHeight - 2;
		previewFrame.size.height -= authorHeight - 2;
	}
	CGSize previewFits = TGEmojiTextSize(self.previewLabel.text, self.previewLabel.font,
		previewFrame.size, NSLineBreakByTruncatingTail, 2);
	if (previewFits.height > 0)
		previewFrame.size.height = MIN(previewFrame.size.height,
			ceilf(previewFits.height));
	CGFloat previewBottom = kRowHeight - 9;
	if (CGRectGetMaxY(previewFrame) > previewBottom)
		previewFrame.size.height = previewBottom - previewFrame.origin.y;
	self.previewLabel.frame = TGLocalizedMirroredRect(previewFrame, w);

	if (!self.tick.hidden) {
		CGSize tickSize = self.tick.image ? self.tick.image.size : CGSizeMake(13, 11);
		CGRect tickFrame = CGRectMake(dateX - tickSize.width - 2, 11 + retinaPixel, tickSize.width, tickSize.height);
		self.tick.frame = TGLocalizedMirroredRect(tickFrame, w);
	}

	if (!self.pendingIndicator.hidden) {
		CGRect pendingFrame = CGRectMake(dateX - kPendingSide - 4, 11 + retinaPixel,
			kPendingSide, kPendingSide);
		self.pendingIndicator.frame = TGLocalizedMirroredRect(pendingFrame, w);
	}

	CGRect arrowFrame = CGRectMake(w - self.arrow.image.size.width - 6, 33, self.arrow.image.size.width, self.arrow.image.size.height);
	self.arrow.frame = TGLocalizedMirroredRect(arrowFrame, w);

	if (_swipeActionsVisible && _swipeButtons.count)
		[self layoutSwipeButtonsCollapsed:NO];
}

@end

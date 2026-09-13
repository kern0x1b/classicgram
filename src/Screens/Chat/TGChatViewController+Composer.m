#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGChatInputTextView.h"
#import "TGVideoCaptureViewController.h"
#import "TGCustomEmojiCache.h"
#import "UIView+SafeTint.h"
#import "TGClient.h"
#import "TGClient+Messages.h"
#import "TGClient+DirectMessages.h"
#import "TGClient+MessageContent.h"
#import "TGSnackbar.h"
#import "TGPendingRunShift.h"
#import "TGDiceEmoji.h"

static const CGFloat kComposerBaseTextHeight = 36.0f;
static const CGFloat kComposerHistoryFloor = 44.0f;
static const NSInteger kComposerMaxLinesTall = 4;
static const NSInteger kComposerMaxLinesWide = 2;

static UIColor *TGChatInputPlaceholderColour(void) {
	return [UIColor colorWithRed:0.616f green:0.655f blue:0.702f alpha:1.0f];
}

static CGFloat TGComposerChrome(void) {
	return kInputHeight - kComposerBaseTextHeight;
}

@implementation TGChatViewController (Composer)

- (void)buildInputBarContainer:(CGRect)b {
	self.inputBar = [[UIView alloc] initWithFrame:
			CGRectMake(0, b.size.height - kInputHeight, b.size.width, kInputHeight)];
	self.inputBar.backgroundColor = [[TGTheme shared] inputBarColour];
	self.inputBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
	self.inputBar.clipsToBounds = NO;
}

- (void)buildInputBarBackground:(CGRect)b retinaPixel:(CGFloat)retinaPixel {
	UIImage *strip = [UIImage imageNamed:@"ConversationInputPanel_Background"];
	if (strip) {
		UIImageView *stripView = [[UIImageView alloc] initWithFrame:
				CGRectMake(0, 0, b.size.width, kInputHeight)];
		stripView.image = [strip stretchableImageWithLeftCapWidth:0 topCapHeight:0];
		stripView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
			UIViewAutoresizingFlexibleHeight;
		[self.inputBar addSubview:stripView];
	}

	UIImage *shadow = [UIImage imageNamed:@"ChatInputContainer_Shadow"];
	if (shadow) {
		UIImageView *shadowView = [[UIImageView alloc] initWithFrame:
				CGRectMake(0, -shadow.size.height, b.size.width, shadow.size.height)];
		shadowView.image = [shadow stretchableImageWithLeftCapWidth:0 topCapHeight:0];
		shadowView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
			UIViewAutoresizingFlexibleBottomMargin;
		shadowView.userInteractionEnabled = NO;
		[self.inputBar addSubview:shadowView];
	} else {
		UIView *hair = [[UIView alloc] initWithFrame:CGRectMake(0, 0, b.size.width, 1)];
		hair.backgroundColor = [[TGTheme shared] separatorColour];
		hair.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[self.inputBar addSubview:hair];
	}

	UIImage *fieldArt = [UIImage imageNamed:@"ConversationInputPanel"];
	if (fieldArt) {
		UIView *plate = [[UIView alloc] initWithFrame:
				CGRectMake(40, 4 - retinaPixel, b.size.width - 106,
					kComposerBaseTextHeight)];
		plate.backgroundColor = [UIColor whiteColor];
		plate.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[self.inputBar addSubview:plate];
		self.inputPlate = plate;

		UIImageView *frameView = [[UIImageView alloc] initWithFrame:
				CGRectMake(0, 0, b.size.width, kInputHeight)];
		frameView.image = [fieldArt stretchableImageWithLeftCapWidth:55 topCapHeight:21];
		frameView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
			UIViewAutoresizingFlexibleHeight;
		frameView.userInteractionEnabled = NO;
		[self.inputBar addSubview:frameView];
	}
}

- (void)buildInputBarAttachButton:(CGRect)b retinaPixel:(CGFloat)retinaPixel {
	(void)retinaPixel;
	UIButton *attach = [UIButton buttonWithType:UIButtonTypeCustom];
	attach.frame = CGRectMake(0, 0, 41, kInputHeight);
	attach.imageEdgeInsets = UIEdgeInsetsMake(1, 0, 0, 0);
	attach.exclusiveTouch = YES;
	attach.autoresizingMask = UIViewAutoresizingFlexibleRightMargin |
		UIViewAutoresizingFlexibleTopMargin;
	UIImage *attachImage = [UIImage imageNamed:@"AttachBtn"];
	if (attachImage) {
		[attach setImage:attachImage forState:UIControlStateNormal];
		[attach setImage:[UIImage imageNamed:@"AttachBtn_Pressed"] forState:UIControlStateHighlighted];
		attach.adjustsImageWhenHighlighted = NO;
	} else {
		[attach setImage:[TGIcons attach] forState:UIControlStateNormal];
		[attach tg_setTintColor:[[TGTheme shared] accentColour]];
	}
	[attach addTarget:self action:@selector(attachTapped)
		forControlEvents:UIControlEventTouchUpInside];
	attach.accessibilityLabel = TGL(@"VoiceOver.Composer.Attach", @"Attach");
	[self.inputBar addSubview:attach];
}

- (void)buildInputBarPlaceholder:(CGRect)b retinaPixel:(CGFloat)retinaPixel {
	self.inputPlaceholder = [[UILabel alloc] initWithFrame:
			CGRectMake(49, 4 - retinaPixel, b.size.width - 158,
				kComposerBaseTextHeight)];
	self.inputPlaceholder.text = TGL(@"Conversation.InputTextPlaceholder", @"Message");
	self.inputPlaceholder.font = [UIFont systemFontOfSize:16];
	self.inputPlaceholder.textColor = TGChatInputPlaceholderColour();
	self.inputPlaceholder.backgroundColor = [UIColor clearColor];
	self.inputPlaceholder.userInteractionEnabled = NO;
	self.inputPlaceholder.autoresizingMask = UIViewAutoresizingFlexibleWidth |
		UIViewAutoresizingFlexibleBottomMargin;
	[self.inputBar addSubview:self.inputPlaceholder];
}

- (void)buildInputBarTextField:(CGRect)b retinaPixel:(CGFloat)retinaPixel {
	[self buildInputBarPlaceholder:b retinaPixel:retinaPixel];

	self.input = [[TGChatInputTextView alloc] initWithFrame:
			CGRectMake(41, 4 - retinaPixel, b.size.width - 142,
				kComposerBaseTextHeight)];
	self.input.contentInset = UIEdgeInsetsZero;
	self.input.backgroundColor = [UIColor clearColor];
	self.input.textColor = [[TGTheme shared] primaryTextColour];
	self.input.font = [UIFont systemFontOfSize:16];
	self.input.returnKeyType = UIReturnKeyDefault;
	self.input.keyboardAppearance = UIKeyboardAppearanceDefault;
	self.input.showsHorizontalScrollIndicator = NO;
	self.input.showsVerticalScrollIndicator = NO;
	self.input.scrollIndicatorInsets = UIEdgeInsetsMake(10, 0, 10, 0);
	self.input.delegate = self;
	self.input.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	__weak typeof(self) weakSelf = self;
	self.input.onTextAssigned = ^{ [weakSelf composerTextWasAssigned]; };
	[self.inputBar addSubview:self.input];

	[self measureComposerLineHeight];
}

- (void)measureComposerLineHeight {
	self.composerTextHeight = kComposerBaseTextHeight;
	self.composerLineHeight = 0;
	[self.input setText:@"A"];
	CGFloat one = self.input.contentSize.height;
	[self.input setText:@"A\nA"];
	CGFloat two = self.input.contentSize.height;
	[self.input setText:@""];
	CGFloat line = two - one;
	if (line < 4.0f || line > 60.0f)
		line = ceilf([self.input.font lineHeight]);
	self.composerLineHeight = line;
}

- (UIImage *)buildInputBarSendButton:(CGRect)b topY:(CGFloat)sendY {
	CGFloat sendWidth = 62;
	self.sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.sendButton.frame = CGRectMake(b.size.width - sendWidth - 5, sendY,
		sendWidth, 29);
	self.sendButton.exclusiveTouch = YES;
	UIImage *sendImage = [UIImage imageNamed:@"SendButton"];
	if (sendImage) {
		UIImage *sendPlate = [sendImage stretchableImageWithLeftCapWidth:(int)(sendImage.size.width / 2) topCapHeight:0];
		[self.sendButton setBackgroundImage:sendPlate forState:UIControlStateNormal];
		UIImage *sendPressed = [UIImage imageNamed:@"SendButton_Pressed"];
		if (sendPressed) {
			UIImage *pressedPlate = [sendPressed stretchableImageWithLeftCapWidth:(int)(sendPressed.size.width / 2) topCapHeight:0];
			[self.sendButton setBackgroundImage:pressedPlate forState:UIControlStateHighlighted];
		}
	} else {
		self.sendButton.backgroundColor = [[TGTheme shared] accentColour];
		self.sendButton.layer.cornerRadius = 4;
	}
	[self.sendButton setTitle:TGL(@"MediaPicker.Send", @"Send") forState:UIControlStateNormal];
	[self.sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	UIColor *titleShadowInk = [UIColor colorWithRed:0.047f green:0.722f blue:0.890f alpha:0.3f];
	[self.sendButton setTitleShadowColor:titleShadowInk forState:UIControlStateNormal];
	self.sendButton.titleLabel.font = [UIFont boldSystemFontOfSize:14.5f];
	self.sendButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
	self.sendButton.titleEdgeInsets = UIEdgeInsetsMake(1.5f, 0, 2, 0);
	UIColor *disabledInk = [UIColor colorWithRed:0.808f green:1.0f blue:0.690f alpha:1.0f];
	[self.sendButton setTitleColor:disabledInk forState:UIControlStateDisabled];
	self.sendButton.adjustsImageWhenHighlighted = NO;
	self.sendButton.adjustsImageWhenDisabled = NO;
	self.sendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
		UIViewAutoresizingFlexibleTopMargin;
	[self.sendButton addTarget:self action:@selector(sendTapped)
			  forControlEvents:UIControlEventTouchUpInside];
	[self.inputBar addSubview:self.sendButton];
	return sendImage;
}

static UIImage *TGChatStickerGlyph(UIColor *colour) {
	const CGFloat box = 24.0f;
	const CGFloat inset = 3.0f;
	const CGFloat corner = 4.5f;
	const CGFloat fold = 7.0f;
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(box, box), NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextSetLineWidth(ctx, 1.5f);
	CGContextSetLineCap(ctx, kCGLineCapRound);
	CGContextSetLineJoin(ctx, kCGLineJoinRound);
	[colour setStroke];

	CGFloat left = inset;
	CGFloat top = inset;
	CGFloat right = box - inset;
	CGFloat bottom = box - inset;

	UIBezierPath *body = [UIBezierPath bezierPath];
	[body moveToPoint:CGPointMake(left + corner, top)];
	[body addLineToPoint:CGPointMake(right - corner, top)];
	[body addArcWithCenter:CGPointMake(right - corner, top + corner)
					radius:corner
				startAngle:(CGFloat)(-M_PI / 2.0)
				  endAngle:0.0f
				 clockwise:YES];
	[body addLineToPoint:CGPointMake(right, bottom - fold)];
	[body addLineToPoint:CGPointMake(right - fold, bottom)];
	[body addLineToPoint:CGPointMake(left + corner, bottom)];
	[body addArcWithCenter:CGPointMake(left + corner, bottom - corner)
					radius:corner
				startAngle:(CGFloat)(M_PI / 2.0)
				  endAngle:(CGFloat)M_PI
				 clockwise:YES];
	[body addLineToPoint:CGPointMake(left, top + corner)];
	[body addArcWithCenter:CGPointMake(left + corner, top + corner)
					radius:corner
				startAngle:(CGFloat)M_PI
				  endAngle:(CGFloat)(-M_PI / 2.0)
				 clockwise:YES];
	CGContextAddPath(ctx, body.CGPath);
	CGContextStrokePath(ctx);

	UIBezierPath *flap = [UIBezierPath bezierPath];
	[flap moveToPoint:CGPointMake(right - fold, bottom)];
	[flap addLineToPoint:CGPointMake(right - fold, bottom - fold)];
	[flap addLineToPoint:CGPointMake(right, bottom - fold)];
	CGContextAddPath(ctx, flap.CGPath);
	CGContextStrokePath(ctx);

	UIImage *glyph = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return glyph;
}

- (void)buildInputBarStickerButton:(CGRect)b retinaPixel:(CGFloat)retinaPixel {
	(void)retinaPixel;
	self.stickerButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.stickerButton.frame = CGRectMake(b.size.width - 109, 0, 39, kInputHeight);
	self.stickerButton.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 2);
	self.stickerButton.exclusiveTouch = YES;
	UIColor *stickerInk = [UIColor colorWithRed:0.616f green:0.655f blue:0.702f alpha:1.0f];
	[self.stickerButton setImage:TGChatStickerGlyph(stickerInk)
						forState:UIControlStateNormal];
	[self.stickerButton setImage:TGChatStickerGlyph([[TGTheme shared] accentColour])
						forState:UIControlStateHighlighted];
	self.stickerButton.accessibilityLabel = TGL(@"VoiceOver.Composer.Stickers", @"Stickers");
	self.stickerButton.adjustsImageWhenHighlighted = NO;
	self.stickerButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
		UIViewAutoresizingFlexibleTopMargin;
	[self.stickerButton addTarget:self action:@selector(toggleStickerPanel)
				 forControlEvents:UIControlEventTouchUpInside];
	[self.inputBar addSubview:self.stickerButton];
}

- (void)buildInputBarMicButton:(UIImage *)sendImage {
	self.micButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.micButton.frame = self.sendButton.frame;
	self.micButton.exclusiveTouch = YES;
	if (sendImage) {
		UIImage *micPlate = [sendImage stretchableImageWithLeftCapWidth:(int)(sendImage.size.width / 2) topCapHeight:0];
		[self.micButton setBackgroundImage:micPlate forState:UIControlStateNormal];
		UIImage *micPressed = [UIImage imageNamed:@"SendButton_Pressed"];
		if (micPressed) {
			UIImage *micPressedPlate = [micPressed stretchableImageWithLeftCapWidth:(int)(micPressed.size.width / 2) topCapHeight:0];
			[self.micButton setBackgroundImage:micPressedPlate forState:UIControlStateHighlighted];
		}
		self.micButton.adjustsImageWhenHighlighted = NO;
	}
	self.micButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
		UIViewAutoresizingFlexibleTopMargin;
	[self applyMicButtonGlyph];

	[self.micButton addTarget:self action:@selector(micTapped)
			 forControlEvents:UIControlEventTouchUpInside];

	self.micHold = [[UILongPressGestureRecognizer alloc]
		initWithTarget:self
				action:@selector(micHeld:)];
	self.micHold.minimumPressDuration = 0.18;
	self.micHold.allowableMovement = CGFLOAT_MAX;
	[self.micButton addGestureRecognizer:self.micHold];

	[self.inputBar addSubview:self.micButton];
}

static UIImage *TGChatVideoNoteGlyph(UIColor *colour, CGFloat side) {
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	[colour setFill];

	CGFloat bodyWidth = side * 0.66f;
	CGFloat bodyHeight = side * 0.58f;
	CGRect body = CGRectMake(side * 0.06f, (side - bodyHeight) / 2, bodyWidth, bodyHeight);
	UIBezierPath *shell = [UIBezierPath bezierPathWithRoundedRect:body cornerRadius:side * 0.14f];
	CGContextAddPath(ctx, shell.CGPath);
	CGContextFillPath(ctx);

	UIBezierPath *lens = [UIBezierPath bezierPath];
	[lens moveToPoint:CGPointMake(CGRectGetMaxX(body) + side * 0.04f, side / 2)];
	[lens addLineToPoint:CGPointMake(side * 0.94f, side * 0.25f)];
	[lens addLineToPoint:CGPointMake(side * 0.94f, side * 0.75f)];
	[lens closePath];
	CGContextAddPath(ctx, lens.CGPath);
	CGContextFillPath(ctx);

	UIImage *glyph = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return glyph;
}

- (void)applyMicButtonGlyph {
	BOOL onPlate = ([self.micButton backgroundImageForState:UIControlStateNormal] != nil);
	UIColor *ink = onPlate ? [UIColor whiteColor] : [[TGTheme shared] secondaryTextColour];
	UIImage *glyph = self.videoNoteMode
		? TGChatVideoNoteGlyph(ink, 21)
		: [TGIcons microphoneOfSide:22 colour:ink];
	[self.micButton setImage:glyph forState:UIControlStateNormal];
	self.micButton.accessibilityLabel = self.videoNoteMode
		? TGL(@"VoiceOver.Chat.RecordModeVideoMessage", @"Video message")
		: TGL(@"VoiceOver.Composer.RecordVoiceMessage", @"Record voice message");
}

- (void)micTapped {
	if (self.micDidRecord) {
		self.micDidRecord = NO;
		return;
	}
	if (self.videoNoteMode)
		self.videoNoteMode = NO;
	else
		self.videoNoteMode = ([self videoCaptureClass] != Nil);
	[self applyMicButtonGlyph];
}

- (void)micHeld:(UILongPressGestureRecognizer *)hold {
	if (hold.state == UIGestureRecognizerStateBegan) {
		self.micDidRecord = YES;
		if (self.videoNoteMode) {
			self.micHoldOrigin = [hold locationInView:self.view];
			[self captureVideoRound:YES];
			[self.videoNoteShooter beginHold];
		} else {
			[self recordStart];
		}
		return;
	}

	if (self.videoNoteMode) {
		TGVideoCaptureViewController *shooter = self.videoNoteShooter;
		CGPoint where = [hold locationInView:self.view];
		CGPoint offset = CGPointMake(where.x - self.micHoldOrigin.x,
			where.y - self.micHoldOrigin.y);
		if (hold.state == UIGestureRecognizerStateChanged) {
			[shooter holdMovedBy:offset];
			return;
		}
		if (hold.state == UIGestureRecognizerStateEnded)
			[shooter endHold];
		else
			[shooter cancelHold];
		self.micDidRecord = NO;
		return;
	}

	if (hold.state == UIGestureRecognizerStateEnded) {
		CGPoint where = [hold locationInView:self.micButton];
		if (CGRectContainsPoint(CGRectInset(self.micButton.bounds, -20, -20), where))
			[self recordFinish];
		else
			[self recordCancel];
		self.micDidRecord = NO;
	} else if (hold.state == UIGestureRecognizerStateCancelled ||
		hold.state == UIGestureRecognizerStateFailed) {
		[self recordCancel];
		self.micDidRecord = NO;
	}
}

- (void)buildInputBar:(CGRect)b {
	const CGFloat retinaPixel = ([UIScreen mainScreen].scale > 1.0f) ? 0.5f : 0.0f;

	[self buildInputBarContainer:b];
	[self buildInputBarBackground:b retinaPixel:retinaPixel];

	CGFloat sendY = 7 + retinaPixel;

	[self buildInputBarAttachButton:b retinaPixel:retinaPixel];
	[self buildInputBarTextField:b retinaPixel:retinaPixel];

	UIImage *sendImage = [self buildInputBarSendButton:b topY:sendY];

	[self buildInputBarStickerButton:b retinaPixel:retinaPixel];
	[self buildInputBarMicButton:sendImage];

	self.sendButton.hidden = YES;
	self.micButton.hidden = NO;
	[self inputChanged];
	[self layoutComposerSubviews];

	[self.view addSubview:self.inputBar];
}

#pragma mark - composer height

- (CGFloat)inputBarHeight {
	CGFloat text = (self.composerTextHeight > 1) ? self.composerTextHeight
												 : kComposerBaseTextHeight;
	return TGComposerChrome() + text;
}

- (NSInteger)composerMaxLines {
	CGRect b = self.view.bounds;
	NSInteger wanted = (b.size.height >= b.size.width) ? kComposerMaxLinesTall : kComposerMaxLinesWide;
	if (TGChatIsPad())
		wanted = kComposerMaxLinesTall;
	CGFloat line = (self.composerLineHeight > 1) ? self.composerLineHeight : 19.0f;
	CGFloat room = b.size.height - self.keyboardInset - TGComposerChrome() -
		kComposerBaseTextHeight - kComposerHistoryFloor;
	NSInteger fits = 1 + (NSInteger)floorf(room / line);
	if (fits < 1)
		fits = 1;
	return MIN(wanted, fits);
}

- (CGFloat)composerTextHeightForContent:(CGFloat)content {
	CGFloat line = (self.composerLineHeight > 1) ? self.composerLineHeight : 19.0f;
	NSInteger lines = 1;
	if (content > kComposerBaseTextHeight)
		lines += (NSInteger)floorf((content - kComposerBaseTextHeight) / line + 0.5f);
	if (lines < 1)
		lines = 1;
	NSInteger cap = [self composerMaxLines];
	if (lines > cap)
		lines = cap;
	return kComposerBaseTextHeight + (lines - 1) * line;
}

- (void)layoutComposerSubviews {
	if (!self.input)
		return;
	const CGFloat retinaPixel = ([UIScreen mainScreen].scale > 1.0f) ? 0.5f : 0.0f;
	CGFloat width = self.inputBar.bounds.size.width;
	CGFloat text = (self.composerTextHeight > 1) ? self.composerTextHeight
												 : kComposerBaseTextHeight;
	self.inputPlate.frame = CGRectMake(40, 4 - retinaPixel, width - 106, text);
	self.input.frame = CGRectMake(41, 4 - retinaPixel, width - 142, text);
	self.inputPlaceholder.frame = CGRectMake(49, 4 - retinaPixel, width - 158,
		kComposerBaseTextHeight);
}

- (void)remeasureComposerForNewWidth {
	if (!self.input)
		return;
	[self layoutComposerSubviews];
	if (!self.input.text.length) {
		[self updateComposerHeightAnimated:NO];
		return;
	}
	NSRange caret = self.input.selectedRange;
	self.input.text = [self.input.text copy];
	self.input.selectedRange = caret;
}

- (void)updateComposerHeightAnimated:(BOOL)animated {
	if (!self.input || self.composerLineHeight <= 0)
		return;
	self.inputPlaceholder.hidden = (self.input.text.length > 0);

	CGFloat content = self.input.contentSize.height;
	CGFloat wanted = [self composerTextHeightForContent:content];
	BOOL scrolls = (content > wanted + 1.0f);
	self.input.showsVerticalScrollIndicator = scrolls;
	if (!scrolls)
		self.input.contentOffset = CGPointZero;

	if (fabsf(wanted - self.composerTextHeight) < 0.5f) {
		[self layoutComposerSubviews];
		return;
	}
	self.composerTextHeight = wanted;
	[self layoutChatStackAnimated:animated duration:0.2
							curve:UIViewAnimationCurveEaseInOut];
}

- (void)textViewDidChange:(UITextView *)textView {
	[self updateComposerHeightAnimated:YES];
	[self inputChanged];
	if (textView == self.input)
		[self refreshComposerCustomEmojiOverlay];
}

- (void)composerTextWasAssigned {
	[self updateComposerHeightAnimated:NO];
	[self updateComposerButtons];
	[self refreshComposerCustomEmojiOverlay];
}

- (void)simulateComposerText:(NSString *)text {
	if (!self.input || self.inputBar.hidden)
		return;
	[self.input becomeFirstResponder];
	self.input.text = text ?: @"";
	[self composerTextWasAssigned];
}

- (void)refreshComposerCustomEmojiOverlay {
	for (UIView *view in self.composerCustomEmojiOverlayViews)
		[view removeFromSuperview];
	[self.composerCustomEmojiOverlayViews removeAllObjects];

	if (!self.input || self.pendingCustomEmojiRuns.count == 0)
		return;

	NSString *text = self.input.text ?: @"";
	NSInteger length = text.length;

	for (NSDictionary *entry in self.pendingCustomEmojiRuns) {
		NSRange range = [entry[@"range"] rangeValue];
		if (NSMaxRange(range) > length)
			continue;
		NSString *glyph = entry[@"glyph"];
		if (![glyph isKindOfClass:NSString.class] || !glyph.length)
			continue;
		if (![[text substringWithRange:range] isEqualToString:glyph])
			continue;

		long long customEmojiId = [entry[@"customEmojiId"] longLongValue];
		if (customEmojiId == 0)
			continue;

		UIImage *image = TGCustomEmojiCachedImage(customEmojiId);
		if (!image) {
			TGCustomEmojiRequestImage(customEmojiId);
			continue;
		}

		UITextPosition *start = [self.input positionFromPosition:self.input.beginningOfDocument offset:(NSInteger)range.location];
		UITextPosition *end = start ? [self.input positionFromPosition:start offset:(NSInteger)range.length] : nil;
		UITextRange *textRange = (start && end) ? [self.input textRangeFromPosition:start toPosition:end] : nil;
		if (!textRange)
			continue;

		CGRect rect = [self.input firstRectForRange:textRange];
		if (CGRectIsNull(rect) || rect.size.width <= 0 || rect.size.height <= 0)
			continue;

		UIImageView *overlay = [[UIImageView alloc] initWithFrame:rect];
		overlay.image = image;
		overlay.contentMode = UIViewContentModeScaleAspectFit;
		overlay.userInteractionEnabled = NO;
		[self.input addSubview:overlay];
		[self.composerCustomEmojiOverlayViews addObject:overlay];
	}
}

static NSMutableArray *TGShiftPendingRuns(NSArray *runs, NSRange range, NSInteger newLength) {
	NSMutableArray *kept = [NSMutableArray array];
	for (NSDictionary *entry in runs) {
		NSRange oldRange = [entry[@"range"] rangeValue];
		NSValue *updatedRange = TGPendingRunRangeAfterEdit(oldRange, range, newLength);
		if (!updatedRange)
			continue;
		NSMutableDictionary *updated = [entry mutableCopy];
		updated[@"range"] = updatedRange;
		[kept addObject:updated];
	}
	return kept;
}

- (void)adjustPendingCustomEmojiForRange:(NSRange)range replacementLength:(NSInteger)newLength {
	self.pendingCustomEmojiRuns = TGShiftPendingRuns(self.pendingCustomEmojiRuns, range, newLength);
}

- (void)adjustPendingMentionRunsForRange:(NSRange)range replacementLength:(NSInteger)newLength {
	self.pendingMentionRuns = TGShiftPendingRuns(self.pendingMentionRuns, range, newLength);
}

- (NSArray *)customEmojiEntitiesForOriginalText:(NSString *)original
									 sentAsText:(NSString *)sent {
	if (self.pendingCustomEmojiRuns.count == 0 || !original.length || !sent.length)
		return nil;

	NSInteger leadingTrim = 0;
	NSCharacterSet *trimSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	while (leadingTrim < original.length &&
		[trimSet characterIsMember:[original characterAtIndex:leadingTrim]])
		leadingTrim++;

	NSMutableArray *entities = [NSMutableArray array];
	for (NSDictionary *entry in self.pendingCustomEmojiRuns) {
		NSRange range = [entry[@"range"] rangeValue];
		if (NSMaxRange(range) > original.length || range.location < leadingTrim)
			continue;

		NSString *glyph = entry[@"glyph"];
		if (![glyph isKindOfClass:NSString.class] || !glyph.length)
			continue;
		if (![[original substringWithRange:range] isEqualToString:glyph])
			continue;

		NSRange shifted = NSMakeRange(range.location - leadingTrim, range.length);
		if (NSMaxRange(shifted) > sent.length ||
			![[sent substringWithRange:shifted] isEqualToString:glyph])
			continue;

		long long customEmojiId = [entry[@"customEmojiId"] longLongValue];
		if (customEmojiId == 0)
			continue;

		[entities addObject:TGCustomEmojiEntity((NSInteger)shifted.location,
								(NSInteger)shifted.length,
								customEmojiId)];
	}
	return entities.count ? entities : nil;
}

- (NSArray *)mentionNameEntitiesForOriginalText:(NSString *)original
									  sentAsText:(NSString *)sent {
	if (self.pendingMentionRuns.count == 0 || !original.length || !sent.length)
		return nil;

	NSInteger leadingTrim = 0;
	NSCharacterSet *trimSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	while (leadingTrim < original.length &&
		[trimSet characterIsMember:[original characterAtIndex:leadingTrim]])
		leadingTrim++;

	NSMutableArray *entities = [NSMutableArray array];
	for (NSDictionary *entry in self.pendingMentionRuns) {
		NSRange range = [entry[@"range"] rangeValue];
		if (NSMaxRange(range) > original.length || range.location < leadingTrim)
			continue;

		NSString *mentionText = entry[@"text"];
		if (![mentionText isKindOfClass:NSString.class] || !mentionText.length)
			continue;
		if (![[original substringWithRange:range] isEqualToString:mentionText])
			continue;

		NSRange shifted = NSMakeRange(range.location - leadingTrim, range.length);
		if (NSMaxRange(shifted) > sent.length ||
			![[sent substringWithRange:shifted] isEqualToString:mentionText])
			continue;

		int64_t userId = [entry[@"userId"] longLongValue];
		if (userId == 0)
			continue;

		[entities addObject:TGMentionNameEntity((NSInteger)shifted.location,
								(NSInteger)shifted.length,
								userId)];
	}
	return entities.count ? entities : nil;
}

- (void)seedPendingStyleEntitiesFromMessage:(NSDictionary *)m {
	NSMutableArray *runs = [NSMutableArray array];
	for (NSDictionary *entity in [self originalEntitiesOf:m]) {
		if (![entity isKindOfClass:NSDictionary.class])
			continue;
		NSInteger offset = [entity[@"offset"] integerValue];
		NSInteger length = [entity[@"length"] integerValue];
		if (length <= 0)
			continue;
		NSMutableDictionary *run = [entity mutableCopy];
		run[@"range"] = [NSValue valueWithRange:NSMakeRange((NSUInteger)offset, (NSUInteger)length)];
		[runs addObject:run];
	}
	self.pendingStyleEntities = runs;
}

- (void)adjustPendingStyleEntitiesForRange:(NSRange)range replacementLength:(NSInteger)newLength {
	self.pendingStyleEntities = TGShiftPendingRuns(self.pendingStyleEntities, range, newLength);
}

- (NSArray *)styleEntitiesForOriginalText:(NSString *)original
								sentAsText:(NSString *)sent {
	if (self.pendingStyleEntities.count == 0 || !original.length || !sent.length)
		return nil;

	NSInteger leadingTrim = 0;
	NSCharacterSet *trimSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	while (leadingTrim < original.length &&
		[trimSet characterIsMember:[original characterAtIndex:leadingTrim]])
		leadingTrim++;

	NSMutableArray *flattened = [NSMutableArray array];
	for (NSDictionary *entry in self.pendingStyleEntities) {
		NSRange range = [entry[@"range"] rangeValue];
		if (NSMaxRange(range) > original.length || range.location < leadingTrim)
			continue;

		NSRange shifted = NSMakeRange(range.location - leadingTrim, range.length);
		if (NSMaxRange(shifted) > sent.length)
			continue;

		NSMutableDictionary *entity = [entry mutableCopy];
		entity[@"offset"] = @(shifted.location);
		entity[@"length"] = @(shifted.length);
		[entity removeObjectForKey:@"range"];
		[flattened addObject:entity];
	}
	return flattened.count ? flattened : nil;
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range
			replacementText:(NSString *)text {
	if (textView == self.input) {
		[self adjustPendingCustomEmojiForRange:range replacementLength:(NSInteger)text.length];
		[self adjustPendingMentionRunsForRange:range replacementLength:(NSInteger)text.length];
		[self adjustPendingStyleEntitiesForRange:range replacementLength:(NSInteger)text.length];
	}
	return YES;
}

static NSArray *TGCombinedComposerEntities(NSArray *customEmojiEntities, NSArray *mentionEntities,
	NSArray *styleWireEntities) {
	NSMutableArray *combinedEntities = [NSMutableArray array];
	if (customEmojiEntities.count > 0)
		[combinedEntities addObjectsFromArray:customEmojiEntities];
	if (mentionEntities.count > 0)
		[combinedEntities addObjectsFromArray:mentionEntities];
	if (styleWireEntities.count > 0)
		[combinedEntities addObjectsFromArray:styleWireEntities];
	return combinedEntities;
}

- (void)sendTapped {
	NSString *original = self.input.text ?: @"";
	NSString *text = [original stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!text.length)
		return;

	if (self.postingBlocked)
		return;

	if (self.editingId == 0 && [self blockSendForSlowMode])
		return;

	if (self.editingId == 0 && self.directMessagesTopicId == 0 && self.replyToId == 0 &&
		TGComposerTextIsSendableDiceEmoji(text)) {
		self.input.text = @"";
		[self.pendingCustomEmojiRuns removeAllObjects];
		[self.pendingMentionRuns removeAllObjects];
		if (self.stickerPanel)
			[self toggleStickerPanel];
		[[TGClient shared] sendDice:text
							 toChat:self.chatId
							 thread:self.threadId
				directMessagesTopic:self.directMessagesTopicId
						 savedTopic:self.savedTopicId];
		[[TGClient shared] clearDraftInChat:self.chatId thread:self.threadId
			directMessagesTopic:self.directMessagesTopicId savedTopic:self.savedTopicId];
		[self recomputeComposerState];
		[self clearComposeState];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
			dispatch_get_main_queue(), ^{
				[self reload];
			});
		return;
	}

	[[TGClient shared] sendChatAction:@"cancel" toChat:self.chatId thread:self.threadId];
	self.lastTypingSent = nil;

	NSArray *customEmojiEntities = [self customEmojiEntitiesForOriginalText:original sentAsText:text];
	NSArray *mentionEntities = [self mentionNameEntitiesForOriginalText:original sentAsText:text];
	NSArray *styleWireEntities =
		TGWireEntitiesFromFlattened([self styleEntitiesForOriginalText:original sentAsText:text]);
	self.input.text = @"";
	[self.pendingCustomEmojiRuns removeAllObjects];
	[self.pendingMentionRuns removeAllObjects];
	[self.pendingStyleEntities removeAllObjects];
	if (self.stickerPanel)
		[self toggleStickerPanel];

	if (self.editingId != 0) {
		__weak typeof(self) weakSelf = self;
		void (^editCompletion)(BOOL) = ^(BOOL ok) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (ok) {
				[strongSelf clearComposeState];
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
					dispatch_get_main_queue(), ^{
						[strongSelf reload];
					});
				return;
			}
			strongSelf.input.text = text;
			[strongSelf inputChanged];
			[TGSnackbar showInView:strongSelf.view
							  text:TGL(@"Toast.CouldNotSaveEditedMessage", @"Could not save the edited message")
						   seconds:3
						  onCommit:nil];
		};
		NSArray *combinedEntities = TGCombinedComposerEntities(customEmojiEntities, mentionEntities,
			styleWireEntities);

		if (self.editingIsCaption) {
			if (self.markdownComposing && combinedEntities.count > 0)
				[TGSnackbar showInView:self.view
								  text:TGL(@"Chat.SentAsPlainTextFormattingNeeds", @"Sent as plain text: formatting needs a plain send")
							   seconds:3
							  onCommit:nil];
			[[TGClient shared] editCaptionOfMessage:self.editingId inChat:self.chatId
											caption:text
										   entities:combinedEntities
						  showCaptionAboveMedia:self.editingCaptionAboveMedia
										 completion:editCompletion];
		} else {
			if (self.markdownComposing && combinedEntities.count == 0) {
				[[TGClient shared] editMessageWithMarkdown:self.editingId inChat:self.chatId
													   text:text
										 linkPreviewOptions:self.editingLinkPreviewOptions
												 completion:editCompletion];
			} else {
				if (self.markdownComposing)
					[TGSnackbar showInView:self.view
									  text:TGL(@"Chat.SentAsPlainTextFormattingNeeds", @"Sent as plain text: formatting needs a plain send")
								   seconds:3
								  onCommit:nil];
				[[TGClient shared] editMessage:self.editingId inChat:self.chatId text:text
									   entities:combinedEntities
							 linkPreviewOptions:self.editingLinkPreviewOptions
									 completion:editCompletion];
			}
		}
		return;
	}

	BOOL isSchedulingThisSend = self.scheduledSendDate != 0 || self.scheduleWhenOnline;
	NSString *pendingEffectEmojiSnapshot = self.pendingEffectEmoji;
	__weak typeof(self) weakSelf = self;
	void (^sendCompletion)(NSDictionary *) = !isSchedulingThisSend ? nil : ^(NSDictionary *message) {
		if (message)
			return;
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf showAlertTitle:@"" message:TGL(@"Toast.CouldNotSendScheduledMessage", @"Could not send the scheduled message")];
	};

	if (self.directMessagesTopicId != 0) {
		NSMutableDictionary *options = [([self sendOptionsDictionary] ?: @{}) mutableCopy];
		NSMutableArray *combinedEntities = [NSMutableArray array];
		if (customEmojiEntities.count > 0)
			[combinedEntities addObjectsFromArray:customEmojiEntities];
		if (mentionEntities.count > 0)
			[combinedEntities addObjectsFromArray:mentionEntities];
		if (combinedEntities.count > 0)
			options[@"entities"] = combinedEntities;
		if (self.replyToId != 0 && self.replyQuoteEntities.count > 0)
			options[@"quoteEntities"] = self.replyQuoteEntities;
		if (options.count == 0)
			options = nil;

		if (self.markdownComposing)
			[TGSnackbar showInView:self.view
							  text:TGL(@"Chat.SentAsPlainTextFormattingNeeds", @"Sent as plain text: formatting needs a plain send")
						   seconds:3
						  onCommit:nil];

		[[TGClient shared] sendText:text toChat:self.chatId
				directMessagesTopic:self.directMessagesTopicId
							replyTo:self.replyToId
						  quoteText:self.replyQuoteText
					  quotePosition:self.replyQuotePosition
							options:options
						 completion:sendCompletion];
	} else if (self.replyToId != 0 && self.replyQuoteText.length) {
		NSMutableDictionary *options = [([self sendOptionsDictionary] ?: @{}) mutableCopy];
		NSMutableArray *combinedEntities = [NSMutableArray array];
		if (customEmojiEntities.count > 0)
			[combinedEntities addObjectsFromArray:customEmojiEntities];
		if (mentionEntities.count > 0)
			[combinedEntities addObjectsFromArray:mentionEntities];
		if (combinedEntities.count > 0)
			options[@"entities"] = combinedEntities;
		if (self.replyQuoteEntities.count > 0)
			options[@"quoteEntities"] = self.replyQuoteEntities;
		if (options.count == 0)
			options = nil;

		if (self.markdownComposing)
			[TGSnackbar showInView:self.view
							  text:TGL(@"Chat.SentAsPlainTextFormattingNeeds", @"Sent as plain text: formatting needs a plain send")
						   seconds:3
						  onCommit:nil];

		[[TGClient shared] sendText:text toChat:self.chatId
							 thread:self.threadId
						 savedTopic:self.savedTopicId
							replyTo:self.replyToId
						  quoteText:self.replyQuoteText
					  quotePosition:self.replyQuotePosition
							options:options
						 completion:sendCompletion];
	} else {
		NSMutableDictionary *options = [([self sendOptionsDictionary] ?: @{}) mutableCopy];
		NSMutableArray *combinedEntities = [NSMutableArray array];
		if (customEmojiEntities.count > 0)
			[combinedEntities addObjectsFromArray:customEmojiEntities];
		if (mentionEntities.count > 0)
			[combinedEntities addObjectsFromArray:mentionEntities];
		if (combinedEntities.count > 0)
			options[@"entities"] = combinedEntities;
		if (options.count == 0)
			options = nil;

		if (self.markdownComposing && !options) {
			[[TGClient shared] sendMarkdown:text toChat:self.chatId
									 thread:self.threadId
						directMessagesTopic:self.directMessagesTopicId
								 savedTopic:self.savedTopicId
									replyTo:self.replyToId];
		} else if (self.markdownComposing && options) {
			[TGSnackbar showInView:self.view
							  text:TGL(@"Chat.SentAsPlainTextFormattingNeeds", @"Sent as plain text: formatting needs a plain send")
						   seconds:3
						  onCommit:nil];
			[[TGClient shared] sendText:text toChat:self.chatId
								 thread:self.threadId
							 savedTopic:self.savedTopicId
								replyTo:self.replyToId
								options:options
							 completion:sendCompletion];
		} else if (options)
			[[TGClient shared] sendText:text toChat:self.chatId
								 thread:self.threadId
							 savedTopic:self.savedTopicId
								replyTo:self.replyToId
								options:options
							 completion:sendCompletion];
		else
			[[TGClient shared] sendText:text toChat:self.chatId
								 thread:self.threadId
							 savedTopic:self.savedTopicId
								replyTo:self.replyToId];
	}

	if (self.scheduledSendDate != 0 || self.scheduleWhenOnline) {
		self.scheduledSendDate = 0;
		self.scheduleWhenOnline = NO;
		[self loadScheduledMessages];
	}

	if (self.editingId == 0 && pendingEffectEmojiSnapshot.length)
		[self playEffectBurstWithEmoji:pendingEffectEmojiSnapshot];

	if (self.editingId == 0) {
		[[TGClient shared] clearDraftInChat:self.chatId thread:self.threadId
			directMessagesTopic:self.directMessagesTopicId savedTopic:self.savedTopicId];
		[self recomputeComposerState];
	}
	[self clearComposeState];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			[self reload];
		});
}

@end

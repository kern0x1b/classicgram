#import "TGBubbleCellBase.h"
#import "TGMessageItem.h"
#import "TGMessageLayout.h"
#import "TGQuoteBadgeView.h"
#import "TGLinkPreviewView.h"
#import "TGReactionPickerView.h"
#import "TGProfileViewController.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGIcons.h"
#import <QuartzCore/QuartzCore.h>

extern UIColor *TGMessageDateColour(void);
extern UIImage *TGViewsEyeImage(UIColor *tint);
extern UIColor *TGSenderColour(int64_t userId);
extern UIColor *TGActiveChatThemeBubbleMineColour(int64_t chatId);
extern UIColor *TGActiveChatThemeAccentColour(int64_t chatId);

static const CGFloat kBubbleCellArtworkTailOverhang = 6.0f;
static const CGFloat kBubbleCellArtworkMinW = 40.0f;
static const CGFloat kBubbleCellArtworkMinH = 31.0f;
static const CGFloat kBubbleCellPlateFallbackCornerRadius = 10.5f;
static const CGFloat kBubbleCellSenderAvatarCornerFactor = 0.5f;
static UIColor *TGBubbleStampColour(void) {
	return [UIColor colorWithRed:0x23 / 255.0f
						   green:0x2d / 255.0f
							blue:0x37 / 255.0f
						   alpha:1.0f];
}
static UIImage *TGBubbleClockGlyph(void) {
	static UIImage *cached;
	if (cached)
		return cached;
	UIImage *frame = [UIImage imageNamed:@"ClockFrame.png"];
	UIImage *hour = [UIImage imageNamed:@"ClockHour.png"];
	UIImage *minute = [UIImage imageNamed:@"ClockMin.png"];
	CGSize size = CGSizeMake(15, 9);
	UIGraphicsBeginImageContextWithOptions(size, NO, 0);
	if (frame) {
		CGRect face = CGRectMake(5.5f, 0.0f, 9.0f, 9.0f);
		[frame drawInRect:face];
		[hour drawInRect:face];
		[minute drawInRect:face];
	} else {
		CGContextRef ctx = UIGraphicsGetCurrentContext();
		CGContextSetStrokeColorWithColor(ctx, TGBubbleStampColour().CGColor);
		CGContextSetLineWidth(ctx, 1.0f);
		CGContextStrokeEllipseInRect(ctx, CGRectMake(5.5f, 0.5f, 8, 8));
		CGContextMoveToPoint(ctx, 9.5f, 4.5f);
		CGContextAddLineToPoint(ctx, 9.5f, 2.0f);
		CGContextMoveToPoint(ctx, 9.5f, 4.5f);
		CGContextAddLineToPoint(ctx, 11.5f, 5.5f);
		CGContextStrokePath(ctx);
	}
	cached = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return cached;
}
static UIImage *TGBubbleFailedGlyph(void) {
	static UIImage *cached;
	if (cached)
		return cached;
	CGSize size = CGSizeMake(15, 9);
	UIGraphicsBeginImageContextWithOptions(size, NO, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	UIColor *red = [UIColor colorWithRed:0.78f green:0.16f blue:0.13f alpha:1.0f];
	CGContextSetFillColorWithColor(ctx, red.CGColor);
	CGContextFillEllipseInRect(ctx, CGRectMake(5.5f, 0.5f, 8, 8));
	CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
	CGContextFillRect(ctx, CGRectMake(9.0f, 2.0f, 1, 3.5f));
	CGContextFillRect(ctx, CGRectMake(9.0f, 6.5f, 1, 1));
	cached = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return cached;
}

@interface TGBubbleCellBase ()

@property (nonatomic, strong, readwrite) UIView *bubble;
@property (nonatomic, strong, readwrite) UIImageView *bubbleArtwork;
@property (nonatomic, strong, readwrite) UIImageView *tail;
@property (nonatomic, strong, readwrite) TGEmojiLabel *sender;
@property (nonatomic, strong, readwrite) UIImageView *senderAvatar;
@property (nonatomic, strong, readwrite) UIImageView *plate;
@property (nonatomic, strong, readwrite) UILabel *plateTime;
@property (nonatomic, strong, readwrite) UILabel *plateViews;
@property (nonatomic, strong, readwrite) UIImageView *plateEye;
@property (nonatomic, strong, readwrite) UIImageView *plateTicks;
@property (nonatomic, strong, readwrite) TGReplySwipeRecognizer *replySwipe;

@property (nonatomic, strong) TGQuoteBadgeView *quoteBadgeStorage;
@property (nonatomic, strong) TGEmojiLabel *forwardLabelStorage;
@property (nonatomic, strong) UIButton *forwardJumpButtonStorage;
@property (nonatomic, strong) TGLinkPreviewView *linkPreviewStorage;
@property (nonatomic, strong) UILabel *signatureLabelStorage;
@property (nonatomic, strong) TGReactionChipsView *reactionChipsStorage;
@property (nonatomic, strong) UIButton *commentsButtonStorage;
@property (nonatomic, strong) UIView *commentsSeparatorStorage;

@end

@implementation TGBubbleCellBase

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.bubble = [[UIView alloc] init];
	self.bubble.clipsToBounds = YES;
	[self.contentView addSubview:self.bubble];

	self.bubbleArtwork = [[UIImageView alloc] init];
	self.bubbleArtwork.hidden = YES;
	[self.contentView insertSubview:self.bubbleArtwork belowSubview:self.bubble];

	self.tail = [[UIImageView alloc] init];
	self.tail.hidden = YES;
	[self.contentView addSubview:self.tail];

	self.sender = [[TGEmojiLabel alloc] init];
	self.sender.numberOfLines = 1;
	self.sender.font = [UIFont boldSystemFontOfSize:13];
	self.sender.backgroundColor = [UIColor clearColor];
	self.sender.hidden = YES;
	[self.bubble addSubview:self.sender];

	self.senderAvatar = [[UIImageView alloc] init];
	self.senderAvatar.hidden = YES;
	self.senderAvatar.clipsToBounds = YES;
	[self.contentView addSubview:self.senderAvatar];

	self.plate = [[UIImageView alloc] init];
	self.plate.hidden = YES;
	[self.contentView addSubview:self.plate];

	self.plateTime = [[UILabel alloc] init];
	self.plateTime.font = [UIFont systemFontOfSize:11];
	self.plateTime.backgroundColor = [UIColor clearColor];
	self.plateTime.hidden = YES;
	[self.contentView addSubview:self.plateTime];

	self.plateViews = [[UILabel alloc] init];
	self.plateViews.font = [UIFont systemFontOfSize:11];
	self.plateViews.backgroundColor = [UIColor clearColor];
	self.plateViews.hidden = YES;
	[self.contentView addSubview:self.plateViews];

	self.plateEye = [[UIImageView alloc] init];
	self.plateEye.hidden = YES;
	[self.contentView addSubview:self.plateEye];

	self.plateTicks = [[UIImageView alloc] init];
	self.plateTicks.hidden = YES;
	[self.contentView addSubview:self.plateTicks];

	self.replyArrow = [[UIView alloc] init];
	self.replyArrow.hidden = YES;
	[self.contentView addSubview:self.replyArrow];

	self.replySwipe = [[TGReplySwipeRecognizer alloc] initWithTarget:nil action:nil];
	[self addGestureRecognizer:self.replySwipe];

	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];

	self.transform = CGAffineTransformIdentity;
	[self.layer removeAllAnimations];

	self.avatarUserId = 0;
	self.avatarChatId = 0;
	self.forwardChatId = 0;
	self.forwardMessageId = 0;
	self.forwardUserId = 0;

	if (self.forwardLabelStorage)
		self.forwardLabelStorage.richLayout = nil;
	if (self.quoteBadgeStorage) {
		self.quoteBadgeStorage.authorLabel.richLayout = nil;
		self.quoteBadgeStorage.textLabel.richLayout = nil;
	}
}

- (void)applyItem:(TGMessageItem *)item layout:(TGMessageLayout *)layout {
	[super applyItem:item layout:layout];

	TGMessageLayoutParts parts = layout.parts;
	BOOL hasBubbleArtwork = (parts & TGMessageLayoutPartBubbleArtwork) != 0;

	TGTheme *theme = [TGTheme shared];
	UIColor *bubbleMineColour = TGActiveChatThemeBubbleMineColour(item.chatId) ?: [theme bubbleMineColour];
	self.bubble.frame = layout.row.bubble;
	self.bubble.layer.cornerRadius = layout.bubbleCornerRadius;
	self.bubble.layer.borderWidth = layout.bubbleBorderWidth;
	self.bubble.layer.borderColor = [theme bubbleBorderColour].CGColor;
	self.bubble.backgroundColor = (layout.sitsOnWallpaper || hasBubbleArtwork)
		? [UIColor clearColor]
		: (layout.outgoing ? bubbleMineColour : [theme bubbleTheirsColour]);

	self.bubbleArtwork.hidden = !hasBubbleArtwork;
	if (hasBubbleArtwork) {
		CGRect box = layout.row.bubble;
		CGFloat artworkWidth = MAX(box.size.width + kBubbleCellArtworkTailOverhang, kBubbleCellArtworkMinW);
		CGFloat artworkHeight = MAX(box.size.height, kBubbleCellArtworkMinH);
		self.bubbleArtwork.frame = CGRectMake(
			layout.outgoing ? box.origin.x : box.origin.x - kBubbleCellArtworkTailOverhang,
			box.origin.y, artworkWidth, artworkHeight);
		self.bubbleArtwork.image = TGMessageLayoutBubbleArtwork(box.size.height >= 48.0f,
			layout.outgoing);
	}

	self.tail.hidden = !(parts & TGMessageLayoutPartTail);
	if (parts & TGMessageLayoutPartTail) {
		self.tail.frame = layout.row.tail;
		UIColor *tailFill = layout.outgoing ? bubbleMineColour : [theme bubbleTheirsColour];
		self.tail.image = [TGIcons bubbleTailForColour:tailFill outgoing:layout.outgoing];
	}

	self.sender.hidden = !(parts & TGMessageLayoutPartSender);
	if (parts & TGMessageLayoutPartSender) {
		self.sender.frame = layout.bubble.sender;
		self.sender.text = item.senderDisplayName;
		self.sender.textColor = TGSenderColour(item.senderId != 0 ? item.senderId : item.senderChatId);
	}

	self.senderAvatar.hidden = !(parts & TGMessageLayoutPartAvatar);
	if (parts & TGMessageLayoutPartAvatar) {
		self.senderAvatar.frame = layout.row.avatar;
		self.senderAvatar.layer.cornerRadius = layout.row.avatar.size.width * kBubbleCellSenderAvatarCornerFactor;
		if (item.forwardAvatarChatId != 0) {
			self.avatarChatId = item.forwardAvatarChatId;
			self.avatarUserId = 0;
		} else if (item.forwardAvatarUserId != 0) {
			self.avatarChatId = 0;
			self.avatarUserId = item.forwardAvatarUserId;
		} else if (item.senderChatId != 0) {
			self.avatarChatId = item.senderChatId;
			self.avatarUserId = 0;
		} else {
			self.avatarChatId = 0;
			self.avatarUserId = item.senderId;
		}
	}

	BOOL plateVisible = (parts & TGMessageLayoutPartPlateBeside) != 0;
	self.plate.hidden = !plateVisible;
	self.plateTime.hidden = !plateVisible;
	if (plateVisible) {
		UIImage *plateArt = [TGIcons messageTimestampPlateOutgoing:layout.outgoing];
		UIColor *stampTint = TGMessageDateColour();

		self.plate.frame = layout.row.platePlate;
		self.plate.image = plateArt;
		self.plate.backgroundColor = plateArt ? [UIColor clearColor]
											  : [UIColor colorWithWhite:1.0f alpha:0.55f];
		self.plate.layer.cornerRadius = plateArt ? 0.0f : kBubbleCellPlateFallbackCornerRadius;
		self.plate.clipsToBounds = plateArt == nil;

		self.plateTime.frame = layout.row.plateTime;
		self.plateTime.text = item.stampText;
		self.plateTime.textColor = stampTint;

		BOOL showsViews = (parts & TGMessageLayoutPartPlateViews) && item.viewCountText.length > 0;
		self.plateViews.hidden = !showsViews;
		self.plateEye.hidden = !showsViews;
		if (showsViews) {
			self.plateViews.frame = layout.row.plateViews;
			self.plateViews.text = item.viewCountText;
			self.plateViews.textColor = stampTint;
			self.plateEye.frame = layout.row.plateEye;
			self.plateEye.image = TGViewsEyeImage(stampTint);
		}

		BOOL showsTicks = (parts & TGMessageLayoutPartPlateTicks) && layout.outgoing;
		self.plateTicks.hidden = !showsTicks;
		if (showsTicks) {
			self.plateTicks.frame = layout.row.plateTicks;
			TGMessageSendState sendState = item.message.sendState;
			self.plateTicks.image = [self tg_tickImageForSendState:sendState read:item.deliveryWasRead];
		}
	}

	self.replyArrow.hidden = YES;
	if (!CGRectIsEmpty(layout.row.replyArrow))
		self.replyArrow.frame = layout.row.replyArrow;

	if (parts & TGMessageLayoutPartForward) {
		self.forwardLabel.hidden = NO;
		self.forwardLabel.frame = layout.bubble.forward;

		NSString *prefix = item.forwardLinePrefix;
		NSString *from = item.forwardDisplayName ?: @"";
		NSString *line = item.forwardLineText ?: prefix;
		UIColor *titleColour = layout.outgoing ? TGColourFromHex(0x3a8e26)
												 : TGColourFromHex(0x0e7acd);
		UIColor *nameColour = layout.outgoing ? TGColourFromHex(0x169600)
												: TGColourFromHex(0x0e7acd);
		NSMutableAttributedString *styled =
			[[NSMutableAttributedString alloc] initWithString:line];
		[styled addAttribute:NSFontAttributeName
					   value:[UIFont systemFontOfSize:13]
					   range:NSMakeRange(0, line.length)];
		[styled addAttribute:NSForegroundColorAttributeName
					   value:titleColour
					   range:NSMakeRange(0, line.length)];
		[styled addAttribute:NSForegroundColorAttributeName
					   value:nameColour
					   range:NSMakeRange(prefix.length, from.length)];
		[styled addAttribute:NSFontAttributeName
					   value:[UIFont boldSystemFontOfSize:13]
					   range:NSMakeRange(prefix.length, from.length)];
		self.forwardLabel.attributedText = styled;

		self.forwardChatId = item.forwardAvatarChatId;
		self.forwardUserId = item.forwardAvatarUserId;
	} else if (self.forwardLabelStorage) {
		self.forwardLabelStorage.hidden = YES;
	}

	if (parts & TGMessageLayoutPartForwardJump) {
		self.forwardJumpButton.hidden = NO;
		self.forwardJumpButton.frame = layout.row.forwardJump;
	} else if (self.forwardJumpButtonStorage) {
		self.forwardJumpButtonStorage.hidden = YES;
	}

	if (parts & TGMessageLayoutPartQuote) {
		UIColor *quoteAccent = TGActiveChatThemeAccentColour(item.chatId) ?: [theme accentColour];
		CGRect quoteFrame = layout.bubble.quoteTapTarget;
		self.quoteBadge.hidden = NO;
		self.quoteBadge.frame = quoteFrame;
		self.quoteBadge.bar.backgroundColor = quoteAccent;
		self.quoteBadge.authorLabel.font = [UIFont boldSystemFontOfSize:13];
		self.quoteBadge.authorLabel.textColor = quoteAccent;
		self.quoteBadge.authorLabel.text = item.quoteAuthorText;
		self.quoteBadge.textLabel.font = [UIFont systemFontOfSize:13];
		self.quoteBadge.textLabel.textColor = [theme primaryTextColour];
		self.quoteBadge.textLabel.text = item.quoteBodyText;
		self.quoteBadge.textLabel.richLayout = item.quoteRichLayout;
		[self.quoteBadge layoutWithBarFrame:CGRectOffset(layout.bubble.quoteBar,
												-quoteFrame.origin.x,
												-quoteFrame.origin.y)
								authorFrame:CGRectOffset(layout.bubble.quoteAuthor,
												-quoteFrame.origin.x,
												-quoteFrame.origin.y)
								  textFrame:CGRectOffset(layout.bubble.quoteText,
												-quoteFrame.origin.x,
												-quoteFrame.origin.y)
							 thumbnailFrame:(parts & TGMessageLayoutPartQuoteThumb)
				? CGRectOffset(layout.bubble.quoteThumb,
					  -quoteFrame.origin.x,
					  -quoteFrame.origin.y)
				: CGRectZero
							 tapTargetFrame:CGRectOffset(layout.bubble.quoteTapTarget,
												-quoteFrame.origin.x,
												-quoteFrame.origin.y)];
	} else if (self.quoteBadgeStorage) {
		self.quoteBadgeStorage.hidden = YES;
	}

	if (parts & TGMessageLayoutPartPreview) {
		self.linkPreview.hidden = NO;
		self.linkPreview.frame = layout.bubble.preview;
	} else if (self.linkPreviewStorage) {
		self.linkPreviewStorage.hidden = YES;
	}

	if (parts & TGMessageLayoutPartSignature) {
		self.signatureLabel.hidden = NO;
		self.signatureLabel.frame = layout.bubble.signature;
		self.signatureLabel.text = item.signatureText;
	} else if (self.signatureLabelStorage) {
		self.signatureLabelStorage.hidden = YES;
	}

	if (parts & TGMessageLayoutPartReactions) {
		self.reactionChips.hidden = NO;
		self.reactionChips.frame = layout.bubble.reactions;
		self.reactionChips.outgoing = layout.outgoing;
		self.reactionChips.chatId = item.chatId;
		self.reactionChips.messageId = item.messageId;
		[self.reactionChips setChips:item.reactionChips animated:NO];
	} else if (self.reactionChipsStorage) {
		self.reactionChipsStorage.hidden = YES;
	}

	if (parts & TGMessageLayoutPartComments) {
		self.commentsButton.hidden = NO;
		self.commentsButton.frame = layout.bubble.comments;
		[self.commentsButton setTitleColor:[theme secondaryTextColour] forState:UIControlStateNormal];
		NSString *commentsLabel = item.commentCount > 0
			? TGLPlural(@"Conversation.MessageViewComments", item.commentCount,
				  @"1 Comment", @"%d Comments")
			: TGL(@"Conversation.MessageLeaveComment", @"Leave a Comment");
		[self.commentsButton setTitle:[NSString stringWithFormat:@"%@  ›", commentsLabel]
							 forState:UIControlStateNormal];
		self.commentsSeparatorStorage.frame = CGRectMake(
			0, 0, layout.bubble.comments.size.width, 0.5f);
	} else if (self.commentsButtonStorage) {
		self.commentsButtonStorage.hidden = YES;
	}
}

- (UIImage *)tg_tickImageForSendState:(TGMessageSendState)state read:(BOOL)read {
	switch (state) {
		case TGMessageSendStatePending:
			return TGBubbleClockGlyph();
		case TGMessageSendStateFailed:
			return TGBubbleFailedGlyph();
		case TGMessageSendStateSent:
			return [TGIcons messageChecksRead:read white:NO];
	}
	return [TGIcons messageChecksRead:read white:NO];
}

- (TGQuoteBadgeView *)quoteBadge {
	if (!self.quoteBadgeStorage) {
		self.quoteBadgeStorage = [[TGQuoteBadgeView alloc] init];
		self.quoteBadgeStorage.hidden = YES;
		[self.quoteBadgeStorage.tapTarget addTarget:self
											 action:@selector(tg_quoteTapped)
								   forControlEvents:UIControlEventTouchUpInside];
		[self.bubble addSubview:self.quoteBadgeStorage];
	}
	return self.quoteBadgeStorage;
}

- (TGEmojiLabel *)forwardLabel {
	if (!self.forwardLabelStorage) {
		self.forwardLabelStorage = [[TGEmojiLabel alloc] init];
		self.forwardLabelStorage.numberOfLines = 1;
		self.forwardLabelStorage.font = [UIFont systemFontOfSize:13];
		self.forwardLabelStorage.backgroundColor = [UIColor clearColor];
		self.forwardLabelStorage.hidden = YES;
		[self.bubble addSubview:self.forwardLabelStorage];
	}
	return self.forwardLabelStorage;
}

- (UIButton *)forwardJumpButton {
	if (!self.forwardJumpButtonStorage) {
		self.forwardJumpButtonStorage = [UIButton buttonWithType:UIButtonTypeCustom];
		self.forwardJumpButtonStorage.backgroundColor = [UIColor clearColor];
		self.forwardJumpButtonStorage.hidden = YES;
		[self.forwardJumpButtonStorage addTarget:self
										  action:@selector(tg_forwardJumpTapped)
								forControlEvents:UIControlEventTouchUpInside];
		[self.contentView addSubview:self.forwardJumpButtonStorage];
	}
	return self.forwardJumpButtonStorage;
}

- (TGLinkPreviewView *)linkPreview {
	if (!self.linkPreviewStorage) {
		self.linkPreviewStorage = [[TGLinkPreviewView alloc] init];
		self.linkPreviewStorage.hidden = YES;
		[self.bubble addSubview:self.linkPreviewStorage];
	}
	return self.linkPreviewStorage;
}

- (UILabel *)signatureLabel {
	if (!self.signatureLabelStorage) {
		self.signatureLabelStorage = [[UILabel alloc] init];
		self.signatureLabelStorage.font = [UIFont systemFontOfSize:11];
		self.signatureLabelStorage.backgroundColor = [UIColor clearColor];
		self.signatureLabelStorage.hidden = YES;
		[self.bubble addSubview:self.signatureLabelStorage];
	}
	return self.signatureLabelStorage;
}

- (TGReactionChipsView *)reactionChips {
	if (!self.reactionChipsStorage) {
		self.reactionChipsStorage = [[TGReactionChipsView alloc] init];
		self.reactionChipsStorage.hidden = YES;
		__weak TGBubbleCellBase *weakSelf = self;
		self.reactionChipsStorage.onChipTapped = ^(NSString *emoji, BOOL __unused chosen) {
			TGBubbleCellBase *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (![strongSelf.delegate respondsToSelector:@selector(bubbleCell:didTapReactionEmoji:atRow:)])
				return;
			[strongSelf.delegate bubbleCell:strongSelf
						didTapReactionEmoji:emoji
									  atRow:strongSelf.appliedRow];
		};
		self.reactionChipsStorage.onOpenProfile = ^(int64_t chatId, int64_t userId, NSString *name,
			id presentingNavigation) {
			UINavigationController *nav = presentingNavigation;
			TGProfileViewController *vc = [[TGProfileViewController alloc]
				initWithChatId:chatId userId:userId title:name];
			[nav pushViewController:vc animated:YES];
		};
		[self.bubble addSubview:self.reactionChipsStorage];
	}
	return self.reactionChipsStorage;
}

- (UIButton *)commentsButton {
	if (!self.commentsButtonStorage) {
		self.commentsButtonStorage = [UIButton buttonWithType:UIButtonTypeCustom];
		self.commentsButtonStorage.backgroundColor = [UIColor clearColor];
		self.commentsButtonStorage.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
		self.commentsButtonStorage.titleLabel.font = [UIFont systemFontOfSize:13];
		self.commentsButtonStorage.hidden = YES;
		self.commentsSeparatorStorage = [[UIView alloc] init];
		self.commentsSeparatorStorage.backgroundColor = [[TGTheme shared] separatorColour];
		[self.commentsButtonStorage addSubview:self.commentsSeparatorStorage];
		[self.commentsButtonStorage addTarget:self
									   action:@selector(tg_commentsTapped)
							 forControlEvents:UIControlEventTouchUpInside];
		[self.bubble addSubview:self.commentsButtonStorage];
	}
	return self.commentsButtonStorage;
}

- (void)tg_commentsTapped {
	if (![self.delegate respondsToSelector:@selector(bubbleCell:didTapPart:atRow:)])
		return;
	[self.delegate bubbleCell:self didTapPart:TGBubbleCellPartComments atRow:self.appliedRow];
}

- (void)tg_forwardJumpTapped {
	[self.delegate bubbleCell:self didTapPart:TGBubbleCellPartForwardJump atRow:self.appliedRow];
}

- (void)tg_quoteTapped {
	[self.delegate bubbleCell:self didTapPart:TGBubbleCellPartQuote atRow:self.appliedRow];
}

- (NSString *)tg_accessibilityLabelWithParts:(NSArray<NSString *> *)parts {
	NSMutableArray<NSString *> *nonEmpty = [NSMutableArray arrayWithCapacity:parts.count];
	for (NSString *part in parts) {
		if (part.length)
			[nonEmpty addObject:part];
	}
	return [nonEmpty componentsJoinedByString:@", "];
}

@end

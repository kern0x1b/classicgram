#import "TGReactionPickerView.h"
#import "TGReactionPickerViewInternal.h"
#import "TGReactionChipView.h"
#import "TGReactionListViewController.h"
#import "TGPaidReactorsViewController.h"
#import "TGReactionService.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGSnackbar.h"
#import "TGHexColour.h"

@interface TGReactionChipsView ()

+ (CGFloat)chipWidthForEmoji:(NSString *)emoji count:(NSInteger)count label:(NSString *)label;
- (BOOL)canOfferReactionList;

@end

@implementation TGReactionChipsView {
	NSMutableArray *_chipViews;
}

+ (CGFloat)chipWidthForEmoji:(NSString *)__unused emoji count:(NSInteger)count label:(NSString *)label {
	NSString *countText = [NSString stringWithFormat:@"%d", (int)MAX(1, count)];
	NSString *cacheKey = label.length
		? [NSString stringWithFormat:@"%@|%@", countText, label]
		: countText;

	static NSMutableDictionary *widths = nil;
	if (!widths)
		widths = [[NSMutableDictionary alloc] init];
	NSNumber *known = [widths objectForKey:cacheKey];
	if (known)
		return [known floatValue];

	CGFloat countWidth = [countText sizeWithFont:[UIFont boldSystemFontOfSize:kChipCountFontSize]].width;
	CGFloat width = ceilf(kChipPadding * 2 + kChipGlyphSlot + kChipCountGap + countWidth);
	if (label.length) {
		CGFloat labelWidth = [label sizeWithFont:[UIFont systemFontOfSize:kChipCountFontSize]].width;
		width += ceilf(kChipCountGap + labelWidth);
	}
	[widths setObject:[NSNumber numberWithFloat:width] forKey:cacheKey];
	return width;
}

+ (CGFloat)rowHeight {
	return kChipHeight;
}

+ (CGSize)sizeForChips:(NSArray *)chips width:(CGFloat)width {
	if (![chips isKindOfClass:[NSArray class]] || chips.count == 0)
		return CGSizeZero;
	if (width < kChipMinRowWidth)
		width = kChipMinRowWidth;

	CGFloat x = 0;
	CGFloat widest = 0;
	NSInteger rows = 1;
	for (id raw in chips) {
		if (![raw isKindOfClass:[NSDictionary class]])
			continue;
		NSString *emoji = [(NSDictionary *)raw objectForKey:@"emoji"];
		if (![emoji isKindOfClass:[NSString class]] || emoji.length == 0)
			continue;
		NSInteger count = [[(NSDictionary *)raw objectForKey:@"count"] integerValue];
		NSString *label = [(NSDictionary *)raw objectForKey:@"label"];
		if (![label isKindOfClass:[NSString class]])
			label = nil;
		CGFloat chipWidth = [self chipWidthForEmoji:emoji count:count label:label];
		if (x > 0 && x + chipWidth > width) {
			widest = MAX(widest, x - kChipGap);
			rows++;
			x = 0;
		}
		x += chipWidth + kChipGap;
	}
	if (x == 0 && rows == 1)
		return CGSizeZero;
	widest = MAX(widest, x - kChipGap);

	return CGSizeMake(ceilf(MIN(widest, width)),
		rows * kChipHeight + (rows - 1) * kChipRowGap);
}

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self != nil) {
		self.backgroundColor = [UIColor clearColor];
		self.clipsToBounds = NO;
		_chipViews = [[NSMutableArray alloc] init];
		self.hidden = YES;
	}
	return self;
}

- (void)styleChip:(TGReactionChipView *)view {
	BOOL chosen = view.chosen;
	UIColor *fill = TGColourFromHex(_outgoing ? 0xAEF57C : 0xDEF0FF);
	UIColor *accent = TGColourFromHex(0x0779D0);

	view.plateView.image = nil;
	view.plateView.backgroundColor = fill;
	view.plateView.layer.cornerRadius = kChipRadius;
	view.plateView.layer.borderWidth = chosen ? 1.0f : 0.0f;
	view.plateView.layer.borderColor = chosen ? accent.CGColor : [UIColor clearColor].CGColor;

	view.countLabel.textColor = chosen ? accent : TGColourFromHex(0x506E8D);
	view.tagLabelView.textColor = view.countLabel.textColor;
}

- (void)setChips:(NSArray *)chips {
	[self setChips:chips animated:NO];
}

- (void)setChips:(NSArray *)chips animated:(BOOL)animated {
	NSMutableArray *usable = [[NSMutableArray alloc] init];
	for (id raw in chips) {
		if (![raw isKindOfClass:[NSDictionary class]])
			continue;
		NSString *emoji = [(NSDictionary *)raw objectForKey:@"emoji"];
		if (![emoji isKindOfClass:[NSString class]] || emoji.length == 0)
			continue;
		[usable addObject:raw];
	}

	_chips = [usable copy];

	for (UIView *view in _chipViews)
		[view removeFromSuperview];
	[_chipViews removeAllObjects];

	if (usable.count == 0) {
		self.hidden = YES;
		return;
	}

	for (NSDictionary *chip in usable) {
		NSString *emoji = [chip objectForKey:@"emoji"];
		NSInteger count = [[chip objectForKey:@"count"] integerValue];
		BOOL chosen = [[chip objectForKey:@"chosen"] boolValue];
		BOOL custom = [[chip objectForKey:@"custom"] boolValue];
		NSString *label = [chip objectForKey:@"label"];
		if (![label isKindOfClass:[NSString class]])
			label = nil;
		NSString *customEmojiId = [chip objectForKey:@"customEmojiId"];
		if (![customEmojiId isKindOfClass:[NSString class]] || customEmojiId.length == 0)
			customEmojiId = nil;

		TGReactionChipView *view = [[TGReactionChipView alloc] initWithFrame:CGRectZero];
		view.emoji = emoji;
		view.chosen = chosen;
		view.custom = custom;
		view.paid = [[chip objectForKey:@"paid"] boolValue];
		view.emojiLabel.text = emoji;
		view.countLabel.text = [NSString stringWithFormat:@"%d", (int)MAX(1, count)];
		view.tagLabel = label;
		[self styleChip:view];
		[view addTarget:self action:@selector(chipTapped:) forControlEvents:UIControlEventTouchUpInside];

		if (custom) {
			if (customEmojiId != nil) {
				__weak TGReactionChipView *weakChip = view;
				TGReactionIconForCustomEmoji(customEmojiId, kReactionIconSide, ^(UIImage *icon) {
					TGReactionChipView *strongChip = weakChip;
					if (strongChip == nil || icon == nil)
						return;
					strongChip.iconView.image = icon;
					strongChip.iconView.hidden = NO;
					strongChip.emojiLabel.hidden = YES;
					[strongChip setNeedsLayout];
				});
			}
		} else {
			__weak TGReactionChipView *weakChip = view;
			TGReactionIconForEmoji(emoji, kReactionIconSide, ^(UIImage *icon) {
				TGReactionChipView *strongChip = weakChip;
				if (strongChip == nil || icon == nil)
					return;
				strongChip.iconView.image = icon;
				strongChip.iconView.hidden = NO;
				strongChip.emojiLabel.hidden = YES;
				[strongChip setNeedsLayout];
			});
		}

		UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc]
			initWithTarget:self
					action:@selector(chipLongPressed:)];
		longPress.minimumPressDuration = 0.4;
		[view addGestureRecognizer:longPress];

		[self addSubview:view];
		[_chipViews addObject:view];
	}

	self.hidden = NO;
	[self setNeedsLayout];
	[self layoutIfNeeded];

	if (animated) {
		self.alpha = 0.0f;
		[UIView animateWithDuration:0.15 animations:^{
			self.alpha = 1.0f;
		}];
	} else
		self.alpha = 1.0f;
}

- (void)setOutgoing:(BOOL)outgoing {
	if (_outgoing == outgoing)
		return;
	_outgoing = outgoing;
	for (TGReactionChipView *view in _chipViews)
		[self styleChip:view];
}

- (void)layoutSubviews {
	[super layoutSubviews];

	CGFloat width = self.bounds.size.width;
	if (width < kChipMinRowWidth)
		width = kChipMinRowWidth;

	CGFloat x = 0;
	CGFloat y = 0;
	for (TGReactionChipView *view in _chipViews) {
		NSInteger count = [view.countLabel.text integerValue];
		CGFloat chipWidth = [[self class] chipWidthForEmoji:view.emoji count:count label:view.tagLabel];
		if (x > 0 && x + chipWidth > width) {
			x = 0;
			y += kChipHeight + kChipRowGap;
		}
		view.frame = CGRectMake(x, y, chipWidth, kChipHeight);
		x += chipWidth + kChipGap;
	}
}

- (CGSize)sizeThatFits:(CGSize)size {
	CGFloat width = size.width > kChipMinRowWidth ? size.width : self.bounds.size.width;
	return [[self class] sizeForChips:_chips width:width];
}

- (void)chipLongPressed:(UILongPressGestureRecognizer *)recognizer {
	if (recognizer.state != UIGestureRecognizerStateBegan)
		return;
	TGReactionChipView *chip = [recognizer.view isKindOfClass:[TGReactionChipView class]]
		? (TGReactionChipView *)recognizer.view
		: nil;
	if (chip.paid) {
		[self showPaidReactors];
		return;
	}
	[self showReactionList];
}

- (BOOL)canOfferReactionList {
	for (NSDictionary *chip in _chips) {
		if (![chip isKindOfClass:[NSDictionary class]])
			continue;
		return [[chip objectForKey:@"canGetAddedReactions"] boolValue];
	}
	return NO;
}

- (void)showReactionList {
	if (_chatId == 0 || _messageId == 0)
		return;
	if (![self canOfferReactionList])
		return;

	UIViewController *owner = TGReactionOwningController(self);
	if (owner == nil)
		return;

	TGReactionListViewController *list = [[TGReactionListViewController alloc]
		initWithMessage:_messageId
				 chatId:_chatId
				  chips:_chips];
	list.onOpenProfile = self.onOpenProfile;
	UINavigationController *navigation =
		[[UINavigationController alloc] initWithRootViewController:list];
	[[TGTheme shared] styleNavigationBar:navigation.navigationBar];

	if ([owner respondsToSelector:@selector(presentViewController:animated:completion:)])
		[owner presentViewController:navigation animated:YES completion:nil];
	else
		[owner presentModalViewController:navigation animated:YES];
}

- (void)showPaidReactors {
	if (_chatId == 0 || _messageId == 0)
		return;

	UIViewController *owner = TGReactionOwningController(self);
	if (owner == nil)
		return;

	TGPaidReactorsViewController *board = [[TGPaidReactorsViewController alloc]
		initWithMessage:_messageId
				 chatId:_chatId];
	UINavigationController *navigation =
		[[UINavigationController alloc] initWithRootViewController:board];
	[[TGTheme shared] styleNavigationBar:navigation.navigationBar];

	if ([owner respondsToSelector:@selector(presentViewController:animated:completion:)])
		[owner presentViewController:navigation animated:YES completion:nil];
	else
		[owner presentModalViewController:navigation animated:YES];
}

- (void)chipTapped:(TGReactionChipView *)view {
	NSString *emoji = view.emoji;
	if (emoji.length == 0)
		return;

	if (view.paid) {
		[self showPaidReactors];
		return;
	}

	if (view.custom) {
		[self showReactionList];
		return;
	}

	BOOL wasChosen = view.chosen;
	TGReactionChipTappedBlock tapped = self.onChipTapped;

	if (!_allowsReactionToggle || _chatId == 0 || _messageId == 0) {
		if (tapped != nil)
			tapped(emoji, wasChosen);
		return;
	}

	if ([TGReactionService isReactionInFlightForMessage:_messageId inChat:_chatId emoji:emoji])
		return;

	int64_t chatId = _chatId;
	int64_t messageId = _messageId;
	__weak typeof(self) weakSelf = self;
	[TGReactionService toggleReaction:emoji
							onMessage:messageId
							   inChat:chatId
								  big:NO
						   completion:^(BOOL nowChosen, BOOL succeeded) {
							   if (!succeeded) {
								   TGReactionChipsView *strongSelf = weakSelf;
								   UIViewController *owner = strongSelf ? TGReactionOwningController(strongSelf) : nil;
								   UIView *host = owner.navigationController.view ?: owner.view;
								   if (host)
									   [TGSnackbar showInView:host
														  text:TGL(@"Toast.CouldNotUpdateReaction", @"Could not update the reaction")
													   seconds:2
													  onCommit:nil];
								   return;
							   }
							   if (tapped != nil)
								   tapped(emoji, nowChosen);
						   }];
}

@end

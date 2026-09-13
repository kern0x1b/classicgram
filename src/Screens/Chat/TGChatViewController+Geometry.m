#import "TGClient+Contacts.h"
#import "TGQuoteBodyText.h"
#import "TGDurationText.h"
#import "TGDateUtils.h"
#import "TGCacheTrim.h"
#import "TGPerfLogging.h"
#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+ChatManagement.h"
#import "TGClient+ChatState.h"
#import "TGClient+Files.h"
#import "TGClient+Messages.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGPreferenceFlags.h"
#import "TGProfileViewController.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGRichText.h"
#import "TGReactionPickerView.h"
#import "TGClient+ChatList.h"
#import "TGImageDecode.h"
#import "TGClient+Stickers.h"
#import "TGLiveLocationExpiry.h"
#import "TGBurnLabelLine.h"

extern UIColor *TGActiveChatThemeAccentColour(int64_t chatId);

@implementation TGChatViewController (Geometry)

- (NSString *)quoteTextFor:(NSDictionary *)m {
	NSNumber *replyId = m[@"replyId"];
	if (![replyId isKindOfClass:NSNumber.class])
		return nil;
	NSDictionary *fetched = self.quotes[replyId];
	return TGQuoteBodyText(m[@"replyText"], fetched[@"text"],
		[self.quotesMissing containsObject:replyId]);
}

- (NSString *)quoteAuthorFor:(NSDictionary *)m {
	NSNumber *replyId = [m[@"replyId"] isKindOfClass:NSNumber.class] ? m[@"replyId"] : nil;
	if (!replyId)
		return nil;
	NSDictionary *original = self.quotes[replyId];
	if (original) {
		if ([original[@"outgoing"] boolValue])
			return TGL(@"DialogList.You", @"You");
		int64_t senderChatId = [original[@"senderChatId"] longLongValue];
		NSString *known = senderChatId != 0
			? [[TGClient shared] cachedTitleForChatId:senderChatId]
			: [[TGClient shared] nameForUserId:[original[@"senderId"] longLongValue]];
		if (known.length)
			return known;
	}
	NSString *carried = [m[@"replyAuthor"] isKindOfClass:NSString.class]
		? m[@"replyAuthor"]
		: nil;
	return carried.length ? carried : nil;
}

- (NSString *)quoteKindLabelFor:(NSDictionary *)original {
	NSString *kind = original[@"kind"];
	if ([kind isEqualToString:@"messagePhoto"])
		return TGL(@"Message.Photo", @"Photo");
	if ([kind isEqualToString:@"messageVideo"])
		return TGL(@"Message.Video", @"Video");
	if ([kind isEqualToString:@"messageAnimation"])
		return TGL(@"Message.Animation", @"GIF");
	if ([kind isEqualToString:@"messageVoiceNote"])
		return TGL(@"Message.Audio", @"Voice message");
	if ([kind isEqualToString:@"messageVideoNote"])
		return TGL(@"Message.VideoMessage", @"Video Message");
	if ([kind isEqualToString:@"messageContact"])
		return TGL(@"Message.Contact", @"Contact");
	if ([kind isEqualToString:@"messagePoll"])
		return TGL(@"Watch.Message.Poll", @"Poll");
	if ([kind isEqualToString:@"messageChecklist"])
		return TGL(@"Chat.Todo.Message.Title", @"Checklist");
	if ([kind isEqualToString:@"messageLocation"])
		return TGL(@"Message.Location", @"Location");
	if ([kind isEqualToString:@"messageLiveLocation"])
		return TGL(@"Message.LiveLocation", @"Live location");
	if ([kind isEqualToString:@"messageVenue"])
		return TGL(@"Message.Location", @"Location");
	if ([kind isEqualToString:@"messageStory"])
		return TGL(@"Message.Story", @"Story");
	if ([kind isEqualToString:@"messageGame"])
		return TGL(@"Message.Game", @"Game");
	if ([kind isEqualToString:@"messageInvoice"])
		return TGL(@"Watch.Message.Invoice", @"Invoice");
	if ([kind isEqualToString:@"messageRichMessage"]) {
		NSString *title = [original[@"richTitle"] isKindOfClass:NSString.class]
			? original[@"richTitle"]
			: @"";
		return title.length ? title : TGL(@"Attachment.Article", @"Article");
	}
	if ([kind hasPrefix:@"messageExpired"])
		return TGL(@"Chat.ExpiredMediaQuoteLabel", @"Expired media");
	if ([kind isEqualToString:@"messageAudio"]) {
		NSString *title = [original[@"audioTitle"] isKindOfClass:NSString.class]
			? original[@"audioTitle"]
			: @"";
		NSString *performer = [original[@"audioPerformer"] isKindOfClass:NSString.class]
			? original[@"audioPerformer"]
			: @"";
		if (title.length && performer.length)
			return [NSString stringWithFormat:@"%@ — %@", performer, title];
		if (title.length)
			return title;
		return TGL(@"RichTextPreview.Music", @"Music");
	}
	if ([kind isEqualToString:@"messageDocument"]) {
		NSString *name = [original[@"docName"] isKindOfClass:NSString.class]
			? original[@"docName"]
			: @"";
		return name.length ? name : TGL(@"Message.File", @"File");
	}
	if ([kind isEqualToString:@"messageSticker"] ||
		[kind isEqualToString:@"messageAnimatedEmoji"]) {
		NSString *text = original[@"text"];
		return [text isKindOfClass:NSString.class] && text.length
			? [NSString stringWithFormat:TGL(@"Message.StickerText", @"Sticker %@"), text]
			: TGL(@"Message.Sticker", @"Sticker");
	}
	return nil;
}

- (NSString *)quoteDisplayTextFor:(NSDictionary *)m {
	NSString *fragment = [m[@"replyText"] isKindOfClass:NSString.class]
		? m[@"replyText"]
		: nil;
	if (fragment.length)
		return TGFoldLineBreaks(fragment);

	NSNumber *replyId = [m[@"replyId"] isKindOfClass:NSNumber.class] ? m[@"replyId"] : nil;
	NSDictionary *original = replyId ? self.quotes[replyId] : nil;
	if (original) {
		NSString *caption = [original[@"captionText"] isKindOfClass:NSString.class]
			? original[@"captionText"]
			: @"";
		if (caption.length)
			return TGFoldLineBreaks(caption);
		NSString *label = [self quoteKindLabelFor:original];
		if (label.length)
			return label;
		NSString *text = [original[@"text"] isKindOfClass:NSString.class]
			? original[@"text"]
			: @"";
		if (text.length)
			return TGFoldLineBreaks(text);
	}

	NSString *carried = [m[@"replyKindLabel"] isKindOfClass:NSString.class]
		? m[@"replyKindLabel"]
		: nil;
	if (carried.length)
		return carried;
	return [self quoteTextFor:m];
}

- (NSArray *)quoteEntitiesFor:(NSDictionary *)m {
	NSString *fragment = [m[@"replyText"] isKindOfClass:NSString.class]
		? m[@"replyText"]
		: nil;
	if (!fragment.length)
		return nil;
	NSArray *entities = m[@"replyEntities"];
	return [entities isKindOfClass:NSArray.class] && entities.count ? entities : nil;
}

- (BOOL)quoteIsVideoNoteFor:(NSDictionary *)m {
	NSNumber *replyId = [m[@"replyId"] isKindOfClass:NSNumber.class] ? m[@"replyId"] : nil;
	if (!replyId)
		return NO;
	NSDictionary *original = self.quotes[replyId];
	return [original[@"kind"] isEqualToString:@"messageVideoNote"];
}

- (UIImage *)quoteThumbnailFor:(NSDictionary *)m {
	NSNumber *replyId = [m[@"replyId"] isKindOfClass:NSNumber.class] ? m[@"replyId"] : nil;
	if (!replyId)
		return nil;
	NSDictionary *original = self.quotes[replyId];
	if (!original)
		return nil;
	NSString *kind = [original[@"kind"] isKindOfClass:NSString.class]
		? original[@"kind"]
		: @"";
	if ([kind isEqualToString:@"messageSticker"] ||
		[kind isEqualToString:@"messageAnimatedEmoji"])
		return nil;
	NSNumber *fileId = original[@"photoId"];
	UIImage *loaded = [fileId isKindOfClass:NSNumber.class] ? self.images[fileId] : nil;
	return loaded ?: [self minithumbnailImageFor:original];
}

static NSString *TGCompactCount(long long count) {
	if (count >= 1000000) {
		long long remainder = (count % 1000000) / 100000;
		return remainder
			? [NSString stringWithFormat:@"%lld.%lldM", count / 1000000, remainder]
			: [NSString stringWithFormat:@"%lldM", count / 1000000];
	}
	if (count >= 1000) {
		long long remainder = (count % 1000) / 100;
		return remainder
			? [NSString stringWithFormat:@"%lld.%lldK", count / 1000, remainder]
			: [NSString stringWithFormat:@"%lldK", count / 1000];
	}
	return [NSString stringWithFormat:@"%lld", count];
}

- (NSString *)viewCountTextFor:(NSDictionary *)m {
	NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
	NSNumber *fresherViews = messageId ? self.viewCounts[messageId] : nil;
	long long views = fresherViews ? fresherViews.longLongValue : [m[@"views"] longLongValue];
	return views > 0 ? TGCompactCount(views) : nil;
}

UIImage *TGViewsEyeImage(UIColor *tint) {
	static NSMutableDictionary *cache = nil;
	if (!cache)
		cache = [NSMutableDictionary dictionary];

	const CGFloat w = 12.0f;
	const CGFloat h = 8.0f;
	CGFloat r = 0, g = 0, b = 0, a = 0;
	if (![tint respondsToSelector:@selector(getRed:green:blue:alpha:)] ||
		![tint getRed:&r green:&g blue:&b alpha:&a]) {
		r = g = b = 0.5f;
		a = 1.0f;
	}
	NSString *key = [NSString stringWithFormat:@"%.3f-%.3f-%.3f-%.3f", r, g, b, a];
	UIImage *cached = cache[key];
	if (cached)
		return cached;

	UIGraphicsBeginImageContextWithOptions(CGSizeMake(w, h), NO, 0.0f);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextSetRGBStrokeColor(ctx, r, g, b, a);
	CGContextSetRGBFillColor(ctx, r, g, b, a);
	CGContextSetLineWidth(ctx, 1.0f);
	CGContextSetLineCap(ctx, kCGLineCapRound);

	CGContextMoveToPoint(ctx, 0.5f, h / 2);
	CGContextAddCurveToPoint(ctx, w * 0.3f, 0.5f, w * 0.7f, 0.5f, w - 0.5f, h / 2);
	CGContextAddCurveToPoint(ctx, w * 0.7f, h - 0.5f, w * 0.3f, h - 0.5f, 0.5f, h / 2);
	CGContextStrokePath(ctx);
	CGContextFillEllipseInRect(ctx, CGRectMake(w / 2 - 1.5f, h / 2 - 1.5f, 3, 3));

	UIImage *eye = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	if (eye)
		cache[key] = eye;
	return eye;
}

static const CGFloat kViewsEyeWidth = 12.0f;
const CGFloat kViewsEyeHeight = 8.0f;
static const CGFloat kViewsEyeGap = 3.0f;
static const CGFloat kViewsTimeGap = 6.0f;
const CGFloat kStampLineHeight = 14.0f;

TGStampPlate TGStampPlateLayout(NSString *countText,
	NSString *timeText,
	UIFont *font,
	CGFloat tickWidth,
	CGFloat leadPad,
	CGFloat trailPad) {
	TGStampPlate plate;
	memset(&plate, 0, sizeof(plate));
	plate.leadPad = leadPad;
	plate.trailPad = trailPad;
	plate.showsViews = countText.length > 0;
	plate.showsTicks = tickWidth > 0;
	plate.timeWidth = ceilf([timeText sizeWithFont:font].width) + 1;

	if (plate.showsViews) {
		plate.eyeWidth = kViewsEyeWidth;
		plate.eyeGap = kViewsEyeGap;
		plate.countWidth = ceilf([countText sizeWithFont:font].width) + 1;
		plate.countGap = kViewsTimeGap;
	}
	if (plate.showsTicks) {
		plate.tickGap = 4.0f;
		plate.tickWidth = tickWidth;
	}

	CGFloat x = leadPad;
	plate.eyeOffset = x;
	if (plate.showsViews)
		x += plate.eyeWidth + plate.eyeGap;
	plate.countOffset = x;
	if (plate.showsViews)
		x += plate.countWidth + plate.countGap;
	plate.timeOffset = x;
	x += plate.timeWidth;
	if (plate.showsTicks)
		x += plate.tickGap;
	plate.tickOffset = x;
	if (plate.showsTicks)
		x += plate.tickWidth;
	plate.width = x + trailPad;
	return plate;
}

- (NSString *)stampFor:(NSDictionary *)m {
	static NSMutableDictionary *stamps = nil;
	if (!stamps)
		stamps = [NSMutableDictionary dictionary];

	BOOL edited = [m[@"edited"] boolValue];
	long long minute = (long long)floor([m[@"date"] doubleValue] / 60.0);
	NSNumber *key = @(edited ? -minute - 1 : minute);
	NSString *known = stamps[key];
	if (known)
		return known;

	NSString *stamp = [TGDateUtils stringForShortTime:(int)(minute * 60)];
	if (edited)
		stamp = [NSString stringWithFormat:TGL(@"Chat.PrivateMessageEditTimestamp.Date", @"edited %@"), stamp];
	if (stamps.count > 2048)
		[stamps removeAllObjects];
	stamps[key] = stamp;
	return stamp;
}

- (CGFloat)stampGutterWidthFor:(NSDictionary *)m {
	BOOL mine = [m[@"outgoing"] boolValue];

	static CGFloat widestTick = 0;
	if (mine && widestTick < 1) {
		UIImage *pair = [TGIcons messageChecksRead:YES white:NO];
		widestTick = MAX(16.0f, pair ? pair.size.width : 0);
	}

	TGStampPlate plate = TGStampPlateLayout([self viewCountTextFor:m],
		[self stampFor:m],
		[UIFont systemFontOfSize:11],
		mine ? widestTick : 0,
		mine ? 5 : 10,
		mine ? 8 : 6);
	return plate.width + (mine ? 12.5f : 12.0f);
}

- (CGFloat)bubbleWidthBudget {
	if (!TGChatIsPad())
		return kBubbleMaxW;

	CGFloat width = self.table ? self.table.bounds.size.width : 0;
	if (width < 1)
		width = self.view.bounds.size.width;
	if (width <= kBubbleReferenceWidth)
		return kBubbleMaxW;

	return floorf(width * (kBubbleBudgetAtReference / kBubbleReferenceWidth)) - kBubbleTailOverhang;
}

- (BOOL)forwardOriginIsReachable:(NSDictionary *)m {
	if ([m[@"forward"] length] == 0)
		return NO;

	if ([m[@"forwardIsHiddenUser"] boolValue])
		return NO;

	if ([m[@"forwardIsChannel"] boolValue])
		return [m[@"forwardChatId"] longLongValue] != 0 &&
			[m[@"forwardMessageId"] longLongValue] != 0;

	if ([m[@"forwardUserId"] longLongValue] != 0)
		return YES;

	return [m[@"forwardChatId"] longLongValue] != 0;
}

- (BOOL)rowCarriesForwardAvatar:(NSDictionary *)m {
	if (![m[@"forward"] length])
		return NO;
	if (self.chatId != [[TGClient shared] savedMessagesChatId])
		return NO;
	return [m[@"forwardUserId"] longLongValue] != 0 || [m[@"forwardChatId"] longLongValue] != 0;
}

- (CGFloat)maxBubbleWidthFor:(NSDictionary *)m {
	CGFloat w = [self bubbleWidthBudget];
	if ([m[@"outgoing"] boolValue]) {
		w -= kBubbleOutgoingTrim;
	} else if (self.group) {
		int64_t senderChatId = [m[@"senderChatId"] longLongValue];
		BOOL isChannelPost = [m[@"channelPost"] boolValue];
		NSString *senderName = (senderChatId != 0 && !isChannelPost)
			? [[TGClient shared] cachedTitleForChatId:senderChatId]
			: [[TGClient shared] nameForUserId:[m[@"senderId"] longLongValue]];
		if (senderName.length)
			w -= kBubbleAvatarTrim;
	} else if ([self rowCarriesForwardAvatar:m]) {
		w -= kBubbleAvatarTrim;
	}

	if ([self forwardOriginIsReachable:m])
		w -= kForwardJumpSide + kForwardJumpGap;

	CGFloat table = self.table ? self.table.bounds.size.width : 0;
	if (table < 1)
		table = self.view.bounds.size.width;
	if (table > 1)
		w = MIN(w, table - [self stampGutterWidthFor:m]);

	return MAX(w, kBubbleMinW);
}

- (void)openProfileForUserId:(int64_t)userId {
	if (userId <= 0)
		return;
	UINavigationController *navigation = self.navigationController;
	if (!navigation)
		return;
	NSString *name = [[TGClient shared] nameForUserId:userId] ?: @"";
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] privateChatWithUser:userId completion:^(int64_t chatId) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!chatId) {
			[strongSelf showAlertTitle:@""
							   message:TGL(@"Resolve.ErrorNotFound", @"Sorry, this user doesn't seem to exist.")];
			return;
		}
		[TGProfileViewController showProfileForChatId:chatId
											   userId:userId
												title:name
										 inNavigation:navigation];
	}];
}

- (void)openForwardOriginUser:(int64_t)userId title:(NSString *)title {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] privateChatWithUser:userId completion:^(int64_t chatId) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf || !chatId)
			return;
		[strongSelf openChatId:chatId
				   title:(title.length ? title : TGL(@"ChatList.UnnamedChat", @"Chat"))
			isGroup:NO
			focusMessage:0];
	}];
}

- (void)openForwardOriginChat:(int64_t)chatId
						title:(NSString *)title
					  message:(int64_t)messageId {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] titleForChatId:chatId completion:^(NSString *name) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!name.length && !title.length) {
			[strongSelf showAlertTitle:@""
					   message:TGL(@"Chat.ToastQuoteChatUnavailbalePrivateChat", @"This quote is from a private chat")];
			return;
		}
		[strongSelf openChatId:chatId
				   title:(name.length ? name : title)
			isGroup:YES
			focusMessage:messageId];
	}];
}

- (void)openCommentsForRow:(NSInteger)row {
	if (self.selecting)
		return;
	NSDictionary *m = [self messageAtRow:row];
	int64_t messageId = [m[@"id"] longLongValue];
	if (!messageId)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] threadForMessage:messageId
								 inChat:self.chatId
							 completion:^(NSDictionary *thread) {
								 TGChatViewController *strongSelf = weakSelf;
								 if (!strongSelf)
									 return;
								 int64_t discussionChatId = [thread[@"chatId"] longLongValue];
								 if (!discussionChatId) {
									 [strongSelf showAlertTitle:@""
										 message:TGL(@"Conversation.CommentsNoLongerAvailable", @"These comments are no longer available")];
									 return;
								 }
								 TGChatViewController *controller = [[TGChatViewController alloc] init];
								 controller.chatId = discussionChatId;
								 controller.chatTitle = TGL(@"Conversation.TitleNoComments", @"Comments");
								 controller.group = YES;
								 controller.threadId = [thread[@"threadId"] longLongValue];
								 [strongSelf.navigationController pushViewController:controller animated:YES];
							 }];
}

- (void)openForwardOriginForRow:(NSInteger)row {
	if (self.selecting)
		return;
	NSDictionary *m = [self messageAtRow:row];
	int64_t forwardChatId = [m[@"forwardChatId"] longLongValue];
	int64_t forwardMessageId = [m[@"forwardMessageId"] longLongValue];
	int64_t forwardUserId = [m[@"forwardUserId"] longLongValue];
	NSString *originTitle = forwardChatId
		? [[TGClient shared] cachedTitleForChatId:forwardChatId]
		: nil;
	NSString *title = originTitle.length ? originTitle : m[@"forward"];

	if (forwardChatId) {
		[self openForwardOriginChat:forwardChatId title:title message:forwardMessageId];
		return;
	}
	if (forwardUserId)
		[self openForwardOriginUser:forwardUserId title:title];
}

static BOOL TGIsEmojiPiece(NSString *piece) {
	if (!piece.length)
		return NO;
	unichar high = [piece characterAtIndex:0];
	UTF32Char code = high;
	if (high >= 0xD800 && high <= 0xDBFF && piece.length > 1) {
		unichar low = [piece characterAtIndex:1];
		code = ((high - 0xD800) * 0x400) + (low - 0xDC00) + 0x10000;
	}
	if (code >= 0x1F000 && code <= 0x1FAFF)
		return YES;
	if (code >= 0x2600 && code <= 0x27BF)
		return YES;
	if (code >= 0x2B00 && code <= 0x2BFF)
		return YES;
	if (code >= 0x2190 && code <= 0x21FF)
		return YES;
	if (code >= 0xFE00 && code <= 0xFE0F)
		return YES;
	if (code == 0x200D || code == 0x203C || code == 0x2049)
		return YES;
	if (code == 0x00A9 || code == 0x00AE)
		return YES;
	if (code >= 0x2122 && code <= 0x2199)
		return YES;
	return NO;
}

- (NSInteger)largeEmojiCountFor:(NSDictionary *)m {
	if (![TGPreferenceFlags stickersLargeEmojiEnabled])
		return 0;
	if (![m[@"kind"] isEqualToString:@"messageText"] &&
		![self animatedEmojiWithoutSticker:m])
		return 0;
	if ([m[@"service"] boolValue])
		return 0;
	NSString *text = [([self textOf:m] ?: @"")
		stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!text.length || text.length > kLargeEmojiTextLimit)
		return 0;

	__block NSInteger count = 0;
	__block BOOL onlyEmoji = YES;
	[text enumerateSubstringsInRange:NSMakeRange(0, text.length)
							 options:NSStringEnumerationByComposedCharacterSequences
						  usingBlock:^(NSString *piece, NSRange range,
							  NSRange enclosing, BOOL *stop) {
							  if (!TGIsEmojiPiece(piece)) {
								  onlyEmoji = NO;
								  *stop = YES;
								  return;
							  }
							  count++;
						  }];
	if (!onlyEmoji || count == 0)
		return 0;

	if ([self quoteTextFor:m] || [m[@"forward"] length])
		return 0;
	if ([self previewSizeFor:m].height > 0)
		return 0;
	return count;
}

static CGFloat TGLargeEmojiFontSize(NSInteger count) {
	static const CGFloat multipliers[] = {
		1.0f, 0.84f, 0.69f, 0.53f, 0.46f, 0.38f, 0.32f, 0.27f, 0.24f};
	const NSInteger known = (NSInteger)(sizeof(multipliers) / sizeof(multipliers[0]));
	CGFloat multiplier = (count >= 1 && count <= known)
		? multipliers[count - 1]
		: 0.21f;
	return floorf(94.0f * multiplier);
}

- (UIFont *)bodyFontFor:(NSDictionary *)m {
	NSInteger emoji = [self largeEmojiCountFor:m];
	if (emoji > 0)
		return [UIFont systemFontOfSize:TGLargeEmojiFontSize(emoji)];
	if ([m[@"kind"] isEqualToString:@"messageDice"] && ![self messageIsSticker:m])
		return [UIFont systemFontOfSize:TGLargeEmojiFontSize(1)];
	return [UIFont systemFontOfSize:TGMessageBaseFontSize()];
}

- (NSString *)liveLocationLineFor:(NSDictionary *)m {
	NSInteger period = [m[@"livePeriod"] integerValue];
	if (period <= 0)
		return nil;
	NSTimeInterval expiresAt = [m[@"liveExpiresAt"] doubleValue];
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	if (TGLiveLocationHasExpired(period, expiresAt, now))
		return TGL(@"Chat.LiveLocationEnded", @"Live location ended");

	NSTimeInterval since1970 = expiresAt + NSTimeIntervalSince1970;
	return [NSString stringWithFormat:TGL(@"Chat.LiveLocationUntil", @"Live until %@"),
		[TGDateUtils stringForShortTime:(int)since1970]];
}

- (BOOL)messageBurnsOnOpening:(NSDictionary *)m {
	if (![m[@"viewOnce"] boolValue] && ![m[@"secretMedia"] boolValue])
		return NO;
	NSString *kind = [m[@"kind"] isKindOfClass:NSString.class] ? m[@"kind"] : @"";
	return [kind isEqualToString:@"messagePhoto"] ||
		[kind isEqualToString:@"messageVideo"] ||
		[kind isEqualToString:@"messageVideoNote"] ||
		[kind isEqualToString:@"messageVoiceNote"];
}

- (NSString *)burnLabelFor:(NSDictionary *)m {
	if (![self messageBurnsOnOpening:m])
		return nil;
	NSString *kind = [m[@"kind"] isKindOfClass:NSString.class] ? m[@"kind"] : @"";
	NSInteger timer = [m[@"destructTimer"] integerValue];
	NSString *line = TGBurnLabelLineForKind(kind, [m[@"outgoing"] boolValue], timer);

	NSString *caption = [m[@"text"] isKindOfClass:NSString.class] ? m[@"text"] : nil;
	if (!caption.length)
		return line;
	return [NSString stringWithFormat:@"%@\n%@", line, caption];
}

- (BOOL)bubbleTextUsesPlainMessageText:(NSDictionary *)m {
	if ([self burnLabelFor:m].length)
		return NO;
	if ([self messageIsSticker:m])
		return NO;
	if ([m[@"kind"] isEqualToString:@"messageLocation"])
		return NO;
	if ([m[@"kind"] isEqualToString:@"messageLiveLocation"] &&
		[self liveLocationLineFor:m].length)
		return NO;
	return YES;
}

- (NSString *)factCheckTextFor:(NSDictionary *)m {
	NSString *text = [m[@"factCheckText"] isKindOfClass:NSString.class]
		? m[@"factCheckText"]
		: nil;
	return text.length ? text : nil;
}

- (NSString *)appendingFactCheckTo:(NSString *)base
						forMessage:(NSDictionary *)m
						quoteRange:(NSRange *)outRange {
	NSString *factCheck = [self factCheckTextFor:m];
	if (!factCheck.length) {
		if (outRange)
			*outRange = NSMakeRange(NSNotFound, 0);
		return base;
	}
	NSString *separator = base.length ? @"\n\n" : @"";
	NSString *quoteBody = [NSString stringWithFormat:@"%@\n%@", TGL(@"Message.FactCheck", @"Fact Check"), factCheck];
	if (outRange)
		*outRange = NSMakeRange(base.length + separator.length, quoteBody.length);
	return [NSString stringWithFormat:@"%@%@%@", base ?: @"", separator, quoteBody];
}

- (NSString *)suggestedPostLineFor:(NSDictionary *)m {
	NSString *state = [m[@"suggestedPostState"] isKindOfClass:NSString.class]
		? m[@"suggestedPostState"]
		: nil;
	if (!state.length)
		return nil;

	NSString *label = [state isEqualToString:@"pending"]
		? TGL(@"Chat.SuggestedPostAwaitingApproval", @"Suggested post - awaiting approval")
		: [state isEqualToString:@"approved"] ? TGL(@"Chat.SuggestedPostApproved", @"Suggested post - approved")
		: [state isEqualToString:@"declined"] ? TGL(@"Chat.SuggestedPostDeclined", @"Suggested post - declined")
											  : nil;
	if (!label)
		return nil;

	NSString *price = [m[@"suggestedPostPrice"] isKindOfClass:NSString.class]
		? m[@"suggestedPostPrice"]
		: nil;
	NSMutableString *line = [label mutableCopy];
	if (price.length)
		[line appendFormat:@" - %@", price];

	long long sendDate = [m[@"suggestedPostSendDate"] longLongValue];
	if (sendDate > 0) {
		[line appendFormat:TGL(@"Chat.SuggestedPostSendsFormat", @" - sends %@"),
			[TGDateUtils stringForDateAndTime:(int)sendDate]];
	}
	return line;
}

- (NSString *)appendingSuggestedPostTo:(NSString *)base
							forMessage:(NSDictionary *)m
							quoteRange:(NSRange *)outRange {
	NSString *line = [self suggestedPostLineFor:m];
	if (!line.length) {
		if (outRange)
			*outRange = NSMakeRange(NSNotFound, 0);
		return base;
	}
	NSString *separator = base.length ? @"\n\n" : @"";
	if (outRange)
		*outRange = NSMakeRange(base.length + separator.length, line.length);
	return [NSString stringWithFormat:@"%@%@%@", base ?: @"", separator, line];
}

- (NSString *)bubbleTextFor:(NSDictionary *)m {
	NSString *burn = [self burnLabelFor:m];
	if (burn.length)
		return burn;
	if ([self messageIsSticker:m])
		return nil;
	if ([m[@"kind"] isEqualToString:@"messageLocation"])
		return nil;
	if ([m[@"kind"] isEqualToString:@"messageLiveLocation"]) {
		NSString *countdown = [self liveLocationLineFor:m];
		NSString *caption = [self textOf:m];
		if (countdown.length)
			return [NSString stringWithFormat:@"%@\n%@",
				caption.length ? caption : TGL(@"Message.LiveLocation", @"Live location"), countdown];
	}
	NSString *withFactCheck = [self appendingFactCheckTo:[self textOf:m] forMessage:m quoteRange:NULL];
	return [self appendingSuggestedPostTo:withFactCheck forMessage:m quoteRange:NULL];
}

- (NSArray *)entitiesOf:(NSDictionary *)m {
	if ([self messageBurnsOnOpening:m])
		return nil;
	NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
	if (messageId && self.aiSummaries[messageId])
		return nil;
	if (messageId && self.translations[messageId])
		return self.translationEntities[messageId] ?: nil;
	NSArray *entities = m[@"entities"];
	NSArray *base = [entities isKindOfClass:NSArray.class] && entities.count ? entities : nil;

	if (![self bubbleTextUsesPlainMessageText:m])
		return base;

	NSRange quoteRange;
	NSString *withFactCheck = [self appendingFactCheckTo:[self textOf:m] forMessage:m
											  quoteRange:&quoteRange];
	NSRange postRange;
	[self appendingSuggestedPostTo:withFactCheck forMessage:m quoteRange:&postRange];

	if (quoteRange.location == NSNotFound && postRange.location == NSNotFound)
		return base;

	NSMutableArray *out = base ? [base mutableCopy] : [NSMutableArray array];
	if (quoteRange.location != NSNotFound) {
		[out addObject:@{
			@"kind" : @"BlockQuote",
			@"offset" : @(quoteRange.location),
			@"length" : @(quoteRange.length),
			@"url" : @"",
			@"userId" : @0,
			@"language" : @"",
			@"timestamp" : @0,
		}];
		NSInteger factCheckStart = quoteRange.location
			+ (NSInteger)[[NSString stringWithFormat:@"%@\n", TGL(@"Message.FactCheck", @"Fact Check")] length];
		NSArray *factCheckEntities = [m[@"factCheckEntities"] isKindOfClass:NSArray.class]
			? m[@"factCheckEntities"]
			: nil;
		for (NSDictionary *entity in factCheckEntities) {
			if (![entity isKindOfClass:NSDictionary.class])
				continue;
			NSMutableDictionary *shifted = [entity mutableCopy];
			shifted[@"offset"] = @([entity[@"offset"] integerValue] + factCheckStart);
			[out addObject:shifted];
		}
	}
	if (postRange.location != NSNotFound) {
		[out addObject:@{
			@"kind" : @"BlockQuote",
			@"offset" : @(postRange.location),
			@"length" : @(postRange.length),
			@"url" : @"",
			@"userId" : @0,
			@"language" : @"",
			@"timestamp" : @0,
		}];
	}
	return out;
}

- (TGRichTextPalette *)bodyPaletteFor:(NSDictionary *)m {
	TGTheme *theme = [TGTheme shared];
	UIColor *ink = TGMessageBodyColour();
	UIColor *accent = TGActiveChatThemeAccentColour(self.chatId) ?: [theme accentColour];
	TGRichTextPalette *palette =
		[TGRichTextPalette paletteWithFont:[self bodyFontFor:m]
									colour:ink
								linkColour:TGMessageLinkColour()
							  accentColour:accent];
	palette.codeBackgroundColour = [UIColor colorWithWhite:0.0f alpha:0.07f];
	return palette;
}

static const CGFloat kCaptionMinWrapWidth = 120.0f;

- (CGFloat)captionWidthCapFor:(NSDictionary *)m {
	NSString *kind = m[@"kind"];
	BOOL captioned = [kind isEqualToString:@"messagePhoto"] ||
		[kind isEqualToString:@"messageVideo"] ||
		[kind isEqualToString:@"messageAnimation"];
	if (!captioned || [self messageCanTile:m])
		return 0;
	CGFloat width = [self imageSizeFor:m].width;
	return width >= kCaptionMinWrapWidth ? width : 0;
}

- (TGRichTextLayout *)bodyLayoutFor:(NSDictionary *)m {
	NSArray *entities = [self entitiesOf:m];
	if (!entities.count)
		return nil;
	NSString *text = [self bubbleTextFor:m] ?: @"";
	if (!text.length)
		return nil;

	CGFloat maxW = floorf([self maxBubbleWidthFor:m] - 2 * kPadH);
	CGFloat cap = [self captionWidthCapFor:m];
	if (cap > 0)
		maxW = MIN(maxW, cap);
	NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
	BOOL revealed = messageId && [self.revealedSpoilers containsObject:messageId];
	NSSet *expanded = messageId ? self.expandedQuotes[messageId] : nil;
	NSString *key = [NSString stringWithFormat:@"%@|%.0f|%.1f|%d|%lu|%lu",
		messageId ?: @0, maxW, TGMessageBaseFontSize(), revealed ? 1 : 0,
		(unsigned long)expanded.count, (unsigned long)text.hash];

	NSArray *cached = messageId ? self.bodyLayouts[messageId] : nil;
	if (cached.count == 2 && [cached[0] isEqualToString:key])
		return cached[1];

	NSAttributedString *styled = TGRichTextBuild(text, entities,
		[self bodyPaletteFor:m], revealed);
	NSTextAlignment alignment = TGTextIsRightToLeft(text) ? NSTextAlignmentRight : NSTextAlignmentLeft;
	TGRichTextLayout *layout = [TGRichTextLayout
		layoutWithText:styled
				 width:maxW
			  maxLines:0
			 alignment:alignment
		expandedBlocks:expanded];
	if (messageId && layout) {
		[self.bodyLayoutOrder removeObject:messageId];
		[self.bodyLayoutOrder addObject:messageId];
		NSArray *stale = TGCacheTrimKeys(self.bodyLayoutOrder, 200, 150);
		if (stale.count) {
			[self.bodyLayouts removeObjectsForKeys:stale];
			[self.bodyLayoutOrder removeObjectsInArray:stale];
			if (TGPerfLogging())
				NSLog(@"PERF cachetrim bodyLayouts dropped=%lu left=%lu",
					(unsigned long)stale.count, (unsigned long)self.bodyLayouts.count);
		}
		self.bodyLayouts[messageId] = @[ key, layout ];
	}
	return layout;
}

- (UIImage *)imageFor:(NSDictionary *)m {
	if ([self messageCarriesMapCard:m])
		return [self mapCardFor:m];
	if ([self messageBurnsOnOpening:m])
		return nil;
	NSNumber *fileId = [self pictureFileIdFor:m];
	return fileId ? self.images[fileId] : nil;
}

- (NSString *)pictureKindOf:(NSDictionary *)m {
	return [m[@"kind"] isKindOfClass:NSString.class] ? m[@"kind"] : @"";
}

- (CGFloat)mediaMaxSide {
	CGFloat budget = [self bubbleWidthBudget];
	if (budget <= kBubbleMaxW)
		return kImageMax;
	return floorf(kImageMax * budget / kBubbleMaxW);
}

- (CGSize)drawnSizeForImageSize:(CGSize)source {
	if (source.width < 1 || source.height < 1)
		return CGSizeZero;
	CGFloat side = [self mediaMaxSide];
	CGFloat scale = MIN(side / source.width, side / source.height);
	scale = MIN(scale, 1.0f);
	return CGSizeMake(floorf(source.width * scale), floorf(source.height * scale));
}

- (CGSize)drawnPointSizeFor:(NSDictionary *)m {
	CGSize tile = [self tileSizeForMessage:m];
	if (tile.width >= 1 && tile.height >= 1)
		return tile;
	if ([self messageCarriesMapCard:m])
		return [self drawnSizeForImageSize:CGSizeMake(kMapCardW, kMapCardH)];

	CGSize declared = [self declaredPixelSizeFor:m];
	if ([self messageIsSticker:m])
		return TGStickerFittedSize(declared, NO);
	if (declared.width >= 1 && declared.height >= 1)
		return [self drawnSizeForImageSize:declared];
	return [self reservedPictureSizeFor:m];
}

- (CGFloat)decodeLimitFor:(NSDictionary *)m {
	CGSize drawn = [self drawnPointSizeFor:m];
	if (drawn.width < 1 || drawn.height < 1)
		return [self pictureDecodeLimit];
	CGFloat screen = [UIScreen mainScreen].scale;
	if (screen < 1.0f)
		screen = 1.0f;
	CGFloat needW = drawn.width * screen;
	CGFloat needH = drawn.height * screen;
	CGFloat side = MAX(needW, needH);
	CGSize source = [self declaredPixelSizeFor:m];
	if (source.width >= 1 && source.height >= 1) {
		CGFloat cover = MIN(1.0f, MAX(needW / source.width, needH / source.height));
		side = MAX(source.width, source.height) * cover;
	}
	return MIN([self pictureDecodeLimit], ceilf(side));
}

- (NSNumber *)pictureFileIdFor:(NSDictionary *)m {
	NSNumber *fileId = m[@"photoId"];
	if (![fileId isKindOfClass:NSNumber.class] || [fileId longLongValue] == 0)
		return nil;

	NSArray *sizes = m[@"photoSizes"];
	if (![sizes isKindOfClass:NSArray.class] || sizes.count < 2)
		return fileId;

	CGSize drawn = [self drawnPointSizeFor:m];
	if (drawn.width < 1 || drawn.height < 1)
		return fileId;

	CGFloat screen = [UIScreen mainScreen].scale;
	CGFloat needW = drawn.width * screen;
	CGFloat needH = drawn.height * screen;
	for (NSDictionary *size in sizes) {
		if ([size[@"w"] floatValue] >= needW && [size[@"h"] floatValue] >= needH)
			return size[@"id"];
	}
	return fileId;
}

- (BOOL)messageCarriesPicture:(NSDictionary *)m {
	if ([self messageBurnsOnOpening:m])
		return NO;
	if (![self pictureFileIdFor:m])
		return NO;
	NSString *kind = [self pictureKindOf:m];
	return [kind isEqualToString:@"messagePhoto"] ||
		[kind isEqualToString:@"messageVideo"] ||
		[kind isEqualToString:@"messageAnimation"] ||
		[kind isEqualToString:@"messageVideoNote"] ||
		[kind isEqualToString:@"messageSticker"] ||
		[kind isEqualToString:@"messageAnimatedEmoji"];
}

- (CGSize)declaredPixelSizeFor:(NSDictionary *)m {
	NSNumber *w = m[@"photoWidth"];
	NSNumber *h = m[@"photoHeight"];
	if (![w isKindOfClass:NSNumber.class] || ![h isKindOfClass:NSNumber.class])
		return CGSizeZero;
	if ([w floatValue] < 1 || [h floatValue] < 1)
		return CGSizeZero;
	return CGSizeMake([w floatValue], [h floatValue]);
}

- (TGFileStatusKind)mediaStatusKindFor:(NSDictionary *)m
								 state:(NSDictionary *)state {
	if ([state[@"active"] boolValue] && ![state[@"local"] boolValue])
		return TGFileStatusKindProgress;
	if ([state[@"local"] boolValue] || [m[@"supportsStreaming"] boolValue])
		return TGFileStatusKindPlay;
	if ([state[@"size"] longLongValue] > 0)
		return TGFileStatusKindDownload;
	return TGFileStatusKindPlay;
}

- (NSString *)mediaBadgeTextFor:(NSDictionary *)m {
	NSString *kind = m[@"kind"];
	BOOL isGif = [kind isEqualToString:@"messageAnimation"];
	if (!isGif && ![kind isEqualToString:@"messageVideo"])
		return nil;

	NSMutableArray *parts = [NSMutableArray array];
	if (isGif) {
		[parts addObject:TGL(@"Message.Animation", @"GIF")];
	} else {
		NSInteger seconds = [m[@"duration"] integerValue];
		if (seconds > 0)
			[parts addObject:TGDurationText(seconds)];
	}

	NSDictionary *state = [self fileStateFor:m];
	if (![state[@"local"] boolValue]) {
		NSString *size = [state[@"active"] boolValue]
			? [NSString stringWithFormat:@"%@ / %@",
				  TGFormatByteCount([state[@"downloaded"] longLongValue]),
				  TGFormatByteCount([state[@"size"] longLongValue])]
			: TGFormatByteCount([state[@"size"] longLongValue]);
		if (size.length)
			[parts addObject:size];
	}

	if (!parts.count)
		return nil;
	return [parts componentsJoinedByString:@", "];
}

- (BOOL)animatedEmojiWithoutSticker:(NSDictionary *)m {
	if (![m[@"kind"] isEqualToString:@"messageAnimatedEmoji"])
		return NO;
	if ([m[@"photoId"] isKindOfClass:NSNumber.class] &&
		[m[@"photoId"] longLongValue] != 0)
		return NO;
	if ([m[@"docId"] isKindOfClass:NSNumber.class] &&
		[m[@"docId"] longLongValue] != 0)
		return NO;
	return [self textOf:m].length > 0;
}

- (BOOL)messageDiceHasFinalArtwork:(NSDictionary *)m {
	if (![m[@"kind"] isEqualToString:@"messageDice"])
		return NO;
	if ([m[@"photoId"] isKindOfClass:NSNumber.class] &&
		[m[@"photoId"] longLongValue] != 0)
		return YES;
	return [m[@"docId"] isKindOfClass:NSNumber.class] &&
		[m[@"docId"] longLongValue] != 0;
}

- (BOOL)messageIsSticker:(NSDictionary *)m {
	if ([self animatedEmojiWithoutSticker:m])
		return NO;
	NSString *kind = [self pictureKindOf:m];
	if ([kind isEqualToString:@"messageSticker"] ||
		[kind isEqualToString:@"messageAnimatedEmoji"])
		return YES;
	return [self messageDiceHasFinalArtwork:m];
}

static CGSize TGStickerFittedSize(CGSize source, BOOL animated) {
	CGFloat side = animated ? 180.0f : 184.0f;
	if (source.width < 1 || source.height < 1)
		return CGSizeMake(side, side);
	CGFloat scale = MIN(side / source.width, side / source.height);
	return CGSizeMake(floorf(source.width * scale),
		floorf(source.height * scale));
}

- (CGSize)reservedPictureSizeFor:(NSDictionary *)m {
	NSString *kind = [self pictureKindOf:m];
	if ([kind isEqualToString:@"messageVideoNote"])
		return CGSizeMake(178, 178);
	if ([self messageIsSticker:m])
		return TGStickerFittedSize(CGSizeZero, NO);
	return [self drawnSizeForImageSize:CGSizeMake(800, 600)];
}

- (CGSize)imageSizeFor:(NSDictionary *)m {
	if ([self messageCarriesMapCard:m])
		return [self drawnSizeForImageSize:CGSizeMake(kMapCardW, kMapCardH)];
	if ([self messageBurnsOnOpening:m])
		return CGSizeZero;

	CGSize declared = [self declaredPixelSizeFor:m];
	if ([self messageIsSticker:m]) {
		if (declared.width < 1 || declared.height < 1)
			declared = [self imageFor:m].size;
		return TGStickerFittedSize(declared, NO);
	}
	if (declared.width >= 1 && declared.height >= 1)
		return [self drawnSizeForImageSize:declared];

	UIImage *img = [self imageFor:m];
	if (img)
		return [self drawnSizeForImageSize:img.size];
	if ([self messageCarriesPicture:m])
		return [self reservedPictureSizeFor:m];
	return CGSizeZero;
}

- (UIImage *)minithumbnailImageFor:(NSDictionary *)m {
	NSNumber *key = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
	if (!key)
		return nil;
	id cached = self.minithumbnails[key];
	return [cached isKindOfClass:[UIImage class]] ? cached : nil;
}

- (void)warmMinithumbnailsFor:(NSArray *)messages {
	NSMutableArray *pending = [NSMutableArray array];
	for (NSDictionary *m in messages) {
		NSNumber *key = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
		id raw = m[@"minithumbnail"];
		if (!key || !raw || raw == [NSNull null] || self.minithumbnails[key])
			continue;
		self.minithumbnails[key] = [NSNull null];
		[pending addObject:@[ key, raw ]];
	}
	if (!pending.count)
		return;

	if (pending.count <= 4) {
		for (NSArray *entry in pending) {
			id raw = entry[1];
			NSData *data = [raw isKindOfClass:NSData.class]
				? raw
				: [[TGClient shared] minithumbnailData:raw];
			UIImage *image = data.length ? [UIImage imageWithData:data] : nil;
			if (image)
				self.minithumbnails[entry[0]] = image;
		}
		return;
	}

	__weak typeof(self) weakSelf = self;
	dispatch_async(TGImageDecodeQueue(), ^{
		NSMutableDictionary *decoded = [NSMutableDictionary dictionary];
		@autoreleasepool {
			for (NSArray *entry in pending) {
				id raw = entry[1];
				NSData *data = [raw isKindOfClass:NSData.class]
					? raw
					: [[TGClient shared] minithumbnailData:raw];
				UIImage *image = data.length ? [UIImage imageWithData:data] : nil;
				if (image)
					decoded[entry[0]] = image;
			}
		}
		if (!decoded.count)
			return;
		dispatch_async(dispatch_get_main_queue(), ^{
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			[strongSelf.minithumbnails addEntriesFromDictionary:decoded];
			[strongSelf setNeedsTableReload];
		});
	});
}

- (BOOL)pictureFailedFor:(NSDictionary *)m {
	NSNumber *fileId = [self pictureFileIdFor:m];
	return fileId && [self.photoFilesFailed containsObject:fileId];
}

- (UIImage *)retryGlyphOfSide:(CGFloat)side {
	static NSMutableDictionary *cache = nil;
	if (!cache)
		cache = [NSMutableDictionary dictionary];
	NSNumber *key = @(side);
	UIImage *cached = cache[key];
	if (cached)
		return cached;

	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0.0f);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0 alpha:0.45f].CGColor);
	CGContextFillEllipseInRect(ctx, CGRectMake(0, 0, side, side));
	CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
	CGContextSetLineWidth(ctx, 2.0f);
	CGFloat inset = side * 0.28f;
	CGRect arc = CGRectMake(inset, inset, side - 2 * inset, side - 2 * inset);
	CGContextAddArc(ctx, CGRectGetMidX(arc), CGRectGetMidY(arc),
		arc.size.width / 2, (CGFloat)(-M_PI_2), (CGFloat)(M_PI), 0);
	CGContextStrokePath(ctx);
	CGFloat tip = CGRectGetMidX(arc);
	CGFloat top = CGRectGetMinY(arc);
	CGContextMoveToPoint(ctx, tip - 4, top);
	CGContextAddLineToPoint(ctx, tip + 4, top);
	CGContextAddLineToPoint(ctx, tip, top + 5);
	CGContextClosePath(ctx);
	CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
	CGContextFillPath(ctx);
	UIImage *glyph = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	if (glyph)
		cache[key] = glyph;
	return glyph;
}

- (UIColor *)picturePlaceholderColour {
	return [UIColor colorWithWhite:0 alpha:0.10f];
}

- (UIImage *)picture:(UIImage *)image forMessage:(NSDictionary *)m
			  atSize:(CGSize)points {
	if (!image || points.width < 1 || points.height < 1)
		return image;

	CGFloat screen = [UIScreen mainScreen].scale;
	CGFloat sourceW = image.size.width * image.scale;
	CGFloat sourceH = image.size.height * image.scale;
	if (sourceW < 1 || sourceH < 1)
		return image;

	CGFloat cover = MAX(points.width * screen / sourceW,
		points.height * screen / sourceH);
	if (cover >= 1.0f)
		return image;
	CGSize target = CGSizeMake(MAX(1.0f, floorf(sourceW * cover / screen)),
		MAX(1.0f, floorf(sourceH * cover / screen)));

	NSNumber *fileId = [self pictureFileIdFor:m];
	if (!fileId)
		return TGImageDrawnAtPointSize(image, target);

	NSString *key = [NSString stringWithFormat:@"%@@%dx%d", fileId,
		(int)roundf(points.width), (int)roundf(points.height)];
	UIImage *cached = self.tileBitmaps[key];
	if (cached)
		return cached;

	if (![self.tileBitmapsRequested containsObject:key]) {
		[self.tileBitmapsRequested addObject:key];
		__weak typeof(self) weakSelf = self;
		dispatch_async(TGImageDecodeQueue(), ^{
			UIImage *drawn = nil;
			@autoreleasepool {
				drawn = TGImageDrawnAtPointSize(image, target);
			}
			dispatch_async(dispatch_get_main_queue(), ^{
				TGChatViewController *strongSelf = weakSelf;
				if (!strongSelf)
					return;
				[strongSelf.tileBitmapsRequested removeObject:key];
				if (!drawn)
					return;
				if (strongSelf.tileBitmaps.count > 80) {
					[strongSelf.tileBitmaps removeAllObjects];
					[strongSelf.tileBitmapsRequested removeAllObjects];
				}
				strongSelf.tileBitmaps[key] = drawn;
			});
		});
	}
	return image;
}

- (void)applyPictureTo:(UIImageView *)view message:(NSDictionary *)m {
	[self applyPictureTo:view message:m atSize:CGSizeZero];
}

- (BOOL)mediaSpoilerActiveForMessage:(NSDictionary *)m {
	if (![m[@"hasSpoiler"] boolValue])
		return NO;
	NSNumber *messageId = [m[@"id"] isKindOfClass:NSNumber.class] ? m[@"id"] : nil;
	return !messageId || ![self.revealedMediaSpoilers containsObject:messageId];
}

- (void)applyPictureTo:(UIImageView *)view
			   message:(NSDictionary *)m
				atSize:(CGSize)points {
	BOOL spoilerActive = [self mediaSpoilerActiveForMessage:m];

	UIImage *shown = spoilerActive ? nil : [self imageFor:m];
	if (shown && !spoilerActive && points.width >= 1 && points.height >= 1)
		shown = [self picture:shown forMessage:m atSize:points];
	if (!shown)
		shown = [self minithumbnailImageFor:m];
	if (!shown && !spoilerActive && points.width >= 1 && points.height >= 1)
		shown = [self stickerOutlineImageForMessage:m atSize:points];
	view.image = shown;
	view.backgroundColor = shown ? [UIColor clearColor] : [self picturePlaceholderColour];
	[self setMediaSpoilerCoverVisible:spoilerActive onView:view];
}

- (void)setMediaSpoilerCoverVisible:(BOOL)visible onView:(UIImageView *)view {
	static const NSInteger kCoverTag = 0x5901;
	UIView *cover = [view viewWithTag:kCoverTag];
	if (!visible) {
		[cover removeFromSuperview];
		return;
	}
	if (!cover) {
		cover = [[UIView alloc] initWithFrame:view.bounds];
		cover.tag = kCoverTag;
		cover.userInteractionEnabled = NO;
		cover.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		cover.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35f];

		UILabel *label = [[UILabel alloc] init];
		label.text = TGL(@"Message.TapToView", @"Tap to view");
		label.font = [UIFont boldSystemFontOfSize:13];
		label.textColor = [UIColor whiteColor];
		label.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45f];
		label.textAlignment = NSTextAlignmentCenter;
		label.layer.cornerRadius = 4;
		label.clipsToBounds = YES;
		[label sizeToFit];
		CGRect frame = label.frame;
		frame.size.width += 16;
		frame.size.height += 8;
		label.frame = frame;
		label.autoresizingMask = UIViewAutoresizingFlexibleTopMargin |
			UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin |
			UIViewAutoresizingFlexibleRightMargin;
		[cover addSubview:label];
		[view addSubview:cover];
	}
	cover.frame = view.bounds;
	for (UIView *sub in cover.subviews)
		sub.center = CGPointMake(CGRectGetMidX(cover.bounds), CGRectGetMidY(cover.bounds));
}

- (UIImage *)stickerOutlineImageForMessage:(NSDictionary *)m atSize:(CGSize)points {
	NSString *kind = m[@"kind"];
	BOOL isSticker = [kind isEqualToString:@"messageSticker"] ||
		[kind isEqualToString:@"messageAnimatedEmoji"];
	if (!isSticker)
		return nil;
	NSNumber *fileId = [m[@"photoId"] isKindOfClass:NSNumber.class] ? m[@"photoId"] : nil;
	if (!fileId || !fileId.longLongValue)
		return nil;

	NSString *key = [NSString stringWithFormat:@"%lld:%dx%d", fileId.longLongValue,
		(int)points.width, (int)points.height];
	UIImage *cached = self.stickerOutlineImages[key];
	if (cached)
		return cached;
	if ([self.stickerOutlinesRequested containsObject:key])
		return nil;
	[self.stickerOutlinesRequested addObject:key];

	CGFloat width = [m[@"photoWidth"] doubleValue];
	CGFloat height = [m[@"photoHeight"] doubleValue];
	if (width <= 0 || height <= 0) {
		width = 512;
		height = 512;
	}

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] stickerOutlineForFileId:fileId.longLongValue completion:^(NSArray *paths) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		UIImage *outline = [strongSelf renderStickerOutlinePaths:paths width:width height:height fitSize:points];
		if (!outline)
			return;
		strongSelf.stickerOutlineImages[key] = outline;
		[strongSelf setNeedsTableReloadKeepingBottom];
	}];
	return nil;
}

- (UIImage *)renderStickerOutlinePaths:(NSArray *)paths
								 width:(CGFloat)width
								height:(CGFloat)height
							   fitSize:(CGSize)fitSize {
	if (!paths.count || width <= 0 || height <= 0)
		return nil;

	CGFloat factor = MIN(fitSize.width / width, fitSize.height / height);
	CGSize target = CGSizeMake(floorf(width * factor), floorf(height * factor));
	if (target.width < 1 || target.height < 1)
		return nil;

	UIBezierPath *bezier = [UIBezierPath bezierPath];
	for (NSArray *path in paths) {
		if (![path isKindOfClass:[NSArray class]] || !path.count)
			continue;
		NSInteger index = 0;
		for (NSDictionary *command in path) {
			if (![command isKindOfClass:[NSDictionary class]])
				continue;
			CGPoint point = CGPointMake([command[@"x"] doubleValue] * factor,
				[command[@"y"] doubleValue] * factor);
			if (index == 0) {
				[bezier moveToPoint:point];
			} else if ([command[@"type"] isEqualToString:@"curve"]) {
				CGPoint control1 = CGPointMake([command[@"c1x"] doubleValue] * factor,
					[command[@"c1y"] doubleValue] * factor);
				CGPoint control2 = CGPointMake([command[@"c2x"] doubleValue] * factor,
					[command[@"c2y"] doubleValue] * factor);
				[bezier addCurveToPoint:point controlPoint1:control1 controlPoint2:control2];
			} else {
				[bezier addLineToPoint:point];
			}
			index++;
		}
		[bezier closePath];
	}
	if (bezier.isEmpty)
		return nil;

	UIImage *result = nil;
	@autoreleasepool {
		UIGraphicsBeginImageContextWithOptions(target, NO, [UIScreen mainScreen].scale);
		[[self picturePlaceholderColour] setFill];
		[bezier fill];
		result = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
	}
	return result;
}

- (long)dayOrdinalForMessage:(NSDictionary *)m {
	time_t stamp = (time_t)[m[@"date"] doubleValue];
	struct tm parts;
	localtime_r(&stamp, &parts);
	return (long)parts.tm_year * 512 + parts.tm_yday;
}

- (NSString *)dayStringForMessage:(NSDictionary *)m {
	return [TGDateUtils stringForDayDivider:(int)[m[@"date"] doubleValue]];
}

- (BOOL)rowOpensNewDay:(NSInteger)row {
	NSDictionary *m = [self messageAtRow:row];
	if (!m || ![m[@"date"] doubleValue])
		return NO;
	if (row == 0)
		return YES;
	NSDictionary *prev = [self messageAtRow:row - 1];
	if (![prev[@"date"] doubleValue])
		return NO;
	return [self dayOrdinalForMessage:prev] != [self dayOrdinalForMessage:m];
}

- (NSInteger)firstRowPastTheReadMark {
	NSInteger count = [self displayRowCount];
	for (NSInteger i = 0; i < count; i++) {
		NSDictionary *m = [self messageAtRow:i];
		if ([m[@"outgoing"] boolValue] || [m[@"service"] boolValue])
			continue;
		if (![m[@"id"] isKindOfClass:NSNumber.class])
			continue;
		if ([m[@"id"] longLongValue] > self.lastReadInboxOnOpen)
			return i;
	}
	return NSNotFound;
}

- (NSInteger)rowCountingBackTheUnreadOnes {
	NSInteger remaining = self.unreadOnOpen;
	NSInteger row = NSNotFound;
	for (NSInteger i = [self displayRowCount] - 1; i >= 0; i--) {
		NSDictionary *m = [self messageAtRow:i];
		if ([m[@"outgoing"] boolValue] || [m[@"service"] boolValue])
			continue;
		row = i;
		remaining -= (NSInteger)[self messagesAtRow:i].count;
		if (remaining <= 0)
			break;
	}
	return (row == 0) ? NSNotFound : row;
}

- (NSInteger)unreadDividerRow {
	if (self.chatSearchBar || self.unreadOnOpen <= 0)
		return NSNotFound;
	if (self.messages && self.cachedUnreadKey == self.messages)
		return self.cachedUnreadRow;
	NSInteger row = self.lastReadInboxOnOpen != 0
		? [self firstRowPastTheReadMark]
		: [self rowCountingBackTheUnreadOnes];
	self.cachedUnreadKey = self.messages;
	self.cachedUnreadRow = row;
	return row;
}

@end

#import "TGMessageLayoutBuilder.h"
#import "TGMessageLayoutBuilder+Private.h"
#import "TGMessageLayout+Construction.h"
#import "TGMessageItem.h"
#import "TGChatLayoutContext.h"
#import "TGMessage.h"
#import "TGRichText.h"
#import "TGEmoji.h"
#import "TGIcons.h"
#import "TGReactionPickerView.h"
#import <string.h>

const CGFloat kBubbleBudgetReferenceWidth = 320.0f;

const CGFloat kMessageLayoutPadH = 10.0f;
const CGFloat kMessageLayoutPadV = 5.0f;
const CGFloat kMessageLayoutAvatarSide = 38.0f;
const CGFloat kMessageLayoutBubbleMinW = 40.0f;
const CGFloat kMessageLayoutCaptionMinWrapWidth = 120.0f;
static const CGFloat kMessageLayoutForwardLineSlack = 6.0f;
const CGFloat kMessageLayoutBubbleMinH = 31.0f;
const CGFloat kMessageLayoutBubbleMaxW = 244.0f;
const CGFloat kMessageLayoutBubbleTailOverhang = 6.0f;
const CGFloat kMessageLayoutForwardJumpSide = 24.0f;
const CGFloat kMessageLayoutForwardJumpGap = 4.0f;
const CGFloat kMessageLayoutDayRowHeight = 27.0f;
const CGFloat kMessageLayoutUnreadRowHeight = 34.0f;
const CGFloat kMessageLayoutSignatureHeight = 14.0f;
const CGFloat kMessageLayoutSignatureTopGap = 2.0f;
const CGFloat kMessageLayoutRetinaPixel = 0.5f;

static const CGFloat kBubbleBudgetAtReference = 250.0f;
static const CGFloat kBubbleOutgoingTrim = 12.0f;
static const CGFloat kBubbleAvatarTrim = 40.0f;
static const CGFloat kSignatureHeight = kMessageLayoutSignatureHeight;
static const CGFloat kSignatureTopGap = kMessageLayoutSignatureTopGap;
static const CGFloat kChipsBubbleTopPad = 4.0f;
static const CGFloat kChipsBubbleBottomPad = 6.0f;
static const CGFloat kChipsBareTopPad = 6.0f;
static const CGFloat kChipsBareBottomPad = 2.0f;
static const CGFloat kCommentsRowHeight = 32.0f;
static const CGFloat kCommentsTopPad = 4.0f;
static const CGFloat kCommentsBottomPad = 4.0f;
static const CGFloat kBareStampBand = 14.0f;
static const CGFloat kViewsEyeWidth = 12.0f;
static const CGFloat kViewsTimeGap = 6.0f;
static const CGFloat kPreviewBar = 2.0f;
static const CGFloat kPreviewGap = 8.0f;
static const CGFloat kPreviewThumb = 52.0f;
static const CGFloat kPreviewLargeMax = 160.0f;
static const CGFloat kInstantHeight = 33.0f;

TGMessageLayoutComputed TGMessageLayoutComputedZero(void) {
	TGMessageLayoutComputed computed;
	memset(&computed, 0, sizeof(computed));
	return computed;
}

CGFloat TGMessageLayoutHeaderHeight(TGMessageItem *item) {
	CGFloat h = 0;
	if (item.opensNewDay)
		h += kMessageLayoutDayRowHeight;
	if (item.carriesUnreadBand)
		h += kMessageLayoutUnreadRowHeight;
	return h;
}

CGFloat TGGapUnderMedia(CGSize body) {
	return body.height > 0 ? 4 : 0;
}

CGFloat TGMessageLayoutBubbleWidthBudget(TGChatLayoutContext *context) {
	if (!context.wideLayout)
		return kMessageLayoutBubbleMaxW;

	CGFloat width = context.tableWidth;
	if (width <= kBubbleBudgetReferenceWidth)
		return kMessageLayoutBubbleMaxW;

	return floorf(width * (kBubbleBudgetAtReference / kBubbleBudgetReferenceWidth)) - kMessageLayoutBubbleTailOverhang;
}

TGMessageLayoutStampPlate TGMessageLayoutStampPlateMake(NSString *countText,
	NSString *timeText,
	UIFont *font,
	CGFloat tickWidth,
	CGFloat leadPad,
	CGFloat trailPad) {
	TGMessageLayoutStampPlate plate;
	memset(&plate, 0, sizeof(plate));
	plate.leadPad = leadPad;
	plate.trailPad = trailPad;
	plate.showsViews = countText.length > 0;
	plate.showsTicks = tickWidth > 0;
	plate.timeWidth = ceilf([timeText sizeWithFont:font].width) + 1;

	if (plate.showsViews) {
		plate.eyeWidth = kViewsEyeWidth;
		plate.eyeGap = 3.0f;
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

CGFloat TGMessageLayoutStampGutterWidth(NSString *viewCountText,
	NSString *stampText,
	BOOL outgoing) {
	static CGFloat widestTick = 0;
	if (outgoing && widestTick < 1) {
		UIImage *pair = [TGIcons messageChecksRead:YES white:NO];
		widestTick = MAX(16.0f, pair ? pair.size.width : 0);
	}

	TGMessageLayoutStampPlate plate = TGMessageLayoutStampPlateMake(
		viewCountText, stampText, [UIFont systemFontOfSize:11],
		outgoing ? widestTick : 0, outgoing ? 5 : 10, outgoing ? 8 : 6);
	return plate.width + (outgoing ? 12.5f : 12.0f);
}

CGRect TGMessageLayoutAvatarFrame(CGRect bubble, BOOL outgoing) {
	CGFloat x = outgoing
		? (CGRectGetMaxX(bubble) + kMessageLayoutBubbleTailOverhang)
		: (CGRectGetMinX(bubble) - kMessageLayoutAvatarSide - kMessageLayoutBubbleTailOverhang);
	return CGRectMake(x, CGRectGetMaxY(bubble) - kMessageLayoutAvatarSide - 1,
		kMessageLayoutAvatarSide, kMessageLayoutAvatarSide);
}

BOOL TGMessageLayoutRowIsAvatarIndented(TGMessageItem *item, __unused TGChatLayoutContext *context) {
	return item.senderDisplayName.length > 0 ||
		item.forwardAvatarUserId != 0 ||
		item.forwardAvatarChatId != 0;
}

CGFloat TGMessageLayoutMaxBubbleWidth(TGMessageItem *item, TGChatLayoutContext *context) {
	BOOL outgoing = item.message.outgoing;
	CGFloat w = TGMessageLayoutBubbleWidthBudget(context);
	if (outgoing)
		w -= kBubbleOutgoingTrim;
	else if (TGMessageLayoutRowIsAvatarIndented(item, context))
		w -= kBubbleAvatarTrim;

	if (item.forwardOriginIsReachable)
		w -= (kMessageLayoutForwardJumpSide + kMessageLayoutForwardJumpGap);

	CGFloat table = context.tableWidth;
	if (table > 1)
		w = MIN(w, table - TGMessageLayoutStampGutterWidth(item.viewCountText, item.stampText, outgoing));

	return MAX(w, kMessageLayoutBubbleMinW);
}

CGFloat TGMessageLayoutHeadDecorationHeight(TGMessageItem *item) {
	CGFloat h = 0;
	if (item.forwardDisplayName.length)
		h += 18;
	if (item.quoteBodyText.length)
		h += 38;
	return h;
}

CGFloat TGMessageLayoutSignatureBlockHeight(TGMessageItem *item) {
	return item.signatureText.length ? (kSignatureHeight + kSignatureTopGap) : 0;
}

TGMessageLayoutReactionGeometry TGMessageLayoutReactionBlock(TGMessageItem *item,
	CGFloat contentBottom,
	CGFloat boxWidth,
	CGFloat inset,
	BOOL rightAligned,
	BOOL sitsOnWallpaper) {
	TGMessageLayoutReactionGeometry block;
	block.present = NO;
	block.frame = CGRectZero;
	block.height = 0;
	if (item.message.service)
		return block;

	CGSize row = item.reactionRowSize;
	if (row.height < 1) {
		if (!item.reactionChips.count && !item.message.reactionsSummaryText.length)
			return block;
		row = CGSizeMake(MAX(boxWidth - 2 * inset, 40), [TGReactionChipsView rowHeight]);
	}

	CGFloat topPad = sitsOnWallpaper ? kChipsBareTopPad : kChipsBubbleTopPad;
	CGFloat bottomPad = sitsOnWallpaper ? kChipsBareBottomPad : kChipsBubbleBottomPad;

	block.present = YES;
	block.height = topPad + row.height + bottomPad;
	block.frame = CGRectMake(
		rightAligned ? (boxWidth - inset - row.width) : inset,
		contentBottom + topPad, row.width, row.height);
	return block;
}

CGFloat TGMessageLayoutReactionsBlockHeight(TGMessageItem *item, BOOL sitsOnWallpaper) {
	return TGMessageLayoutReactionBlock(item, 0, 0, 0, NO, sitsOnWallpaper).height;
}

TGMessageLayoutReactionGeometry TGMessageLayoutCommentsBlock(TGMessageItem *item,
	CGFloat contentBottom,
	CGFloat boxWidth,
	CGFloat inset) {
	TGMessageLayoutReactionGeometry block;
	block.present = NO;
	block.frame = CGRectZero;
	block.height = 0;
	if (!item.message.channelPost || !item.hasCommentThread)
		return block;

	block.present = YES;
	block.height = kCommentsTopPad + kCommentsRowHeight + kCommentsBottomPad;
	block.frame = CGRectMake(inset, contentBottom + kCommentsTopPad,
		MAX(boxWidth - 2 * inset, 40), kCommentsRowHeight);
	return block;
}

CGFloat TGMessageLayoutCommentsBlockHeight(TGMessageItem *item) {
	return TGMessageLayoutCommentsBlock(item, 0, 0, 0).height;
}

CGFloat TGMessageLayoutBubbleBottomPad(TGMessageItem *item,
	BOOL sitsOnWallpaper,
	CGFloat otherwise) {
	CGFloat footer = TGMessageLayoutReactionsBlockHeight(item, sitsOnWallpaper) +
		TGMessageLayoutCommentsBlockHeight(item);
	return footer > 0 ? 0 : otherwise;
}

CGFloat TGMessageLayoutBareBoxTailHeight(TGMessageItem *item, BOOL sitsOnWallpaper) {
	CGFloat block = TGMessageLayoutReactionsBlockHeight(item, sitsOnWallpaper);
	return block > 0 ? block : kBareStampBand;
}

CGFloat TGMessageLayoutBareStampBoxHeight(TGMessageItem *item,
	CGFloat artSide,
	BOOL sitsOnWallpaper) {
	return artSide + (TGMessageLayoutReactionsBlockHeight(item, sitsOnWallpaper) > 0 ? 0 : kBareStampBand);
}

CGSize TGMessageLayoutLinkPreviewSize(TGMessageItem *item, TGChatLayoutContext *context) {
	NSDictionary *preview = item.linkPreview;
	if (!preview || ![preview[@"url"] length])
		return CGSizeZero;

	CGFloat maxWidth = TGMessageLayoutMaxBubbleWidth(item, context) - 2 * kMessageLayoutPadH;
	CGSize imageSize = item.linkPreviewImageSize;
	BOOL hasImage = imageSize.width >= 1 && imageSize.height >= 1;

	CGFloat columnX = kPreviewBar + kPreviewGap;
	CGFloat columnW = maxWidth - columnX;
	BOOL large = hasImage && [preview[@"hasLargeMedia"] boolValue] &&
		[preview[@"showLargeMedia"] boolValue];
	BOOL smallThumb = hasImage && !large;
	CGFloat textW = smallThumb ? columnW - kPreviewThumb - 6 : columnW;
	if (textW < 40)
		textW = columnW;

	CGFloat textH = 0;
	if ([preview[@"siteName"] length])
		textH += 17;
	NSString *title = preview[@"title"];
	if ([title length]) {
		CGSize s = [title sizeWithFont:[UIFont boldSystemFontOfSize:14]
					 constrainedToSize:CGSizeMake(textW, 32)
						 lineBreakMode:NSLineBreakByWordWrapping];
		textH += MIN(s.height, 32);
	}
	NSString *body = preview[@"description"];
	if ([body length]) {
		CGSize s = [body sizeWithFont:[UIFont systemFontOfSize:14]
					constrainedToSize:CGSizeMake(textW, 32)
						lineBreakMode:NSLineBreakByWordWrapping];
		textH += MIN(s.height, 32);
	}

	CGFloat height = textH;
	if (smallThumb)
		height = MAX(height, kPreviewThumb);
	if (large) {
		CGFloat largeHeight = imageSize.width >= 1
			? MIN(imageSize.height * (columnW / imageSize.width), kPreviewLargeMax)
			: 0;
		height += largeHeight + 5;
	}
	if (height < 1)
		return CGSizeZero;
	if ([preview[@"hasInstantView"] boolValue])
		height += 8 + kInstantHeight;

	CGFloat width = (large || smallThumb) ? maxWidth : columnX + textW;
	return CGSizeMake(width, ceilf(height));
}

CGFloat TGMessageLayoutFootDecorationHeight(TGMessageItem *item,
	TGChatLayoutContext *context,
	BOOL sitsOnWallpaper) {
	CGFloat h = 0;
	CGFloat previewH = TGMessageLayoutLinkPreviewSize(item, context).height;
	if (previewH > 0)
		h += previewH + 6;
	h += TGMessageLayoutSignatureBlockHeight(item);
	h += TGMessageLayoutReactionsBlockHeight(item, sitsOnWallpaper);
	h += TGMessageLayoutCommentsBlockHeight(item);
	return h;
}

CGFloat TGMessageLayoutDecorationHeight(TGMessageItem *item,
	TGChatLayoutContext *context,
	BOOL sitsOnWallpaper) {
	return TGMessageLayoutHeadDecorationHeight(item) +
		TGMessageLayoutFootDecorationHeight(item, context, sitsOnWallpaper);
}

UIFont *TGMessageLayoutBodyFont(TGMessageItem *item, TGChatLayoutContext *context) {
	(void)item;
	return [UIFont systemFontOfSize:context.baseFontSize];
}

CGFloat TGMessageLayoutCaptionWidthCap(TGMessageItem *item) {
	if (item.mosaicSize.height > 0)
		return item.mosaicSize.width >= kMessageLayoutCaptionMinWrapWidth
			? item.mosaicSize.width
			: 0;
	TGMessageContentKind kind = item.message.kind;
	BOOL captioned = kind == TGMessageContentKindPhoto || kind == TGMessageContentKindVideo ||
		kind == TGMessageContentKindAnimation;
	if (captioned && item.pictureSize.width >= kMessageLayoutCaptionMinWrapWidth)
		return item.pictureSize.width;
	return 0;
}

CGSize TGMessageLayoutBodySize(TGMessageItem *item, TGChatLayoutContext *context) {
	NSString *text = item.bodyText ?: @"";
	if (!text.length)
		return CGSizeZero;
	if (item.bodyRichLayout)
		return item.bodyRichLayout.size;
	CGFloat maxW = TGMessageLayoutMaxBubbleWidth(item, context) - 2 * kMessageLayoutPadH;
	CGFloat cap = TGMessageLayoutCaptionWidthCap(item);
	if (cap > 0)
		maxW = MIN(maxW, cap);
	return TGEmojiTextSize(text, TGMessageLayoutBodyFont(item, context),
		CGSizeMake(maxW, 10000), NSLineBreakByWordWrapping, 0);
}

CGFloat TGMessageLayoutSignatureWidth(TGMessageItem *item) {
	NSString *line = item.signatureText;
	if (!line.length)
		return 0;
	return ceilf([line sizeWithFont:[UIFont systemFontOfSize:11]].width);
}

CGSize TGMessageLayoutTranscriptSize(TGMessageItem *item, TGChatLayoutContext *context) {
	NSString *text = item.transcriptText;
	if (!text.length)
		return CGSizeZero;
	CGFloat maxW = floorf(TGMessageLayoutMaxBubbleWidth(item, context) - 2 * kMessageLayoutPadH);
	if (maxW < 40)
		return CGSizeZero;
	CGSize measured = [text sizeWithFont:[UIFont systemFontOfSize:14]
					   constrainedToSize:CGSizeMake(maxW, 10000)
						   lineBreakMode:NSLineBreakByWordWrapping];
	return CGSizeMake(ceilf(measured.width), ceilf(measured.height) + 8);
}

CGFloat TGMessageLayoutForwardLineWidth(TGMessageItem *item) {
	NSString *name = item.forwardDisplayName;
	if (!name.length)
		return 0;
	CGFloat prefix = [item.forwardLinePrefix sizeWithFont:[UIFont systemFontOfSize:13]].width;
	CGFloat named = [name sizeWithFont:[UIFont boldSystemFontOfSize:13]].width;
	return ceilf(prefix + named) + kMessageLayoutForwardLineSlack;
}

CGFloat TGMessageLayoutGenericBubbleWidth(TGMessageItem *item,
	TGChatLayoutContext *context,
	CGSize body,
	CGSize picture,
	BOOL isVoice) {
	CGFloat contentW = MAX(body.width, picture.width);
	BOOL hasThumb = item.quoteThumbnailSize.width > 0 && item.quoteThumbnailSize.height > 0;
	if (item.quoteBodyText.length > 0)
		contentW = MAX(contentW, hasThumb ? 200 : 170);
	if (item.forwardDisplayName.length > 0)
		contentW = MAX(contentW, TGMessageLayoutForwardLineWidth(item));
	if (item.reactionChips.count)
		contentW = MAX(contentW, item.reactionRowSize.width);
	CGSize previewSize = TGMessageLayoutLinkPreviewSize(item, context);
	if (previewSize.height > 0)
		contentW = MAX(contentW, previewSize.width);
	contentW = MAX(contentW, TGMessageLayoutSignatureWidth(item));

	if (isVoice) {
		CGSize transcript = TGMessageLayoutTranscriptSize(item, context);
		contentW = MAX(MAX(190, transcript.width),
			item.reactionChips.count ? item.reactionRowSize.width : 0);
	}

	if (item.senderDisplayName.length) {
		CGFloat nameW = ceilf([item.senderDisplayName
							sizeWithFont:[UIFont boldSystemFontOfSize:13]]
								.width) +
			4;
		contentW = MAX(contentW, nameW);
	}

	CGFloat maxBubbleW = TGMessageLayoutMaxBubbleWidth(item, context);
	CGFloat bubbleW = MAX(contentW + 2 * kMessageLayoutPadH,
		kMessageLayoutBubbleMinW - kMessageLayoutBubbleTailOverhang);
	return MIN(bubbleW, maxBubbleW);
}

static const CGFloat kRetinaPixel = kMessageLayoutRetinaPixel;
static const CGFloat kStampLineHeight = 14.0f;
static const CGFloat kViewsEyeHeight = 8.0f;
static const CGFloat kForwardJumpSlop = 4.0f;

static CGRect TGMessageLayoutForwardJumpFrame(CGRect anchor, BOOL outgoing) {
	CGFloat plateX = outgoing
		? (CGRectGetMinX(anchor) - kMessageLayoutForwardJumpGap - kMessageLayoutForwardJumpSide)
		: (CGRectGetMaxX(anchor) + kMessageLayoutForwardJumpGap);
	CGFloat plateY = CGRectGetMidY(anchor) - kMessageLayoutForwardJumpSide / 2;
	return CGRectInset(CGRectMake(plateX, plateY,
						   kMessageLayoutForwardJumpSide, kMessageLayoutForwardJumpSide),
		-kForwardJumpSlop, -kForwardJumpSlop);
}

TGMessageLayoutStampGeometry TGMessageLayoutPlaceStampBesideBox(TGMessageItem *item,
	TGChatLayoutContext *context,
	CGRect box,
	BOOL outgoing) {
	TGMessageLayoutStampGeometry geo;
	memset(&geo, 0, sizeof(geo));

	NSString *stampText = item.stampText;
	if (!stampText.length) {
		CGRect stampless = CGRectMake(
			outgoing ? CGRectGetMinX(box) : CGRectGetMaxX(box),
			CGRectGetMaxY(box) - 25 - kRetinaPixel, 0, 21);
		if (item.forwardOriginIsReachable) {
			geo.showsForwardJump = YES;
			geo.forwardJump = TGMessageLayoutForwardJumpFrame(stampless, outgoing);
		}
		return geo;
	}

	BOOL showsTicks = outgoing;
	CGSize tickSize = showsTicks ? [TGIcons messageChecksRead:YES white:NO].size : CGSizeZero;
	TGMessageLayoutStampPlate plate = TGMessageLayoutStampPlateMake(
		item.viewCountText, stampText, [UIFont systemFontOfSize:11],
		showsTicks ? tickSize.width : 0, outgoing ? 5 : 10, outgoing ? 8 : 6);

	CGFloat dateY = CGRectGetMaxY(box) - 22;
	CGRect badge = CGRectMake(
		outgoing ? (CGRectGetMinX(box) - 2 - kRetinaPixel - plate.width)
				 : (CGRectGetMaxX(box) + 2),
		dateY - 3 - kRetinaPixel, plate.width, 21);

	CGFloat run = item.forwardOriginIsReachable
		? (kMessageLayoutForwardJumpSide + kMessageLayoutForwardJumpGap)
		: 0;
	CGFloat runLeft = badge.origin.x - (outgoing ? run : 0);
	CGFloat runRight = CGRectGetMaxX(badge) + (outgoing ? 0 : run);
	CGFloat over = runRight - (context.tableWidth - 2);
	if (over > 0) {
		badge.origin.x -= over;
		runLeft -= over;
	}
	if (runLeft < 2)
		badge.origin.x += 2 - runLeft;

	geo.showsStamp = YES;
	geo.platePlate = badge;
	geo.plateTime = CGRectMake(badge.origin.x + plate.timeOffset, dateY,
		plate.timeWidth, kStampLineHeight);
	geo.showsViews = plate.showsViews;
	if (plate.showsViews) {
		geo.plateEye = CGRectMake(badge.origin.x + plate.eyeOffset,
			dateY + floorf((kStampLineHeight - kViewsEyeHeight) / 2),
			plate.eyeWidth, kViewsEyeHeight);
		geo.plateViews = CGRectMake(badge.origin.x + plate.countOffset, dateY,
			plate.countWidth, kStampLineHeight);
	}
	geo.showsTicks = plate.showsTicks;
	if (plate.showsTicks) {
		geo.plateTicks = CGRectMake(badge.origin.x + plate.tickOffset,
			CGRectGetMidY(badge) - tickSize.height / 2,
			tickSize.width, tickSize.height);
	}

	if (item.forwardOriginIsReachable) {
		geo.showsForwardJump = YES;
		geo.forwardJump = TGMessageLayoutForwardJumpFrame(badge, outgoing);
	}
	return geo;
}

static const CGFloat kMessageLayoutBubbleTailCap = 12.0f;

UIImage *TGMessageLayoutBubbleArtwork(BOOL tall, BOOL outgoing) {
	NSString *name = outgoing ? @"Msg_Out" : @"Msg_In";
	if (tall)
		name = [name stringByAppendingString:@"_High"];
	UIImage *art = [UIImage imageNamed:name];
	if (!art)
		return nil;
	if (tall) {
		CGFloat rightCap = art.size.width - (outgoing ? 17 : 23) - 1;
		CGFloat topCap = art.size.height - kMessageLayoutBubbleTailCap - 1;
		return [art resizableImageWithCapInsets:
				UIEdgeInsetsMake(MAX(topCap, 0), outgoing ? 17 : 23,
					kMessageLayoutBubbleTailCap, MAX(rightCap, 0))];
	}
	return [art stretchableImageWithLeftCapWidth:(outgoing ? 15 : 20) topCapHeight:9];
}

BOOL TGMessageLayoutBubbleArtworkExists(BOOL tall, BOOL outgoing) {
	NSString *name = outgoing ? @"Msg_Out" : @"Msg_In";
	if (tall)
		name = [name stringByAppendingString:@"_High"];
	return [UIImage imageNamed:name] != nil;
}

@implementation TGMessageLayoutBuilder

+ (TGMessageLayout *)layoutForItem:(TGMessageItem *)item
						   context:(TGChatLayoutContext *)context {
	NSString *reuse = item.reuseIdentifier;
	TGMessageLayoutComputed computed = TGMessageLayoutComputedZero();
	BOOL known = YES;

	if ([reuse isEqualToString:@"TGBubbleCell.Service"])
		computed = TGMessageLayoutBuildService(item, context);
	else if ([reuse isEqualToString:@"TGBubbleCell.Text"])
		computed = TGMessageLayoutBuildText(item, context);
	else if ([reuse isEqualToString:@"TGBubbleCell.Photo"])
		computed = TGMessageLayoutBuildPhoto(item, context);
	else if ([reuse isEqualToString:@"TGBubbleCell.File"])
		computed = TGMessageLayoutBuildFile(item, context);
	else if ([reuse isEqualToString:@"TGBubbleCell.Voice"])
		computed = TGMessageLayoutBuildVoice(item, context);
	else if ([reuse isEqualToString:@"TGBubbleCell.Sticker"])
		computed = TGMessageLayoutBuildSticker(item, context);
	else if ([reuse isEqualToString:@"TGBubbleCell.AnimatedSticker"])
		computed = TGMessageLayoutBuildAnimatedSticker(item, context);
	else if ([reuse isEqualToString:@"TGBubbleCell.BareEmoji"])
		computed = TGMessageLayoutBuildBareEmoji(item, context);
	else if ([reuse isEqualToString:@"TGBubbleCell.VideoNote"])
		computed = TGMessageLayoutBuildVideoNote(item, context);
	else if ([reuse isEqualToString:@"TGBubbleCell.Album"])
		computed = TGMessageLayoutBuildAlbum(item, context);
	else if ([reuse isEqualToString:@"TGBubbleCell.Poll"])
		computed = TGMessageLayoutBuildPoll(item, context);
	else if ([reuse isEqualToString:@"TGBubbleCell.Checklist"])
		computed = TGMessageLayoutBuildChecklist(item, context);
	else if ([reuse isEqualToString:@"TGBubbleCell.Call"])
		computed = TGMessageLayoutBuildCall(item, context);
	else if ([reuse isEqualToString:@"TGBubbleCell.RichMessage"])
		computed = TGMessageLayoutBuildRichMessage(item, context);
	else if ([reuse isEqualToString:@"TGBubbleCell.Location"])
		computed = TGMessageLayoutBuildLocation(item, context);
	else
		known = NO;

	NSAssert(known, @"TGMessageLayoutBuilder has no kind builder for reuse identifier %@", reuse);

	CGFloat headerHeight = TGMessageLayoutHeaderHeight(item);
	if (item.opensNewDay)
		computed.parts |= TGMessageLayoutPartDayPlate;
	if (item.carriesUnreadBand)
		computed.parts |= TGMessageLayoutPartUnreadBand;
	if (context.selecting && !item.message.service)
		computed.row.selectionCheck = CGRectMake(2, (computed.messageHeight - 26) / 2, 26, 26);

	TGMessageLayout *layout = [TGMessageLayout alloc];
	layout = [layout initWithHeaderHeight:headerHeight
							messageHeight:computed.messageHeight
									parts:computed.parts
									  row:computed.row
								   bubble:computed.bubble
					   bubbleCornerRadius:computed.bubbleCornerRadius
						bubbleBorderWidth:computed.bubbleBorderWidth
							   isOutgoing:item.message.outgoing
						  sitsOnWallpaper:computed.sitsOnWallpaper
							 repeatedRows:computed.repeatedRows
									count:computed.repeatedRowCount];
	return layout;
}

@end

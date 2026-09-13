#import "TGInstantViewItemBuilder.h"
#import "TGInstantViewController.h"
#import "TGInstantViewCellCatalogue.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGRichText.h"
#import "TGHexColour.h"

static const CGFloat kPreviewBar = 2.0f;

@implementation TGInstantViewItemBuilder

+ (TGInstantViewRowKind)rowKindForBlock:(NSDictionary *)block {
	NSString *kind = block[@"kind"] ?: @"unsupported";
	if ([kind isEqualToString:@"divider"])
		return TGInstantViewRowKindDivider;
	if ([kind isEqualToString:@"photo"] || [kind isEqualToString:@"cover"] ||
		[kind isEqualToString:@"animation"] || [kind isEqualToString:@"video"])
		return TGInstantViewRowKindMedia;
	if (![TGInstantViewController kindIsText:kind])
		return TGInstantViewRowKindUnsupported;
	return TGInstantViewRowKindText;
}

+ (TGInstantViewItem *)itemFromBlock:(NSDictionary *)block height:(CGFloat)height width:(CGFloat)width {
	TGInstantViewRowKind kind = [self rowKindForBlock:block];
	NSString *reuseIdentifier = [TGInstantViewCellCatalogue reuseIdentifierForKind:kind];
	Class cellClass = [TGInstantViewCellCatalogue cellClassForKind:kind];

	BOOL barHidden = YES;
	CGRect barFrame = CGRectZero;
	UIColor *barColour = nil;
	long long photoFileId = 0;
	CGRect pictureFrame = CGRectZero;
	UIColor *pictureEmptyColour = TGColourFromHex(0xEEF1F4);
	BOOL captionHidden = YES;
	NSString *captionText = nil;
	CGRect captionFrame = CGRectZero;
	BOOL bodyHidden = YES;
	NSString *bodyText = nil;
	UIFont *bodyFont = nil;
	UIColor *bodyTextColour = nil;
	UIColor *bodyBackgroundColour = nil;
	CGRect bodyFrame = CGRectZero;
	TGRichTextLayout *bodyRichLayout = nil;
	UIColor *cellBackgroundColour = [UIColor whiteColor];

	if (kind == TGInstantViewRowKindDivider) {
		barHidden = NO;
		barColour = [[TGTheme shared] separatorColour];
		barFrame = CGRectMake(15, 8, width - 30, 1);
	} else if (kind == TGInstantViewRowKindMedia) {
		NSNumber *fileId = block[@"photoFileId"];
		photoFileId = [fileId isKindOfClass:NSNumber.class] ? fileId.longLongValue : 0;
		NSString *text = block[@"captionText"];
		CGFloat captionH = 0;
		if (text.length) {
			CGSize s = [text sizeWithFont:[UIFont systemFontOfSize:13]
						constrainedToSize:CGSizeMake(width - 30, 200)
							lineBreakMode:NSLineBreakByWordWrapping];
			captionH = s.height + 6;
		}
		CGFloat pictureH = MAX(0, height - captionH - 11);
		pictureFrame = CGRectMake(0, 5, width, pictureH);
		if (text.length) {
			captionHidden = NO;
			captionText = text;
			captionFrame = CGRectMake(15, 5 + pictureH + 6, width - 30, captionH - 6);
		}
	} else if (kind == TGInstantViewRowKindUnsupported) {
		bodyHidden = NO;
		bodyFont = [UIFont systemFontOfSize:15];
		bodyTextColour = TGColourFromHex(0x141617);
		NSString *title = block[@"text"];
		bodyText = title.length
			? [NSString stringWithFormat:TGL(@"Chat.TapToOpenInSafari", @"%@\nTap to open in Safari"), title]
			: TGL(@"Chat.TapToOpenInSafariGeneric", @"Tap to open in Safari");
		bodyFrame = CGRectMake(15, 8, width - 30, 50);
		cellBackgroundColour = TGColourFromHex(0xEEF1F4);
	} else {
		NSString *rawKind = block[@"kind"] ?: @"unsupported";
		NSString *text = [TGInstantViewController textOfBlock:block];
		CGFloat inset = 15;
		if ([rawKind isEqualToString:@"blockQuote"] || [rawKind isEqualToString:@"pullQuote"]) {
			inset += 10;
			barHidden = NO;
			barColour = TGColourFromHex(0x0E7ACD);
			barFrame = CGRectMake(15, 4, kPreviewBar, MAX(0, height - 11));
		}
		if ([rawKind isEqualToString:@"list"])
			inset += 20;

		CGFloat top = [rawKind isEqualToString:@"sectionHeading"] ? 12 : 4;
		bodyHidden = NO;
		bodyFont = [TGInstantViewController fontForKind:rawKind];
		bodyTextColour = [TGInstantViewController colourForKind:rawKind];
		bodyText = [rawKind isEqualToString:@"kicker"] ? text.uppercaseString : text;
		bodyBackgroundColour = [rawKind isEqualToString:@"preformatted"]
			? TGColourFromHex(0xEEF1F4)
			: [UIColor clearColor];
		bodyFrame = CGRectMake(inset, top, [TGInstantViewController textWidthForKind:rawKind width:width],
			MAX(0, height - 11 - (top - 4)));

		NSArray *entities = [TGInstantViewController styledEntitiesForBlock:block kind:rawKind];
		if (entities.count) {
			TGRichTextPalette *palette = [TGRichTextPalette paletteWithFont:bodyFont
																	  colour:bodyTextColour
																  linkColour:TGColourFromHex(0x0E7ACD)
																accentColour:TGColourFromHex(0x0E7ACD)];
			NSAttributedString *styled = TGRichTextBuild(text, entities, palette, YES);
			bodyRichLayout = [TGRichTextLayout layoutWithText:styled
														  width:bodyFrame.size.width
													   maxLines:0
													  alignment:NSTextAlignmentLeft
												 expandedBlocks:nil];
		}
	}

	return [[TGInstantViewItem alloc] initWithKind:kind
								   reuseIdentifier:reuseIdentifier
										 cellClass:cellClass
											height:height
										 barHidden:barHidden
										  barFrame:barFrame
										 barColour:barColour
									   photoFileId:photoFileId
									  pictureFrame:pictureFrame
								pictureEmptyColour:pictureEmptyColour
									 captionHidden:captionHidden
									   captionText:captionText
									  captionFrame:captionFrame
										bodyHidden:bodyHidden
										  bodyText:bodyText
										  bodyFont:bodyFont
									bodyTextColour:bodyTextColour
							  bodyBackgroundColour:bodyBackgroundColour
										 bodyFrame:bodyFrame
										bodyRichLayout:bodyRichLayout
							  cellBackgroundColour:cellBackgroundColour];
}

@end

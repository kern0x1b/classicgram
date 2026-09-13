#import "TGClient+Contacts.h"
#import "TGClient+ChatState.h"
#import "TGInstantViewRemeasure.h"
#import "TGInstantViewController.h"
#import "TGClient+Files.h"
#import "TGLocalization.h"
#import "TGClient+WebLinks.h"
#import "TGTheme.h"
#import "TGWebViewController.h"
#import "TGImageDecode.h"
#import <ImageIO/ImageIO.h>
#import "TGInstantViewPresenter.h"
#import "TGInstantViewRowBridge.h"
#import "TGInstantViewCellBase.h"
#import "TGInstantViewItem.h"
#import "TGWebViewController.h"
#import "TGEmoji.h"
#import "TGRichText.h"
#import "TGProfileViewController.h"
#import "TGHexColour.h"

static const CGFloat kPreviewBar = 2.0f;
static NSString *const kTGIVAnchorLinkScheme = @"tg-instant-view-anchor:";

@interface TGInstantViewTextCell : UITableViewCell
@property (nonatomic, assign) CGPoint lastTouchInCell;
@property (nonatomic, assign) BOOL lastTouchKnown;
@end

@implementation TGInstantViewTextCell

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	UITouch *touch = [touches anyObject];
	if (touch) {
		self.lastTouchInCell = [touch locationInView:self.contentView];
		self.lastTouchKnown = YES;
	}
	[super touchesBegan:touches withEvent:event];
}

- (void)prepareForReuse {
	[super prepareForReuse];
	self.lastTouchKnown = NO;
}

@end

static NSArray *TGIVEntitiesFromRuns(NSArray *runs) {
	NSMutableArray *entities = [NSMutableArray array];
	for (id raw in runs) {
		if (![raw isKindOfClass:NSDictionary.class])
			continue;
		NSDictionary *run = raw;
		NSNumber *offset = [run[@"offset"] isKindOfClass:NSNumber.class] ? run[@"offset"] : nil;
		NSNumber *length = [run[@"length"] isKindOfClass:NSNumber.class] ? run[@"length"] : nil;
		if (!offset || !length)
			continue;
		NSString *kind = [run[@"kind"] isKindOfClass:NSString.class] ? run[@"kind"] : @"";
		NSMutableDictionary *entity = [NSMutableDictionary dictionary];
		entity[@"offset"] = offset;
		entity[@"length"] = length;

		if ([kind isEqualToString:@"bold"]) {
			entity[@"kind"] = @"bold";
		} else if ([kind isEqualToString:@"italic"]) {
			entity[@"kind"] = @"italic";
		} else if ([kind isEqualToString:@"underline"]) {
			entity[@"kind"] = @"underline";
		} else if ([kind isEqualToString:@"strikethrough"]) {
			entity[@"kind"] = @"strikethrough";
		} else if ([kind isEqualToString:@"spoiler"]) {
			entity[@"kind"] = @"spoiler";
		} else if ([kind isEqualToString:@"fixed"]) {
			entity[@"kind"] = @"code";
		} else if ([kind isEqualToString:@"url"] || [kind isEqualToString:@"referenceLink"]) {
			NSString *url = [run[@"url"] isKindOfClass:NSString.class] ? run[@"url"] : nil;
			if (!url.length)
				continue;
			entity[@"kind"] = @"texturl";
			entity[@"url"] = url;
		} else if ([kind isEqualToString:@"anchorLink"]) {
			NSString *anchor = [run[@"anchor"] isKindOfClass:NSString.class] ? run[@"anchor"] : @"";
			NSString *url = [run[@"url"] isKindOfClass:NSString.class] ? run[@"url"] : nil;
			if (anchor.length) {
				entity[@"kind"] = @"texturl";
				entity[@"url"] = [kTGIVAnchorLinkScheme stringByAppendingString:anchor];
			} else if (url.length) {
				entity[@"kind"] = @"texturl";
				entity[@"url"] = url;
			} else {
				continue;
			}
		} else if ([kind isEqualToString:@"emailAddress"]) {
			entity[@"kind"] = @"emailaddress";
		} else if ([kind isEqualToString:@"phoneNumber"]) {
			entity[@"kind"] = @"phonenumber";
		} else if ([kind isEqualToString:@"mention"]) {
			entity[@"kind"] = @"mention";
		} else if ([kind isEqualToString:@"mentionName"]) {
			NSNumber *userId = [run[@"userId"] isKindOfClass:NSNumber.class] ? run[@"userId"] : nil;
			if (!userId)
				continue;
			entity[@"kind"] = @"mentionname";
			entity[@"userId"] = userId;
		} else if ([kind isEqualToString:@"hashtag"]) {
			entity[@"kind"] = @"hashtag";
		} else if ([kind isEqualToString:@"cashtag"]) {
			entity[@"kind"] = @"cashtag";
		} else if ([kind isEqualToString:@"bankCardNumber"]) {
			entity[@"kind"] = @"bankcardnumber";
		} else if ([kind isEqualToString:@"botCommand"]) {
			entity[@"kind"] = @"botcommand";
		} else {
			continue;
		}
		[entities addObject:entity];
	}
	return entities;
}

static NSArray *TGIVStyledEntitiesForBlock(NSDictionary *block, NSString *kind) {
	NSArray *runs = [block[@"runs"] isKindOfClass:NSArray.class] ? block[@"runs"] : nil;
	if ([kind isEqualToString:@"kicker"] || !runs.count)
		return nil;
	return TGIVEntitiesFromRuns(runs);
}

@interface TGInstantViewController () <TGInstantViewRowBridgeDelegate>
@end

@implementation TGInstantViewController {
	UITableView *_table;
	NSArray *_blocks;
	NSMutableArray *_heights;
	NSMutableDictionary *_images;
	NSMutableSet *_imagesRequested;
	UILabel *_placeholder;
	TGInstantViewPresenter *_presenter;
	TGInstantViewRowBridge *_rowBridge;
	CGFloat _measuredWidth;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.view.backgroundColor = [UIColor whiteColor];
	_images = [NSMutableDictionary dictionary];
	_imagesRequested = [NSMutableSet set];
	_blocks = @[];
	_heights = [NSMutableArray array];
	_presenter = [[TGInstantViewPresenter alloc] init];
	_rowBridge = [[TGInstantViewRowBridge alloc] initWithPresenter:_presenter];
	_rowBridge.delegate = self;

	NSString *host = [[NSURL URLWithString:(self.url ?: @"")] host] ?: TGL(@"InstantPage.Title", @"Instant View");
	self.title = self.readerTitle.length ? self.readerTitle : host;

	_table = [[UITableView alloc] initWithFrame:self.view.bounds
										  style:UITableViewStylePlain];
	_table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_table.separatorStyle = UITableViewCellSeparatorStyleNone;
	_table.backgroundColor = [UIColor whiteColor];
	_table.dataSource = self;
	_table.delegate = self;
	[self.view addSubview:_table];

	_placeholder = [[UILabel alloc] initWithFrame:CGRectMake(0, 120, self.view.bounds.size.width, 20)];
	_placeholder.textAlignment = NSTextAlignmentCenter;
	_placeholder.backgroundColor = [UIColor clearColor];
	_placeholder.textColor = TGColourFromHex(0x999999);
	_placeholder.text = TGL(@"Channel.NotificationLoading", @"Loading…");
	[self.view addSubview:_placeholder];

	if (self.presetBlocks) {
		[self adoptBlocks:self.presetBlocks];
		return;
	}

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] instantViewForUrl:self.url completion:^(NSDictionary *view) {
		TGInstantViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSArray *blocks = view[@"blocks"];
		if (!blocks.count) {
			NSString *fallback = strongSelf.fallbackUrl.length ? strongSelf.fallbackUrl : strongSelf.url;
			[strongSelf.navigationController popViewControllerAnimated:NO];
			[TGWebViewController openURLString:fallback fromViewController:strongSelf.navigationController.topViewController];
			return;
		}
		[strongSelf adoptBlocks:blocks];
	}];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	if (TGInstantViewNeedsRemeasure(self.view.bounds.size.width, _measuredWidth, _blocks.count))
		[self adoptBlocks:_blocks];
}

- (void)adoptBlocks:(NSArray *)blocks {
	CGFloat width = self.view.bounds.size.width;
	if (width < 1)
		return;
	_measuredWidth = width;
	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSMutableArray *heights = [NSMutableArray array];
		for (NSDictionary *block in blocks)
			[heights addObject:@([TGInstantViewController heightForBlock:block width:width])];
		dispatch_async(dispatch_get_main_queue(), ^{
			TGInstantViewController *strongSelf = weakSelf;
			if (!strongSelf || fabs(strongSelf->_measuredWidth - width) > 0.5f)
				return;
			strongSelf->_blocks = blocks;
			strongSelf->_heights = heights;
			[strongSelf->_presenter updateWithBlocks:blocks width:width];
			strongSelf->_placeholder.hidden = YES;
			[strongSelf->_table reloadData];
		});
	});
}

+ (UIFont *)fontForKind:(NSString *)kind {
	if ([kind isEqualToString:@"title"])
		return [UIFont boldSystemFontOfSize:19];
	if ([kind isEqualToString:@"subtitle"])
		return [UIFont systemFontOfSize:15];
	if ([kind isEqualToString:@"authorDate"])
		return [UIFont systemFontOfSize:13];
	if ([kind isEqualToString:@"kicker"])
		return [UIFont boldSystemFontOfSize:12];
	if ([kind isEqualToString:@"header"])
		return [UIFont boldSystemFontOfSize:17];
	if ([kind isEqualToString:@"sectionHeading"])
		return [UIFont boldSystemFontOfSize:17];
	if ([kind isEqualToString:@"subheader"])
		return [UIFont boldSystemFontOfSize:15];
	if ([kind isEqualToString:@"preformatted"])
		return [UIFont fontWithName:@"Courier" size:13];
	if ([kind isEqualToString:@"blockQuote"] || [kind isEqualToString:@"pullQuote"])
		return [UIFont italicSystemFontOfSize:15];
	if ([kind isEqualToString:@"footer"])
		return [UIFont systemFontOfSize:13];
	return [UIFont systemFontOfSize:15];
}

+ (UIColor *)colourForKind:(NSString *)kind {
	if ([kind isEqualToString:@"kicker"])
		return TGColourFromHex(0x0E7ACD);
	if ([kind isEqualToString:@"subtitle"])
		return TGColourFromHex(0x62768A);
	if ([kind isEqualToString:@"authorDate"])
		return TGColourFromHex(0x999999);
	if ([kind isEqualToString:@"footer"])
		return TGColourFromHex(0x697487);
	return TGColourFromHex(0x141617);
}

+ (BOOL)kindIsText:(NSString *)kind {
	static NSSet *known = nil;
	if (!known)
		known = [NSSet setWithObjects:@"title", @"subtitle", @"authorDate", @"kicker",
			@"header", @"subheader", @"sectionHeading", @"paragraph", @"preformatted",
			@"footer", @"blockQuote", @"pullQuote", @"list", nil];
	return [known containsObject:(kind ?: @"")];
}

+ (NSString *)textOfBlock:(NSDictionary *)block {
	NSString *kind = block[@"kind"];
	if ([kind isEqualToString:@"list"]) {
		NSMutableString *lines = [NSMutableString string];
		for (NSDictionary *item in block[@"items"]) {
			NSString *label = item[@"label"] ?: @"•";
			NSMutableString *body = [NSMutableString string];
			for (NSDictionary *nested in item[@"blocks"]) {
				NSString *text = nested[@"text"];
				if (text.length)
					[body appendFormat:@"%@ ", text];
			}
			[lines appendFormat:@"%@  %@\n", label, [body stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
		}
		return [lines stringByTrimmingCharactersInSet:
				[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	}
	if ([kind isEqualToString:@"blockQuote"] || [kind isEqualToString:@"pullQuote"]) {
		NSString *own = block[@"text"];
		if (own.length)
			return own;
		NSMutableString *body = [NSMutableString string];
		for (NSDictionary *nested in block[@"blocks"]) {
			NSString *text = nested[@"text"];
			if (text.length)
				[body appendFormat:@"%@\n", text];
		}
		return [body stringByTrimmingCharactersInSet:
				[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	}
	return block[@"text"] ?: @"";
}

+ (CGFloat)textWidthForKind:(NSString *)kind width:(CGFloat)width {
	CGFloat inset = 15;
	if ([kind isEqualToString:@"blockQuote"] || [kind isEqualToString:@"pullQuote"])
		inset += 10;
	if ([kind isEqualToString:@"list"])
		inset += 20;
	return width - inset - 15;
}

+ (NSArray *)styledEntitiesForBlock:(NSDictionary *)block kind:(NSString *)kind {
	return TGIVStyledEntitiesForBlock(block, kind);
}

+ (CGFloat)heightForBlock:(NSDictionary *)block width:(CGFloat)width {
	NSString *kind = block[@"kind"] ?: @"unsupported";

	if ([kind isEqualToString:@"divider"])
		return 17;
	if ([kind isEqualToString:@"anchor"])
		return 0;
	if ([kind isEqualToString:@"photo"] || [kind isEqualToString:@"cover"] ||
		[kind isEqualToString:@"animation"] || [kind isEqualToString:@"video"]) {
		CGFloat w = [block[@"width"] floatValue], h = [block[@"height"] floatValue];
		CGFloat picture = (w > 1 && h > 1) ? MIN(width * (h / w), width) : 180;
		NSString *caption = block[@"captionText"];
		CGFloat captionH = 0;
		if (caption.length) {
			CGSize s = [caption sizeWithFont:[UIFont systemFontOfSize:13]
						   constrainedToSize:CGSizeMake(width - 30, 200)
							   lineBreakMode:NSLineBreakByWordWrapping];
			captionH = s.height + 6;
		}
		return ceilf(picture) + captionH + 11;
	}
	if (![self kindIsText:kind])
		return 66;

	NSString *text = [self textOfBlock:block];
	if (!text.length)
		return 0;
	CGFloat top = [kind isEqualToString:@"sectionHeading"] ? 8 : 0;
	CGFloat textWidth = [self textWidthForKind:kind width:width];
	NSArray *entities = TGIVStyledEntitiesForBlock(block, kind);
	if (entities.count) {
		UIFont *font = [self fontForKind:kind];
		TGRichTextPalette *palette = [TGRichTextPalette paletteWithFont:font
																  colour:[self colourForKind:kind]
															  linkColour:TGColourFromHex(0x0E7ACD)
															accentColour:TGColourFromHex(0x0E7ACD)];
		NSAttributedString *styled = TGRichTextBuild(text, entities, palette, YES);
		TGRichTextLayout *layout = [TGRichTextLayout layoutWithText:styled
																width:textWidth
															 maxLines:0
															alignment:NSTextAlignmentLeft
													   expandedBlocks:nil];
		return ceilf(layout.size.height) + 11 + top;
	}
	CGSize s = [text sizeWithFont:[self fontForKind:kind]
				constrainedToSize:CGSizeMake(textWidth, 20000)
					lineBreakMode:NSLineBreakByWordWrapping];
	return ceilf(s.height) + 11 + top;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return _blocks.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row >= (NSInteger)_heights.count)
		return 0;
	return [_heights[indexPath.row] floatValue];
}

- (void)fetchImageForBlock:(NSDictionary *)block {
	NSNumber *blockFileId = block[@"photoFileId"];
	if (![blockFileId isKindOfClass:NSNumber.class])
		return;
	[self fetchImageForFileId:blockFileId.longLongValue];
}

- (void)fetchImageForFileId:(long long)fileIdValue {
	if (fileIdValue == 0)
		return;
	NSNumber *fileId = @(fileIdValue);
	if (_images[fileId] || [_imagesRequested containsObject:fileId])
		return;
	[_imagesRequested addObject:fileId];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] downloadFile:fileId.longLongValue completion:^(NSString *path) {
		TGInstantViewController *strongSelf = weakSelf;
		if (!strongSelf || !path)
			return;
		dispatch_async(TGImageDecodeQueue(), ^{
			UIImage *image = nil;
			CGImageSourceRef source = CGImageSourceCreateWithURL(
				(__bridge CFURLRef)[NSURL fileURLWithPath:path], NULL);
			if (source) {
				NSDictionary *options = @{
					(id)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
					(id)kCGImageSourceThumbnailMaxPixelSize : @640,
				};
				CGImageRef thumb = CGImageSourceCreateThumbnailAtIndex(source, 0,
					(__bridge CFDictionaryRef)options);
				if (thumb) {
					image = [UIImage imageWithCGImage:thumb];
					CGImageRelease(thumb);
				}
				CFRelease(source);
			}
			if (!image)
				image = [UIImage imageWithContentsOfFile:path];
			if (!image)
				return;
			dispatch_async(dispatch_get_main_queue(), ^{
				TGInstantViewController *innerSelf = weakSelf;
				if (!innerSelf)
					return;
				innerSelf->_images[fileId] = image;
				[innerSelf->_table reloadData];
			});
		});
	}];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([_rowBridge ownsRowAtIndex:indexPath.row])
		return [_rowBridge cellForRow:indexPath.row inTable:tableView];

	static NSString *reuse = @"TGInstantBlock";
	TGInstantViewTextCell *cell = (TGInstantViewTextCell *)[tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell) {
		cell = [[TGInstantViewTextCell alloc] initWithStyle:UITableViewCellStyleDefault
											 reuseIdentifier:reuse];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.backgroundColor = [UIColor whiteColor];

		TGEmojiLabel *body = [[TGEmojiLabel alloc] init];
		body.tag = 0x8001;
		body.numberOfLines = 0;
		body.backgroundColor = [UIColor clearColor];
		[cell.contentView addSubview:body];

		UIView *bar = [[UIView alloc] init];
		bar.tag = 0x8002;
		bar.backgroundColor = TGColourFromHex(0x0E7ACD);
		bar.hidden = YES;
		[cell.contentView addSubview:bar];

		UIImageView *picture = [[UIImageView alloc] init];
		picture.tag = 0x8003;
		picture.contentMode = UIViewContentModeScaleAspectFill;
		picture.clipsToBounds = YES;
		picture.hidden = YES;
		[cell.contentView addSubview:picture];

		UILabel *caption = [[UILabel alloc] init];
		caption.tag = 0x8004;
		caption.numberOfLines = 0;
		caption.font = [UIFont systemFontOfSize:13];
		caption.textColor = TGColourFromHex(0x697487);
		caption.backgroundColor = [UIColor clearColor];
		caption.hidden = YES;
		[cell.contentView addSubview:caption];
	}

	TGEmojiLabel *body = (TGEmojiLabel *)[cell.contentView viewWithTag:0x8001];
	UIView *bar = [cell.contentView viewWithTag:0x8002];
	UIImageView *picture = (UIImageView *)[cell.contentView viewWithTag:0x8003];
	UILabel *caption = (UILabel *)[cell.contentView viewWithTag:0x8004];
	body.hidden = YES;
	body.richLayout = nil;
	bar.hidden = YES;
	picture.hidden = YES;
	caption.hidden = YES;
	cell.backgroundColor = [UIColor whiteColor];

	if (indexPath.row >= (NSInteger)_blocks.count)
		return cell;
	NSDictionary *block = _blocks[indexPath.row];
	NSString *kind = block[@"kind"] ?: @"unsupported";
	CGFloat height = [_heights[indexPath.row] floatValue];
	CGFloat width = tableView.bounds.size.width;

	if ([kind isEqualToString:@"divider"]) {
		bar.hidden = NO;
		bar.backgroundColor = [[TGTheme shared] separatorColour];
		bar.frame = CGRectMake(15, 8, width - 30, 1);
		return cell;
	}

	if ([kind isEqualToString:@"photo"] || [kind isEqualToString:@"cover"] ||
		[kind isEqualToString:@"animation"] || [kind isEqualToString:@"video"]) {
		[self fetchImageForBlock:block];
		NSNumber *fileId = block[@"photoFileId"];
		UIImage *image = [fileId isKindOfClass:NSNumber.class] ? _images[fileId] : nil;
		NSString *text = block[@"captionText"];
		CGFloat captionH = 0;
		if (text.length) {
			CGSize s = [text sizeWithFont:[UIFont systemFontOfSize:13]
						constrainedToSize:CGSizeMake(width - 30, 200)
							lineBreakMode:NSLineBreakByWordWrapping];
			captionH = s.height + 6;
		}
		CGFloat pictureH = MAX(0, height - captionH - 11);
		picture.hidden = NO;
		picture.image = image;
		picture.backgroundColor = image ? [UIColor clearColor] : TGColourFromHex(0xEEF1F4);
		picture.frame = CGRectMake(0, 5, width, pictureH);
		if (text.length) {
			caption.hidden = NO;
			caption.text = text;
			caption.frame = CGRectMake(15, 5 + pictureH + 6, width - 30, captionH - 6);
		}
		return cell;
	}

	if (![TGInstantViewController kindIsText:kind]) {
		body.hidden = NO;
		body.font = [UIFont systemFontOfSize:15];
		body.textColor = TGColourFromHex(0x141617);
		NSString *title = block[@"text"];
		body.text = title.length
			? [NSString stringWithFormat:TGL(@"Chat.TapToOpenInSafari", @"%@\nTap to open in Safari"), title]
			: TGL(@"Chat.TapToOpenInSafariGeneric", @"Tap to open in Safari");
		body.frame = CGRectMake(15, 8, width - 30, 50);
		cell.backgroundColor = TGColourFromHex(0xEEF1F4);
		return cell;
	}

	NSString *text = [TGInstantViewController textOfBlock:block];
	CGFloat inset = 15;
	if ([kind isEqualToString:@"blockQuote"] || [kind isEqualToString:@"pullQuote"]) {
		inset += 10;
		bar.hidden = NO;
		bar.backgroundColor = TGColourFromHex(0x0E7ACD);
		bar.frame = CGRectMake(15, 4, kPreviewBar, MAX(0, height - 11));
	}
	if ([kind isEqualToString:@"list"])
		inset += 20;

	CGFloat top = [kind isEqualToString:@"sectionHeading"] ? 12 : 4;
	body.hidden = NO;
	body.font = [TGInstantViewController fontForKind:kind];
	body.textColor = [TGInstantViewController colourForKind:kind];
	body.text = [kind isEqualToString:@"kicker"] ? text.uppercaseString : text;
	body.backgroundColor = [kind isEqualToString:@"preformatted"]
		? TGColourFromHex(0xEEF1F4)
		: [UIColor clearColor];
	body.frame = CGRectMake(inset, top, [TGInstantViewController textWidthForKind:kind width:width],
		MAX(0, height - 11 - (top - 4)));

	NSArray *entities = TGIVStyledEntitiesForBlock(block, kind);
	if (entities.count) {
		TGRichTextPalette *palette = [TGRichTextPalette paletteWithFont:body.font
																  colour:body.textColor
															  linkColour:TGColourFromHex(0x0E7ACD)
															accentColour:TGColourFromHex(0x0E7ACD)];
		NSAttributedString *styled = TGRichTextBuild(text, entities, palette, YES);
		body.richLayout = [TGRichTextLayout layoutWithText:styled
													  width:body.frame.size.width
												   maxLines:0
												  alignment:NSTextAlignmentLeft
											 expandedBlocks:nil];
	}
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row >= (NSInteger)_blocks.count)
		return;
	NSDictionary *block = _blocks[indexPath.row];
	if ([TGInstantViewController kindIsText:block[@"kind"]]) {
		[self followTappedRichLinkAtIndexPath:indexPath];
		return;
	}
	NSString *link = block[@"url"] ?: self.url;
	if (link.length)
		[TGWebViewController openURLString:link fromViewController:self];
}

- (void)followTappedRichLinkAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [_table cellForRowAtIndexPath:indexPath];

	TGEmojiLabel *body = nil;
	BOOL touchKnown = NO;
	CGPoint touchInCell = CGPointZero;

	if ([cell isKindOfClass:TGInstantViewTextCell.class]) {
		TGInstantViewTextCell *textCell = (TGInstantViewTextCell *)cell;
		touchKnown = textCell.lastTouchKnown;
		touchInCell = textCell.lastTouchInCell;
		textCell.lastTouchKnown = NO;
		body = (TGEmojiLabel *)[cell.contentView viewWithTag:0x8001];
	} else if ([cell isKindOfClass:TGInstantViewCellBase.class]) {
		TGInstantViewCellBase *blockCell = (TGInstantViewCellBase *)cell;
		touchKnown = blockCell.lastTouchKnown;
		touchInCell = blockCell.lastTouchInCell;
		blockCell.lastTouchKnown = NO;
		body = blockCell.body;
	} else {
		return;
	}

	if (!touchKnown)
		return;

	TGRichTextLayout *layout = body.richLayout;
	if (!layout || body.hidden)
		return;

	CGPoint point = [body convertPoint:touchInCell fromView:cell.contentView];
	NSDictionary *link = [layout linkAtPoint:point inRect:body.bounds];
	if (link)
		[self followInstantViewRichLink:link];
}

- (void)followInstantViewRichLink:(NSDictionary *)link {
	NSString *kind = link[TGRichLinkKindKey];
	NSString *value = link[TGRichLinkValueKey];
	if (![kind isKindOfClass:NSString.class] || ![value isKindOfClass:NSString.class] || !value.length)
		return;

	if ([kind isEqualToString:@"url"]) {
		if ([value hasPrefix:kTGIVAnchorLinkScheme]) {
			[self scrollToAnchorNamed:[value substringFromIndex:kTGIVAnchorLinkScheme.length]];
			return;
		}
		[TGWebViewController openURLString:value fromViewController:self];
		return;
	}
	if ([kind isEqualToString:@"phone"]) {
		[TGWebViewController openURLString:[@"tel:" stringByAppendingString:value] fromViewController:self];
		return;
	}
	if ([kind isEqualToString:@"mention"]) {
		NSString *username = value.length > 1 ? [value substringFromIndex:1] : value;
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] publicLinkForUsername:username completion:^(NSString *publicLink) {
			TGInstantViewController *strongSelf = weakSelf;
			if (!strongSelf || !publicLink.length)
				return;
			[TGWebViewController openURLString:publicLink fromViewController:strongSelf];
		}];
		return;
	}
	if ([kind isEqualToString:@"user"]) {
		[self openProfileForUserId:value.longLongValue];
	}
}

- (void)openProfileForUserId:(long long)userId {
	if (userId <= 0)
		return;
	UINavigationController *navigation = self.navigationController;
	if (!navigation)
		return;
	NSString *name = [[TGClient shared] nameForUserId:userId] ?: @"";
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] privateChatWithUser:userId completion:^(int64_t chatId) {
		TGInstantViewController *strongSelf = weakSelf;
		if (!strongSelf || !chatId)
			return;
		[TGProfileViewController showProfileForChatId:chatId
											   userId:userId
												title:name
										 inNavigation:navigation];
	}];
}

- (void)scrollToAnchorNamed:(NSString *)anchor {
	if (!anchor.length) {
		[_table setContentOffset:CGPointZero animated:YES];
		return;
	}
	for (NSUInteger i = 0; i < _blocks.count; i++) {
		NSDictionary *candidate = _blocks[i];
		if ([candidate[@"kind"] isEqualToString:@"anchor"] && [candidate[@"name"] isEqualToString:anchor]) {
			[_table scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]
						   atScrollPosition:UITableViewScrollPositionTop
								   animated:YES];
			return;
		}
	}
}

- (UIImage *)instantViewRowBridge:(TGInstantViewRowBridge *)bridge imageForFileId:(long long)fileId {
	[self fetchImageForFileId:fileId];
	return _images[@(fileId)];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	[_images removeAllObjects];
	[_imagesRequested removeAllObjects];
	[_table reloadData];
}

@end

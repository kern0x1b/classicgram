#import "TGFlattenWebLinks.h"
#import "TGStringTruncation.h"

static NSString *TGWLString(id value) {
	return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSNumber *TGWLNumber(id value) {
	return [value isKindOfClass:NSNumber.class] ? value : @(0);
}

static NSNumber *TGWLBool(id value) {
	return @([TGWLNumber(value) boolValue]);
}

static NSDictionary *TGWLDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSArray *TGWLArray(id value) {
	return [value isKindOfClass:NSArray.class] ? value : nil;
}

static NSString *TGWLKind(id typeName, NSString *prefix) {
	NSString *name = TGWLString(typeName);
	if (prefix.length && name.length > prefix.length &&
		[name hasPrefix:prefix])
		name = [name substringFromIndex:prefix.length];
	if (name.length == 0)
		return @"unsupported";
	return TGStringWithFirstCharacterLowercased(name);
}

static void TGWLSetString(NSMutableDictionary *out, NSString *key, id raw) {
	if ([raw isKindOfClass:NSString.class] && [raw length])
		out[key] = raw;
}

static NSNumber *TGWLFileId(id file) {
	NSDictionary *f = TGWLDict(file);
	id fileId = f[@"id"];
	return [fileId isKindOfClass:NSNumber.class] ? fileId : nil;
}

static NSDictionary *TGWLBiggestSize(id photo) {
	NSArray *sizes = TGWLArray(TGWLDict(photo)[@"sizes"]);
	if (!sizes.count)
		return nil;
	NSDictionary *best = nil;
	NSInteger bestArea = -1;
	for (id raw in sizes) {
		NSDictionary *size = TGWLDict(raw);
		if (!size)
			continue;
		NSInteger area = [TGWLNumber(size[@"width"]) integerValue] *
			[TGWLNumber(size[@"height"]) integerValue];
		if (area > bestArea) {
			bestArea = area;
			best = size;
		}
	}
	return best;
}

static void TGWLAddPhoto(NSMutableDictionary *out, id photo) {
	NSDictionary *size = TGWLBiggestSize(photo);
	if (!size)
		return;
	NSNumber *fileId = TGWLFileId(size[@"photo"]);
	if (!fileId)
		return;
	out[@"photoFileId"] = fileId;
	out[@"width"] = TGWLNumber(size[@"width"]);
	out[@"height"] = TGWLNumber(size[@"height"]);
}

static void TGWLAddThumbnail(NSMutableDictionary *out, id thumbnail) {
	NSDictionary *thumb = TGWLDict(thumbnail);
	NSNumber *fileId = TGWLFileId(thumb[@"file"]);
	if (!fileId)
		return;
	out[@"photoFileId"] = fileId;
	if (!out[@"width"]) {
		out[@"width"] = TGWLNumber(thumb[@"width"]);
		out[@"height"] = TGWLNumber(thumb[@"height"]);
	}
}

#pragma mark - rich text

static void TGWLAppendRich(id node, NSMutableString *text, NSMutableArray *runs);

static void TGWLAppendRichList(id nodes, NSMutableString *text, NSMutableArray *runs) {
	for (id child in (TGWLArray(nodes) ?: @[]))
		TGWLAppendRich(child, text, runs);
}

static void TGWLAppendRich(id node, NSMutableString *text, NSMutableArray *runs) {
	NSDictionary *rich = TGWLDict(node);
	if (!rich)
		return;
	NSString *type = TGWLString(rich[@"@type"]);

	if ([type isEqualToString:@"richTextPlain"]) {
		[text appendString:TGWLString(rich[@"text"])];
		return;
	}
	if ([type isEqualToString:@"richTexts"]) {
		TGWLAppendRichList(rich[@"texts"], text, runs);
		return;
	}
	if ([type isEqualToString:@"richTextAnchor"])
		return;
	if ([type isEqualToString:@"richTextIcon"])
		return;
	if ([type isEqualToString:@"richTextMathematicalExpression"]) {
		[text appendString:TGWLString(rich[@"expression"])];
		return;
	}
	if ([type isEqualToString:@"richTextCustomEmoji"]) {
		[text appendString:TGWLString(rich[@"alternative_text"])];
		return;
	}

	NSInteger start = text.length;
	if ([type isEqualToString:@"richTextDiff"])
		TGWLAppendRich(rich[@"text"], text, runs);
	else if (rich[@"text"])
		TGWLAppendRich(rich[@"text"], text, runs);
	NSInteger length = text.length - start;
	if (length == 0)
		return;

	NSString *kind = TGWLKind(type, @"richText");
	NSMutableDictionary *run = [NSMutableDictionary dictionary];
	run[@"offset"] = @(start);
	run[@"length"] = @(length);
	run[@"kind"] = kind;
	run[@"tappable"] = @NO;
	if ([type isEqualToString:@"richTextUrl"] ||
		[type isEqualToString:@"richTextReferenceLink"]) {
		TGWLSetString(run, @"url", rich[@"url"]);
		run[@"tappable"] = @YES;
	} else if ([type isEqualToString:@"richTextEmailAddress"]) {
		TGWLSetString(run, @"email", rich[@"email_address"]);
		run[@"tappable"] = @YES;
	} else if ([type isEqualToString:@"richTextPhoneNumber"]) {
		TGWLSetString(run, @"phone", rich[@"phone_number"]);
		run[@"tappable"] = @YES;
	} else if ([type isEqualToString:@"richTextAnchorLink"]) {
		TGWLSetString(run, @"anchor", rich[@"anchor_name"]);
		TGWLSetString(run, @"url", rich[@"url"]);
		run[@"tappable"] = @YES;
	} else if ([type isEqualToString:@"richTextMention"]) {
		TGWLSetString(run, @"username", rich[@"username"]);
		run[@"tappable"] = @YES;
	} else if ([type isEqualToString:@"richTextHashtag"]) {
		TGWLSetString(run, @"hashtag", rich[@"hashtag"]);
		run[@"tappable"] = @YES;
	} else if ([type isEqualToString:@"richTextCashtag"]) {
		TGWLSetString(run, @"cashtag", rich[@"cashtag"]);
		run[@"tappable"] = @YES;
	} else if ([type isEqualToString:@"richTextBankCardNumber"]) {
		TGWLSetString(run, @"bankCard", rich[@"bank_card_number"]);
		run[@"tappable"] = @YES;
	} else if ([type isEqualToString:@"richTextMentionName"]) {
		run[@"userId"] = TGWLNumber(rich[@"user_id"]);
		run[@"tappable"] = @YES;
	}
	[runs addObject:run];
}

NSDictionary *TGWLRichPair(id node, NSString *textKey, NSString *runsKey) {
	NSMutableString *text = [NSMutableString string];
	NSMutableArray *runs = [NSMutableArray array];
	TGWLAppendRich(node, text, runs);
	if (text.length == 0 && runs.count == 0)
		return nil;
	return @{textKey : [NSString stringWithString:text], runsKey : runs};
}

static void TGWLMergeRich(NSMutableDictionary *out, id node,
	NSString *textKey, NSString *runsKey) {
	NSDictionary *pair = TGWLRichPair(node, textKey, runsKey);
	if (pair)
		[out addEntriesFromDictionary:pair];
}

#pragma mark - page blocks

static NSDictionary *TGWLBlock(id rawBlock) {
	NSDictionary *block = TGWLDict(rawBlock);
	if (!block)
		return nil;
	NSString *type = TGWLString(block[@"@type"]);
	NSMutableDictionary *out = [NSMutableDictionary dictionary];
	out[@"kind"] = TGWLKind(type, @"pageBlock");

	TGWLMergeRich(out, block[@"title"], @"text", @"runs");
	TGWLMergeRich(out, block[@"subtitle"], @"text", @"runs");
	TGWLMergeRich(out, block[@"header"], @"text", @"runs");
	TGWLMergeRich(out, block[@"subheader"], @"text", @"runs");
	TGWLMergeRich(out, block[@"kicker"], @"text", @"runs");
	TGWLMergeRich(out, block[@"footer"], @"text", @"runs");
	TGWLMergeRich(out, block[@"author"], @"text", @"runs");
	if (![type isEqualToString:@"pageBlockTable"])
		TGWLMergeRich(out, block[@"text"], @"text", @"runs");

	NSDictionary *caption = TGWLDict(block[@"caption"]);
	if (caption) {
		TGWLMergeRich(out, caption[@"text"], @"captionText", @"captionRuns");
		TGWLMergeRich(out, caption[@"credit"], @"creditText", @"creditRuns");
	}
	if (block[@"credit"])
		TGWLMergeRich(out, block[@"credit"], @"creditText", @"creditRuns");

	if (block[@"publish_date"])
		out[@"publishDate"] = TGWLNumber(block[@"publish_date"]);
	if (block[@"language"])
		TGWLSetString(out, @"language", block[@"language"]);
	if (block[@"name"])
		TGWLSetString(out, @"name", block[@"name"]);
	if (block[@"size"])
		out[@"size"] = TGWLNumber(block[@"size"]);

	if ([type isEqualToString:@"pageBlockPhoto"]) {
		TGWLAddPhoto(out, block[@"photo"]);
		TGWLSetString(out, @"url", block[@"url"]);
	} else if ([type isEqualToString:@"pageBlockAnimation"] ||
		[type isEqualToString:@"pageBlockVideo"]) {
		NSDictionary *media = TGWLDict(block[@"animation"]) ?: TGWLDict(block[@"video"]);
		NSNumber *fileId = TGWLFileId(media[@"animation"]) ?: TGWLFileId(media[@"video"]);
		if (fileId)
			out[@"fileId"] = fileId;
		out[@"width"] = TGWLNumber(media[@"width"]);
		out[@"height"] = TGWLNumber(media[@"height"]);
		out[@"duration"] = TGWLNumber(media[@"duration"]);
		out[@"autoplay"] = TGWLBool(block[@"need_autoplay"]);
		out[@"looped"] = TGWLBool(block[@"is_looped"]);
		TGWLAddThumbnail(out, media[@"thumbnail"]);
	} else if ([type isEqualToString:@"pageBlockAudio"] ||
		[type isEqualToString:@"pageBlockVoiceNote"]) {
		NSDictionary *media = TGWLDict(block[@"audio"]) ?: TGWLDict(block[@"voice_note"]);
		NSNumber *fileId = TGWLFileId(media[@"audio"]) ?: TGWLFileId(media[@"voice"]);
		if (fileId)
			out[@"fileId"] = fileId;
		out[@"duration"] = TGWLNumber(media[@"duration"]);
		TGWLSetString(out, @"performer", media[@"performer"]);
		TGWLSetString(out, @"trackName", media[@"title"]);
	} else if ([type isEqualToString:@"pageBlockCover"]) {
		NSDictionary *cover = TGWLBlock(block[@"cover"]);
		if (cover) {
			out[@"blocks"] = @[ cover ];
			NSMutableDictionary *hoisted = [cover mutableCopy];
			[hoisted removeObjectForKey:@"kind"];
			[out addEntriesFromDictionary:hoisted];
		}
	} else if ([type isEqualToString:@"pageBlockEmbedded"]) {
		TGWLSetString(out, @"url", block[@"url"]);
		TGWLAddPhoto(out, block[@"poster_photo"]);
		out[@"width"] = TGWLNumber(block[@"width"]);
		out[@"height"] = TGWLNumber(block[@"height"]);
	} else if ([type isEqualToString:@"pageBlockEmbeddedPost"]) {
		TGWLSetString(out, @"url", block[@"url"]);
		TGWLSetString(out, @"author", block[@"author"]);
		out[@"publishDate"] = TGWLNumber(block[@"date"]);
		TGWLAddPhoto(out, block[@"author_photo"]);
		out[@"blocks"] = TGWLBlocks(block[@"blocks"]);
	} else if ([type isEqualToString:@"pageBlockCollage"] ||
		[type isEqualToString:@"pageBlockSlideshow"] ||
		[type isEqualToString:@"pageBlockBlockQuote"]) {
		out[@"blocks"] = TGWLBlocks(block[@"blocks"]);
	} else if ([type isEqualToString:@"pageBlockDetails"]) {
		out[@"blocks"] = TGWLBlocks(block[@"blocks"]);
		out[@"isOpen"] = TGWLBool(block[@"is_open"]);
	} else if ([type isEqualToString:@"pageBlockList"]) {
		NSMutableArray *items = [NSMutableArray array];
		for (id raw in (TGWLArray(block[@"items"]) ?: @[])) {
			NSDictionary *item = TGWLDict(raw);
			if (!item)
				continue;
			[items addObject:@{
				@"label" : TGWLString(item[@"label"]),
				@"blocks" : TGWLBlocks(item[@"blocks"]),
			}];
		}
		out[@"items"] = items;
	} else if ([type isEqualToString:@"pageBlockChatLink"]) {
		TGWLSetString(out, @"title", block[@"title"]);
		TGWLSetString(out, @"username", block[@"username"]);
		NSNumber *photoId = TGWLFileId(TGWLDict(block[@"photo"])[@"small"]);
		if (photoId)
			out[@"photoFileId"] = photoId;
	} else if ([type isEqualToString:@"pageBlockTable"]) {
		TGWLMergeRich(out, block[@"caption"], @"captionText", @"captionRuns");
		out[@"isBordered"] = TGWLBool(block[@"is_bordered"]);
		out[@"isStriped"] = TGWLBool(block[@"is_striped"]);
		NSMutableArray *rows = [NSMutableArray array];
		for (id rawRow in (TGWLArray(block[@"cells"]) ?: @[])) {
			NSMutableArray *row = [NSMutableArray array];
			for (id rawCell in (TGWLArray(rawRow) ?: @[])) {
				NSDictionary *cell = TGWLDict(rawCell);
				if (!cell)
					continue;
				NSMutableDictionary *flat = [NSMutableDictionary dictionary];
				flat[@"text"] = @"";
				flat[@"runs"] = @[];
				TGWLMergeRich(flat, cell[@"text"], @"text", @"runs");
				flat[@"isHeader"] = TGWLBool(cell[@"is_header"]);
				flat[@"colspan"] = TGWLNumber(cell[@"colspan"]);
				flat[@"rowspan"] = TGWLNumber(cell[@"rowspan"]);
				flat[@"align"] = TGWLKind(TGWLDict(cell[@"align"])[@"@type"],
					@"pageBlockHorizontalAlignment");
				flat[@"valign"] = TGWLKind(TGWLDict(cell[@"valign"])[@"@type"],
					@"pageBlockVerticalAlignment");
				[row addObject:flat];
			}
			[rows addObject:row];
		}
		out[@"rows"] = rows;
	} else if ([type isEqualToString:@"pageBlockRelatedArticles"]) {
		NSMutableArray *articles = [NSMutableArray array];
		for (id raw in (TGWLArray(block[@"articles"]) ?: @[])) {
			NSDictionary *article = TGWLDict(raw);
			if (!article)
				continue;
			NSMutableDictionary *flat = [NSMutableDictionary dictionary];
			flat[@"url"] = TGWLString(article[@"url"]);
			flat[@"title"] = TGWLString(article[@"title"]);
			flat[@"description"] = TGWLString(article[@"description"]);
			flat[@"author"] = TGWLString(article[@"author"]);
			flat[@"publishDate"] = TGWLNumber(article[@"publish_date"]);
			TGWLAddPhoto(flat, article[@"photo"]);
			[articles addObject:flat];
		}
		out[@"articles"] = articles;
	} else if ([type isEqualToString:@"pageBlockMap"]) {
		NSDictionary *location = TGWLDict(block[@"location"]);
		out[@"latitude"] = TGWLNumber(location[@"latitude"]);
		out[@"longitude"] = TGWLNumber(location[@"longitude"]);
		out[@"zoom"] = TGWLNumber(block[@"zoom"]);
		out[@"width"] = TGWLNumber(block[@"width"]);
		out[@"height"] = TGWLNumber(block[@"height"]);
	}

	return out;
}

NSArray *TGWLBlocks(id rawBlocks) {
	NSMutableArray *out = [NSMutableArray array];
	for (id raw in (TGWLArray(rawBlocks) ?: @[])) {
		NSDictionary *block = TGWLBlock(raw);
		if (block)
			[out addObject:block];
	}
	return out;
}

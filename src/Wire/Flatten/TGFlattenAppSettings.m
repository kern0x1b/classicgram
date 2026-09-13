#import "TGFlattenAppSettings.h"

static NSString *TGASIdString(id value) {
	if ([value isKindOfClass:NSString.class])
		return value;
	if ([value isKindOfClass:NSNumber.class])
		return [NSString stringWithFormat:@"%lld", [value longLongValue]];
	return nil;
}

static NSDictionary *TGASDict(id value) {
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSArray *TGASArray(id value) {
	return [value isKindOfClass:NSArray.class] ? value : @[];
}

static NSNumber *TGASFileId(id file) {
	NSDictionary *dict = TGASDict(file);
	id fileId = dict[@"id"];
	if ([fileId isKindOfClass:NSNumber.class])
		return fileId;
	return nil;
}

void TGASApplyFill(NSMutableDictionary *out, NSDictionary *fill) {
	if (!fill)
		return;
	NSString *type = fill[@"@type"];
	if ([type isEqualToString:@"backgroundFillSolid"]) {
		id color = fill[@"color"];
		if ([color isKindOfClass:NSNumber.class]) {
			out[@"topColor"] = color;
			out[@"bottomColor"] = color;
		}
		return;
	}
	if ([type isEqualToString:@"backgroundFillGradient"]) {
		if ([fill[@"top_color"] isKindOfClass:NSNumber.class])
			out[@"topColor"] = fill[@"top_color"];
		if ([fill[@"bottom_color"] isKindOfClass:NSNumber.class])
			out[@"bottomColor"] = fill[@"bottom_color"];
		if ([fill[@"rotation_angle"] isKindOfClass:NSNumber.class])
			out[@"rotation"] = fill[@"rotation_angle"];
		return;
	}
	if ([type isEqualToString:@"backgroundFillFreeformGradient"]) {
		NSArray *colors = fill[@"colors"];
		if ([colors isKindOfClass:NSArray.class] && colors.count > 0) {
			if ([colors[0] isKindOfClass:NSNumber.class])
				out[@"topColor"] = colors[0];
			id last = colors.lastObject;
			if ([last isKindOfClass:NSNumber.class])
				out[@"bottomColor"] = last;
		}
	}
}

NSDictionary *TGASBackgroundRow(id object) {
	NSDictionary *background = TGASDict(object);
	if (!background)
		return nil;
	NSMutableDictionary *out = [NSMutableDictionary dictionary];
	NSString *identifier = TGASIdString(background[@"id"]);
	out[@"id"] = identifier ? identifier : @"0";
	NSString *name = background[@"name"];
	out[@"name"] = [name isKindOfClass:NSString.class] ? name : @"";
	out[@"isDark"] = @([background[@"is_dark"] boolValue]);
	out[@"isDefault"] = @([background[@"is_default"] boolValue]);

	NSDictionary *document = TGASDict(background[@"document"]);
	NSNumber *fileId = TGASFileId(document[@"document"]);
	if (fileId)
		out[@"fileId"] = fileId;
	NSDictionary *thumbnail = TGASDict(document[@"thumbnail"]);
	NSNumber *thumbId = TGASFileId(thumbnail[@"file"]);
	if (thumbId)
		out[@"thumbFileId"] = thumbId;

	NSDictionary *type = TGASDict(background[@"type"]);
	NSString *typeName = type[@"@type"];
	NSString *kind = @"wallpaper";
	if ([typeName isEqualToString:@"backgroundTypePattern"])
		kind = @"pattern";
	else if ([typeName isEqualToString:@"backgroundTypeFill"])
		kind = @"fill";
	else if ([typeName isEqualToString:@"backgroundTypeChatTheme"])
		kind = @"theme";
	out[@"kind"] = kind;
	out[@"isBlurred"] = @([type[@"is_blurred"] boolValue]);
	out[@"isMoving"] = @([type[@"is_moving"] boolValue]);
	if ([type[@"intensity"] isKindOfClass:NSNumber.class])
		out[@"intensity"] = type[@"intensity"];
	out[@"isInverted"] = @([type[@"is_inverted"] boolValue]);
	TGASApplyFill(out, TGASDict(type[@"fill"]));
	return out;
}

NSDictionary *TGASFillFromRow(NSDictionary *row) {
	NSNumber *top = row[@"topColor"];
	NSNumber *bottom = row[@"bottomColor"];
	if (![top isKindOfClass:NSNumber.class])
		top = @0;
	if (![bottom isKindOfClass:NSNumber.class])
		bottom = top;
	if ([top intValue] == [bottom intValue])
		return @{@"@type" : @"backgroundFillSolid",
			@"color" : @([top intValue])};
	NSInteger angle = [row[@"rotation"] isKindOfClass:NSNumber.class]
		? [row[@"rotation"] integerValue]
		: 0;
	angle %= 360;
	if (angle < 0)
		angle += 360;
	angle = (angle / 45) * 45;
	return @{@"@type" : @"backgroundFillGradient",
		@"top_color" : @([top intValue]),
		@"bottom_color" : @([bottom intValue]),
		@"rotation_angle" : @((int)angle)};
}

NSDictionary *TGASBackgroundTypeForKind(NSString *kind) {
	if ([kind isEqualToString:@"pattern"])
		return @{@"@type" : @"backgroundTypePattern",
			@"fill" : @{@"@type" : @"backgroundFillSolid", @"color" : @0},
			@"intensity" : @50,
			@"is_inverted" : @NO,
			@"is_moving" : @NO};
	if ([kind isEqualToString:@"fill"])
		return @{@"@type" : @"backgroundTypeFill",
			@"fill" : @{@"@type" : @"backgroundFillSolid", @"color" : @0}};
	return @{@"@type" : @"backgroundTypeWallpaper",
		@"is_blurred" : @NO,
		@"is_moving" : @NO};
}

NSDictionary *TGASThemeColoursFromSettings(NSDictionary *settings) {
	if (!settings)
		return nil;
	NSMutableDictionary *colours = [NSMutableDictionary dictionary];
	NSNumber *accent = [settings[@"accent_color"] isKindOfClass:NSNumber.class]
		? settings[@"accent_color"]
		: nil;
	if (accent)
		colours[@"accentColour"] = accent;
	NSMutableDictionary *fillRow = [NSMutableDictionary dictionary];
	TGASApplyFill(fillRow, TGASDict(settings[@"outgoing_message_fill"]));
	NSNumber *bubbleColour = [fillRow[@"topColor"] isKindOfClass:NSNumber.class]
		? fillRow[@"topColor"]
		: nil;
	if (bubbleColour)
		colours[@"bubbleMineColour"] = bubbleColour;
	return colours.count > 0 ? colours : nil;
}

NSArray *TGASWebDomainExceptions(id rawList) {
	NSMutableArray *out = [NSMutableArray array];
	for (id raw in TGASArray(rawList)) {
		NSDictionary *entry = TGASDict(raw);
		if (!entry)
			continue;
		NSString *domain = TGASIdString(entry[@"domain"]);
		if (!domain.length)
			continue;
		[out addObject:@{
			@"url" : TGASIdString(entry[@"url"]),
			@"domain" : domain,
			@"title" : TGASIdString(entry[@"title"]),
		}];
	}
	return out;
}

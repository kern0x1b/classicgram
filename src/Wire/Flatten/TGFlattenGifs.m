#import "TGFlattenGifs.h"

static NSDictionary *TGFGDict(id value) {
	return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

static NSString *TGFGString(id value) {
	return [value isKindOfClass:[NSString class]] ? value : nil;
}

static NSNumber *TGFGNumber(id value) {
	if ([value isKindOfClass:[NSNumber class]])
		return value;
	if ([value isKindOfClass:[NSString class]])
		return [NSNumber numberWithLongLong:[value longLongValue]];
	return @0;
}

static NSString *TGFGUniqueId(NSDictionary *file) {
	return TGFGString(TGFGDict(file[@"remote"])[@"unique_id"]) ?: @"";
}

NSDictionary *TGFlattenAnimation(id object) {
	NSDictionary *animation = TGFGDict(object);
	NSDictionary *file = TGFGDict(animation[@"animation"]);
	NSNumber *fileId = file[@"id"];
	if (![fileId isKindOfClass:[NSNumber class]])
		return nil;

	NSDictionary *thumbnail = TGFGDict(animation[@"thumbnail"]);
	NSDictionary *thumbFile = TGFGDict(thumbnail[@"file"]);
	NSNumber *thumbId = thumbFile[@"id"];
	if (![thumbId isKindOfClass:[NSNumber class]])
		thumbId = @0;

	NSString *thumbFormat = TGFGString(TGFGDict(thumbnail[@"format"])[@"@type"]) ?: @"";
	BOOL thumbIsVideo = [thumbFormat isEqualToString:@"thumbnailFormatMpeg4"] ||
		[thumbFormat isEqualToString:@"thumbnailFormatWebm"];
	if ([thumbFormat isEqualToString:@"thumbnailFormatWebm"] ||
		[thumbFormat isEqualToString:@"thumbnailFormatTgs"])
		thumbId = @0;

	NSMutableDictionary *out = [NSMutableDictionary dictionaryWithDictionary:@{
		@"fileId" : fileId,
		@"thumbId" : thumbId,
		@"thumbIsVideo" : @(thumbIsVideo),
		@"thumbUniqueId" : TGFGUniqueId(thumbFile),
		@"uniqueId" : TGFGUniqueId(file),
		@"width" : TGFGNumber(animation[@"width"]),
		@"height" : TGFGNumber(animation[@"height"]),
		@"duration" : TGFGNumber(animation[@"duration"]),
		@"mimeType" : TGFGString(animation[@"mime_type"]) ?: @"",
		@"title" : TGFGString(animation[@"file_name"]) ?: @"",
	}];

	NSDictionary *mini = TGFGDict(animation[@"minithumbnail"]);
	if (mini != nil)
		out[@"minithumbnail"] = mini;
	return out;
}

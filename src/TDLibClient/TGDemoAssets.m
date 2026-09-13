#import "TGDemoAssets.h"

#import <UIKit/UIKit.h>

static NSString *TGDemoAssetDirectory(void) {
	static NSString *directory = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		NSString *caches = [NSSearchPathForDirectoriesInDomains(
			NSCachesDirectory, NSUserDomainMask, YES) firstObject];
		directory = [caches stringByAppendingPathComponent:@"TGDemoAssets"];
		[[NSFileManager defaultManager] createDirectoryAtPath:directory
								  withIntermediateDirectories:YES
												   attributes:nil
														error:NULL];
	});
	return directory;
}

static UIImage *TGDemoSquareCrop(UIImage *image, CGFloat side) {
	if (!image)
		return nil;
	CGFloat scale = MAX(side / image.size.width, side / image.size.height);
	CGSize scaled = CGSizeMake(ceilf(image.size.width * scale), ceilf(image.size.height * scale));
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), YES, 1.0);
	[image drawInRect:CGRectMake((side - scaled.width) / 2.0, (side - scaled.height) / 2.0,
		scaled.width, scaled.height)];
	UIImage *cropped = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return cropped;
}

static NSString *TGDemoWriteJPEG(UIImage *image, NSString *name) {
	if (!image)
		return nil;
	NSString *path = [TGDemoAssetDirectory() stringByAppendingPathComponent:name];
	if ([[NSFileManager defaultManager] fileExistsAtPath:path])
		return path;
	NSData *data = UIImageJPEGRepresentation(image, 0.85);
	if (!data.length)
		return nil;
	return [data writeToFile:path atomically:YES] ? path : nil;
}

static NSString *TGDemoCopyBundleFile(NSString *resource, NSString *name) {
	NSString *source = [[NSBundle mainBundle] pathForResource:resource ofType:nil];
	if (!source)
		return nil;
	NSString *path = [TGDemoAssetDirectory() stringByAppendingPathComponent:name];
	if ([[NSFileManager defaultManager] fileExistsAtPath:path])
		return path;
	return [[NSFileManager defaultManager] copyItemAtPath:source toPath:path error:NULL]
		? path : nil;
}

static NSDictionary *TGDemoAssetMap(void) {
	static NSDictionary *map = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		NSMutableDictionary *paths = [NSMutableDictionary dictionary];
		NSArray *wallpapers = @[ @"builtin-wallpaper-0", @"builtin-wallpaper-1",
			@"builtin-wallpaper-2", @"builtin-wallpaper-3", @"builtin-wallpaper-4" ];
		for (NSUInteger index = 0; index < wallpapers.count; index++) {
			NSString *sourcePath = [[NSBundle mainBundle] pathForResource:wallpapers[index]
																   ofType:@"jpg"];
			UIImage *source = sourcePath ? [UIImage imageWithContentsOfFile:sourcePath] : nil;
			NSString *avatar = TGDemoWriteJPEG(TGDemoSquareCrop(source, 160),
				[NSString stringWithFormat:@"avatar-%lu.jpg", (unsigned long)index]);
			if (avatar)
				paths[[NSString stringWithFormat:@"avatar-%lu", (unsigned long)index]] = avatar;
			NSString *photo = TGDemoWriteJPEG(source,
				[NSString stringWithFormat:@"photo-%lu.jpg", (unsigned long)index]);
			if (photo)
				paths[[NSString stringWithFormat:@"photo-%lu", (unsigned long)index]] = photo;
			NSString *thumb = TGDemoWriteJPEG(TGDemoSquareCrop(source, 90),
				[NSString stringWithFormat:@"thumb-%lu.jpg", (unsigned long)index]);
			if (thumb)
				paths[[NSString stringWithFormat:@"thumb-%lu", (unsigned long)index]] = thumb;
		}
		NSString *voice = TGDemoCopyBundleFile(@"7.caf", @"voice.caf");
		if (voice)
			paths[@"voice"] = voice;
		NSString *document = [TGDemoAssetDirectory() stringByAppendingPathComponent:@"Schedule.txt"];
		if (![[NSFileManager defaultManager] fileExistsAtPath:document]) {
			NSString *text = @"Rehearsal 18:00\nSound check 19:15\nDoors 20:00\n";
			[text writeToFile:document atomically:YES encoding:NSUTF8StringEncoding error:NULL];
		}
		paths[@"document"] = document;
		map = paths;
	});
	return map;
}

NSString *TGDemoAssetPathForKey(NSString *key) {
	if (!key.length)
		return nil;
	return TGDemoAssetMap()[key];
}

void TGDemoPrepareAssets(void) {
	TGDemoAssetMap();
}

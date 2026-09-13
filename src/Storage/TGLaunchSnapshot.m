#import "TGLaunchSnapshot.h"
#include <sys/stat.h>

static NSString *const TGLaunchSnapshotInstalledKey = @"tgLaunchSnapshotInstalled";

static NSString *TGLaunchLastNote = @"nothing yet";

static void TGLaunchNote(NSString *format, ...) {
	va_list args;
	va_start(args, format);
	NSString *line = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	TGLaunchLastNote = line;
	NSLog(@"PERF launchimage %@", line);
}

static NSArray *TGLaunchImageNames(void) {
	UIScreen *screen = [UIScreen mainScreen];
	CGSize size = screen.bounds.size;
	CGFloat scale = [screen respondsToSelector:@selector(scale)] ? screen.scale : 1.0f;
	CGFloat height = MAX(size.width, size.height);

	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
		return scale > 1.0f
			? @[ @"LaunchImage-Portrait@2x~ipad.png", @"Default-Portrait@2x~ipad.png" ]
			: @[ @"LaunchImage-Portrait~ipad.png", @"Default-Portrait~ipad.png" ];

	if (height >= 568.0f)
		return @[ @"LaunchImage-568h@2x.png", @"Default-568h@2x.png" ];

	return scale > 1.0f
		? @[ @"LaunchImage@2x.png", @"Default@2x.png" ]
		: @[ @"LaunchImage.png", @"Default.png" ];
}

static NSString *TGBundleImagePath(NSString *name) {
	return [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:name];
}

static NSArray *TGLaunchImageTargets(void) {
	NSFileManager *files = [NSFileManager defaultManager];
	NSMutableArray *targets = [NSMutableArray array];
	for (NSString *name in TGLaunchImageNames())
		if ([files fileExistsAtPath:TGBundleImagePath(name)])
			[targets addObject:name];
	return targets;
}

static NSString *TGShippedImagePath(NSString *name) {
	NSString *support = [NSSearchPathForDirectoriesInDomains(
		NSApplicationSupportDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSString *directory = [support stringByAppendingPathComponent:@"launchimage"];
	NSFileManager *files = [NSFileManager defaultManager];
	[files createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
	return [directory stringByAppendingPathComponent:name];
}

@implementation TGLaunchSnapshot

+ (BOOL)installed {
	return [[NSUserDefaults standardUserDefaults] boolForKey:TGLaunchSnapshotInstalledKey];
}

+ (void)setInstalled:(BOOL)installed {
	[[NSUserDefaults standardUserDefaults] setBool:installed
											forKey:TGLaunchSnapshotInstalledKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSData *)blankImageData {
	UIScreen *screen = [UIScreen mainScreen];
	CGSize size = screen.bounds.size;
	CGFloat scale = [screen respondsToSelector:@selector(scale)] ? screen.scale : 1.0f;
	UIGraphicsBeginImageContextWithOptions(size, YES, scale);
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (!context) {
		UIGraphicsEndImageContext();
		return nil;
	}
	CGContextSetRGBFillColor(context, 0.84f, 0.85f, 0.87f, 1.0f);
	CGContextFillRect(context, CGRectMake(0, 0, size.width, size.height));
	CGContextSetGrayFillColor(context, 0.0f, 1.0f);
	CGContextFillRect(context, CGRectMake(0, 0, size.width, 20.0f));
	UIImage *plain = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return UIImagePNGRepresentation(plain);
}

+ (void)restoreShippedImage:(NSString *)reason {
	if (![self installed])
		return;
	NSFileManager *files = [NSFileManager defaultManager];
	NSInteger restored = 0;
	NSData *blank = nil;
	for (NSString *name in TGLaunchImageTargets()) {
		NSString *shipped = TGShippedImagePath(name);
		NSData *data = [files fileExistsAtPath:shipped]
			? [NSData dataWithContentsOfFile:shipped]
			: nil;
		if (!data.length) {
			if (!blank)
				blank = [self blankImageData];
			data = blank;
		}
		if (!data.length)
			continue;
		NSString *bundled = TGBundleImagePath(name);
		if (![data writeToFile:bundled atomically:YES])
			continue;
		chmod(bundled.fileSystemRepresentation, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
		restored++;
	}
	[self setInstalled:NO];
	TGLaunchNote(@"restored the shipped artwork (%lu file(s)): %@",
		(unsigned long)restored, reason);
}

+ (NSString *)describe {
	NSMutableString *out = [NSMutableString string];
	[out appendFormat:@"installed=%@ last=\"%@\"",
		[self installed] ? @"yes" : @"no", TGLaunchLastNote];
	for (NSString *name in TGLaunchImageNames()) {
		NSDictionary *attributes = [[NSFileManager defaultManager]
			attributesOfItemAtPath:TGBundleImagePath(name)
							 error:NULL];
		[out appendFormat:@" %@=%@", name,
			attributes ? [NSString stringWithFormat:@"%lluB mode%o",
							 [attributes fileSize],
							 (unsigned)[attributes filePosixPermissions]]
					   : @"missing"];
	}
	return out;
}

@end

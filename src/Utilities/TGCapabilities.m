#import "TGCapabilities.h"
#import "TGLocalization.h"
#import <UIKit/UIKit.h>

@implementation TGCapability
@end

static BOOL (^sVideoEncoderProbe)(void) = nil;

@implementation TGCapabilities

+ (void)setVideoEncoderProbe:(BOOL (^)(void))probe {
	sVideoEncoderProbe = [probe copy];
}

+ (double)systemVersion {
	static double version = 0;
	if (version == 0)
		version = [[UIDevice currentDevice].systemVersion doubleValue];
	return version;
}

+ (BOOL)is64Bit {
	return sizeof(void *) == 8;
}

+ (NSUInteger)memoryMB {
	return (NSUInteger)([NSProcessInfo processInfo].physicalMemory / (1024 * 1024));
}

+ (BOOL)canRunWebApps {
	return [self systemVersion] >= 9.0 && NSClassFromString(@"WKWebView") != nil;
}

+ (BOOL)canPlayAnimatedStickers {
	return [TGDevice tier] >= TGDeviceTierLegacy;
}

+ (BOOL)canShowWallpaper {
	return [TGDevice tier] >= TGDeviceTierLegacy;
}

+ (BOOL)canAnimateInline {
	return [TGDevice tier] >= TGDeviceTierModern && [self is64Bit];
}

+ (BOOL)canHoldMultipleAccounts {
	return [TGDevice tier] >= TGDeviceTierFull;
}

+ (BOOL)canEncodeVideoCall {
	return sVideoEncoderProbe ? sVideoEncoderProbe() : NO;
}

+ (NSArray *)all {
	NSString *everyDevice = TGL(@"Device.RequirementEveryDevice", @"every device");
	NSString *legacy512 = TGL(@"Device.RequirementLegacy512", @"Legacy - 512MB or more");
	NSArray *rows = @[
		@[ TGL(@"Device.CapabilityMessages", @"Messages, media, groups"), @YES, everyDevice ],
		@[ TGL(@"Device.CapabilityStickers", @"WebP stickers"), @YES, everyDevice ],
		@[ TGL(@"Device.CapabilityVoiceNotes", @"Voice notes"), @YES, everyDevice ],
		@[ TGL(@"Device.CapabilityWallpaper", @"Chat wallpaper"), @([self canShowWallpaper]), legacy512 ],
		@[ TGL(@"Device.CapabilityAnimatedStickers", @"Animated stickers"), @([self canPlayAnimatedStickers]), legacy512 ],
		@[ TGL(@"Device.CapabilityCustomEmoji", @"Custom emoji"), @([self canAnimateInline]), TGL(@"Device.RequirementModern64", @"Modern - a 64-bit chip") ],
		@[ TGL(@"Device.CapabilityMiniApps", @"Mini apps"), @([self canRunWebApps]), TGL(@"Device.RequirementIOS9", @"iOS 9 or later") ],
		@[ TGL(@"Device.CapabilityMultipleAccounts", @"Multiple accounts"), @([self canHoldMultipleAccounts]), TGL(@"Device.RequirementFull2GB", @"Full - 2GB or more") ],
		@[ TGL(@"Device.CapabilityVideoCalls", @"Video calls"), @([self canEncodeVideoCall]), TGL(@"Device.RequirementVideoCalls", @"every device - software VP8, hardware H.264 where available") ],
	];

	NSMutableArray *out = [NSMutableArray array];
	for (NSArray *row in rows) {
		TGCapability *capability = [[TGCapability alloc] init];
		capability.name = row[0];
		capability.available = [row[1] boolValue];
		capability.requirement = row[2];
		[out addObject:capability];
	}
	return out;
}

@end

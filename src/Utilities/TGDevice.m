#import "TGDevice.h"
#import "TGLocalization.h"
#import <UIKit/UIKit.h>
#include <sys/sysctl.h>

typedef struct {
	const char *machine;
	const char *name;
	const char *chip;
	unsigned memoryMB;
	double maximumIOS;
	TGDeviceTier tier;
} TGDeviceRow;

static const TGDeviceRow kDevices[] = {
	{"iPhone2,1", "iPhone 3GS", "S5L8920", 256, 6.1, TGDeviceTierVintage},
	{"iPhone3,1", "iPhone 4", "A4", 512, 7.1, TGDeviceTierVintage},
	{"iPhone3,2", "iPhone 4", "A4", 512, 7.1, TGDeviceTierVintage},
	{"iPhone3,3", "iPhone 4", "A4", 512, 7.1, TGDeviceTierVintage},
	{"iPod4,1", "iPod touch 4", "A4", 256, 6.1, TGDeviceTierVintage},

	{"iPhone4,1", "iPhone 4S", "A5", 512, 9.3, TGDeviceTierLegacy},
	{"iPad2,1", "iPad 2", "A5", 512, 9.3, TGDeviceTierLegacy},
	{"iPad2,2", "iPad 2", "A5", 512, 9.3, TGDeviceTierLegacy},
	{"iPad2,3", "iPad 2", "A5", 512, 9.3, TGDeviceTierLegacy},
	{"iPad2,4", "iPad 2", "A5", 512, 9.3, TGDeviceTierLegacy},
	{"iPhone5,1", "iPhone 5", "A6", 1024, 10.3, TGDeviceTierLegacy},
	{"iPhone5,2", "iPhone 5", "A6", 1024, 10.3, TGDeviceTierLegacy},
	{"iPhone5,3", "iPhone 5c", "A6", 1024, 10.3, TGDeviceTierLegacy},
	{"iPhone5,4", "iPhone 5c", "A6", 1024, 10.3, TGDeviceTierLegacy},
	{"iPod5,1", "iPod touch 5", "A5", 512, 9.3, TGDeviceTierLegacy},
	{"iPad2,5", "iPad mini", "A5", 512, 9.3, TGDeviceTierLegacy},
	{"iPad2,6", "iPad mini", "A5", 512, 9.3, TGDeviceTierLegacy},
	{"iPad2,7", "iPad mini", "A5", 512, 9.3, TGDeviceTierLegacy},
	{"iPad3,1", "iPad (3rd generation)", "A5X", 1024, 9.3, TGDeviceTierLegacy},
	{"iPad3,2", "iPad (3rd generation)", "A5X", 1024, 9.3, TGDeviceTierLegacy},
	{"iPad3,3", "iPad (3rd generation)", "A5X", 1024, 9.3, TGDeviceTierLegacy},
	{"iPad3,4", "iPad (4th generation)", "A6X", 1024, 10.3, TGDeviceTierLegacy},
	{"iPad3,5", "iPad (4th generation)", "A6X", 1024, 10.3, TGDeviceTierLegacy},
	{"iPad3,6", "iPad (4th generation)", "A6X", 1024, 10.3, TGDeviceTierLegacy},

	{"iPhone6,1", "iPhone 5s", "A7", 1024, 12.5, TGDeviceTierModern},
	{"iPhone6,2", "iPhone 5s", "A7", 1024, 12.5, TGDeviceTierModern},
	{"iPhone7,2", "iPhone 6", "A8", 1024, 12.5, TGDeviceTierModern},
	{"iPhone7,1", "iPhone 6 Plus", "A8", 1024, 12.5, TGDeviceTierModern},
	{"iPod7,1", "iPod touch 6", "A8", 1024, 12.5, TGDeviceTierModern},

	{"iPhone8,1", "iPhone 6s", "A9", 2048, 15.8, TGDeviceTierFull},
	{"iPhone8,2", "iPhone 6s Plus", "A9", 2048, 15.8, TGDeviceTierFull},
	{"iPhone8,4", "iPhone SE", "A9", 2048, 15.8, TGDeviceTierFull},
	{"iPhone9,1", "iPhone 7", "A10", 2048, 15.8, TGDeviceTierFull},
	{"iPhone9,3", "iPhone 7", "A10", 2048, 15.8, TGDeviceTierFull},
	{"iPhone9,2", "iPhone 7 Plus", "A10", 3072, 15.8, TGDeviceTierFull},
	{"iPhone9,4", "iPhone 7 Plus", "A10", 3072, 15.8, TGDeviceTierFull},
	{"iPhone10,1", "iPhone 8", "A11", 2048, 16.7, TGDeviceTierFull},
	{"iPhone10,4", "iPhone 8", "A11", 2048, 16.7, TGDeviceTierFull},
	{"iPhone10,2", "iPhone 8 Plus", "A11", 3072, 16.7, TGDeviceTierFull},
	{"iPhone10,5", "iPhone 8 Plus", "A11", 3072, 16.7, TGDeviceTierFull},
	{"iPhone10,3", "iPhone X", "A11", 3072, 16.7, TGDeviceTierFull},
	{"iPhone10,6", "iPhone X", "A11", 3072, 16.7, TGDeviceTierFull},
	{"iPhone11,8", "iPhone XR", "A12", 3072, 18.0, TGDeviceTierFull},
	{"iPhone11,2", "iPhone XS", "A12", 4096, 18.0, TGDeviceTierFull},
	{"iPhone11,4", "iPhone XS Max", "A12", 4096, 18.0, TGDeviceTierFull},
	{"iPhone11,6", "iPhone XS Max", "A12", 4096, 18.0, TGDeviceTierFull},
};

static const TGDeviceRow *TGRowForMachineName(const char *machine) {
	if (!machine)
		return NULL;
	for (NSInteger i = 0; i < (NSInteger)(sizeof(kDevices) / sizeof(kDevices[0])); i++) {
		if (strcmp(kDevices[i].machine, machine) == 0)
			return &kDevices[i];
	}
	return NULL;
}

static const TGDeviceRow *TGFindDevice(void) {
	static const TGDeviceRow *found = NULL;
	static BOOL searched = NO;
	if (searched)
		return found;
	searched = YES;

	found = TGRowForMachineName([TGDevice machine].UTF8String);
	return found;
}

@implementation TGDevice

+ (NSString *)machine {
	static NSString *machine = nil;
	if (machine)
		return machine;

	size_t size = 0;
	sysctlbyname("hw.machine", NULL, &size, NULL, 0);
	char *value = malloc(size + 1);
	if (!value)
		return @"";
	sysctlbyname("hw.machine", value, &size, NULL, 0);
	value[size] = '\0';
	machine = [NSString stringWithUTF8String:value];
	free(value);
	return machine;
}

+ (NSDictionary *)tableEntryForMachine:(NSString *)machine {
	const TGDeviceRow *row = TGRowForMachineName(machine.UTF8String);
	if (!row)
		return nil;
	return @{
		@"name" : [NSString stringWithUTF8String:row->name],
		@"chip" : [NSString stringWithUTF8String:row->chip],
		@"memoryMB" : @(row->memoryMB),
		@"maximumIOS" : @(row->maximumIOS),
		@"tier" : @((NSInteger)row->tier),
	};
}

+ (NSString *)modelName {
	const TGDeviceRow *row = TGFindDevice();

	return row ? [NSString stringWithUTF8String:row->name] : [self machine];
}

+ (NSString *)chip {
	const TGDeviceRow *row = TGFindDevice();
	return row ? [NSString stringWithUTF8String:row->chip] : nil;
}

+ (NSUInteger)memoryMB {
	const TGDeviceRow *row = TGFindDevice();
	if (row)
		return row->memoryMB;
	return (NSUInteger)([NSProcessInfo processInfo].physicalMemory / (1024 * 1024));
}

+ (double)maximumIOS {
	const TGDeviceRow *row = TGFindDevice();
	return row ? row->maximumIOS : 0;
}

+ (TGDeviceTier)tier {
	const TGDeviceRow *row = TGFindDevice();
	if (row)
		return row->tier;

	if (sizeof(void *) == 8)
		return [self memoryMB] >= 2048 ? TGDeviceTierFull : TGDeviceTierModern;
	return [self memoryMB] > 512 ? TGDeviceTierLegacy : TGDeviceTierVintage;
}

+ (NSString *)tierName {
	switch ([self tier]) {
		case TGDeviceTierVintage:
			return TGL(@"Device.TierVintage", @"Vintage");
		case TGDeviceTierLegacy:
			return TGL(@"Device.TierLegacy", @"Legacy");
		case TGDeviceTierModern:
			return TGL(@"Device.TierModern", @"Modern");
		default:
			return TGL(@"Device.TierFull", @"Full");
	}
}

+ (NSString *)summary {
	NSString *chip = [self chip];
	return [NSString stringWithFormat:@"%@%@%@, %luMB, iOS %@",
		[self modelName],
		chip ? @" - " : @"", chip ?: @"",
		(unsigned long)[self memoryMB],
		[UIDevice currentDevice].systemVersion];
}

+ (BOOL)isPadIdiom {
	return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
}

@end

#import "tg_device_table_tests.h"

#import "../../src/Utilities/TGDevice.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGDeviceTableTestEveryArmv7DeviceIsKnown(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	NSArray *armv7 = @[ @"iPhone3,1", @"iPhone4,1", @"iPhone5,1", @"iPhone5,3",
		@"iPod4,1", @"iPod5,1",
		@"iPad2,1", @"iPad2,5", @"iPad3,1", @"iPad3,4" ];
	for (NSString *machine in armv7) {
		NSDictionary *entry = [TGDevice tableEntryForMachine:machine];
		TGTestExpectTrue(&outcome, entry != nil,
				"this app runs on armv7 hardware, so every armv7 identifier must be in the table "
				"rather than falling back to the raw machine string");
		TGTestExpectTrue(&outcome, [entry[@"name"] rangeOfString:@","].location == NSNotFound,
				"and each has a name a person would recognise, not the identifier again");
	}

	NSDictionary *mini = [TGDevice tableEntryForMachine:@"iPad2,5"];
	TGTestExpectTrue(&outcome, [mini[@"tier"] integerValue] == (NSInteger)TGDeviceTierLegacy,
			"the first iPad mini is an A5 with 512MB, so the memory fallback would have called it "
			"Vintage and taken away the animated stickers and the wallpaper it can run");

	NSDictionary *third = [TGDevice tableEntryForMachine:@"iPad3,1"];
	TGTestExpectTrue(&outcome, [third[@"chip"] isEqualToString:@"A5X"],
			"the third-generation iPad reports its own chip rather than an iPhone's");

	TGTestExpectTrue(&outcome, [TGDevice tableEntryForMachine:@"Nonesuch1,1"] == nil,
			"a machine the table has never heard of answers nothing, and the caller falls back");

	return outcome;
}

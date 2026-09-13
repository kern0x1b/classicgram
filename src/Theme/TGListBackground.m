#import "TGListBackground.h"
#import "TGTheme.h"

UIColor *TGGroupedListBackground(void) {
	static UIColor *background = nil;
	UIImage *pattern = [UIImage imageNamed:@"SettingsBackground.png"];
	if (!pattern)
		return [[TGTheme shared] listBackgroundColour];
	if (!background)
		background = [UIColor colorWithPatternImage:pattern];
	return background;
}

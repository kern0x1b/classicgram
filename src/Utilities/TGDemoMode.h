#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const TGDemoModeDefaultsKey;

BOOL TGDemoModeWanted(NSString *_Nullable environmentValue, BOOL storedFlag, BOOL markerPresent);
NSString *TGDemoModeMarkerPath(void);
BOOL TGDemoModeEnabled(void);

NS_ASSUME_NONNULL_END

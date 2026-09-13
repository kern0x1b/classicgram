#import <Foundation/Foundation.h>

BOOL TGTestDCEnabled(void);
BOOL TGTestDCWanted(NSString *_Nullable environmentValue, BOOL storedFlag, BOOL markerPresent);
NSString *TGTestDCMarkerPath(void);
void TGSetTestDCEnabled(BOOL enabled);
NSString *TGTestDCScopeForScope(NSString *scope);

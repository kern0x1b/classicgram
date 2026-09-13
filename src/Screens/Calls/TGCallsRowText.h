#import <UIKit/UIKit.h>

NSString *TGCallsInitials(NSString *name);
NSString *TGCallsDisplayName(NSDictionary *group);
BOOL TGCallsWasMissedByMe(NSDictionary *call);
UIColor *TGCallsMissedColour(void);
NSString *TGCallsDurationText(NSInteger seconds);
NSString *TGCallsKindText(NSDictionary *call);
NSString *TGCallsSubtitleText(NSDictionary *call);

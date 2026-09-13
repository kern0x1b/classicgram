#import <Foundation/Foundation.h>
#import "TGFileStatusView.h"

NSString *TGPinnedDescriptor(NSDictionary *target);
TGFileStatusKind TGFileStatusKindForState(NSDictionary *state, BOOL playable, BOOL playing);
NSString *TGClockText(NSInteger seconds);

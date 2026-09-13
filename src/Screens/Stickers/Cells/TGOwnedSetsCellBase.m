#import "TGOwnedSetsCellBase.h"
#import "TGOwnedSetsItem.h"
#import "TGTheme.h"

@implementation TGOwnedSetsCellBase

- (void)applyItem:(TGOwnedSetsItem *)item {
	[[TGTheme shared] styleCell:self];
}

@end

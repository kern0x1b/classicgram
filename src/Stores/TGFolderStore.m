#import "TGFolderStore.h"
#import "TGClient.h"

@implementation TGFolderStore

+ (NSArray *)folders {
	return [[TGClient shared] folders];
}

@end

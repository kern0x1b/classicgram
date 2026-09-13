#import <Foundation/Foundation.h>

int64_t TGOrderInList(NSArray *positions, NSString *listType);
int64_t TGMainListOrder(NSArray *positions);
int64_t TGArchiveOrder(NSArray *positions);
BOOL TGPinnedInMain(NSArray *positions);
BOOL TGPinnedInArchive(NSArray *positions);

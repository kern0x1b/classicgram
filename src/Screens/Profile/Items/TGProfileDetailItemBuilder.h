#import <Foundation/Foundation.h>
#import "TGProfileDetailItem.h"

@interface TGProfileDetailItemBuilder : NSObject

+ (NSString *)displayLabelForKind:(NSString *)kind;
+ (TGProfileDetailItem *)itemFromPair:(NSArray *)pair isSongPlaying:(BOOL)isSongPlaying;

@end

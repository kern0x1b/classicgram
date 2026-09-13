#import <UIKit/UIKit.h>
#import "TGStorageDownloadsItem.h"

@interface TGStorageDownloadsCellCatalogue : NSObject

+ (NSString *)reuseIdentifierForKind:(TGStorageDownloadsRowKind)kind;
+ (Class)cellClassForKind:(TGStorageDownloadsRowKind)kind;
+ (UITableViewCellStyle)cellStyleForKind:(TGStorageDownloadsRowKind)kind;

@end

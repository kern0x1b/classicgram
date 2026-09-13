#import "TGStorageDownloadsCellCatalogue.h"
#import "TGStorageDownloadsRowContentCell.h"

@implementation TGStorageDownloadsCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGStorageDownloadsRowKind)kind {
	return @"TGStorageDownloadsRow";
}

+ (Class)cellClassForKind:(TGStorageDownloadsRowKind)kind {
	return [TGStorageDownloadsRowContentCell class];
}

+ (UITableViewCellStyle)cellStyleForKind:(TGStorageDownloadsRowKind)kind {
	return UITableViewCellStyleValue1;
}

@end

#import "TGConnectedWebsitesCellCatalogue.h"
#import "TGConnectedWebsiteRowCell.h"

@implementation TGConnectedWebsitesCellCatalogue

+ (NSString *)reuseIdentifierForKind:(TGConnectedWebsitesRowKind)kind {
	switch (kind) {
		case TGConnectedWebsitesRowKindSite:
			return @"TGConnectedWebsitesRow.Site";
	}
	return nil;
}

+ (Class)cellClassForKind:(TGConnectedWebsitesRowKind)kind {
	switch (kind) {
		case TGConnectedWebsitesRowKindSite:
			return [TGConnectedWebsiteRowCell class];
	}
	return nil;
}

@end

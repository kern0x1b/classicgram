#import "TGConnectedWebsitesItem.h"

@implementation TGConnectedWebsitesItem

- (instancetype)initWithKind:(TGConnectedWebsitesRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
					  siteId:(int64_t)siteId
				   titleText:(NSString *)titleText
				  detailText:(NSString *)detailText {
	self = [super init];
	if (!self)
		return nil;

	_kind = kind;
	_reuseIdentifier = [reuseIdentifier copy];
	_cellClass = cellClass;
	_siteId = siteId;
	_titleText = [titleText copy];
	_detailText = [detailText copy];

	return self;
}

@end

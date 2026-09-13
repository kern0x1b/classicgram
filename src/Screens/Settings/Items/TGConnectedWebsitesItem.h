#import <Foundation/Foundation.h>

typedef NS_ENUM(uint8_t, TGConnectedWebsitesRowKind) {
	TGConnectedWebsitesRowKindSite = 0,
};

@interface TGConnectedWebsitesItem : NSObject

@property (nonatomic, readonly) TGConnectedWebsitesRowKind kind;
@property (nonatomic, readonly, copy) NSString *reuseIdentifier;
@property (nonatomic, readonly) Class cellClass;

@property (nonatomic, readonly) int64_t siteId;
@property (nonatomic, readonly, copy) NSString *titleText;
@property (nonatomic, readonly, copy) NSString *detailText;

- (instancetype)initWithKind:(TGConnectedWebsitesRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
					  siteId:(int64_t)siteId
				   titleText:(NSString *)titleText
				  detailText:(NSString *)detailText NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

#import <UIKit/UIKit.h>

typedef NS_ENUM(uint8_t, TGStorageDownloadsRowKind) {
	TGStorageDownloadsRowKindClear = 0,
	TGStorageDownloadsRowKindLoading,
	TGStorageDownloadsRowKindEmpty,
	TGStorageDownloadsRowKindMore,
	TGStorageDownloadsRowKindEntry,
};

@interface TGStorageDownloadsItem : NSObject

@property (nonatomic, readonly) TGStorageDownloadsRowKind kind;
@property (nonatomic, readonly, copy) NSString *reuseIdentifier;
@property (nonatomic, readonly) Class cellClass;

@property (nonatomic, readonly, copy) NSString *titleText;
@property (nonatomic, readonly, copy) NSString *detailText;

- (instancetype)initWithKind:(TGStorageDownloadsRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
				   titleText:(NSString *)titleText
				  detailText:(NSString *)detailText NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

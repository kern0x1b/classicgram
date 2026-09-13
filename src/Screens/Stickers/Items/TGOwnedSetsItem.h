#import <UIKit/UIKit.h>

typedef NS_ENUM(uint8_t, TGOwnedSetsRowKind) {
	TGOwnedSetsRowKindCreate = 0,
	TGOwnedSetsRowKindSet,
};

@interface TGOwnedSetsItem : NSObject

@property (nonatomic, readonly) TGOwnedSetsRowKind kind;
@property (nonatomic, readonly, copy) NSString *reuseIdentifier;
@property (nonatomic, readonly) Class cellClass;

@property (nonatomic, readonly, copy) NSString *titleText;
@property (nonatomic, readonly, copy) NSString *countText;
@property (nonatomic, readonly, copy) NSString *thumbnailKey;
@property (nonatomic, readonly) int64_t thumbnailFileId;
@property (nonatomic, readonly, strong) UIImage *thumbnailPlaceholder;

- (instancetype)initWithKind:(TGOwnedSetsRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
				   titleText:(NSString *)titleText
				   countText:(NSString *)countText
				thumbnailKey:(NSString *)thumbnailKey
			 thumbnailFileId:(int64_t)thumbnailFileId
		thumbnailPlaceholder:(UIImage *)thumbnailPlaceholder NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

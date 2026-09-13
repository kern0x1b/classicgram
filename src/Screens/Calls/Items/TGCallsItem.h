#import <UIKit/UIKit.h>

typedef NS_ENUM(uint8_t, TGCallsRowKind) {
	TGCallsRowKindGroup = 0,
};

@interface TGCallsItem : NSObject

@property (nonatomic, readonly) TGCallsRowKind kind;
@property (nonatomic, readonly, copy) NSString *reuseIdentifier;
@property (nonatomic, readonly) Class cellClass;

@property (nonatomic, readonly, copy) NSString *nameText;
@property (nonatomic, readonly, strong) UIColor *nameColour;
@property (nonatomic, readonly, copy) NSString *countText;
@property (nonatomic, readonly, copy) NSString *dateText;
@property (nonatomic, readonly, copy) NSString *subtitleText;
@property (nonatomic, readonly, strong) UIImage *arrowImage;

@property (nonatomic, readonly, copy) NSNumber *avatarKey;
@property (nonatomic, readonly, strong) UIImage *avatarPlaceholder;

- (instancetype)initWithKind:(TGCallsRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
					nameText:(NSString *)nameText
				  nameColour:(UIColor *)nameColour
				   countText:(NSString *)countText
					dateText:(NSString *)dateText
				subtitleText:(NSString *)subtitleText
				  arrowImage:(UIImage *)arrowImage
				   avatarKey:(NSNumber *)avatarKey
		   avatarPlaceholder:(UIImage *)avatarPlaceholder NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

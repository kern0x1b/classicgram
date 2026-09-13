#import <UIKit/UIKit.h>

typedef NS_ENUM(uint8_t, TGSearchRowKind) {
	TGSearchRowKindGeneric = 0,
	TGSearchRowKindMessage,
};

@interface TGSearchResultItem : NSObject

@property (nonatomic, readonly) TGSearchRowKind kind;
@property (nonatomic, readonly, copy) NSString *reuseIdentifier;
@property (nonatomic, readonly) Class cellClass;

@property (nonatomic, readonly, copy) NSString *titleFirst;
@property (nonatomic, readonly, copy) NSString *titleSecond;
@property (nonatomic, readonly, copy) NSString *authorText;
@property (nonatomic, readonly, copy) NSString *subtitleText;
@property (nonatomic, readonly, copy) NSString *dateText;

@property (nonatomic, readonly) int64_t avatarColourId;
@property (nonatomic, readonly, copy) NSString *avatarTitle;
@property (nonatomic, readonly, copy) NSNumber *avatarFileId;
@property (nonatomic, readonly) BOOL avatarIsPrecomputed;
@property (nonatomic, readonly, strong) UIImage *avatarPrecomputed;

- (instancetype)initWithKind:(TGSearchRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
				  titleFirst:(NSString *)titleFirst
				 titleSecond:(NSString *)titleSecond
				  authorText:(NSString *)authorText
				subtitleText:(NSString *)subtitleText
					dateText:(NSString *)dateText
			  avatarColourId:(int64_t)avatarColourId
				 avatarTitle:(NSString *)avatarTitle
				avatarFileId:(NSNumber *)avatarFileId
		 avatarIsPrecomputed:(BOOL)avatarIsPrecomputed
		   avatarPrecomputed:(UIImage *)avatarPrecomputed NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

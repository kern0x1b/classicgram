#import <UIKit/UIKit.h>

typedef NS_ENUM(uint8_t, TGStarsListRowKind) {
	TGStarsListRowKindStatus = 0,
	TGStarsListRowKindValue,
	TGStarsListRowKindSubtitle,
};

@interface TGStarsListItem : NSObject

@property (nonatomic, readonly) TGStarsListRowKind kind;
@property (nonatomic, readonly, copy) NSString *reuseIdentifier;
@property (nonatomic, readonly) Class cellClass;

@property (nonatomic, readonly, copy) NSString *titleText;
@property (nonatomic, readonly, copy) NSString *detailText;
@property (nonatomic, readonly) BOOL destructive;
@property (nonatomic, readonly) BOOL tappable;
@property (nonatomic, readonly) BOOL statusIsLoading;
@property (nonatomic, readonly) BOOL statusIsMore;

- (instancetype)initWithKind:(TGStarsListRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
				   titleText:(NSString *)titleText
				  detailText:(NSString *)detailText
			   isDestructive:(BOOL)isDestructive
				  isTappable:(BOOL)isTappable
			 statusIsLoading:(BOOL)statusIsLoading
				statusIsMore:(BOOL)statusIsMore NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

#import <Foundation/Foundation.h>

typedef NS_ENUM(uint8_t, TGAccountsRowKind) {
	TGAccountsRowKindAccount = 0,
};

@interface TGAccountsItem : NSObject

@property (nonatomic, readonly) TGAccountsRowKind kind;
@property (nonatomic, readonly, copy) NSString *reuseIdentifier;
@property (nonatomic, readonly) Class cellClass;

@property (nonatomic, readonly) NSInteger slot;
@property (nonatomic, readonly) int64_t userId;
@property (nonatomic, readonly, copy) NSString *titleText;
@property (nonatomic, readonly, copy) NSString *subtitleText;
@property (nonatomic, readonly, copy) NSString *initials;
@property (nonatomic, readonly) BOOL current;
@property (nonatomic, readonly) NSInteger unreadCount;

- (instancetype)initWithKind:(TGAccountsRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
						slot:(NSInteger)slot
					  userId:(int64_t)userId
				   titleText:(NSString *)titleText
				subtitleText:(NSString *)subtitleText
					initials:(NSString *)initials
				   isCurrent:(BOOL)isCurrent
				 unreadCount:(NSInteger)unreadCount NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

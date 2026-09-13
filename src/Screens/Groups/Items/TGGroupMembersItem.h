#import <UIKit/UIKit.h>

typedef NS_ENUM(uint8_t, TGGroupMembersRowKind) {
	TGGroupMembersRowKindMember = 0,
};

@interface TGGroupMembersItem : NSObject

@property (nonatomic, readonly) TGGroupMembersRowKind kind;
@property (nonatomic, readonly, copy) NSString *reuseIdentifier;
@property (nonatomic, readonly) Class cellClass;

@property (nonatomic, readonly) long long userId;
@property (nonatomic, readonly, copy) NSString *titleText;
@property (nonatomic, readonly, copy) NSString *subtitleText;
@property (nonatomic, readonly) BOOL subtitleIsOnline;
@property (nonatomic, readonly, copy) NSString *roleText;
@property (nonatomic, readonly, strong) UIImage *avatarPlaceholder;

- (instancetype)initWithKind:(TGGroupMembersRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
					  userId:(long long)userId
				   titleText:(NSString *)titleText
				subtitleText:(NSString *)subtitleText
			subtitleIsOnline:(BOOL)subtitleIsOnline
					roleText:(NSString *)roleText
		   avatarPlaceholder:(UIImage *)avatarPlaceholder NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

#import <Foundation/Foundation.h>

typedef NS_ENUM(uint8_t, TGNewGroupMembersRowKind) {
	TGNewGroupMembersRowKindContact = 0,
};

@interface TGNewGroupMembersItem : NSObject

@property (nonatomic, readonly) TGNewGroupMembersRowKind kind;
@property (nonatomic, readonly, copy) NSString *reuseIdentifier;
@property (nonatomic, readonly) Class cellClass;

@property (nonatomic, readonly) int64_t userId;
@property (nonatomic, readonly, copy) NSString *titleText;
@property (nonatomic, readonly) BOOL selected;

- (instancetype)initWithKind:(TGNewGroupMembersRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
					  userId:(int64_t)userId
				   titleText:(NSString *)titleText
				  isSelected:(BOOL)isSelected NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

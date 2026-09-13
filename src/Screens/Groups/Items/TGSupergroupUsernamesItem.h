#import <Foundation/Foundation.h>

typedef NS_ENUM(uint8_t, TGSupergroupUsernamesRowKind) {
	TGSupergroupUsernamesRowKindUsername = 0,
};

@interface TGSupergroupUsernamesItem : NSObject

@property (nonatomic, readonly) TGSupergroupUsernamesRowKind kind;
@property (nonatomic, readonly, copy) NSString *reuseIdentifier;
@property (nonatomic, readonly) Class cellClass;

@property (nonatomic, readonly, copy) NSString *username;
@property (nonatomic, readonly, copy) NSString *displayText;
@property (nonatomic, readonly, copy) NSString *badgeText;

- (instancetype)initWithKind:(TGSupergroupUsernamesRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
					username:(NSString *)username
				 displayText:(NSString *)displayText
				   badgeText:(NSString *)badgeText NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

#import <Foundation/Foundation.h>

typedef NS_ENUM(uint8_t, TGAccountUsernamesRowKind) {
	TGAccountUsernamesRowKindUsername = 0,
};

@interface TGAccountUsernamesItem : NSObject

@property (nonatomic, readonly) TGAccountUsernamesRowKind kind;
@property (nonatomic, readonly, copy) NSString *reuseIdentifier;
@property (nonatomic, readonly) Class cellClass;

@property (nonatomic, readonly, copy) NSString *username;
@property (nonatomic, readonly, copy) NSString *displayText;
@property (nonatomic, readonly) BOOL showsEditableBadge;

- (instancetype)initWithKind:(TGAccountUsernamesRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
					username:(NSString *)username
				 displayText:(NSString *)displayText
		  showsEditableBadge:(BOOL)showsEditableBadge NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

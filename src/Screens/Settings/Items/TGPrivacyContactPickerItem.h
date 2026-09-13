#import <Foundation/Foundation.h>

typedef NS_ENUM(uint8_t, TGPrivacyContactPickerRowKind) {
	TGPrivacyContactPickerRowKindContact = 0,
};

@interface TGPrivacyContactPickerItem : NSObject

@property (nonatomic, readonly) TGPrivacyContactPickerRowKind kind;
@property (nonatomic, readonly, copy) NSString *reuseIdentifier;
@property (nonatomic, readonly) Class cellClass;

@property (nonatomic, readonly) int64_t userId;
@property (nonatomic, readonly, copy) NSString *titleText;
@property (nonatomic, readonly) BOOL chosen;

- (instancetype)initWithKind:(TGPrivacyContactPickerRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
					  userId:(int64_t)userId
				   titleText:(NSString *)titleText
					isChosen:(BOOL)isChosen NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

#import <UIKit/UIKit.h>

typedef NS_ENUM(uint8_t, TGProfileDetailRowKind) {
	TGProfileDetailRowKindPlain = 0,
};

@interface TGProfileDetailItem : NSObject

@property (nonatomic, readonly) TGProfileDetailRowKind kind;
@property (nonatomic, readonly, copy) NSString *reuseIdentifier;
@property (nonatomic, readonly) Class cellClass;

@property (nonatomic, readonly, copy) NSString *labelText;
@property (nonatomic, readonly, copy) NSString *valueText;
@property (nonatomic, readonly, strong) UIColor *valueTextColor;
@property (nonatomic, readonly) BOOL showsDisclosure;
@property (nonatomic, readonly) BOOL selectable;
@property (nonatomic, readonly) BOOL interactionEnabled;

- (instancetype)initWithKind:(TGProfileDetailRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
				   labelText:(NSString *)labelText
				   valueText:(NSString *)valueText
			  valueTextColor:(UIColor *)valueTextColor
			 showsDisclosure:(BOOL)showsDisclosure
				isSelectable:(BOOL)isSelectable
		  interactionEnabled:(BOOL)interactionEnabled NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

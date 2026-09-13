#import <Foundation/Foundation.h>

typedef NS_ENUM(uint8_t, TGStoryViewersRowKind) {
	TGStoryViewersRowKindViewer = 0,
};

@interface TGStoryViewersItem : NSObject

@property (nonatomic, readonly) TGStoryViewersRowKind kind;
@property (nonatomic, readonly, copy) NSString *reuseIdentifier;
@property (nonatomic, readonly) Class cellClass;

@property (nonatomic, readonly, copy) NSString *titleText;
@property (nonatomic, readonly, copy) NSString *detailText;

- (instancetype)initWithKind:(TGStoryViewersRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
				   titleText:(NSString *)titleText
				  detailText:(NSString *)detailText NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

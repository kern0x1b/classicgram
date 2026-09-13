#import <UIKit/UIKit.h>

@class TGViewRecycler;

@protocol TGReusableView <NSObject>

- (NSString *)reuseIdentifier;

- (void)prepareForReuse;
- (void)prepareForRecycle:(TGViewRecycler *)recycler;

@end

@interface TGReusableView : UIView <TGReusableView>

@property (nonatomic, strong) NSString *reuseIdentifier;

@end

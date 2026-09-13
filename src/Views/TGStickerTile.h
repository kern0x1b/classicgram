#import <UIKit/UIKit.h>
#import "TGReusableView.h"

@class TGViewRecycler;

@interface TGStickerTile : UIControl <TGReusableView>

@property (nonatomic, strong) NSString *reuseIdentifier;
@property (nonatomic, strong) UIImageView *pressPlate;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UILabel *emojiLabel;
@property (nonatomic, strong) NSDictionary *sticker;
@property (nonatomic, assign) NSInteger sectionIndex;
@property (nonatomic, assign) NSInteger itemIndex;
@property (nonatomic, strong) NSString *imageKey;
@property (nonatomic, strong) id imageToken;

@end

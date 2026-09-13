#import <UIKit/UIKit.h>
#import "TGEmoji.h"

@interface TGReactionChipView : UIControl

@property (nonatomic, strong) UIImageView *plateView;
@property (nonatomic, strong) TGEmojiLabel *emojiLabel;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UILabel *tagLabelView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, copy) NSString *emoji;
@property (nonatomic, copy) NSString *tagLabel;
@property (nonatomic, assign) BOOL chosen;
@property (nonatomic, assign) BOOL custom;

@end

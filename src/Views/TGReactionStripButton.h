#import <UIKit/UIKit.h>
#import "TGEmoji.h"

@interface TGReactionStripButton : UIButton

@property (nonatomic, strong) UIImageView *leftView;
@property (nonatomic, strong) UIImageView *centerView;
@property (nonatomic, strong) UIImageView *rightView;
@property (nonatomic, strong) TGEmojiLabel *emojiLabel;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *tagLabelView;
@property (nonatomic, copy) NSString *emoji;
@property (nonatomic, copy) NSString *tagLabel;
@property (nonatomic, assign) BOOL paid;

@end

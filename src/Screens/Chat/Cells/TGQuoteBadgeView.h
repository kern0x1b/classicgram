#import <UIKit/UIKit.h>
#import "TGEmoji.h"

@interface TGQuoteBadgeView : UIView

@property (nonatomic, strong, readonly) UIView *bar;
@property (nonatomic, strong, readonly) TGEmojiLabel *authorLabel;
@property (nonatomic, strong, readonly) TGEmojiLabel *textLabel;
@property (nonatomic, strong, readonly) UIImageView *thumbnail;
@property (nonatomic, strong, readonly) UIButton *tapTarget;

- (void)layoutWithBarFrame:(CGRect)barFrame
			   authorFrame:(CGRect)authorFrame
				 textFrame:(CGRect)textFrame
			thumbnailFrame:(CGRect)thumbnailFrame
			tapTargetFrame:(CGRect)tapTargetFrame;

@end

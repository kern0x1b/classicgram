#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>

@class TGRichTextLayout;

BOOL TGEmojiTextNeedsSubstitution(NSString *text);

CGSize TGEmojiTextSize(NSString *text, UIFont *font, CGSize limit,
	NSLineBreakMode mode, NSInteger maxLines);

void TGEmojiTextDraw(NSString *text, UIFont *font, UIColor *colour, CGRect rect,
	NSTextAlignment alignment, NSInteger maxLines);

NSAttributedString *TGEmojiSubstituteInString(NSAttributedString *source);

void TGEmojiDrawImagesInLine(CTLineRef line, CGFloat left, CGFloat baseline);

void TGEmojiLogHealthOnce(void);

UIFont *TGEmojiFontOfSize(CGFloat size);

@interface TGEmojiLabel : UILabel

@property (nonatomic, strong) TGRichTextLayout *richLayout;

@end

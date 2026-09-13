#import <UIKit/UIKit.h>

void TGRichTextSetCustomEmojiImageProvider(UIImage * (^provider)(long long customEmojiId));
void TGRichTextSetCustomEmojiImageRequester(void (^requester)(long long customEmojiId));
UIImage *TGRichTextCustomEmojiImage(long long customEmojiId);
void TGRichTextRequestCustomEmojiImage(long long customEmojiId);
#import <CoreText/CoreText.h>

extern NSString *const TGRichLinkAttribute;
extern NSString *const TGRichSpoilerAttribute;
extern NSString *const TGRichBlockAttribute;
extern NSString *const TGRichStrikeAttribute;
extern NSString *const TGRichCodeAttribute;
extern NSString *const TGRichCustomEmojiAttribute;

extern NSString *const TGRichLinkKindKey;
extern NSString *const TGRichLinkValueKey;

@interface TGRichTextPalette : NSObject

@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) UIColor *textColour;
@property (nonatomic, strong) UIColor *linkColour;
@property (nonatomic, strong) UIColor *accentColour;
@property (nonatomic, strong) UIColor *codeBackgroundColour;
@property (nonatomic, assign) BOOL underlineLinks;

+ (TGRichTextPalette *)paletteWithFont:(UIFont *)font
								colour:(UIColor *)colour
							linkColour:(UIColor *)linkColour
						  accentColour:(UIColor *)accentColour;

@end

NSAttributedString *TGRichTextBuild(NSString *text, NSArray *entities,
	TGRichTextPalette *palette,
	BOOL spoilersRevealed);

@interface TGRichTextLayout : NSObject

+ (TGRichTextLayout *)layoutWithText:(NSAttributedString *)text
							   width:(CGFloat)width
							maxLines:(NSInteger)maxLines
						   alignment:(NSTextAlignment)alignment
					  expandedBlocks:(NSSet *)expandedBlocks;

@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) BOOL carriesSpoilers;
@property (nonatomic, readonly) BOOL carriesCollapsedBlocks;

- (void)drawInRect:(CGRect)rect;

- (NSDictionary *)linkAtPoint:(CGPoint)point inRect:(CGRect)rect;

- (NSUInteger)stringIndexAtPoint:(CGPoint)point inRect:(CGRect)rect;

- (NSArray *)rectsForRange:(NSRange)range inRect:(CGRect)rect;

- (BOOL)spoilerAtPoint:(CGPoint)point inRect:(CGRect)rect;

- (NSNumber *)collapsibleBlockAtPoint:(CGPoint)point inRect:(CGRect)rect;

@end

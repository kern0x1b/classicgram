#import <UIKit/UIKit.h>

@class TGRichTextLayout;

typedef NS_ENUM(uint8_t, TGInstantViewRowKind) {
	TGInstantViewRowKindDivider = 0,
	TGInstantViewRowKindMedia,
	TGInstantViewRowKindUnsupported,
	TGInstantViewRowKindText,
};

@interface TGInstantViewItem : NSObject

@property (nonatomic, readonly) TGInstantViewRowKind kind;
@property (nonatomic, readonly, copy) NSString *reuseIdentifier;
@property (nonatomic, readonly) Class cellClass;
@property (nonatomic, readonly) CGFloat height;

@property (nonatomic, readonly) BOOL barHidden;
@property (nonatomic, readonly) CGRect barFrame;
@property (nonatomic, readonly) UIColor *barColour;

@property (nonatomic, readonly) long long photoFileId;
@property (nonatomic, readonly) CGRect pictureFrame;
@property (nonatomic, readonly) UIColor *pictureEmptyColour;

@property (nonatomic, readonly) BOOL captionHidden;
@property (nonatomic, readonly, copy) NSString *captionText;
@property (nonatomic, readonly) CGRect captionFrame;

@property (nonatomic, readonly) BOOL bodyHidden;
@property (nonatomic, readonly, copy) NSString *bodyText;
@property (nonatomic, readonly, strong) UIFont *bodyFont;
@property (nonatomic, readonly, strong) UIColor *bodyTextColour;
@property (nonatomic, readonly, strong) UIColor *bodyBackgroundColour;
@property (nonatomic, readonly) CGRect bodyFrame;
@property (nonatomic, readonly, strong) TGRichTextLayout *bodyRichLayout;

@property (nonatomic, readonly, strong) UIColor *cellBackgroundColour;

- (instancetype)initWithKind:(TGInstantViewRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
					  height:(CGFloat)height
				   barHidden:(BOOL)barHidden
					barFrame:(CGRect)barFrame
				   barColour:(UIColor *)barColour
				 photoFileId:(long long)photoFileId
				pictureFrame:(CGRect)pictureFrame
		  pictureEmptyColour:(UIColor *)pictureEmptyColour
			   captionHidden:(BOOL)captionHidden
				 captionText:(NSString *)captionText
				captionFrame:(CGRect)captionFrame
				  bodyHidden:(BOOL)bodyHidden
					bodyText:(NSString *)bodyText
					bodyFont:(UIFont *)bodyFont
			  bodyTextColour:(UIColor *)bodyTextColour
		bodyBackgroundColour:(UIColor *)bodyBackgroundColour
				   bodyFrame:(CGRect)bodyFrame
			  bodyRichLayout:(TGRichTextLayout *)bodyRichLayout
		cellBackgroundColour:(UIColor *)cellBackgroundColour NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

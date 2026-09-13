#import "TGInstantViewItem.h"

@implementation TGInstantViewItem

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
		cellBackgroundColour:(UIColor *)cellBackgroundColour {
	self = [super init];
	if (!self)
		return nil;

	_kind = kind;
	_reuseIdentifier = [reuseIdentifier copy];
	_cellClass = cellClass;
	_height = height;
	_barHidden = barHidden;
	_barFrame = barFrame;
	_barColour = barColour;
	_photoFileId = photoFileId;
	_pictureFrame = pictureFrame;
	_pictureEmptyColour = pictureEmptyColour;
	_captionHidden = captionHidden;
	_captionText = [captionText copy];
	_captionFrame = captionFrame;
	_bodyHidden = bodyHidden;
	_bodyText = [bodyText copy];
	_bodyFont = bodyFont;
	_bodyTextColour = bodyTextColour;
	_bodyBackgroundColour = bodyBackgroundColour;
	_bodyFrame = bodyFrame;
	_bodyRichLayout = bodyRichLayout;
	_cellBackgroundColour = cellBackgroundColour;

	return self;
}

@end

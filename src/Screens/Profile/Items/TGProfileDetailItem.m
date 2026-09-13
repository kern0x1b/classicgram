#import "TGProfileDetailItem.h"

@implementation TGProfileDetailItem

- (instancetype)initWithKind:(TGProfileDetailRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
				   labelText:(NSString *)labelText
				   valueText:(NSString *)valueText
			  valueTextColor:(UIColor *)valueTextColor
			 showsDisclosure:(BOOL)showsDisclosure
				isSelectable:(BOOL)isSelectable
		  interactionEnabled:(BOOL)interactionEnabled {
	self = [super init];
	if (!self)
		return nil;

	_kind = kind;
	_reuseIdentifier = [reuseIdentifier copy];
	_cellClass = cellClass;
	_labelText = [labelText copy] ?: @"";
	_valueText = [valueText copy] ?: @"";
	_valueTextColor = valueTextColor;
	_showsDisclosure = showsDisclosure;
	_selectable = isSelectable;
	_interactionEnabled = interactionEnabled;
	return self;
}

@end

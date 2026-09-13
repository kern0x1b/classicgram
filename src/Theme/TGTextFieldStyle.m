#import "TGTextFieldStyle.h"
#import "TGHexColour.h"
#import "TGTheme.h"

UIColor *TGTextFieldPlaceholderColour(void) {
	return TGColourFromHex(0x8d98a6);
}

UIFont *TGTextFieldFont(void) {
	return [UIFont boldSystemFontOfSize:16];
}

static void TGPaintPlaceholder(UITextField *field, UIColor *colour) {
	NSString *placeholder = field.placeholder;
	if (!placeholder.length)
		return;
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	[attributes setObject:colour forKey:NSForegroundColorAttributeName];
	if (field.font)
		[attributes setObject:field.font forKey:NSFontAttributeName];
	field.attributedPlaceholder = [[NSAttributedString alloc]
			initWithString:placeholder
				attributes:attributes];
}

void TGStyleTextField(UITextField *field) {
	if (![field isKindOfClass:[UITextField class]])
		return;
	field.textColor = [[TGTheme shared] primaryTextColour];
	field.borderStyle = UITextBorderStyleNone;
	TGPaintPlaceholder(field, TGTextFieldPlaceholderColour());
}

void TGStyleTextFieldOverDarkness(UITextField *field) {
	if (![field isKindOfClass:[UITextField class]])
		return;
	field.textColor = [UIColor whiteColor];
	field.borderStyle = UITextBorderStyleNone;
	TGPaintPlaceholder(field, [UIColor colorWithWhite:1.0f alpha:0.6f]);
}

void TGStyleSearchField(UITextField *field) {
	if (![field isKindOfClass:[UITextField class]])
		return;
	field.borderStyle = UITextBorderStyleNone;
	TGPaintPlaceholder(field, TGColourFromHex(0x8d9298));
}

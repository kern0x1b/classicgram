#import "tg_text_field_style_tests.h"

#import "../../src/Theme/TGTextFieldStyle.h"

#import <Foundation/Foundation.h>

TGTestOutcome TGTextFieldStyleTestThePlaceholderIsTheOriginalsGrey(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	UIColor *colour = TGTextFieldPlaceholderColour();
	CGFloat red = 0, green = 0, blue = 0, alpha = 0;
	[colour getRed:&red green:&green blue:&blue alpha:&alpha];

	TGTestExpectTrue(&outcome, (int)(red * 255.0f + 0.5f) == 0x8d,
			"the placeholder is the 0x8d98a6 of the original, which the 2013 client forced "
			"because the system grey was too pale against a white plate");
	TGTestExpectTrue(&outcome, (int)(green * 255.0f + 0.5f) == 0x98,
			"green matches");
	TGTestExpectTrue(&outcome, (int)(blue * 255.0f + 0.5f) == 0xa6,
			"blue matches");
	TGTestExpectTrue(&outcome, alpha == 1.0f,
			"and it is opaque");

	return outcome;
}

TGTestOutcome TGTextFieldStyleTestTheFormFontIsOne(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	UIFont *font = TGTextFieldFont();

	TGTestExpectTrue(&outcome, font.pointSize == 16.0f,
			"a field in a form is bold 16 as the original's name fields were, not the 16 and 17 "
			"the screens each chose");
	TGTestExpectTrue(&outcome, font.isBold,
			"and it is the bold weight, which is what the name field of the original used");

	return outcome;
}

TGTestOutcome TGTextFieldStyleTestAFieldWithNothingInIt(void) {
	TGTestOutcome outcome = TGTestOutcomeZero;

	UITextField *field = [[UITextField alloc] init];
	field.borderStyle = UITextBorderStyleRoundedRect;
	TGStyleTextField(field);

	TGTestExpectTrue(&outcome, field.borderStyle == UITextBorderStyleNone,
			"no field in this app wears the system's rounded rectangle");
	TGTestExpectTrue(&outcome, field.attributedPlaceholder == nil,
			"a field with no placeholder is given no empty one to draw");

	UITextField *named = [[UITextField alloc] init];
	named.placeholder = @"Folder Name";
	named.font = TGTextFieldFont();
	TGStyleTextField(named);

	NSDictionary *attributes = [named.attributedPlaceholder attributesAtIndex:0 effectiveRange:NULL];

	UIColor *painted = attributes[NSForegroundColorAttributeName];
	CGFloat paintedRed = 0, expectedRed = 0;
	[painted getRed:&paintedRed green:NULL blue:NULL alpha:NULL];
	[TGTextFieldPlaceholderColour() getRed:&expectedRed green:NULL blue:NULL alpha:NULL];

	TGTestExpectTrue(&outcome, painted != nil && paintedRed == expectedRed,
			"a placeholder is repainted in the app's own grey");
	TGTestExpectTrue(&outcome, attributes[NSFontAttributeName] == named.font,
			"and keeps the font the field was given, so the grey text is not a different size "
			"from what is typed over it");

	return outcome;
}

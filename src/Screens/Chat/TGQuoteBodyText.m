#import "TGQuoteBodyText.h"

#import "TGLocalization.h"

NSString *TGQuoteBodyText(NSString *inlineFragment,
	NSString *fetchedText,
	BOOL originalMissing) {
	if ([inlineFragment isKindOfClass:NSString.class] && [inlineFragment length])
		return inlineFragment;
	if (originalMissing)
		return TGL(@"Message.DeletedMessage", @"Deleted message");
	if ([fetchedText isKindOfClass:NSString.class] && [fetchedText length])
		return fetchedText;
	return @"...";
}

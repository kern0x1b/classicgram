#import "TGFailedMessageTitle.h"

#import "TGFriendlyError.h"
#import "TGLocalization.h"

NSString *TGFailedMessageTitle(NSString *sendErrorMessage) {
	NSString *fallback = TGL(@"Conversation.MessageDeliveryFailed", @"This message was not sent");
	if (![sendErrorMessage isKindOfClass:[NSString class]] || !sendErrorMessage.length)
		return fallback;
	return TGFriendlyErrorText(sendErrorMessage, fallback);
}

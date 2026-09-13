#import <Foundation/Foundation.h>

NSRange TGMentionTriggerRangeInText(NSString *text, NSUInteger caret);

NSRange TGInlineBotUsernameRangeInText(NSString *text);

NSRange TGInlineBotQueryRangeInText(NSString *text, NSUInteger caret);

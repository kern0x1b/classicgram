#import <Foundation/Foundation.h>

NSRange TGQuickReplyTriggerRangeInText(NSString *text, NSUInteger caret);

NSArray *TGQuickReplyMatches(NSArray *shortcuts, NSString *query);

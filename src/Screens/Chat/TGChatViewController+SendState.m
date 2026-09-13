#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+Messages.h"
#import "TGIcons.h"
#import "TGTheme.h"

@implementation TGChatViewController (SendState)

- (NSString *)sendStateForMessage:(NSDictionary *)m {
	if (![m[@"id"] isKindOfClass:NSNumber.class] || ![m[@"outgoing"] boolValue])
		return @"sent";
	NSNumber *messageId = m[@"id"];
	NSString *known = self.sendStates[messageId];
	if (known)
		return known;

	NSString *carried = [m[@"sendState"] isKindOfClass:NSString.class]
		? m[@"sendState"]
		: nil;
	if (carried.length)
		return carried;

	if ([self.sendStatesRequested containsObject:messageId])
		return @"sent";

	[self.sendStatesRequested addObject:messageId];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] sendingStateOfMessage:[messageId longLongValue]
									  inChat:self.chatId
								  completion:^(NSString *state, BOOL canRetry) {
									  TGChatViewController *strongSelf = weakSelf;
									  if (!strongSelf || !state.length)
										  return;
									  NSString *before = strongSelf.sendStates[messageId];
									  strongSelf.sendStates[messageId] = state;
									  if (!before && ![state isEqualToString:@"sent"]) {
										  [strongSelf tg_invalidateLayoutForMessageId:messageId.longLongValue];
										  [strongSelf.table reloadData];
									  }
								  }];
	return @"sent";
}

- (BOOL)canResendMessage:(NSDictionary *)m {
	if (![[self sendStateForMessage:m] isEqualToString:@"failed"])
		return NO;
	return [m[@"canRetry"] boolValue];
}

@end

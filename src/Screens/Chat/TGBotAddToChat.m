#import "TGBotAddToChat.h"
#import "TGBotAdminRights.h"
#import "TGBotService.h"
#import "TGChatIdPickerViewController.h"
#import "TGLocalization.h"
#import "TGTheme.h"

@implementation TGBotAddToChat

+ (void)presentForLink:(NSString *)link
		fromController:(UIViewController *)owner
			completion:(void (^)(int64_t chatId, NSString *errorCode))completion {
	if (!link.length || owner == nil) {
		if (completion)
			completion(0, @"notFound");
		return;
	}

	[TGBotService botStartLinkInfo:link completion:^(NSDictionary *info) {
		BOOL channel = [info[@"inChannel"] boolValue];
		if (!info || !(channel || [info[@"inGroup"] boolValue])) {
			if (completion)
				completion(0, @"notFound");
			return;
		}
		NSDictionary *rights = [info[@"administratorRights"] isKindOfClass:NSDictionary.class]
			? info[@"administratorRights"]
			: @{};
		NSString *parameter = [info[@"parameter"] isKindOfClass:NSString.class]
			? info[@"parameter"]
			: @"";

		[TGBotService resolveBotForUsername:info[@"username"] completion:^(int64_t botUserId) {
			if (botUserId == 0) {
				if (completion)
					completion(0, @"notFound");
				return;
			}
			[TGBotService chatsAcceptingBots:channel completion:^(NSArray *chats) {
				if (!chats.count) {
					if (completion)
						completion(0, @"noChats");
					return;
				}
				[self presentPickerForChats:chats
								  botUserId:botUserId
						administratorRights:rights
								  parameter:parameter
							 fromController:owner
								 completion:completion];
			}];
		}];
	}];
}

+ (void)presentPickerForChats:(NSArray *)chats
					botUserId:(int64_t)botUserId
		  administratorRights:(NSDictionary *)rights
					parameter:(NSString *)parameter
			   fromController:(UIViewController *)owner
				   completion:(void (^)(int64_t chatId, NSString *errorCode))completion {
	NSMutableArray *chatIds = [NSMutableArray array];
	NSMutableDictionary *titles = [NSMutableDictionary dictionary];
	for (NSDictionary *chat in chats) {
		NSNumber *chatId = chat[@"chatId"];
		if (![chatId isKindOfClass:NSNumber.class])
			continue;
		[chatIds addObject:chatId];
		titles[chatId] = [chat[@"title"] isKindOfClass:NSString.class] ? chat[@"title"] : @"";
	}

	TGChatIdPickerViewController *picker = [[TGChatIdPickerViewController alloc] init];
	picker.chatIds = [chatIds copy];
	picker.titles = [titles copy];
	picker.singleSelection = YES;
	picker.title = TGBotAdminRightsRequested(rights)
		? TGL(@"Bot.AddAsAdmin", @"Add as Admin")
		: TGL(@"Bot.AddToChat", @"Add Bot");
	picker.prompt = TGL(@"Bot.AddToChatPrompt", @"Choose where to add this bot");
	picker.onConfirm = ^(NSArray *picked) {
		NSNumber *chosen = picked.firstObject;
		if (![chosen isKindOfClass:NSNumber.class]) {
			if (completion)
				completion(0, @"cancelled");
			return;
		}
		[TGBotService addBot:botUserId
					  toChat:[chosen longLongValue]
		 administratorRights:rights
				   parameter:parameter
				  completion:completion];
	};

	UINavigationController *navigation = owner.navigationController;
	if (navigation != nil) {
		[navigation pushViewController:picker animated:YES];
		return;
	}

	UINavigationController *wrapper =
		[[UINavigationController alloc] initWithRootViewController:picker];
	[[TGTheme shared] styleNavigationBar:wrapper.navigationBar];
	if ([owner respondsToSelector:@selector(presentViewController:animated:completion:)])
		[owner presentViewController:wrapper animated:YES completion:nil];
	else
		[owner presentModalViewController:wrapper animated:YES];
}

@end

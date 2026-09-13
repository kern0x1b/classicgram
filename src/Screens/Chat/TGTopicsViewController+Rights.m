#import "TGTopicsViewController.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGChatViewController.h"
#import "TGClient.h"
#import "TGClient+ChatManagement.h"
#import "TGClient+Groups.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGActionSheet.h"
#import "TGPopupMenu.h"
#import "TGDateUtils.h"
#import "TGDateLabel.h"
#import "UIView+SafeTint.h"
#import <QuartzCore/QuartzCore.h>
#import "TGAlertView.h"

#import "TGTopicsViewControllerInternal.h"

@implementation TGTopicsViewController (Rights)

#pragma mark - rights

- (void)loadRights {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] myRightsInChat:self.chatId completion:^(NSDictionary *rights) {
		TGTopicsViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;

		BOOL owner = TGTopicFlag(rights, @"isOwner");
		BOOL manage = owner || TGTopicFlag(rights, @"canManageTopics");
		strongSelf.canManageTopics = manage;
		strongSelf.canPinMessages = owner || TGTopicFlag(rights, @"canPinMessages");
		strongSelf.canDeleteTopics = owner || TGTopicFlag(rights, @"canDeleteMessages");

		if (manage) {
			strongSelf.canCreateTopics = YES;
			strongSelf.rightsLoaded = YES;
			[strongSelf updateCreateButton];
			return;
		}

		int64_t myId = [[TGClient shared].me[@"id"] longLongValue];
		[[TGClient shared] permissionsOfUser:myId
									  inGroup:strongSelf.chatId
								   completion:^(NSDictionary *permissions, BOOL isRestricted, NSInteger untilDate) {
									   TGTopicsViewController *innerSelf = weakSelf;
									   if (!innerSelf)
										   return;
									   innerSelf.canCreateTopics = [permissions[@"can_create_topics"] boolValue];
									   innerSelf.rightsLoaded = YES;
									   [innerSelf updateCreateButton];
								   }];
	}];
}

- (void)updateCreateButton {
	if (self.reordering)
		return;

	if (!self.canCreateTopics) {
		self.navigationItem.rightBarButtonItem = nil;
		return;
	}

	UIButton *create = [TGIcons headerButtonWithTitle:TGL(@"ChatList.ContextMenuBadgeNew", @"New") bold:NO
											   target:self
											   action:@selector(newTopicPressed)];
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:create];
}

- (BOOL)canEditTopic:(NSDictionary *)topic {
	if (self.canManageTopics)
		return YES;
	return TGTopicFlag(topic, @"isOutgoing");
}

- (BOOL)canDeleteTopic:(NSDictionary *)topic {
	if (self.canDeleteTopics)
		return YES;
	return TGTopicFlag(topic, @"isOutgoing");
}

@end

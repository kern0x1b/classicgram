#import "TGClient+Contacts.h"
#import "TGGroupInviteLinkOffer.h"
#import "TGClient+Groups.h"
#import "TGClient+Messages.h"
#import "TGLocalization.h"
#import "TGAlertView.h"

static NSString *TGRestrictedUsersOfferMessage(NSArray *userIds, NSDictionary *namesByUserId, BOOL available) {
	if (userIds.count == 1) {
		NSString *name = [namesByUserId objectForKey:[userIds objectAtIndex:0]] ?: @"";
		NSString *format = available
			? TGL(@"SendInviteLink.TextAvailableSingleUser", @"%@ restricts adding them to groups.\nYou can send them an invite link as message instead.")
			: TGL(@"SendInviteLink.TextUnavailableSingleUser", @"%@ can only be invited via an invite link.\nHowever the admin of this group restricts you from sharing invite links.");
		return [NSString stringWithFormat:format, name];
	}
	return available
		? TGLPlural(@"SendInviteLink.TextAvailableMultipleUsers", (NSInteger)userIds.count,
			@"%d user restricts adding them to groups.\nYou can send them an invite link as message instead.",
			@"%d users restrict adding them to groups.\nYou can send them an invite link as message instead.")
		: TGLPlural(@"SendInviteLink.TextUnavailableMultipleUsers", (NSInteger)userIds.count,
			@"%d user can only be invited via an invite link.\nHowever the admin of this group restricts you from sharing invite links.",
			@"%d users can only be invited via an invite link.\nHowever the admin of this group restricts you from sharing invite links.");
}

static void TGSendInviteLinkToUsers(NSString *link, NSArray *userIds) {
	TGClient *client = [TGClient shared];
	for (NSNumber *userId in userIds) {
		[client privateChatWithUser:[userId longLongValue] completion:^(int64_t chatId) {
			if (!chatId)
				return;
			[client sendText:link toChat:chatId thread:0 savedTopic:0 replyTo:0 options:nil completion:nil];
		}];
	}
}

void TGOfferInviteLinkToRestrictedUsers(UIViewController *presenter,
										 int64_t chatId,
										 NSArray *userIds,
										 NSDictionary *namesByUserId,
										 void (^completion)(void)) {
	__weak UIViewController *weakPresenter = presenter;
	[[TGClient shared] primaryInviteLinkForGroup:chatId completion:^(NSDictionary *link) {
		if (!weakPresenter)
			return;
		NSString *url = [link[@"link"] isKindOfClass:NSString.class] ? link[@"link"] : nil;
		BOOL available = url.length > 0;
		NSString *message = TGRestrictedUsersOfferMessage(userIds, namesByUserId, available);
		if (!available) {
			[[[UIAlertView alloc] initWithTitle:TGL(@"SendInviteLink.LinkUnavailableTitle", @"You can't create a link")
										message:message
									   delegate:nil
							  cancelButtonTitle:TGL(@"SendInviteLink.ActionClose", @"Close")
							  otherButtonTitles:nil] show];
			if (completion)
				completion();
			return;
		}
		TGAlertView *offer = [[TGAlertView alloc]
				initWithTitle:TGL(@"SendInviteLink.InviteTitle", @"Invite via Link")
					  message:message
			cancelButtonTitle:TGL(@"SendInviteLink.ActionSkip", @"Skip")
				okButtonTitle:TGL(@"SendInviteLink.ActionInvite", @"Send Invite Link")
			  completionBlock:^(bool okPressed) {
				  if (okPressed)
					  TGSendInviteLinkToUsers(url, userIds);
				  if (completion)
					  completion();
			  }];
		[offer show];
	}];
}

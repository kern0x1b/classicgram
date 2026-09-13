#import "TGInviteLinksViewController.h"
#import "TGQRCodeViewController.h"
#import "TGInviteLinksViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGInviteLinkService.h"
#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "TGForwardPicker.h"
#import "TGSnackbar.h"

@implementation TGInviteLinksViewController (LinkActions)

#pragma mark - link actions

- (void)copyLink:(NSString *)link {
	if (!link.length)
		return;
	[[UIPasteboard generalPasteboard] setString:link];
}

- (void)shareLink:(NSString *)link {
	if (!link.length)
		return;
	TGForwardPicker *picker = [[TGForwardPicker alloc] init];
	__weak typeof(self) weakSelf = self;
	NSString *text = link;
	picker.onPicked = ^(NSArray *chatIds) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		__block BOOL reported = NO;
		for (NSNumber *chatId in chatIds) {
			if ([chatId longLongValue] == 0)
				continue;
			[TGInviteLinkService sendInviteLinkText:text
											 toChat:[chatId longLongValue]
										 completion:^(BOOL ok) {
				__strong typeof(weakSelf) innerSelf = weakSelf;
				if (!innerSelf || ok || reported)
					return;
				reported = YES;
				[TGSnackbar showInView:innerSelf.view
								  text:TGL(@"Toast.CouldNotSendLink", @"Could not send the link")
							   seconds:2
							  onCommit:nil];
			}];
		}
		[strongSelf dismissViewControllerAnimated:YES completion:nil];
	};
	UINavigationController *navigation =
		[[UINavigationController alloc] initWithRootViewController:picker];
	[self presentViewController:navigation animated:YES completion:nil];
}

- (void)showSheetForPrimaryLink {
	NSString *link = self.primaryLink;
	if (!link.length)
		return;

	NSMutableArray *actions = [NSMutableArray array];
	TGActionSheetAction *sheetAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"GroupInfo.InviteLink.CopyLink", @"Copy Link") action:@"copy"];
	[actions addObject:sheetAction];
	sheetAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"GroupInfo.InviteLink.ShareLink", @"Share Link") action:@"share"];
	[actions addObject:sheetAction];
	sheetAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"PeerInfo.QRCode.Title", @"QR Code") action:@"qr"];
	[actions addObject:sheetAction];
	if (self.canManage) {
		sheetAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"GroupInfo.InviteLink.RevokeLink", @"Revoke Link") action:@"revoke" type:TGActionSheetActionTypeDestructive];
		[actions addObject:sheetAction];
	}
	sheetAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"Common.Cancel", @"Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel];
	[actions addObject:sheetAction];

	__weak typeof(self) weakSelf = self;
	TGActionSheet *sheet = [[TGActionSheet alloc]
		initWithTitle:[self shortLink:link]
			  actions:actions
		  actionBlock:^(__unused id target, NSString *action) {
			  __strong typeof(weakSelf) strongSelf = weakSelf;
			  strongSelf.currentActionSheet = nil;
			  if ([action isEqualToString:@"copy"])
				  [strongSelf copyLink:link];
			  else if ([action isEqualToString:@"share"])
				  [strongSelf shareLink:link];
			  else if ([action isEqualToString:@"qr"])
				  [strongSelf showQRCodeForLink:link expiresAt:0];
			  else if ([action isEqualToString:@"revoke"])
				  [strongSelf replacePrimaryLink];
		  }
			   target:self];
	self.currentActionSheet = sheet;
	UIView *presentationHost = [self sheetHostView];
	[self.currentActionSheet tg_showFromRect:CGRectMake(CGRectGetMidX(presentationHost.bounds), CGRectGetMidY(presentationHost.bounds), 1, 1)
									   inView:presentationHost];
}

- (void)showSheetForLink:(NSDictionary *)link revoked:(BOOL)revoked {
	if (!link)
		return;
	NSString *url = link[@"link"];
	if (![url isKindOfClass:[NSString class]])
		url = @"";
	self.pendingLink = link;

	NSMutableArray *actions = [NSMutableArray array];
	TGActionSheetAction *sheetAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"GroupInfo.InviteLink.CopyLink", @"Copy Link") action:@"copy"];
	[actions addObject:sheetAction];
	if (!revoked) {
		sheetAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"GroupInfo.InviteLink.ShareLink", @"Share Link") action:@"share"];
		[actions addObject:sheetAction];
		sheetAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"PeerInfo.QRCode.Title", @"QR Code") action:@"qr"];
		[actions addObject:sheetAction];
	}
	if (!revoked && self.canManage) {
		sheetAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"InviteLink.Create.EditTitle", @"Edit Link") action:@"edit"];
		[actions addObject:sheetAction];
	}
	if (self.canManage) {
		NSString *revokeTitle = revoked ? TGL(@"Business.Links.DeleteItemConfirmationAction", @"Delete Link") : TGL(@"GroupInfo.InviteLink.RevokeLink", @"Revoke Link");
		NSString *revokeAction = revoked ? @"delete" : @"revoke";
		sheetAction = [[TGActionSheetAction alloc] initWithTitle:revokeTitle action:revokeAction type:TGActionSheetActionTypeDestructive];
		[actions addObject:sheetAction];
	}
	sheetAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"Common.Cancel", @"Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel];
	[actions addObject:sheetAction];

	__weak typeof(self) weakSelf = self;
	TGActionSheet *sheet = [[TGActionSheet alloc]
		initWithTitle:[self shortLink:url]
			  actions:actions
		  actionBlock:^(__unused id target, NSString *action) {
			  __strong typeof(weakSelf) strongSelf = weakSelf;
			  strongSelf.currentActionSheet = nil;
			  NSDictionary *pending = strongSelf.pendingLink;
			  strongSelf.pendingLink = nil;
			  if ([action isEqualToString:@"copy"])
				  [strongSelf copyLink:url];
			  else if ([action isEqualToString:@"share"])
				  [strongSelf shareLink:url];
			  else if ([action isEqualToString:@"qr"])
				  [strongSelf showQRCodeForLink:url
									  expiresAt:[pending[@"expirationDate"] longLongValue]];
			  else if ([action isEqualToString:@"edit"])
				  [strongSelf showEditSheetForLink:pending];
			  else if ([action isEqualToString:@"revoke"])
				  [strongSelf revokeLink:pending];
			  else if ([action isEqualToString:@"delete"])
				  [strongSelf deleteRevokedLink:pending];
		  }
			   target:self];
	self.currentActionSheet = sheet;
	UIView *presentationHost = [self sheetHostView];
	[self.currentActionSheet tg_showFromRect:CGRectMake(CGRectGetMidX(presentationHost.bounds), CGRectGetMidY(presentationHost.bounds), 1, 1)
									   inView:presentationHost];
}

- (void)failedWithMessage:(NSString *)message {
	[[[TGAlertView alloc] initWithTitle:nil message:message cancelButtonTitle:TGL(@"Common.OK", @"OK")
						  okButtonTitle:nil
						completionBlock:nil] show];
}

- (void)replacePrimaryLink {
	if (self.busy)
		return;
	self.busy = YES;
	__weak typeof(self) weakSelf = self;
	void (^done)(NSDictionary *) = ^(NSDictionary *link) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		strongSelf.busy = NO;
		if (!link) {
			[strongSelf failedWithMessage:TGL(@"InviteLink.CouldNotBeRevoked", @"The link could not be revoked.")];
			return;
		}
		[strongSelf reload];
	};
	[TGInviteLinkService replacePrimaryInviteLinkForChat:self.chatId completion:done];
}

- (void)revokeLink:(NSDictionary *)link {
	NSString *url = link[@"link"];
	if (![url isKindOfClass:[NSString class]] || !url.length)
		return;
	if (self.busy)
		return;
	self.busy = YES;

	__weak typeof(self) weakSelf = self;
	[TGInviteLinkService revokeInviteLink:url inChat:self.chatId completion:^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		strongSelf.busy = NO;
		if (!ok) {
			[strongSelf failedWithMessage:TGL(@"InviteLink.CouldNotBeRevoked", @"The link could not be revoked.")];
			return;
		}
		[strongSelf reload];
	}];
}

- (void)deleteRevokedLink:(NSDictionary *)link {
	NSString *url = link[@"link"];
	if (![url isKindOfClass:[NSString class]] || !url.length)
		return;
	if (self.busy)
		return;
	self.busy = YES;

	__weak typeof(self) weakSelf = self;
	[TGInviteLinkService deleteRevokedInviteLink:url inChat:self.chatId completion:^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		strongSelf.busy = NO;
		if (!ok) {
			[strongSelf failedWithMessage:TGL(@"InviteLink.CouldNotBeDeleted", @"The link could not be deleted.")];
			return;
		}
		[strongSelf reload];
	}];
}

- (void)confirmDeleteAllRevoked {
	if (!self.revokedLinks.count)
		return;

	TGActionSheetAction *deleteAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"InviteLink.DeleteAllRevokedLinks", @"Delete All Revoked Links") action:@"deleteAll" type:TGActionSheetActionTypeDestructive];
	TGActionSheetAction *cancelAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"Common.Cancel", @"Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel];
	NSArray *actions = [NSArray arrayWithObjects:deleteAction, cancelAction, nil];

	__weak typeof(self) weakSelf = self;
	void (^deleted)(BOOL) = ^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		strongSelf.busy = NO;
		if (!ok) {
			[strongSelf failedWithMessage:TGL(@"InviteLink.RevokedLinksCouldNotBeDeleted", @"The revoked links could not be deleted.")];
			return;
		}
		[strongSelf reload];
	};
	TGActionSheet *sheet = [[TGActionSheet alloc]
		initWithTitle:nil
			  actions:actions
		  actionBlock:^(__unused id target, NSString *action) {
			  __strong typeof(weakSelf) strongSelf = weakSelf;
			  strongSelf.currentActionSheet = nil;
			  if (![action isEqualToString:@"deleteAll"])
				  return;
			  if (strongSelf.busy)
				  return;
			  strongSelf.busy = YES;
			  [TGInviteLinkService deleteAllRevokedInviteLinksInChat:strongSelf.chatId completion:deleted];
		  }
			   target:self];
	self.currentActionSheet = sheet;
	UIView *presentationHost = [self sheetHostView];
	[self.currentActionSheet tg_showFromRect:CGRectMake(CGRectGetMidX(presentationHost.bounds), CGRectGetMidY(presentationHost.bounds), 1, 1)
									   inView:presentationHost];
}

#pragma mark - join requests

- (void)showSheetForRequest:(NSDictionary *)request {
	if (!request || !self.canManage)
		return;
	self.pendingRequest = request;

	NSString *name = request[@"name"];
	if (![name isKindOfClass:[NSString class]])
		name = @"";

	TGActionSheetAction *approveAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"InviteLink.RequestApprove", @"Approve") action:@"approve"];
	TGActionSheetAction *declineAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"Call.Decline", @"Decline") action:@"decline" type:TGActionSheetActionTypeDestructive];
	TGActionSheetAction *cancelAction = [[TGActionSheetAction alloc] initWithTitle:TGL(@"Common.Cancel", @"Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel];
	NSArray *actions = [NSArray arrayWithObjects:approveAction, declineAction, cancelAction, nil];

	__weak typeof(self) weakSelf = self;
	TGActionSheet *sheet = [[TGActionSheet alloc]
		initWithTitle:name.length ? name : nil
			  actions:actions
		  actionBlock:^(__unused id target, NSString *action) {
			  __strong typeof(weakSelf) strongSelf = weakSelf;
			  strongSelf.currentActionSheet = nil;
			  NSDictionary *pending = strongSelf.pendingRequest;
			  strongSelf.pendingRequest = nil;
			  if ([action isEqualToString:@"approve"])
				  [strongSelf processRequest:pending approve:YES];
			  else if ([action isEqualToString:@"decline"])
				  [strongSelf processRequest:pending approve:NO];
		  }
			   target:self];
	self.currentActionSheet = sheet;
	UIView *presentationHost = [self sheetHostView];
	[self.currentActionSheet tg_showFromRect:CGRectMake(CGRectGetMidX(presentationHost.bounds), CGRectGetMidY(presentationHost.bounds), 1, 1)
									   inView:presentationHost];
}

- (void)processRequest:(NSDictionary *)request approve:(BOOL)approve {
	int64_t userId = [request[@"userId"] longLongValue];
	if (!userId)
		return;

	NSMutableArray *remaining = [NSMutableArray arrayWithArray:self.requests ?: [NSArray array]];
	[remaining removeObject:request];
	self.requests = remaining;
	if (self.requestTotal > 0)
		self.requestTotal -= 1;
	[self rebuildSections];
	[self.tableView reloadData];

	__weak typeof(self) weakSelf = self;
	void (^processed)(BOOL) = ^(BOOL ok) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!ok)
			[strongSelf failedWithMessage:TGL(@"InviteLink.RequestCouldNotBeProcessed", @"The request could not be processed.")];
		[strongSelf reload];
	};
	[TGInviteLinkService processJoinRequestFromUser:userId inChat:self.chatId approve:approve completion:processed];
}

- (void)showQRCodeForLink:(NSString *)link expiresAt:(long long)expiresAt {
	if (!link.length)
		return;
	NSTimeInterval left = expiresAt > 0
		? (NSTimeInterval)expiresAt - [[NSDate date] timeIntervalSince1970]
		: 0;
	TGQRCodeViewController *code = [[TGQRCodeViewController alloc]
		initWithLink:link
			 caption:TGL(@"InviteLink.QRCodeCaption", @"Anyone can scan this code to join the chat.")
		   expiresIn:(NSInteger)MAX((NSTimeInterval)0, left)
		 refreshLink:nil];
	[self.navigationController pushViewController:code animated:YES];
}

@end

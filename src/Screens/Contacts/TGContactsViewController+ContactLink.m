#import "TGContactsViewController.h"
#import "TGActionSheetIndexBuilder.h"
#import "TGContactsViewControllerInternal.h"
#import "TGFlatActionCell.h"
#import "TGContactRowCell.h"
#import "TGInviteFriendsViewController.h"
#import "TGContactsService.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGImageDecode.h"
#import "TGNewContactViewController.h"
#import "RootViewController.h"
#import "UIView+SafeTint.h"
#import "TGEmoji.h"
#import <QuartzCore/QuartzCore.h>
#import <AddressBook/AddressBook.h>
#import <dlfcn.h>
#import "TGAlertView.h"
#import "TGQRCodeViewController.h"
#import "TGActionSheet.h"
#import "TGClient.h"
#import "TGClient+WebLinks.h"

@implementation TGContactsViewController (ContactLink)

- (NSInteger)contactLinkSecondsRemaining {
	if (!self.contactLink.length || !self.contactLinkFetchedAt || self.contactLinkExpiresIn <= 0)
		return 0;
	NSInteger elapsed = (NSInteger)(-[self.contactLinkFetchedAt timeIntervalSinceNow]);
	NSInteger left = self.contactLinkExpiresIn - elapsed;
	return left > 0 ? left : 0;
}

- (NSString *)shareableLink {
	if (self.contactLink.length && ([self contactLinkSecondsRemaining] > 0 || self.contactLinkExpiresIn <= 0))
		return self.contactLink;
	return self.myUsernameLink;
}

- (void)reloadMyUsernames {
	if (self.pickerMode)
		return;
	__weak typeof(self) weakSelf = self;
	[TGContactsService myUsernamesWithCompletion:^(NSDictionary *usernames) {
		TGContactsViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSString *pick = nil;
		if ([usernames isKindOfClass:NSDictionary.class]) {
			NSArray *active = [usernames[@"active"] isKindOfClass:NSArray.class]
				? usernames[@"active"]
				: nil;
			for (NSString *one in active) {
				if ([one isKindOfClass:NSString.class] && one.length) {
					pick = one;
					break;
				}
			}
			if (!pick.length) {
				NSString *editable = usernames[@"editable"];
				if ([editable isKindOfClass:NSString.class] && editable.length)
					pick = editable;
			}
		}
		if (!pick.length) {
			[strongSelf reloadTableSoon];
			return;
		}
		[[TGClient shared] publicLinkForUsername:pick completion:^(NSString *link) {
			TGContactsViewController *innerSelf = weakSelf;
			if (!innerSelf)
				return;
			BOOL appears = (link.length && !innerSelf.myUsernameLink.length && !innerSelf.contactLink.length);
			innerSelf.myUsernameLink = link;
			if (appears)
				[innerSelf refreshTable];
			else
				[innerSelf reloadTableSoon];
		}];
	}];
}

- (NSString *)contactLinkSubtitle {
	NSString *display = [self shareableLink];
	for (NSString *prefix in @[ @"https://", @"http://" ]) {
		if ([display hasPrefix:prefix])
			display = [display substringFromIndex:prefix.length];
	}
	NSInteger left = [self contactLinkSecondsRemaining];
	if (left <= 0)
		return display;
	if (left < 60)
		return [NSString stringWithFormat:TGL(@"Contacts.MyLinkSecondsLeftFormat", @"%@ · %ds left"), display, (int)left];
	return [NSString stringWithFormat:TGL(@"Contacts.MyLinkMinutesLeftFormat", @"%@ · %d min left"), display, (int)(left / 60)];
}

- (void)reloadContactLink {
	if (self.pickerMode || self.contactLinkRequested)
		return;
	self.contactLinkRequested = YES;
	__weak typeof(self) weakSelf = self;
	[TGContactsService myContactLinkWithCompletion:^(NSString *url, NSInteger expiresIn) {
		TGContactsViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.contactLinkRequested = NO;
		if (![url isKindOfClass:NSString.class] || !url.length)
			return;
		BOOL appeared = (strongSelf.contactLink.length == 0);
		strongSelf.contactLink = url;
		strongSelf.contactLinkExpiresIn = expiresIn;
		strongSelf.contactLinkFetchedAt = [NSDate date];
		if (appeared)
			[strongSelf refreshTable];
		else
			[strongSelf reloadTableSoon];
	}];
}

- (void)contactLinkTapped {
	if (!self.contactLink.length && !self.myUsernameLink.length)
		return;
	__weak typeof(self) weakSelf = self;
	void (^refresh)(void (^)(NSString *, NSInteger)) = ^(void (^completion)(NSString *, NSInteger)) {
		[TGContactsService myContactLinkWithCompletion:^(NSString *url, NSInteger expiresIn) {
			TGContactsViewController *innerSelf = weakSelf;
			if (innerSelf && url.length) {
				innerSelf.contactLink = url;
				innerSelf.contactLinkExpiresIn = expiresIn;
				innerSelf.contactLinkFetchedAt = [NSDate date];
			}
			if (completion)
				completion(url, expiresIn);
		}];
	};
	BOOL expired = self.contactLink.length && [self contactLinkSecondsRemaining] <= 0 && self.contactLinkExpiresIn > 0;
	if (!expired) {
		NSString *link = [self shareableLink];
		if (!link.length)
			return;
		NSInteger remaining = self.contactLink.length ? [self contactLinkSecondsRemaining] : 0;
		TGQRCodeViewController *code = [[TGQRCodeViewController alloc]
			initWithLink:link
				 caption:TGL(@"Settings.AnyoneCanScanThisCodeTo", @"Anyone can scan this code to open your profile.")
			   expiresIn:remaining
			 refreshLink:remaining > 0 ? refresh : nil];
		[self.navigationController pushViewController:code animated:YES];
		return;
	}
	refresh(^(NSString *freshLink, NSInteger freshExpiresIn) {
		TGContactsViewController *innerSelf = weakSelf;
		if (!innerSelf)
			return;
		NSString *finalLink = freshLink.length ? freshLink : [innerSelf shareableLink];
		NSInteger remaining = freshLink.length ? freshExpiresIn : 0;
		TGQRCodeViewController *code = [[TGQRCodeViewController alloc]
			initWithLink:finalLink
				 caption:TGL(@"Settings.AnyoneCanScanThisCodeTo", @"Anyone can scan this code to open your profile.")
			   expiresIn:remaining
			 refreshLink:remaining > 0 ? refresh : nil];
		[innerSelf.navigationController pushViewController:code animated:YES];
	});
}

- (void)presentSheet:(UIActionSheet *)sheet {
	UITabBar *tabBar = [self.tabBarController isKindOfClass:UITabBarController.class]
		? self.tabBarController.tabBar
		: nil;
	if (tabBar) {
		[sheet showFromTabBar:tabBar];
	} else {
		UIView *presentationHost = self.navigationController.view;
		[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(presentationHost.bounds), CGRectGetMidY(presentationHost.bounds), 1, 1)
						 inView:presentationHost];
	}
}

- (void)handleLinkSheetAtIndex:(NSInteger)index {
	NSString *link = [self shareableLink];
	if (!link.length)
		return;
	if (index == 0) {
		[UIPasteboard generalPasteboard].string = link;
		return;
	}
	if (index == 1) {
		UIActivityViewController *share = [[UIActivityViewController alloc]
			initWithActivityItems:@[ link ]
			applicationActivities:nil];
		[self presentViewController:share animated:YES completion:nil];
	}
}

@end

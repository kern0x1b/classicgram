#import "TGProfileViewController.h"
#import "TGProfileViewControllerInternal.h"
#import "TGProfileDetailPresenter.h"
#import "TGProfileDetailRowBridge.h"
#import "TGProfileButtonsCell.h"
#import "TGProfileRedButtonCell.h"
#import "TGProfilePermissionsController.h"
#import "TGProfileStatisticsController.h"
#import "TGProfileBoostsController.h"
#import "TGProfileCommonGroupsController.h"
#import "TGProfileLinkJoinsController.h"
#import "TGLocalization.h"
#import "TGFileDownloadService.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGPopupMenu.h"
#import "TGActionSheet.h"
#import "TGForwardPicker.h"
#import "UIView+SafeTint.h"
#import "TGImageDecode.h"
#import "TGLazyFramework.h"
#import <AVFoundation/AVFoundation.h>
#import <AddressBook/AddressBook.h>
#import <ImageIO/ImageIO.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>
#import "TGEmoji.h"
#import "TGDateLabel.h"
#import "TGDateUtils.h"
#import "TGAlertView.h"

const NSInteger kPickerModeChatPhoto = 0;
const NSInteger kPickerModeStory = 1;
const NSInteger kPickerModePersonalPhoto = 2;
const NSInteger kPickerModeSuggestPhoto = 3;

const NSInteger kOverlayPhotoLimit = 20;
const CGFloat kOverlayPagerBottom = 34.0f;
const CGFloat kOverlayPagerHeight = 20.0f;

@implementation TGProfileViewController

+ (void)showProfileForChatId:(int64_t)chatId
					  userId:(int64_t)userId
					   title:(NSString *)title
				inNavigation:(UINavigationController *)navigation {
	if (!navigation)
		return;

	if (userId > 0) {
		for (UIViewController *controller in navigation.viewControllers) {
			if (![controller isKindOfClass:[TGProfileViewController class]])
				continue;
			if (((TGProfileViewController *)controller).userId != userId)
				continue;
			[navigation popToViewController:controller animated:YES];
			return;
		}
	}

	TGProfileViewController *profile = [[TGProfileViewController alloc] initWithChatId:chatId
																			   userId:userId
																				title:title];
	[navigation pushViewController:profile animated:YES];
}

- (instancetype)initWithChatId:(int64_t)chatId userId:(int64_t)userId title:(NSString *)title {
	if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
		_chatId = chatId;
		_userId = userId;
		_name = title ?: @"";
		_details = @[];
		_manageRows = @[];
		_profileDetailPresenter = [[TGProfileDetailPresenter alloc] init];
		_profileDetailRowBridge = [[TGProfileDetailRowBridge alloc] initWithPresenter:_profileDetailPresenter];
		_recipientAcceptsGifts = YES;
		_recipientAcceptsPremiumGift = YES;
		_canCall = YES;
		_canVideoCall = YES;
		[self rebuildSections];
	}
	return self;
}

- (void)refreshProfileDetailPresenter {
	BOOL isSongPlaying = self.songPlayer.playing && self.songPlayerFileId == [self.profileAudioInfo[@"fileId"] longLongValue];
	[self.profileDetailPresenter updateDetails:self.details isSongPlaying:isSongPlaying];
}

- (void)dealloc {
	_photoScroll.delegate = nil;
	for (NSNumber *fileId in _overlayDownloads) {
		if ([fileId longLongValue] > 0)
			[TGFileDownloadService cancelDownloadOfFile:[fileId longLongValue] onlyIfPending:NO];
	}
	if (_userProfileObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_userProfileObserverToken];
	if (_userBlockedStateObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_userBlockedStateObserverToken];
	if (_chatVerificationObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_chatVerificationObserverToken];
	if (_chatOnlineMemberCountObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_chatOnlineMemberCountObserverToken];
	if (_chatEmojiStatusObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_chatEmojiStatusObserverToken];
	if (_chatSlowModeDelayObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_chatSlowModeDelayObserverToken];
	if (_chatPendingJoinRequestsObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:_chatPendingJoinRequestsObserverToken];
}

@end

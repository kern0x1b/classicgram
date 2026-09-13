#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+MessageContent.h"
#import "TGLocalization.h"
#import "TGAlertView.h"
#import "TGSnackbar.h"
#import "TGActionSheetIndexBuilder.h"
#import "TGActionSheet.h"

@implementation TGChatViewController (Location)

- (void)showLocationOptions {
	BOOL liveActive = self.liveLocationMessageId != 0;
	NSMutableArray *otherTitles = [NSMutableArray array];
	if (!liveActive)
		[otherTitles addObject:TGL(@"Map.SendMyCurrentLocation", @"Send My Current Location")];
	if (liveActive)
		[otherTitles addObject:TGL(@"Conversation.StopLiveLocation", @"Stop Sharing")];
	else
		[otherTitles addObject:TGL(@"Map.ShareLiveLocation", @"Share My Live Location for...")];
	if (!liveActive)
		[otherTitles addObject:TGL(@"Map.SendThisPlace", @"Send a Place")];
	NSInteger destructiveButtonIndex, cancelButtonIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:TGL(@"Attachment.Location", @"Location")
					  delegate:self
				   otherTitles:otherTitles
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:&destructiveButtonIndex
			 cancelButtonIndex:&cancelButtonIndex];
	sheet.tag = kLocationSheetTag;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)runLocationOption:(NSString *)chosen {
	if ([chosen isEqualToString:TGL(@"Map.SendMyCurrentLocation", @"Send My Current Location")]) {
		self.locationMode = @"point";
		[self sendCurrentLocation];
		return;
	}
	if ([chosen isEqualToString:TGL(@"Map.ShareLiveLocation", @"Share My Live Location for...")]) {
		self.locationMode = @"live";
		[self sendCurrentLocation];
		return;
	}
	if ([chosen isEqualToString:TGL(@"Conversation.StopLiveLocation", @"Stop Sharing")]) {
		[self stopSharingLiveLocation];
		return;
	}
	if ([chosen isEqualToString:TGL(@"Map.SendThisPlace", @"Send a Place")]) {
		[self prefetchVenueLocation];
		UIAlertView *ask =
			[[TGAlertView alloc] initWithTitle:TGL(@"Chat.Place", @"Place")
									   message:TGL(@"Chat.ItsName", @"Its name")
									  delegate:self
							 cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
							 otherButtonTitles:TGL(@"Common.Next", @"Next"), nil];
		if ([ask respondsToSelector:@selector(setAlertViewStyle:)])
			ask.alertViewStyle = UIAlertViewStylePlainTextInput;
		ask.tag = kVenueTitleAlertTag;
		[ask show];
	}
}

- (void)stopSharingLiveLocation {
	if (!self.liveLocationMessageId)
		return;
	int64_t messageId = self.liveLocationMessageId;
	int64_t chatId = self.chatId;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] stopLiveLocation:messageId inChat:chatId completion:^(BOOL ok, NSInteger errorCode) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[TGSnackbar showInView:strongSelf.view
							   text:TGL(@"Map.StopLiveLocationFailed", @"Could not stop sharing your location")
							seconds:3
						   onCommit:nil];
			return;
		}
		if (strongSelf.liveLocationMessageId == messageId) {
			strongSelf.liveLocationMessageId = 0;
			strongSelf.locationMode = nil;
			[strongSelf stopLiveLocationTrackingCleanup];
			[strongSelf refreshLiveLocationTimerState];
		}
		[strongSelf reload];
	}];
}
@end

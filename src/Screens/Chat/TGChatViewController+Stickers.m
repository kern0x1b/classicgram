#import "TGClient+Messages.h"
#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGClient+Gifs.h"
#import "TGClient+Premium.h"
#import "TGLocalization.h"
#import "TGStickerPanelView.h"
#import "TGStickersViewController.h"
#import "TGGifPickerViewController.h"
#import "TGQuickReplyListViewController.h"
#import "TGSnackbar.h"

@implementation TGChatViewController (Stickers)

- (void)toggleStickerPanel {
	if (self.stickerPanel) {
		UIView *going = self.stickerPanel;
		self.stickerPanel = nil;
		self.stickerPanelSearching = NO;
		[going endEditing:YES];
		[going removeFromSuperview];
		[self shiftForKeyboardHeight:0];
		return;
	}

	[self.input resignFirstResponder];

	CGRect b = self.view.bounds;
	BOOL landscape = b.size.width > b.size.height;
	CGFloat height = [TGStickerPanelView preferredHeightForLandscape:landscape];
	TGStickerPanelView *panel = [[TGStickerPanelView alloc] initWithFrame:
			CGRectMake(0, b.size.height - height, b.size.width, height)];
	panel.autoresizingMask = UIViewAutoresizingFlexibleWidth |
		UIViewAutoresizingFlexibleTopMargin;

	__weak typeof(self) weakSelf = self;
	panel.onStickerPicked = ^(NSDictionary *sticker) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if ([sticker[@"customEmojiId"] longLongValue] != 0) {
			if (![[TGClient shared] isPremiumAccount]) {
				[strongSelf showAlertTitle:@""
									message:TGL(@"EmojiInput.PremiumEmojiToast.Text",
										@"Subscribe to Telegram Premium to unlock premium emoji.")];
				return;
			}
			NSString *glyph = sticker[@"emoji"];
			if ([glyph isKindOfClass:NSString.class] && glyph.length > 0) {
				NSString *current = strongSelf.input.text ?: @"";
				NSRange caret = strongSelf.input.selectedRange;
				if (caret.location > current.length)
					caret = NSMakeRange(current.length, 0);
				else if (NSMaxRange(caret) > current.length)
					caret.length = current.length - caret.location;
				[strongSelf adjustPendingCustomEmojiForRange:caret replacementLength:(NSInteger)glyph.length];
				[strongSelf adjustPendingMentionRunsForRange:caret replacementLength:(NSInteger)glyph.length];
				[strongSelf.pendingCustomEmojiRuns addObject:@{
					@"range" : [NSValue valueWithRange:
							NSMakeRange(caret.location, glyph.length)],
					@"customEmojiId" : sticker[@"customEmojiId"],
					@"glyph" : glyph,
				}];
				NSString *replaced = [current stringByReplacingCharactersInRange:caret withString:glyph];
				strongSelf.input.text = replaced;
				strongSelf.input.selectedRange = NSMakeRange(caret.location + glyph.length, 0);
				[strongSelf inputChanged];
			}
			return;
		}
		NSNumber *fileId = sticker[@"fileId"];
		if (![fileId isKindOfClass:NSNumber.class])
			return;
		if (strongSelf.postingBlocked)
			return;
		if ([strongSelf blockSendForSlowMode])
			return;
		[[TGClient shared] sendStickerWithFileId:fileId.longLongValue
										  toChat:strongSelf.chatId
										  thread:strongSelf.threadId
									  savedTopic:strongSelf.savedTopicId
										 replyTo:strongSelf.replyToId
										 options:[strongSelf sendOptionsDictionary]];
		[strongSelf clearComposeState];
		[strongSelf toggleStickerPanel];
	};
	panel.onCloseRequested = ^{
		TGChatViewController *strongSelf = weakSelf;
		if (strongSelf.stickerPanel)
			[strongSelf toggleStickerPanel];
	};
	panel.onSearchVisibilityChanged = ^(BOOL searching) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf || !strongSelf.stickerPanel)
			return;
		strongSelf.stickerPanelSearching = searching;
	};
	panel.onBackspace = ^BOOL {
		TGChatViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return NO;
		NSString *text = strongSelf.input.text;
		if (text.length == 0)
			return NO;
		NSRange last = [text rangeOfComposedCharacterSequenceAtIndex:text.length - 1];
		[strongSelf adjustPendingCustomEmojiForRange:
				NSMakeRange(last.location, text.length - last.location)
						   replacementLength:0];
		[strongSelf adjustPendingMentionRunsForRange:
				NSMakeRange(last.location, text.length - last.location)
						   replacementLength:0];
		strongSelf.input.text = [text substringToIndex:last.location];
		[strongSelf inputChanged];
		return YES;
	};

	[self.view addSubview:panel];
	self.stickerPanel = panel;
	[self shiftForKeyboardHeight:height];
}

- (void)openStickerSetWithId:(int64_t)setId {
	if (setId == 0)
		return;
	TGStickersViewController *pack = [[TGStickersViewController alloc] init];
	pack.page = TGStickersPageSet;
	pack.setId = setId;
	[self.navigationController pushViewController:pack animated:YES];
}

#pragma mark - gifs

- (void)showGifPicker {
	if (self.postingBlocked)
		return;
	if (self.stickerPanel)
		[self toggleStickerPanel];
	[self.input resignFirstResponder];

	TGGifPickerViewController *picker = [[TGGifPickerViewController alloc] init];
	__weak typeof(self) weakSelf = self;
	picker.onPicked = ^(NSDictionary *gif) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf || strongSelf.postingBlocked)
			return;
		if ([strongSelf blockSendForSlowMode])
			return;
		long long fileId = [gif[@"fileId"] longLongValue];
		if (fileId != 0)
			[[TGClient shared] saveGifWithFileId:fileId completion:nil];
		[[TGClient shared] sendGif:gif
							toChat:strongSelf.chatId
							thread:strongSelf.threadId
			   directMessagesTopic:strongSelf.directMessagesTopicId
						savedTopic:strongSelf.savedTopicId
						   replyTo:strongSelf.replyToId
						   options:[strongSelf sendOptionsDictionary]];
		[strongSelf clearComposeState];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
			dispatch_get_main_queue(), ^{ [strongSelf reload]; });
	};
	picker.onPickFromLibrary = ^{
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.attachMode = @"animation";
		[strongSelf pickMedia];
	};

	UINavigationController *wrapper = [[UINavigationController alloc]
		initWithRootViewController:picker];
	if (TGChatIsPad())
		wrapper.modalPresentationStyle = UIModalPresentationFormSheet;
	[self presentViewController:wrapper animated:YES completion:nil];
}

- (void)showQuickReplies {
	if (self.postingBlocked)
		return;

	TGQuickReplyListViewController *list =
		[[TGQuickReplyListViewController alloc] initWithChatId:self.chatId];
	__weak typeof(self) weakSelf = self;
	list.onSent = ^{
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
			dispatch_get_main_queue(), ^{ [strongSelf reload]; });
	};
	[self.navigationController pushViewController:list animated:YES];
}
@end

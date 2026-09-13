#import "TGMediaFullscreenControllerInternal.h"
#import "TGMediaPageView.h"
#import "TGClient+Files.h"
#import "TGClient+Messages.h"
#import "TGClient+SecretChats.h"
#import "TGClient+Stickers.h"
#import "TGForwardPicker.h"
#import "TGLocalization.h"
#import "TGActionSheet.h"
#import "TGActionSheetIndexBuilder.h"
#import "UIImage+WebP.h"

@implementation TGMediaFullscreenController (Actions)

#pragma mark - actions

- (void)closeTapped {
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showMessage:(NSString *)message {
	UIAlertView *alert = [UIAlertView alloc];
	alert = [alert initWithTitle:@""
						 message:message
						delegate:nil
			   cancelButtonTitle:TGL(@"Common.OK", @"OK")
			   otherButtonTitles:nil];
	[alert show];
}

- (void)actionsTapped {
	NSDictionary *item = [self currentItem];
	if (!item)
		return;

	BOOL burns = [item[@"burns"] boolValue];
	BOOL hasMessage = self.chatId != 0 && [item[@"messageId"] longLongValue] != 0;
	NSNumber *fileId = item[@"fullId"];
	BOOL hasFile = [fileId isKindOfClass:[NSNumber class]] && [fileId longLongValue] > 0;

	if (!hasMessage || burns) {
		[self presentActionsSheetWithItem:item canForward:NO canSave:YES hasFile:hasFile];
		return;
	}

	int64_t chatId = self.chatId;
	int64_t messageId = [item[@"messageId"] longLongValue];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] propertiesOfMessage:messageId
									 inChat:chatId
								 completion:^(NSDictionary *properties) {
									 dispatch_async(dispatch_get_main_queue(), ^{
										 typeof(self) strongSelf = weakSelf;
										 if (!strongSelf || strongSelf.chatId != chatId)
											 return;
										 NSDictionary *stillItem = [strongSelf currentItem];
										 if (![stillItem[@"messageId"] isKindOfClass:NSNumber.class] ||
											 [stillItem[@"messageId"] longLongValue] != messageId)
											 return;
										 BOOL canForward = [properties isKindOfClass:NSDictionary.class] &&
											 [properties[@"canForward"] boolValue];
										 BOOL canSave = [properties isKindOfClass:NSDictionary.class] &&
											 [properties[@"canSave"] boolValue];
										 [strongSelf presentActionsSheetWithItem:stillItem canForward:canForward canSave:canSave hasFile:hasFile];
									 });
								 }];
}

- (void)presentActionsSheetWithItem:(NSDictionary *)item canForward:(BOOL)canForward canSave:(BOOL)canSave hasFile:(BOOL)hasFile {
	BOOL burns = [item[@"burns"] boolValue];
	BOOL hasMessage = self.chatId != 0 && [item[@"messageId"] longLongValue] != 0;

	NSMutableArray *actions = [NSMutableArray array];
	if (hasMessage && !burns && canForward)
		[actions addObject:@"forward"];
	if (!burns && canSave)
		[actions addObject:@"save"];
	if (hasMessage && self.onShowInChat)
		[actions addObject:@"showInChat"];
	if (hasFile && self.onOpenStickerSet)
		[actions addObject:@"whichSticker"];
	if (actions.count == 0)
		return;
	self.sheetActions = actions;

	NSMutableArray *otherTitles = [NSMutableArray array];
	for (NSString *action in actions) {
		if ([action isEqualToString:@"save"])
			[otherTitles addObject:TGL(@"Preview.SaveToCameraRoll", @"Save to Camera Roll")];
		else if ([action isEqualToString:@"showInChat"])
			[otherTitles addObject:TGL(@"MediaPlayer.ContextMenu.ShowInChat", @"Show in Chat")];
		else if ([action isEqualToString:@"forward"])
			[otherTitles addObject:TGL(@"Conversation.ContextMenuForward", @"Forward")];
		else if ([action isEqualToString:@"whichSticker"])
			[otherTitles addObject:TGL(@"StickerPack.ViewPack", @"View Pack")];
	}
	NSInteger destructiveButtonIndex, cancelButtonIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:nil
					  delegate:self
				   otherTitles:otherTitles
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:&destructiveButtonIndex
			 cancelButtonIndex:&cancelButtonIndex];
	sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
	[sheet tg_showFromRect:_actionButton.bounds inView:_actionButton];
}

- (void)deleteTapped {
	NSDictionary *item = [self currentItem];
	if (!item)
		return;
	int64_t chatId = self.chatId;
	int64_t messageId = [item[@"messageId"] longLongValue];
	if (chatId == 0 || messageId == 0)
		return;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] propertiesOfMessage:messageId
									 inChat:chatId
								 completion:^(NSDictionary *properties) {
									 dispatch_async(dispatch_get_main_queue(), ^{
										 typeof(self) strongSelf = weakSelf;
										 if (!strongSelf || strongSelf.chatId != chatId)
											 return;
										 NSDictionary *stillItem = [strongSelf currentItem];
										 if (![stillItem[@"messageId"] isKindOfClass:NSNumber.class] ||
											 [stillItem[@"messageId"] longLongValue] != messageId)
											 return;
										 BOOL canDeleteForEveryone = [properties isKindOfClass:NSDictionary.class] &&
											 [properties[@"canDeleteForEveryone"] boolValue];
										 [strongSelf presentDeleteSheetForItem:stillItem canDeleteForEveryone:canDeleteForEveryone];
									 });
								 }];
}

- (void)presentDeleteSheetForItem:(NSDictionary *)item canDeleteForEveryone:(BOOL)canDeleteForEveryone {
	BOOL secret = [[TGClient shared] isSecretChat:self.chatId];
	BOOL offerForEveryone = !secret && canDeleteForEveryone;

	NSString *singleTitle = [item[@"isVideo"] boolValue]
		? TGL(@"Preview.DeleteVideo", @"Delete Video")
		: TGL(@"Preview.DeletePhoto", @"Delete Photo");

	NSMutableArray *otherTitles = [NSMutableArray array];
	if (offerForEveryone) {
		self.sheetActions = @[ @"deleteForEveryone", @"deleteForMe" ];
		[otherTitles addObject:TGL(@"Stickers.Delete.ForEveryone", @"Delete for Everyone")];
		[otherTitles addObject:TGL(@"ChatList.DeleteForMe", @"Delete for Me")];
	} else {
		self.sheetActions = @[ @"delete" ];
		[otherTitles addObject:singleTitle];
	}

	NSInteger destructiveButtonIndex, cancelButtonIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:nil
					  delegate:self
				   otherTitles:otherTitles
			  destructiveIndex:0
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:&destructiveButtonIndex
			 cancelButtonIndex:&cancelButtonIndex];
	sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
	[sheet tg_showFromRect:_deleteButton.bounds inView:_deleteButton];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
	if (self.stickerSetChoices.count) {
		NSArray *choices = self.stickerSetChoices;
		self.stickerSetChoices = nil;
		if (index >= 0 && index < (NSInteger)choices.count)
			[self openStickerSet:choices[index]];
		return;
	}

	if (self.pendingForwardMessageId) {
		NSNumber *messageId = self.pendingForwardMessageId;
		self.pendingForwardMessageId = nil;
		if (index >= 0 && index <= 2)
			[self pushForwardPickerForMessageId:[messageId longLongValue] asCopy:(index >= 1) removeCaptions:(index == 2)];
		return;
	}

	if (index < 0 || index >= (NSInteger)self.sheetActions.count)
		return;

	NSString *action = self.sheetActions[index];
	if ([action isEqualToString:@"save"])
		[self saveCurrentItem];
	else if ([action isEqualToString:@"forward"])
		[self forwardCurrentItem];
	else if ([action isEqualToString:@"delete"])
		[self deleteCurrentItemForEveryone:[[TGClient shared] isSecretChat:self.chatId]];
	else if ([action isEqualToString:@"deleteForEveryone"])
		[self deleteCurrentItemForEveryone:YES];
	else if ([action isEqualToString:@"deleteForMe"])
		[self deleteCurrentItemForEveryone:NO];
	else if ([action isEqualToString:@"showInChat"])
		[self showCurrentItemInChat];
	else if ([action isEqualToString:@"whichSticker"])
		[self lookupStickerForCurrentItem];
}

- (void)lookupStickerForCurrentItem {
	NSDictionary *item = [self currentItem];
	NSNumber *fileId = item[@"fullId"];
	if (![fileId isKindOfClass:[NSNumber class]] || [fileId longLongValue] <= 0)
		return;

	[_spinner startAnimating];
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] attachedStickerSetsForFileId:[fileId longLongValue] completion:^(NSArray *sets) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf.spinner stopAnimating];
		if (![sets isKindOfClass:[NSArray class]] || sets.count == 0)
			return;
		if (sets.count == 1) {
			[strongSelf openStickerSet:sets.firstObject];
			return;
		}

		strongSelf.stickerSetChoices = sets;
		NSMutableArray *otherTitles = [NSMutableArray array];
		for (NSDictionary *set in sets)
			[otherTitles addObject:[set[@"title"] length] ? set[@"title"] : TGL(@"Stickers.UntitledSet", @"Sticker Set")];
		NSInteger destructiveButtonIndex, cancelButtonIndex;
		UIActionSheet *sheet = [TGActionSheetIndexBuilder
					sheetWithTitle:TGL(@"Preview.SelectStickerSet", @"Select a sticker set")
						  delegate:strongSelf
					   otherTitles:otherTitles
				  destructiveIndex:-1
					   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
			destructiveButtonIndex:&destructiveButtonIndex
				 cancelButtonIndex:&cancelButtonIndex];
		sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
		[sheet tg_showFromRect:strongSelf->_actionButton.bounds inView:strongSelf->_actionButton];
	}];
}

- (void)openStickerSet:(NSDictionary *)set {
	int64_t setId = [set[@"id"] longLongValue];
	if (setId == 0 || !self.onOpenStickerSet)
		return;

	void (^callback)(int64_t) = [self.onOpenStickerSet copy];
	[self dismissViewControllerAnimated:YES completion:^{
		callback(setId);
	}];
}

- (void)showCurrentItemInChat {
	NSDictionary *item = [self currentItem];
	int64_t messageId = [item[@"messageId"] longLongValue];
	if (messageId == 0 || !self.onShowInChat)
		return;

	void (^callback)(int64_t) = [self.onShowInChat copy];
	[self dismissViewControllerAnimated:YES completion:^{
		callback(messageId);
	}];
}

- (void)saveCurrentItem {
	NSDictionary *item = [self currentItem];
	NSNumber *fileId = item[@"fullId"];
	if (![fileId isKindOfClass:NSNumber.class] || [fileId longLongValue] <= 0)
		return;

	BOOL isVideo = [item[@"isVideo"] boolValue];
	[_spinner startAnimating];
	_playButton.enabled = NO;
	_busyPageIndex = _currentIndex;

	NSInteger requestedIndex = _currentIndex;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] downloadFile:[fileId longLongValue] completion:^(NSString *path) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf.spinner stopAnimating];
		strongSelf.playButton.enabled = YES;
		if (strongSelf.busyPageIndex == requestedIndex)
			strongSelf.busyPageIndex = NSNotFound;
		[strongSelf updateLoadingChrome];
		if (path.length == 0) {
			[strongSelf showMessage:TGL(@"Toast.CouldNotSaveMedia", @"Could not save")];
			return;
		}
		if (isVideo) {
			if (!UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(path)) {
				[strongSelf showMessage:TGL(@"Chat.ThisVideoCannotBeSaved", @"This video cannot be saved.")];
				return;
			}
			UISaveVideoAtPathToSavedPhotosAlbum(path, strongSelf,
				@selector(media:didFinishSavingWithError:contextInfo:), NULL);
			return;
		}
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			UIImage *decoded = [UIImage imageWithContentsOfFile:path];
			if (!decoded && [path.pathExtension.lowercaseString isEqualToString:@"webp"])
				decoded = [UIImage convertFromWebP:path compressedData:nil error:nil];
			dispatch_async(dispatch_get_main_queue(), ^{
				typeof(self) innerSelf = weakSelf;
				if (!innerSelf)
					return;
				if (!decoded) {
					[innerSelf showMessage:TGL(@"Toast.CouldNotSaveMedia", @"Could not save")];
					return;
				}
				UIImageWriteToSavedPhotosAlbum(decoded, innerSelf,
					@selector(media:didFinishSavingWithError:contextInfo:), NULL);
			});
		});
	}];
}

- (void)media:(id)item didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
	[self showMessage:error
		? TGL(@"Toast.CouldNotSaveMedia", @"Could not save")
		: TGL(@"WebApp.Download.SavedToPhotos", @"Saved to Camera Roll")];
}

- (void)forwardCurrentItem {
	NSDictionary *item = [self currentItem];
	NSNumber *messageId = item[@"messageId"];
	if (![messageId isKindOfClass:NSNumber.class] || [messageId longLongValue] == 0)
		return;

	self.pendingForwardMessageId = messageId;

	NSInteger destructiveButtonIndex, cancelButtonIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:TGL(@"Conversation.ForwardOptions.ForwardTitleSingle", @"Forward Message")
					  delegate:self
				   otherTitles:@[
					   TGL(@"Conversation.ForwardTitle", @"Forward"),
					   TGL(@"Conversation.ForwardOptions.HideSendersName", @"Hide sender name"),
					   TGL(@"Conversation.ForwardOptions.HideCaption", @"Hide Captions"),
				   ]
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:&destructiveButtonIndex
			 cancelButtonIndex:&cancelButtonIndex];
	sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
	[sheet tg_showFromRect:_actionButton.bounds inView:_actionButton];
}

- (void)pushForwardPickerForMessageId:(int64_t)messageId asCopy:(BOOL)asCopy removeCaptions:(BOOL)removeCaptions {
	int64_t fromChat = self.chatId;
	TGForwardPicker *picker = [[TGForwardPicker alloc] init];
	__weak typeof(self) weakSelf = self;
	picker.onPicked = ^(NSArray *chatIds) {
		for (NSNumber *targetChatId in chatIds)
			[[TGClient shared] forwardMessages:@[ @(messageId) ]
									  fromChat:fromChat
										toChat:[targetChatId longLongValue]
										thread:0
										asCopy:asCopy
								removeCaptions:removeCaptions
										silent:NO
									completion:^(NSArray *forwarded) {
										TGMediaFullscreenController *strongSelf = weakSelf;
										if (!strongSelf || forwarded.count)
											return;
										[strongSelf showMessage:TGL(@"Toast.CouldNotForwardMessages", @"Could not forward these messages")];
									}];
	};

	UINavigationController *wrapper = [[UINavigationController alloc]
		initWithRootViewController:picker];
	[self presentViewController:wrapper animated:YES completion:nil];
}

- (void)deleteCurrentItemForEveryone:(BOOL)forEveryone {
	NSDictionary *item = [self currentItem];
	NSNumber *messageId = item[@"messageId"];
	if (![messageId isKindOfClass:NSNumber.class] || [messageId longLongValue] == 0)
		return;

	int64_t identifier = [messageId longLongValue];
	NSInteger index = _currentIndex;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] deleteMessages:@[ messageId ]
							   inChat:self.chatId
						  forEveryone:forEveryone
						   completion:^(BOOL ok) {
							   typeof(self) strongSelf = weakSelf;
							   if (!strongSelf)
								   return;
							   if (!ok) {
								   [strongSelf showMessage:TGL(@"Toast.CouldNotDeleteMessages", @"Could not delete these messages")];
								   return;
							   }
							   if (strongSelf.onMessageDeleted)
								   strongSelf.onMessageDeleted(identifier);
							   [strongSelf removeItemAtIndex:index];
						   }];
}

- (void)removeItemAtIndex:(NSInteger)index {
	if (index < 0 || index >= (NSInteger)_items.count)
		return;

	[_items removeObjectAtIndex:index];
	if (_items.count == 0) {
		[self closeTapped];
		return;
	}

	for (NSNumber *key in _visiblePages.allKeys)
		[self recyclePage:_visiblePages[key] forKey:key];
	[_imageCache removeAllObjects];
	[_failedPages removeAllObjects];

	if (_currentIndex > (NSInteger)_items.count - 1)
		_currentIndex = (NSInteger)_items.count - 1;

	_validSize = CGSizeZero;
	[self layoutPagesPreservingIndex:_currentIndex];
	[self updateChromeForCurrentItem];
}

- (void)installBackgroundObserver {
	if (_backgroundObserverToken)
		return;

	__weak typeof(self) weakSelf = self;
	_backgroundObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:UIApplicationDidEnterBackgroundNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					typeof(self) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf stopInlinePlayer];
				}];
}

- (void)removeBackgroundObserver {
	if (!_backgroundObserverToken)
		return;
	[[NSNotificationCenter defaultCenter] removeObserver:_backgroundObserverToken];
	_backgroundObserverToken = nil;
}

@end

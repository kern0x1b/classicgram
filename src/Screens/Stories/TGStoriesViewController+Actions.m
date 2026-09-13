#import "TGStoriesViewController.h"
#import "TGFriendlyError.h"
#import "TGLocalization.h"
#import "TGLazyFramework.h"

#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "TGClient+Stories.h"
#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "TGSnackbar.h"
#import "TGTheme.h"
#import "TGDateUtils.h"
#import "TGImageDecode.h"
#import "TGReactionPickerView.h"
#import "RootViewController.h"
#import "TGStoryAreaEditorViewController.h"
#import "TGStoryHelpers.h"
#import "TGStoryTextViewController.h"

#import "TGStoryContactPicker.h"
#import "TGStoryViewersViewController.h"
#import "TGStoryListViewController.h"

#import "TGStoryPage.h"
#import "TGStoryPostOptions.h"
#import "TGStoryComposer.h"
#import "TGStoryStatisticsViewController.h"
#import "TGStoriesViewControllerInternal.h"

@implementation TGStoriesViewController (Actions)

#pragma mark - actions

- (void)sendReaction:(NSString *)emoji {
	NSInteger storyId = [self currentStoryId];
	if (storyId == 0)
		return;

	NSString *value = emoji ?: @"";
	[[TGClient shared] reactToStory:storyId inChat:_chatId emoji:value];

	NSDictionary *story = [self currentStory];
	if (story == nil)
		return;

	NSString *mine = TGStoryString(story, @"myReaction");
	NSInteger count = TGStoryNumber(story, @"reactions");
	NSInteger delta = 0;
	if (mine.length == 0 && value.length > 0)
		delta = 1;
	else if (mine.length > 0 && value.length == 0)
		delta = -1;

	NSMutableDictionary *patched = [story mutableCopy];
	[patched setObject:value forKey:@"myReaction"];
	[patched setObject:[NSNumber numberWithInteger:MAX(0, count + delta)] forKey:@"reactions"];
	[_stories setObject:patched forKey:[_storyIds objectAtIndex:(NSUInteger)_index]];
	[self updateChrome];
}

- (void)replyPressed {
	NSInteger storyId = [self currentStoryId];
	if (storyId == 0)
		return;

	int64_t chatId = _chatId;
	[self setModalPaused:YES];
	__weak TGStoriesViewController *weakSelf = self;
	TGAlertView *alert = nil;
	__block __weak TGAlertView *weakAlert = nil;
	alert = [[TGAlertView alloc] initWithTitle:nil
									   message:TGL(@"Notification.Reply", @"Reply")
							 cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
								 okButtonTitle:TGL(@"MediaPicker.Send", @"Send")
							   completionBlock:^(bool okButtonPressed) {
								   [weakSelf setModalPaused:NO];
								   if (!okButtonPressed)
									   return;
								   NSString *text = nil;
								   if ([weakAlert respondsToSelector:@selector(textFieldAtIndex:)])
									   text = [weakAlert textFieldAtIndex:0].text;
								   if (text.length == 0)
									   return;
								   [[TGClient shared] replyToStory:storyId
															 inChat:chatId
															   text:text
														 completion:^(BOOL ok) {
									   TGStoriesViewController *innerSelf = weakSelf;
									   if (!innerSelf)
										   return;
									   if (!ok) {
										   [[[TGAlertView alloc] initWithTitle:nil
																	   message:TGL(@"Toast.CouldNotSendMessage", @"Your message could not be sent.")
															 cancelButtonTitle:TGL(@"Common.OK", @"OK")
																 okButtonTitle:nil
															   completionBlock:nil] show];
										   return;
									   }
									   [TGSnackbar showInView:innerSelf.view
														  text:TGL(@"Story.ReplySent", @"Your reply was sent.")
													   seconds:2
													  onCommit:nil];
								   }];
							   }];
	weakAlert = alert;
	if ([alert respondsToSelector:@selector(setAlertViewStyle:)])
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	[alert show];
}

- (void)middlePressed {
	NSInteger storyId = [self currentStoryId];
	if (storyId == 0)
		return;

	NSDictionary *story = [self currentStory];
	if ([self isOwnStory] && (story == nil || TGStoryFlag(story, @"canGetViewers"))) {
		TGStoryViewersViewController *viewers = [[TGStoryViewersViewController alloc] init];
		viewers.storyId = storyId;
		viewers.chatId = _chatId;
		[self.navigationController pushViewController:viewers animated:YES];
		return;
	}

	NSString *mine = story != nil ? TGStoryString(story, @"myReaction") : @"";
	[self sendReaction:(mine.length > 0) ? @"" : @"❤"];
}

- (void)middleHeld:(UILongPressGestureRecognizer *)recognizer {
	if (recognizer.state != UIGestureRecognizerStateBegan)
		return;
	if ([self currentStoryId] == 0)
		return;

	NSDictionary *story = [self currentStory];
	if ([self isOwnStory] && (story == nil || TGStoryFlag(story, @"canGetViewers")))
		return;
	UIView *host = self.view;
	CGRect anchor = [host convertRect:_middleButton.bounds fromView:_middleButton];
	__weak TGStoriesViewController *weakSelf = self;

	[self setModalPaused:YES];
	[[TGClient shared] storyReactionsWithLimit:12 completion:^(NSArray *emoji) {
		TGStoriesViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		if (![emoji isKindOfClass:[NSArray class]] || emoji.count == 0) {
			[strongSelf setModalPaused:NO];
			return;
		}

		TGReactionPickerView *picker =
			[TGReactionPickerView showForMessage:0
										  inChat:0
										fromRect:anchor
										  inView:host
										  picked:^(NSString *chosen, BOOL nowChosen) {
											  (void)nowChosen;
											  TGStoriesViewController *innerSelf = weakSelf;
											  if (innerSelf == nil)
												  return;
											  [innerSelf setModalPaused:NO];
											  if (chosen.length > 0)
												  [innerSelf sendReaction:chosen];
										  }];
		if (picker == nil) {
			[strongSelf setModalPaused:NO];
			return;
		}
		strongSelf->_reactionPicker = picker;
		[picker setEmoji:emoji reason:nil];
	}];
}

- (void)sharePressed {
	if (_repostingStory)
		return;

	NSInteger storyId = [self currentStoryId];
	if (storyId == 0)
		return;

	NSDictionary *me = [[TGClient shared] me];
	if (me == nil)
		return;
	int64_t myId = TGStoryChatId(me, @"id");
	int64_t chatId = _chatId;

	_repostingStory = YES;
	__weak TGStoriesViewController *weakSelf = self;
	TGClient *client = [TGClient shared];
	[client repostStory:storyId
			   fromChat:chatId
				 asChat:myId
				caption:@""
				privacy:@"everyone"
			 completion:^(NSDictionary *repostedStory, NSString *error) {
				 TGStoriesViewController *strongSelf = weakSelf;
				 if (!strongSelf)
					 return;
				 strongSelf->_repostingStory = NO;
				 if (!repostedStory) {
					 [[[TGAlertView alloc] initWithTitle:nil
												 message:TGFriendlyErrorText(error,
														 TGL(@"Stories.CouldNotRepostThisStory",
															 @"Could not repost this story"))
										   cancelButtonTitle:TGL(@"Common.OK", @"OK")
											   okButtonTitle:nil
											 completionBlock:nil] show];
					 return;
				 }
				 [TGSnackbar showInView:strongSelf.view
									text:TGL(@"Story.MessageReposted.Personal", @"Message reposted to your stories.")
								 seconds:3
								onCommit:nil];
			 }];
}

- (NSMutableArray *)moreActions {
	NSDictionary *story = [self currentStory];
	NSMutableArray *actions = [[NSMutableArray alloc] init];

	if ([self currentImage] != nil) {
		TGActionSheetAction *saveAction = [TGActionSheetAction alloc];
		[actions addObject:[saveAction initWithTitle:TGL(@"Story.Context.SaveToGallery", @"Save to Gallery")
											  action:@"save"]];
	}

	if (![self isOwnStory])
		[self appendOtherPosterActionsTo:actions];

	NSString *hashtag = [self hashtagInCaption];
	if (hashtag.length > 0) {
		[actions addObject:[[TGActionSheetAction alloc]
							   initWithTitle:[NSString stringWithFormat:TGL(@"HashtagSearch.StoriesFoundInfo", @"View stories with %@"), hashtag]
									  action:@"hashtag"]];
	}

	[self appendStoryStateActionsTo:actions story:story];

	return actions;
}

- (void)appendOtherPosterActionsTo:(NSMutableArray *)actions {
	if ([self unreadStoryIds].count > 0) {
		TGActionSheetAction *readAction = [TGActionSheetAction alloc];
		[actions addObject:[readAction initWithTitle:TGL(@"ChatList.Context.MarkAllAsRead", @"Mark All as Read")
											  action:@"markread"]];
	}
	TGActionSheetAction *stealthAction = [TGActionSheetAction alloc];
	[actions addObject:[stealthAction initWithTitle:TGL(@"Premium.Stories.Stealth.Title", @"Stealth Mode")
											 action:@"stealth"]];
	[actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGL(@"StoryFeed.ContextArchive", @"Hide Stories") action:@"hide"]];
	[actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGL(@"ReportPeer.Report", @"Report") action:@"report"]];
}

- (void)appendStoryStateActionsTo:(NSMutableArray *)actions story:(NSDictionary *)story {
	if (story != nil && TGStoryFlag(story, @"canEdit")) {
		TGActionSheetAction *replaceAction = [TGActionSheetAction alloc];
		[actions addObject:[replaceAction initWithTitle:TGL(@"Story.Context.Edit", @"Edit Story")
												 action:@"replace"]];
	}

	if (story != nil && TGStoryFlag(story, @"canEdit") &&
		[story[@"kind"] isEqualToString:@"video"]) {
		TGActionSheetAction *coverAction = [TGActionSheetAction alloc];
		[actions addObject:[coverAction initWithTitle:TGL(@"Story.SaveCover", @"Set Current Frame as Cover")
											   action:@"cover"]];
	}

	if (story != nil && TGStoryFlag(story, @"canGetStatistics")) {
		TGActionSheetAction *statsAction = [TGActionSheetAction alloc];
		[actions addObject:[statsAction initWithTitle:TGL(@"Stats.Statistics", @"Statistics")
											   action:@"statistics"]];
	}

	if ([[TGClient shared] me] != nil) {
		TGActionSheetAction *myStoryAction = [TGActionSheetAction alloc];
		[actions addObject:[myStoryAction initWithTitle:TGL(@"Settings.MyStories", @"My Stories")
												 action:@"mystories"]];
	}

	if (story != nil && TGStoryFlag(story, @"canToggleProfile")) {
		NSString *title = TGStoryFlag(story, @"onProfile")
			? TGL(@"Story.Context.RemoveFromProfile", @"Remove from Profile")
			: TGL(@"Story.Context.SaveToProfile", @"Save to Profile");
		[actions addObject:[[TGActionSheetAction alloc] initWithTitle:title action:@"profile"]];
	}

	if (story != nil && TGStoryFlag(story, @"canSetPrivacy")) {
		TGActionSheetAction *privacyAction = [TGActionSheetAction alloc];
		[actions addObject:[privacyAction initWithTitle:TGL(@"Story.Context.Privacy", @"Who Can See")
												 action:@"privacy"]];
	}

	if (story != nil && TGStoryFlag(story, @"canDelete")) {
		TGActionSheetAction *delAction = [TGActionSheetAction alloc];
		[actions addObject:[delAction initWithTitle:TGL(@"Common.Delete", @"Delete")
											 action:@"delete"
											   type:TGActionSheetActionTypeDestructive]];
	}
}

- (void)morePressed {
	NSArray *actions = [self moreActions];

	if (actions.count == 0)
		return;

	[self setModalPaused:YES];
	__weak TGStoriesViewController *weakSelf = self;
	TGActionSheet *sheet = [TGActionSheet alloc];
	sheet = [sheet initWithTitle:nil
						 actions:actions
					 actionBlock:^(id target, NSString *action) {
						 (void)target;
						 [weakSelf performMoreAction:action];
					 }
						  target:self];
	[sheet tg_showFromRect:_actionButton.bounds inView:_actionButton];
}

- (void)askStoryPrivacy {
	NSInteger storyId = [self currentStoryId];
	if (storyId == 0)
		return;

	int64_t chatId = _chatId;
	[self setModalPaused:YES];
	__weak TGStoriesViewController *weakSelf = self;
	[[TGClient shared] storyWithId:storyId
							 inChat:chatId
						 completion:^(NSDictionary *story) {
							 TGStoriesViewController *strongSelf = weakSelf;
							 if (strongSelf == nil)
								 return;
							 [strongSelf presentStoryPrivacySheetForStoryId:storyId
																  exceptUserIds:[story objectForKey:@"privacyExceptUserIds"]
																selectedUserIds:[story objectForKey:@"privacyUserIds"]];
						 }];
}

- (void)presentStoryPrivacySheetForStoryId:(NSInteger)storyId
							  exceptUserIds:(NSArray *)exceptUserIds
							selectedUserIds:(NSArray *)selectedUserIds {
	NSArray *titles = [NSArray arrayWithObjects:
			TGL(@"Story.Privacy.CategoryEveryone", @"Everyone"),
			TGL(@"Story.Privacy.CategoryContacts", @"Contacts"),
			TGL(@"Story.Privacy.CategoryCloseFriends", @"Close Friends"),
			TGL(@"Story.Privacy.CategorySelectedContacts", @"Selected Contacts"), nil];
	NSArray *values = [NSArray arrayWithObjects:
			@"everyone", @"contacts", @"closeFriends", @"selected", nil];

	NSMutableArray *actions = [[NSMutableArray alloc] init];
	for (NSString *title in titles)
		[actions addObject:[[TGActionSheetAction alloc] initWithTitle:title action:title]];

	[self setModalPaused:YES];
	__weak TGStoriesViewController *weakSelf = self;
	TGActionSheet *sheet = [TGActionSheet alloc];
	sheet = [sheet initWithTitle:TGL(@"Story.Context.Privacy", @"Who Can See")
						 actions:actions
					 actionBlock:^(id target, NSString *action) {
						 (void)target;
						 TGStoriesViewController *strongSelf = weakSelf;
						 if (strongSelf == nil)
							 return;
						 NSInteger index = [titles indexOfObject:action];
						 if (index == NSNotFound) {
							 [strongSelf setModalPaused:NO];
							 return;
						 }
						 NSString *privacy = [values objectAtIndex:index];
						 if (![privacy isEqualToString:@"selected"]) {
							 [strongSelf setModalPaused:NO];
							 [[TGClient shared] setStory:storyId
												  privacy:privacy
												  userIds:exceptUserIds
											   completion:^(BOOL ok) {
												   if (ok)
													   return;
												   [[[TGAlertView alloc] initWithTitle:nil
															   message:TGL(@"Privacy.TheSettingCouldNotBeChanged", @"That setting could not be changed.")
													 cancelButtonTitle:TGL(@"Common.OK", @"OK")
														 okButtonTitle:nil
													   completionBlock:nil] show];
											   }];
							 return;
						 }

						 [TGStoryContactPicker presentFrom:strongSelf
													 title:TGL(@"Story.Privacy.CategorySelectedContacts", @"Selected Contacts")
											   preselected:selectedUserIds
													picked:^(NSArray *userIds) {
														TGStoriesViewController *innerSelf = weakSelf;
														if (innerSelf == nil)
															return;
														[innerSelf setModalPaused:NO];
														if (userIds.count == 0)
															return;
														[[TGClient shared] setStory:storyId
																			 privacy:@"selected"
																			 userIds:userIds
																		  completion:^(BOOL ok) {
																			  if (ok)
																				  return;
																			  [[[TGAlertView alloc] initWithTitle:nil
																						  message:TGL(@"Privacy.TheSettingCouldNotBeChanged", @"That setting could not be changed.")
																			cancelButtonTitle:TGL(@"Common.OK", @"OK")
																					okButtonTitle:nil
																			  completionBlock:nil] show];
																		  }];
													}];
					 }
						  target:self];
	[sheet tg_showFromRect:_actionButton.bounds inView:_actionButton];
}

- (void)performMoreAction:(NSString *)action {
	[self setModalPaused:NO];

	NSInteger storyId = [self currentStoryId];
	if (storyId == 0)
		return;

	if ([action isEqualToString:@"save"]) {
		[self saveCurrentImageToPhotos];
		return;
	}

	if ([action isEqualToString:@"profile"]) {
		[self toggleOnProfileForStoryId:storyId];
		return;
	}

	if ([action isEqualToString:@"privacy"]) {
		[self askStoryPrivacy];
		return;
	}

	if ([action isEqualToString:@"hide"]) {
		[self hideStoriesFromCurrentPoster];
		return;
	}

	if ([action isEqualToString:@"delete"]) {
		[self confirmDeleteStoryId:storyId];
		return;
	}

	if ([action isEqualToString:@"report"]) {
		_reportStoryId = storyId;
		_reportChatId = _chatId;
		[self setModalPaused:YES];
		[self reportWithOptionId:nil text:nil];
		return;
	}

	if ([action isEqualToString:@"markread"]) {
		[self markRemainingRead];
		return;
	}

	if ([action isEqualToString:@"hashtag"]) {
		[self openHashtagSearch];
		return;
	}

	if ([action isEqualToString:@"replace"]) {
		[self replacePhoto];
		return;
	}

	if ([action isEqualToString:@"mystories"]) {
		[self openMyStories];
		return;
	}

	if ([action isEqualToString:@"stealth"]) {
		[self activateStealthMode];
		return;
	}

	if ([action isEqualToString:@"cover"]) {
		[self askCoverFrameChoice];
		return;
	}

	if ([action isEqualToString:@"statistics"]) {
		[self openStoryStatistics];
		return;
	}
}

- (void)activateStealthMode {
	[self setModalPaused:YES];
	__weak TGStoriesViewController *weakSelf = self;
	[[TGClient shared] activateStoryStealthModeWithCompletion:^(BOOL ok) {
		TGStoriesViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		[strongSelf setModalPaused:NO];
		NSString *message = ok
			? TGL(@"Stories.StealthModeActivatedInfo",
				  @"Your recent views are hidden and you won't leave new ones for a while.")
			: TGL(@"Story.StealthMode.UpgradeText",
				  @"Subscribe to Telegram Premium to hide the fact that you viewed peoples' stories from them.");
		[[[TGAlertView alloc] initWithTitle:TGL(@"Premium.Stories.Stealth.Title", @"Stealth Mode") message:message
						  cancelButtonTitle:TGL(@"Common.OK", @"OK")
							  okButtonTitle:nil
							completionBlock:nil] show];
	}];
}

- (void)askCoverFrameChoice {
	NSDictionary *story = [self currentStory];
	NSInteger storyId = [self currentStoryId];
	double duration = (double)TGStoryNumber(story, @"duration");
	if (storyId == 0 || duration <= 0)
		return;

	NSArray *titles = [NSArray arrayWithObjects:@"Start", @"25%", @"Middle", @"75%", @"End", nil];
	NSArray *fractions = [NSArray arrayWithObjects:@0.0, @0.25, @0.5, @0.75, @0.98, nil];

	NSMutableArray *actions = [[NSMutableArray alloc] init];
	for (NSString *title in titles)
		[actions addObject:[[TGActionSheetAction alloc] initWithTitle:title action:title]];

	[self setModalPaused:YES];
	int64_t chatId = _chatId;
	__weak TGStoriesViewController *weakSelf = self;
	TGActionSheet *sheet = [TGActionSheet alloc];
	sheet = [sheet initWithTitle:TGL(@"Story.Privacy.ChooseCoverInfo", @"Set the story's cover frame")
						 actions:actions
					 actionBlock:^(id target, NSString *action) {
						 (void)target;
						 TGStoriesViewController *strongSelf = weakSelf;
						 if (strongSelf == nil)
							 return;
						 [strongSelf setModalPaused:NO];
						 NSInteger index = [titles indexOfObject:action];
						 if (index == NSNotFound)
							 return;
						 double timestamp = duration * [[fractions objectAtIndex:index] doubleValue];
						 TGClient *client = [TGClient shared];
						 [client editStoryCover:storyId
										  inChat:chatId
							 coverFrameTimestamp:timestamp
									  completion:^(BOOL ok) {
							 if (ok)
								 return;
							 [[[TGAlertView alloc] initWithTitle:nil
														 message:TGL(@"Toast.CouldNotEditStory", @"Could not edit this story")
											   cancelButtonTitle:TGL(@"Common.OK", @"OK")
												   okButtonTitle:nil
												 completionBlock:nil] show];
						 }];
					 }
						  target:self];
	[sheet tg_showFromRect:_actionButton.bounds inView:_actionButton];
}

- (void)openStoryStatistics {
	NSInteger storyId = [self currentStoryId];
	int64_t chatId = _chatId;
	if (storyId == 0 || chatId == 0)
		return;

	TGStoryStatisticsViewController *stats = [[TGStoryStatisticsViewController alloc] init];
	stats.chatId = chatId;
	stats.storyId = storyId;
	if (self.navigationController)
		[self.navigationController pushViewController:stats animated:YES];
}

- (void)saveCurrentImageToPhotos {
	NSDictionary *story = [self currentStory];
	if ([TGStoryString(story, @"kind") isEqualToString:@"video"]) {
		NSString *path = [self pageForIndex:_index].videoPath;
		if (!path.length) {
			[self reportStorySaveFailed];
			return;
		}
		if (!UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(path)) {
			[[[TGAlertView alloc] initWithTitle:nil
										 message:TGL(@"Chat.ThisVideoCannotBeSaved", @"This video cannot be saved.")
							   cancelButtonTitle:TGL(@"Common.OK", @"OK")
								   okButtonTitle:nil
								 completionBlock:nil] show];
			return;
		}
		UISaveVideoAtPathToSavedPhotosAlbum(path, self,
			@selector(video:didFinishSavingWithError:contextInfo:), NULL);
		return;
	}

	UIImage *image = [self currentImage];
	if (image == nil)
		return;
	UIImageWriteToSavedPhotosAlbum(image, self,
		@selector(image:didFinishSavingWithError:contextInfo:), NULL);
}

- (void)reportStorySaveFailed {
	[[[TGAlertView alloc] initWithTitle:nil
								message:TGL(@"Toast.CouldNotSaveMedia", @"Could not save")
					  cancelButtonTitle:TGL(@"Common.OK", @"OK")
						  okButtonTitle:nil
						completionBlock:nil] show];
}

- (void)reportStorySaveFinishedWithError:(NSError *)error {
	if (error) {
		[self reportStorySaveFailed];
		return;
	}
	[TGSnackbar showInView:self.view
					   text:TGL(@"WebApp.Download.SavedToPhotos", @"Saved to Camera Roll")
					seconds:3
				   onCommit:nil];
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
	[self reportStorySaveFinishedWithError:error];
}

- (void)video:(NSString *)path didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
	[self reportStorySaveFinishedWithError:error];
}

- (void)hideStoriesFromCurrentPoster {
	int64_t chatId = _chatId;
	BOOL isChat = chatId < 0;
	__weak TGStoriesViewController *weakSelf = self;
	[[TGClient shared] setStorySender:chatId
							   isChat:isChat
						storiesHidden:YES
						   completion:^(BOOL ok) {
		TGStoriesViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[[[TGAlertView alloc] initWithTitle:nil
										message:TGL(@"Toast.CouldNotHideStories", @"Could not hide this account's stories")
							  cancelButtonTitle:TGL(@"Common.OK", @"OK")
								  okButtonTitle:nil
								completionBlock:nil] show];
			return;
		}
		[strongSelf.navigationController popViewControllerAnimated:YES];
	}];
}

- (void)toggleOnProfileForStoryId:(NSInteger)storyId {
	NSDictionary *story = [self currentStory];
	BOOL onProfile = !TGStoryFlag(story, @"onProfile");
	NSNumber *key = [self currentStoryKey];
	int64_t chatId = _chatId;

	if (story != nil) {
		NSMutableDictionary *patched = [story mutableCopy];
		[patched setObject:[NSNumber numberWithBool:onProfile] forKey:@"onProfile"];
		[_stories setObject:patched forKey:key];
		[self updateChrome];
	}

	__weak TGStoriesViewController *weakSelf = self;
	[[TGClient shared] setStory:storyId
						  inChat:chatId
					   onProfile:onProfile
					  completion:^(BOOL ok) {
						  if (ok)
							  return;
						  TGStoriesViewController *strongSelf = weakSelf;
						  if (strongSelf == nil || strongSelf->_chatId != chatId)
							  return;
						  if (story != nil) {
							  [strongSelf->_stories setObject:story forKey:key];
							  [strongSelf updateChrome];
						  }
						  [[[TGAlertView alloc] initWithTitle:nil
													  message:TGL(@"Privacy.TheSettingCouldNotBeChanged", @"That setting could not be changed.")
											cancelButtonTitle:TGL(@"Common.OK", @"OK")
												okButtonTitle:nil
											  completionBlock:nil] show];
					  }];
}

- (void)confirmDeleteStoryId:(NSInteger)storyId {
	int64_t chatId = _chatId;
	__weak TGStoriesViewController *weakSelf = self;
	[[[TGAlertView alloc] initWithTitle:nil
								message:TGLPlural(@"StoryList.DeleteConfirmation.Title", 1, @"Delete 1 story?", @"Delete %@ stories?")
					  cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
						  okButtonTitle:TGL(@"Common.Delete", @"Delete")
						completionBlock:^(bool okButtonPressed) {
							if (!okButtonPressed)
								return;
							[[TGClient shared] deleteStory:storyId
													 inChat:chatId
												 completion:^(BOOL ok) {
								TGStoriesViewController *strongSelf = weakSelf;
								if (!strongSelf)
									return;
								if (!ok) {
									[[[TGAlertView alloc] initWithTitle:nil
																message:TGL(@"Toast.CouldNotDeleteStory", @"Could not delete this story")
													  cancelButtonTitle:TGL(@"Common.OK", @"OK")
														  okButtonTitle:nil
														completionBlock:nil] show];
									return;
								}
								[strongSelf.navigationController popViewControllerAnimated:YES];
							}];
						}] show];
}

- (void)openHashtagSearch {
	NSString *hashtag = [self hashtagInCaption];
	if (hashtag.length == 0 || self.navigationController == nil)
		return;
	TGStoryListViewController *list = [[TGStoryListViewController alloc] init];
	list.mode = TGStoryListTag;
	list.tag = hashtag;
	list.title = [NSString stringWithFormat:@"#%@", hashtag];
	[self.navigationController pushViewController:list animated:YES];
}

- (void)openVenueSearchWithProvider:(NSString *)provider venueId:(NSString *)venueId title:(NSString *)title {
	if (provider.length == 0 || venueId.length == 0 || self.navigationController == nil)
		return;
	TGStoryListViewController *list = [[TGStoryListViewController alloc] init];
	list.mode = TGStoryListVenue;
	list.venueProvider = provider;
	list.venueId = venueId;
	list.title = title.length > 0 ? title : TGL(@"StoryGridScreen.TitleLocationSearch", @"Location");
	[self.navigationController pushViewController:list animated:YES];
}

- (void)openMyStories {
	NSDictionary *me = [[TGClient shared] me];
	if (me == nil)
		return;
	[TGStoryListViewController pushMode:TGStoryListMenu
								 chatId:TGStoryChatId(me, @"id")
								  title:TGL(@"StoryList.TitleSaved", @"My Stories")
								   from:self];
}

- (NSArray *)unreadStoryIds {
	NSMutableArray *unread = [[NSMutableArray alloc] init];
	for (NSNumber *key in _storyIds) {
		if (![_seen containsObject:key])
			[unread addObject:key];
	}
	return unread;
}

- (void)markRemainingRead {
	NSArray *unread = [self unreadStoryIds];
	for (NSNumber *key in unread) {
		[[TGClient shared] markStoryRead:[key integerValue] inChat:_chatId];
		[_seen addObject:key];
	}
	[self updateStrip];
}

- (void)replacePhoto {
	if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
		[[[TGAlertView alloc] initWithTitle:nil
									message:TGL(@"Toast.NoPhotoLibrary", @"No photo library")
						  cancelButtonTitle:TGL(@"Common.OK", @"OK")
							  okButtonTitle:nil
							completionBlock:nil] show];
		return;
	}

	[self setModalPaused:YES];
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	picker.allowsEditing = YES;
	picker.delegate = self;
	[self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	(void)picker;
	[self dismissViewControllerAnimated:YES completion:nil];
	[self setModalPaused:NO];
}

- (void)imagePickerController:(UIImagePickerController *)picker
	didFinishPickingMediaWithInfo:(NSDictionary *)info {
	(void)picker;
	[self dismissViewControllerAnimated:YES completion:nil];
	[self setModalPaused:NO];

	NSInteger storyId = [self currentStoryId];
	if (storyId == 0)
		return;

	UIImage *image = [info objectForKey:UIImagePickerControllerEditedImage];
	if (![image isKindOfClass:[UIImage class]])
		image = [info objectForKey:UIImagePickerControllerOriginalImage];
	if (![image isKindOfClass:[UIImage class]])
		return;

	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"storyedit.jpg"];
	BOOL written = NO;

	@autoreleasepool {
		CGFloat side = MAX(image.size.width, image.size.height);
		UIImage *scaled = image;
		if (side > 720.0f) {
			CGFloat factor = 720.0f / side;
			CGSize target = CGSizeMake(floorf(image.size.width * factor),
				floorf(image.size.height * factor));
			UIGraphicsBeginImageContextWithOptions(target, YES, 1.0f);
			[image drawInRect:CGRectMake(0, 0, target.width, target.height)];
			scaled = UIGraphicsGetImageFromCurrentImageContext();
			UIGraphicsEndImageContext();
		}
		image = nil;

		NSData *data = UIImageJPEGRepresentation(scaled, 0.87f);
		scaled = nil;
		if (data.length != 0)
			written = [data writeToFile:path atomically:YES];
	}

	if (!written) {
		[[[TGAlertView alloc] initWithTitle:nil
									message:TGL(@"Toast.CouldNotPreparePhoto", @"Could not prepare the photo")
						  cancelButtonTitle:TGL(@"Common.OK", @"OK")
							  okButtonTitle:nil
							completionBlock:nil] show];
		return;
	}

	[self applyReplacementPhotoAtPath:path forStoryId:storyId];
}

- (void)applyReplacementPhotoAtPath:(NSString *)path forStoryId:(NSInteger)storyId {
	NSDictionary *story = [self currentStory];
	NSString *caption = story != nil ? TGStoryString(story, @"caption") : @"";
	NSNumber *key = [self currentStoryKey];
	int64_t chatId = _chatId;
	__weak TGStoriesViewController *weakSelf = self;
	[[TGClient shared] editStory:storyId
						   inChat:chatId
						photoPath:path
						  caption:caption
					   completion:^(BOOL ok) {
		TGStoriesViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (!ok) {
			[[[TGAlertView alloc] initWithTitle:nil
										message:TGL(@"Toast.CouldNotEditStory", @"Could not edit this story")
							  cancelButtonTitle:TGL(@"Common.OK", @"OK")
								  okButtonTitle:nil
								completionBlock:nil] show];
			return;
		}
		[[TGClient shared] storyWithId:storyId inChat:chatId completion:^(NSDictionary *updated) {
			TGStoriesViewController *innerSelf = weakSelf;
			if (innerSelf == nil || key == nil || innerSelf->_chatId != chatId)
				return;
			if (![updated isKindOfClass:[NSDictionary class]])
				return;
			[innerSelf->_stories setObject:updated forKey:key];
			TGStoryPage *page = [innerSelf pageForIndex:innerSelf->_index];
			if (page != nil && [page.itemId isEqual:key]) {
				[page setCaption:TGStoryString(updated, @"caption")];
				[page setAreas:[updated objectForKey:@"areas"]];
				[innerSelf loadPhotoForPage:page story:updated];
			}
			[innerSelf updateChrome];
		}];
	}];
}

- (void)reportWithOptionId:(NSString *)optionId text:(NSString *)text {
	NSInteger storyId = _reportStoryId;
	int64_t chatId = _reportChatId;
	if (storyId == 0)
		return;

	__weak TGStoriesViewController *weakSelf = self;
	[[TGClient shared] reportStory:storyId
							inChat:chatId
						  optionId:optionId
							  text:text
						completion:^(NSDictionary *result) {
							TGStoriesViewController *strongSelf = weakSelf;
							if (strongSelf == nil)
								return;
							[strongSelf handleReportResult:result];
						}];
}

- (void)handleReportResult:(NSDictionary *)result {
	NSString *status = TGStoryString(result, @"status");

	if ([status isEqualToString:@"ok"]) {
		[self setModalPaused:NO];
		[[[TGAlertView alloc] initWithTitle:nil
									message:TGL(@"Report.Succeed", @"Telegram moderators will study your report. Thank you!")
						  cancelButtonTitle:TGL(@"Common.OK", @"OK")
							  okButtonTitle:nil
							completionBlock:nil] show];
		return;
	}

	if ([status isEqualToString:@"option"]) {
		[self presentReportOptions:result];
		return;
	}

	if ([status isEqualToString:@"text"]) {
		NSString *optionId = TGStoryString(result, @"optionId");
		BOOL optional = TGStoryFlag(result, @"optional");
		[self askReportCommentWithOptionId:optionId optional:optional];
		return;
	}

	[self setModalPaused:NO];
	[[[TGAlertView alloc] initWithTitle:nil
								message:TGL(@"Stories.CouldNotReportThisStory", @"Could not report this story")
					  cancelButtonTitle:TGL(@"Common.OK", @"OK")
						  okButtonTitle:nil
						completionBlock:nil] show];
}

- (void)presentReportOptions:(NSDictionary *)result {
	NSArray *rawOptions = [result objectForKey:@"options"];
	if (![rawOptions isKindOfClass:[NSArray class]] || rawOptions.count == 0) {
		[self setModalPaused:NO];
		return;
	}

	NSMutableArray *actions = [[NSMutableArray alloc] init];
	NSMutableArray *validOptions = [[NSMutableArray alloc] init];
	NSString *actionPrefix = @"report-option-";
	for (NSDictionary *option in rawOptions) {
		if (![option isKindOfClass:[NSDictionary class]])
			continue;
		NSString *title = TGStoryString(option, @"text");
		if (title.length == 0)
			continue;
		NSString *action = [actionPrefix stringByAppendingFormat:@"%lu", (unsigned long)validOptions.count];
		[validOptions addObject:option];
		[actions addObject:[[TGActionSheetAction alloc] initWithTitle:title action:action]];
	}
	if (actions.count == 0) {
		[self setModalPaused:NO];
		return;
	}

	__weak TGStoriesViewController *weakSelf = self;
	TGActionSheet *sheet = [TGActionSheet alloc];
	sheet = [sheet initWithTitle:TGStoryString(result, @"title")
						 actions:actions
					 actionBlock:^(id target, NSString *action) {
						 (void)target;
						 TGStoriesViewController *strongSelf = weakSelf;
						 if (strongSelf == nil)
							 return;
						 if (![action hasPrefix:actionPrefix]) {
							 [strongSelf setModalPaused:NO];
							 return;
						 }
						 NSInteger index = [[action substringFromIndex:actionPrefix.length] integerValue];
						 if (index < 0 || index >= (NSInteger)validOptions.count) {
							 [strongSelf setModalPaused:NO];
							 return;
						 }
						 NSString *identifier = TGStoryString([validOptions objectAtIndex:(NSUInteger)index], @"id");
						 [strongSelf reportWithOptionId:identifier text:nil];
					 }
						  target:self];
	[sheet tg_showFromRect:_actionButton.bounds inView:_actionButton];
}

- (void)askReportCommentWithOptionId:(NSString *)optionId optional:(BOOL)optional {
	__weak TGStoriesViewController *weakSelf = self;
	TGAlertView *alert = nil;
	__block __weak TGAlertView *weakAlert = nil;
	NSString *cancelTitle = optional ? TGL(@"PhotoEditor.Skip", @"Skip") : TGL(@"Common.Cancel", @"Cancel");
	alert = [[TGAlertView alloc] initWithTitle:nil
									   message:TGL(@"ShareMenu.Comment", @"Add a comment")
							 cancelButtonTitle:cancelTitle
								 okButtonTitle:TGL(@"MediaPicker.Send", @"Send")
							   completionBlock:^(bool okButtonPressed) {
								   TGStoriesViewController *strongSelf = weakSelf;
								   if (strongSelf == nil)
									   return;
								   if (!okButtonPressed) {
									   if (optional)
										   [strongSelf reportWithOptionId:optionId text:@""];
									   else
										   [strongSelf setModalPaused:NO];
									   return;
								   }
								   NSString *text = nil;
								   if ([weakAlert respondsToSelector:@selector(textFieldAtIndex:)])
									   text = [weakAlert textFieldAtIndex:0].text;
								   [strongSelf reportWithOptionId:optionId text:(text ?: @"")];
							   }];
	weakAlert = alert;
	if ([alert respondsToSelector:@selector(setAlertViewStyle:)])
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	[alert show];
}

@end

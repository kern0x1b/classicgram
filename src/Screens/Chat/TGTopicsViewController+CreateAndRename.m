#import "TGTopicsViewController.h"
#import "TGLocalization.h"
#import "TGEmoji.h"
#import "TGChatViewController.h"
#import "TGClient.h"
#import "TGClient+Forums.h"
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

@implementation TGTopicsViewController (CreateAndRename)

#pragma mark - create and rename

- (void)newTopicPressed {
	if (!self.canCreateTopics)
		return;

	NSArray *colours = [[TGClient shared] forumTopicIconColors];
	if (![colours isKindOfClass:[NSArray class]])
		colours = @[];

	TGTopicComposeController *compose = [[TGTopicComposeController alloc] init];
	compose.colours = colours;
	compose.selectedColour = colours.count ? [colours[0] integerValue] : 0;

	__weak typeof(self) weakSelf = self;
	compose.onCreate = ^(NSString *name, NSInteger colour) {
		TGTopicsViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.pendingColour = colour;
		strongSelf.pendingName = name;
		[strongSelf.navigationController popToViewController:strongSelf animated:YES];
		[strongSelf performSelector:@selector(chooseIconForPendingName) withObject:nil afterDelay:0.35];
	};

	[self.navigationController pushViewController:compose animated:YES];
}

- (void)askTopicNameForEdit:(NSDictionary *)topic {
	self.actionTopic = topic;
	UIAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:TGL(@"CreateTopic.EditTitle", @"Edit Topic")
						 message:TGL(@"CreateTopic.EnterTopicTitle", @"Name the topic.")
						delegate:self
			   cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
			   otherButtonTitles:TGL(@"Conversation.LinkDialogSave", @"Save"), nil];
	alert.tag = kTopicNameAlertEdit;
	if ([alert respondsToSelector:@selector(setAlertViewStyle:)]) {
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
		[alert textFieldAtIndex:0].text = TGTopicString(topic, @"name");
	}
	[alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex == alertView.cancelButtonIndex) {
		self.actionTopic = nil;
		return;
	}

	if (alertView.tag == kTopicDeleteAlert) {
		NSDictionary *t = self.actionTopic;
		self.actionTopic = nil;
		int32_t topicId = [self topicIdOf:t];
		if (topicId == 0 || self.deletingTopic)
			return;
		self.deletingTopic = YES;
		__weak typeof(self) weakSelf = self;
		[[TGClient shared] deleteForumTopicInChat:self.chatId topic:topicId
									   completion:^(BOOL success) {
										   TGTopicsViewController *strongSelf = weakSelf;
										   if (!strongSelf)
											   return;
										   strongSelf.deletingTopic = NO;
										   if (!success)
											   [strongSelf showError:TGL(@"Topics.CouldNotDelete", @"Could not delete the topic.")];
										   [strongSelf reloadTopics];
									   }];
		return;
	}

	if (![alertView respondsToSelector:@selector(textFieldAtIndex:)])
		return;

	NSString *name = [[alertView textFieldAtIndex:0].text
		stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (name.length == 0) {
		[self showError:TGL(@"Topics.NameRequired", @"The topic needs a name.")];
		return;
	}

	if (alertView.tag == kTopicNameAlertEdit)
		[self chooseIconForName:name editing:YES];
}

- (NSArray *)availableIconChoices {
	NSMutableArray *clean = [NSMutableArray array];
	for (id icon in self.iconChoices) {
		if (![icon isKindOfClass:NSDictionary.class])
			continue;
		NSString *emoji = [icon[@"emoji"] isKindOfClass:NSString.class] ? icon[@"emoji"] : nil;
		if (!emoji.length)
			continue;
		[clean addObject:icon];
		if (clean.count >= 8)
			break;
	}
	return clean;
}

- (void)chooseIconForPendingName {
	NSString *name = self.pendingName;
	self.pendingName = nil;
	if (name.length)
		[self chooseIconForName:name editing:NO];
}

- (void)chooseIconForName:(NSString *)name editing:(BOOL)editing {
	NSArray *icons = [self availableIconChoices];
	NSMutableArray *actions = [NSMutableArray array];

	[actions addObject:[[TGActionSheetAction alloc]
						   initWithTitle:(editing ? TGL(@"Topics.KeepIcon", @"Keep Icon") : TGL(@"Topics.NoIcon", @"No Icon"))
								  action:@"none"]];

	for (NSInteger i = 0; i < icons.count; i++) {
		NSDictionary *icon = icons[i];
		[actions addObject:[[TGActionSheetAction alloc]
							   initWithTitle:icon[@"emoji"]
									  action:[NSString stringWithFormat:@"icon%lu", (unsigned long)i]]];
	}

	if (editing)
		[actions addObject:[[TGActionSheetAction alloc]
							   initWithTitle:TGL(@"Topics.ColourOnly", @"Colour Only")
									  action:@"clear"]];

	TGActionSheetAction *cancelAction = [TGActionSheetAction alloc];
	cancelAction = [cancelAction initWithTitle:TGL(@"Common.Cancel", @"Cancel")
										action:@"cancel"
										  type:TGActionSheetActionTypeCancel];
	[actions addObject:cancelAction];

	__weak typeof(self) weakSelf = self;
	TGActionSheet *sheet = [TGActionSheet alloc];
	sheet = [sheet initWithTitle:nil
						 actions:actions
					 actionBlock:^(id target, NSString *action) {
						 TGTopicsViewController *strongSelf = weakSelf;
						 strongSelf.currentActionSheet = nil;
						 if (!strongSelf)
							 return;
						 if ([action isEqualToString:@"cancel"]) {
							 strongSelf.actionTopic = nil;
							 return;
						 }

						 int64_t emojiId = 0;
						 BOOL changeIcon = YES;
						 if ([action isEqualToString:@"none"])
							 changeIcon = !editing;
						 else if (![action isEqualToString:@"clear"]) {
							 NSInteger index = [[action substringFromIndex:4] integerValue];
							 if (index >= 0 && index < (NSInteger)icons.count)
								 emojiId = TGTopicLongLong(icons[(NSUInteger)index], @"emojiId");
						 }

						 if (editing)
							 [strongSelf commitEditWithName:name changeIcon:changeIcon iconEmojiId:emojiId];
						 else
							 [strongSelf commitCreateWithName:name iconEmojiId:emojiId];
					 }
						  target:self];
	self.currentActionSheet = sheet;

	UIView *view = self.navigationController.view;
	[self.currentActionSheet tg_showFromRect:CGRectMake(CGRectGetMidX(view.bounds), CGRectGetMidY(view.bounds), 1, 1) inView:view];
}

- (NSInteger)iconColourForName:(NSString *)name {
	NSArray *colours = [[TGClient shared] forumTopicIconColors];
	if (![colours isKindOfClass:[NSArray class]] || colours.count == 0)
		return 0;
	NSInteger index = (NSUInteger)labs((long)name.hash) % colours.count;
	id colour = colours[index];
	return [colour isKindOfClass:[NSNumber class]] ? [colour integerValue] : 0;
}

- (void)commitCreateWithName:(NSString *)name iconEmojiId:(int64_t)emojiId {
	NSInteger colour = self.pendingColour > 0
		? self.pendingColour
		: [self iconColourForName:name];
	self.pendingColour = 0;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] createForumTopicInChat:self.chatId
										 name:name
									iconColor:colour
								  iconEmojiId:emojiId
								   completion:^(NSDictionary *topic) {
									   if (!topic)
										   [weakSelf showError:TGL(@"Topics.CouldNotCreate", @"Could not create the topic.")];
									   [weakSelf reloadTopics];
								   }];
}

- (void)commitEditWithName:(NSString *)name changeIcon:(BOOL)changeIcon iconEmojiId:(int64_t)emojiId {
	NSDictionary *t = self.actionTopic;
	if (!t)
		return;

	int32_t topicId = [self topicIdOf:t];
	self.actionTopic = nil;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] editForumTopicInChat:self.chatId
									  topic:topicId
									   name:name
								 changeIcon:changeIcon
								iconEmojiId:emojiId
								 completion:^(BOOL success) {
									 if (!success)
										 [weakSelf showError:TGL(@"Topics.CouldNotEdit", @"Could not edit the topic.")];
									 [weakSelf reloadTopics];
								 }];
}

@end

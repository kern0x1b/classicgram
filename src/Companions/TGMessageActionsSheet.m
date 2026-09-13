#import "TGMessageActionsSheet.h"
#import "TGLocalization.h"
#import "TGInAppNotificationPreferences.h"
#import "TGPopupMenu.h"
#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "TGClient+Messages.h"
#import "TGClient+SecretChats.h"

NSString *const TGMessageActionReact = @"react";
NSString *const TGMessageActionReply = @"reply";
NSString *const TGMessageActionQuote = @"quote";
NSString *const TGMessageActionEdit = @"edit";
NSString *const TGMessageActionCopy = @"copy";
NSString *const TGMessageActionSelectText = @"selectText";
NSString *const TGMessageActionCopyLink = @"copyLink";
NSString *const TGMessageActionForward = @"forward";
NSString *const TGMessageActionSaveImage = @"saveImage";
NSString *const TGMessageActionSaveVideo = @"saveVideo";
NSString *const TGMessageActionSaveGif = @"saveGif";
NSString *const TGMessageActionPin = @"pin";
NSString *const TGMessageActionUnpin = @"unpin";
NSString *const TGMessageActionTranslate = @"translate";
NSString *const TGMessageActionSummarize = @"summarize";
NSString *const TGMessageActionTranscribe = @"transcribe";
NSString *const TGMessageActionSelect = @"select";
NSString *const TGMessageActionDeleteForMe = @"deleteForMe";
NSString *const TGMessageActionDeleteForEveryone = @"deleteForEveryone";
NSString *const TGMessageActionReport = @"report";
NSString *const TGMessageActionSeenBy = @"seenBy";
NSString *const TGMessageActionViewAuthor = @"viewAuthor";
NSString *const TGMessageActionFactCheck = @"factCheck";
NSString *const TGMessageActionApprovePost = @"approvePost";
NSString *const TGMessageActionDeclinePost = @"declinePost";
NSString *const TGMessageActionSuggestPost = @"suggestPost";
NSString *const TGMessageActionSuggestPostEditMessage = @"suggestPostEditMessage";
NSString *const TGMessageActionSetNotificationSound = @"setNotificationSound";

static NSString *const TGMessageActionDeleteRow = @"deleteRow";

@interface TGMessageActionsSheet ()
@property (nonatomic, strong) NSArray *actionIds;
@property (nonatomic, strong) TGActionSheet *currentActionSheet;
@property (nonatomic, weak) UIView *hostView;
@property (nonatomic, copy) void (^completion)(NSString *action);
@property (nonatomic, assign) BOOL presenting;
@property (nonatomic, assign) BOOL finished;
@property (nonatomic, assign) BOOL canDeleteForMe;
@property (nonatomic, assign) BOOL canDeleteForEveryone;
@property (nonatomic, assign) BOOL confirming;
@property (nonatomic, assign) BOOL resolvedPinned;
@property (nonatomic, assign) NSInteger viewerCount;
@property (nonatomic, assign, readwrite) BOOL canGetViewers;
@property (nonatomic, assign, readwrite) BOOL canGetReadDate;
@property (nonatomic, weak) UIView *menuView;
@end

@implementation TGMessageActionsSheet

+ (instancetype)sheetForMessage:(int64_t)messageId inChat:(int64_t)chatId {
	TGMessageActionsSheet *sheet = [[TGMessageActionsSheet alloc] init];
	sheet.messageId = messageId;
	sheet.chatId = chatId;
	return sheet;
}

- (instancetype)init {
	self = [super init];
	if (self != nil)
		_allowsSelection = YES;
	return self;
}

- (void)dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
}

#pragma mark - presenting

- (void)presentAtPoint:(CGPoint)point
				inView:(UIView *)host
			completion:(void (^)(NSString *action))completion {
	if (self.presenting || host == nil || self.messageId == 0 || self.chatId == 0) {
		if (completion)
			completion(nil);
		return;
	}

	self.presenting = YES;
	self.finished = NO;
	self.hostView = host;
	self.completion = completion;
	self.confirming = NO;
	self.resolvedPinned = self.pinned;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] propertiesOfMessage:self.messageId
									inChat:self.chatId
								completion:^(NSDictionary *properties) {
									dispatch_async(dispatch_get_main_queue(), ^{
										__strong typeof(weakSelf) strongSelf = weakSelf;
										if (strongSelf == nil || strongSelf.finished)
											return;
										if ([properties isKindOfClass:NSDictionary.class] && properties.count > 0)
											strongSelf.canTranscribe = [properties[@"canRecognizeSpeech"] boolValue];
										[strongSelf resolveExtras:properties then:^{
											__strong typeof(weakSelf) innerSelf = weakSelf;
											if (innerSelf == nil || innerSelf.finished)
												return;
											[innerSelf showMenuAtPoint:point properties:properties];
										}];
									});
								}];
}

- (void)resolveExtras:(NSDictionary *)properties then:(void (^)(void))done {
	if (![properties isKindOfClass:NSDictionary.class]) {
		done();
		return;
	}

	__weak typeof(self) weakSelf = self;
	void (^afterPinned)(void) = ^{
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (strongSelf == nil || strongSelf.finished)
			return;
		if (![strongSelf flag:@"canGetViewers" in:properties]) {
			done();
			return;
		}
		[[TGClient shared] viewersOfMessage:strongSelf.messageId
									 inChat:strongSelf.chatId
								 completion:^(NSArray *viewers, NSString *unavailableReason) {
									 dispatch_async(dispatch_get_main_queue(), ^{
										 __strong typeof(weakSelf) innerSelf = weakSelf;
										 if (innerSelf == nil || innerSelf.finished)
											 return;
										 innerSelf.viewerCount = [viewers isKindOfClass:NSArray.class]
											 ? (NSInteger)viewers.count
											 : 0;
										 done();
									 });
								 }];
	};

	if (![self flag:@"canPin" in:properties]) {
		afterPinned();
		return;
	}
	[[TGClient shared] isMessagePinned:self.messageId
								inChat:self.chatId
							completion:^(BOOL pinned) {
								dispatch_async(dispatch_get_main_queue(), ^{
									__strong typeof(weakSelf) strongSelf = weakSelf;
									if (strongSelf == nil || strongSelf.finished)
										return;
									strongSelf.resolvedPinned = pinned;
									afterPinned();
								});
							}];
}

- (void)showMenuAtPoint:(CGPoint)point properties:(NSDictionary *)properties {
	if (self.finished)
		return;

	self.presenting = NO;

	UIView *host = self.hostView;
	if (host == nil || host.window == nil) {
		[self finishWithAction:nil];
		return;
	}

	if (![properties isKindOfClass:NSDictionary.class] || properties.count == 0) {
		[self reportUnavailable];
		return;
	}

	NSMutableArray *items = [[NSMutableArray alloc] init];
	NSMutableArray *ids = [[NSMutableArray alloc] init];
	[self buildItems:items ids:ids fromProperties:properties];

	if (items.count == 0) {
		[self reportUnavailable];
		return;
	}

	self.actionIds = ids;

	__weak typeof(self) weakSelf = self;
	[TGPopupMenu showItems:items atPoint:point inView:host
				  onChoice:^(NSInteger index, __unused NSString *title) {
					  [weakSelf menuChoseIndex:index];
				  }];

	self.menuView = [self openMenuViewInHost:host];
	if (self.menuView == nil) {
		[self finishWithAction:nil];
		return;
	}
	[self scheduleDismissalWatch];
}

- (UIView *)openMenuViewInHost:(UIView *)host {
	Class menuClass = NSClassFromString(@"TGPopupMenu");
	if (menuClass == Nil)
		return nil;
	for (UIView *view in [host.subviews reverseObjectEnumerator]) {
		if ([view isKindOfClass:menuClass])
			return view;
	}
	return nil;
}

- (void)scheduleDismissalWatch {
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(checkMenuStillOpen)
											   object:nil];
	[self performSelector:@selector(checkMenuStillOpen) withObject:nil afterDelay:0.2];
}

- (void)checkMenuStillOpen {
	if (self.finished || self.confirming)
		return;
	UIView *menu = self.menuView;
	if (menu != nil && menu.superview != nil && menu.window != nil) {
		[self scheduleDismissalWatch];
		return;
	}
	self.menuView = nil;
	[self finishWithAction:nil];
}

- (void)stopDismissalWatch {
	self.menuView = nil;
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(checkMenuStillOpen)
											   object:nil];
}

- (BOOL)flag:(NSString *)key in:(NSDictionary *)properties {
	id value = properties[key];
	return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

- (void)add:(NSMutableArray *)items
			ids:(NSMutableArray *)ids
		  title:(NSString *)title
		   icon:(NSString *)icon
		 action:(NSString *)action
	destructive:(BOOL)destructive {
	NSMutableDictionary *item = [[NSMutableDictionary alloc] init];
	item[@"title"] = title;
	if (icon.length)
		item[@"icon"] = icon;
	if (destructive)
		item[@"destructive"] = @YES;
	[items addObject:item];
	[ids addObject:action];
}

- (void)buildItems:(NSMutableArray *)items
			   ids:(NSMutableArray *)ids
	fromProperties:(NSDictionary *)properties {
	BOOL hasText = self.messageText.length > 0;

	if ([self flag:@"canReactTo" in:properties])
		[self add:items ids:ids title:TGL(@"Chat.ReactAction", @"React") icon:@"react"
				 action:TGMessageActionReact
			destructive:NO];

	if ([self flag:@"canReply" in:properties]) {
		[self add:items ids:ids title:TGL(@"Conversation.ContextMenuReply", @"Reply") icon:@"reply"
				 action:TGMessageActionReply
			destructive:NO];
		if (self.canQuoteText)
			[self add:items ids:ids title:TGL(@"Conversation.ContextMenuQuote", @"Quote") icon:@"reply"
					 action:TGMessageActionQuote
				destructive:NO];
	}

	if ([self flag:@"canEdit" in:properties] || [self flag:@"canEditMedia" in:properties])
		[self add:items ids:ids title:TGL(@"Conversation.MessageDialogEdit", @"Edit") icon:@"edit"
				 action:TGMessageActionEdit
			destructive:NO];

	if (hasText && [self flag:@"canCopy" in:properties]) {
		[self add:items ids:ids title:TGL(@"Conversation.ContextMenuCopy", @"Copy") icon:@"copy"
				 action:TGMessageActionCopy
			destructive:NO];
		[self add:items ids:ids title:TGL(@"Conversation.ContextMenuSelectText", @"Select Text") icon:@"copy"
				 action:TGMessageActionSelectText
			destructive:NO];
	}

	if ([self flag:@"canGetLink" in:properties])
		[self add:items ids:ids title:TGL(@"Conversation.ContextMenuCopyLink", @"Copy Link") icon:@"copy"
				 action:TGMessageActionCopyLink
			destructive:NO];

	if ([self flag:@"canForward" in:properties])
		[self add:items ids:ids title:TGL(@"Conversation.ContextMenuForward", @"Forward") icon:@"forward"
				 action:TGMessageActionForward
			destructive:NO];

	if ([self flag:@"canSave" in:properties]) {
		if ([self.mediaKind isEqualToString:@"photo"])
			[self add:items ids:ids title:TGL(@"Gallery.SaveImage", @"Save Image") icon:@"save"
					 action:TGMessageActionSaveImage
				destructive:NO];
		else if ([self.mediaKind isEqualToString:@"video"])
			[self add:items ids:ids title:TGL(@"Gallery.SaveVideo", @"Save Video") icon:@"save"
					 action:TGMessageActionSaveVideo
				destructive:NO];
		else if ([self.mediaKind isEqualToString:@"gif"])
			[self add:items ids:ids title:TGL(@"Preview.SaveGif", @"Save GIF") icon:@"save"
					 action:TGMessageActionSaveGif
				destructive:NO];
	}

	if ([self flag:@"canSetAsNotificationSound" in:properties])
		[self add:items ids:ids title:TGL(@"Chat.SaveForNotifications", @"Set as Notification Sound") icon:nil
				 action:TGMessageActionSetNotificationSound
			destructive:NO];

	if ([self flag:@"canPin" in:properties]) {
		if (self.resolvedPinned)
			[self add:items ids:ids title:TGL(@"Conversation.Unpin", @"Unpin") icon:@"unpin"
					 action:TGMessageActionUnpin
				destructive:NO];
		else
			[self add:items ids:ids title:TGL(@"Conversation.Pin", @"Pin") icon:@"pin"
					 action:TGMessageActionPin
				destructive:NO];
	}

	if (self.canTranscribe)
		[self add:items ids:ids
				  title:(self.transcriptShown ? TGL(@"Chat.HideTranscript", @"Hide Transcript") : TGL(@"Chat.Transcribe", @"Transcribe"))
			icon:nil
				 action:TGMessageActionTranscribe
			destructive:NO];

	BOOL canTranslate = properties[@"canTranslate"] != nil
		? [self flag:@"canTranslate" in:properties]
		: hasText;
	if (canTranslate && [TGInAppNotificationPreferences showTranslateButton])
		[self add:items ids:ids
				  title:(self.translationShown ? TGL(@"Chat.HideTranslation", @"Hide Translation") : TGL(@"Conversation.ContextMenuTranslate", @"Translate"))
			icon:nil
				 action:TGMessageActionTranslate
			destructive:NO];

	if (hasText && ![[TGClient shared] isSecretChat:self.chatId])
		[self add:items ids:ids
				  title:(self.summaryShown ? TGL(@"Chat.HideSummary", @"Hide Summary") : TGL(@"Chat.Summarize", @"Summarize"))
			icon:nil
				 action:TGMessageActionSummarize
			destructive:NO];

	BOOL forMe = [self flag:@"canDeleteForMe" in:properties];
	BOOL forEveryone = [self flag:@"canDeleteForEveryone" in:properties];
	if (forEveryone && !forMe)
		[self add:items ids:ids title:TGL(@"Conversation.DeleteMessagesForEveryone", @"Delete for Everyone") icon:@"delete"
				 action:TGMessageActionDeleteForEveryone
			destructive:YES];
	else if (forMe && !forEveryone)
		[self add:items ids:ids title:TGL(@"Conversation.ContextMenuDelete", @"Delete") icon:@"delete"
				 action:TGMessageActionDeleteForMe
			destructive:YES];
	else if (forMe && forEveryone)
		[self add:items ids:ids title:TGL(@"Common.Delete", @"Delete") icon:@"delete"
				 action:TGMessageActionDeleteRow
			destructive:YES];

	self.canGetViewers = [self flag:@"canGetViewers" in:properties];
	self.canGetReadDate = [self flag:@"canGetReadDate" in:properties];
	if (self.canGetViewers || self.canGetReadDate)
		[self add:items ids:ids
				  title:(self.viewerCount > 0
								? TGLPlural(@"Conversation.ContextMenuSeen", self.viewerCount, @"1 Seen", @"%@ Seen")
								: TGL(@"Chat.SeenBy", @"Seen By"))
				   icon:nil
				 action:TGMessageActionSeenBy
			destructive:NO];

	if ([self flag:@"canGetAuthor" in:properties])
		[self add:items ids:ids title:TGL(@"Chat.ViewAuthor", @"View Author") icon:nil
				 action:TGMessageActionViewAuthor
			destructive:NO];

	if (self.allowsSelection && (properties[@"canSelect"] == nil || [self flag:@"canSelect" in:properties]))
		[self add:items ids:ids title:TGL(@"Conversation.ContextMenuSelect", @"Select") icon:nil
				 action:TGMessageActionSelect
			destructive:NO];

	if ([self flag:@"canReport" in:properties])
		[self add:items ids:ids title:TGL(@"Conversation.ContextMenuReport", @"Report") icon:nil
				 action:TGMessageActionReport
			destructive:NO];

	if ([self flag:@"canSetFactCheck" in:properties])
		[self add:items ids:ids
				  title:(self.factCheckText.length ? TGL(@"Conversation.ContextMenuEditFactCheck", @"Edit Fact Check") : TGL(@"Conversation.ContextMenuAddFactCheck", @"Add Fact Check"))
			icon:nil
				 action:TGMessageActionFactCheck
			destructive:NO];

	if ([self flag:@"canApproveSuggestedPost" in:properties])
		[self add:items ids:ids
				  title:TGL(@"Chat.PostApproval.Message.ActionApprove", @"Approve Post")
				   icon:nil
				 action:TGMessageActionApprovePost
			destructive:NO];

	if ([self flag:@"canDeclineSuggestedPost" in:properties])
		[self add:items ids:ids title:TGL(@"Chat.PostApproval.Message.ActionReject", @"Decline Post") icon:nil
				 action:TGMessageActionDeclinePost
			destructive:YES];

	if ([self flag:@"canAddOffer" in:properties])
		[self add:items ids:ids title:TGL(@"Chat.ContextMenu.SuggestedPost.Create", @"Suggest as Post") icon:nil
				 action:TGMessageActionSuggestPost
			destructive:NO];
	else if ([self flag:@"canEditSuggestedPostInfo" in:properties]) {
		if ([self flag:@"canEdit" in:properties] || [self flag:@"canEditMedia" in:properties])
			[self add:items ids:ids title:TGL(@"Chat.ContextMenu.SuggestedPost.EditMessage", @"Edit Message") icon:nil
					 action:TGMessageActionSuggestPostEditMessage
				destructive:NO];
		[self add:items ids:ids title:TGL(@"Chat.ContextMenu.SuggestedPost.EditTime", @"Edit Time") icon:nil
				 action:TGMessageActionSuggestPost
			destructive:NO];
		[self add:items ids:ids title:TGL(@"Chat.ContextMenu.SuggestedPost.EditPrice", @"Edit Price") icon:nil
				 action:TGMessageActionSuggestPost
			destructive:NO];
	}

	self.canDeleteForMe = forMe;
	self.canDeleteForEveryone = forEveryone;
}

#pragma mark - choice

- (void)menuChoseIndex:(NSInteger)index {
	[self stopDismissalWatch];

	if (index < 0 || index >= (NSInteger)self.actionIds.count) {
		[self finishWithAction:nil];
		return;
	}

	NSString *action = self.actionIds[index];
	if ([action isEqualToString:TGMessageActionDeleteRow]) {
		[self confirmDeleteForMe:self.canDeleteForMe forEveryone:self.canDeleteForEveryone];
		return;
	}
	if ([action isEqualToString:TGMessageActionDeleteForMe]) {
		[self confirmDeleteForMe:YES forEveryone:NO];
		return;
	}
	if ([action isEqualToString:TGMessageActionDeleteForEveryone]) {
		[self confirmDeleteForMe:NO forEveryone:YES];
		return;
	}
	[self finishWithAction:action];
}

- (void)confirmDeleteForMe:(BOOL)forMe forEveryone:(BOOL)forEveryone {
	UIView *host = self.hostView;
	if (host == nil) {
		[self finishWithAction:nil];
		return;
	}

	NSMutableArray *actions = [[NSMutableArray alloc] init];
	if (forEveryone) {
		TGActionSheetAction *everyone = [[TGActionSheetAction alloc]
			initWithTitle:TGL(@"Stickers.Delete.ForEveryone", @"Delete for Everyone")
				   action:TGMessageActionDeleteForEveryone
					 type:TGActionSheetActionTypeDestructive];
		[actions addObject:everyone];
	}
	if (forMe) {
		NSString *meTitle = forEveryone ? TGL(@"ChatList.DeleteForMe", @"Delete for Me")
										: TGL(@"Common.Delete", @"Delete");
		TGActionSheetActionType meType =
			forEveryone ? TGActionSheetActionTypeGeneric : TGActionSheetActionTypeDestructive;
		TGActionSheetAction *mine = [[TGActionSheetAction alloc]
			initWithTitle:meTitle
				   action:TGMessageActionDeleteForMe
					 type:meType];
		[actions addObject:mine];
	}

	if (actions.count == 0) {
		[self finishWithAction:nil];
		return;
	}

	self.confirming = YES;
	__weak typeof(self) weakSelf = self;
	self.currentActionSheet = [[TGActionSheet alloc]
		initWithTitle:nil
			  actions:actions
		  actionBlock:^(__unused id target, NSString *action) {
			  __strong typeof(weakSelf) strongSelf = weakSelf;
			  strongSelf.currentActionSheet = nil;
			  strongSelf.confirming = NO;
			  if ([action isEqualToString:TGMessageActionDeleteForEveryone] ||
				  [action isEqualToString:TGMessageActionDeleteForMe])
				  [strongSelf finishWithAction:action];
			  else
				  [strongSelf finishWithAction:nil];
		  }
			   target:self];
	UIView *sheetHost = (host.window != nil ? host.window : host);
	[self.currentActionSheet tg_showFromRect:CGRectMake(CGRectGetMidX(sheetHost.bounds), CGRectGetMidY(sheetHost.bounds), 1, 1) inView:sheetHost];
}

#pragma mark - states

- (void)reportUnavailable {
	TGAlertView *alert = [[TGAlertView alloc]
			initWithTitle:TGL(@"Tour.Title1", @"Telegram")
				  message:TGL(@"Conversation.MessageDoesntExist", @"Message doesn't exist")
		cancelButtonTitle:nil
			okButtonTitle:TGL(@"Common.OK", @"OK")
		  completionBlock:nil];
	[alert show];
	[self finishWithAction:nil];
}

- (void)finishWithAction:(NSString *)action {
	if (self.finished)
		return;
	self.finished = YES;
	[self stopDismissalWatch];

	void (^block)(NSString *) = self.completion;
	self.completion = nil;
	self.actionIds = nil;
	if (block)
		block(action);
}

- (void)dismiss {
	[TGPopupMenu dismiss];
	if (self.currentActionSheet) {
		NSInteger cancelIndex = self.currentActionSheet.cancelButtonIndex;
		[self.currentActionSheet dismissWithClickedButtonIndex:cancelIndex animated:NO];
		self.currentActionSheet = nil;
	}
	self.confirming = NO;
	self.presenting = NO;
	[self finishWithAction:nil];
}

@end

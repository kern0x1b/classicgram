#import "TGChatViewController.h"
#import "TGChatViewControllerInternal.h"
#import "TGClient.h"
#import "TGLocalization.h"
#import "TGClient+AiWriting.h"
#import "TGClient+WebLinks.h"
#import "TGClient+MessageContent.h"
#import "TGClient+Translation.h"
#import "TGClient+SecretChats.h"
#import "TGTranslationLanguageCode.h"
#import "TGSnackbar.h"
#import "TGAlertView.h"
#import "TGQuickReplyListViewController.h"
#import "TGActionSheet.h"

@implementation TGChatViewController (TextTools)

#pragma mark - text tools

- (void)showTextTools {
	UIActionSheet *sheet = [UIActionSheet alloc];
	sheet = [sheet initWithTitle:TGL(@"Paint.Text", @"Text")
						delegate:self
			   cancelButtonTitle:nil
		  destructiveButtonTitle:nil
			   otherButtonTitles:nil];
	NSString *markdownToggle = TGL(@"Chat.SendAsMarkdown", @"Send as Markdown");
	if (self.markdownComposing)
		markdownToggle = TGL(@"Chat.SendAsPlainText", @"Send as Plain Text");
	[sheet addButtonWithTitle:markdownToggle];
	[sheet addButtonWithTitle:TGL(@"Chat.PreviewFormatting", @"Preview Formatting")];
	[sheet addButtonWithTitle:TGL(@"Chat.PreviewLink", @"Preview Link")];
	[sheet addButtonWithTitle:TGL(@"TextProcessing.TabTranslate", @"Translate")];
	[sheet addButtonWithTitle:TGL(@"TextProcessing.TabFix", @"Fix")];
	[sheet addButtonWithTitle:TGL(@"TextProcessing.TabStylize", @"Style")];
	[sheet addButtonWithTitle:TGL(@"Chat.SaveAsQuickReply", @"Save as Quick Reply")];
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
	sheet.tag = kTextToolsSheetTag;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)showAiRewriteStylePicker {
	NSString *text = [self composerText];
	if (!text.length)
		return;
	NSArray *styles = [[TGClient shared] cachedTextCompositionStyles];
	if (!styles.count) {
		[self showAlertTitle:@""
					 message:TGL(@"Chat.NoAiRewriteStyles", @"No rewrite styles are available for this account yet.")];
		return;
	}

	NSMutableArray *names = [NSMutableArray array];
	UIActionSheet *sheet = [UIActionSheet alloc];
	sheet = [sheet initWithTitle:TGL(@"TextProcessing.TabStylize", @"Style")
						delegate:self
			   cancelButtonTitle:nil
		  destructiveButtonTitle:nil
			   otherButtonTitles:nil];
	for (NSDictionary *style in styles) {
		NSString *name = style[@"name"];
		if (!name.length)
			continue;
		[names addObject:name];
		NSString *title = style[@"title"];
		[sheet addButtonWithTitle:(title.length ? title : name)];
	}
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
	self.pendingAiRewriteStyleNames = names;
	sheet.tag = kAiRewriteStyleSheetTag;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)runAiRewriteStyleAtIndex:(NSInteger)index {
	NSArray *names = self.pendingAiRewriteStyleNames;
	self.pendingAiRewriteStyleNames = nil;

	if (index < 0 || index >= (NSInteger)names.count)
		return;
	NSString *styleName = names[index];
	if (!styleName.length)
		return;

	NSString *text = [self composerText];
	if (!text.length)
		return;

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] composeTextWithAi:text translateToLanguageCode:@""
							   styleName:styleName
							   addEmojis:NO
							  completion:^(NSString *result, NSString *errorMessage) {
								  TGChatViewController *strongSelf = weakSelf;
								  if (!strongSelf)
									  return;
								  if (!result.length) {
									  if ([strongSelf aiPremiumRequiredFor:errorMessage])
										  [strongSelf showAlertTitle:TGL(@"TextProcessing.LimitToast.Title", @"Daily limit reached")
													 message:TGL(@"TextProcessing.LimitToast.Text", @"Get Telegram Premium for 50x more text edits per day.")];
									  else
										  [strongSelf showAlertTitle:@"" message:TGL(@"Toast.CouldNotRewriteText", @"Could not rewrite this text")];
									  return;
								  }
								  [strongSelf presentAiSuggestion:result original:text title:TGL(@"TextProcessing.TitleEdit", @"AI Editor")];
							  }];
}

- (NSString *)composerText {
	return [self.input.text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)runTextToolAtIndex:(NSInteger)index {
	if (index == 0) {
		self.markdownComposing = !self.markdownComposing;
		[TGSnackbar showInView:self.view
						  text:(self.markdownComposing
									   ? TGL(@"Chat.BoldItalicAndCodeWillBe", @"*bold*, _italic_ and `code` will be applied")
									   : TGL(@"Chat.TextWillBeSentExactly", @"Text will be sent exactly as typed"))
			seconds:3
					  onCommit:nil];
		return;
	}

	NSString *text = [self composerText];
	if (!text.length)
		return;

	__weak typeof(self) weakSelf = self;
	if (index == 1) {
		[[TGClient shared] parseMarkdown:text completion:^(NSString *plainText, NSArray *entities) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			[strongSelf showFormattingPreview:(plainText ?: text) markup:entities];
		}];
		return;
	}

	if (index == 2) {
		NSDictionary *options = [TGClient linkPreviewOptionsDisabled:NO url:@"" forceSmallMedia:NO forceLargeMedia:YES showAboveText:NO];
		[[TGClient shared] linkPreviewForText:text withOptions:options
								   completion:^(NSDictionary *preview) {
									   TGChatViewController *strongSelf = weakSelf;
									   if (!strongSelf)
										   return;
									   if (![preview[@"url"] length])
										   return;
									   NSMutableArray *lines = [NSMutableArray array];
									   for (NSString *key in @[ @"siteName", @"title", @"description", @"displayUrl" ]) {
										   NSString *value = [preview[key] isKindOfClass:NSString.class]
											   ? preview[key]
											   : nil;
										   if (value.length)
											   [lines addObject:value];
									   }
									   if ([preview[@"hasInstantView"] boolValue])
										   [lines addObject:TGL(@"Chat.InstantViewAvailable", @"Instant View available")];
									   NSString *previewTitle = preview[@"url"] ?: TGL(@"Channel.Edit.LinkItem", @"Link");
									   NSString *previewMessage = lines.count
										   ? [lines componentsJoinedByString:@"\n"]
										   : TGL(@"Chat.NothingIsKnownAboutThisLink", @"Nothing is known about this link yet.");
									   [strongSelf showAlertTitle:previewTitle message:previewMessage];
								   }];
		return;
	}

	if (index == 3) {
		if ([[TGClient shared] isSecretChat:self.chatId]) {
			[self showAlertTitle:@"" message:TGL(@"Chat.TranslateUnavailableSecretChat", @"Translation is not available in Secret Chats.")];
			return;
		}
		NSString *preferred = [[NSLocale preferredLanguages] firstObject];
		NSString *language = TGTranslationLanguageCodeForLocaleIdentifier(preferred);
		void (^performTranslate)(NSString *, NSArray *) = ^(NSString *sourceText, NSArray *sourceEntities) {
			[[TGClient shared] translateText:sourceText entities:sourceEntities toLanguage:language tone:nil
								  completion:^(NSString *translated, NSArray *translatedEntities, NSString *errorMessage) {
									  TGChatViewController *strongSelf = weakSelf;
									  if (!strongSelf)
										  return;
									  if (!translated.length) {
										  if ([strongSelf aiPremiumRequiredFor:errorMessage])
											  [strongSelf showAlertTitle:TGL(@"TextProcessing.LimitToast.Title", @"Daily limit reached")
														 message:TGL(@"TextProcessing.LimitToast.Text", @"Get Telegram Premium for 50x more text edits per day.")];
										  return;
									  }
									  [strongSelf presentAiSuggestion:translated original:text title:TGL(@"TextProcessing.TitleTranslate", @"Translation")];
								  }];
		};
		if (self.markdownComposing) {
			[[TGClient shared] formattedTextFromMarkdown:text
											   completion:^(NSString *parsedText, NSArray *parsedEntities) {
												   performTranslate(parsedText.length ? parsedText : text, parsedEntities);
											   }];
		} else {
			performTranslate(text, nil);
		}
		return;
	}

	if (index == 4) {
		[[TGClient shared] fixTextWithAi:text completion:^(NSString *fixed, NSString *errorMessage) {
			TGChatViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (!fixed.length) {
				if ([strongSelf aiPremiumRequiredFor:errorMessage])
					[strongSelf showAlertTitle:TGL(@"TextProcessing.LimitToast.Title", @"Daily limit reached")
							   message:TGL(@"TextProcessing.LimitToast.Text", @"Get Telegram Premium for 50x more text edits per day.")];
				else
					[strongSelf showAlertTitle:@"" message:TGL(@"Toast.CouldNotFixText", @"Could not fix this text")];
				return;
			}
			[strongSelf presentAiSuggestion:fixed original:text title:TGL(@"TextProcessing.TitleEdit", @"AI Editor")];
		}];
		return;
	}

	if (index == 5) {
		[self showAiRewriteStylePicker];
		return;
	}

	if (index == 6) {
		TGQuickReplyListViewController *list =
			[[TGQuickReplyListViewController alloc] initWithChatId:self.chatId];
		[list beginCreatingShortcutWithText:text];
		[self.navigationController pushViewController:list animated:YES];
	}
}

- (void)showFormattingPreview:(NSString *)plainText markup:(NSArray *)markup {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] entitiesInText:plainText completion:^(NSArray *detected) {
		TGChatViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		NSMutableArray *lines = [NSMutableArray array];
		for (NSDictionary *entity in markup)
			[lines addObject:[NSString stringWithFormat:@"%@ %@",
								 (entity[@"kind"] ?: @"text"),
								 [strongSelf fragmentOf:plainText entity:entity]]];
		for (NSDictionary *entity in detected)
			[lines addObject:[NSString stringWithFormat:@"%@ %@",
								 (entity[@"kind"] ?: @"text"),
								 [strongSelf fragmentOf:plainText entity:entity]]];
		[strongSelf showAlertTitle:plainText
				   message:(lines.count ? [lines componentsJoinedByString:@"\n"]
										: TGL(@"Chat.NoFormattingInThisText", @"No formatting in this text."))];
	}];
}

- (NSString *)fragmentOf:(NSString *)text entity:(NSDictionary *)entity {
	NSInteger offset = (NSUInteger)[entity[@"offset"] integerValue];
	NSInteger length = (NSUInteger)[entity[@"length"] integerValue];
	if (offset + length > text.length || length == 0)
		return @"";
	return [text substringWithRange:NSMakeRange(offset, length)];
}

@end

#import "TGChatViewController.h"
#import "TGStringTruncation.h"
#import "TGChatViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGActionSheet.h"
#import "TGEmoji.h"
#import "TGClient.h"
#import "TGSnackbar.h"
#import "TGClient+MessageContent.h"

@implementation TGChatViewController (LinkHitTesting)

#pragma mark - a link under the finger

- (NSArray *)lineRangesOfText:(NSString *)text font:(UIFont *)font width:(CGFloat)width {
	NSMutableArray *lines = [NSMutableArray array];
	if (!text.length || !font || width < 1)
		return lines;

	NSInteger length = text.length;
	NSInteger lineStart = 0;
	NSInteger cursor = 0;
	NSInteger lastBreak = NSNotFound;
	NSCharacterSet *spaces = [NSCharacterSet whitespaceCharacterSet];

	while (cursor < length) {
		unichar c = [text characterAtIndex:cursor];
		if (c == '\n') {
			[lines addObject:[NSValue valueWithRange:
									 NSMakeRange(lineStart, cursor - lineStart)]];
			cursor++;
			lineStart = cursor;
			lastBreak = NSNotFound;
			continue;
		}
		if ([spaces characterIsMember:c])
			lastBreak = cursor;

		NSRange sofar = NSMakeRange(lineStart, cursor - lineStart + 1);
		CGFloat used = [[text substringWithRange:sofar] sizeWithFont:font].width;
		if (used > width && cursor > lineStart) {
			NSUInteger breakAt = (lastBreak != NSNotFound && lastBreak > lineStart)
				? lastBreak
				: cursor;
			[lines addObject:[NSValue valueWithRange:
									 NSMakeRange(lineStart, breakAt - lineStart)]];
			lineStart = (breakAt == lastBreak) ? breakAt + 1 : breakAt;
			cursor = lineStart;
			lastBreak = NSNotFound;
			continue;
		}
		cursor++;
	}
	if (lineStart <= length)
		[lines addObject:[NSValue valueWithRange:
								 NSMakeRange(lineStart, length - lineStart)]];
	return lines;
}

- (NSInteger)characterIndexInLabel:(UILabel *)label atPoint:(CGPoint)point {
	NSString *text = label.text;
	if (!text.length || label.hidden)
		return -1;
	if (!CGRectContainsPoint(CGRectInset(label.bounds, -4, -2), point))
		return -1;

	UIFont *font = label.font;
	CGFloat lineHeight = [@"Ag" sizeWithFont:font].height;
	if (lineHeight < 1)
		return -1;

	NSArray *lines = [self lineRangesOfText:text font:font
									  width:label.bounds.size.width];
	if (!lines.count)
		return -1;
	NSInteger index = (NSInteger)floorf(MAX(0.0f, point.y) / lineHeight);
	if (index < 0 || index >= (NSInteger)lines.count)
		return -1;

	NSRange line = [[lines objectAtIndex:index] rangeValue];
	CGFloat x = 0;
	if (label.textAlignment != NSTextAlignmentLeft) {
		CGFloat lineW = [[text substringWithRange:line] sizeWithFont:font].width;
		CGFloat slack = MAX(0.0f, label.bounds.size.width - lineW);
		x = (label.textAlignment == NSTextAlignmentCenter) ? slack / 2 : slack;
	}
	CGFloat start = x;
	for (NSInteger i = 0; i < line.length; i++) {
		NSString *prefix = [text substringWithRange:
				NSMakeRange(line.location, i + 1)];
		CGFloat next = start + [prefix sizeWithFont:font].width;
		if (point.x >= x && point.x < next)
			return (NSInteger)(line.location + i);
		x = next;
	}
	return -1;
}

- (NSString *)urlInLabel:(UILabel *)label atPoint:(CGPoint)point {
	NSString *text = label.text;
	if (!text.length || label.hidden)
		return nil;
	if (TGEmojiTextNeedsSubstitution(text))
		return nil;
	if (text.length > 600)
		return nil;

	NSError *error = nil;
	NSDataDetector *detector = [NSDataDetector
		dataDetectorWithTypes:NSTextCheckingTypeLink
						error:&error];
	if (!detector)
		return nil;
	NSArray *matches = [detector matchesInString:text options:0
										   range:NSMakeRange(0, text.length)];
	if (!matches.count)
		return nil;

	NSInteger index = [self characterIndexInLabel:label atPoint:point];
	if (index < 0)
		return nil;
	for (NSTextCheckingResult *match in matches) {
		if (!NSLocationInRange((NSUInteger)index, match.range))
			continue;
		NSURL *found = match.URL;
		if (found)
			return found.absoluteString;
		return [text substringWithRange:match.range];
	}
	return nil;
}

- (void)showHeldLinkSheetFor:(NSString *)url {
	self.heldLinkURL = url;
	NSString *title = url;
	if (title.length > 60)
		title = [TGSafeSubstringToIndex(title, 57) stringByAppendingString:@"..."];
	UIActionSheet *sheet = [UIActionSheet alloc];
	sheet = [sheet initWithTitle:title
						delegate:self
			   cancelButtonTitle:nil
		  destructiveButtonTitle:nil
			   otherButtonTitles:nil];
	[sheet addButtonWithTitle:TGL(@"Conversation.LinkDialogOpen", @"Open")];
	[sheet addButtonWithTitle:TGL(@"GroupInfo.InviteLink.CopyLink", @"Copy Link")];
	if ([self readingListClass])
		[sheet addButtonWithTitle:TGL(@"Conversation.AddToReadingList", @"Add to Reading List")];
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
	sheet.tag = kHeldLinkSheetTag;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (Class)readingListClass {
	return NSClassFromString(@"SSReadingList");
}

- (void)runHeldLinkOption:(NSString *)chosen {
	NSString *url = self.heldLinkURL;
	self.heldLinkURL = nil;
	if (!url.length)
		return;
	if ([chosen isEqualToString:TGL(@"Conversation.LinkDialogOpen", @"Open")]) {
		[self openLink:url];
		return;
	}
	if ([chosen isEqualToString:TGL(@"GroupInfo.InviteLink.CopyLink", @"Copy Link")]) {
		[UIPasteboard generalPasteboard].string = url;
		return;
	}
	if (![chosen isEqualToString:TGL(@"Conversation.AddToReadingList", @"Add to Reading List")])
		return;
	Class readingList = [self readingListClass];
	NSURL *target = [NSURL URLWithString:url];
	if (!readingList || !target)
		return;
	id list = [readingList defaultReadingList];
	if (![list respondsToSelector:
				@selector(addReadingListItemWithURL:title:previewText:error:)])
		return;
	[list addReadingListItemWithURL:target title:nil previewText:nil error:NULL];
}

- (void)followBankCardNumber:(NSString *)cardNumber {
	if (!cardNumber.length)
		return;
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] bankCardInfoForNumber:cardNumber
								  completion:^(NSString *title, NSArray *actions) {
									  TGChatViewController *strongSelf = weakSelf;
									  if (!strongSelf)
										  return;
									  [strongSelf showBankCardSheetForNumber:cardNumber title:title actions:actions];
								  }];
}

- (void)showBankCardSheetForNumber:(NSString *)cardNumber
							 title:(NSString *)title
						   actions:(NSArray *)actions {
	self.bankCardNumber = cardNumber;
	self.bankCardActions = actions;
	UIActionSheet *sheet = [[UIActionSheet alloc]
				 initWithTitle:(title.length ? title : nil)
					  delegate:self
			 cancelButtonTitle:nil
		destructiveButtonTitle:nil
			 otherButtonTitles:nil];
	for (NSDictionary *action in actions)
		[sheet addButtonWithTitle:action[@"text"]];
	[sheet addButtonWithTitle:TGL(@"Chat.Context.Card.Copy", @"Copy Card Number")];
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:TGL(@"Common.Cancel", @"Cancel")];
	sheet.tag = kBankCardSheetTag;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)runBankCardOptionIndex:(NSInteger)index {
	NSArray *actions = self.bankCardActions;
	NSString *number = self.bankCardNumber;
	self.bankCardActions = nil;
	self.bankCardNumber = nil;
	if (index >= 0 && index < (NSInteger)actions.count) {
		NSString *url = actions[(NSUInteger)index][@"url"];
		if (url.length)
			[self openLink:url];
		return;
	}
	if (number.length) {
		[UIPasteboard generalPasteboard].string = number;
		[TGSnackbar showInView:self.view text:TGL(@"Conversation.CardNumberCopied", @"Card number copied")
					   seconds:2
					  onCommit:nil];
	}
}

@end

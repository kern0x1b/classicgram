#import "TGStoriesViewController.h"
#import "TGLocalization.h"
#import "TGLazyFramework.h"

#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "TGClient+Stories.h"
#import "TGActionSheet.h"
#import "TGAlertView.h"
#import "TGTheme.h"
#import "TGDateUtils.h"
#import "TGImageDecode.h"
#import "TGReactionPickerView.h"
#import "TGChatViewController.h"
#import "TGWebViewController.h"
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

@implementation TGStoriesViewController (Dismissal)

#pragma mark - dismissal

- (void)dismissViewer {
	if (_dismissing)
		return;
	_dismissing = YES;

	CGFloat height = self.view.bounds.size.height;
	__weak TGStoriesViewController *weakSelf = self;
	[UIView animateWithDuration:0.2
		animations:^{
			TGStoriesViewController *strongSelf = weakSelf;
			if (strongSelf == nil)
				return;
			strongSelf.view.transform = CGAffineTransformMakeTranslation(0, height);
			strongSelf.view.alpha = 0.0f;
		}
		completion:^(BOOL finished) {
			(void)finished;
			TGStoriesViewController *strongSelf = weakSelf;
			if (strongSelf == nil)
				return;
			strongSelf.view.transform = CGAffineTransformIdentity;
			strongSelf.view.alpha = 1.0f;
			[strongSelf.navigationController popViewControllerAnimated:NO];
		}];
}

- (void)viewDragged:(UIPanGestureRecognizer *)recognizer {
	if (_dismissing)
		return;

	CGPoint translation = [recognizer translationInView:self.view];
	CGFloat shift = MAX(0.0f, translation.y);

	if (recognizer.state == UIGestureRecognizerStateChanged) {
		self.view.transform = CGAffineTransformMakeTranslation(0, shift);
		CGFloat height = MAX(1.0f, self.view.bounds.size.height);
		self.view.alpha = MAX(0.4f, 1.0f - shift / height);
		return;
	}

	if (recognizer.state == UIGestureRecognizerStateEnded ||
		recognizer.state == UIGestureRecognizerStateCancelled ||
		recognizer.state == UIGestureRecognizerStateFailed) {
		CGFloat velocity = [recognizer velocityInView:self.view].y;
		BOOL leaving = (recognizer.state == UIGestureRecognizerStateEnded) &&
			(shift > kStoryDismissDistance || velocity > kStoryDismissVelocity);
		if (leaving) {
			[self dismissViewer];
			return;
		}

		__weak TGStoriesViewController *weakSelf = self;
		[UIView animateWithDuration:0.2
						 animations:^{
							 TGStoriesViewController *strongSelf = weakSelf;
							 if (strongSelf == nil)
								 return;
							 strongSelf.view.transform = CGAffineTransformIdentity;
							 strongSelf.view.alpha = 1.0f;
						 }];
	}
}

- (void)viewHeld:(UILongPressGestureRecognizer *)recognizer {
	if (recognizer.state == UIGestureRecognizerStateBegan) {
		CGPoint point = [recognizer locationInView:self.view];
		if ([self pointIsOnChrome:point])
			return;
		[self setHoldPaused:YES];
		return;
	}

	if (recognizer.state == UIGestureRecognizerStateEnded ||
		recognizer.state == UIGestureRecognizerStateCancelled ||
		recognizer.state == UIGestureRecognizerStateFailed) {
		[self setHoldPaused:NO];
	}
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer {
	if (![recognizer isKindOfClass:[UIPanGestureRecognizer class]])
		return YES;

	CGPoint velocity = [(UIPanGestureRecognizer *)recognizer velocityInView:self.view];
	return velocity.y > 0.0f && fabsf((float)velocity.y) > fabsf((float)velocity.x);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(UITouch *)touch {
	UIView *hit = touch.view;
	if (hit == nil)
		return YES;

	UIView *picker = _reactionPicker;
	if (picker != nil && picker.superview != nil && hit != picker &&
		[hit isDescendantOfView:picker]) {
		return NO;
	}

	if ([recognizer isKindOfClass:[UIPanGestureRecognizer class]])
		return YES;

	if (_footerView != nil && [hit isDescendantOfView:_footerView])
		return NO;
	if (_topPanel != nil && [hit isDescendantOfView:_topPanel])
		return NO;
	if (_bottomPanel != nil && [hit isDescendantOfView:_bottomPanel])
		return NO;

	return YES;
}

- (BOOL)pointIsOnChrome:(CGPoint)point {
	if (_footerView != nil && CGRectContainsPoint(_footerView.frame, point))
		return YES;
	if (_topPanel != nil && CGRectContainsPoint(_topPanel.frame, point))
		return YES;
	if (_bottomPanel != nil && CGRectContainsPoint(_bottomPanel.frame, point))
		return YES;
	return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer
	shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
	(void)recognizer;
	(void)other;
	return YES;
}

- (void)updateChrome {
	NSDictionary *story = [self currentStory];

	_counterLabel.text = [NSString stringWithFormat:@"%d of %d",
		(int)(_index + 1), (int)_storyIds.count];
	_authorLabel.text = [self resolvedPosterName];

	int date = story != nil ? (int)TGStoryNumber(story, @"date") : 0;
	_dateLabel.text = date > 0 ? [TGDateUtils stringForLastSeen:date] : @"";

	_deleteButton.hidden = !(story != nil && TGStoryFlag(story, @"canDelete"));

	if ([self isOwnStory] && (story == nil || TGStoryFlag(story, @"canGetViewers"))) {
		[_middleButton setTitle:TGLPlural(@"Story.Footer.Views", TGStoryNumber(story, @"views"), @"%d view", @"%d views")
					   forState:UIControlStateNormal];
	} else {
		NSString *mine = story != nil ? TGStoryString(story, @"myReaction") : @"";
		[_middleButton setTitle:[NSString stringWithFormat:@"%@ %d",
									(mine.length > 0 ? mine : @"♥"),
									(int)TGStoryNumber(story, @"reactions")]
					   forState:UIControlStateNormal];
	}

	BOOL canReply = story == nil ? YES : TGStoryFlag(story, @"canReply");
	_replyButton.enabled = canReply;
	_replyButton.alpha = canReply ? 1.0f : 0.5f;

	BOOL canForward = story == nil ? YES : TGStoryFlag(story, @"canForward");
	_shareButton.enabled = canForward;
	_shareButton.alpha = canForward ? 1.0f : 0.5f;
}

- (void)viewTapped:(UITapGestureRecognizer *)recognizer {
	if (_dismissing)
		return;

	CGPoint point = [recognizer locationInView:self.view];
	if ([self pointIsOnChrome:point])
		return;

	if (_reactionPicker != nil && _reactionPicker.superview != nil) {
		[TGReactionPickerView dismiss];
		[self setModalPaused:NO];
		return;
	}

	[self setModalPaused:NO];

	TGStoryPage *page = [self pageForIndex:_index];
	if (page != nil && page.failed &&
		[page isRetryPoint:[self.view convertPoint:point toView:page]]) {
		[self loadPage:page];
		return;
	}
	if (page != nil && [self handleAreaTapOnPage:page atPoint:point])
		return;

	CGRect caption = [page captionFrame];
	if (page != nil && !CGRectIsEmpty(caption) &&
		CGRectContainsPoint([self.view convertRect:caption fromView:page], point)) {
		NSDictionary *story = [self currentStory];
		NSString *text = story != nil ? TGStoryString(story, @"caption") : @"";
		if (text.length > 0) {
			TGStoryTextViewController *reader = [[TGStoryTextViewController alloc] init];
			reader.text = text;
			reader.title = [self resolvedPosterName];
			[self.navigationController pushViewController:reader animated:YES];
		}
		return;
	}

	CGFloat width = self.view.bounds.size.width;
	if (point.x < width / 3.0f) {
		if (_index > 0)
			[self showIndex:_index - 1 animated:YES];
		else
			[self movePosterBy:-1];
	} else if (point.x > width * 2.0f / 3.0f) {
		if (_index + 1 < (NSInteger)_storyIds.count)
			[self showIndex:_index + 1 animated:YES];
		else
			[self movePosterBy:1];
	}
}

- (BOOL)handleAreaTapOnPage:(TGStoryPage *)page atPoint:(CGPoint)point {
	CGPoint local = [self.view convertPoint:point toView:page];
	NSDictionary *area = [page areaAtPoint:local];
	if (area == nil)
		return NO;

	NSString *kind = TGStoryString(area, @"kind");

	if ([kind isEqualToString:@"link"]) {
		NSString *link = TGStoryString(area, @"url");
		if (link.length == 0)
			return NO;
		[self openLink:link];
		return YES;
	}

	if ([kind isEqualToString:@"reaction"]) {
		NSString *emoji = TGStoryString(area, @"emoji");
		if (emoji.length == 0)
			return NO;
		[self sendReaction:emoji];
		return YES;
	}

	if ([kind isEqualToString:@"location"] || [kind isEqualToString:@"venue"]) {
		double latitude = [[area objectForKey:@"latitude"] doubleValue];
		double longitude = [[area objectForKey:@"longitude"] doubleValue];
		if (latitude == 0.0 && longitude == 0.0)
			return NO;

		NSString *title = TGStoryString(area, @"title");
		NSString *venueProvider = TGStoryString(area, @"venueProvider");
		NSString *venueId = TGStoryString(area, @"venueId");
		if ([kind isEqualToString:@"venue"] && venueProvider.length > 0 && venueId.length > 0) {
			[self presentVenueAreaOptionsWithLatitude:latitude longitude:longitude title:title
											 provider:venueProvider
											  venueId:venueId];
		} else {
			[self openAreaMapAtLatitude:latitude longitude:longitude title:title];
		}
		return YES;
	}

	if ([kind isEqualToString:@"message"]) {
		int64_t chatId = TGStoryChatId(area, @"chatId");
		int64_t messageId = TGStoryChatId(area, @"messageId");
		if (chatId == 0 || messageId == 0)
			return NO;
		[self openAreaMessageInChat:chatId messageId:messageId];
		return YES;
	}

	return NO;
}

- (void)openAreaMapAtLatitude:(double)latitude longitude:(double)longitude title:(NSString *)title {
	NSString *query = title.length > 0 ? [title stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] : @"Location";
	NSString *mapsUrl = [NSString stringWithFormat:@"http://maps.apple.com/?ll=%f,%f&q=%@",
		latitude, longitude, query];
	NSURL *url = [NSURL URLWithString:mapsUrl];
	if (url != nil)
		[[UIApplication sharedApplication] openURL:url];
}

- (void)presentVenueAreaOptionsWithLatitude:(double)latitude longitude:(double)longitude
									  title:(NSString *)title
								   provider:(NSString *)provider
									venueId:(NSString *)venueId {
	NSArray *actions = [NSArray arrayWithObjects:
			[[TGActionSheetAction alloc] initWithTitle:TGL(@"Map.OpenInMaps", @"Open in Maps") action:@"maps"],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Story.ViewLocation", @"View Location") action:@"search"],
		[[TGActionSheetAction alloc] initWithTitle:TGL(@"Common.Cancel", @"Cancel") action:@"cancel"
											  type:TGActionSheetActionTypeCancel],
		nil];
	__weak typeof(self) weakSelf = self;
	void (^chosen)(id, NSString *) = ^(__unused id target, NSString *action) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if ([action isEqualToString:@"maps"])
			[strongSelf openAreaMapAtLatitude:latitude longitude:longitude title:title];
		else if ([action isEqualToString:@"search"])
			[strongSelf openVenueSearchWithProvider:provider venueId:venueId title:title];
	};
	NSString *sheetTitle = title.length > 0 ? title : nil;
	TGActionSheet *sheet = [[TGActionSheet alloc] initWithTitle:sheetTitle actions:actions actionBlock:chosen target:self];
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)openAreaMessageInChat:(int64_t)chatId messageId:(int64_t)messageId {
	TGChatViewController *controller = [[TGChatViewController alloc] init];
	controller.chatId = chatId;
	controller.chatTitle = @"Chat";
	controller.focusMessageId = messageId;
	[self.navigationController pushViewController:controller animated:YES];
}

- (void)openLink:(NSString *)link {
	if ([link rangeOfString:@"/s/"].location == NSNotFound &&
		[link rangeOfString:@"story"].location == NSNotFound) {
		[TGWebViewController openURLString:link fromViewController:self];
		return;
	}

	__weak TGStoriesViewController *weakSelf = self;
	[[TGClient shared] resolveStoryLink:link completion:^(int64_t chatId, NSInteger storyId) {
		TGStoriesViewController *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		if (chatId == 0 || storyId == 0) {
			[TGWebViewController openURLString:link fromViewController:strongSelf];
			return;
		}
		TGStoriesViewController *viewer = [[TGStoriesViewController alloc]
			initWithChatId:chatId
				  storyIds:[NSArray arrayWithObject:[NSNumber numberWithInteger:storyId]]
				startIndex:0];
		[strongSelf.navigationController pushViewController:viewer animated:YES];
	}];
}

- (NSString *)hashtagInCaption {
	NSDictionary *story = [self currentStory];
	NSString *caption = story != nil ? TGStoryString(story, @"caption") : @"";
	NSRange hash = [caption rangeOfString:@"#"];
	if (hash.location == NSNotFound || hash.location + 1 >= caption.length)
		return nil;

	NSCharacterSet *stop = [NSCharacterSet characterSetWithCharactersInString:@" \n\t,.!?;:#"];
	NSRange rest = NSMakeRange(hash.location + 1, caption.length - hash.location - 1);
	NSRange end = [caption rangeOfCharacterFromSet:stop options:0 range:rest];
	NSUInteger length = (end.location == NSNotFound)
		? rest.length
		: end.location - rest.location;
	if (length == 0)
		return nil;
	return [caption substringWithRange:NSMakeRange(rest.location, length)];
}

@end

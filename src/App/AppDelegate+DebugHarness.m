#import "AppDelegate+Private.h"
#import <objc/runtime.h>
#import "TGClient.h"
#import "TGClient+Account.h"
#import "TGClient+ChatList.h"
#import "TGBackgroundSession.h"
#import "TGIcons.h"
#import "TGRemoteImageView.h"
#import "TGLaunchSnapshot.h"
#import "TGChatViewController.h"
#import "TGChatListViewController.h"
#import "TGTopicsViewController.h"
#import "TGTabBar.h"
#import "TGLazyFramework.h"
#import "RootViewController.h"
#import "TGCall.h"
#import "TGSearchViewController.h"
#import "TGSnackbar.h"
#import "TGDeviceViewController.h"
#import "TGVideoLoopback.h"
#import "TGLocalization.h"
#import "AppDelegate+I18nDump.h"
#import "TGPasscodeLock.h"
#import "TGVisibleAlerts.h"
#import "TGTestDCMode.h"
#import "TGFrameTimeLogger.h"
#import "TGChatLayoutBridge.h"

@implementation AppDelegate (DebugHarness)

- (UIScrollView *)scrollViewToDrive {
	UIViewController *top = [self topControllerOnScreen];
	if (!top)
		return nil;
	UIView *view = top.view;
	UIScrollView *scroll = [view isKindOfClass:UIScrollView.class] ? (UIScrollView *)view : nil;
	for (UIView *sub in view.subviews)
		if (!scroll && [sub isKindOfClass:UIScrollView.class])
			scroll = (UIScrollView *)sub;
	if (scroll)
		return scroll;
	for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
		UIScrollView *nested = [self deepestScrollViewIn:window];
		if (nested)
			scroll = nested;
	}
	return scroll;
}

- (UITableView *)masterTableOnScreen {
	for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
		UIViewController *root = window.rootViewController;
		UISplitViewController *split = nil;
		if ([root isKindOfClass:[UISplitViewController class]])
			split = (UISplitViewController *)root;
		for (UIViewController *child in root.childViewControllers)
			if (!split && [child isKindOfClass:[UISplitViewController class]])
				split = (UISplitViewController *)child;
		if (!split || !split.viewControllers.count)
			continue;
		UIViewController *master = split.viewControllers[0];
		if ([master isKindOfClass:[UINavigationController class]])
			master = [(UINavigationController *)master topViewController];
		UITableView *table = [self firstTableViewIn:master.view];
		if (table)
			return table;
	}
	return nil;
}

static NSString *const TGHarnessCommandPath = @"/tmp/tgcmd";

- (void)installHarnessCommandWatcher {
	[NSTimer scheduledTimerWithTimeInterval:1.0
									 target:self
								   selector:@selector(readHarnessCommandFile)
								   userInfo:nil
									repeats:YES];
	NSLog(@"harness: watching %@", TGHarnessCommandPath);
}

- (void)readHarnessCommandFile {
	NSFileManager *files = [NSFileManager defaultManager];
	NSDictionary *attributes = [files attributesOfItemAtPath:TGHarnessCommandPath error:NULL];
	if (!attributes)
		return;

	NSDate *written = attributes[NSFileModificationDate];
	if (self.lastHarnessCommandDate && written &&
		[written compare:self.lastHarnessCommandDate] != NSOrderedDescending)
		return;
	self.lastHarnessCommandDate = written ?: [NSDate date];

	NSString *body = [NSString stringWithContentsOfFile:TGHarnessCommandPath
											   encoding:NSUTF8StringEncoding
												  error:NULL];
	[files removeItemAtPath:TGHarnessCommandPath error:NULL];

	NSString *text = [body stringByTrimmingCharactersInSet:
		[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!text.length)
		return;

	NSURL *url = [NSURL URLWithString:text];
	if (!url)
		url = [NSURL URLWithString:[text stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	if (!url) {
		NSLog(@"harness: %@ is not a URL", text);
		return;
	}
	NSLog(@"harness: file command %@", url.host ?: text);
	[self handleDebugHarnessURL:url];
}

- (BOOL)handleDebugHarnessURL:(NSURL *)url {
	NSString *host = url.host;
	NSString *arg = [url.path stringByReplacingOccurrencesOfString:@"/" withString:@""];

	if (![url.scheme isEqualToString:@"telegramdev"])
		return NO;

	NSArray<NSString *> *harnessCommandsExemptFromPasscodeLock = @[
		@"i18n", @"mem", @"bgstatus", @"memflush", @"lazyframeworks",
		@"launchimage", @"regions", @"captureframes", @"perflog",
		@"bridgecounts", @"stacks", @"stacksatlaunch",
		@"phone", @"code", @"password", @"testdc", @"tdlog",
	];
	if (![harnessCommandsExemptFromPasscodeLock containsObject:host ?: @""] &&
		[[TGPasscodeLock shared] isLocked])
		return YES;

	if ([host isEqualToString:@"i18n"]) {
		[self i18nDumpForLanguage:arg];
		return YES;
	}

	if ([host isEqualToString:@"mem"]) {
		TGMemMark(arg.length ? arg : @"probe");
		TGMemZoneReport(arg.length ? arg : @"probe");
		return YES;
	}

	if ([host isEqualToString:@"bgstatus"]) {
		NSLog(@"BGSESSION status %@", [[TGBackgroundSession shared] statusLine]);
		[[TGBackgroundSession shared] runDiagnosticProbe];
		return YES;
	}

	if ([host isEqualToString:@"memflush"]) {
		NSString *what = arg.length ? arg : @"all";
		unsigned long long before = TGResidentBytes();
		if ([what isEqualToString:@"icons"] || [what isEqualToString:@"all"])
			[TGIcons flush];
		if ([what isEqualToString:@"images"] || [what isEqualToString:@"all"])
			[TGRemoteImageView performSelector:NSSelectorFromString(@"tgPurgeMemoryCache")];
		if ([what isEqualToString:@"emoji"] || [what isEqualToString:@"all"])
			TGEmojiPurgeImages();
		if ([what isEqualToString:@"warning"] || [what isEqualToString:@"all"])
			[[NSNotificationCenter defaultCenter]
				postNotificationName:UIApplicationDidReceiveMemoryWarningNotification
							  object:[UIApplication sharedApplication]];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)),
			dispatch_get_main_queue(), ^{
				unsigned long long after = TGResidentBytes();
				NSLog(@"PERF memflush %@ before=%.2f MB after=%.2f MB freed=%.2f MB",
					what, before / 1048576.0, after / 1048576.0,
					((double)before - (double)after) / 1048576.0);
			});
		return YES;
	}

	if ([host isEqualToString:@"lazyframeworks"]) {
		TGFrameworkSelfTest();
		return YES;
	}

	if ([host isEqualToString:@"launchimage"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			if ([arg isEqualToString:@"restore"])
				[TGLaunchSnapshot restoreShippedImage:@"asked to"];
			NSLog(@"PERF launchimage state %@", [TGLaunchSnapshot describe]);
		});
		return YES;
	}

	if ([host isEqualToString:@"regions"]) {
		TGMemMark(arg.length ? arg : @"regions");
		TGRegionReport(arg.length ? arg : @"regions");
		return YES;
	}

	if ([host isEqualToString:@"captureframes"]) {
		[[NSUserDefaults standardUserDefaults] setBool:[arg isEqualToString:@"on"]
												forKey:@"tgCaptureFrames"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		NSLog(@"PERF captureframes %@", arg);
		return YES;
	}

	if ([host isEqualToString:@"perflog"]) {
		TGSetPerfLogging([arg isEqualToString:@"on"]);
		if (TGPerfLogging())
			TGStartMemorySampler();
		NSLog(@"PERF perflog %@", TGPerfLogging() ? @"on" : @"off");
		return YES;
	}

	if ([host isEqualToString:@"counts"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			TGClient *client = [TGClient shared];
			NSDictionary *main = [client unreadSummaryForList:TGChatListMain];
			NSDictionary *archive = [client unreadSummaryForList:TGChatListArchive];
			NSLog(@"PERF counts main=%lu archive=%lu mainUnreadChats=%@ archiveUnreadChats=%@",
				(unsigned long)[client.chats count],
				(unsigned long)[client.archivedChats count],
				main[@"chats"], archive[@"chats"]);
		});
		return YES;
	}

	if ([host isEqualToString:@"archive"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			UIViewController *top = [self topControllerOnScreen];
			if (![top respondsToSelector:@selector(openArchive)]) {
				NSLog(@"PERF archive: the chat list is not on screen");
				return;
			}
			[top performSelector:@selector(openArchive)];
		});
		return YES;
	}

	if ([host isEqualToString:@"layoutcache"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			UIViewController *top = [self topControllerOnScreen];
			if (![top isKindOfClass:TGChatViewController.class]) {
				NSLog(@"PERF layoutcache no chat on screen");
				return;
			}
			TGChatLayoutBridge *bridge = [top valueForKey:@"layoutBridge"];
			if ([arg isEqualToString:@"reset"]) {
				[bridge resetCacheCounts];
				NSLog(@"PERF layoutcache reset");
				return;
			}
			UITableView *chatTable = [top valueForKey:@"table"];
			NSLog(@"PERF layoutcache %@ table=%.0f view=%.0f",
				[bridge cacheCountsDescription],
				chatTable.bounds.size.width, top.view.bounds.size.width);
		});
		return YES;
	}

	if ([host isEqualToString:@"frametime"]) {
		if ([arg isEqualToString:@"on"])
			TGFrameTimeLoggingStart();
		else
			TGFrameTimeLoggingStop();
		NSLog(@"PERF frametime %@", TGFrameTimeLoggingActive() ? @"on" : @"off");
		return YES;
	}

	if ([host isEqualToString:@"scrollrun"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			UIScrollView *scroll = [self scrollViewToDrive];
			if (!scroll)
				return;
			CGFloat reach = MAX(0, scroll.contentSize.height - scroll.bounds.size.height +
				scroll.contentInset.bottom);
			CGFloat wanted = MIN(MAX(-scroll.contentInset.top, scroll.contentOffset.y + [arg floatValue]),
				reach);
			NSLog(@"PERF scrollrun from=%.0f to=%.0f reach=%.0f",
				scroll.contentOffset.y, wanted, reach);
			[UIView animateWithDuration:3.0
								  delay:0
								options:UIViewAnimationOptionCurveLinear
							 animations:^{
								 scroll.contentOffset = CGPointMake(0, wanted);
							 }
							 completion:nil];
		});
		return YES;
	}

	if ([host isEqualToString:@"bridgecounts"]) {
		if ([arg isEqualToString:@"reset"])
			[[TGClient shared] resetBridgeCounts];
		else
			[[TGClient shared] logBridgeCounts];
		return YES;
	}

	if ([host isEqualToString:@"stacks"]) {
		TGStackSamplingOn = [arg isEqualToString:@"on"];
		if (TGStackSamplingOn)
			TGStartMemorySampler();
		NSLog(@"PERF stacks %@", TGStackSamplingOn ? @"on" : @"off");
		return YES;
	}

	if ([host isEqualToString:@"stacksatlaunch"]) {
		[[NSUserDefaults standardUserDefaults] setBool:[arg isEqualToString:@"on"]
												forKey:@"tgStacksAtLaunch"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		NSLog(@"PERF stacksatlaunch %@", arg);
		return YES;
	}

	if ([host isEqualToString:@"phone"] && arg.length) {
		NSCharacterSet *digits = [NSCharacterSet decimalDigitCharacterSet];
		NSCharacterSet *inArg = [NSCharacterSet characterSetWithCharactersInString:arg];
		NSString *number = [digits isSupersetOfSet:inArg] ? [@"+" stringByAppendingString:arg] : arg;
		self.currentPhoneNumber = number;
		[[TGClient shared] sendPhoneNumber:number];
		return YES;
	}

	if ([host isEqualToString:@"code"] && arg.length) {
		NSLog(@"code received (%lu chars)", (unsigned long)arg.length);
		[[TGClient shared] sendCode:arg];
		return YES;
	}

	if ([host isEqualToString:@"password"] && arg.length) {
		NSLog(@"password received (%lu chars)", (unsigned long)arg.length);
		[[TGClient shared] sendPassword:arg];
		return YES;
	}

	if ([host isEqualToString:@"tab"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			UITabBarController *tabs = [self tabControllerForHarness];
			NSInteger idx = [arg integerValue];
			if (!tabs || idx < 0 || idx >= (NSInteger)tabs.viewControllers.count)
				return;
			[tabs setSelectedIndex:(NSUInteger)idx];

			UIViewController *chosen = tabs.viewControllers[idx];
			if ([chosen isKindOfClass:UINavigationController.class])
				[(UINavigationController *)chosen popToRootViewControllerAnimated:NO];
		});
		return YES;
	}

	if ([host isEqualToString:@"gifpicker"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			UIViewController *top = [self topControllerOnScreen];
			if (![top isKindOfClass:TGChatViewController.class])
				return;
			SEL selector = NSSelectorFromString(@"showGifPicker");
			if ([top respondsToSelector:selector])
				[top performSelector:selector];
		});
		return YES;
	}

	if ([host isEqualToString:@"composerstate"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			if (!TGPerfLogging())
				return;
			UIViewController *top = [self topControllerOnScreen];
			if (![top isKindOfClass:TGChatViewController.class])
				return;
			SEL selector = NSSelectorFromString(@"recomputeComposerState");
			if ([top respondsToSelector:selector])
				[top performSelector:selector];
			NSLog(@"PERF composerstate blocked=%@",
				[top valueForKey:@"postingBlocked"]);
		});
		return YES;
	}

	if ([host isEqualToString:@"dumpcode"] && arg.length) {
		unsigned long long address = strtoull(arg.UTF8String, NULL, 0);
		NSData *code = [NSData dataWithBytes:(const void *)(uintptr_t)address length:1024];
		NSString *cache = [NSSearchPathForDirectoriesInDomains(
			NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
		NSString *path = [cache stringByAppendingPathComponent:@"code.bin"];
		[code writeToFile:path atomically:YES];
		NSLog(@"dumpcode 0x%llx -> %@", address, path);
		return YES;
	}

	if ([host isEqualToString:@"symdump"]) {
		NSMutableString *dump = [NSMutableString string];
		unsigned int classCount = 0;
		Class *classes = objc_copyClassList(&classCount);
		for (unsigned int i = 0; i < classCount; i++) {
			Class cls = classes[i];
			const char *name = class_getName(cls);
			unsigned int methodCount = 0;
			Method *methods = class_copyMethodList(cls, &methodCount);
			for (unsigned int j = 0; j < methodCount; j++)
				[dump appendFormat:@"%p -[%s %s]\n",
					(void *)method_getImplementation(methods[j]), name,
					sel_getName(method_getName(methods[j]))];
			free(methods);
			unsigned int classMethodCount = 0;
			Method *classMethods = class_copyMethodList(object_getClass(cls), &classMethodCount);
			for (unsigned int j = 0; j < classMethodCount; j++)
				[dump appendFormat:@"%p +[%s %s]\n",
					(void *)method_getImplementation(classMethods[j]), name,
					sel_getName(method_getName(classMethods[j]))];
			free(classMethods);
		}
		free(classes);
		NSString *cache = [NSSearchPathForDirectoriesInDomains(
			NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
		NSString *path = [cache stringByAppendingPathComponent:@"symdump.txt"];
		[dump writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
		NSLog(@"symdump %u classes to %@", classCount, path);
		return YES;
	}

	if ([host isEqualToString:@"tdlog"]) {
		NSInteger level = MAX(0, MIN(10, [arg integerValue]));
		[[TGClient shared] setTdlibLogVerbosity:level];
		NSLog(@"tdlog verbosity %ld", (long)level);
		return YES;
	}

	if ([host isEqualToString:@"signup"] && arg.length) {
		[[TGClient shared] registerWithFirstName:arg lastName:nil completion:^(BOOL ok) {
			NSLog(@"signup %@ ok=%d", arg, ok);
		}];
		return YES;
	}

	if ([host isEqualToString:@"savedscope"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			UIViewController *top = [self topControllerOnScreen];
			SEL selector = @selector(scopeTapped:);
			if (![top respondsToSelector:selector]) {
				NSLog(@"savedscope: %@ is not the saved messages list", [top class]);
				return;
			}
			NSArray *buttons = [top valueForKey:@"scopeButtons"];
			NSInteger scope = [arg integerValue];
			if (scope < 0 || scope >= (NSInteger)buttons.count) {
				NSLog(@"savedscope: %ld out of range (%lu)", (long)scope,
					(unsigned long)buttons.count);
				return;
			}
			[top performSelector:selector withObject:buttons[scope]];
		});
		return YES;
	}

	if ([host isEqualToString:@"testdc"]) {
		BOOL wanted = [arg isEqualToString:@"on"];
		BOOL already = TGTestDCEnabled() == wanted;
		TGSetTestDCEnabled(wanted);
		NSLog(@"testdc %@%@", wanted ? @"on" : @"off",
			already ? @" (unchanged)" : @" - relaunch to apply");
		return YES;
	}

	if ([host isEqualToString:@"chatindex"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			TGBeginOpenTimingFromTap();
			NSArray *chats = [TGClient shared].chats;
			NSInteger idx = [arg integerValue];
			if (idx < 0 || idx >= (NSInteger)chats.count) {
				NSLog(@"chatindex %ld out of range (%lu)",
					(long)idx, (unsigned long)chats.count);
				return;
			}
			if (![chats[idx] isKindOfClass:[NSDictionary class]])
				return;
			NSDictionary *c = (NSDictionary *)chats[idx];

			UITabBarController *tabs = [self tabControllerForHarness];
			if (!tabs)
				return;
			tabs.selectedIndex = kTabIndexChats;
			UINavigationController *nc = tabs.viewControllers[kTabIndexChats];
			[nc popToRootViewControllerAnimated:NO];

			if ([c[@"isForum"] boolValue]) {
				TGTopicsViewController *topics = [[TGTopicsViewController alloc] init];
				topics.chatId = [c[@"id"] longLongValue];
				topics.chatTitle = c[@"title"];
				[nc pushViewController:topics animated:NO];
				NSLog(@"open forum index %ld", (long)idx);
				return;
			}

			id listController = [nc.viewControllers firstObject];
			if ([listController isKindOfClass:[TGChatListViewController class]])
				[(TGChatListViewController *)listController
					prefetchOpenHistoryForChat:[c[@"id"] longLongValue]];

			TGChatViewController *vc = [[TGChatViewController alloc] init];
			vc.chatId = [c[@"id"] longLongValue];
			vc.chatTitle = c[@"title"];
			vc.group = [c[@"isGroup"] boolValue];
			if (![RootViewController presentInDetail:vc])
				[nc pushViewController:vc animated:NO];
			NSLog(@"open chat index %ld", (long)idx);
		});
		return YES;
	}

	if ([host isEqualToString:@"touch"] || [host isEqualToString:@"hold"]) {
		BOOL holding = [host isEqualToString:@"hold"];

		NSMutableArray *parts = [NSMutableArray array];
		for (NSString *component in url.pathComponents)
			if (![component isEqualToString:@"/"] && component.length)
				[parts addObject:component];
		if (parts.count < 2) {
			NSLog(@"touch: expected x and y, got %@", url.path);
			return YES;
		}

		CGPoint point = CGPointMake([parts[0] floatValue], [parts[1] floatValue]);
		NSTimeInterval seconds = (holding && parts.count > 2)
			? [parts[2] doubleValue] / 1000.0
			: 0;

		dispatch_async(dispatch_get_main_queue(), ^{
			UIWindow *window = [UIApplication sharedApplication].keyWindow;
			UIView *hit = [window hitTest:point withEvent:nil];
			NSLog(@"touch at %.0f,%.0f hit %@", point.x, point.y, [hit class]);

			UIControl *control = nil;
			for (UIView *view = hit; view; view = view.superview)
				if ([view isKindOfClass:UIControl.class]) {
					control = (UIControl *)view;
					break;
				}

			Class tabBarClass = NSClassFromString(@"TGTabBar");
			for (UIView *view = hit; view; view = view.superview) {
				if (tabBarClass && [view isKindOfClass:tabBarClass]) {
					int slot = [(id<TGTabBarHitTesting>)view
						indexForLocation:[view convertPoint:point fromView:nil]];
					NSInteger index = [(id<TGTabBarHitTesting>)view tabForSlot:slot];
					if (slot < 0 || index < 0)
						return;
					if ([view respondsToSelector:@selector(setSelectedIndex:)])
						[view setValue:@(index) forKey:@"selectedIndex"];
					id delegate = [view valueForKey:@"tabDelegate"];
					SEL selector = @selector(tabBarSelectedItem:);
					if ([delegate respondsToSelector:selector]) {
						NSMethodSignature *sig = [delegate methodSignatureForSelector:selector];
						NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
						invocation.selector = selector;
						[invocation setArgument:&index atIndex:2];
						[invocation invokeWithTarget:delegate];
					}
					NSLog(@"touch: TGTabBar -> slot %d tab %d", slot, index);
					return;
				}
			}

			if ([control isKindOfClass:UISwitch.class]) {
				UISwitch *toggle = (UISwitch *)control;
				[toggle setOn:!toggle.on animated:YES];
				[toggle sendActionsForControlEvents:UIControlEventValueChanged];
				NSLog(@"touch: switch -> %@", toggle.on ? @"on" : @"off");
				return;
			}

			for (UIView *view = hit; view; view = view.superview) {
				if (![view isKindOfClass:UITextView.class] && ![view isKindOfClass:UITextField.class])
					continue;
				[view becomeFirstResponder];
				NSLog(@"touch: %@ -> first responder", [view class]);
				return;
			}

			if (holding) {
				UILongPressGestureRecognizer *press = nil;
				for (UIView *view = hit; view && !press; view = view.superview) {
					for (UIGestureRecognizer *recognizer in view.gestureRecognizers)
						if ([recognizer isKindOfClass:UILongPressGestureRecognizer.class] &&
							recognizer.enabled && recognizer.view.userInteractionEnabled) {
							press = (UILongPressGestureRecognizer *)recognizer;
							break;
						}
					if (!press && [view isKindOfClass:UIScrollView.class])
						break;
				}
				if (press) {
					NSLog(@"hold: long-press recognizer on %@", [press.view class]);
					[press setValue:@(UIGestureRecognizerStateBegan) forKey:@"state"];
					[self fireGestureRecognizer:press];
					[press setValue:@(UIGestureRecognizerStateEnded) forKey:@"state"];
					return;
				}
			}

			if (!holding) {
				UITapGestureRecognizer *tap = nil;
				for (UIView *view = hit; view && !tap; view = view.superview) {
					if ([view isKindOfClass:UIScrollView.class])
						break;
					if ([view isKindOfClass:UIControl.class] &&
						((UIControl *)view).enabled &&
						((UIControl *)view).allTargets.count != 0)
						break;
					for (UIGestureRecognizer *recognizer in view.gestureRecognizers)
						if ([recognizer isKindOfClass:UITapGestureRecognizer.class] &&
							recognizer.enabled && recognizer.view.userInteractionEnabled) {
							tap = (UITapGestureRecognizer *)recognizer;
							break;
						}
				}
				if (tap) {
					NSLog(@"touch: tap recognizer on %@", [tap.view class]);
					[self fireGestureRecognizer:tap];
					return;
				}
			}

			BOOL hitIsItsOwnControl = [hit isKindOfClass:UIControl.class] &&
				((UIControl *)hit).enabled &&
				((UIControl *)hit).allTargets.count != 0;

			for (UIView *view = hit; !hitIsItsOwnControl && view; view = view.superview) {
				if (![view isKindOfClass:UITableView.class])
					continue;
				UITableView *table = (UITableView *)view;
				NSIndexPath *path = [table indexPathForRowAtPoint:
						[table convertPoint:point fromView:nil]];
				if (!path)
					break;
				if (![table.delegate respondsToSelector:
							@selector(tableView:didSelectRowAtIndexPath:)])
					break;
				[table.delegate tableView:table didSelectRowAtIndexPath:path];
				NSLog(@"touch: table row %d", (int)path.row);
				return;
			}

			if (control) {
				[control sendActionsForControlEvents:UIControlEventTouchDown];
				if (seconds > 0) {
					dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
									   (int64_t)(seconds * NSEC_PER_SEC)),
						dispatch_get_main_queue(), ^{
							[control sendActionsForControlEvents:UIControlEventTouchUpInside];
							NSLog(@"released after %.0f ms", seconds * 1000);
						});
				} else {
					[control sendActionsForControlEvents:UIControlEventTouchUpInside];
				}
				return;
			}

			SEL openPlayer = NSSelectorFromString(@"openFullPlayer");
			for (UIView *view = hit; view; view = view.superview) {
				if (![view respondsToSelector:openPlayer])
					continue;
				void (*invoke)(id, SEL) = (void (*)(id, SEL))
					[view methodForSelector:openPlayer];
				invoke(view, openPlayer);
				NSLog(@"touch: opened full player");
				return;
			}

			if ([NSStringFromClass([hit class]) rangeOfString:@"Dimming"].location != NSNotFound) {
				for (id sheet in TGVisibleAlertsInWindows([UIApplication sharedApplication].windows))
					if ([sheet isKindOfClass:UIActionSheet.class]) {
						[(UIActionSheet *)sheet dismissWithClickedButtonIndex:-1 animated:YES];
						NSLog(@"touch: dismissed action sheet");
						return;
					}
			}

			NSLog(@"touch: nothing actionable at that point");
		});
		return YES;
	}

	if ([host isEqualToString:@"hangup"]) {
		dispatch_async(dispatch_get_main_queue(), ^{ [[TGCall shared] hangUp]; });
		return YES;
	}

	if ([host isEqualToString:@"type"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			NSString *text = [arg stringByReplacingPercentEscapesUsingEncoding:
									 NSUTF8StringEncoding]
				?: arg;
			UIView *responder = [self firstResponderUnder:self.window];
			if (!responder) {
				UISearchBar *bar = [self searchBarUnder:self.window];
				[bar becomeFirstResponder];
				responder = [self firstResponderUnder:self.window] ?: bar;
			}
			if ([responder isKindOfClass:UITextField.class]) {
				UITextField *field = (UITextField *)responder;
				field.text = text;
				[field sendActionsForControlEvents:UIControlEventEditingChanged];
			}

			if ([responder isKindOfClass:UITextView.class])
				[(UITextView *)responder setText:text];

			UIView *bar = responder;
			while (bar && ![bar isKindOfClass:UISearchBar.class])
				bar = bar.superview;
			if (bar) {
				[(UISearchBar *)bar setText:text];
				id<UISearchBarDelegate> delegate = [(UISearchBar *)bar delegate];
				if ([delegate respondsToSelector:@selector(searchBar:textDidChange:)])
					[delegate searchBar:(UISearchBar *)bar textDidChange:text];
			}
			NSLog(@"type: %@ into %@", text, responder ? [responder class] : (id) @"nothing");
		});
		return YES;
	}

	if ([host isEqualToString:@"search"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			UINavigationController *nc = [self navigationControllerForPush];
			if (!nc) {
				NSLog(@"search: no navigation controller on screen");
				return;
			}
			[nc pushViewController:[[TGSearchViewController alloc] init] animated:YES];
		});
		return YES;
	}

	if ([host isEqualToString:@"badgetest"]) {
		NSInteger count = arg.integerValue;
		dispatch_async(dispatch_get_main_queue(), ^{
			UIViewController *top = [self topControllerOnScreen];
			UIButton *backButton = (UIButton *)top.navigationItem.leftBarButtonItem.customView;
			[TGIcons setUnreadCount:count onBackButton:backButton];
		});
		return YES;
	}

	if ([host isEqualToString:@"snackbar"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			[TGSnackbar showInView:self.window.rootViewController.view
							  text:TGL(@"Undo.ChatDeleted", @"Chat deleted")
						   seconds:5
						  onCommit:^{ NSLog(@"snackbar: committed (test, no-op)"); }];
		});
		return YES;
	}

	if ([host isEqualToString:@"holdrow"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			UITabBarController *tabs = [self tabControllerForHarness];
			if (!tabs)
				return;
			UIViewController *top = [self topControllerOnScreen];
			if (![top respondsToSelector:@selector(showActionsForRow:)]) {
				NSLog(@"holdrow: %@ has no row menu", [top class]);
				return;
			}
			NSLog(@"holdrow: %ld on %@", (long)[arg integerValue], [top class]);
			NSInteger row = [arg integerValue];
			NSMethodSignature *sig = [top methodSignatureForSelector:
					@selector(showActionsForRow:)];
			NSInvocation *call = [NSInvocation invocationWithMethodSignature:sig];
			call.selector = @selector(showActionsForRow:);
			call.target = top;
			[call setArgument:&row atIndex:2];
			[call invoke];
		});
		return YES;
	}

	if ([host isEqualToString:@"scrollrow"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			UIViewController *top = [self topControllerOnScreen];
			UITableView *table = [self firstTableViewIn:top.view];
			if (!table)
				for (UIWindow *window in [[UIApplication sharedApplication] windows])
					if (!table)
						table = [self firstTableViewIn:window];
			if (!table) {
				NSLog(@"scrollrow found no table");
				return;
			}
			NSInteger row = [arg integerValue];
			NSInteger rows = [table numberOfRowsInSection:0];
			if (row < 0 || row >= rows) {
				NSLog(@"scrollrow %ld out of range (%ld)", (long)row, (long)rows);
				return;
			}
			[table scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]
						 atScrollPosition:UITableViewScrollPositionMiddle
								 animated:NO];
			NSLog(@"scrollrow %ld of %ld", (long)row, (long)rows);
		});
		return YES;
	}

	if ([host isEqualToString:@"scrollmaster"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			UITableView *table = [self masterTableOnScreen];
			if (!table) {
				NSLog(@"scrollmaster found no master table");
				return;
			}
			CGFloat reach = MAX(0, table.contentSize.height - table.bounds.size.height +
					table.contentInset.bottom);
			CGFloat wanted = MIN(MAX(-table.contentInset.top, [arg floatValue]), reach);
			[table setContentOffset:CGPointMake(0, wanted) animated:NO];
		});
		return YES;
	}

	if ([host isEqualToString:@"scroll"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			UIScrollView *scroll = [self scrollViewToDrive];
			if (!scroll)
				return;
			CGFloat reach = MAX(0, scroll.contentSize.height - scroll.bounds.size.height + scroll.contentInset.bottom);
			CGFloat wanted = MIN(MAX(-scroll.contentInset.top, [arg floatValue]), reach);
			[scroll setContentOffset:CGPointMake(0, wanted) animated:NO];
		});
		return YES;
	}

	if ([host isEqualToString:@"device"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			UITabBarController *tabs = [self tabControllerForHarness];
			if (!tabs)
				return;
			tabs.selectedIndex = tabs.viewControllers.count - 1;
			UINavigationController *nc = tabs.viewControllers[tabs.selectedIndex];
			[nc popToRootViewControllerAnimated:NO];
			[nc pushViewController:[[TGDeviceViewController alloc] init] animated:NO];
		});
		return YES;
	}

	if ([host isEqualToString:@"videoloop"]) {
		NSArray *parts = [arg componentsSeparatedByString:@"x"];
		unsigned int width = parts.count == 2 ? (unsigned int)[parts[0] integerValue] : 320;
		unsigned int height = parts.count == 2 ? (unsigned int)[parts[1] integerValue] : 240;
		dispatch_async(dispatch_get_main_queue(), ^{
			[TGVideoLoopback runAtWidth:width height:height seconds:8.0];
		});
		return YES;
	}

	if ([host isEqualToString:@"pollupdate"] && arg.length) {
		NSArray<NSString *> *parts = [arg componentsSeparatedByString:@"-"];
		long long pollId = parts.count > 0 ? [parts[0] longLongValue] : 0;
		NSInteger total = parts.count > 1 ? [parts[1] integerValue] : 0;
		if (!pollId)
			return YES;
		NSDictionary *fields = @{
			@"pollId" : @(pollId),
			@"pollTotal" : @(total),
			@"pollClosed" : @(parts.count > 2 && [parts[2] isEqualToString:@"closed"]),
		};
		dispatch_async(dispatch_get_main_queue(), ^{
			[[NSNotificationCenter defaultCenter]
				postNotificationName:TGPollDidChangeNotification
							  object:[TGClient shared]
							userInfo:@{TGPollDataKey : fields}];
			NSLog(@"pollupdate: poll %lld now shows %ld votes", pollId, (long)total);
		});
		return YES;
	}

	if ([host isEqualToString:@"stickers"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			UITabBarController *tabs = [self tabControllerForHarness];
			if (!tabs)
				return;
			UIViewController *top = [self topControllerOnScreen];
			if ([top respondsToSelector:@selector(toggleStickerPanel)])
				[top performSelector:@selector(toggleStickerPanel)];
		});
		return YES;
	}

	if ([host isEqualToString:@"pinnedmenu"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			UIViewController *top = [self topControllerOnScreen];
			if ([top respondsToSelector:@selector(showPinnedBannerMenu)])
				[top performSelector:@selector(showPinnedBannerMenu)];
		});
		return YES;
	}

	if ([host isEqualToString:@"dayplate"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			UIViewController *top = [self topControllerOnScreen];
			if ([top respondsToSelector:@selector(simulateTapOnDayPlate)])
				[top performSelector:@selector(simulateTapOnDayPlate)];
			else
				NSLog(@"dayplate: %@ is not a chat", [top class]);
		});
		return YES;
	}

	if ([host isEqualToString:@"compose"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			NSString *text = [[[url absoluteString]
				substringFromIndex:MIN([url absoluteString].length,
									   [@"telegramdev://compose/" length])]
				stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
			UIViewController *top = [self topControllerOnScreen];
			if ([top isKindOfClass:[TGChatViewController class]])
				[(TGChatViewController *)top simulateComposerText:text ?: @""];
			else
				NSLog(@"compose: no chat on screen");
		});
		return YES;
	}

	if ([host isEqualToString:@"profile"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			UITabBarController *tabs = [self tabControllerForHarness];
			if (!tabs)
				return;
			UIViewController *top = [self topControllerOnScreen];
			if ([top respondsToSelector:@selector(openProfile)])
				[top performSelector:@selector(openProfile)];
			else
				NSLog(@"profile: no chat on screen");
		});
		return YES;
	}

	if ([host isEqualToString:@"where"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			UITabBarController *tabs = [self tabControllerForHarness];
			UIViewController *master = nil;
			if (tabs && tabs.selectedIndex < tabs.viewControllers.count) {
				id nc = tabs.viewControllers[tabs.selectedIndex];
				master = [nc isKindOfClass:UINavigationController.class]
					? [(UINavigationController *)nc topViewController]
					: nc;
			}
			UINavigationController *detail = [RootViewController detailNavigationController];
			NSLog(@"WHERE tab=%ld master=%@ detail=%@ top=%@",
				tabs ? (long)tabs.selectedIndex : -1,
				master ? NSStringFromClass([master class]) : @"none",
				detail ? NSStringFromClass([detail.topViewController class]) : @"none",
				NSStringFromClass([[self topControllerOnScreen] class]));
		});
		return YES;
	}

	if ([host isEqualToString:@"back"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			UIViewController *presented = self.rootViewController.presentedViewController;
			while (presented.presentedViewController)
				presented = presented.presentedViewController;
			if (presented) {
				[presented dismissViewControllerAnimated:NO completion:nil];
				return;
			}
			UIViewController *top = [self topControllerOnScreen];
			UINavigationController *nav = top.navigationController;
			if (nav.viewControllers.count > 1) {
				[nav popViewControllerAnimated:NO];
				return;
			}
			if (nav && nav == [RootViewController detailNavigationController]) {
				[RootViewController showDetailEmptyState];
				return;
			}
			NSLog(@"back: nothing to leave");
		});
		return YES;
	}

	if ([host isEqualToString:@"tap"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			UIViewController *presented = self.rootViewController.presentedViewController;
			while (presented.presentedViewController)
				presented = presented.presentedViewController;
			UIViewController *top;
			if ([presented isKindOfClass:UINavigationController.class])
				top = ((UINavigationController *)presented).topViewController;
			else if (presented)
				top = presented;
			else {
				top = [self topControllerOnScreen];
				if (!top)
					return;
			}

			UITableView *table = [top isKindOfClass:UITableViewController.class]
				? [(UITableViewController *)top tableView]
				: nil;
			if (!table && [top respondsToSelector:@selector(table)]) {
				id candidate = [top valueForKey:@"table"];
				if ([candidate isKindOfClass:[UITableView class]])
					table = candidate;
			}
			if (!table && [top respondsToSelector:@selector(tableView)]) {
				id candidate = [top valueForKey:@"tableView"];
				if ([candidate isKindOfClass:[UITableView class]])
					table = candidate;
			}
			if ([top isKindOfClass:[TGChatViewController class]]) {
				NSMutableArray *chatParts = [NSMutableArray array];
				for (NSString *component in url.pathComponents)
					if (![component isEqualToString:@"/"] && component.length)
						[chatParts addObject:component];
				if (chatParts.count != 1) {
					NSLog(@"tap: %@ names a section and a row, but a chat has only rows", url.path);
					return;
				}
				[(TGChatViewController *)top simulateTapOnRow:[chatParts[0] integerValue]];
			} else if (table) {
				NSMutableArray *parts = [NSMutableArray array];
				for (NSString *component in url.pathComponents)
					if (![component isEqualToString:@"/"] && component.length)
						[parts addObject:component];
				NSIndexPath *path = (parts.count > 1)
					? [NSIndexPath indexPathForRow:[parts[1] integerValue]
										 inSection:[parts[0] integerValue]]
					: [NSIndexPath indexPathForRow:[arg integerValue] inSection:0];

				NSInteger rows = [table numberOfRowsInSection:path.section];
				if (path.section >= [table numberOfSections] || path.row >= rows) {
					NSLog(@"tap: %ld.%ld is out of range (%ld rows)",
						(long)path.section, (long)path.row, (long)rows);
					return;
				}
				NSLog(@"tap: %ld.%ld on %@", (long)path.section, (long)path.row, [top class]);
				[table.delegate tableView:table didSelectRowAtIndexPath:path];
			} else {
				NSLog(@"tap: %@ has no rows", [top class]);
			}
		});
		return YES;
	}

	if ([host isEqualToString:@"screenshot"]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			@autoreleasepool {
				UIGraphicsBeginImageContextWithOptions(self.window.bounds.size, YES, 0.0f);
				CGContextRef ctx = UIGraphicsGetCurrentContext();

				for (UIWindow *w in [UIApplication sharedApplication].windows) {
					if (w.hidden || w.alpha <= 0.01f)
						continue;
					CGContextSaveGState(ctx);
					CGContextTranslateCTM(ctx, w.frame.origin.x, w.frame.origin.y);
					[w.layer renderInContext:ctx];
					CGContextRestoreGState(ctx);
				}
				UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
				UIGraphicsEndImageContext();

				NSString *dir = [NSSearchPathForDirectoriesInDomains(
					NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
				NSString *path = [dir stringByAppendingPathComponent:@"screen.png"];
				BOOL ok = [UIImagePNGRepresentation(img) writeToFile:path atomically:YES];
				NSLog(@"screenshot %@", ok ? @"saved" : @"FAILED");
			}
		});
		return YES;
	}

	return YES;
}

@end

#import <Foundation/Foundation.h>

#import <notify.h>
#import <objc/message.h>
#import <objc/runtime.h>

static NSString *const TSCApplicationIdentifier = @"com.kern0x1b.telegram";
static NSString *const TSCDisabledPath = @"/var/lib/telegramsystemcall/disabled";
static NSString *const TSCPayloadRelativePath = @"Library/Caches/systemcall.plist";
static NSString *const TSCAnswerURL = @"telegramdev://answer";

static const char *const TSCIncomingName = "com.kern0x1b.telegram.call.incoming";
static const char *const TSCEndedName = "com.kern0x1b.telegram.call.ended";
static const char *const TSCAnswerName = "com.kern0x1b.telegram.call.answer";
static const char *const TSCDeclineName = "com.kern0x1b.telegram.call.decline";

static const NSTimeInterval TSCPayloadMaximumAge = 90.0;
static const NSTimeInterval TSCWatchdogInterval = 75.0;

@protocol TSCAlertItem <NSObject>
+ (void)activateAlertItem:(id)item;
- (id)alertSheet;
- (void)dismiss;
@end

@protocol TSCAlertSheet <NSObject>
- (void)setTitle:(NSString *)title;
- (void)addButtonWithTitle:(NSString *)title;
- (void)setBodyText:(NSString *)text;
- (void)setNumberOfRows:(NSInteger)rows;
- (void)_addButtonWithTitle:(NSString *)title;
- (void)setDefaultButton:(NSInteger)index;
@end

@protocol TSCApplicationRecord <NSObject>
- (NSString *)containerPath;
@end

@protocol TSCApplicationController <NSObject>
+ (id)sharedInstanceIfExists;
- (id)applicationWithDisplayIdentifier:(NSString *)identifier;
@end

@protocol TSCAwayController <NSObject>
+ (id)sharedAwayControllerIfExists;
- (BOOL)isLocked;
@end

@protocol TSCSpringBoard <NSObject>
+ (id)sharedApplication;
- (BOOL)launchApplicationWithIdentifier:(NSString *)identifier suspended:(BOOL)suspended;
- (void)applicationOpenURL:(NSURL *)url publicURLsOnly:(BOOL)publicOnly;
@end

static BOOL gStop;
static Class gItemClass;
static id gItem;
static NSString *gCallerName;
static NSString *gSubtitle;
static NSTimer *gWatchdog;
static int gIncomingToken = NOTIFY_TOKEN_INVALID;
static int gEndedToken = NOTIFY_TOKEN_INVALID;

static void TSCLog(NSString *format, ...)
{
	va_list arguments;
	va_start(arguments, format);
	NSString *line = [[NSString alloc] initWithFormat:format arguments:arguments];
	va_end(arguments);
	NSLog(@"TelegramSystemCall: %@", line);
	[line release];
}

#pragma mark - shape guards

static BOOL TSCSignatureIs(NSMethodSignature *signature, const char *returnType,
						   const char *argumentTypes)
{
	if (!signature)
		return NO;
	size_t wanted = strlen(argumentTypes);
	if ([signature numberOfArguments] != wanted + 2)
		return NO;
	if (strcmp([signature methodReturnType], returnType) != 0)
		return NO;
	for (size_t i = 0; i < wanted; i++){
		char one[2] = {argumentTypes[i], 0};
		if (strcmp([signature getArgumentTypeAtIndex:i + 2], one) != 0)
			return NO;
	}
	return YES;
}

static BOOL TSCInstanceMethodIs(Class target, SEL selector, const char *returnType,
								const char *argumentTypes)
{
	if (!target || !class_getInstanceMethod(target, selector))
		return NO;
	return TSCSignatureIs([target instanceMethodSignatureForSelector:selector],
						  returnType, argumentTypes);
}

static BOOL TSCClassMethodIs(Class target, SEL selector, const char *returnType,
							 const char *argumentTypes)
{
	if (!target || ![target respondsToSelector:selector])
		return NO;
	return TSCSignatureIs([target methodSignatureForSelector:selector],
						  returnType, argumentTypes);
}

static BOOL TSCOverride(Class target, Class base, SEL selector, IMP implementation,
						const char *returnType, const char *argumentTypes,
						const char *encoding)
{
	if (!TSCInstanceMethodIs(base, selector, returnType, argumentTypes)){
		TSCLog(@"-%@ is not the shape this build expects; leaving it alone",
			   NSStringFromSelector(selector));
		return NO;
	}
	return class_addMethod(target, selector, implementation, encoding);
}

#pragma mark - strings

static NSString *TSCLocalized(NSBundle *bundle, NSString *key, NSString *table,
							  NSString *fallback)
{
	if (![bundle isKindOfClass:[NSBundle class]])
		return fallback;
	NSString *value = [bundle localizedStringForKey:key value:@"" table:table];
	if (![value isKindOfClass:[NSString class]] || ![value length] ||
		[value isEqualToString:key])
		return fallback;
	return value;
}

static NSString *TSCSpringBoardString(NSString *key, NSString *fallback)
{
	return TSCLocalized([NSBundle mainBundle], key, @"SpringBoard", fallback);
}

static NSString *TSCTelephonyString(NSString *key, NSString *fallback)
{
	static NSBundle *bundle;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		bundle = [[NSBundle bundleWithPath:
				@"/System/Library/PrivateFrameworks/TelephonyUI.framework"] retain];
		[bundle load];
	});
	return TSCLocalized(bundle, key, @"General", fallback);
}

#pragma mark - payload

static NSString *TSCContainerPath(void)
{
	Class controller = objc_getClass("SBApplicationController");
	if (!TSCClassMethodIs(controller, @selector(sharedInstanceIfExists), "@", ""))
		return nil;
	id shared = [(Class <TSCApplicationController>)controller sharedInstanceIfExists];
	if (![shared respondsToSelector:@selector(applicationWithDisplayIdentifier:)])
		return nil;
	id record = [(id <TSCApplicationController>)shared
			applicationWithDisplayIdentifier:TSCApplicationIdentifier];
	if (![record respondsToSelector:@selector(containerPath)])
		return nil;
	NSString *path = [(id <TSCApplicationRecord>)record containerPath];
	return [path isKindOfClass:[NSString class]] && [path length] ? path : nil;
}

static NSDictionary *TSCReadPayload(void)
{
	NSString *container = TSCContainerPath();
	if (!container)
		return nil;
	NSString *path = [container stringByAppendingPathComponent:TSCPayloadRelativePath];
	NSDictionary *payload = [NSDictionary dictionaryWithContentsOfFile:path];
	if (![payload isKindOfClass:[NSDictionary class]])
		return nil;

	id stamp = [payload objectForKey:@"posted"];
	if ([stamp respondsToSelector:@selector(doubleValue)]){
		NSTimeInterval age = CFAbsoluteTimeGetCurrent() - [stamp doubleValue];
		if (age < -TSCPayloadMaximumAge || age > TSCPayloadMaximumAge){
			TSCLog(@"payload is %.0f s old; ignoring it", age);
			return nil;
		}
	}
	return payload;
}

#pragma mark - handing the answer back

static void TSCForegroundApplication(void)
{
	Class springBoard = objc_getClass("SpringBoard");
	if (!TSCClassMethodIs(springBoard, @selector(sharedApplication), "@", ""))
		return;
	id application = [(Class <TSCSpringBoard>)springBoard sharedApplication];

	if (TSCInstanceMethodIs([application class],
							@selector(launchApplicationWithIdentifier:suspended:), "c", "@c")){
		[(id <TSCSpringBoard>)application
				launchApplicationWithIdentifier:TSCApplicationIdentifier suspended:NO];
		return;
	}
	if (TSCInstanceMethodIs([application class],
							@selector(applicationOpenURL:publicURLsOnly:), "v", "@c")){
		[(id <TSCSpringBoard>)application
				applicationOpenURL:[NSURL URLWithString:TSCAnswerURL] publicURLsOnly:NO];
		return;
	}
	TSCLog(@"no way to bring %@ forward on this build", TSCApplicationIdentifier);
}

static BOOL TSCDeviceIsLocked(void)
{
	Class away = objc_getClass("SBAwayController");
	if (!TSCClassMethodIs(away, @selector(sharedAwayControllerIfExists), "@", ""))
		return NO;
	id controller = [(Class <TSCAwayController>)away sharedAwayControllerIfExists];
	if (!TSCInstanceMethodIs([controller class], @selector(isLocked), "c", ""))
		return NO;
	return [(id <TSCAwayController>)controller isLocked];
}

static id TSCForget(void)
{
	[gWatchdog invalidate];
	[gWatchdog release];
	gWatchdog = nil;

	id item = gItem;
	gItem = nil;
	[gCallerName release];
	gCallerName = nil;
	[gSubtitle release];
	gSubtitle = nil;
	return [item autorelease];
}

static void TSCDismiss(void)
{
	id item = TSCForget();
	if (!item)
		return;
	@try {
		if ([item respondsToSelector:@selector(dismiss)])
			[(id <TSCAlertItem>)item dismiss];
	}
	@catch (NSException *exception){
		TSCLog(@"dismiss raised %@ (%@)", [exception name], [exception reason]);
	}
}

static void TSCAnswer(BOOL alertIsDismissingItself)
{
	notify_post(TSCAnswerName);
	if (alertIsDismissingItself)
		TSCForget();
	else
		TSCDismiss();
	if (!TSCDeviceIsLocked())
		TSCForegroundApplication();
}

static void TSCDecline(BOOL alertIsDismissingItself)
{
	notify_post(TSCDeclineName);
	if (alertIsDismissingItself)
		TSCForget();
	else
		TSCDismiss();
}

#pragma mark - the alert item

static void TSCConfigure(id self, SEL _cmd, BOOL configure, BOOL requirePasscode)
{
	if (gStop || ![self respondsToSelector:@selector(alertSheet)])
		return;
	@try {
		id sheet = [(id <TSCAlertItem>)self alertSheet];
		if (!sheet)
			return;
		if (![sheet respondsToSelector:@selector(addButtonWithTitle:)]){
			TSCLog(@"the alert sheet on this build takes no buttons; leaving it alone");
			return;
		}

		if ([sheet respondsToSelector:@selector(setTitle:)])
			[(id <TSCAlertSheet>)sheet setTitle:gCallerName ?: @"Telegram"];
		if (gSubtitle && [sheet respondsToSelector:@selector(setBodyText:)])
			[(id <TSCAlertSheet>)sheet setBodyText:gSubtitle];
		if ([sheet respondsToSelector:@selector(setNumberOfRows:)])
			[(id <TSCAlertSheet>)sheet setNumberOfRows:1];

		[(id <TSCAlertSheet>)sheet addButtonWithTitle:
				TSCTelephonyString(@"DECLINE", @"Decline")];

		NSString *answer = TSCTelephonyString(@"ANSWER", @"Answer");
		if ([sheet respondsToSelector:@selector(_addButtonWithTitle:)])
			[(id <TSCAlertSheet>)sheet _addButtonWithTitle:answer];
		else
			[(id <TSCAlertSheet>)sheet addButtonWithTitle:answer];

		if ([sheet respondsToSelector:@selector(setDefaultButton:)])
			[(id <TSCAlertSheet>)sheet setDefaultButton:1];
	}
	@catch (NSException *exception){
		gStop = YES;
		TSCLog(@"configure raised %@ (%@); the tweak is now inert",
			   [exception name], [exception reason]);
	}
}

static id TSCLockLabel(id self, SEL _cmd)
{
	return TSCSpringBoardString(@"SLIDE_TO_ANSWER", @"slide to answer");
}

static void TSCPerformUnlockAction(id self, SEL _cmd)
{
	TSCAnswer(NO);
}

static void TSCClickedButton(id self, SEL _cmd, id sheet, NSInteger index)
{
	if (index == 1)
		TSCAnswer(YES);
	else
		TSCDecline(YES);
}

static BOOL TSCYes(id self, SEL _cmd)
{
	return YES;
}

static BOOL TSCNo(id self, SEL _cmd)
{
	return NO;
}

static double TSCZero(id self, SEL _cmd)
{
	return 0.0;
}

static Class TSCBuildItemClass(void)
{
	Class existing = objc_getClass("TSCIncomingCallAlertItem");
	if (existing)
		return existing;

	Class base = objc_getClass("SBAlertItem");
	if (!base){
		TSCLog(@"SBAlertItem is missing; doing nothing");
		return Nil;
	}
	if (!TSCClassMethodIs(base, @selector(activateAlertItem:), "v", "@")){
		TSCLog(@"+activateAlertItem: is not the shape this build expects; doing nothing");
		return Nil;
	}
	if (!TSCInstanceMethodIs(base, @selector(alertSheet), "@", "") ||
		!TSCInstanceMethodIs(base, @selector(dismiss), "v", "")){
		TSCLog(@"SBAlertItem has an unexpected shape; doing nothing");
		return Nil;
	}
	if (!TSCInstanceMethodIs(base, @selector(configure:requirePasscodeForActions:),
							 "v", "cc")){
		TSCLog(@"-configure:requirePasscodeForActions: is not the shape this build "
			   @"expects; doing nothing");
		return Nil;
	}

	Class item = objc_allocateClassPair(base, "TSCIncomingCallAlertItem", 0);
	if (!item){
		TSCLog(@"could not allocate the alert item class; doing nothing");
		return Nil;
	}

	if (!TSCOverride(item, base, @selector(configure:requirePasscodeForActions:),
					 (IMP)(void *)TSCConfigure, "v", "cc", "v@:cc")){
		objc_disposeClassPair(item);
		return Nil;
	}
	if (!TSCOverride(item, base, @selector(alertView:clickedButtonAtIndex:),
					 (IMP)(void *)TSCClickedButton, "v", "@i", "v@:@i")){
		objc_disposeClassPair(item);
		return Nil;
	}

	TSCOverride(item, base, @selector(lockLabel), (IMP)(void *)TSCLockLabel, "@", "", "@@:");
	TSCOverride(item, base, @selector(shortLockLabel), (IMP)(void *)TSCLockLabel, "@", "", "@@:");
	TSCOverride(item, base, @selector(performUnlockAction),
				(IMP)(void *)TSCPerformUnlockAction, "v", "", "v@:");
	TSCOverride(item, base, @selector(shouldShowInLockScreen), (IMP)(void *)TSCYes, "c", "", "c@:");
	TSCOverride(item, base, @selector(undimsScreen), (IMP)(void *)TSCYes, "c", "", "c@:");
	TSCOverride(item, base, @selector(preventLockOver), (IMP)(void *)TSCYes, "c", "", "c@:");
	TSCOverride(item, base, @selector(isCriticalAlert), (IMP)(void *)TSCYes, "c", "", "c@:");
	TSCOverride(item, base, @selector(unlocksScreen), (IMP)(void *)TSCNo, "c", "", "c@:");
	TSCOverride(item, base, @selector(dismissOnLock), (IMP)(void *)TSCNo, "c", "", "c@:");
	TSCOverride(item, base, @selector(allowMenuButtonDismissal), (IMP)(void *)TSCNo, "c", "", "c@:");
	TSCOverride(item, base, @selector(autoDismissInterval), (IMP)(void *)TSCZero, "d", "", "d@:");

	objc_registerClassPair(item);
	return item;
}

#pragma mark - presenting

static void TSCWatchdogFired(void)
{
	TSCLog(@"nothing said the call was over within %.0f s; taking the alert down",
		   TSCWatchdogInterval);
	TSCDismiss();
}

@interface TSCWatchdogTarget : NSObject
@end

@implementation TSCWatchdogTarget
- (void)fire:(NSTimer *)timer
{
	TSCWatchdogFired();
}
@end

static void TSCPresent(void)
{
	if (gStop || !gItemClass || gItem)
		return;

	NSDictionary *payload = TSCReadPayload();
	NSString *name = [payload objectForKey:@"name"];
	NSString *subtitle = [payload objectForKey:@"subtitle"];
	[gCallerName release];
	gCallerName = [name isKindOfClass:[NSString class]] && [name length]
			? [name copy] : [@"Telegram" copy];
	[gSubtitle release];
	gSubtitle = [subtitle isKindOfClass:[NSString class]] && [subtitle length]
			? [subtitle copy] : nil;

	@try {
		id item = [[gItemClass alloc] init];
		if (!item)
			return;
		gItem = item;
		[(Class <TSCAlertItem>)objc_getClass("SBAlertItem") activateAlertItem:item];
	}
	@catch (NSException *exception){
		gStop = YES;
		[gItem release];
		gItem = nil;
		TSCLog(@"activating the alert raised %@ (%@); the tweak is now inert",
			   [exception name], [exception reason]);
		return;
	}

	static TSCWatchdogTarget *target;
	if (!target)
		target = [[TSCWatchdogTarget alloc] init];
	gWatchdog = [[NSTimer scheduledTimerWithTimeInterval:TSCWatchdogInterval
												  target:target
												selector:@selector(fire:)
												userInfo:nil
												 repeats:NO] retain];
	TSCLog(@"incoming call from %@", gCallerName);
}

#pragma mark - installation

__attribute__((constructor))
static void TSCInitialise(void)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	@try {
		if (!objc_getClass("SpringBoard")){
			[pool drain];
			return;
		}
		if ([[NSFileManager defaultManager] fileExistsAtPath:TSCDisabledPath]){
			TSCLog(@"switched off by %@", TSCDisabledPath);
			[pool drain];
			return;
		}

		gItemClass = TSCBuildItemClass();
		if (!gItemClass){
			[pool drain];
			return;
		}

		notify_register_dispatch(TSCIncomingName, &gIncomingToken,
								 dispatch_get_main_queue(), ^(int token){
			@try {
				TSCPresent();
			}
			@catch (NSException *exception){
				gStop = YES;
				TSCLog(@"present raised %@ (%@); the tweak is now inert",
					   [exception name], [exception reason]);
			}
		});
		notify_register_dispatch(TSCEndedName, &gEndedToken,
								 dispatch_get_main_queue(), ^(int token){
			@try {
				TSCDismiss();
			}
			@catch (NSException *exception){
				TSCLog(@"dismiss raised %@ (%@)", [exception name], [exception reason]);
			}
		});

		TSCLog(@"installed in %@", [[NSProcessInfo processInfo] processName]);
	}
	@catch (NSException *exception){
		gStop = YES;
		TSCLog(@"install raised %@ (%@); nothing is active",
			   [exception name], [exception reason]);
	}
	[pool drain];
}

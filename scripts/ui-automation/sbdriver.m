#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

#include <stdio.h>
#include <dlfcn.h>
#include <unistd.h>
#include <mach/mach.h>
#include <stdlib.h>


static NSString *TGDevicePasscode(void) {
	const char *env = getenv("TG_DEVICE_PASSCODE");
	return env ? [NSString stringWithUTF8String:env] : @"";
}

static FILE *L;
static void lg(const char *fmt, ...) { va_list ap; va_start(ap,fmt); if(L){vfprintf(L,fmt,ap);fputc('\n',L);fflush(L);} va_end(ap); }

// ---- GSEvent hardware touch injection ----
typedef void (*GSSendEventFn)(const void *record, mach_port_t port);
typedef uint64_t (*GSTimestampFn)(void);
typedef mach_port_t (*GSPortFn)(void);
static GSSendEventFn gGSSendEvent;
static GSTimestampFn gGSTimestamp;
static GSPortFn gGSPort;

static void loadGS(void) {
	if (gGSSendEvent) return;
	void *gs = dlopen("/System/Library/PrivateFrameworks/GraphicsServices.framework/GraphicsServices", RTLD_LAZY);
	lg("GraphicsServices=%p", gs);
	gGSSendEvent = (GSSendEventFn)dlsym(gs, "GSSendEvent");
	gGSTimestamp = (GSTimestampFn)dlsym(gs, "GSCurrentEventTimestamp");
	gGSPort      = (GSPortFn)dlsym(gs, "GSGetPurpleApplicationPort");
	if (!gGSPort) gGSPort = (GSPortFn)dlsym(gs, "GSGetPurpleSystemEventPort");
	lg("GSSendEvent=%p GSCurrentEventTimestamp=%p GSPort=%p port=%u",
		gGSSendEvent, gGSTimestamp, gGSPort, gGSPort?gGSPort():0);
}

#define REC_SZ 52
#define HAND_OFF 52
#define PATH_OFF 88
#define BUF_SZ 112

static inline void wI(uint8_t *b, int off, int v){ *(int*)(b+off)=v; }
static inline void wF(uint8_t *b, int off, float v){ *(float*)(b+off)=v; }

// handType: 0=down, 5=up ; proximity: 3=touching, 0=not
static void sendGSTouch(CGPoint p, int handType, int proximity) {
	loadGS();
	if (!gGSSendEvent || !gGSPort) { lg("GS fns missing"); return; }
	uint8_t buf[BUF_SZ]; memset(buf, 0, sizeof(buf));
	// record
	wI(buf, 0, 3001);              // type = kGSEventHand
	wI(buf, 4, 0);                 // subtype
	wF(buf, 8, p.x); wF(buf, 12, p.y);       // location
	wF(buf, 16, p.x); wF(buf, 20, p.y);      // windowLocation
	wI(buf, 24, 0);               // windowContextId
	*(uint64_t*)(buf+28) = gGSTimestamp ? gGSTimestamp() : 0; // timestamp @28
	*(void**)(buf+36) = NULL;     // window
	wI(buf, 40, 0);               // flags
	wI(buf, 44, getpid());        // senderPID
	wI(buf, 48, 60);              // infoSize = hand(36)+path(24)
	// hand @52
	wI(buf, HAND_OFF+0, handType);
	// deltas/floats zero; width/height zero
	buf[HAND_OFF+33] = 1;         // pathInfosCount @ hand+33 (0x5D)
	// path @88
	buf[PATH_OFF+0] = 1;          // pathIndex
	buf[PATH_OFF+1] = 2;          // pathIdentity
	buf[PATH_OFF+2] = (uint8_t)proximity; // pathProximity
	wF(buf, PATH_OFF+4, proximity ? 1.0f : 0.0f); // pathPressure
	wF(buf, PATH_OFF+8, 0.0f);    // pathMajorRadius
	wF(buf, PATH_OFF+12, p.x); wF(buf, PATH_OFF+16, p.y); // pathLocation
	*(void**)(buf+PATH_OFF+20) = NULL; // pathWindow
	gGSSendEvent(buf, gGSPort());
	lg("GSSendEvent handType=%d prox=%d at (%.0f,%.0f)", handType, proximity, p.x, p.y);
}

static mach_port_t sysPort(void) {
	void *gs = dlopen("/System/Library/PrivateFrameworks/GraphicsServices.framework/GraphicsServices", RTLD_LAZY);
	GSPortFn f = (GSPortFn)dlsym(gs, "GSGetPurpleSystemEventPort");
	return f ? f() : 0;
}
// send a bare record (no info) of the given type to the system port
static void sendGSSimple(int type) {
	loadGS();
	uint8_t buf[BUF_SZ]; memset(buf, 0, sizeof(buf));
	wI(buf, 0, type);
	*(uint64_t*)(buf+28) = gGSTimestamp ? gGSTimestamp() : 0;
	wI(buf, 44, getpid());
	wI(buf, 48, 0); // infoSize 0
	mach_port_t sp = sysPort();
	if (gGSSendEvent) gGSSendEvent(buf, sp);
	lg("sendGSSimple type=%d sysport=%u", type, sp);
}

static void doGTap(CGPoint p) {
	sendGSTouch(p, 0, 3);  // down
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.06*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		sendGSTouch(p, 5, 0); // up
	});
}

// drag: down at a, N moved steps to b, up at b — each step scheduled so the runloop animates it
static void doGSwipe(CGPoint a, CGPoint b, double dur) {
	const int STEPS = 20;
	sendGSTouch(a, 0, 3); // down
	for (int i = 1; i <= STEPS; i++) {
		double frac = (double)i / STEPS;
		CGPoint p = CGPointMake(a.x + (b.x-a.x)*frac, a.y + (b.y-a.y)*frac);
		int last = (i == STEPS);
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((dur*frac)*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			sendGSTouch(p, 1, 3); // dragged
			if (last)
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					sendGSTouch(p, 5, 0); // up
				});
		});
	}
}

// hitTest across all windows, highest windowLevel first
static UIView *hitAt(CGPoint p) {
	NSArray *ws = [[UIApplication sharedApplication] windows];
	NSArray *sorted = [ws sortedArrayUsingComparator:^NSComparisonResult(UIWindow *a, UIWindow *b){
		if (a.windowLevel > b.windowLevel) return NSOrderedAscending;
		if (a.windowLevel < b.windowLevel) return NSOrderedDescending;
		return NSOrderedSame;
	}];
	for (UIWindow *w in sorted) {
		if (w.hidden || w.alpha < 0.01) continue;
		UIView *hit = [w hitTest:[w convertPoint:p fromWindow:nil] withEvent:nil];
		if (hit) return hit;
	}
	return nil;
}

static void setScalarIvar(id obj, const char *name, void *val, size_t sz) {
	Ivar iv = class_getInstanceVariable([obj class], name);
	if (!iv) { lg("  !ivar %s", name); return; }
	ptrdiff_t off = ivar_getOffset(iv);
	memcpy((char *)(void *)obj + off, val, sz);
}

static UITouch *synthTouch(UIWindow *win, UIView *view, CGPoint locWin, int phase) {
	UITouch *t = [[UITouch alloc] init];
	object_setInstanceVariable(t, "_window", (void *)win);
	object_setInstanceVariable(t, "_view", (void *)view);
	object_setInstanceVariable(t, "_gestureView", (void *)view);
	NSUInteger tap = 1; setScalarIvar(t, "_tapCount", &tap, sizeof(tap));
	double ts = [[NSProcessInfo processInfo] systemUptime]; setScalarIvar(t, "_timestamp", &ts, sizeof(ts));
	setScalarIvar(t, "_phase", &phase, sizeof(phase));
	setScalarIvar(t, "_locationInWindow", &locWin, sizeof(locWin));
	setScalarIvar(t, "_previousLocationInWindow", &locWin, sizeof(locWin));
	CGPoint z = locWin; setScalarIvar(t, "_preciseLocationInWindow", &z, sizeof(z));
	setScalarIvar(t, "_precisePreviousLocationInWindow", &z, sizeof(z));
	return t;
}

static void doTap(CGPoint p) {
	UIView *hit = hitAt(p);
	lg("tap (%.0f,%.0f) -> %s", p.x, p.y, hit ? class_getName([hit class]) : "(nil)");
	if (!hit) return;
	UIWindow *win = hit.window;
	CGPoint locWin = [win convertPoint:p fromWindow:nil];
	UIApplication *app = [UIApplication sharedApplication];

	UITouch *touch = synthTouch(win, hit, locWin, 0 /*UITouchPhaseBegan*/);
	UIEvent *ev = [app performSelector:@selector(_touchesEvent)];
	// try to register the touch with the event so allTouches works
	if ([ev respondsToSelector:sel_registerName("_addTouch:forDelayedDelivery:")])
		((void(*)(id,SEL,id,BOOL))objc_msgSend)(ev, sel_registerName("_addTouch:forDelayedDelivery:"), touch, NO);
	NSSet *set = [NSSet setWithObject:touch];

	[hit touchesBegan:set withEvent:ev];
	int endedPhase = 3; /*UITouchPhaseEnded*/
	setScalarIvar(touch, "_phase", &endedPhase, sizeof(endedPhase));
	[hit touchesEnded:set withEvent:ev];
	lg("  delivered began/ended to %s", class_getName([hit class]));
}

static void run(void) {
	NSString *cmd = [NSString stringWithContentsOfFile:@"/tmp/sbcmd" encoding:NSUTF8StringEncoding error:NULL];
	dispatch_async(dispatch_get_main_queue(), ^{
		L = fopen("/tmp/sbcmd.out","w");
		lg("cmd=[%s]", cmd ? [cmd UTF8String] : "(null)");
		NSArray *lines = [(cmd?:@"") componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
		for (NSString *raw in lines) {
			NSString *line = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			if (line.length == 0) continue;
			NSArray *t = [line componentsSeparatedByString:@" "];
			NSString *op = [t[0] lowercaseString];
			if ([op isEqualToString:@"tap"] && t.count >= 3) {
				doTap(CGPointMake([t[1] floatValue], [t[2] floatValue]));
			} else if ([op isEqualToString:@"gtap"] && t.count >= 3) {
				doGTap(CGPointMake([t[1] floatValue], [t[2] floatValue]));
			} else if ([op isEqualToString:@"sys"] && t.count >= 2) {
				int down = [t[1] intValue];
				sendGSSimple(down);
				if (t.count >= 3) {
					int up = [t[2] intValue];
					dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.12*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ sendGSSimple(up); });
				}
			} else if ([op isEqualToString:@"gswipe"] && t.count >= 5) {
				doGSwipe(CGPointMake([t[1] floatValue], [t[2] floatValue]),
				         CGPointMake([t[3] floatValue], [t[4] floatValue]),
				         t.count >= 6 ? [t[5] doubleValue] : 0.4);
			} else if ([op isEqualToString:@"passcode"] && t.count >= 2) {
				id ac = [objc_getClass("SBAwayController") performSelector:@selector(sharedAwayController)];
				SEL s1 = sel_registerName("attemptDeviceUnlockWithPassword:lockViewOwner:");
				if ([ac respondsToSelector:s1]) {
					BOOL r = ((BOOL(*)(id,SEL,id,id))objc_msgSend)(ac, s1, t[1], nil);
					lg("attemptDeviceUnlockWithPassword:lockViewOwner: ret=%d", r);
				} else lg("ac !resp attemptDeviceUnlockWithPassword:lockViewOwner:");
			} else if ([op isEqualToString:@"full"]) {
				id ac = [objc_getClass("SBAwayController") performSelector:@selector(sharedAwayController)];
				SEL isL = sel_registerName("isLocked");
				#define LK() ((BOOL(*)(id,SEL))objc_msgSend)(ac, isL)
				lg("start isLocked=%d", LK());
				id dlc = [objc_getClass("SBDeviceLockController") performSelector:@selector(sharedController)];
				BOOL kb = ((BOOL(*)(id,SEL,id,BOOL))objc_msgSend)(dlc, sel_registerName("attemptDeviceUnlockWithPassword:appRequested:"), TGDevicePasscode(), NO);
				lg("keybag=%d", kb);
				((void(*)(id,SEL,BOOL,int,BOOL,id,BOOL))objc_msgSend)(ac, sel_registerName("_attemptUnlockWithSound:unlockSource:isAutoUnlock:lockOwner:bypassPinLock:"), NO,0,NO,nil,YES);
				lg("after _attemptUnlock isLocked=%d", LK());
				((void(*)(id,SEL,BOOL,int,BOOL))objc_msgSend)(ac, sel_registerName("_finishUnlockWithSound:unlockSource:isAutoUnlock:"), NO,0,NO);
				((void(*)(id,SEL))objc_msgSend)(ac, sel_registerName("deactivate"));
				lg("after deactivate isLocked=%d", LK());
				// SBUIController: restore home screen
				Class UIC = objc_getClass("SBUIController");
				id uic = nil;
				for (const char *acc = "sharedInstance"; acc;) {
					if ([UIC respondsToSelector:sel_registerName(acc)]) { uic = ((id(*)(id,SEL))objc_msgSend)(UIC, sel_registerName(acc)); break; }
					break;
				}
				if (!uic && [UIC respondsToSelector:sel_registerName("sharedInstanceIfExists")])
					uic = ((id(*)(id,SEL))objc_msgSend)(UIC, sel_registerName("sharedInstanceIfExists"));
				lg("uic=%p", uic);
				if (uic) {
					SEL r = sel_registerName("restoreIconListAnimated:animateWallpaper:");
					if ([uic respondsToSelector:r]) { ((void(*)(id,SEL,BOOL,BOOL))objc_msgSend)(uic, r, YES, YES); lg("restoreIconList done"); }
					SEL fu = sel_registerName("finishedUnscattering");
					if ([uic respondsToSelector:fu]) { ((void(*)(id,SEL))objc_msgSend)(uic, fu); lg("finishedUnscattering done"); }
				}
				// tear down the away view window
				SEL avfo = sel_registerName("_awayViewFinishedAnimatingOut:");
				if ([ac respondsToSelector:avfo]) { ((void(*)(id,SEL,id))objc_msgSend)(ac, avfo, nil); lg("_awayViewFinishedAnimatingOut done"); }
				SEL dfao = sel_registerName("didFinishAnimatingOut");
				if ([ac respondsToSelector:dfao]) { ((void(*)(id,SEL))objc_msgSend)(ac, dfao); lg("didFinishAnimatingOut done"); }
				SEL rav = sel_registerName("_releaseAwayView");
				SEL avSel = sel_registerName("awayView");
				UIView *awayView = [ac respondsToSelector:avSel] ? ((UIView*(*)(id,SEL))objc_msgSend)(ac, avSel) : nil;
				UIWindow *awin = awayView.window;
				lg("awayView=%p window=%p", awayView, awin);
				if ([ac respondsToSelector:rav]) { ((void(*)(id,SEL))objc_msgSend)(ac, rav); lg("_releaseAwayView done"); }
				if (awin) { awin.hidden = YES; lg("away window hidden"); }
				// force the home root view visible
				for (UIWindow *w in [[UIApplication sharedApplication] windows]) {
					if ([w isKindOfClass:objc_getClass("SBAppWindow")] || w.windowLevel < 0) {
						for (UIView *sv in w.subviews) {
							if ([sv isKindOfClass:objc_getClass("SBUIRootView")]) {
								sv.hidden = NO; sv.alpha = 1.0;
								lg("SBUIRootView made visible");
							}
						}
					}
				}
				lg("final isLocked=%d", LK());
			} else if ([op isEqualToString:@"u2"]) {
				id ac = [objc_getClass("SBAwayController") performSelector:@selector(sharedAwayController)];
				SEL isL = sel_registerName("isLocked");
				id dlc = [objc_getClass("SBDeviceLockController") performSelector:@selector(sharedController)];
				BOOL kb = ((BOOL(*)(id,SEL,id,BOOL))objc_msgSend)(dlc, sel_registerName("attemptDeviceUnlockWithPassword:appRequested:"), TGDevicePasscode(), NO);
				lg("keybag=%d isLocked=%d", kb, ((BOOL(*)(id,SEL))objc_msgSend)(ac,isL));
				SEL sfs = sel_registerName("attemptUnlockFromSource:");
				if ([ac respondsToSelector:sfs]) {
					((void(*)(id,SEL,int))objc_msgSend)(ac, sfs, 1);
					lg("attemptUnlockFromSource:1 isLocked=%d", ((BOOL(*)(id,SEL))objc_msgSend)(ac,isL));
				} else lg("!resp attemptUnlockFromSource:");
			} else if ([op isEqualToString:@"finish"]) {
				id ac = [objc_getClass("SBAwayController") performSelector:@selector(sharedAwayController)];
				SEL isL = sel_registerName("isLocked");
				#define LOCKED() ((BOOL(*)(id,SEL))objc_msgSend)(ac, isL)
				lg("isLocked start=%d", LOCKED());
				// re-unlock keybag
				id dlc = [objc_getClass("SBDeviceLockController") performSelector:@selector(sharedController)];
				BOOL kb = ((BOOL(*)(id,SEL,id,BOOL))objc_msgSend)(dlc, sel_registerName("attemptDeviceUnlockWithPassword:appRequested:"), TGDevicePasscode(), NO);
				lg("keybag unlock=%d", kb);
				SEL sa = sel_registerName("_attemptUnlockWithSound:unlockSource:isAutoUnlock:lockOwner:bypassPinLock:");
				if ([ac respondsToSelector:sa]) {
					((void(*)(id,SEL,BOOL,int,BOOL,id,BOOL))objc_msgSend)(ac, sa, NO, 0, NO, nil, YES);
					lg("_attemptUnlockWithSound:...:lockOwner:bypassPinLock: done isLocked=%d", LOCKED());
				} else lg("!resp _attemptUnlockWithSound...");
				SEL s4 = sel_registerName("_unlockWithSound:unlockSource:isAutoUnlock:bypassPinLock:");
				if (LOCKED() && [ac respondsToSelector:s4]) {
					((void(*)(id,SEL,BOOL,int,BOOL,BOOL))objc_msgSend)(ac, s4, NO, 0, NO, YES);
					lg("_unlockWithSound:...:bypassPinLock: done isLocked=%d", LOCKED());
				}
				SEL s3 = sel_registerName("_finishUnlockWithSound:unlockSource:isAutoUnlock:");
				if ([ac respondsToSelector:s3]) {
					((void(*)(id,SEL,BOOL,int,BOOL))objc_msgSend)(ac, s3, NO, 0, NO);
					lg("_finishUnlockWithSound done isLocked=%d", LOCKED());
				}
				SEL sf = sel_registerName("frontLocked:animate:automatically:");
				if ([ac respondsToSelector:sf]) {
					((void(*)(id,SEL,BOOL,BOOL,BOOL))objc_msgSend)(ac, sf, NO, YES, NO);
					lg("frontLocked:NO done isLocked=%d", LOCKED());
				}
				SEL sd = sel_registerName("deactivate");
				if ([ac respondsToSelector:sd]) {
					((void(*)(id,SEL))objc_msgSend)(ac, sd);
					lg("deactivate done isLocked=%d", LOCKED());
				}
				// now isLocked should be 0: reveal home by completing the unlock
				SEL sfs = sel_registerName("attemptUnlockFromSource:");
				if ([ac respondsToSelector:sfs]) {
					((void(*)(id,SEL,int))objc_msgSend)(ac, sfs, 0);
					lg("attemptUnlockFromSource:0 isLocked=%d", LOCKED());
				}
				SEL au = sel_registerName("attemptUnlock");
				if ([ac respondsToSelector:au]) {
					((void(*)(id,SEL))objc_msgSend)(ac, au);
					lg("attemptUnlock isLocked=%d", LOCKED());
				}
				// report away view / window visibility
				SEL av = sel_registerName("awayView");
				if ([ac respondsToSelector:av]) {
					UIView *awayView = ((UIView*(*)(id,SEL))objc_msgSend)(ac, av);
					lg("awayView=%p hidden=%d window=%p windowHidden=%d", awayView,
						awayView.hidden, awayView.window, awayView.window.hidden);
				}
			} else if ([op isEqualToString:@"bypass"]) {
				id ac = [objc_getClass("SBAwayController") performSelector:@selector(sharedAwayController)];
				SEL s = sel_registerName("unlockWithSound:bypassPinLock:");
				if ([ac respondsToSelector:s]) {
					((void(*)(id,SEL,BOOL,BOOL))objc_msgSend)(ac, s, NO, YES);
					lg("unlockWithSound:bypassPinLock: called");
				} else lg("ac !resp unlockWithSound:bypassPinLock:");
			} else {
				lg("unknown cmd: %s", [line UTF8String]);
			}
		}
		lg("=== done ===");
		fclose(L); L = NULL;
	});
}

__attribute__((constructor))
static void init_(void){
	if(![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) return;
	run();
}

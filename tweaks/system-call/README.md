# Telegram System Call UI

An incoming Telegram call raised by SpringBoard itself, on the lock screen and
over whatever app is in front, with Answer and Decline wired back to `TGCall`.

Nothing in here goes into the app binary. The app side is three small pieces in
`src/Calls/` (`TGSystemCall.[hm]`, one notification posted from `TGCall.mm`, one line
in `AppDelegate.m`); everything else is this out-of-tree tweak.

## What iOS 6.1.3 actually has

The starting point was "there is no CallKit". The rest was read out of the stock
firmware for this exact device rather than guessed - the root filesystem of
`iPhone4,1_6.1.3_10B329` mounted read-only, `SpringBoard.app/SpringBoard` parsed
directly, and the private frameworks parsed out of `dyld_shared_cache_armv7`.
The full dump is in `evidence/ios6.1.3-10B329.txt`; the tools that produced it
are in `evidence/tools/`.

Three of the four routes named in the brief are closed on this build:

* **`SBCallAlert` does not exist on 10B329.** SpringBoard's entire call surface
  is `SBCallFailureAlert`, `SBCallFailureAlertItem`, `SBCallFailureAlertDisplay`,
  `SBCallPermissionAlertItem`, `SBAwayInCallController` and `SBTelephonyManager`.
  None of them is an incoming-call screen.

* **The real incoming-call screen lives in MobilePhone.app**, as
  `InCallController` over a `PhoneCall`, and `PhoneCall` is a thin wrapper around
  a `CTCallRef`. SpringBoard raises it by opening MobilePhone's private URL
  schemes - `telshow:`, `tellock:`, `telanswer:`, `telemergency:`. A `CTCallRef`
  is minted by CommCenter from something the baseband saw. There is no VoIP call
  type to inject into on iOS 6, so short of faking `CTCallCopyAll` and friends
  inside both SpringBoard and MobilePhone - and then also faking the audio route,
  the in-call status bar and every `CTCall*` the two of them touch - that screen
  cannot be raised for a call the modem never saw. That is a research project
  with SpringBoard and CommCenter as the blast radius, and it is not what this
  package does.

* **`TelephonyUtilities.framework` exists on 6.1.3 but is only logging** plus
  `TUReplyWithMessageStore`. There is no `TUCall`, no `TUCallCenter` - no
  CallKit ancestor to talk to.

What is left is the fourth route, and it is the one the system itself uses:
**`SBAlertItem`**, in `SpringBoardUI.framework`. SpringBoard's own call alert,
`SBCallFailureAlertItem`, is exactly an `SBAlertItem` that overrides
`-lockLabel`, `-performUnlockAction`, `-configure:requirePasscodeForActions:`
and `-alertView:clickedButtonAtIndex:`. On the lock screen an active alert item
takes over the slide bar - `-[SBAwayView _updateLockBarLabelByClearingFirst:]`
reads `-lockLabel`, and `-[SBAwayController _finishUnlockWithSound:unlockSource:isAutoUnlock:]`
calls `-performUnlockAction` once the slide completes. Over an app it is the
system modal alert. That is the standard answer/decline affordance on this OS,
and this package adds one class of exactly that shape.

The three visible strings come from the system's own bundles, so they are
localised for free: `SLIDE_TO_ANSWER` from `SpringBoard.app`'s `SpringBoard`
table (present in every lproj on this build), `ANSWER` and `DECLINE` from
`TelephonyUI.framework`'s `General` table.

## How the two halves talk

Four Darwin notifications and one plist. No mach ports, no
`CPDistributedMessagingCenter`, nothing that needs an entitlement.

```
app  --> com.kern0x1b.telegram.call.incoming   a call is ringing
app  --> com.kern0x1b.telegram.call.ended      it is not ringing any more
     <-- com.kern0x1b.telegram.call.answer     answered from the alert
     <-- com.kern0x1b.telegram.call.decline    declined from the alert
```

Darwin notifications carry no payload, so the caller's name travels in a plist
the app writes inside its own container, at `Library/Caches/systemcall.plist`.
The tweak finds the container the way SpringBoard already knows it -
`[[SBApplicationController sharedInstanceIfExists] applicationWithDisplayIdentifier:@"com.kern0x1b.telegram"] containerPath]`
- so the app never writes outside its sandbox and the tweak never guesses a
path. A payload older than 90 s is ignored; a missing payload just means the
alert says "Telegram".

Answering posts `.answer` (the app accepts immediately, so the audio path starts
without waiting for the UI) and then, if the device is not locked, brings the app
forward with `-[SpringBoard launchApplicationWithIdentifier:suspended:]`, falling
back to `applicationOpenURL:publicURLsOnly:` with `telegramdev://answer`. The call
screen is already up behind it: the app puts `TGCallViewController` on screen the
moment the call starts ringing.

Declining posts `.decline` and takes the alert down without touching whatever
was on screen. `TGCall -hangUp` sends `discardCall`, so the caller sees a normal
decline.

When the call ends from either side - the caller cancels, the call connects, it
fails, or the app hangs up - the app's state notification fires and it posts
`.ended`, which dismisses the alert. If nothing says the call is over within
75 s the tweak dismisses the alert anyway, so a wedged app cannot leave a dead
alert on the lock screen.

## Failing safe

* **It hooks nothing.** There is no `MSHookMessageEx`, no method swizzle, no
  `%hook`. The dylib adds one class and registers two notification handlers.
  The worst it can do to SpringBoard is nothing at all.
* Every selector it overrides is checked for existence *and* type encoding
  against `SBAlertItem` before `class_addMethod`. If
  `-configure:requirePasscodeForActions:` or `-alertView:clickedButtonAtIndex:`
  is missing or the wrong shape, the class pair is disposed and the tweak is
  inert. If one of the optional overrides (`lockLabel`, `undimsScreen`, …) is
  missing, that one is skipped and the rest still work.
* Every call into SpringBoard's classes is inside `@try`. The first exception
  sets a stop flag and the tweak never touches anything again.
* The filter plist restricts loading to `com.apple.springboard`, and the
  constructor bails immediately if the `SpringBoard` class is absent.
* `/var/lib/telegramsystemcall/disabled` switches it off without uninstalling.
* The dylib links Foundation and libobjc only - no UIKit, no substrate. `make
  check` enforces that.

## Building

```
cd tweaks/system-call
make            # out/TelegramSystemCall.dylib, armv7, min iOS 6.0
make check      # armv7 slice, no UIKit, no substrate
make deb        # out/com.kern0x1b.telegramsystemcall_<version>_iphoneos-arm.deb
```

`SDK=` overrides the SDK; it needs an armv7 slice in `libSystem.tbd`
(`build/sdks/iPhoneOS12.4.sdk` works, the 9.3 one in this repo is missing
`liblaunch.dylib` for armv7).

The app half is already in the normal build - `make FINALPACKAGE=1` at the repo root.
**Both halves are needed.** An app without the tweak posts notifications nobody
listens to and behaves exactly as before; a tweak without the app half never
hears an incoming call.

## Installing

```
scp out/com.kern0x1b.telegramsystemcall_*_iphoneos-arm.deb root@<ip>:/tmp/
ssh root@<ip> 'dpkg -i /tmp/com.kern0x1b.telegramsystemcall_*.deb'
```

`postinst` resprings after 4 s. Set `TELEGRAMSYSTEMCALL_NO_RESPRING=1` to
respring by hand instead.

## Removing it from SSH

In order of how much you want to keep:

**Switch it off, keep it installed** - survives a reboot, no reinstall needed:

```
ssh root@<ip> 'mkdir -p /var/lib/telegramsystemcall && \
    touch /var/lib/telegramsystemcall/disabled && killall -9 SpringBoard'
```

Undo with `rm /var/lib/telegramsystemcall/disabled && killall -9 SpringBoard`.

**Unload it now** - fastest, does not need dpkg to be healthy:

```
ssh root@<ip> 'rm -f /Library/MobileSubstrate/DynamicLibraries/TelegramSystemCall.dylib \
                     /Library/MobileSubstrate/DynamicLibraries/TelegramSystemCall.plist && \
               killall -9 SpringBoard'
```

**Uninstall properly:**

```
ssh root@<ip> 'dpkg -r com.kern0x1b.telegramsystemcall'
```

**If SpringBoard is in a boot loop and you cannot get a shell**, hold volume-up
from boot - MobileSubstrate's safe mode does not load any tweak - then use the
`dpkg -r` above. If even that fails, SSH still comes up before SpringBoard does;
the `rm` above is the recovery.

## On-device test plan

Nothing below has been run yet - the device was off limits while this was
written. Do these in order; each one is a separate failure the design has a
distinct answer for.

Two shells help: `ssh root@<ip>` for the device log, and the app's own log at
`/var/mobile/Applications/<uuid>/Library/Caches/log.txt`
(`scripts/deploy-and-watch.sh` already pulls it).

**0. It loaded, and it loaded nowhere else.**
```
ssh root@<ip> 'grep -i TelegramSystemCall /var/log/syslog | tail'
```
Expect one line: `TelegramSystemCall: installed in SpringBoard`. If you see
"is not the shape this build expects" instead, the OS is not what
`evidence/ios6.1.3-10B329.txt` says and the tweak has correctly done nothing.
Nothing should appear from any other process.

**1. Unlocked, on the home screen.** Call the 4S from another Telegram account.
Expect: screen undims, the system modal alert appears with the caller's name as
the title, "Telegram Audio" under it, and **Decline / Answer** with Answer as
the default button. Check the button titles are the system's, not English
fallbacks, by switching the phone to another language and repeating.

**2. Answer from that alert.** Expect: alert goes, the app comes forward already
showing `TGCallViewController`, audio connects, the call timer runs. This is the
one to watch for a race - the tweak posts `.answer` before it foregrounds the
app, so `acceptCall` should already be in flight in the app log before the
window changes.

**3. Decline from that alert.** Expect: alert goes, you stay exactly where you
were, the caller sees a decline (not a missed call), `TGCall -hangUp` in the app
log, no audio session left active.

**4. Locked, screen off.** Lock the phone, call it. Expect: the screen wakes
(`undimsScreen`), the alert is on the lock screen, and the slide bar reads
**slide to answer**, not "slide to unlock". Slide it. With no passcode set,
expect the device to unlock, the app to come forward and the call to connect.

**5. Locked with a passcode.** Same, but expect the passcode keypad after the
slide, and the app to come forward only after the passcode is entered. Answering
by *tapping* Answer while locked should still connect the audio without putting
the app in front of the lock screen - that branch is the `TSCDeviceIsLocked()`
check, and this is the test that proves it.

**6. Caller hangs up while it is ringing.** Expect the alert to disappear on its
own, from `.ended`, within a second. Do this both locked and unlocked.

**7. Over a full-screen app.** Start a call while the app under test is in the
foreground (Safari, Music, the Telegram app itself). Expect the alert over it in
all three cases, and no double UI when the Telegram app is already frontmost.

**8. Screen off, app in the background for a long time.** Leave the phone for
20+ minutes with the screen off, then call it. This is the one most likely to
fail, and it fails in the *app*, not the tweak: if the `voip` background mode has
not kept the app alive, TDLib never sees the call and nothing is posted. Check
the app log for the `updateCall` before blaming the tweak.

**9. Two calls in a row.** Answer one, end it, then have the caller ring again.
The old `onStateChanged` router only ever fired once per session; the router now
listens on `TGCallStateDidChangeNotification` instead, so the second call must
raise the alert *and* put the call screen up. This is a regression test for that
specific bug.

**10. Outgoing calls must be untouched.** Place a call from the 4S. No alert
should appear at any point.

**11. The watchdog.** Kill the app while a call is ringing
(`killall -9 Telegram`). The alert should still be there, and should take
itself down 75 s after it appeared. Nothing should be stuck on the lock screen
afterwards.

**12. Respring while ringing.** `killall -9 SpringBoard` mid-ring. Expect
SpringBoard to come back clean with no alert; the app is still in the call state
it was in, and hanging up from the app screen must still work.

**13. Remove it.** Run the disable-file recipe above, respring, and repeat test
1: the call must still arrive and `TGCallViewController` must still come up on
its own. The app must not depend on the tweak for anything.

## What was deliberately not built

* Injecting a synthetic `CTCallRef` into SpringBoard and MobilePhone to raise
  the genuine full-screen phone UI. It is the only way to get the actual
  answer-slider-over-wallpaper screen, and the evidence for how it would work is
  in `evidence/` - but it means intercepting CoreTelephony inside two system
  processes, and the failure mode is a SpringBoard that thinks it is in a call.
* A full-screen `SBAlert` built from TelephonyUI parts. `SBCallFailureAlertDisplay`
  shows the recipe - `TPBottomDoubleButtonBar -initForIncomingCallWithFrame:`
  gives the real Decline/Answer pair and `TPBottomLockBar -initForIncomingCallWithFrame:`
  gives the real slide-to-answer bar, both already localised - and
  `SBUISlidingFullscreenAlertController` in SpringBoardUI is a plain
  `UIViewController` subclass with `newTopBar` / `newBottomBar` overrides that
  would host them. That is the upgrade path if the alert item turns out to look
  too small for a call. It is strictly more code and strictly more ways to break
  the lock screen, so it is not what shipped first.

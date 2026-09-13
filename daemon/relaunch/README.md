# Background message delivery on iOS 6.1.3

How a message arrives as a notification when Telegram is not on screen, and
what the jailbreak part of that is.

There is no APNs anywhere in here. Apple's push servers will only sign a push
for a topic somebody holds a certificate for, and nobody holds one for
`com.kern0x1b.telegram`. Registering an APNs token with Telegram through TDLib's
`registerDevice` returns a `PushReceiverId` and then silence forever, which is
exactly what happens in the 2013 Telegram source itself — its APNs path
defaults to off (`Telegraph/TGAppDelegate.mm:99-104`) and its own
`PUBLIC_BUILD_NOTES.md:11,17` says the credentials are stripped. The app is
never woken by a push. **The app is simply never dead.**

Two layers do that:

| layer | where | what it buys |
| --- | --- | --- |
| iOS 6 `voip` socket + keep-alive | inside the app (`src/Storage/TGBackgroundSession.m`, `third_party/tdlib/td` patch) | app stays alive and connected while backgrounded, screen locked, indefinitely; the system relaunches it after a reboot |
| `telegramd` watchdog | this directory, a LaunchDaemon | closes the hole the first layer cannot: force-quit from the app switcher, and a jetsam kill |

---

## Layer 1 — inside the app (no jailbreak needed)

Four pieces, copied from twelve because that implementation is proven on this
hardware and this OS version.

**1. `voip` in `UIBackgroundModes`.** `src/Resources/Info.plist`. Without it
`setKeepAliveTimeout:handler:` returns `NO` and the VoIP socket marking is
ignored.

**2. The primary MTProto socket is marked as a VoIP stream.** This is the piece
that keeps the TCP connection open while the process is suspended;
`SO_KEEPALIVE` alone does not do it — it only keeps the NAT mapping warm.

TDLib uses raw BSD sockets (`third_party/tdlib/td/tdutils/td/utils/port/SocketFd.cpp`,
`init_socket_options` sets `SO_REUSEADDR`/`SO_KEEPALIVE`/`TCP_NODELAY`/
`SO_NOSIGPIPE` and nothing else), so nothing in it ever touches CFNetwork. The
fix is the GCDAsyncSocket recipe (`enableBackgroundingOnSocket`,
`twelve/submodules/MtProtoKit/thirdparty/AsyncSocket/GCDAsyncSocket.m:7206-7235`):
build a shadow `CFStreamCreatePairWithSocket` over the already-connected fd with
`kCFStreamPropertyShouldCloseNativeSocket = false`, set
`kCFStreamNetworkServiceType = kCFStreamNetworkServiceTypeVoIP` on both halves,
open them, and never read or write through them. The streams exist purely to
register the fd with CFNetwork as a VoIP stream; TDLib keeps doing its own
`read()`/`write()` on the same fd.

Getting the fd needs a hook in TDLib, so `third_party/tdlib/td` carries a patch:

- `td/telegram/net/Session.cpp` exports
  `td_ios_set_primary_socket_callback(void (*)(int fd))` and invokes the
  installed callback from `Session::connection_open_finish` for
  `is_main_ && is_primary_ && connection_id_ == 0` only.
- `tdclientjson_export_list` lists the new symbol, otherwise
  `-Wl,-exported_symbols_list` hides it and `dlsym` on the app side returns NULL.

The gate on "primary" matters. twelve marks only the long-lived data/update
connection and says why at `MTTcpConnection.m:1076-1078`: VoIP-marking the
short-lived download workers made file and avatar traffic disturb scrolling.

The app installs the callback in `TGClient start`, before
`td_json_client_create`, and marks the fd in `TGVoipMarkPrimarySocket`
(`src/Storage/TGBackgroundSession.m`) together with `SO_KEEPALIVE` and
`TCP_KEEPALIVE = 60`.

**3. `setKeepAliveTimeout:600 handler:`** is installed on background entry and
again on a cold background launch. The handler does a health check at most once
per 30 minutes, 60 minutes between 23:00 and 07:00 — the same schedule as
`TGAppDelegate.mm:1894-1899`. The check is skipped outright when the connection
is ready and data arrived within that window. When it does run it takes a short
`beginBackgroundTaskWithExpirationHandler:` lease first, because the work is
asynchronous and iOS will otherwise suspend the process between the probe and
its answer (`TGAppDelegate.mm:2315-2342` documents exactly this). The probe is
TDLib's `pingProxy` with a null proxy, which is a real server round trip; on
failure or an 8-second timeout the connection is forced down and back up with
`setNetworkType`.

**4. Cold background launch.** After a reboot, and after the watchdog relaunches
the app, the process starts in `UIApplicationStateBackground`. UIKit does not
persist a keep-alive handler across process death, so
`TGBackgroundSession applicationDidFinishLaunching:` takes a background-task
lease and installs a provisional keep-alive **before** the asynchronous TDLib
bootstrap begins; without that iOS can suspend the process before MTProto even
exists. This mirrors `TGAppDelegate.mm:891-937`. The lease is released when
TDLib reports `connectionStateReady`, or after 120 seconds, whichever is first.

The notification itself was already local: `TGNotificationManager` builds
`UILocalNotification`s from `updateNotificationGroup` /
`updateActiveNotifications` and already does burst folding, sound throttling and
a bounded dedup set.

Turn the whole in-app layer off without rebuilding:

```
defaults write /var/mobile/Library/Preferences/com.kern0x1b.telegram.plist backgroundDeliveryEnabled -bool NO
```

Check what it did, on the device, with the app running:

```
uiopen telegramdev://bgstatus
# syslog: BGSESSION status hook=1 voip=1 fd=23 keepAlive=1 coldLaunch=0 rxAge=12s
#         BGSESSION probe seconds after 214 ms
```

It also fires one `pingProxy` so the health-probe path is exercised end to end;
`probe error` or `probe (nothing)` means the probe would never confirm anything
in the background either.

The interesting syslog lines are all prefixed `BGSESSION`.

---

## Layer 2 — `telegramd`, the watchdog (this directory)

Layer 1 cannot survive the user swiping the app out of the switcher, and it
cannot survive jetsam killing it under memory pressure. Nothing inside an app
can: the process is gone and iOS will not start it again on its own.

The obvious jailbreak answer — a root daemon that holds its own TDLib connection
— is the wrong trade. Two TDLib instances cannot share one database directory,
so it means either rearchitecting the app into a thin client over local IPC, or
running a second authorized session for the account (visible in Active Sessions,
double the update traffic, duplicate banners to coordinate away). A root daemon
also cannot post a `UILocalNotification` and would have to poke SpringBoard.

`telegramd` does something much smaller: **it watches whether the app process
exists, and relaunches it into the background when it does not.** All the actual
Telegram work stays in the one place that already does it.

### What it is

`/usr/libexec/telegramd`, ~50 KB, C, no MobileSubstrate, no hooks, no patched
system files. It loops on a timer (30 s):

1. If `/var/mobile/Library/Preferences/com.kern0x1b.telegram.nolaunch` exists, do
   nothing. That file is the kill switch; the daemon keeps running and keeps
   logging, it just stops relaunching.
2. Scan the process table with `sysctl(CTL_KERN, KERN_PROC, KERN_PROC_ALL)` and
   look for `p_comm == "Telegram"`.
3. If it is running, do nothing.
4. If it is not, and the cooldown (180 s) has passed, call
   `SBSLaunchApplicationWithIdentifierAndLaunchOptions("com.kern0x1b.telegram", NULL,
   suspended: true)` from `SpringBoardServices.framework`, resolved with
   `dlsym` so a missing or renamed symbol degrades to a log line instead of a
   crash. `SBSLaunchApplicationWithIdentifier` is the fallback.

`suspended: true` is the whole point — the app is launched into the background,
not onto the screen. It lands in the cold-background-launch path of layer 1,
takes its lease, connects TDLib, marks the VoIP socket, and goes back to sleep.

Nothing is hooked and nothing is injected. The daemon talks to SpringBoard over
the normal `com.apple.springboard.services` Mach port, the same way `sbopenapp`
and similar CLI tools do.

### Files it installs

```
/usr/libexec/telegramd
/etc/telegramd.conf
/Library/LaunchDaemons/com.kern0x1b.telegramd.plist
```

and writes `/var/log/telegramd.log` (rotated at 256 KB to `.log.1`), plus
`/var/log/telegramd.out` and `.err` from launchd.

### Build

```
cd daemon/relaunch
./build.sh
```

armv7, `-miphoneos-version-min=6.0`, against `build/sdks/iPhoneOS12.4.sdk`,
signed with `ldid -S entitlements.plist`. Output lands in `out/`.

The entitlements (`platform-application`,
`com.apple.springboard.launchapplications`) are not enforced on iOS 6 and are
there so the same binary keeps working if it is ever moved to a newer jailbreak.

### Install

```
./install.sh [ssh-host]        # defaults to the `itgphone` alias
```

It copies the three files, fixes ownership and modes, then
`launchctl unload` + `launchctl load`. Watch it work:

```
ssh itgphone tail -f /var/log/telegramd.log
```

### Remove

```
./uninstall.sh [ssh-host]
```

`launchctl unload`, then delete the binary, the config, the plist and the four
log files. Nothing else on the device was ever modified, so that is a complete
removal. To disable it without removing it:

```
ssh itgphone touch /var/mobile/Library/Preferences/com.kern0x1b.telegram.nolaunch
```

### Configuration

`/etc/telegramd.conf`, read once at daemon start (`launchctl unload`/`load` to
re-read):

```
bundle_id=com.kern0x1b.telegram
executable=Telegram       # matched against p_comm, max 16 chars
interval=30                # seconds between checks, floor 5
cooldown=180               # seconds between relaunch attempts, floor = interval
settle=45                  # seconds after daemon start before the first relaunch
dry_run=0                  # 1 logs what it would launch and launches nothing
```

`settle` exists for boot: at `RunAtLoad` the daemon comes up long before
SpringBoard is ready to launch anything, and hammering it there just fills the
log.

---

## What actually survives

Honest version, and none of it has been on hardware yet.

| situation | layer 1 alone | layer 1 + watchdog |
| --- | --- | --- |
| app backgrounded, screen locked, hours | yes | yes |
| device rebooted, app never opened | yes — the system relaunches a `voip` app into the background after boot | yes |
| app force-quit from the app switcher | **no** | yes, within `interval` + `cooldown` (30–210 s) |
| app killed by jetsam under memory pressure | **no** | yes, same window |
| Airplane mode / no network | no, and nothing can | no |
| user turns notifications off for the app in Settings | no banner, by design | no banner, by design |
| kill switch file present | n/a | back to layer 1 alone |

Two caveats worth stating plainly:

- A relaunched app is a **cold** launch. It has to reconnect MTProto and pull
  updates before it can raise a banner, so the first notification after a
  force-quit arrives late — seconds to a minute, not instantly.
- The watchdog defeats "I quit this app on purpose". That is the point of it,
  but it is also the reason the kill switch file exists and the reason the whole
  thing is a separate, removable component rather than something the app does to
  itself.

## On-device tests still to run

Nothing below has been verified; the phone was busy with timed measurements.

1. Foreground the app, watch syslog for `BGSESSION socket fd=… voip=1`. `voip=0`
   means the CFStream marking was refused and layer 1 is not working at all.
2. Background it, lock, wait 30 minutes, send a message from another account.
   Expect a banner, and `BGSESSION wake` in syslog.
3. Reboot, do not open the app, unlock, send a message. This is the test that
   separates "still backgrounded" from "actually relaunched by the system".
4. Force-quit from the switcher, send a message. Expect nothing before the
   watchdog is installed, and a late banner after.
5. Overnight soak. The health interval changes to 60 minutes between 23:00 and
   07:00, so a night run exercises a different path than a daytime one.
6. Battery. The 4S is the whole reason for the 30/60-minute health schedule;
   measure idle drain overnight with and without the daemon loaded.

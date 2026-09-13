---
name: device-deploy
description: Use when building for the iPhone 4S or iPad 2, copying a binary to either device over SSH, resigning it, stopping/starting the app, taking a device screenshot, or driving the telegramdev:// debug harness. Covers the inode/signature trap, the SIGTERM-before-SIGKILL rule, and what must never be done to a device.
---

# Device deploy

Two real jailbroken devices: iPhone 4S (iOS 6.1.3, armv7) and iPad 2. Bundle id
`com.kern0x1b.telegram`, executable `Telegram`, URL scheme `telegramdev://`.

## Never do these to a device

- **Never respring.** No `killall SpringBoard`, no `uicache` with `-r`, no `killall backboardd` —
  a backboardd kill is a respring in all but name. A respring locks the screen and forces the user
  to type their passcode by hand; this has already happened once from an agent running
  `killall backboardd`.
- **Never `killall -9 Telegram`.** TDLib flushes its binlog on the way out. A hard kill mid-write
  can corrupt the binlog; TDLib then starts a clean session, which on-device means the user is
  logged out and has to re-authenticate. This happened once, on the iPad, during an ordinary
  deploy loop. Always:
  ```
  killall Telegram   # SIGTERM
  sleep 3
  killall -9 Telegram   # only if it is still alive after the sleep
  ```
- **Never overwrite the binary in place.** The kernel caches a Mach-O's code signature and
  entitlements against the file's *vnode*. `scp` over the same path keeps the same inode, so the
  device goes on enforcing the OLD signature — measured on the iPad: same bytes, same path,
  opposite entitlement behavior depending only on whether the inode changed. Always `rm` first so
  the copy lands on a fresh inode:
  ```
  rm -f /Applications/Telegram.app/Telegram
  # scp the new binary into place
  ldid -S/tmp/entitlements.plist /Applications/Telegram.app/Telegram
  ```
- **Never delete the whole `.app` bundle.** Deleting `Telegram.app` unregisters it with
  SpringBoard; the debug URL scheme then launches nothing until the shell restarts, which locks
  the device and forces a passcode re-entry. Replace the binary only. Delete the whole bundle
  only when resources (not just code) actually changed, and say so up front since it costs a
  respring-equivalent lock.
- **Never leave a branch build on a device when you finish.** The user judges the state of the
  project by what's on the devices. After testing your own build, rebuild the integration branch
  and deploy that, or say explicitly in your report which branch is left on which device.
- **End of session: lock the devices.** Stop the app (SIGTERM, as above), and leave both devices
  locked — do not leave one sitting unlocked on a screen.

## SSH access

DHCP-assigned IP, changes between sessions. Find it by scanning the local subnet for an open port
22 (`arp -a`, then `nc -z -w1 <ip> 22` per candidate) rather than asking the user, unless the scan
is genuinely ambiguous between two devices. Device addresses and the root password are not in this repository; read them from `../iTgLegacy-notes/environment.md` and export `TG_DEVICE` and `TG_DEVICE_PASSWORD` before running anything below.

The device's OpenSSH predates modern clients' default algorithm set — a bare `ssh` fails with
"no matching host key type found. Their offer: ssh-rsa,ssh-dss" unless legacy algorithms are
re-enabled explicitly, one `-o` per algorithm family (a single comma-joined `+=` value fails with
"Bad key types"):

```
sshpass -p "$TG_DEVICE_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
  -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa \
  -o KexAlgorithms=+diffie-hellman-group1-sha1,diffie-hellman-group14-sha1 \
  -o Ciphers=+aes128-cbc,3des-cbc \
  root@<device-ip> "command"
```

Write this command inline every time rather than caching it in a shell variable — zsh does not
word-split an unquoted `$VAR`, so a cached SSH command string reused via `$SSH "cmd"` breaks with
"file name too long". See the `shell-macos` skill.

The device busybox shell is missing most normal Unix tools: no `wc`, `head`, `ps`, `md5`,
`syslog`, `strings`. Only `ls`, `cat`, `find`, `grep`, `rm`, `date` are confirmed present. Don't
pipe through the missing ones — use `ls -t` and read output directly instead of `| head`, do
`md5`/`wc`-equivalent work locally after `scp`ing the file back.

## Deploy procedure

1. `make FINALPACKAGE=1 stage` (or the iPad equivalent target) builds straight to
   `.theos/_/Applications/Telegram.app/Telegram` — no need for full `.ipa` packaging during iteration.
   See the `build-and-verify` skill for reading the build log correctly.
2. `ldid -S/tmp/entitlements.plist .theos/_/Applications/Telegram.app/Telegram` — ad-hoc resign; the
   device is jailbroken so no real provisioning is needed. `ldid` rewrites the binary in place, so
   a size mismatch against the local pre-sign copy proves nothing about whether resigning worked.
   If `ldid` aborts on an assert, `/tmp/entitlements.plist` is missing on the Mac side — copy
   `src/Resources/entitlements.plist` there first.
3. `rm` the installed binary, then `scp` the new one over (see the inode rule above), then `ldid`
   the copy that is now on the device if resigning after transfer rather than before.
4. Stop and relaunch: `killall Telegram; sleep 3; killall -9 Telegram` (only if still alive), then
   relaunch via `uiopen telegramdev://` over SSH, or by tapping the icon.

`scripts/deploy-and-watch.sh` in the repo automates a USB/`idevice*`-tool version of build+install+launch+
syslog-collection for a directly-cabled Mac; it is a different transport (usbmuxd, not WiFi SSH)
and assumes `idevice_id`/`ideviceinstaller`/`idevicedebug` are present. Use the manual SSH
procedure above when only WiFi access is set up, which is the common case on this project.

## The telegramdev:// debug harness

Implemented in `src/App/AppDelegate.m`. All commands take effect on the topmost view controller of
the currently selected tab, or inside the topmost presented modal if one is up.

| URL | Effect |
|---|---|
| `telegramdev://touch/X/Y` | Synthesizes a tap via `hitTest:` + `sendActionsForControlEvents:`. Only reaches actual `UIControl` subclasses — buttons, bar items, switches. Silently no-ops on a plain `UITableViewCell` row (not a `UIControl`). |
| `telegramdev://tap/N` or `tap/S/R` | The correct way to select a table row; drives `didSelectRowAtIndexPath:` directly. Bare `tap/N` means row N of section 0. |
| `telegramdev://tab/N` | Switches the tab bar to index N and pops that tab's nav stack to root first. |
| `telegramdev://hold/X/Y/MS` | Like `touch/` but holds for MS milliseconds (press-and-hold controls, e.g. the mic button). |
| `telegramdev://type/TEXT` | Types into whichever text field/view is first responder. |
| `telegramdev://scroll/N` | Sets a scroll view's content offset directly to pixel `N`, clamped to `[-contentInset.top, contentSize.height - bounds.height + contentInset.bottom]`. **This is a raw pixel offset, not a row index**, and the reachable range shifts as more history loads — do not treat two `scroll/N` calls minutes apart as scrolling to the "same" place. |
| `telegramdev://screenshot` | Writes to the app's own cache dir, in-process — window-only, will not include the status bar. |

Coordinates for `touch`/`hold` are in **points**, not raw screenshot pixels — the iPhone 4S
screenshot is 640×960 (retina 2x), so divide screenshot pixel coordinates by 2 before passing them
to `touch/X/Y`.

Always `sleep 1`–`sleep 2` between a tap/scroll and the next screenshot — transitions and
keyboard show/hide are animated, and a screenshot taken mid-transition reads as "nothing
happened" when something did.

## Full-screen screenshots

The in-process `telegramdev://screenshot` handler is window-only. For a screenshot that includes
the status bar, use the standalone `UIGetScreenImage()`-based binary at `/tmp/screenshot` on the
device (pushed once from `scripts/device-grab-screenshot.m`; survives until an actual reboot since it's just a
file under `/tmp`) — `/tmp/screenshot /tmp/out.png` over SSH, then `scp` the PNG back. See the
`look-verify` skill for how to inspect the result honestly, and always zoom with nearest-neighbor,
never a smoothed resize.

## Debugging on-device

- Crash logs: `/var/mobile/Library/Logs/CrashReporter/<ProcessName>_<timestamp>_<device>.plist` —
  `cat` the file directly; the human-readable Apple crash text is inside the `description` string
  key, no plist parsing needed. `ls -t` the directory for the newest one.
- Symbolicate against the **exact binary that was deployed at crash time**:
  `atos -arch armv7 -o .theos/_/Applications/Telegram.app/Telegram -l <loadBase> <addr1> <addr2> ...`.
  `loadBase` and each frame's absolute address are printed directly in the crash log's backtrace
  lines. A rebuild since the crash — even a no-op recompile — changes code layout and silently
  produces wrong-but-plausible symbol names; confirm the crash log postdates the last deploy, or
  reproduce fresh against the currently-deployed binary.
- No `syslog`/ASL access (`/var/log/asl/` is empty on this setup) — `NSLog` output is
  unrecoverable. For live inspection, write debug lines to a plain file (e.g. `/tmp/debug.log` via
  `NSFileHandle`) inside the suspect method, rebuild, redeploy, trigger the path, `cat` the file
  over SSH, then remove the debug write — it is scaffolding, never a permanent log.
- If a fix seems to have no effect, `touch <file>.m` and confirm the build log actually recompiled
  it (`make` can otherwise reuse a stale object file) before concluding the fix is wrong.

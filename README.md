# Classicgram

[![Platform](https://img.shields.io/badge/platform-iOS%206%20%C2%B7%20armv7-lightgrey)](#supported-targets)
[![Licence](https://img.shields.io/badge/licence-GPLv3-blue)](LICENSE)
[![Language](https://img.shields.io/badge/written%20in-Objective--C-438eff)](#repository-layout)

An unofficial Telegram client for the hardware Telegram itself stopped supporting years ago:
32-bit armv7 iPhones and iPads on iOS 6, the last release those devices ever received. It talks to
Telegram's servers through [TDLib](https://github.com/tdlib/td), the same client library the
official apps use, and wears the visual language Telegram for iOS had in 2013 — bubble geometry,
toolbar art and interaction lifted from the genuine pre-redesign client, not a modern skin painted
over old chrome. The project exists because that hardware still turns on, and because nothing else
currently lets it speak to Telegram as more than a read-only relic: a real login, a real chat list,
real media, running natively on a dual-core A5 with 512 MB of RAM.

The client is written from the interface up for this hardware: every list is a `UITableView`, every
layout is a computed rectangle, and the only SDK in play is iOS 6's. It descends from earlier work by
Igor V. Sementsov ([@igkuzm](https://github.com/igkuzm)) and carries 2013 interface code and artwork
from [Twelve](https://github.com/theanazerka/twelve-project); both are credited in full under
[Credits](#credits) and [`NOTICE`](NOTICE), as the licence requires. It is not affiliated with,
endorsed by, or in any way connected to Telegram FZ-LLC or Telegram Messenger Inc.

## Contents

- [Supported targets](#supported-targets)
- [Feature table](#feature-table)
- [Building](#building)
- [Installing on a device](#installing-on-a-device)
- [Repository layout](#repository-layout)
- [Where the reasoning lives](#where-the-reasoning-lives)
- [Licence](#licence)
- [Credits](#credits)

## Supported targets

| | |
|---|---|
| **Primary target** | armv7 (32-bit), iOS 6.0 and later — `make` |
| **Second target** | arm64, iOS 7 through 12.5.7 — built into the same fat binary (`ARCHS = armv7 arm64`) |
| **Toolchain ceiling** | iOS 6 SDK only — nothing from a later SDK is available at compile time |

The armv7 slice is the one the project is written for and the one that gets exercised on real
hardware; the iPhone 4S and iPad 2 are the usual test devices simply because they are the last
models Telegram itself supported, but nothing in the code is specific to them. Any armv7 device
that runs iOS 6 is a target, and the layout derives every width from the view rather than assuming
a screen size.

The arm64 slice is built into the same fat binary as armv7 and links, but it has not been exercised
on 64-bit hardware — treat it as a build target you are welcome to test, not as a verified one.

A jailbreak is required to install either slice; see [Installing on a device](#installing-on-a-device).
The build self-signs with `ldid`, so no paid developer account and no App Store distribution is
involved anywhere in the chain.

Targeting the iOS 6 SDK caps what the app can ever do on this hardware, regardless of what TDLib
itself is capable of:

- No `UICollectionView`, Auto Layout, `UIAlertController`, `WKWebView`, `UNUserNotificationCenter`,
  CallKit, PushKit, or Local Authentication — none of them exist on this SDK. Every list is a
  `UITableView`, every layout is a hand-computed `CGRect`, every alert is a `UIAlertView` or
  `UIActionSheet`.
- No Touch ID/Face ID — the 4S has no sensor, and the API doesn't exist on this SDK regardless.
- No push notifications. Telegram's APNs push is minted for Telegram's own bundle identifier, so a
  sideloaded build can never be handed a token their servers will push to — see the feature table.
  Notifications work, but only while the process is alive.
- iOS 6's system font stops at Unicode 6.0. Emoji added since then are drawn from a bitmap atlas
  bundled with the app and composited through CoreText. Two optional jailbreak packages, kept in
  their own repository at [kern0x1b/ios6-emoji](https://github.com/kern0x1b/ios6-emoji), go further:
  one replaces the system emoji font so the whole device can draw modern emoji, the other patches
  them into the system keyboard's hard-coded category list.
- No VideoToolbox framework — it arrived in iOS 8 — so video calling falls back to the vendored VP8
  software codec on both the encode and the decode side. That path is wired and reachable but has
  never been measured on an A5; the feature table says so rather than promising it works.

## Feature table

Built from reading `src/`, not from a spec. **Supported** means the code path is genuinely wired
end to end, TDLib call through to a real screen. **Partial** means part of it works and the comment
says exactly what's missing. **Not supported** means it doesn't exist, and the comment says why —
usually the SDK, the hardware, or a deliberate decision, never "not yet gotten to."

### Messaging

| Feature | Status | Comment |
|---|---|---|
| Text, photo, video, document, voice and video-note (round video) messages | Supported | |
| Edit and delete own messages | Supported | |
| Replies, including replying to a specific quoted range | Supported | |
| Pinning and unpinning messages, pinned-messages bar and list | Supported | |
| "Seen by" — who has read a message in a group | Supported | |
| Typing indicators — sending your own and showing other people's | Supported | |
| Forwarding, including multi-select forward and "hide sender name" | Supported | |
| Drafts | Supported | Saved and restored per chat through TDLib's own draft field |
| Message search — in a chat, globally, by sender, by media type, jump-to-date calendar | Supported | |
| Chat folders, including shared folder invite links | Supported | |
| Archive | Supported | |
| Scheduled messages | Supported | |
| Saved Messages, with tags | Supported | |
| Polls | Supported | Creating (including removing a draft option before sending), voting, adding an option to an already-sent poll, per-option properties, and a "votes over time" chart all work; there is no UI to remove an option from a poll that's already been sent, matching real Telegram, which does not support that either |
| Checklists (to-do messages) | Partial | Ticking a task, adding a new task, and editing or deleting an individual task's text all work; there is no UI to rename the checklist's own title after creation |
| Reactions | Partial | Adding/removing standard and custom emoji reactions people already sent, seeing who reacted, and paid (Stars) reactions all work; there is no way yet to *pick* a custom-emoji reaction to send — only to display one someone else sent |
| Spoiler text and spoiler media | Supported | |
| Message effects | Supported | |
| Fact-check labels on channel posts | Supported | |
| Suggested / paid channel posts | Supported | Approve, decline, suggest and re-price a post offered into a channel's direct-messages chat |
| Paid media — pay-to-unlock photos/videos in a message | Partial | Unlocking someone else's paid media works end to end through Stars; there is no UI to compose and send your own pay-to-unlock media |
| Live location sharing | Supported | Send, live-update and stop a live location |
| Business quick replies, greeting/away messages, opening hours and location | Supported | |
| Business-connected bots (a bot handling your Business messages automatically) | Supported | |
| Channel direct messages ("monoforum" topics) | Supported | |
| Forum topics | Supported | |
| AI-assisted writing (compose, fix, translate, summarize) | Supported | Wraps Telegram's own server-side text tools; no on-device model |
| Importing chat history from another app | Not supported | iOS 6 has no document picker of any kind — there is no way to hand this app a file from outside its own sandbox |
| Screenshot notice in secret chats | Not supported | TDLib has no send-side call for this at all, and iOS 6 has no screenshot-taken hook (public or private) even if it did |

### Media

| Feature | Status | Comment |
|---|---|---|
| Photos, videos, GIFs, documents, voice messages, video messages | Supported | |
| Sticker packs — static and animated (Lottie-style) stickers | Supported | |
| Video/WebM stickers | Partial | Parsed and browsable, but no VP8/VP9 decode is wired for stickers specifically; a webm sticker falls back to its static thumbnail image instead of playing |
| Masks | Partial | Browsing, installing and searching mask sticker sets works, and a mask can be dragged/scaled/rotated onto a still photo by hand; there is no camera face detection to place one automatically, the way Telegram's own mask feature does |
| GIF search and trending GIFs | Supported | |
| Instant View (in-app article reader) | Supported | |
| Background music player | Supported | |
| QR codes — scanning and generating (invite links, login, public profile links) | Supported | |
| Photo/video editing before sending (crop, draw, filters) | Not supported | Deliberately out of scope for this port |
| Bot mini apps / web apps | Not supported | Needs a modern JS engine; iOS 6's `UIWebView` cannot run current Telegram Web App JS, and the hardware wouldn't survive a modern SPA regardless |

### Groups and channels

| Feature | Status | Comment |
|---|---|---|
| Create and manage basic groups and supergroups | Supported | |
| Converting a basic group to a supergroup | Supported | |
| Admin rights, permissions, custom admin titles | Supported | |
| Transferring group/channel ownership to another member | Supported | Requires re-entering your 2FA password, same as real Telegram |
| Leaving a group or channel | Supported | |
| Deleting a group or channel entirely, for everyone | Not supported | The "Delete" action in this app's chat list only leaves and wipes local history (TDLib's `deleteChatHistory` + `leaveChat`); it never calls TDLib's real `deleteChat`, so the chat still exists for every other member afterward |
| Multiple usernames, on your own account and on a channel/group | Supported | |
| Channel accent/profile colour and channel emoji status, boost-level gated | Supported | |
| Channel signatures / "show author profiles" | Supported | |
| Discussion group linking and comment threads on posts | Supported | |
| Channel and supergroup statistics | Supported | |
| Boosts — list, level features, deep links | Supported | |
| Join requests, slow mode, anti-spam, spam reports | Supported | |
| Per-group sticker sets | Supported | |
| Forum topics | Supported | (see Messaging above) |
| Location-based ("Groups nearby") groups | Not supported | Telegram retired the discovery call server-side; no client can rebuild a feature the server no longer offers |

### Calls

| Feature | Status | Comment |
|---|---|---|
| 1:1 voice calls — outgoing, incoming, mute, speakerphone, emoji-key verification, call rating | Supported | Own vendored `libtgvoip`, not a stub |
| Call bubbles in chat history, call-back, call log with clear/filter | Supported | |
| 1:1 video calls | Partial | The wiring is there and reachable: a Video Call tile on any one-to-one profile, and "Telegram Video Call" on a long-pressed phone number, both pass `video:YES` through to the call. VideoToolbox does not exist on iOS 6, so encoding and decoding fall back to the vendored VP8 software codec, which is compiled in. Whether a call is watchable end to end on an A5 has not been measured — treat it as untested, not as promised |
| Group calls / video chats — joining, speaking, muting, hand-raise | Not supported | Needs `tgcalls` (a WebRTC media engine), which isn't vendored anywhere in this repo, and this project also refuses on principle to ever place or join a real call |
| Group call / video chat viewing — title, live state, participant count, recent speakers, a live indicator in the chat header | Supported | Read-only by design; see the row above for why joining is out |
| System-style incoming-call screen on the lock screen | Supported, via optional jailbreak tweak | `tweaks/system-call` is a separate MobileSubstrate package; nothing it needs is compiled into the app binary itself |

### Stickers and emoji

| Feature | Status | Comment |
|---|---|---|
| Browsing, installing, searching sticker sets; editing sets you own | Supported | |
| Custom emoji packs — browsing, installing, and using a custom emoji from a pack you don't own | Supported | |
| Modern emoji glyphs (post-Unicode-6.0) | Partial | Bundled bitmap atlas rendered through CoreText as a fallback when the system font can't resolve a glyph, covering every single-codepoint emoji and flag pair; true ZWJ sequences (family groupings, profession+gender, hair-style combinations) have no composed image, so the joiner is dropped and the sequence falls apart into separate single-person glyphs |
| Modern emoji in the system keyboard | Supported, via optional jailbreak package | Lives in [kern0x1b/ios6-emoji](https://github.com/kern0x1b/ios6-emoji); the app works without it, just with the same fixed 2012-era keyboard palette |
| Emoji status on your own profile | Supported | |

### Search and folders

| Feature | Status | Comment |
|---|---|---|
| In-chat, global and scoped (media/links/files/voice) search | Supported | |
| Recent search history shown when opening search | Supported | |
| Chat folders, folder invite links, Archive | Supported | |

### Stories

| Feature | Status | Comment |
|---|---|---|
| Posting a story — photo/video, caption, areas, privacy | Supported | |
| Viewing stories, reacting, viewer lists | Supported | |
| Story albums, archived and hidden stories | Supported | |
| Story statistics | Supported | |
| Stealth mode, close friends list | Supported | |

### Saved Messages, drafts, notifications

| Feature | Status | Comment |
|---|---|---|
| Saved Messages, with tags | Supported | |
| Per-chat drafts | Supported | |
| Local notifications while backgrounded, screen locked | Supported | The primary connection is marked as a VoIP socket (`src/Storage/TGBackgroundSession.m` + a TDLib patch), which keeps it alive and connected indefinitely without a jailbreak, even across a reboot; an optional jailbreak LaunchDaemon (`daemon/relaunch`) adds a second layer that relaunches the app if it's force-quit from the app switcher or killed by jetsam. Burst throttling (at most one sound every 3 seconds, a hard budget per 10 seconds) is inherited from Twelve's iOS 6 fix so a large update doesn't stall SpringBoard |
| Remote push notifications (APNs) when the app is fully closed | Not supported | An APNs token is minted against the signing bundle id it was requested under; Telegram's servers only push to tokens minted for Telegram's own bundle id, which a sideloaded build can never obtain. This is a server-trust boundary, not a missing API call |
| Badge counting preference (unread chats vs. unread messages, include muted) | Supported | |
| In-app sound / vibrate / banner preview toggles | Supported | |
| Setting a custom notification sound | Supported | From an MP3 already received as an audio/document message — iOS 6 has no file picker to import one from outside the app |

### Secret chats

| Feature | Status | Comment |
|---|---|---|
| Creating and closing a secret chat | Supported | |
| Self-destruct timer, per-message and as a chat default | Supported | |
| "X took a screenshot" notice | Not supported | Neither TDLib nor iOS 6 offers a hook for this in either direction |

### Payments and Stars

| Feature | Status | Comment |
|---|---|---|
| Stars balance, transaction history, gifting, gift collections, upgraded gifts, collectibles | Supported | |
| Paying a bot invoice (a merchant bot's checkout) | Supported | Opens the payment provider's hosted checkout page in an embedded `UIWebView` |
| Paid messages and paid reactions | Supported | |
| Paid channel subscriptions | Supported | |
| Giveaways | Partial | Launching a giveaway you've already prepaid for works; there is no in-app purchase flow to buy a brand-new giveaway, matching how TDLib itself expects giveaways to be bought outside the messaging client |
| Refunding a Stars payment | Supported | |
| Redeeming and looking up Premium gift codes | Supported | |
| Buying Telegram Premium or Stars with real money | Not supported | A 2012-era StoreKit cannot address a modern App Store product catalogue Premium/Stars are registered against; this is also an outward-acting purchase on the account, which this project refuses to build regardless |

### Bots

| Feature | Status | Comment |
|---|---|---|
| Inline keyboards under messages, custom reply keyboards, callback buttons | Partial | Every button type (callback, switch-inline, URL, web app, copy-text, user, callback-with-password) is parsed and really dispatches; presented as an action sheet listing the buttons on tap, not as a persistent grid rendered under the bubble the way Telegram's own client draws it |
| Bot commands, starting a bot, deep-link start parameters | Supported | |
| Inline query results (`@bot query` in the input bar) | Supported | |
| Bot mini apps / web apps | Not supported | See Media above |

### Settings, privacy and storage

| Feature | Status | Comment |
|---|---|---|
| Multiple accounts (up to 3), with switch/add/remove | Supported | Each slot gets its own TDLib database directory; never two sessions open at once |
| Two-step verification, passcode lock, active sessions, blocked users, connected websites | Supported | |
| Privacy rules (last seen, calls, forwards, phone number, etc.) | Supported | |
| Proxy configuration | Supported | |
| Chat wallpapers and per-chat themes | Supported | |
| Storage and cache management — usage by chat/type, clear cache, download queue, network stats | Supported | |
| Automatic download settings by network/media type | Supported | |
| Translation — per-message "Translate" and installing a language pack from Telegram's servers | Supported | Only English UI strings ship in the app itself; installing an additional pack translates message text, not the interface chrome, and right-to-left table-row/accessory layout is a known remaining gap |

## Building

Toolchain: a Mac with a current Xcode, plus a legacy `iPhoneOS` SDK snapshot for the armv7 slice,
fetched by a helper script below (current Xcode no longer ships an armv7 `libSystem` stub). The
build is a [Theos](https://theos.dev) application project driven through `make`; no Xcode project exists.

```bash
brew install cmake gperf ccache
git clone --recursive <this repository>
cd telegram-classic
```

Before building for real use, register your own Telegram API credentials at
[my.telegram.org](https://my.telegram.org) (under *API development tools*), then:

```bash
cp src/Resources/Config/tg_config.h.example src/Resources/Config/tg_config.h
```

and fill in `TG_API_ID` / `TG_API_HASH` in that file. It is git-ignored — keep your own credentials
out of commits, they identify your application to Telegram.

TDLib is built as its own `libtdjson.dylib` by a standalone script, not by the Makefile, and is
loaded by the app at runtime with `dlopen` rather than linked statically — a statically linked copy
pushes the combined `__TEXT` segment past the armv7 Thumb branch's 16 MB reach, which current
Xcode's linker cannot route around. Building it the first time also fetches an older SDK snapshot
for the armv7 slice, because current Xcode's `iPhoneOS.sdk` no longer ships an armv7 `libSystem`
stub at all:

```bash
scripts/fetch-ios-sdk.sh          # once — an armv7-capable SDK snapshot into build/sdks
scripts/build-tdlib-dylib.sh      # once (or after a TDLib update) — builds build/armv7/tdlib/lib/libtdjson.dylib
export THEOS=~/theos             # wherever Theos lives
make FINALPACKAGE=1               # the app bundle, stripped and signed
make package FINALPACKAGE=1       # the same, wrapped as a .deb under packages/
```

`make` on its own builds the debug variant, which is larger and unstripped but otherwise identical.
`make stage` assembles the bundle under `.theos/_/Applications/Telegram.app` without packaging it,
and that is the path to copy onto a device. `make clean` removes `.theos/` and `packages/`.

The build produces a fat binary for both armv7 and arm64 (`ARCHS = armv7 arm64` in the makefile);
armv7 is the slice the project is written for and the only one exercised on hardware. `machofix`
repairs the armv7 slice inside the fat binary after the link.

`DEBUG_HARNESS=1 make` additionally compiles in a `telegramdev://` URL-scheme debug harness
(screenshot capture, memory/stack probes, synthetic taps and scrolls — see
`src/App/AppDelegate+DebugHarness.m`). A plain `make` never builds that file at all, so production
has zero trace of it.

Several more build-time traps are load-bearing here: the linker drops the Thumb bit on function
pointers it writes into data sections, which `scripts/fix-armv7-macho.c` puts back on every build;
symbols weak-imported from a later iOS resolve to `NULL` rather than failing to link; and the SDK
snapshot above exists because current Xcode ships no armv7 `libSystem` stub. Each is explained in
the commit that introduced its fix — this repository forbids comments in source, so `git log` and
`git blame` are where the reasoning lives.

No test framework is vendored; `scripts/run-host-tests.sh` compiles a small table of pure-function
tests straight against the Mac's own Foundation, no iOS SDK involved, and prints pass/fail counts.
`scripts/run-fuzz-flatten-message.sh` builds a libFuzzer harness against the same boundary — see
`tests/README.md` for both.

## Installing on a device

A jailbreak is required — there is no signed distribution of this app anywhere, by design:

1. `make FINALPACKAGE=1 stage` to produce `.theos/_/Applications/Telegram.app`, or
   `make package FINALPACKAGE=1` for a `.deb` you can install with `dpkg -i` on the device.
2. Copy the `.app` bundle onto the device (`scp`, over SSH, to a jailbroken device with OpenSSH
   installed — e.g. from Cydia).
3. Ad-hoc sign the binary with [`ldid`](https://github.com/ProcursusTeam/ldid), which is available
   on-device through Cydia/Sileo:
   ```
   ldid -S/path/to/entitlements.plist /path/to/Telegram.app/Telegram
   ```
   using `src/Resources/entitlements.plist` from this repository.
4. Register the bundle with SpringBoard (`uicache`, or reinstalling through a package manager) so
   the icon appears.

If you are replacing an already-installed copy, delete the old binary first rather than copying
over it in place — the kernel caches a Mach-O's code signature against the file's inode, so copying
over the same path silently keeps enforcing the *old* signature. Replace the binary, not the whole
bundle, unless bundled resources changed too. Stop the app with SIGTERM and give it a moment before
resorting to SIGKILL: TDLib flushes its local database on the way out, and a hard kill mid-write can
cost the session and force a fresh login.

Four further pieces are optional, not part of the app binary itself, each installed separately:

- `tweaks/system-call` — a MobileSubstrate tweak that raises an incoming Telegram call as a
  system-style lock-screen call. Built and shipped as its own Cydia `.deb`.
- The two emoji packages — the replacement system emoji font and the keyboard patch — are not in
  this repository at all. They are system-level work with no knowledge of this app and live in
  [kern0x1b/ios6-emoji](https://github.com/kern0x1b/ios6-emoji).
- `daemon/relaunch` — a LaunchDaemon (`telegramd`) that relaunches the app if it's force-quit from
  the app switcher or killed by jetsam, so backgrounded notifications keep arriving; see
  `daemon/relaunch/README.md` and `daemon/relaunch/install.sh`.

## Repository layout

```
telegram-classic/
├── Makefile              # the entire build — there is no Xcode project
├── src/                  # everything that compiles into Classicgram.app
│   ├── App/               # application lifecycle, root view controllers, TGCoordinator (navigation seam)
│   ├── TDLibClient/        # the TDLib wrapper (TGClient and its per-feature categories) — the only package allowed to import TDLib's own headers
│   ├── Model/              # value objects
│   ├── Wire/               # TDLib JSON-boundary DTOs (Wire/Types, pervasively used), plus an Encode/Decode/request layer most of the app does not actually go through
│   ├── Stores/             # observer-pattern local caches for chat/account/user/etc. state — some screens feed and read them, most exist unfed
│   ├── Services/           # per-feature facades in front of TDLibClient, in two unrelated shapes sharing one directory
│   ├── Companions/         # per-screen non-UI helper objects
│   ├── Screens/            # every UITableViewController/UIViewController, grouped by area
│   ├── Views/              # reusable views and table cells
│   ├── Theme/              # the single visual theme
│   ├── Layout/             # geometry/measurement code shared across screens
│   ├── Utilities/          # cross-cutting helpers
│   ├── Storage/            # on-disk state: accounts, disk cache, passcode, notifications
│   ├── Media/              # image/audio/video decode, sticker and emoji caches
│   ├── Calls/              # the voice/video call engine's app-side glue
│   └── Resources/          # Info.plist, entitlements, images/, Localization/, Config/
├── daemon/relaunch/        # optional jailbreak LaunchDaemon: relaunches the app after a force-quit/jetsam kill
├── tweaks/                 # the SpringBoard call-UI tweak: a dylib injected into another process, shipped as .deb
├── third_party/            # every vendored tree (TDLib, libtgvoip, libvpx, opus, webp, …)
│                           #   plus prebuilt archives and the tdlib submodule's patches
├── scripts/                # build, device-deployment and lint automation, flat and verb-first
│   └── ui-automation/      # a SpringBoard driver injected for testing: unlock, tap, screenshot
│                           #   plus baselines/ — the layer-lint baseline files the hook checks against
└── tests/                  # the host-side pure-function test harness
```

## Where the reasoning lives

The house rule against comments in source means the "why" is not in the files. It is in the commit
that made the change: every non-obvious decision here — the layer rules, the chat-message
item/layout/cell split, the build traps, the settled visual decisions — was explained in its commit
message, so `git log -p` and `git blame` on the line you are puzzled by are the primary reference.

Two shorter forms sit next to the code itself:

- `CLAUDE.md` — the house rules that bind every change: the SDK ceiling, no comments, the settled
  product decisions, and what must never be done to a signed-in account.
- `.claude/skills/` — task guides for building and verifying, deploying to a device, judging a
  screenshot, working within the iOS 6 SDK, and the shell traps that produce wrong results which
  look right.

The checks that enforce all of this are the scripts under `scripts/`, wired to a pre-commit hook by
`scripts/install-git-hooks.sh`. Run any of them by hand; each prints what it checked and exits
non-zero on a real violation.

## Licence

GNU General Public License v3.0. See [`LICENSE`](LICENSE) for the full text and
[`NOTICE`](NOTICE) for the attribution this licence requires — in particular, the portions of this
app's 2013-era interface and artwork taken from the [Twelve](https://github.com/theanazerka/twelve-project)
project, originally GPL-2.0-or-later and relicensed here under GPLv3 as that licence permits.

## Credits

- **Original author**: Igor V. Sementsov ([@igkuzm](https://github.com/igkuzm))
- **Earlier work this descends from**: [bla1r1/iTgLegacy](https://github.com/bla1r1/iTgLegacy)
- **2013 interface and artwork**: reproduced from [Twelve](https://github.com/theanazerka/twelve-project)
  by theanazerka, itself carrying forward Telegram for iOS v1.1's original 2013 source and artwork
  (Copyright Peter Iakovlev, 2013). Full file-by-file attribution is in [`NOTICE`](NOTICE).
- **[TDLib](https://github.com/tdlib/td)**: Telegram's own open-source client library, which this
  app talks to via a dynamically loaded `libtdjson.dylib` — it is the entire networking and protocol
  layer, and this project vendors it as a patched submodule under `third_party/tdlib`.
- **Vendored third-party components** (`third_party/`, each under its own upstream licence): a fork
  of **libtgvoip** for voice/video call transport; **libvpx** (VP8); **Opus**, **libogg** and
  **opusfile**/**opusenc** for audio; **libwebp** for image decode; **OpenSSL** for TLS; **quirc**
  for QR code decoding.
- **This project**: maintained by kern0x1b and contributors.

Classicgram is an independent, unofficial project and is not affiliated with, endorsed by, or sponsored by
Telegram FZ-LLC, Telegram Messenger Inc., or Apple Inc.

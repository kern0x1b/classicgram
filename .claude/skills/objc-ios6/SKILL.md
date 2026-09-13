---
name: objc-ios6
description: Use when writing or reviewing Objective-C for this codebase — choosing a layout approach, an alert/action-sheet API, a networking call, or anything touching a TDLib id or file id. Covers what the iOS 6 SDK does not have, the in-house replacements this project already uses, and the id-type traps specific to this client.
---

# Objective-C on the iOS 6 SDK

Target: iPhone 4S / iPad 2, iOS 6.1.3, armv7, built against the **iOS 6 SDK only**
(`-miphoneos-version-min=6.0`). Nothing from a later SDK is available at compile time, regardless
of whether the runtime would technically support it — the SDK headers themselves are absent.
ARC is on (`-fobjc-arc`).

## Forbidden — do not reach for these, ever

- `UICollectionView` — iOS 6 only has `UITableView` for scrollable lists.
- Auto Layout / `NSLayoutConstraint` / `UIStackView` — frames only.
- `UIAlertController` — iOS 6 has `UIAlertView` and `UIActionSheet` and nothing else.
- `UNUserNotificationCenter` — iOS 6 uses `UILocalNotification` / the old push APIs.
- CallKit / PushKit — do not exist pre-iOS 8/10.
- `LocalAuthentication` (Touch ID/Face ID) — does not exist pre-iOS 8, and the 4S has no sensor.
- `WKWebView` — iOS 6 only has `UIWebView`.

If a suggestion (from training data, from a modern reference client) uses any of these, it does
not apply here regardless of how idiomatic it looks for "current iOS" — check the SDK ceiling
before the suggestion, not after writing code that won't compile.

## What this project uses instead

- **Layout**: explicit `CGRectMake` frames plus `autoresizingMask` (springs/struts), computed in
  code — see any `-layout...` method in `TGChatViewController.m` for the house style. **Never
  hard-code `320`** for a width — derive it from the owning view's or table's actual bounds, since
  the iPad target is 768pt wide and a literal `320` silently produces an iPhone-only layout.
- **Alerts / confirmations**: `UIAlertView` directly, or `TGActionSheetIndexBuilder`
  (`src/Utilities/TGActionSheetIndexBuilder.h`) wrapping `UIActionSheet` for anything with more
  than two options — this in-house builder is what most existing call sites already use instead of
  constructing `UIActionSheet` by hand; match it for consistency rather than inventing a second
  pattern.
- **Nav-bar buttons**: push a screen, or raise a plain system `UIActionSheet` (via the builder
  above) — never `TGPopupMenu`, the project's own custom popup. This is a settled decision, not a
  style suggestion; it has been reverted once already after an agent converted a bar button to the
  custom menu.
- **Networking**: `NSURLConnection`, not `NSURLSession` (iOS 7+).
- **Web content**: `UIWebView`, only where genuinely necessary — most content in this app is
  rendered natively, not in a web view.

## TDLib id types and the codebase's own id traps

- Every TDLib id (`chat_id`, `message_id`, `user_id`, `file.id`, etc.) is a **`long long`** —
  never `NSInteger`/`int`, which truncate on 32-bit armv7 and silently corrupt the id.
- **`file.id` is session-local** — it is only valid for the lifetime of the current TDLib client
  session and must never be persisted (cached to disk, used as a dictionary key that survives a
  relaunch). Only **`file.remote.unique_id`** (a string, not an int) is stable across sessions —
  it is what this codebase actually uses as a persistent cache key (see
  `TGClient+Stickers.m`'s `TGRemoteUniqueId(file)` and the `photoKey`/`userPhotoKeysById` uses in
  `TGClient.m`). If you need to remember "this is the same file/photo" across a relaunch, key on
  `remote.unique_id`, never on `file.id`.
- TDLib is reached through a **dlopen'd `libtdjson.dylib`**, not linked at compile time
  (`TGClient.m`'s `dlopen`/`dlsym` of `td_json_client_create` etc.) — there is no static TDLib
  Objective-C binding to autocomplete against; every TDLib call is a hand-built JSON dictionary
  sent through the C function pointers `TGClient` resolved at startup. Check `TGClient.h` and its
  category headers for the Objective-C method that already wraps the TDLib call you want before
  building a new raw JSON request — most TDLib methods already have a category method.
- Method ownership: `TGClient.m` is being split into per-feature categories
  (`TGClient+Stickers.m`, `TGClient+Privacy.m`, `TGClient+ChatList.m`, etc.) — before adding a new
  TDLib-facing method, check whether a category for that feature area already exists and belongs
  there rather than growing the primary `TGClient.m` file further.

## Never act outward on the user's account

No code path may send a message, place a call, join/leave a chat, block, or report, from the
user's real Telegram account. The `telegramdev://send` and `telegramdev://call` debug URLs were
removed from the harness specifically for this reason and must not be reintroduced in any form,
including as a "test-only" gated path.

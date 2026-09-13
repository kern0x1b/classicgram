# Telegram Classic — house rules

A Telegram client for hardware Telegram itself dropped: 32-bit armv7 iPhones and iPads on iOS 6.
Objective-C against the iOS 6 SDK, a Theos build, TDLib
reached at runtime through a `dlopen`ed `tdjson`.

These rules bind anyone working in this repository, human or agent. They describe the project, not
one person's setup. Keep device addresses, credentials, local paths and your own deploy loop in a
file outside this repository; nothing here may assume a particular machine, a particular device at
a particular address, or a particular checkout path.

## Absolute prohibitions

- **Never act outward on the signed-in account.** No sending, calling, forwarding, reacting,
  deleting, joining, blocking or reporting. The account a development build is logged into belongs
  to a real person and usually holds real conversations. Debug URLs that sent a message or placed a
  call were removed for exactly this reason and must not return in any form.
- **No comments in source. None.** Not `//`, `///`, `/* */`, a doc block above a method, or a header
  banner — in any language in this repository, in new files as much as in edits. Explain the
  reasoning in the commit message or the pull request. If a line needs explaining, rename the
  variable or split the method until it does not. This rule is broken more often than any other; a
  diff that adds a comment is wrong even when the code in it is right.
  `scripts/lint-source-comments.py` enforces it, and the pre-commit hook runs it.
- **The iOS 6 SDK is the ceiling.** No UICollectionView, Auto Layout, UIAlertController,
  UNUserNotificationCenter, CallKit, PushKit, LocalAuthentication or WKWebView. Every list is a
  `UITableView`, every layout is a computed `CGRect`, every alert is a `UIAlertView` or a
  `UIActionSheet`.
- **No hard-coded screen width.** Derive widths from the view or the table. The supported targets
  differ in both width and scale, so a literal `320` is wrong on all but one of them.

## TDLib ids

Ids are `long long`. `file.id` is session-local: never persist it, never use it as a cache key.
Only `remote.unique_id` survives a restart.

## Where the look and the behaviour come from

The look comes from Telegram for iOS as it shipped in 2013, the behaviour from the modern client,
and the code already in this repository is the lowest authority of the three. When the three
disagree, that order settles it.

## Settled product decisions

Each of these was decided, changed by someone anyway, and restored. Changing one again is a defect,
not a preference.

- **Every message is drawn in a bubble** — text, photo, album, video, file, voice, poll, call, service
  line, all of them. The only exceptions are round video notes, stickers, animated stickers, animated
  emoji and dice, which sit directly on the wallpaper with no bubble.
- **Nothing has square corners.** A picture inside a bubble is rounded to the bubble's own radius so
  it sits inside it, never a sharp-cornered rectangle over rounded chrome.
- **The timestamp plate is always beside the bubble, never on top of the artwork.** It sits outside
  the bubble on the wallpaper, on the side the message came from, exactly the same for a photo or an
  album as for a line of text. The only messages whose plate sits anywhere else are the ones with no
  bubble at all, where it goes on the wallpaper beside the artwork.
- A navigation-bar button raises the system `UIActionSheet` or pushes a screen. Never a custom popup.
- One theme. No picker, no dark or flat variant, no imported theme files.
- The app icon is left alone; the system draws the shine.
- No advertising or sponsored messages anywhere, in channels or otherwise — deliberately never
  implemented, not a gap. TDLib only ever delivers a sponsored message through the dedicated
  `getChatSponsoredMessages` RPC, never through the ordinary message pipeline, so simply never
  calling it is sufficient and safe. If a future change is ever found rendering one, cut it out
  completely; that is a bug, not a feature to finish.

## Working rules

- Build before claiming a change works: `make FINALPACKAGE=1` has to reach the `machofix` lines, and the
  checks under `scripts/` have to stay green. Compiling is not verifying.
- A screenshot that renders is not a screenshot that is correct. Compare the region you changed
  against the same region before the change, zoomed with nearest-neighbour — a smoothed zoom hides
  exactly the single-pixel differences that matter here.
- Work in a git worktree under `.claude/worktree/`, never in the main checkout, and never rewrite or
  discard work that is not yours without being asked to. When the work is done it belongs in the
  main checkout's branch: merge it there, verify the build, then delete the worktree.
- The device is not a build server. Replace the installed binary rather than the whole bundle, and
  stop the app with SIGTERM before SIGKILL — TDLib flushes its database on the way out, and a hard
  kill mid-write can cost the session.

## Skills

`.claude/skills/` holds the task-specific guides: building and verifying, deploying to a device,
judging a screenshot, the iOS 6 SDK and what to use in place of what it lacks, and the shell traps
that have produced wrong results which looked right. Load the one that matches before working a
task out from scratch.

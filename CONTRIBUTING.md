# Contributing to Telegram Classic

The project targets hardware that stopped receiving updates in 2013, so a change here is judged by
a narrower set of rules than most codebases apply. Reading this page first will save you a round of
review.

## Before you write code

- Build once and run the tests: `make FINALPACKAGE=1`, then `./scripts/run-host-tests.sh`. The build must
  reach its `machofix: Thumb bit restored …` line; a build that stops earlier produces a binary the
  device cannot launch.
- Point `$THEOS` at a Theos checkout; the build is a Theos application target.
- Install the hooks: `./scripts/install-git-hooks.sh`. The pre-commit hook runs the lint scripts
  under `scripts/`, and it refuses the same things a reviewer would.
- Work on a branch in a worktree under `.claude/worktree/`, not in the main checkout. See
  [`.claude/skills/build-and-verify/SKILL.md`](.claude/skills/build-and-verify/SKILL.md) for the
  symlinks a fresh worktree needs before its first build.

## The rules a change is measured against

**The iOS 6 SDK is the ceiling.** No `UICollectionView`, Auto Layout, `UIAlertController`,
`WKWebView`, CallKit, PushKit or LocalAuthentication. Every list is a `UITableView`, every layout is
a computed `CGRect`, every alert is a `UIAlertView` or a `UIActionSheet`. `scripts/lint-sdk-ceiling.py`
enforces this.

**No comments in source.** None — not `//`, not `/* */`, not a doc block above a method. Put the
reasoning in the commit message or the pull request. If a line needs explaining, rename the variable
or split the method until it does not. `scripts/lint-source-comments.py` enforces this.

**No hard-coded screen width.** Derive widths from the view or the table; the supported devices
differ in both width and scale.

**The look comes from Telegram for iOS as it shipped in 2013**, the behaviour from the modern
client, and the code already here is the lowest authority of the three. When they disagree, that
order settles it.

**Tests come with the change.** `tests/` holds host tests that run on macOS in seconds; add cases to
the matching file and register them in `tests/host_tests_main.m`. Logic that can be pulled out of a
view controller and tested should be.

**Fixture data is invented.** Never put a real account's name, username, phone number or user id in
a test, a screenshot or a commit.

## Pull requests

- One subject per pull request. A change that fixes a bug and also renames twenty files is two
  pull requests.
- The message explains *why*, since the code may not: what was wrong, what the fix does, and how you
  verified it on hardware or in tests.
- Say which device and iOS version you tested on, or say plainly that you could not test on hardware.
- Screenshots for anything that changes the interface. Take them against Telegram's test servers
  (`TG_TEST_DC=1`, see the README) rather than your own account, so no real conversation ends up in
  a public image.

## Reporting a bug

Open an issue with the device, the iOS version, what you did, what happened, and what you expected.
A crash report from `/var/mobile/Library/Logs/CrashReporter/` is worth more than any description.
Security-sensitive reports go the private route described in [`SECURITY.md`](SECURITY.md) instead.

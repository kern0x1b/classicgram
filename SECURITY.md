# Security policy

## What this project is

Telegram Classic is an unofficial client that runs on hardware whose operating system, iOS 6, has
not received a security update since 2014. The platform itself is unpatched: a device running this
app is not a safe place for a sensitive account, no matter how carefully this code is written. Treat
it as what it is — a way to keep old hardware usable, not a hardened messenger.

Transport security and the MTProto protocol are TDLib's, not this project's; this app loads
`libtdjson.dylib` and talks to it. A protocol-level issue belongs upstream at
[tdlib/td](https://github.com/tdlib/td). What is in scope here is everything around it: how this app
stores data on the device, what it writes to logs, how it handles the local passcode, and what it
puts on screen.

## Reporting a vulnerability

Report privately, not in a public issue:

- GitHub's **Report a vulnerability** button under this repository's Security tab (private advisory).

Please include the device and iOS version, the build you tested, steps to reproduce, and what an
attacker gets out of it. A proof of concept is welcome; a crash report is enough to start.

Expect a first reply within a week. There is no bounty programme — this is a spare-time project — and
no formal SLA, but a reproducible report gets a fix and credit in the advisory unless you ask to stay
anonymous.

## Out of scope

- Anything that requires the attacker to already have root on the device. A jailbreak is a
  prerequisite for installing this app at all.
- Weaknesses inherent to iOS 6 itself (TLS stack, kernel, Safari/UIWebView engine).
- Issues in TDLib's protocol implementation — report those upstream.

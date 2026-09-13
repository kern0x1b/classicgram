# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project does not
publish versioned releases, so changes are grouped under **Unreleased** and dated
when they land on `main`.

## [1.0] - 2026-09-13

First public release as **Classicgram**, an unofficial Telegram client, distributed as a
Cydia `.deb` (`com.kern0x1b.telegram`) for armv7 + arm64. The [feature table](README.md#feature-table) lists what the client
does; the app reports its Telegram feature-parity version (1.16.48) in Settings,
while `1.0` is the release/package version.

## [Unreleased]

Classicgram is developed continuously on `main`; there is no tagged release.
The [feature table](README.md#feature-table) is the authoritative statement of
what works. Notable recent changes:

- The project is presented consistently as **Classicgram**: the README title, the in-app
  Settings footer (which now also states it is an unofficial client using the Telegram API), and
  the repository name all match the app.

- The build moved to a [Theos](https://theos.dev) application project (`make
  FINALPACKAGE=1`), replacing the hand-written Makefile.
- The arm64 slice is built into the same fat binary as armv7 (`ARCHS = armv7 arm64`).
- Repository history was reset to a single commit and the project was renamed to
  `telegram-classic`; community health files (this changelog, CODEOWNERS,
  editorconfig, issue/PR templates, SECURITY, CONTRIBUTING, CODE_OF_CONDUCT) were
  added.

[Unreleased]: https://github.com/kern0x1b/classicgram/compare/v1.0...HEAD
[1.0]: https://github.com/kern0x1b/classicgram/releases/tag/v1.0

# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project does not
publish versioned releases, so changes are grouped under **Unreleased** and dated
when they land on `main`.

## [Unreleased]

Telegram Classic is developed continuously on `main`; there is no tagged release.
The [feature table](README.md#feature-table) is the authoritative statement of
what works. Notable recent changes:

- The build moved to a [Theos](https://theos.dev) application project (`make
  FINALPACKAGE=1`), replacing the hand-written Makefile.
- The arm64 slice is built into the same fat binary as armv7 (`ARCHS = armv7 arm64`).
- Repository history was reset to a single commit and the project was renamed to
  `telegram-classic`; community health files (this changelog, CODEOWNERS,
  editorconfig, issue/PR templates, SECURITY, CONTRIBUTING, CODE_OF_CONDUCT) were
  added.

[Unreleased]: https://github.com/kern0x1b/telegram-classic/commits/main

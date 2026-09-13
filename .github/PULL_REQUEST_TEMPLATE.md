## What this changes

<!-- One subject per pull request. Say what was wrong and what the change does about it. -->

## Why

<!-- The reasoning that cannot live in the code, since this codebase carries no comments. -->

## How it was verified

- [ ] `make FINALPACKAGE=1` reaches its `machofix: Thumb bit restored …` line
- [ ] `./scripts/run-host-tests.sh` passes
- [ ] Tested on hardware — device and iOS version: <!-- e.g. iPad 2, iOS 6.1.3 --> <!-- or: not tested on hardware -->

## Interface changes

<!-- Screenshots, before and after. Use the demo mode (TG_DEMO_MODE=1) rather than a real account. -->

## Checklist

- [ ] No comments added to source
- [ ] Nothing above the iOS 6 SDK ceiling
- [ ] No hard-coded screen width
- [ ] Tests added or updated
- [ ] No real account's data in code, tests or screenshots

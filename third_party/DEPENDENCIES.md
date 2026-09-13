# Third-party dependency versions

One row per directory under `third_party/`. "Pinned by" says what in this repository fixes the
version today. "Bump" says the exact steps to move to a newer one.

| Directory | What | Version today | Pinned by | Rebuild script |
|---|---|---|---|---|
| `openssl/` | OpenSSL, static `libcrypto`/`libssl` | 1.1.1d (2019-09-10), read from `prebuilt/include/opensslv.h` | the two tracked archives in `prebuilt/lib/` | `scripts/rebuild-openssl.sh` (builds 1.1.1w) |
| `tdlib/td` | TDLib | submodule pinned at commit `022d60202e446ad1287b9fb68e687c8a0760788b`, plus the 22-file `patches/tdlib-ios6.patch` on top | `.gitmodules` commit + the patch set | `scripts/build-tdlib-dylib.sh` (armv7), `scripts/build-tdlib-dylib-arm64.sh` (arm64) — both build from source, there is no prebuilt TDLib |
| `libvpx/` | VP8/VP9 codec | 1.13.1 "Ugly Duckling" (2023-09-29), read from `CHANGELOG`'s top entry | vendored source tree, no submodule | none — the Makefile compiles it directly from the vendored source; "rebuilding" means replacing the tree with a newer upstream checkout |
| `libtgvoip/` | VoIP transport (Grishka's fork) | not recorded anywhere in the tree — no version string, no submodule, no CHANGELOG | vendored source tree | none — same as libvpx |
| `opusfile/` | Ogg/Opus file container | not recorded in the vendored tree (no `configure`-generated `config.h` survives, so no `PACKAGE_VERSION`) | vendored source tree | none |
| `ogg/` | libogg | not recorded in the vendored tree, same reason as opusfile | vendored source tree | none |
| `opusenc/` | Opus encoder helper (`opus_header.*`) | not recorded in the vendored tree | vendored source tree | none |
| `quirc/` | QR decoder | `quirc_version()` returns the literal `"1.0"` (`quirc.c:7`) | vendored source tree | none |
| `opus/prebuilt` | Opus codec, static `libopus.a` | not recorded — the archive carries no embedded version string and the headers under `prebuilt/include` don't either | tracked prebuilt archive, force-added before this refactor | none written yet — see "Gaps," below |
| `webp/prebuilt` | WebP image codec, `WebP.framework` | not pinned to a release — only ABI markers survive, `WEBP_ENCODER_ABI_VERSION 0x0202` / `WEBP_DECODER_ABI_VERSION 0x0203` in the vendored headers, which have been stable across many libwebp releases and do not identify one | tracked prebuilt framework | none written yet — see "Gaps," below |

## How to bump a dependency

**OpenSSL.** Edit `OPENSSL_VERSION`, `OPENSSL_TAG` and `OPENSSL_SHA256` at the top of
`scripts/rebuild-openssl.sh` to the new release's tag and the sha256 published at
`https://github.com/openssl/openssl/releases/download/<tag>/openssl-<version>.tar.gz.sha256`, run the
script, then run `scripts/build-openssl-libs.sh`, then rebuild both TDLib dylibs (TDLib links against
these), then update the version and date in the table above.

**TDLib.** `cd third_party/tdlib/td && git fetch && git checkout <new-commit>`, re-apply
`patches/tdlib-ios6.patch` (`git apply --check` first — a TDLib upstream change touching one of the
patched files will make this the step that actually needs work, not a formality), regenerate the
patch file from the result if anything had to change, then run both `build-tdlib-dylib*.sh` scripts
and update the pinned commit above.

**libvpx / libtgvoip / opusfile / ogg / opusenc / quirc.** These are plain vendored source, compiled
directly by the root `Makefile` — there is no separate build step to script. Replace the directory's
contents with a fresh upstream checkout (keeping the existing `LICENSE` file, or replacing it with the
new release's), diff for files the Makefile's generated source list would need to pick up, and rebuild.
`libtgvoip` has no upstream release tags to pin to; record the exact source commit or tarball used in
this table when it's bumped, so this row stops saying "not recorded."

**opus / webp (prebuilt).** No rebuild script exists for either yet. Both need the same treatment
`rebuild-openssl.sh` gives OpenSSL: a script that builds the archive/framework from a pinned upstream
source tag for armv7 and arm64 and drops the result at `opus/prebuilt/` or `webp/prebuilt/`. Until that
script exists, the tracked binaries are the only copies and bumping them means rebuilding by hand and
recording the version and command line used, here.

## Gaps this wave did not close

Per-dependency rebuild scripts exist only for OpenSSL and TDLib, because those were the two named in
this wave's task. `libvpx`, `libtgvoip`, `opusfile`, `ogg`, `opusenc` and `quirc` are compiled from
vendored source by the Makefile already, which satisfies "buildable from source" without a separate
script; `opus` and `webp` are prebuilt binaries with no rebuild path at all, tracked but frozen at
whatever version they were originally built at — nobody currently knows what that is. Writing their
rebuild scripts is follow-up work, not done here.

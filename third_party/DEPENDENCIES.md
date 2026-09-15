# Third-party dependency versions

One row per directory under `third_party/`. "Pinned by" says what in this repository fixes the
version today. "Bump" says the exact steps to move to a newer one.

OpenSSL and TDLib are no longer vendored under `third_party/` at all — both are built by Conan from
vanilla upstream source, see `packaging/openssl` and `packaging/tdlib`. The Makefile resolves them
through `packaging/deps` (`conan install`, generating `ios6-deps.env` per architecture); nothing to
run by hand.

| Directory | What | Version today | Pinned by | Rebuild script |
|---|---|---|---|---|
| `libvpx/` | VP8/VP9 codec | 1.13.1 "Ugly Duckling" (2023-09-29), read from `CHANGELOG`'s top entry | vendored source tree, no submodule | none — the Makefile compiles it directly from the vendored source; "rebuilding" means replacing the tree with a newer upstream checkout |
| `libtgvoip/` | VoIP transport (Grishka's fork) | not recorded anywhere in the tree — no version string, no submodule, no CHANGELOG | vendored source tree | none — same as libvpx |
| `opusfile/` | Ogg/Opus file container | not recorded in the vendored tree (no `configure`-generated `config.h` survives, so no `PACKAGE_VERSION`) | vendored source tree | none |
| `ogg/` | libogg | not recorded in the vendored tree, same reason as opusfile | vendored source tree | none |
| `opusenc/` | Opus encoder helper (`opus_header.*`) | not recorded in the vendored tree | vendored source tree | none |
| `quirc/` | QR decoder | `quirc_version()` returns the literal `"1.0"` (`quirc.c:7`) | vendored source tree | none |
| `opus/prebuilt` | Opus codec, static `libopus.a` | not recorded — the archive carries no embedded version string and the headers under `prebuilt/include` don't either | tracked prebuilt archive, force-added before this refactor | none written yet — see "Gaps," below |
| `webp/prebuilt` | WebP image codec, `WebP.framework` | not pinned to a release — only ABI markers survive, `WEBP_ENCODER_ABI_VERSION 0x0202` / `WEBP_DECODER_ABI_VERSION 0x0203` in the vendored headers, which have been stable across many libwebp releases and do not identify one | tracked prebuilt framework | none written yet — see "Gaps," below |

## How to bump a dependency

**OpenSSL.** Edit `version` and the `conandata.yml` `url`/`commit` in `packaging/openssl` to the new
release's tag and commit, re-check the `_armcap_old`/`_armcap_new` patch text in `conanfile.py`
against the new source (it has changed shape between major versions before), then
`conan create packaging/openssl -pr:h ios6-armv7 -pr:b default --build=missing` (and again with
`-pr:h packaging/profiles/arm64`) to confirm it still builds both architectures.

**TDLib.** Edit `_TDLIB_COMMIT` in `packaging/tdlib/conanfile.py`, then verify the two replacement
tables (`_TLS_REPLACEMENTS`, `_VOIP_BACKGROUND_REPLACEMENTS`) still apply cleanly against the new
commit — `conan create` raises immediately if a `replace_in_file` text goes missing, so a clean
build is real confirmation, not a formality. Rebuild both architectures the same way as OpenSSL
above.

**libvpx / libtgvoip / opusfile / ogg / opusenc / quirc.** These are plain vendored source, compiled
directly by the root `Makefile` — there is no separate build step to script. Replace the directory's
contents with a fresh upstream checkout (keeping the existing `LICENSE` file, or replacing it with the
new release's), diff for files the Makefile's generated source list would need to pick up, and rebuild.
`libtgvoip` has no upstream release tags to pin to; record the exact source commit or tarball used in
this table when it's bumped, so this row stops saying "not recorded."

**opus / webp (prebuilt).** No rebuild script exists for either yet. Both would benefit from the same
treatment OpenSSL and TDLib already got: a Conan recipe under `packaging/` that builds the archive/
framework from a pinned upstream source tag for armv7 and arm64. Until that exists, the tracked
binaries are the only copies and bumping them means rebuilding by hand and recording the version and
command line used, here.

## Gaps this wave did not close

OpenSSL and TDLib moved to Conan recipes because those were the two named in this wave's task.
`libvpx`, `libtgvoip`, `opusfile`, `ogg`, `opusenc` and `quirc` are compiled from vendored source by
the Makefile already, which satisfies "buildable from source" without a separate recipe; `opus` and
`webp` are prebuilt binaries with no rebuild path at all, tracked but frozen at whatever version they
were originally built at — nobody currently knows what that is. Writing their
rebuild scripts is follow-up work, not done here.

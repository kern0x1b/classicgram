# Dependencies

No third-party source is stored in this repository. Every dependency is fetched from its own
upstream by the Conan recipe named below, built into the Conan cache under `$CONAN_HOME`, and
resolved by the Makefile through `packaging/deps` (`conan install`, which writes one
`ios6-deps.env` per architecture). What is tracked here is the recipe, its `conandata.yml` pin,
and — for libtgvoip only — this port's own patch and its four project-authored files.

| Recipe | Upstream | Pinned to | Why this version |
|---|---|---|---|
| `tdlib` | github.com/tdlib/td | commit `022d6020` | the app's TDLib API surface is built against it |
| `openssl` | github.com/openssl/openssl | `openssl-3.0.22` | newest 3.0.x LTS patch; 3.5+ changed `OPENSSL_armcap_P` from `.comm` to `.extern`, which breaks the PC-relative `.word OPENSSL_armcap_P-.` arithmetic the armv7 assembly needs |
| `libtgvoip` | github.com/grishka/libtgvoip | commit `6c82c9de` (branch `public`) | the tip of `public`, upstream's default branch: the newest commit that exists, the project having had no change since mid-2019 |
| `libvpx` | github.com/webmproject/libvpx | `v1.16.0` | latest release |
| `opus` | github.com/xiph/opus | `v1.6.1` | latest release; it also fixes the `OPUS_MAY_SUPPORT_NEON`/`OPUS_MAY_HAVE_NEON` name mismatch that forced manual NEON overrides on 1.3.1 |
| `opusfile` | github.com/xiph/opusfile | `v0.12` | latest release |
| `opusenc` | github.com/xiph/opus-tools | `v0.1.10` | latest release whose `opus_header_to_packet` still takes three arguments; v0.2 moved it into an encoder object and added a fourth, which does not match `src/Media/opusenc.m` |
| `ogg` | github.com/xiph/ogg | `v1.3.6` | latest release |
| `quirc` | github.com/dlbeer/quirc | commit `927d6809` | upstream has no release newer than its last tag |
| `webp` | chromium.googlesource.com/webm/libwebp | `v1.6.0` | latest release |

The `tdlib` recipe additionally downloads `emutls.c` and four `int_*.h` headers from LLVM's
compiler-rt at `llvmorg-21.1.0`, each pinned by sha256 in its `conandata.yml`.

## Thread-local storage on armv7

Clang refuses `__thread` for armv7 iOS below a 9.0 deployment target, which is why TDLib used to be
rewritten by hand. It is not rewritten any more. The recipe probes the real compiler, and where
`__thread` is genuinely unavailable it compiles TDLib against iOS 9.0 with `-femulated-tls`, links
compiler-rt's `__emutls_get_address`, and records iOS 6.0 in the Mach-O via the link flag. The
emitted code uses ordinary `__DATA` control structs and never touches dyld's TLV machinery, so it
runs on iOS 6. arm64 builds at 9.0 already, so it keeps real `__thread` and stays vanilla.

## When a build stops before it compiles anything

The armv7 profile takes its linker from `ld64@ios6/stable`, whose recipe asks for
`user.ios6:llvm_prefix`. That setting is not in this repository — it comes from the shared
ios6-toolchain config, which `conan config install` *copies* into `~/.conan2`. The copy and the
toolchain can therefore drift apart silently, and the first symptom is `conan install` failing with
`Invalid configuration: user.ios6:llvm_prefix does not name an LLVM` while building the linker.

    conan config show user.ios6:llvm_prefix

Empty means the home copy is stale; reinstall the toolchain config. To get one build through
without touching the machine's shared configuration, pass it for that invocation only — `-c:a`,
not `-c`, because the linker is a `tool_requires` and so is built in the build context:

    conan install packaging/deps -pr:h ios6-armv7 -pr:b default --build=missing \
        -c:a user.ios6:llvm_prefix="$(brew --prefix llvm)"

## Bumping one

Edit the version and the `commit` in that recipe's `conandata.yml`, then build both architectures:

    conan create packaging/<name> -pr:h ios6-armv7 -pr:h packaging/profiles/cxx-stdlib -pr:b default --build=missing
    conan create packaging/<name> -pr:h packaging/profiles/arm64 -pr:h packaging/profiles/cxx-stdlib -pr:b default --build=missing

Then rebuild the app and compare the new library's exported and undefined symbols against the
previous build's before trusting it; a bump that compiles can still have dropped a symbol.

## libtgvoip's patch

`packaging/libtgvoip/patches/ios6.patch` carries this port's changes to 48 upstream files (custom
crypto hooks, echo canceller and input/output volume effects, callback audio I/O, the VideoToolbox
paths). `packaging/libtgvoip/port/` holds the four things upstream never had — `TGVP8Codec`,
`TGCallVideoSource`, `TGCallVideoRenderer`, `TGVTDynamic` — plus the `config.h` that upstream
generates with autotools and this port does not run.

To refresh the patch after changing that source, apply it to a clean checkout of the pinned commit,
edit there, and regenerate with `git diff`.

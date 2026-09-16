# Dependencies

No third-party source is stored in this repository. Every dependency is fetched from its own
upstream by the Conan recipe in `recipes/<name>/all`, built into the Conan cache, and resolved by
`charon build` through this folder, which `charon setup` registers as the `itglegacy` index. What
is tracked here is each recipe, its `conandata.yml` pin and, where one is unavoidable, its patch.

Every library follows its newest upstream. A commit that is not a release is versioned the way
`git describe` names it, `<last tag>+<commits since>.g<sha>`, so version checks in CMake and
pkg-config still compare correctly and the version names the commit.

| Recipe | Upstream | Pinned to | Built by |
|---|---|---|---|
| `tdlib` | github.com/tdlib/td | `master` (1.8.67) | its CMake project |
| `openssl` | github.com/openssl/openssl | `openssl-4.0.2`, the newest release | its `Configure` (`ios-xcrun`, `ios64-xcrun`) |
| `libtgvoip` | github.com/telegramdesktop/libtgvoip | `tdesktop` head, the line Telegram ships for 2.4.4 calls | its source list |
| `libvpx` | github.com/webmproject/libvpx | `main` | its `configure` |
| `opus` | github.com/xiph/opus | `main` | its CMake project |
| `opusfile` | github.com/xiph/opusfile | `main` | its CMake project |
| `libopusenc` | github.com/xiph/libopusenc | `master` | its autotools project |
| `ogg` | github.com/xiph/ogg | `main` | its CMake project |
| `webp` | chromium.googlesource.com/webm/libwebp | `main` | its CMake project |
| `quirc` | github.com/dlbeer/quirc | `master` | its Makefile |
| `qrcodegen` | github.com/nayuki/QR-Code-generator | `master` | its Makefile, archived with the platform's `ar` |

The C++ runtime, the SDK, the armv7 linker and `ldid` are the `apple-ios` platform's packages
(`libcxx`, `iphoneos-sdk`, `ld64`, `ldid`, all `@charon/stable`). libc++ is the newest release; the
`aligned_alloc` its runtime calls unconditionally since 22.1, and which iOS below 13 does not have,
comes from the platform's `apple-compat` layer, hidden inside the runtime. libvpx's encoder timer
takes `clock_gettime` from the same layer. TDLib links every call the layer provides for the target:
`clock_gettime` and `fdopendir`, which its source calls unconditionally, and `__sincos_stret`,
`__strlcpy_chk` and `__strlcat_chk`, which exist only from iOS 7 and which the compiler and the SDK's
fortify headers emit because TDLib compiles against iOS 9.0 for its thread-local storage.

## What is carried, and why

Each of these was checked against a flag or an upstream option first; none exists.

- **`openssl`: `patches/arm-xlate-ios32-hidden-extern-data.patch`.** Since 3.1.3 the armv4 perlasm
  modules reach `OPENSSL_armcap_P` through `.word OPENSSL_armcap_P-.Lblock`, a subtraction from an
  undefined symbol that 32-bit ARM Mach-O cannot relocate, so every one of them fails to assemble
  for armv7 iOS (openssl/openssl#26510). The patch makes the translator give a hidden external data
  symbol a local `.data` word holding its address on the `ios32` flavour only; every other flavour's
  output is byte-identical. Submitted upstream as openssl/openssl#32856.
- **`openssl`: `-DBROKEN_CLANG_ATOMICS` on armv7.** OpenSSL's own switch; without it clang emits
  calls to out-of-line atomic helpers that a static iOS 6 link does not have.
- **`libtgvoip`: `-includealgorithm`.** `Buffers.h` calls `std::fill` without including
  `<algorithm>`, which libc++ 23 headers no longer pull in transitively. The header is forced in on
  the command line rather than patched into the source, for the library's own build and, through the
  package's `cxxflags`, for every C++ file that includes `Buffers.h` through its public headers.
  Submitted upstream as telegramdesktop/libtgvoip#39.
- **`tdlib`: `patches/voip-primary-socket-callback.patch`.** Hands the app the file descriptor of
  TDLib's main primary connection, which iOS 6's VoIP background mode needs marked. TDLib has no API
  for it, and an in-process proxy could not tell that connection apart from the others to the same
  data centre.
- **`tdlib`: emulated thread-local storage.** Clang refuses `__thread` below iOS 9.0 on both armv7
  and arm64, even with `-femulated-tls`. The recipe probes the compiler and, where it is refused,
  compiles against iOS 9.0 with `-femulated-tls` and links at the real minimum, which the Mach-O
  records. `__emutls_get_address` comes from the compiler's own runtime, `libclang_rt.ios.a`, which
  the driver links anyway, so no compiler-rt source is fetched.

## Bumping one

Move `commit` and the version in that recipe's `conandata.yml` and `config.yml`, keep both files in
the form `yaml.safe_dump` writes (the index rewrites anything else and the revision changes), then
build both architectures with the platform's profiles:

    conan create recipes/<name>/all --version <version> -pr:h apple-ios-armv7 -pr:b default --build="<name>/*" --build=missing
    conan create recipes/<name>/all --version <version> -pr:h apple-ios-armv8 -pr:b default --build="<name>/*" --build=missing

`--build="<name>/*"` matters when only the toolchain changed: a tool requirement is not part of a
package id, so `--build=missing` alone reuses the old binary. Then run `charon build`, whose checks
refuse any object recording a minimum other than the profile's and any bundled binary that loads a
library the bundle carries from somewhere else.

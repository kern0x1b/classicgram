set_project("itglegacy")
set_version("1.0.2")
set_policy("package.requires_lock", true)
set_policy("package.librarydeps.strict_compatibility", true)

add_repositories("charon https://github.com/kern0x1b/charon.git main")
add_addons("charon v0.4.1")
set_config("apple_minimum", "6.0")
includes("@addon/charon/apple-ios")

set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7", "iphoneos|arm64")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

local function revision(value)
    add_configs("revision", {description = "Raised whenever this package script changes, so the change rebuilds it.", default = value, type = "string", readonly = true})
end

package("ogg")
    set_homepage("https://github.com/xiph/ogg")
    set_description("libogg, the Ogg container format library, built by its own CMake project")
    set_license("BSD-3-Clause")
    revision("2")
    add_urls("https://github.com/xiph/ogg.git")
    add_versions("1.3.6+7.g06a5e02", "06a5e0262cdc28aa4ae6797627a783b5010440f0")
    add_deps("cmake", "ninja", {kind = "binary"})
    on_install("iphoneos", function (package)
        import("@addon.charon.apple.cmake").install(package, {
            "-DBUILD_TESTING=OFF",
            "-DINSTALL_DOCS=OFF",
            "-DINSTALL_PKG_CONFIG_MODULE=ON",
            "-DINSTALL_CMAKE_PACKAGE_MODULE=ON",
        }, {prune = {"share"}, licenses = {"COPYING"}})
    end)
    on_test(function (package)
        assert(package:has_cfuncs("ogg_sync_init", {includes = "ogg/ogg.h"}))
    end)
package_end()

package("opus")
    set_homepage("https://opus-codec.org")
    set_description("libopus, the Opus audio codec, built by its own CMake project")
    set_license("BSD-3-Clause")
    revision("2")
    add_urls("https://github.com/xiph/opus.git")
    add_versions("1.6.1+68.g503d81b", "503d81b138d76621aae4b12786e90de48aa8db3a")
    add_deps("cmake", "ninja", {kind = "binary"})
    add_includedirs("include", "include/opus")
    on_install("iphoneos", function (package)
        import("@addon.charon.apple.cmake").install(package, {
            "-DBUILD_TESTING=OFF",
            "-DOPUS_BUILD_SHARED_LIBRARY=OFF",
            "-DOPUS_BUILD_TESTING=OFF",
            "-DOPUS_BUILD_PROGRAMS=OFF",
            "-DOPUS_INSTALL_PKG_CONFIG_MODULE=ON",
            "-DOPUS_INSTALL_CMAKE_CONFIG_MODULE=ON",
        }, {prune = {"share"}, licenses = {"COPYING"}})
    end)
    on_test(function (package)
        assert(package:has_cfuncs("opus_encoder_create", {includes = "opus.h"}))
    end)
package_end()

package("opusfile")
    set_homepage("https://opus-codec.org")
    set_description("libopusfile, reading Ogg Opus files, built by its own CMake project without HTTP")
    set_license("BSD-3-Clause")
    revision("2")
    add_urls("https://github.com/xiph/opusfile.git")
    add_versions("0.12+59.g6dfd29e", "6dfd29e7adb87f2e193575fc3fa88cbf1a0b27df")
    add_deps("cmake", "ninja", {kind = "binary"})
    add_deps("ogg", "opus")
    add_includedirs("include", "include/opus")
    on_install("iphoneos", function (package)
        import("@addon.charon.apple.cmake").install(package, {
            "-DBUILD_TESTING=OFF",
            "-DOP_DISABLE_HTTP=ON",
            "-DOP_DISABLE_EXAMPLES=ON",
            "-DOP_DISABLE_DOCS=ON",
        }, {prune = {"share", "lib/cmake", "lib/pkgconfig"}, licenses = {"COPYING"}})
    end)
    on_test(function (package)
        assert(package:has_cfuncs("op_open_memory", {includes = "opusfile.h"}))
    end)
package_end()

package("webp")
    set_homepage("https://developers.google.com/speed/webp")
    set_description("libwebp's decoding and encoding libraries, built by its own CMake project without its tools")
    set_license("BSD-3-Clause")
    revision("2")
    add_urls("https://chromium.googlesource.com/webm/libwebp.git")
    add_versions("1.6.0+258.g6ff2f43", "6ff2f43acb05d4c78b3eebe4956e4afd22f14452")
    add_deps("cmake", "ninja", {kind = "binary"})
    add_links("webpdemux", "webpdecoder", "webp", "sharpyuv")
    on_install("iphoneos", function (package)
        local configs = {"-DWEBP_LINK_STATIC=ON"}
        for _, tool in ipairs({"ANIM_UTILS", "CWEBP", "DWEBP", "GIF2WEBP", "IMG2WEBP", "VWEBP", "WEBPINFO", "LIBWEBPMUX", "WEBPMUX", "EXTRAS", "FUZZTEST"}) do
            table.insert(configs, "-DWEBP_BUILD_" .. tool .. "=OFF")
        end
        import("@addon.charon.apple.cmake").install(package, configs, {prune = {"share", "lib/cmake", "lib/pkgconfig"}, licenses = {"COPYING"}})
    end)
    on_test(function (package)
        assert(package:has_cfuncs("WebPDecodeRGBA", {includes = "webp/decode.h"}))
    end)
package_end()

package("libvpx")
    set_homepage("https://chromium.googlesource.com/webm/libvpx")
    set_description("libvpx, a VP8-only realtime build through its own configure")
    set_license("BSD-3-Clause")
    revision("5")
    add_urls("https://github.com/webmproject/libvpx.git")
    add_versions("1.17.0+60.gfcc9ba8", "fcc9ba864d5540a94c6dceb859c35d42dfddf50b")
    add_deps("charon@apple-compat", {alias = "apple-compat"})
    add_links("vpx")
    local targets = {armv7 = "armv7-darwin-gcc", arm64 = "arm64-darwin-gcc"}
    on_install("iphoneos", function (package)
        local target = targets[package:arch()]
        if not target then
            raise("libvpx has no configure target for %s", package:arch())
        end
        local envs = import("@addon.charon.apple.envs").build(package, import("package.tools.autoconf").buildenvs(package))
        local toolchain = package:toolchains()[1]
        toolchain:load()
        local extra = table.join({"-miphoneos-version-min=" .. toolchain:config("deployment")},
            import("@addon.charon.apple.compat").force_includes(package:dep("apple-compat"), {"clock_gettime"}))
        os.tryrm("build_charon")
        os.mkdir("build_charon")
        os.cd("build_charon")
        os.vrunv("../configure", {"--target=" .. target, "--extra-cflags=" .. table.concat(extra, " "),
            "--enable-neon", "--enable-static", "--disable-shared",
            "--disable-examples", "--disable-tools", "--disable-docs", "--disable-unit-tests",
            "--disable-vp9", "--enable-vp8", "--enable-realtime-only", "--disable-runtime-cpu-detect"}, {envs = envs})
        os.vrunv("make", {"-j" .. os.cpuinfo("ncpu"), "libvpx.a"}, {envs = envs})
        os.cp("libvpx.a", package:installdir("lib") .. "/")
        os.cp("vpx_version.h", package:installdir("include/vpx") .. "/")
        os.cd("..")
        os.cp("vpx/*.h", package:installdir("include/vpx") .. "/")
        import("@addon.charon.apple.install").finish(package, {licenses = {"LICENSE", "PATENTS"}})
    end)
    on_test(function (package)
        assert(package:has_cfuncs("vpx_codec_version", {includes = "vpx/vpx_codec.h"}))
    end)
package_end()

package("libopusenc")
    set_homepage("https://opus-codec.org")
    set_description("libopusenc, writing Ogg Opus files, built by its own autotools project")
    set_license("BSD-3-Clause")
    revision("3")
    add_urls("https://github.com/xiph/libopusenc.git")
    add_versions("0.3+14.g3c65f44", "3c65f440baff6220872ec11b0cbde37ef7a48f78")
    add_deps("autoconf", "automake", "libtool", "pkgconf", {kind = "binary"})
    add_deps("opus")
    add_includedirs("include", "include/opus")
    on_install("iphoneos", function (package)
        local autoconf = import("package.tools.autoconf")
        local envs = import("@addon.charon.apple.envs").build(package, autoconf.buildenvs(package))
        envs.PKG_CONFIG = path.join(package:dep("pkgconf"):installdir("bin"), "pkgconf")
        autoconf.install(package, {"--enable-static", "--disable-shared", "--disable-examples", "--disable-doc"}, {envs = envs})
        import("@addon.charon.apple.install").finish(package, {prune = {"lib/*.la", "lib/pkgconfig", "share"}, licenses = {"COPYING"}})
    end)
    on_test(function (package)
        assert(package:has_cfuncs("ope_comments_create", {includes = "opusenc.h"}))
    end)
package_end()

package("libtgvoip")
    set_homepage("https://github.com/telegramdesktop/libtgvoip")
    set_description("libtgvoip from Telegram Desktop's tdesktop branch, the line Telegram ships for 2.4.4 calls, compiled from its own source list against libc++ 23")
    set_license("Unlicense")
    revision("2")
    add_urls("https://github.com/telegramdesktop/libtgvoip.git")
    add_versions("2.4.4+124.g2d25928", "2d2592860478e60d972b96e67ee034b8a71bb57a")
    add_deps("opus")
    add_deps("charon@libcxx", {alias = "libcxx"})
    add_includedirs("include", "include/libtgvoip")
    add_links("tgvoip")
    add_defines("TGVOIP_NO_DSP", "WEBRTC_POSIX", "TGVOIP_USE_CUSTOM_CRYPTO")
    add_cxxflags("-includealgorithm")
    add_mxxflags("-includealgorithm")
    on_install("iphoneos", function (package)
        local cxx = {"-std=c++14", "-includealgorithm"}
        import("@addon.charon.apple.sources").static(package, {
            name = "tgvoip",
            files = {
                "VoIPController.cpp", "VoIPServerConfig.cpp", "logging.cpp", "json11.cpp",
                "video/ScreamCongestionController.cpp", "JitterBuffer.cpp", "OpusEncoder.cpp", "OpusDecoder.cpp",
                "NetworkSocket.cpp", "CongestionControl.cpp", "EchoCanceller.cpp", "MessageThread.cpp",
                "Buffers.cpp", "BlockingQueue.cpp", "MediaStreamItf.cpp", "PacketReassembler.cpp",
                "audio/AudioIO.cpp", "audio/AudioInput.cpp", "audio/AudioOutput.cpp", "audio/Resampler.cpp",
                "os/darwin/AudioUnitIO.cpp", "os/darwin/AudioInputAudioUnit.cpp",
                "os/darwin/AudioOutputAudioUnit.cpp", "os/posix/NetworkSocketPosix.cpp",
                "os/darwin/DarwinSpecific.mm"
            },
            includedirs = {".", path.join(package:dep("opus"):installdir("include"), "opus")},
            defines = {"TGVOIP_NO_DSP", "WEBRTC_POSIX", "TGVOIP_USE_CUSTOM_CRYPTO"},
            cxxflags = cxx,
            mxxflags = table.join(cxx, {"-fobjc-arc"}),
            deps = {"opus", "libcxx"},
            headers = {"**.h|webrtc_dsp/**|client/**|os/android/**|os/linux/**|os/windows/**|build_charon/**"},
            headers_prefix = "libtgvoip",
            licenses = {"UNLICENSE"}
        })
    end)
package_end()

package("tdlib")
    set_homepage("https://github.com/tdlib/td")
    set_description("TDLib's libtdjson, fetched vanilla from upstream with this port's backgrounded VoIP socket hook as a patch, built by its own CMake project with emulated thread-local storage wherever the target compiler lacks real __thread")
    set_license("BSL-1.0")
    revision("5")
    add_urls("https://github.com/tdlib/td.git")
    add_versions("1.8.67", "d1085f9cebc5a62379991ae1652673954f229c1f")
    add_patches("1.8.67", path.join(os.scriptdir(), "patches", "tdlib", "voip-primary-socket-callback.patch"), "95a9228262968a9861ebf5b95449497f4f22e7c2ea24fc903bd3b07464223440")
    add_configs("shared", {description = "libtdjson is always the dylib the application bundles.", default = true, type = "boolean", readonly = true})
    add_deps("cmake", "ninja", "gperf", {kind = "binary"})
    add_deps("charon@openssl", {alias = "openssl"})
    add_deps("charon@libcxx", {alias = "libcxx"})
    add_deps("charon@apple-compat", {alias = "apple-compat"})
    add_links("tdjson")
    on_install("iphoneos", function (package)
        local cmake = import("@addon.charon.apple.cmake")
        local toolchain = cmake.toolchain(package)
        local root = os.curdir()
        if not os.isdir("native-build") then
            os.mkdir("native-build")
            os.vrunv("cmake", {"-DTD_GENERATE_SOURCE_FILES=ON", root}, {curdir = path.join(root, "native-build")})
            os.vrunv("cmake", {"--build", ".", "--target", "prepare_cross_compiling"}, {curdir = path.join(root, "native-build")})
        end
        local shims = import("@addon.charon.apple.compat").force_includes(package:dep("apple-compat"), {"clock_gettime", "fdopendir"})
        local opt = {cflags = table.copy(shims), cxxflags = table.copy(shims), deps = {"libcxx", "apple-compat"}, targets = {"tdjson"}, install = false}
        local probe = path.join(root, "build_charon_tls_probe.cpp")
        io.writefile(probe, "static __thread int x;\nint main() { x = 1; return x; }\n")
        local real_thread_local = try { function ()
            os.vrunv("xcrun", {"clang++", "-target", package:arch() .. "-apple-ios", "-miphoneos-version-min=" .. toolchain:config("deployment"),
                               "-isysroot", toolchain:config("sdkdir"), "-fsyntax-only", probe})
            return true
        end }
        if not real_thread_local then
            print("no real __thread at iOS %s: compiling against iOS 9.0 with -femulated-tls, taking __emutls_get_address from the compiler's own runtime and recording iOS %s in the Mach-O", toolchain:config("deployment"), toolchain:config("deployment"))
            table.insert(opt.cflags, "-femulated-tls")
            table.insert(opt.cxxflags, "-femulated-tls")
            opt.compile_deployment = "9.0"
        end
        os.tryrm("build_charon")
        local openssl = package:dep("openssl")
        local builddir = cmake.install(package, {
            "-DBUILD_SHARED_LIBS=ON",
            "-DTD_ENABLE_LTO=OFF",
            "-DCMAKE_BUILD_TYPE=RelWithDebInfo",
            "-DCMAKE_C_FLAGS_RELWITHDEBINFO=-Os -g -DNDEBUG",
            "-DCMAKE_CXX_FLAGS_RELWITHDEBINFO=-Os -g -DNDEBUG",
            "-DOPENSSL_INCLUDE_DIR=" .. openssl:installdir("include"),
            "-DOPENSSL_CRYPTO_LIBRARY=" .. path.join(openssl:installdir("lib"), "libcrypto.a"),
            "-DOPENSSL_SSL_LIBRARY=" .. path.join(openssl:installdir("lib"), "libssl.a"),
        }, opt)
        local built
        for _, file in ipairs(table.join(os.files(path.join(builddir, "libtdjson*.dylib")), os.files(path.join(builddir, "**", "libtdjson*.dylib")))) do
            if not os.islink(file) then
                built = file
            end
        end
        assert(built, "the build produced no libtdjson dylib")
        local dylib = path.join(package:installdir("lib"), "libtdjson.dylib")
        os.cp(built, dylib)
        os.vrunv("xcrun", {"install_name_tool", "-id", "@rpath/libtdjson.dylib", dylib})
        os.cp("td/telegram/*.h", package:installdir("include/td/telegram") .. "/")
        os.cp("td/generate/scheme/td_api.tl", package:installdir("res") .. "/")
        import("@addon.charon.apple.install").finish(package, {licenses = {"LICENSE_1_0.txt"}})
    end)
package_end()

package("quirc")
    set_homepage("https://github.com/dlbeer/quirc")
    set_description("quirc, a QR-code recognition library, built by its own Makefile")
    set_license("ISC")
    revision("2")
    add_urls("https://github.com/dlbeer/quirc.git")
    add_versions("1.2+7.g927d680", "927d680904dc95fdff4cd9d022eb374b438ff8f2")
    on_install(function (package)
        import("package.tools.make").build(package, {"libquirc.a", "SDL_CFLAGS=", "OPENCV_CFLAGS="})
        os.cp("libquirc.a", package:installdir("lib"))
        os.cp("lib/quirc.h", package:installdir("include"))
        import("@addon.charon.apple.install").finish(package, {licenses = {"LICENSE"}})
    end)
    on_test(function (package)
        assert(package:has_cfuncs("quirc_new", {includes = "quirc.h"}))
    end)
package_end()

package("qrcodegen")
    set_homepage("https://github.com/nayuki/QR-Code-generator")
    set_description("Project Nayuki's QR Code generator, its C library, compiled by its own Makefile and archived")
    set_license("MIT")
    revision("1")
    add_urls("https://github.com/nayuki/QR-Code-generator.git")
    add_versions("1.8.0+31.g3c6d0b3", "3c6d0b3cefb4e049dc337e82237c9644399716a8")
    on_install(function (package)
        local root = os.curdir()
        os.cd("c")
        import("package.tools.make").build(package, {"qrcodegen.o"})
        os.vrunv("ar", {"rcs", "libqrcodegen.a", "qrcodegen.o"})
        os.cp("libqrcodegen.a", package:installdir("lib"))
        os.cp("qrcodegen.h", package:installdir("include"))
        local readme = io.readfile(path.join(root, "Readme.markdown"))
        io.writefile(path.join(package:installdir("licenses"), "LICENSE"), readme:sub(readme:find("License\n-------", 1, true)))
    end)
    on_test(function (package)
        assert(package:has_cfuncs("qrcodegen_encodeText", {includes = "qrcodegen.h"}))
    end)
package_end()

local dependencies = {
    {"ogg", "1.3.6+7.g06a5e02"},
    {"opus", "1.6.1+68.g503d81b"},
    {"opusfile", "0.12+59.g6dfd29e"},
    {"libopusenc", "0.3+14.g3c65f44"},
    {"webp", "1.6.0+258.g6ff2f43"},
    {"libvpx", "1.17.0+60.gfcc9ba8"},
    {"libtgvoip", "2.4.4+124.g2d25928"},
    {"tdlib", "1.8.67"},
    {"quirc", "1.2+7.g927d680"},
    {"qrcodegen", "1.8.0+31.g3c6d0b3"},
    {"openssl", "4.0.2", "charon@"},
    {"libcxx", "23.1.1", "charon@"},
}

local packages = {}
for _, dependency in ipairs(dependencies) do
    add_requires((dependency[3] or "") .. dependency[1] .. " " .. dependency[2], {alias = dependency[1]})
    table.insert(packages, dependency[1])
end

local function source_include_dirs()
    local skipped = {"src/Resources/images", "src/Resources/AppIcon", "src/Resources/Localization"}
    local dirs = {}
    for _, dir in ipairs(os.dirs(path.join(os.scriptdir(), "src", "**"))) do
        local relative = path.relative(dir, os.scriptdir())
        local keep = relative ~= "src/Resources"
        for _, prefix in ipairs(skipped) do
            if relative == prefix or relative:startswith(prefix .. "/") then
                keep = false
            end
        end
        if keep then
            table.insert(dirs, relative)
        end
    end
    table.sort(dirs)
    return dirs
end

local function telegram_application(harness)
    add_rules("@addon/charon/app")
    set_basename("Telegram")
    if harness then
        set_default(false)
        set_targetdir("$(builddir)/harness")
        add_files("src/**.m|Resources/**|App/AppDelegate+I18nDump.m", "src/**.c|Resources/**", "src/**.mm|Resources/**")
        add_values("app.resources", "src/Resources/CustomKeys.txt")
    else
        add_values("apple.architectures", "armv7", "arm64")
        add_files("src/**.m|Resources/**|App/AppDelegate+DebugHarness.m|App/AppDelegate+I18nDump.m", "src/**.c|Resources/**", "src/**.mm|Resources/**")
        set_values("charon.control", "packaging/control")
        add_values("charon.licenses", "LICENSE", "NOTICE")
    end
    add_includedirs(source_include_dirs())
    local common = {"-O2", "-fPIC", "-fno-modules", "-Wall", "-Wconditional-uninitialized", "-Wunreachable-code", "-Wno-macro-redefined", "-Wno-deprecated-declarations", "-Wno-error"}
    add_cxflags(table.unpack(common))
    add_mxflags(table.unpack(table.join(common, {"-Wobjc-missing-super-calls", "-fobjc-arc"})))
    add_mxxflags("-fno-cxx-modules", "-std=c++14")
    add_ldflags("-Wl,-dead_strip", "-nostdlib++", "-ObjC")
    add_frameworks("UIKit", "Foundation", "CoreGraphics", "QuartzCore", "AudioToolbox", "AVFoundation", "CoreMedia", "CoreVideo", "AddressBook", "AddressBookUI", "MobileCoreServices", "CoreTelephony", "ImageIO", "CoreText", "CFNetwork", "SystemConfiguration", "Security", "MapKit", "CoreLocation")
    add_syslinks("z", "pthread")
    add_packages(table.unpack(packages))
    set_values("app.plist-file", "src/Resources/Info.plist")
    add_values("app.resources", "src/Resources/images", "src/Resources/Localization", "src/Resources/AppIcon")
    add_values("app.frameworks", "libcxx", "tdlib")
    set_values("charon.entitlements", "src/Resources/entitlements.plist")
    set_values("charon.strip", "-S -x")
    on_config(function (target)
        if not os.isfile(path.join(os.projectdir(), "src", "Resources", "Config", "tg_config.h")) then
            raise("src/Resources/Config/tg_config.h is missing: copy src/Resources/Config/tg_config.h.example to it and fill in the API credentials, or run scripts/worktree-prepare.sh in a worktree")
        end
    end)
end

target("Telegram")
    telegram_application(false)
target_end()

target("Telegram-harness")
    telegram_application(true)
target_end()

target("TelegramSystemCall")
    add_rules("@addon/charon/tweak")
    add_files("tweaks/system-call/src/TSCTweak.m")
    add_frameworks("Foundation")
    add_mflags("-O2", "-Wall", "-Wextra", "-Wno-unused-parameter", "-Wno-deprecated-declarations", "-fobjc-exceptions")
    set_values("tweak.filter", "tweaks/system-call/packaging/TelegramSystemCall.plist")
    set_values("charon.control", "tweaks/system-call/packaging/control")
    set_values("charon.version", "1.0")
    set_values("charon.maintainer-scripts", "tweaks/system-call/packaging/DEBIAN")
    after_link(function (target)
        local linked = os.iorunv("xcrun", {"otool", "-L", target:targetfile()})
        if linked:find("UIKit") or linked:find("substrate") then
            raise("TelegramSystemCall links UIKit or substrate, and SpringBoard loads it before either is safe to bind")
        end
    end)
target_end()

target("telegramd")
    add_rules("@addon/charon/daemon")
    add_files("daemon/relaunch/src/telegramd.c")
    add_frameworks("CoreFoundation")
    add_cflags("-Os", "-Wall", "-Wextra")
    set_values("charon.entitlements", "daemon/relaunch/entitlements.plist")
    add_installfiles("daemon/relaunch/com.kern0x1b.telegramd.plist", {prefixdir = "Library/LaunchDaemons"})
    add_installfiles("daemon/relaunch/telegramd.conf", {prefixdir = "etc"})
    set_values("charon.control", "daemon/relaunch/packaging/control")
    set_values("charon.version", "1.0")
    set_values("charon.maintainer-scripts", "daemon/relaunch/packaging/DEBIAN")
target_end()

target("sbdriver")
    add_rules("@addon/charon/tweak")
    set_default(false)
    set_values("charon.install", "/tmp")
    add_files("tools/device/sbdriver.m")
    add_frameworks("Foundation", "UIKit", "CoreGraphics")
    add_mflags("-O2", "-fno-objc-arc", "-fobjc-exceptions")
target_end()

target("screenshot")
    add_rules("@addon/charon/daemon")
    set_default(false)
    set_values("charon.install", "/tmp")
    add_files("tools/device/screenshot.m")
    add_frameworks("Foundation", "UIKit", "CoreGraphics")
    add_mflags("-fobjc-arc")
target_end()

local sources = {"src/**.m", "src/**.mm", "src/**.h", "src/**.c"}
local implementation = {"src/**.m", "src/**.mm"}
local headers_and_implementation = {"src/**.m", "src/**.mm", "src/**.h"}
local wire = {"src/TDLibClient/**.m", "src/TDLibClient/**.mm", "src/Wire/**.m", "src/Wire/**.mm"}
local english = "src/Resources/Localization/en.lproj/Localizable.strings"
local strings = "src/Resources/Localization/**.strings"

local function check(name, script, files, opt)
    opt = opt or {}
    target("check-" .. name)
        add_rules("@addon/charon/check")
        set_values("check.script", table.unpack(script))
        if #files > 0 then
            add_values("check.files", table.unpack(files))
        end
        if opt.pass_files then
            set_values("check.pass-files", true)
        end
        if opt.needs_files then
            set_values("check.needs-files", true)
        end
    target_end()
end

check("source-comments", {"scripts/lint-source-comments.py", "--check"}, {"**.m", "**.mm", "**.h", "**.c"}, {pass_files = true, needs_files = true})
check("sdk-ceiling", {"scripts/lint-sdk-ceiling.py"}, sources)
check("fallback-markdown", {"scripts/lint-fallback-markdown.py"}, sources)
check("strings-escapes", {"scripts/lint-strings-escapes.py"}, sources)
check("recursive-setters", {"scripts/lint-recursive-setters.py"}, sources)
check("layer-imports", {"scripts/lint-layer-imports.py", "--baseline-rank", "scripts/baselines/layer-rank.txt", "--baseline-screen-wall", "scripts/baselines/layer-screen-wall.txt", "--baseline-tdlib-schema", "scripts/baselines/tdlib-schema.txt"}, sources)
check("plural-keys", {"scripts/lint-plural-keys.py"}, table.join(implementation, {english}))
check("bare-ui-strings", {"scripts/lint-bare-ui-strings.py"}, table.join(implementation, {english}))
check("dead-client-api", {"scripts/lint-dead-client-api.py"}, {"src/TDLibClient/**.h", "src/TDLibClient/**.m"})
check("dead-declarations", {"scripts/lint-dead-declarations.py", "src"}, headers_and_implementation)
check("tdlib-type-names", {"scripts/lint-tdlib-type-names.py", "src"}, implementation)
check("tdlib-request-fields", {"scripts/lint-tdlib-request-fields.py"}, wire)
check("tdlib-int64-reads", {"scripts/lint-tdlib-int64-reads.py"}, wire)
check("topic-threading", {"scripts/lint-topic-threading.py", "src"}, wire)
check("english-fallbacks", {"scripts/lint-english-fallbacks.py", "src"}, {"src/Screens/**.m", "src/Screens/**.mm", "src/Views/**.m", "src/Views/**.mm", "src/App/**.m", "src/App/**.mm", "src/Companions/**.m", "src/Companions/**.mm"})
check("translation-placeholders", {"scripts/lint-translation-placeholders.py"}, table.join(implementation, {strings}))
check("fallback-drift", {"scripts/lint-fallback-drift.py", "src"}, table.join(headers_and_implementation, {strings}))
check("format-arguments", {"scripts/lint-format-arguments.py", "src"}, table.join(implementation, {strings}))
check("text-truncation", {"scripts/lint-text-truncation.py", "src"}, implementation)
check("navbar-buttons", {"scripts/lint-navbar-buttons.py", "src"}, implementation)
check("grouped-background", {"scripts/lint-grouped-background.py", "src"}, implementation)
check("row-colours", {"scripts/lint-row-colours.py", "src"}, implementation)
check("grouped-classes-self-test", {"scripts/tg_grouped_classes.py"}, {"scripts/tg_grouped_classes.py", "scripts/lint-grouped-*.py", "scripts/lint-centred-action-rows.py"})
check("grouped-row-font", {"scripts/lint-grouped-row-font.py", "src"}, implementation)
check("text-field-style", {"scripts/lint-text-field-style.py", "src"}, implementation)
check("screen-backgrounds", {"scripts/lint-screen-backgrounds.py", "src", "scripts/baselines/screen-backgrounds.txt"}, implementation)
check("unset-dictionary-keys", {"scripts/lint-unset-dictionary-keys.py", "src", "", "scripts/baselines/unset-dictionary-keys.txt"}, headers_and_implementation)
check("centred-action-rows", {"scripts/lint-centred-action-rows.py", "src"}, implementation)
check("destructive-rows", {"scripts/lint-destructive-rows.py", "src"}, implementation)
check("grouped-captions", {"scripts/lint-grouped-captions.py", "src"}, implementation)
check("caption-reads", {"scripts/lint-caption-reads.py", "src"}, implementation)
check("preview-tables", {"scripts/lint-preview-tables.py", "src"}, implementation)
check("date-formatting", {"scripts/lint-date-formatting.py", "src"}, implementation)
check("duplicate-selectors", {"scripts/lint-duplicate-selectors.py"}, {"src/**.m"})
check("duplicate-declarations", {"scripts/lint-duplicate-declarations.py"}, {"src/**.h"})
check("header-standalone", {"scripts/lint-header-standalone.sh"}, {"src/**.h"}, {pass_files = true, needs_files = true})
check("bubble-geometry", {"scripts/check-bubble-geometry.py", "--commit-gate"}, {"src/Screens/Chat/Cells/**.m", "src/Screens/Chat/Cells/**.h", "src/Views/Cells/TGBubbleCell.m", "src/Views/Cells/TGBubbleCell.h"}, {pass_files = true, needs_files = true})
check("image-scales", {"scripts/lint-image-scales.py"}, {"src/Resources/images/**.png"})
check("unused-strings", {"scripts/lint-unused-strings.py", "--missing-keys"}, {"src/**.m", english})

includes("tests")

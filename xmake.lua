set_project("itglegacy")
set_version("1.0.2")
set_policy("package.requires_lock", true)
set_policy("package.librarydeps.strict_compatibility", true)

add_repositories("charon https://github.com/kern0x1b/charon.git main")
add_addons("charon v0.3.0")
set_config("apple_minimum", "6.0")
includes("@addon/charon/apple-ios")

set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7", "iphoneos|arm64")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

package("ogg")
    set_homepage("https://github.com/xiph/ogg")
    set_description("libogg, the Ogg container format library, built by its own CMake project")
    set_license("BSD-3-Clause")
    add_configs("revision", {description = "Raised whenever this package script changes, so the change rebuilds it.", default = "1", type = "string", readonly = true})
    add_urls("https://github.com/xiph/ogg.git")
    add_versions("1.3.6+7.g06a5e02", "06a5e0262cdc28aa4ae6797627a783b5010440f0")
    add_deps("cmake", "ninja", {kind = "binary"})
    on_install("iphoneos", function (package)
        import("@addon.charon.apple.cmake").install(package, {
            "-DBUILD_TESTING=OFF",
            "-DINSTALL_DOCS=OFF",
            "-DINSTALL_PKG_CONFIG_MODULE=ON",
            "-DINSTALL_CMAKE_PACKAGE_MODULE=ON",
        })
        os.tryrm(package:installdir("share"))
        os.cp("COPYING", package:installdir("licenses") .. "/")
    end)
    on_test(function (package)
        assert(package:has_cfuncs("ogg_sync_init", {includes = "ogg/ogg.h"}))
    end)
package_end()

package("opus")
    set_homepage("https://opus-codec.org")
    set_description("libopus, the Opus audio codec, built by its own CMake project")
    set_license("BSD-3-Clause")
    add_configs("revision", {description = "Raised whenever this package script changes, so the change rebuilds it.", default = "1", type = "string", readonly = true})
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
        })
        os.tryrm(package:installdir("share"))
        os.cp("COPYING", package:installdir("licenses") .. "/")
    end)
    on_test(function (package)
        assert(package:has_cfuncs("opus_encoder_create", {includes = "opus.h"}))
    end)
package_end()

package("opusfile")
    set_homepage("https://opus-codec.org")
    set_description("libopusfile, reading Ogg Opus files, built by its own CMake project without HTTP")
    set_license("BSD-3-Clause")
    add_configs("revision", {description = "Raised whenever this package script changes, so the change rebuilds it.", default = "1", type = "string", readonly = true})
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
        })
        os.tryrm(package:installdir("lib/cmake"))
        os.tryrm(package:installdir("lib/pkgconfig"))
        os.tryrm(package:installdir("share"))
        os.cp("COPYING", package:installdir("licenses") .. "/")
    end)
    on_test(function (package)
        assert(package:has_cfuncs("op_open_memory", {includes = "opusfile.h"}))
    end)
package_end()

package("webp")
    set_homepage("https://developers.google.com/speed/webp")
    set_description("libwebp's decoding and encoding libraries, built by its own CMake project without its tools")
    set_license("BSD-3-Clause")
    add_configs("revision", {description = "Raised whenever this package script changes, so the change rebuilds it.", default = "1", type = "string", readonly = true})
    add_urls("https://chromium.googlesource.com/webm/libwebp.git")
    add_versions("1.6.0+258.g6ff2f43", "6ff2f43acb05d4c78b3eebe4956e4afd22f14452")
    add_deps("cmake", "ninja", {kind = "binary"})
    add_links("webpdemux", "webpdecoder", "webp", "sharpyuv")
    on_install("iphoneos", function (package)
        local tools = {"ANIM_UTILS", "CWEBP", "DWEBP", "GIF2WEBP", "IMG2WEBP", "VWEBP", "WEBPINFO", "LIBWEBPMUX", "WEBPMUX", "EXTRAS", "FUZZTEST"}
        local configs = {"-DWEBP_LINK_STATIC=ON"}
        for _, tool in ipairs(tools) do
            table.insert(configs, "-DWEBP_BUILD_" .. tool .. "=OFF")
        end
        import("@addon.charon.apple.cmake").install(package, configs)
        os.tryrm(package:installdir("lib/cmake"))
        os.tryrm(package:installdir("lib/pkgconfig"))
        os.tryrm(package:installdir("share"))
        os.cp("COPYING", package:installdir("licenses") .. "/")
    end)
    on_test(function (package)
        assert(package:has_cfuncs("WebPDecodeRGBA", {includes = "webp/decode.h"}))
    end)
package_end()

package("libvpx")
    set_homepage("https://chromium.googlesource.com/webm/libvpx")
    set_description("libvpx, a VP8-only realtime build through its own configure")
    set_license("BSD-3-Clause")
    add_configs("revision", {description = "Raised whenever this package script changes, so the change rebuilds it.", default = "2", type = "string", readonly = true})
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
        local envs = import("package.tools.autoconf").buildenvs(package)
        local compat = package:dep("apple-compat")
        local toolchain = package:toolchains()[1]
        toolchain:load()
        envs.IPHONEOS_DEPLOYMENT_TARGET = toolchain:config("deployment")
        local extra = {"-miphoneos-version-min=" .. toolchain:config("deployment")}
        table.join2(extra, import("@addon.charon.apple.compat").force_includes(compat, {"clock_gettime"}))
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
        os.cp("LICENSE", package:installdir("licenses") .. "/")
        os.cp("PATENTS", package:installdir("licenses") .. "/")
    end)
    on_test(function (package)
        assert(package:has_cfuncs("vpx_codec_version", {includes = "vpx/vpx_codec.h"}))
    end)
package_end()

package("libopusenc")
    set_homepage("https://opus-codec.org")
    set_description("libopusenc, writing Ogg Opus files, built by its own autotools project")
    set_license("BSD-3-Clause")
    add_configs("revision", {description = "Raised whenever this package script changes, so the change rebuilds it.", default = "1", type = "string", readonly = true})
    add_urls("https://github.com/xiph/libopusenc.git")
    add_versions("0.3+14.g3c65f44", "3c65f440baff6220872ec11b0cbde37ef7a48f78")
    add_deps("autoconf", "automake", "libtool", "pkg-config", {kind = "binary"})
    add_deps("opus")
    add_includedirs("include", "include/opus")
    on_install("iphoneos", function (package)
        os.vrunv("autoreconf", {"-fi"})
        import("package.tools.autoconf").install(package, {"--enable-static", "--disable-shared", "--disable-examples", "--disable-doc"})
        os.tryrm(package:installdir("lib/*.la"))
        os.tryrm(package:installdir("lib/pkgconfig"))
        os.tryrm(package:installdir("share"))
        os.cp("COPYING", package:installdir("licenses") .. "/")
    end)
    on_test(function (package)
        assert(package:has_cfuncs("ope_comments_create", {includes = "opusenc.h"}))
    end)
package_end()

package("libtgvoip")
    set_homepage("https://github.com/telegramdesktop/libtgvoip")
    set_description("libtgvoip from Telegram Desktop's tdesktop branch, the line Telegram ships for 2.4.4 calls, compiled from its own source list against libc++ 23")
    set_license("Unlicense")
    add_configs("revision", {description = "Raised whenever this package script changes, so the change rebuilds it.", default = "1", type = "string", readonly = true})
    add_urls("https://github.com/telegramdesktop/libtgvoip.git")
    add_versions("2.4.4+124.g2d25928", "2d2592860478e60d972b96e67ee034b8a71bb57a")
    add_deps("opus", "charon@libcxx")
    add_includedirs("include", "include/libtgvoip")
    add_links("tgvoip")
    add_cxxflags("-includealgorithm")
    add_mxxflags("-includealgorithm")
    local sources = {
        "VoIPController.cpp", "VoIPServerConfig.cpp", "logging.cpp", "json11.cpp",
        "video/ScreamCongestionController.cpp", "JitterBuffer.cpp", "OpusEncoder.cpp", "OpusDecoder.cpp",
        "NetworkSocket.cpp", "CongestionControl.cpp", "EchoCanceller.cpp", "MessageThread.cpp",
        "Buffers.cpp", "BlockingQueue.cpp", "MediaStreamItf.cpp", "PacketReassembler.cpp",
        "audio/AudioIO.cpp", "audio/AudioInput.cpp", "audio/AudioOutput.cpp", "audio/Resampler.cpp",
        "os/darwin/AudioUnitIO.cpp", "os/darwin/AudioInputAudioUnit.cpp",
        "os/darwin/AudioOutputAudioUnit.cpp", "os/posix/NetworkSocketPosix.cpp",
        "os/darwin/DarwinSpecific.mm"
    }
    on_install("iphoneos", function (package)
        local envs = import("package.tools.autoconf").buildenvs(package)
        local root = os.curdir()
        local flags = table.join(os.argv(envs.CXXFLAGS or ""), os.argv(envs.CPPFLAGS or ""), {
            "-std=c++14", "-includealgorithm", "-DTGVOIP_NO_DSP", "-DWEBRTC_POSIX", "-DTGVOIP_USE_CUSTOM_CRYPTO",
            "-I" .. root, "-I" .. path.join(package:dep("opus"):installdir("include"), "opus")})
        local objects = {}
        for _, source in ipairs(sources) do
            local object = path.join(root, "build_charon", source:gsub("/", "_") .. ".o")
            os.mkdir(path.directory(object))
            local language = source:endswith(".mm") and {"-fobjc-arc"} or {}
            os.vrunv(envs.CXX, table.join(flags, language, {"-c", path.join(root, source), "-o", object}), {envs = envs})
            table.insert(objects, object)
        end
        os.vrunv("ar", table.join({"rcs", package:installdir("lib") .. "/libtgvoip.a"}, objects))
        for _, header in ipairs(os.files("**.h|webrtc_dsp/**|client/**|os/android/**|os/linux/**|os/windows/**|build_charon/**")) do
            os.cp(header, path.join(package:installdir("include/libtgvoip"), header))
        end
        os.cp("UNLICENSE", package:installdir("licenses") .. "/")
    end)
package_end()

package("tdlib")
    set_homepage("https://github.com/tdlib/td")
    set_description("TDLib's libtdjson, fetched vanilla from upstream with this port's backgrounded VoIP socket hook as a patch, built by its own CMake project with emulated thread-local storage wherever the target compiler lacks real __thread")
    set_license("BSL-1.0")
    add_configs("revision", {description = "Raised whenever this package script changes, so the change rebuilds it.", default = "1", type = "string", readonly = true})
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
        local libcxx = package:dep("libcxx")
        local compat = package:dep("apple-compat")
        local openssl = package:dep("openssl")
        local cflags = import("@addon.charon.apple.compat").force_includes(compat, {"clock_gettime", "fdopendir"})
        local cxxflags = table.join(cflags, {"-nostdinc++", "-isystem", path.join(libcxx:installdir("include"), "c++", "v1"), "-D_LIBCPP_DISABLE_AVAILABILITY"})
        local shflags = {"-nostdlib++", "-L" .. libcxx:installdir("lib"), "-lc++", "-lc++abi"}
        if os.isfile(path.join(compat:installdir("lib"), "libapple-compat.a")) then
            table.join2(shflags, {"-L" .. compat:installdir("lib"), "-lapple-compat"})
        end
        local opt = {cflags = cflags, cxxflags = cxxflags, shflags = shflags, targets = {"tdjson"}, install = false}
        local probe = path.join(root, "build_charon_tls_probe.cpp")
        io.writefile(probe, "static __thread int x;\nint main() { x = 1; return x; }\n")
        local ok = try { function ()
            os.vrunv("xcrun", {"clang++", "-target", package:arch() .. "-apple-ios", "-miphoneos-version-min=" .. toolchain:config("deployment"),
                               "-isysroot", toolchain:config("sdkdir"), "-fsyntax-only", probe})
            return true
        end }
        if not ok then
            print("no real __thread at iOS %s: compiling against iOS 9.0 with -femulated-tls, taking __emutls_get_address from the compiler's own runtime and recording iOS %s in the Mach-O", toolchain:config("deployment"), toolchain:config("deployment"))
            table.insert(opt.cflags, "-femulated-tls")
            table.insert(opt.cxxflags, "-femulated-tls")
            opt.compile_deployment = "9.0"
        end
        os.tryrm("build_charon")
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
        local built_dir = builddir or "build_charon"
        for _, file in ipairs(table.join(os.files(path.join(built_dir, "libtdjson*.dylib")), os.files(path.join(built_dir, "**", "libtdjson*.dylib")))) do
            if not os.islink(file) then
                built = file
            end
        end
        assert(built, "the build produced no libtdjson dylib")
        os.cp(built, path.join(package:installdir("lib"), "libtdjson.dylib"))
        os.cp("td/telegram/*.h", package:installdir("include/td/telegram") .. "/")
        os.cp("td/generate/scheme/td_api.tl", package:installdir("res") .. "/")
        os.cp("LICENSE_1_0.txt", package:installdir("licenses") .. "/")
    end)
package_end()

package("quirc")
    set_homepage("https://github.com/dlbeer/quirc")
    set_description("quirc, a QR-code recognition library, built by its own Makefile")
    set_license("ISC")
    add_configs("revision", {description = "Raised whenever this package script changes, so the change rebuilds it.", default = "1", type = "string", readonly = true})
    add_urls("https://github.com/dlbeer/quirc.git")
    add_versions("1.2+7.g927d680", "927d680904dc95fdff4cd9d022eb374b438ff8f2")
    on_install(function (package)
        import("package.tools.make").build(package, {"libquirc.a", "SDL_CFLAGS=", "OPENCV_CFLAGS="})
        os.cp("libquirc.a", package:installdir("lib"))
        os.cp("lib/quirc.h", package:installdir("include"))
        os.cp("LICENSE", package:installdir("licenses"))
    end)
    on_test(function (package)
        assert(package:has_cfuncs("quirc_new", {includes = "quirc.h"}))
    end)
package_end()

package("qrcodegen")
    set_homepage("https://github.com/nayuki/QR-Code-generator")
    set_description("Project Nayuki's QR Code generator, its C library, compiled by its own Makefile and archived")
    set_license("MIT")
    add_configs("revision", {description = "Raised whenever this package script changes, so the change rebuilds it.", default = "1", type = "string", readonly = true})
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

add_requires("ogg 1.3.6+7.g06a5e02", "opus 1.6.1+68.g503d81b", "opusfile 0.12+59.g6dfd29e", "libopusenc 0.3+14.g3c65f44", "webp 1.6.0+258.g6ff2f43", "libvpx 1.17.0+60.gfcc9ba8", "libtgvoip 2.4.4+124.g2d25928", "tdlib 1.8.67", "quirc 1.2+7.g927d680", "qrcodegen 1.8.0+31.g3c6d0b3")
add_requires("charon@openssl 4.0.2", {alias = "openssl"})

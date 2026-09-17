set_project("itglegacy")
set_version("1.0.2")
set_policy("package.requires_lock", true)
set_policy("package.librarydeps.strict_compatibility", true)

add_repositories("charon https://github.com/kern0x1b/charon.git main")
add_addons("charon v0.7.1")
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
    set_description("libvpx through its own configure: VP8 both ways for calls, and the VP9 decoder video stickers need")
    set_license("BSD-3-Clause")
    revision("6")
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
            "--enable-vp8", "--enable-vp9-decoder", "--disable-vp9-encoder", "--enable-realtime-only", "--disable-runtime-cpu-detect"}, {envs = envs})
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

package("libwebm")
    set_homepage("https://github.com/webmproject/libwebm")
    set_description("libwebm's webm_parser, the callback parser that surfaces BlockAdditions, where a WebM video carries its VP9 alpha channel")
    set_license("BSD-3-Clause")
    revision("1")
    add_urls("https://github.com/webmproject/libwebm.git")
    add_versions("1.0.0.32+7.g6184f44", "6184f4484a826724b5293837134ab9492261b941")
    add_deps("charon@libcxx", {alias = "libcxx"})
    add_links("webm")
    on_install("iphoneos", function (package)
        import("@addon.charon.apple.sources").static(package, {
            name = "webm",
            files = {"webm_parser/src/*.cc"},
            includedirs = {".", "webm_parser", "webm_parser/include"},
            flags = {"-Os"},
            cxxflags = {"-std=c++17"},
            deps = {"libcxx"},
            licenses = {"LICENSE.TXT", "PATENTS.TXT"}
        })
        os.cp("webm_parser/include/webm", package:installdir("include") .. "/")
    end)
package_end()

package("libyuv")
    set_homepage("https://chromium.googlesource.com/libyuv/libyuv")
    set_description("libyuv, Chromium's colour conversion and scaling library, with the NEON rows for the architecture being built; on arm64 the dot-product kernels get their own archive and flags, as upstream's CMake builds them, and are chosen at run time")
    set_license("BSD-3-Clause")
    revision("2")
    add_urls("https://chromium.googlesource.com/libyuv/libyuv.git")
    add_versions("1971+2dd4257", "2dd4257364d39c38d79465c4ddc4b93137fe729b")
    add_deps("charon@libcxx", {alias = "libcxx"})
    on_load(function (package)
        package:add("links", "yuv")
        if package:arch() == "arm64" then
            package:add("links", "yuv_neon64")
        end
    end)
    on_install("iphoneos", function (package)
        local arch = package:arch()
        if arch ~= "armv7" and arch ~= "arm64" then
            raise("libyuv has no NEON rows for %s", arch)
        end
        local defines = {"LIBYUV_DISABLE_SVE", "LIBYUV_DISABLE_SME"}
        local sources = import("@addon.charon.apple.sources")
        local common = {
            name = "yuv",
            files = {"source/*.cc|*_gcc.cc|*_win.cc|*_msa.cc|*_lsx.cc|*_lasx.cc|*_rvv.cc|*_sve.cc|*_sme.cc|*_neon.cc|*_neon64.cc|mjpeg_*.cc|convert_jpeg.cc"},
            includedirs = {"include"},
            defines = defines,
            flags = {"-O2"},
            cxxflags = {"-std=c++17"},
            deps = {"libcxx"},
            headers = {"include/**.h"},
            licenses = {"LICENSE", "PATENTS"}
        }
        if arch == "armv7" then
            table.insert(common.files, "source/*_neon.cc")
            table.insert(common.defines, "LIBYUV_NEON")
            table.insert(common.flags, "-mfpu=neon")
            sources.static(package, common)
        else
            sources.static(package, common)
            sources.static(package, {
                name = "yuv_neon64",
                files = {"source/*_neon64.cc"},
                includedirs = {"include"},
                defines = defines,
                flags = {"-O2", "-march=armv8.2-a+dotprod+i8mm"},
                cxxflags = {"-std=c++17"},
                deps = {"libcxx"}
            })
        end
        os.mv(path.join(package:installdir("include"), "include", "*"), package:installdir("include") .. "/")
        os.rm(path.join(package:installdir("include"), "include"))
    end)
    on_test(function (package)
        assert(package:check_cxxsnippets({test = "void test() { auto convert = &libyuv::I420AlphaToARGB; (void)convert; }"}, {includes = "libyuv.h"}))
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

package("tgcalls")
    set_homepage("https://github.com/TelegramMessenger/tgcalls")
    set_description("tgcalls, the engine behind Telegram's one-to-one calls, at the commit Telegram-iOS pins, on the WebRTC of Telegram Desktop's tg_owt, compiled from its own source list into one archive")
    set_license("LGPL-3.0")
    revision("2")
    add_urls("https://github.com/TelegramMessenger/tgcalls.git")
    add_versions("2026.6.15+e306932", "e3069322a3d1e16ecb11a5e302242e59ddd7f09e")
    add_patches("2026.6.15+e306932", path.join(os.scriptdir(), "patches", "tgcalls", "audio-session-on-ios-6.patch"), "f457021a627703851a451efd33e3991abcaa3a7ee3a786860aec1033cd059a8b")
    add_deps("opus", "libvpx")
    add_deps("charon@openssl", {alias = "openssl"})
    add_deps("charon@libcxx", {alias = "libcxx"})
    add_links("tgcalls")
    add_includedirs("include", "include/tgcalls", "include/webrtc", "include/webrtc/third_party/abseil-cpp", "include/webrtc/third_party/libyuv/include", "include/webrtc/sdk/objc", "include/webrtc/sdk/objc/base")
    add_frameworks("AVFoundation", "AudioToolbox", "CoreAudio", "UIKit", "Security", "SystemConfiguration", "CFNetwork")
    add_syslinks("z")
    local defines = {"WEBRTC_POSIX", "WEBRTC_MAC", "WEBRTC_IOS", "WEBRTC_ENABLE_PROTOBUF=0", "WEBRTC_APM_DEBUG_DUMP=0", "WEBRTC_LIBRARY_IMPL",
        "WEBRTC_NON_STATIC_TRACE_EVENT_HANDLERS=1", "RTC_DISABLE_TRACE_EVENTS", "BWE_TEST_LOGGING_COMPILE_TIME_ENABLE=0", "HAVE_SCTP", "ABSL_ALLOCATOR_NOTHROW=1",
        "WEBRTC_USE_BUILTIN_ISAC_FLOAT", "WEBRTC_INCLUDE_INTERNAL_AUDIO_DEVICE", "WEBRTC_HAVE_DCSCTP", "WEBRTC_HAVE_SCTP", "NO_MAIN_THREAD_WRAPPING",
        "HAVE_WEBRTC_VIDEO", "PFFFT_SIMD_DISABLE", "WEBRTC_DUMMY_AUDIO_BUILD", "WEBRTC_OPUS_VARIABLE_COMPLEXITY=0", "WEBRTC_OPUS_SUPPORT_120MS_PTIME=1", "WEBRTC_HAS_NEON"}
    local arch_defines = {armv7 = {"WEBRTC_ARCH_ARM", "WEBRTC_ARCH_ARM_V7", "LIBYUV_NEON"}, arm64 = {"WEBRTC_ARCH_ARM64"}}
    on_load(function (package)
        package:add("defines", table.unpack(table.join(defines, arch_defines[package:arch()] or {})))
    end)
    on_install("iphoneos", function (package)
        local arch = package:arch()
        if not arch_defines[arch] then
            raise("tgcalls has no WebRTC configuration for %s", arch)
        end
        os.tryrm("tg_owt")
        os.tryrm("gen")
        os.mkdir("gen/experiments")
        os.mkdir("gen/crc32c")
        os.vrunv("git", {"clone", "--no-checkout", "--filter=blob:none", "https://github.com/desktop-app/tg_owt.git", "tg_owt"})
        os.vrunv("git", {"-C", "tg_owt", "checkout", "19d51d3c19632a63fdbe17c62f10332d978cb940"})
        os.vrunv("git", {"-C", "tg_owt", "submodule", "update", "--init", "--depth", "1"})
        os.vrunv("python3", {"tg_owt/src/experiments/field_trials.py", "header", "--output", "gen/experiments/registered_field_trials.h"})
        io.writefile("gen/crc32c/crc32c_config.h", table.concat({"#ifndef CRC32C_CRC32C_CONFIG_H_", "#define CRC32C_CRC32C_CONFIG_H_",
            "#define BYTE_ORDER_BIG_ENDIAN 0", "#define HAVE_BUILTIN_PREFETCH 1", "#define HAVE_MM_PREFETCH 0", "#define HAVE_SSE42 0",
            "#define HAVE_ARM64_CRC32C 0", "#define HAVE_STRONG_GETAUXVAL 0", "#define HAVE_WEAK_GETAUXVAL 0",
            "#define CRC32C_TESTS_BUILT_WITH_GLOG 0", "#endif", ""}, "\n"))
        local tests = "*_unittest*|*_test.*|*_tests.*|*test_*|*mock*|*fuzz*|*benchmark*|*_perftest*|*integrationtest*|*loopback*"
        local files = {}
        for _, pattern in ipairs({
            "api/*.cc|wrapping_async_dns_resolver.cc", "api/adaptation/*.cc", "api/audio/*.cc|echo_detector_creator.cc", "api/audio_codecs/*.cc",
            "api/audio_codecs/L16/*.cc", "api/audio_codecs/g711/*.cc", "api/audio_codecs/g722/*.cc", "api/audio_codecs/ilbc/*.cc",
            "api/audio_codecs/opus/*.cc", "api/call/*.cc", "api/crypto/*.cc", "api/environment/*.cc", "api/neteq/*.cc", "api/numerics/*.cc",
            "api/rtc_event_log/*.cc", "api/task_queue/default_task_queue_factory_stdlib.cc", "api/task_queue/pending_task_safety_flag.cc",
            "api/task_queue/task_queue_base.cc", "api/transport/*.cc", "api/transport/rtp/*.cc", "api/units/*.cc", "api/video/*.cc",
            "api/video_codecs/*.cc|spatial_layer.cc", "audio/*.cc", "audio/utility/*.cc", "audio/voip/audio_egress.cc", "call/*.cc",
            "call/adaptation/*.cc", "common_audio/*.c", "common_audio/*.cc|fir_filter_avx2.cc|fir_filter_sse.cc",
            "common_audio/resampler/*.cc|sinc_resampler_avx2.cc|sinc_resampler_sse.cc",
            "common_audio/signal_processing/*.c|complex_bit_reverse_mips.c|complex_fft_mips.c|cross_correlation_mips.c|downsample_fast_mips.c|filter_ar_fast_q12_mips.c|min_max_operations_mips.c|resample_by_2_mips.c|vector_scaling_operations_mips.c",
            "common_audio/signal_processing/*.cc", "common_audio/third_party/ooura/fft_size_128/ooura_fft.cc",
            "common_audio/third_party/ooura/fft_size_128/ooura_fft_neon.cc", "common_audio/third_party/ooura/fft_size_256/*.cc",
            "common_audio/third_party/spl_sqrt_floor/spl_sqrt_floor.c", "common_audio/vad/*.c", "common_audio/vad/*.cc", "common_video/*.cc",
            "common_video/generic_frame_descriptor/*.cc", "common_video/h264/*.cc", "common_video/h265/*.cc", "common_video/libyuv/*.cc",
            "logging/rtc_event_log/ice_logger.cc", "logging/rtc_event_log/rtc_stream_config.cc",
            "logging/rtc_event_log/encoder/*.cc|rtc_event_log_encoder_legacy.cc|rtc_event_log_encoder_new_format.cc",
            "logging/rtc_event_log/events/*.cc|rtc_event_frame_decoded.cc",
            "media/base/*.cc|fake_frame_source.cc|fake_media_engine.cc|fake_rtp.cc|fake_video_renderer.cc",
            "media/engine/*.cc|fake_video_codec_factory.cc|fake_webrtc_call.cc|fake_webrtc_video_engine.cc", "media/sctp/*.cc",
            "modules/async_audio_processing/*.cc", "modules/audio_coding/acm2/*.cc",
            "modules/audio_coding/audio_network_adaptor/*.cc|frame_length_controller_v2.cc", "modules/audio_coding/codecs/*.cc",
            "modules/audio_coding/codecs/cng/*.cc", "modules/audio_coding/codecs/g711/*.c", "modules/audio_coding/codecs/g711/*.cc",
            "modules/audio_coding/codecs/g722/*.c", "modules/audio_coding/codecs/g722/*.cc", "modules/audio_coding/codecs/ilbc/*.c",
            "modules/audio_coding/codecs/ilbc/*.cc", "modules/audio_coding/codecs/isac/main/source/*.c", "modules/audio_coding/codecs/opus/*.cc",
            "modules/audio_coding/codecs/pcm16b/*.c", "modules/audio_coding/codecs/pcm16b/*.cc", "modules/audio_coding/codecs/red/*.cc",
            "modules/audio_coding/neteq/*.cc", "modules/audio_device/*.cc", "modules/audio_device/dummy/*.cc|file_audio_device_factory.cc",
            "modules/audio_mixer/*.cc", "modules/audio_processing/*.cc",
            "modules/audio_processing/aec3/*.cc|adaptive_fir_filter_avx2.cc|adaptive_fir_filter_erl_avx2.cc|fft_data_avx2.cc|matched_filter_avx2.cc|vector_math_avx2.cc",
            "modules/audio_processing/aec_dump/null_aec_dump_factory.cc", "modules/audio_processing/aecm/*.cc|aecm_core_mips.cc",
            "modules/audio_processing/agc/*.cc", "modules/audio_processing/agc/legacy/*.cc", "modules/audio_processing/agc2/*.cc",
            "modules/audio_processing/agc2/rnn_vad/*.cc|rnn_vad_tool.cc|vector_math_avx2.cc",
            "modules/audio_processing/capture_levels_adjuster/*.cc", "modules/audio_processing/echo_detector/*.cc",
            "modules/audio_processing/include/*.cc", "modules/audio_processing/logging/*.cc", "modules/audio_processing/ns/*.cc",
            "modules/audio_processing/transient/*.cc|click_annotate.cc", "modules/audio_processing/utility/*.cc",
            "modules/audio_processing/vad/*.cc", "modules/congestion_controller/*.cc", "modules/congestion_controller/goog_cc/*.cc",
            "modules/congestion_controller/pcc/*.cc", "modules/congestion_controller/rtp/*.cc", "modules/pacing/*.cc",
            "modules/remote_bitrate_estimator/*.cc", "modules/rtp_rtcp/include/*.cc",
            "modules/rtp_rtcp/source/*.cc|rtcp_transceiver.cc|rtcp_transceiver_config.cc|rtcp_transceiver_impl.cc",
            "modules/rtp_rtcp/source/deprecated/*.cc", "modules/rtp_rtcp/source/rtcp_packet/*.cc", "modules/third_party/fft/*.c",
            "modules/third_party/g711/*.c", "modules/third_party/g722/*.c", "modules/third_party/portaudio/*.c",
            "modules/video_capture/*.cc|video_capture_factory_null.cc", "modules/video_coding/*.cc|video_coding_impl.cc|video_receiver.cc",
            "modules/video_coding/codecs/av1/av1_svc_config.cc", "modules/video_coding/codecs/h264/h264.cc",
            "modules/video_coding/codecs/interface/*.cc", "modules/video_coding/codecs/multiplex/*.cc", "modules/video_coding/codecs/vp8/*.cc",
            "modules/video_coding/codecs/vp9/*.cc", "modules/video_coding/deprecated/*.cc", "modules/video_coding/include/*.cc",
            "modules/video_coding/svc/*.cc", "modules/video_coding/timing/*.cc", "modules/video_coding/utility/*.cc", "net/dcsctp/packet/*.cc",
            "net/dcsctp/packet/chunk/*.cc", "net/dcsctp/packet/error_cause/*.cc", "net/dcsctp/packet/parameter/*.cc", "net/dcsctp/public/*.cc",
            "net/dcsctp/rx/*.cc|reassembly_streams.cc", "net/dcsctp/socket/*.cc", "net/dcsctp/timer/*.cc", "net/dcsctp/tx/*.cc", "p2p/base/*.cc",
            "p2p/client/*.cc", "p2p/stunprober/*.cc", "pc/*.cc|peer_connection_wrapper.cc",
            "rtc_base/*.cc|boringssl_certificate.cc|boringssl_identity.cc|cpu_time.cc|fake_clock.cc|fake_ssl_identity.cc|firewall_socket_server.cc|ifaddrs_android.cc|log_sinks.cc|memory_stream.cc|memory_usage.cc|nat_server.cc|nat_socket_factory.cc|nat_types.cc|network_monitor_factory.cc|proxy_server.cc|server_socket_adapters.cc|socket_stream.cc|task_queue_gcd.cc|task_queue_libevent.cc|task_queue_win.cc|virtual_socket_server.cc|win32.cc",
            "rtc_base/containers/*.cc", "rtc_base/deprecated/*.cc", "rtc_base/experiments/*.cc", "rtc_base/internal/*.cc", "rtc_base/memory/*.cc",
            "rtc_base/network/*.cc", "rtc_base/numerics/*.cc", "rtc_base/strings/*.cc|json.cc", "rtc_base/synchronization/*.cc",
            "rtc_base/system/file_wrapper.cc", "rtc_base/system/*.mm", "rtc_base/task_utils/*.cc", "rtc_base/third_party/base64/*.cc",
            "rtc_base/third_party/sigslot/*.cc", "sdk/*.cc", "sdk/objc/base/RTCLogging.mm", "sdk/objc/native/src/audio/helpers.mm", "stats/*.cc",
            "system_wrappers/source/*.cc|cpu_features_android.cc|cpu_features_linux.cc", "third_party/abseil-cpp/absl/base/internal/raw_logging.cc",
            "third_party/abseil-cpp/absl/base/internal/throw_delegate.cc", "third_party/abseil-cpp/absl/numeric/*.cc",
            "third_party/abseil-cpp/absl/strings/*.cc|cord_analysis.cc|cord_buffer.cc",
            "third_party/abseil-cpp/absl/strings/internal/charconv_bigint.cc", "third_party/abseil-cpp/absl/strings/internal/charconv_parse.cc",
            "third_party/abseil-cpp/absl/strings/internal/escaping.cc", "third_party/abseil-cpp/absl/strings/internal/memutil.cc",
            "third_party/abseil-cpp/absl/strings/internal/ostringstream.cc", "third_party/abseil-cpp/absl/strings/internal/pow10_helper.cc",
            "third_party/abseil-cpp/absl/strings/internal/utf8.cc", "third_party/abseil-cpp/absl/strings/internal/str_format/*.cc",
            "third_party/abseil-cpp/absl/types/*.cc|bad_any_cast.cc", "third_party/crc32c/src/src/crc32c.cc",
            "third_party/crc32c/src/src/crc32c_portable.cc", "third_party/libsrtp/crypto/cipher/aes_gcm_ossl.c",
            "third_party/libsrtp/crypto/cipher/aes_icm_ossl.c", "third_party/libsrtp/crypto/cipher/cipher.c",
            "third_party/libsrtp/crypto/cipher/cipher_test_cases.c", "third_party/libsrtp/crypto/cipher/null_cipher.c",
            "third_party/libsrtp/crypto/hash/auth.c", "third_party/libsrtp/crypto/hash/auth_test_cases.c",
            "third_party/libsrtp/crypto/hash/hmac_ossl.c", "third_party/libsrtp/crypto/hash/null_auth.c", "third_party/libsrtp/crypto/kernel/*.c",
            "third_party/libsrtp/crypto/math/*.c", "third_party/libsrtp/crypto/replay/*.c", "third_party/libsrtp/srtp/*.c",
            "third_party/libyuv/source/*.cc|*_gcc.cc|*_msa.cc|*_win.cc|*_lsx.cc|*_lasx.cc|*_rvv.cc|*_neon.cc|*_neon64.cc|scale_rgb.cc",
            "third_party/pffft/src/*.c", "third_party/rnnoise/src/*.cc", "video/*.cc|video_analyzer.cc", "video/adaptation/*.cc",
            "video/config/*.cc", "video/render/*.cc",
            arch == "arm64" and "third_party/libyuv/source/*_neon64.cc" or "third_party/libyuv/source/*_neon.cc"}) do
            table.insert(files, "tg_owt/src/" .. pattern .. (pattern:find("*", 1, true) and "|" .. tests or ""))
        end
        for _, pattern in ipairs({"tgcalls/*.cpp", "tgcalls/platform/darwin/iOS/*.mm", "tgcalls/third-party/*.cpp", "tgcalls/utils/*.cpp", "tgcalls/v2/*.cpp"}) do
            table.insert(files, pattern)
        end
        local webrtc = "tg_owt/src"
        local cxx = {"-std=c++20", "-Wno-deprecated-declarations", "-Wno-deprecated-volatile", "-Wno-deprecated-anon-enum-enum-conversion"}
        import("@addon.charon.apple.sources").static(package, {
            name = "tgcalls",
            files = files,
            includedirs = {".", "tgcalls", "tgcalls/platform/darwin/iOS", "gen", webrtc, webrtc .. "/third_party/abseil-cpp",
                webrtc .. "/third_party/libyuv/include", webrtc .. "/third_party/libsrtp/include", webrtc .. "/third_party/libsrtp/crypto/include",
                webrtc .. "/third_party/libsrtp_config", webrtc .. "/third_party/crc32c/src/include", webrtc .. "/sdk/objc", webrtc .. "/sdk/objc/base",
                path.join(package:dep("opus"):installdir("include"), "opus")},
            defines = table.join(defines, arch_defines[arch], {"NDEBUG", "HAVE_CONFIG_H", "HAVE_NETINET_IN_H", "_USE_MATH_DEFINES"}),
            flags = table.join({"-Os"}, arch == "armv7" and {"-mfpu=neon"} or {}),
            cxxflags = cxx,
            mxxflags = table.join(cxx, {"-fobjc-arc"}),
            mflags = {"-fobjc-arc"},
            deps = {"opus", "libvpx", "openssl", "libcxx"},
            licenses = {"LICENSE"}
        })
        for _, header in ipairs(table.join(os.files(path.join(webrtc, "**.h")), os.files(path.join(webrtc, "**.inc")))) do
            local destination = path.join(package:installdir("include", "webrtc"), path.relative(header, webrtc))
            os.mkdir(path.directory(destination))
            os.cp(header, destination)
        end
        for _, header in ipairs(os.files("tgcalls/**.h")) do
            local destination = path.join(package:installdir("include"), header)
            os.mkdir(path.directory(destination))
            os.cp(header, destination)
        end
        os.cp("gen/experiments", package:installdir("include", "experiments"))
        os.cp("tg_owt/LICENSE", path.join(package:installdir("licenses"), "WebRTC-LICENSE"))
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
    {"libwebm", "1.0.0.32+7.g6184f44"},
    {"libyuv", "1971+2dd4257"},
    {"tdlib", "1.8.67"},
    {"quirc", "1.2+7.g927d680"},
    {"qrcodegen", "1.8.0+31.g3c6d0b3"},
    {"openssl", "4.0.2", "charon@"},
    {"libcxx", "23.1.1", "charon@"},
}

add_requires("tgcalls 2026.6.15+e306932", {alias = "tgcalls"})

local packages = {}
for _, dependency in ipairs(dependencies) do
    add_requires((dependency[3] or "") .. dependency[1] .. " " .. dependency[2], {alias = dependency[1]})
    table.insert(packages, dependency[1])
end

local function source_include_dirs()
    local skipped = {"src/Resources/images", "src/Resources/AppIcon", "src/Resources/Localization", "src/CallsEngine"}
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

target("TGCallsEngine")
    add_rules("@addon/charon/library")
    set_license("GPL-3.0")
    set_policy("check.target_package_licenses", false)
    add_files("src/CallsEngine/*.mm")
    add_includedirs("src/CallsEngine", "src/Calls")
    add_packages("tgcalls", "opus", "libvpx", "openssl", "libcxx")
    set_languages("cxx20")
    add_mxxflags("-Os", "-fPIC", "-fobjc-arc", "-fvisibility=hidden", "-fvisibility-inlines-hidden", "-Wall", "-Wno-deprecated-declarations")
    add_frameworks("Foundation", "UIKit", "AVFoundation", "AudioToolbox", "CoreAudio", "CoreVideo", "CoreMedia", "Security", "SystemConfiguration", "CFNetwork")
    add_syslinks("z")
    add_shflags("-Wl,-dead_strip", "-nostdlib++", "-Wl,-exported_symbol,_OBJC_CLASS_$_TGCallsEngineSession", "-Wl,-exported_symbol,_OBJC_METACLASS_$_TGCallsEngineSession", {force = true})
target_end()

local function telegram_application(harness)
    add_rules("@addon/charon/app")
    set_basename("Telegram")
    if harness then
        set_default(false)
        set_targetdir("$(builddir)/harness")
        add_files("src/**.m|Resources/**|CallsEngine/**|App/AppDelegate+I18nDump.m", "src/**.c|Resources/**|CallsEngine/**", "src/**.mm|Resources/**|CallsEngine/**")
        add_values("app.resources", "src/Resources/CustomKeys.txt")
    else
        add_values("apple.architectures", "armv7", "arm64")
        add_files("src/**.m|Resources/**|CallsEngine/**|App/AppDelegate+DebugHarness.m|App/AppDelegate+I18nDump.m", "src/**.c|Resources/**|CallsEngine/**", "src/**.mm|Resources/**|CallsEngine/**")
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
    add_deps("TGCallsEngine", {inherit = false})
    add_values("app.frameworks", "libcxx", "tdlib", "TGCallsEngine")
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

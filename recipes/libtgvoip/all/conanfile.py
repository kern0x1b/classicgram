import os
import shutil

from conan import ConanFile
from conan.tools.apple import to_apple_arch
from conan.tools.files import copy
from conan.tools.scm import Git

_CPP_SOURCES = (
    "VoIPController.cpp", "VoIPServerConfig.cpp", "logging.cpp", "json11.cpp",
    "video/ScreamCongestionController.cpp", "JitterBuffer.cpp", "OpusEncoder.cpp", "OpusDecoder.cpp",
    "NetworkSocket.cpp", "CongestionControl.cpp", "EchoCanceller.cpp", "MessageThread.cpp",
    "Buffers.cpp", "BlockingQueue.cpp", "MediaStreamItf.cpp", "PacketReassembler.cpp",
    "audio/AudioIO.cpp", "audio/AudioInput.cpp", "audio/AudioOutput.cpp", "audio/Resampler.cpp",
    "os/darwin/AudioUnitIO.cpp", "os/darwin/AudioInputAudioUnit.cpp",
    "os/darwin/AudioOutputAudioUnit.cpp", "os/posix/NetworkSocketPosix.cpp",
)

_OBJCXX_SOURCES = ("os/darwin/DarwinSpecific.mm",)


_FORCED_INCLUDES = ("-includealgorithm",)


class LibtgvoipConan(ConanFile):
    name = "libtgvoip"
    user = "itglegacy"
    channel = "stable"
    package_type = "static-library"
    description = ("libtgvoip from Telegram Desktop's tdesktop branch, the line Telegram ships for 2.4.4 calls, "
                   "built unmodified, with <algorithm> force-included because Buffers.h uses std::fill without including it and libc++ 23 no longer reaches it transitively; the platform video source and renderer, whose VideoSource and "
                   "VideoRenderer members upstream only provides for iOS 8 and Android, come from the "
                   "application that links it")
    license = "Unlicense"
    homepage = "https://github.com/telegramdesktop/libtgvoip"

    python_requires = "charon-base/1.0@charon/stable", "charon-apple/1.0@charon/stable"
    python_requires_extend = "charon-base.CharonPort", "charon-apple.ApplePort"

    def requirements(self):
        self.requires("opus/1.6.1+68.g503d81b@itglegacy/stable", transitive_headers=True)
        self.requires("libcxx/23.1.1@charon/stable")

    def source(self):
        data = self.conan_data["sources"][self.version]
        Git(self).fetch_commit(url=data["url"], commit=data["commit"])

    def _libcxx(self):
        return self.dependencies["libcxx"].cpp_info.components

    def _libcxx_compile_flags(self):
        headers, runtime = self._libcxx()["headers"], self._libcxx()["runtime"]
        return " ".join([*headers.cxxflags, *(f'-isystem "{folder}"' for folder in headers.includedirs),
                         *(f"-D{define}" for define in runtime.defines)])

    def build(self):
        clangxx = shutil.which("clang++") or "/usr/bin/clang++"
        opus_include = os.path.join(self.dependencies["opus"].package_folder, "include", "opus")
        cxxflags = " ".join(self.conf.get("tools.build:cxxflags", default=[], check_type=list))
        common = (
            f'-arch {to_apple_arch(self)} -Os -isysroot "{self.sdk_path}" '
            f'-miphoneos-version-min={self.settings.os.version} -std=c++14 {" ".join(_FORCED_INCLUDES)} '
            f'-DTGVOIP_NO_DSP -DWEBRTC_POSIX -DTGVOIP_USE_CUSTOM_CRYPTO '
            f'-I "{self.source_folder}" -I "{opus_include}" {self._libcxx_compile_flags()} {cxxflags}'
        )
        objects = []
        for source, language in [(s, "") for s in _CPP_SOURCES] + [(s, "-fobjc-arc") for s in _OBJCXX_SOURCES]:
            obj = os.path.splitext(source.replace("/", "_"))[0] + ".o"
            objects.append(obj)
            self.run(f'"{clangxx}" {common} {language} -c "{os.path.join(self.source_folder, source)}" -o "{obj}"')
        self.run(f'ar rcs libtgvoip.a {" ".join(objects)}')

    def package(self):
        copy(self, "libtgvoip.a", self.build_folder, os.path.join(self.package_folder, "lib"), keep_path=False)
        copy(self, "*.h", self.source_folder, os.path.join(self.package_folder, "include", "libtgvoip"),
             excludes=("webrtc_dsp/*", "client/*", "os/android/*", "os/linux/*", "os/windows/*"))
        copy(self, "UNLICENSE", self.source_folder, os.path.join(self.package_folder, "licenses"))

    def package_info(self):
        self.cpp_info.libs = ["tgvoip"]
        self.cpp_info.requires = ["opus::opus", "libcxx::runtime"]
        self.cpp_info.cxxflags = list(_FORCED_INCLUDES)

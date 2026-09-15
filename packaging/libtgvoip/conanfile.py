import os
import shutil

from conan import ConanFile
from conan.errors import ConanException
from conan.tools.apple import to_apple_arch
from conan.tools.files import copy

_CPP_SOURCES = (
    "VoIPController.cpp", "VoIPServerConfig.cpp", "logging.cpp", "json11.cpp",
    "video/ScreamCongestionController.cpp", "video/VideoSource.cpp", "video/TGVP8Codec.cpp",
    "JitterBuffer.cpp", "OpusEncoder.cpp", "OpusDecoder.cpp", "NetworkSocket.cpp",
    "CongestionControl.cpp", "EchoCanceller.cpp", "MessageThread.cpp", "Buffers.cpp",
    "BlockingQueue.cpp", "MediaStreamItf.cpp", "PacketReassembler.cpp",
    "audio/AudioIO.cpp", "audio/AudioInput.cpp", "audio/AudioOutput.cpp", "audio/Resampler.cpp",
    "os/darwin/AudioUnitIO.cpp", "os/darwin/AudioInputAudioUnit.cpp",
    "os/darwin/AudioOutputAudioUnit.cpp", "os/posix/NetworkSocketPosix.cpp",
)

_OBJCXX_SOURCES = (
    "os/darwin/TGCallVideoSource.cpp", "os/darwin/TGCallVideoRenderer.cpp",
    "os/darwin/DarwinSpecific.mm", "os/darwin/TGVTDynamic.mm",
)


class LibtgvoipConan(ConanFile):
    name = "libtgvoip"
    user = "itglegacy"
    channel = "stable"
    version = "2.4.4-itglegacy"
    package_type = "static-library"
    description = ("Grishka's libtgvoip fork (VoIP transport) as vendored in this port - confirmed "
                   "byte-identical to upstream tag 2.4.4 for several files, but real local "
                   "modifications exist in others (custom crypto hooks, echo canceller and "
                   "output/input volume effects, callback audio I/O) plus wholly project-specific "
                   "files (TGCallVideoSource/Renderer, TGVP8Codec, TGVTDynamic) not in Grishka's "
                   "fork at all, so this packages the vendored tree as-is rather than re-fetching")
    license = "Unlicense"
    homepage = "https://github.com/grishka/libtgvoip"

    python_requires = "ios6-base/1.0@ios6/stable"
    python_requires_extend = "ios6-base.Ios6Port"

    exports_sources = "src/*", "compat/*"

    def requirements(self):
        self.requires("opus/1.3.1@itglegacy/stable")
        self.requires("libvpx/1.13.1@itglegacy/stable")

    def _apple_arch(self):
        return to_apple_arch(self)

    def _real_sdk_path(self):
        root = os.environ.get("ITGLEGACY_ROOT")
        if root:
            for sdk_name in ("iPhoneOS12.4.sdk", "iPhoneOS9.3.sdk"):
                candidate = os.path.join(root, "build", "sdks", sdk_name)
                if os.path.isdir(candidate):
                    return candidate
        sdk = self.conf.get("tools.apple:sdk_path")
        if not sdk or not os.path.isdir(sdk):
            raise ConanException(f"tools.apple:sdk_path does not point at a real SDK: {sdk!r}")
        return sdk

    def build(self):
        clangxx = shutil.which("clang++") or "/usr/bin/clang++"
        arch = self._apple_arch()
        sdk = self._real_sdk_path()
        min_version = str(self.settings.os.version)
        arch_flag = "-mthumb" if arch == "armv7" else ""
        opus_include = os.path.join(self.dependencies["opus"].package_folder, "include", "opus")
        vpx_include = os.path.join(self.dependencies["libvpx"].package_folder, "include")
        src_root = os.path.join(self.source_folder, "src")
        compat_include = os.path.join(self.source_folder, "compat")

        cxx_stdlib_inc = ""
        root = os.environ.get("ITGLEGACY_ROOT")
        if root:
            for sdk_name in ("iPhoneOS16.5.sdk", "iPhoneOS15.6.sdk"):
                candidate = os.path.join(root, "build", "sdks", sdk_name, "usr", "include", "c++", "v1")
                if os.path.isdir(candidate):
                    cxx_stdlib_inc = f"-isystem {candidate}"
                    break

        common = (
            f'-arch {arch} {arch_flag} -Os -isysroot "{sdk}" -miphoneos-version-min={min_version} '
            f'-DTGVOIP_NO_DSP -DWEBRTC_POSIX -DTGVOIP_USE_CUSTOM_CRYPTO '
            f'-I "{src_root}" -I "{opus_include}" -I "{vpx_include}" -I "{compat_include}" {cxx_stdlib_inc}'
        )

        objects = []
        for src in _CPP_SOURCES:
            obj = src.replace("/", "_").replace(".cpp", ".o")
            objects.append(obj)
            self.run(f'"{clangxx}" {common} -std=c++14 -fno-threadsafe-statics '
                     f'-c "{os.path.join(src_root, src)}" -o "{obj}"')
        for src in _OBJCXX_SOURCES:
            obj = src.replace("/", "_").replace(".mm", ".o").replace(".cpp", ".o")
            objects.append(obj)
            self.run(f'"{clangxx}" {common} -std=c++14 -fno-threadsafe-statics -fobjc-arc '
                     f'-c "{os.path.join(src_root, src)}" -o "{obj}"')

        self.run(f'ar rcs libtgvoip.a {" ".join(objects)}')

    def package(self):
        copy(self, "libtgvoip.a", self.build_folder, os.path.join(self.package_folder, "lib"), keep_path=False)
        copy(self, "*.h", os.path.join(self.source_folder, "src"),
             os.path.join(self.package_folder, "include", "libtgvoip"), keep_path=True)
        copy(self, "UNLICENSE", os.path.join(self.source_folder, "src"),
             os.path.join(self.package_folder, "licenses"))

    def package_info(self):
        self.cpp_info.libs = ["tgvoip"]
        self.cpp_info.frameworks = ["Foundation", "AudioToolbox", "AVFoundation", "VideoToolbox", "CoreMedia"]

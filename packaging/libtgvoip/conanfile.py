import os
import shutil

from conan import ConanFile
from conan.errors import ConanException
from conan.tools.apple import to_apple_arch
from conan.tools.files import apply_conandata_patches, copy
from conan.tools.scm import Git

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

_HEADER_DIRS = ("", "audio", "os/darwin", "os/posix", "video", "video/cm256")


class LibtgvoipConan(ConanFile):
    name = "libtgvoip"
    user = "itglegacy"
    channel = "stable"
    version = "2.4.4-itglegacy"
    package_type = "static-library"
    description = ("Grishka's libtgvoip, fetched vanilla at the newest upstream commit there is, "
                   "with this port's iOS 6 changes carried as a patch and the four "
                   "project-authored pieces upstream never had - TGVP8Codec, TGCallVideoSource, "
                   "TGCallVideoRenderer and TGVTDynamic")
    license = "Unlicense"
    homepage = "https://github.com/grishka/libtgvoip"

    python_requires = "ios6-base/1.0@ios6/stable"
    python_requires_extend = "ios6-base.Ios6Port"

    exports_sources = "port/*", "compat/*", "patches/*"

    def requirements(self):
        self.requires("opus/1.6.1@itglegacy/stable")
        self.requires("libvpx/1.16.0@itglegacy/stable")

    def source(self):
        source = self.conan_data["sources"]["libtgvoip"]
        Git(self).fetch_commit(url=source["url"], commit=source["commit"])
        apply_conandata_patches(self)
        copy(self, "*", os.path.join(self.source_folder, "port"), self.source_folder,
             keep_path=True)

    def _apple_arch(self):
        return to_apple_arch(self)

    def _real_sdk_path(self):
        sdk = self.conf.get("tools.apple:sdk_path")
        if not sdk or not os.path.isdir(sdk):
            raise ConanException(f"tools.apple:sdk_path does not point at a real SDK: {sdk!r}")
        return sdk

    def build(self):
        clang = shutil.which("clang") or "/usr/bin/clang"
        clangxx = shutil.which("clang++") or "/usr/bin/clang++"
        arch = self._apple_arch()
        sdk = self._real_sdk_path()
        min_version = str(self.settings.os.version)
        arch_flag = "-mthumb" if arch == "armv7" else ""
        opus_include = os.path.join(self.dependencies["opus"].package_folder, "include", "opus")
        vpx_include = os.path.join(self.dependencies["libvpx"].package_folder, "include")
        src_root = self.source_folder
        compat_root = os.path.join(self.source_folder, "compat")

        cxx_stdlib_inc = ""
        cxx_stdlib_dir = self.conf.get("user.itglegacy:cxx_stdlib_include")
        if cxx_stdlib_dir:
            cxx_stdlib_inc = f"-isystem {cxx_stdlib_dir}"

        common = (
            f'-arch {arch} {arch_flag} -Os -isysroot "{sdk}" -miphoneos-version-min={min_version} '
            f'-DTGVOIP_NO_DSP -DWEBRTC_POSIX -DTGVOIP_USE_CUSTOM_CRYPTO '
            f'-I "{src_root}" -I "{opus_include}" -I "{vpx_include}" -I "{compat_root}" {cxx_stdlib_inc}'
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

        self.run(f'"{clang}" -arch {arch} {arch_flag} -Os -isysroot "{sdk}" '
                 f'-miphoneos-version-min={min_version} '
                 f'-c "{os.path.join(compat_root, "darwin_check_fd_set_overflow.c")}" '
                 f'-o "darwin_check_fd_set_overflow.o"')
        objects.append("darwin_check_fd_set_overflow.o")

        self.run(f'ar rcs libtgvoip.a {" ".join(objects)}')

    def package(self):
        copy(self, "libtgvoip.a", self.build_folder,
             os.path.join(self.package_folder, "lib"), keep_path=False)
        include_root = os.path.join(self.package_folder, "include", "libtgvoip")
        for relative in _HEADER_DIRS:
            copy(self, "*.h", os.path.join(self.source_folder, relative),
                 os.path.join(include_root, relative), keep_path=False)
        copy(self, "UNLICENSE", self.source_folder,
             os.path.join(self.package_folder, "licenses"))

    def package_info(self):
        self.cpp_info.libs = ["tgvoip"]
        self.cpp_info.frameworks = ["Foundation", "AudioToolbox", "AVFoundation",
                                    "VideoToolbox", "CoreMedia"]

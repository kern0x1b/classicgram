import os
import shutil

from conan import ConanFile
from conan.errors import ConanException
from conan.tools.apple import to_apple_arch
from conan.tools.files import copy


class OpusencConan(ConanFile):
    name = "opusenc"
    user = "itglegacy"
    channel = "stable"
    version = "unpinned"
    package_type = "static-library"
    description = "The Ogg-Opus header serialization helper this port vendors - exact upstream commit unconfirmed"
    license = "BSD-3-Clause"
    homepage = "https://github.com/xiph/opus-tools"

    python_requires = "ios6-base/1.0@ios6/stable"
    python_requires_extend = "ios6-base.Ios6Port"

    exports_sources = "opusenc/*", "LICENSE"

    def requirements(self):
        self.requires("ogg/unpinned@itglegacy/stable")

    def _apple_arch(self):
        return to_apple_arch(self)

    def _real_sdk_path(self):
        sdk = self.conf.get("tools.apple:sdk_path")
        if not sdk or not os.path.isdir(sdk):
            raise ConanException(f"tools.apple:sdk_path does not point at a real SDK: {sdk!r}")
        return sdk

    def build(self):
        clang = shutil.which("clang") or "/usr/bin/clang"
        arch = self._apple_arch()
        sdk = self._real_sdk_path()
        min_version = str(self.settings.os.version)
        arch_flag = "-mthumb" if arch == "armv7" else ""
        ogg_include = os.path.join(self.dependencies["ogg"].package_folder, "include")

        self.run(
            f'"{clang}" -arch {arch} {arch_flag} -Os -isysroot "{sdk}" '
            f'-miphoneos-version-min={min_version} -I "{self.source_folder}" -I "{ogg_include}" '
            f'-c "{os.path.join(self.source_folder, "opusenc", "opus_header.c")}" -o "opus_header.o"'
        )
        self.run("ar rcs libopusenc.a opus_header.o")

    def package(self):
        copy(self, "libopusenc.a", self.build_folder, os.path.join(self.package_folder, "lib"), keep_path=False)
        copy(self, "*.h", os.path.join(self.source_folder, "opusenc"),
             os.path.join(self.package_folder, "include", "opusenc"), keep_path=False)
        copy(self, "LICENSE", self.source_folder, os.path.join(self.package_folder, "licenses"))

    def package_info(self):
        self.cpp_info.libs = ["opusenc"]
        self.cpp_info.includedirs = ["include", os.path.join("include", "opusenc")]

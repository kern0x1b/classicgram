import os
import shutil

from conan import ConanFile
from conan.errors import ConanException
from conan.tools.apple import to_apple_arch
from conan.tools.files import copy
from conan.tools.scm import Git


class OpusfileConan(ConanFile):
    name = "opusfile"
    user = "itglegacy"
    channel = "stable"
    version = "0.12"
    package_type = "static-library"
    description = "opusfile 0.12, fetched vanilla from upstream (file-based playback only, no HTTP)"
    license = "BSD-3-Clause"
    homepage = "https://github.com/xiph/opusfile"

    python_requires = "ios6-base/1.0@ios6/stable"
    python_requires_extend = "ios6-base.Ios6Port"

    _sources = ("internal.c", "opusfile.c", "info.c", "stream.c")

    def source(self):
        Git(self).fetch_commit(url="https://github.com/xiph/opusfile.git", commit="v0.12")

    def requirements(self):
        self.requires("ogg/1.3.6@itglegacy/stable")
        self.requires("opus/1.6.1@itglegacy/stable")

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
        opus_include = os.path.join(self.dependencies["opus"].package_folder, "include", "opus")
        src_dir = os.path.join(self.source_folder, "src")
        include_dir = os.path.join(self.source_folder, "include")

        objects = []
        for src in self._sources:
            obj = src.replace(".c", ".o")
            objects.append(obj)
            self.run(
                f'"{clang}" -arch {arch} {arch_flag} -Os -isysroot "{sdk}" '
                f'-miphoneos-version-min={min_version} '
                f'-I "{src_dir}" -I "{include_dir}" -I "{ogg_include}" -I "{opus_include}" '
                f'-c "{os.path.join(src_dir, src)}" -o "{obj}"'
            )
        self.run(f'ar rcs libopusfile.a {" ".join(objects)}')

    def package(self):
        copy(self, "libopusfile.a", self.build_folder, os.path.join(self.package_folder, "lib"), keep_path=False)
        copy(self, "*.h", os.path.join(self.source_folder, "include"),
             os.path.join(self.package_folder, "include", "opusfile"), keep_path=False)
        copy(self, "COPYING", self.source_folder, os.path.join(self.package_folder, "licenses"))

    def package_info(self):
        self.cpp_info.libs = ["opusfile"]

import os
import shutil

from conan import ConanFile
from conan.errors import ConanException
from conan.tools.apple import to_apple_arch
from conan.tools.files import copy


class QuircConan(ConanFile):
    name = "quirc"
    user = "itglegacy"
    channel = "stable"
    version = "unpinned"
    package_type = "static-library"
    description = "The QR-code decoder this port vendors - exact upstream commit unconfirmed"
    license = "ISC"
    homepage = "https://github.com/dlbeer/quirc"

    python_requires = "ios6-base/1.0@ios6/stable"
    python_requires_extend = "ios6-base.Ios6Port"

    exports_sources = "quirc/*", "LICENSE"

    _sources = ("quirc.c", "identify.c", "decode.c", "version_db.c")

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

        objects = []
        for src in self._sources:
            obj = src.replace(".c", ".o")
            objects.append(obj)
            self.run(
                f'"{clang}" -arch {arch} {arch_flag} -Os -isysroot "{sdk}" '
                f'-miphoneos-version-min={min_version} -I "{self.source_folder}" '
                f'-c "{os.path.join(self.source_folder, "quirc", src)}" -o "{obj}"'
            )
        self.run(f'ar rcs libquirc.a {" ".join(objects)}')

    def package(self):
        copy(self, "libquirc.a", self.build_folder, os.path.join(self.package_folder, "lib"), keep_path=False)
        copy(self, "*.h", os.path.join(self.source_folder, "quirc"),
             os.path.join(self.package_folder, "include", "quirc"), keep_path=False)
        copy(self, "LICENSE", self.source_folder, os.path.join(self.package_folder, "licenses"))

    def package_info(self):
        self.cpp_info.libs = ["quirc"]
        self.cpp_info.includedirs = ["include"]

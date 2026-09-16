import os
import shutil

from conan import ConanFile
from conan.errors import ConanException
from conan.tools.apple import to_apple_arch
from conan.tools.files import copy
from conan.tools.scm import Git

_QUIRC_COMMIT = "927d680904dc95fdff4cd9d022eb374b438ff8f2"


class QuircConan(ConanFile):
    name = "quirc"
    user = "itglegacy"
    channel = "stable"
    version = "1.2+git"
    package_type = "static-library"
    description = "The QR-code decoder, fetched vanilla from upstream at its latest commit (no newer tagged release exists past v1.2)"
    license = "ISC"
    homepage = "https://github.com/dlbeer/quirc"

    python_requires = "ios6-base/1.0@ios6/stable"
    python_requires_extend = "ios6-base.Ios6Port"

    _sources = ("quirc.c", "identify.c", "decode.c", "version_db.c")

    def source(self):
        Git(self).fetch_commit(url="https://github.com/dlbeer/quirc.git", commit=_QUIRC_COMMIT)

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
        lib_dir = os.path.join(self.source_folder, "lib")

        objects = []
        for src in self._sources:
            obj = src.replace(".c", ".o")
            objects.append(obj)
            self.run(
                f'"{clang}" -arch {arch} {arch_flag} -Os -isysroot "{sdk}" '
                f'-miphoneos-version-min={min_version} -I "{lib_dir}" '
                f'-c "{os.path.join(lib_dir, src)}" -o "{obj}"'
            )
        self.run(f'ar rcs libquirc.a {" ".join(objects)}')

    def package(self):
        copy(self, "libquirc.a", self.build_folder, os.path.join(self.package_folder, "lib"), keep_path=False)
        copy(self, "*.h", os.path.join(self.source_folder, "lib"),
             os.path.join(self.package_folder, "include", "quirc"), keep_path=False)
        copy(self, "LICENSE", self.source_folder, os.path.join(self.package_folder, "licenses"))

    def package_info(self):
        self.cpp_info.libs = ["quirc"]
        self.cpp_info.includedirs = ["include"]

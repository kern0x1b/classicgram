import os

from conan import ConanFile
from conan.errors import ConanException
from conan.tools.apple import to_apple_arch
from conan.tools.files import copy
from conan.tools.scm import Git


class WebpConan(ConanFile):
    name = "webp"
    user = "itglegacy"
    channel = "stable"
    version = "1.6.0"
    package_type = "static-library"
    description = "libwebp 1.6.0, fetched vanilla from upstream - replaces a prebuilt archive of unknown provenance"
    license = "BSD-3-Clause"
    homepage = "https://chromium.googlesource.com/webm/libwebp"

    python_requires = "ios6-base/1.0@ios6/stable"
    python_requires_extend = "ios6-base.Ios6Port"

    def source(self):
        Git(self).fetch_commit(url="https://chromium.googlesource.com/webm/libwebp", commit="v1.6.0")

    def _apple_arch(self):
        return to_apple_arch(self)

    def _real_sdk_path(self):
        sdk = self.conf.get("tools.apple:sdk_path")
        if not sdk or not os.path.isdir(sdk):
            raise ConanException(f"tools.apple:sdk_path does not point at a real SDK: {sdk!r}")
        return sdk

    def build(self):
        arch = self._apple_arch()
        sdk = self._real_sdk_path()
        min_version = str(self.settings.os.version)

        self.run(
            f'cmake "{self.source_folder}" '
            f'-DCMAKE_BUILD_TYPE=Release '
            f'-DCMAKE_SYSTEM_NAME=iOS '
            f'-DCMAKE_OSX_SYSROOT="{sdk}" '
            f'-DCMAKE_OSX_ARCHITECTURES="{arch}" '
            f'-DCMAKE_OSX_DEPLOYMENT_TARGET={min_version} '
            f'-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY '
            f'-DWEBP_LINK_STATIC=ON '
            f'-DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF '
            f'-DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF -DWEBP_BUILD_VWEBP=OFF '
            f'-DWEBP_BUILD_WEBPINFO=OFF -DWEBP_BUILD_LIBWEBPMUX=OFF -DWEBP_BUILD_WEBPMUX=OFF '
            f'-DWEBP_BUILD_EXTRAS=OFF -DWEBP_BUILD_FUZZTEST=OFF '
            f'-DCMAKE_POLICY_VERSION_MINIMUM=3.5',
            cwd=self.build_folder,
        )
        self.run(f"cmake --build . --target webp -- -j{os.cpu_count()}", cwd=self.build_folder)

    def _find_lib(self, name):
        for dirpath, _, filenames in os.walk(self.build_folder):
            for filename in filenames:
                if filename == name:
                    return os.path.join(dirpath, filename)
        raise ConanException(f"no {name} produced")

    def package(self):
        for lib in ("libwebp.a", "libsharpyuv.a"):
            copy(self, lib, os.path.dirname(self._find_lib(lib)),
                 os.path.join(self.package_folder, "lib"), keep_path=False)
        copy(self, "*.h", os.path.join(self.source_folder, "src", "webp"),
             os.path.join(self.package_folder, "include", "webp"), keep_path=False)
        copy(self, "COPYING", self.source_folder, os.path.join(self.package_folder, "licenses"))

    def package_info(self):
        self.cpp_info.libs = ["webp", "sharpyuv"]

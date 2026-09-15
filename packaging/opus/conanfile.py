import os

from conan import ConanFile
from conan.errors import ConanException
from conan.tools.apple import to_apple_arch
from conan.tools.files import copy
from conan.tools.scm import Git


class OpusConan(ConanFile):
    name = "opus"
    user = "itglegacy"
    channel = "stable"
    version = "1.3.1"
    package_type = "static-library"
    description = "libopus 1.3.1, the version string embedded in the prebuilt archive this replaces"
    license = "BSD-3-Clause"
    homepage = "https://opus-codec.org"

    python_requires = "ios6-base/1.0@ios6/stable"
    python_requires_extend = "ios6-base.Ios6Port"

    def source(self):
        Git(self).fetch_commit(url="https://github.com/xiph/opus.git", commit="v1.3.1")

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
        arch_flag = "-mthumb" if arch == "armv7" else ""
        system_processor = "armv7-a" if arch == "armv7" else "aarch64"

        build_dir = self.build_folder
        self.run(
            f'cmake "{self.source_folder}" '
            f'-DCMAKE_BUILD_TYPE=Release '
            f'-DCMAKE_SYSTEM_NAME=iOS '
            f'-DCMAKE_SYSTEM_PROCESSOR={system_processor} '
            f'-DCMAKE_OSX_SYSROOT="{sdk}" '
            f'-DCMAKE_OSX_ARCHITECTURES="{arch}" '
            f'-DCMAKE_OSX_DEPLOYMENT_TARGET={min_version} '
            f'-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY '
            f'-DCMAKE_C_FLAGS="{arch_flag}" '
            f'-DOPUS_BUILD_PROGRAMS=OFF '
            f'-DOPUS_BUILD_TESTING=OFF '
            f'-DOPUS_INSTALL_PKG_CONFIG_MODULE=OFF '
            f'-DOPUS_INSTALL_CMAKE_CONFIG_MODULE=OFF '
            f'-DOPUS_MAY_HAVE_NEON=ON '
            f'-DOPUS_PRESUME_NEON=ON '
            f'-DCMAKE_POLICY_VERSION_MINIMUM=3.5',
            cwd=build_dir,
        )
        self.run(f"cmake --build . -- -j{os.cpu_count()}", cwd=build_dir)

    def _find_lib(self):
        for dirpath, _, filenames in os.walk(self.build_folder):
            for filename in filenames:
                if filename == "libopus.a":
                    return os.path.join(dirpath, filename)
        raise ConanException("no libopus.a produced")

    def package(self):
        copy(self, "libopus.a", os.path.dirname(self._find_lib()),
             os.path.join(self.package_folder, "lib"), keep_path=False)
        copy(self, "*.h", os.path.join(self.source_folder, "include"),
             os.path.join(self.package_folder, "include", "opus"), keep_path=False)
        copy(self, "COPYING", self.source_folder, os.path.join(self.package_folder, "licenses"))

    def package_info(self):
        self.cpp_info.libs = ["opus"]
        self.cpp_info.includedirs = ["include", os.path.join("include", "opus")]

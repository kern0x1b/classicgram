import os

from conan import ConanFile
from conan.errors import ConanException
from conan.tools.apple import to_apple_arch
from conan.tools.files import copy
from conan.tools.scm import Git


class LibvpxConan(ConanFile):
    name = "libvpx"
    user = "itglegacy"
    channel = "stable"
    version = "1.13.1"
    package_type = "static-library"
    description = "libvpx 1.13.1 'Ugly Duckling', VP8-only realtime build, matching scripts/build-libvpx.sh"
    license = "BSD-3-Clause"
    homepage = "https://chromium.googlesource.com/webm/libvpx"

    python_requires = "ios6-base/1.0@ios6/stable"
    python_requires_extend = "ios6-base.Ios6Port"

    def source(self):
        Git(self).fetch_commit(url="https://github.com/webmproject/libvpx.git", commit="v1.13.1")

    def _real_sdk_path(self):
        sdk = self.conf.get("tools.apple:sdk_path")
        if not sdk or not os.path.isdir(sdk):
            raise ConanException(f"tools.apple:sdk_path does not point at a real SDK: {sdk!r}")
        return sdk

    def build(self):
        arch = str(self.settings.arch)
        sdk = self._real_sdk_path()
        min_version = str(self.settings.os.version)

        if arch == "armv7":
            target = "armv7-darwin-gcc"
        elif arch == "armv8":
            target = "arm64-darwin-gcc"
        else:
            raise ConanException(f"libvpx has no configure target for arch {arch!r}")

        flags = f"-arch {to_apple_arch(self)} -miphoneos-version-min={min_version} -isysroot {sdk}"

        cxx_stdlib_inc = ""
        root = os.environ.get("ITGLEGACY_ROOT")
        if root:
            for sdk_name in ("iPhoneOS16.5.sdk", "iPhoneOS15.6.sdk"):
                candidate = os.path.join(root, "build", "sdks", sdk_name, "usr", "include", "c++", "v1")
                if os.path.isdir(candidate):
                    cxx_stdlib_inc = f"-isystem {candidate}"
                    break

        env = {
            "CC": "clang",
            "CXX": "clang++",
            "CFLAGS": flags,
            "CXXFLAGS": f"{flags} {cxx_stdlib_inc}",
            "LDFLAGS": flags,
        }
        exports = " ".join(f'{k}="{v}"' for k, v in env.items())

        self.run(
            f'{exports} "{self.source_folder}/configure" --target={target} --enable-neon '
            f'--disable-examples --disable-docs --disable-unit-tests '
            f'--enable-static --disable-shared --disable-vp9 --enable-vp8 '
            f'--enable-realtime-only --disable-runtime-cpu-detect',
            cwd=self.build_folder,
        )
        self.run(f"make -j{os.cpu_count()} libvpx.a", cwd=self.build_folder)

    def package(self):
        copy(self, "libvpx.a", self.build_folder, os.path.join(self.package_folder, "lib"), keep_path=False)
        copy(self, "vpx/*.h", self.source_folder, os.path.join(self.package_folder, "include"))
        copy(self, "LICENSE", self.source_folder, os.path.join(self.package_folder, "licenses"))

    def package_info(self):
        self.cpp_info.libs = ["vpx"]

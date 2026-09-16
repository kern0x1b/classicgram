import os

from conan import ConanFile
from conan.errors import ConanInvalidConfiguration
from conan.tools.files import copy
from conan.tools.gnu import Autotools, AutotoolsToolchain
from conan.tools.scm import Git


class LibvpxConan(ConanFile):
    name = "libvpx"
    user = "itglegacy"
    channel = "stable"
    package_type = "static-library"
    description = "libvpx, VP8-only realtime build through its own configure"
    license = "BSD-3-Clause"
    homepage = "https://chromium.googlesource.com/webm/libvpx"

    python_requires = "charon-base/1.0@charon/stable", "charon-apple/1.0@charon/stable"
    python_requires_extend = "charon-base.CharonPort", "charon-apple.ApplePort"

    _configure_targets = {"armv7": "armv7-darwin-gcc", "armv8": "arm64-darwin-gcc"}

    def requirements(self):
        self.requires("apple-compat/1.0@charon/stable")

    def validate(self):
        super().validate()
        if str(self.settings.arch) not in self._configure_targets:
            raise ConanInvalidConfiguration(f"libvpx has no configure target for {self.settings.arch}")

    def source(self):
        data = self.conan_data["sources"][self.version]
        git = Git(self)
        git.clone(url=data["url"], target=".", args=["--filter=blob:none", "--no-checkout"])
        git.checkout(data["commit"])

    def generate(self):
        super().generate()
        AutotoolsToolchain(self).generate()

    def build(self):
        target = self._configure_targets[str(self.settings.arch)]
        clock_gettime = self.dependencies["apple-compat"].cpp_info.components["clock_gettime"]
        extra_cflags = " ".join([f"-miphoneos-version-min={self.settings.os.version}", *clock_gettime.cflags])
        self.run(
            f'"{self.source_folder}/configure" --target={target} '
            f'--extra-cflags="{extra_cflags}" '
            f'--enable-neon --enable-static --disable-shared '
            f'--disable-examples --disable-tools --disable-docs --disable-unit-tests '
            f'--disable-vp9 --enable-vp8 --enable-realtime-only --disable-runtime-cpu-detect',
            cwd=self.build_folder)
        Autotools(self).make(target="libvpx.a")

    def package(self):
        copy(self, "libvpx.a", self.build_folder, os.path.join(self.package_folder, "lib"), keep_path=False)
        copy(self, "vpx/*.h", self.source_folder, os.path.join(self.package_folder, "include"))
        copy(self, "vpx_version.h", self.build_folder, os.path.join(self.package_folder, "include", "vpx"))
        copy(self, "LICENSE", self.source_folder, os.path.join(self.package_folder, "licenses"))
        copy(self, "PATENTS", self.source_folder, os.path.join(self.package_folder, "licenses"))

    def package_info(self):
        self.cpp_info.set_property("cmake_file_name", "libvpx")
        self.cpp_info.set_property("pkg_config_name", "vpx")
        self.cpp_info.libs = ["vpx"]
        self.cpp_info.requires = ["apple-compat::clock_gettime"]

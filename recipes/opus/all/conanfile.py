import os

from conan import ConanFile
from conan.tools.cmake import CMake
from conan.tools.files import copy, rmdir
from conan.tools.scm import Git


class OpusConan(ConanFile):
    name = "opus"
    user = "itglegacy"
    channel = "stable"
    package_type = "static-library"
    description = "libopus, the Opus audio codec, built by its own CMake project"
    license = "BSD-3-Clause"
    homepage = "https://opus-codec.org"

    python_requires = "charon-base/1.0@charon/stable", "charon-apple/1.0@charon/stable"
    python_requires_extend = "charon-base.CharonPort", "charon-apple.ApplePort"

    def source(self):
        data = self.conan_data["sources"][self.version]
        git = Git(self)
        git.clone(url=data["url"], target=".", args=["--filter=blob:none", "--no-checkout"])
        git.checkout(data["commit"])

    def build(self):
        cmake = CMake(self)
        cmake.configure(variables={
            "BUILD_TESTING": False,
            "OPUS_BUILD_SHARED_LIBRARY": False,
            "OPUS_BUILD_TESTING": False,
            "OPUS_BUILD_PROGRAMS": False,
            "OPUS_INSTALL_PKG_CONFIG_MODULE": False,
            "OPUS_INSTALL_CMAKE_CONFIG_MODULE": False,
        })
        cmake.build()

    def package(self):
        CMake(self).install()
        rmdir(self, os.path.join(self.package_folder, "share"))
        copy(self, "COPYING", self.source_folder, os.path.join(self.package_folder, "licenses"))

    def package_info(self):
        self.cpp_info.set_property("cmake_file_name", "Opus")
        self.cpp_info.set_property("cmake_target_name", "Opus::opus")
        self.cpp_info.set_property("pkg_config_name", "opus")
        self.cpp_info.libs = ["opus"]
        self.cpp_info.includedirs = ["include", os.path.join("include", "opus")]

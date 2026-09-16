import os

from conan import ConanFile
from conan.tools.cmake import CMake
from conan.tools.files import copy, rmdir
from conan.tools.scm import Git


class OggConan(ConanFile):
    name = "ogg"
    user = "itglegacy"
    channel = "stable"
    package_type = "static-library"
    description = "libogg, the Ogg container format library, built by its own CMake project"
    license = "BSD-3-Clause"
    homepage = "https://github.com/xiph/ogg"

    python_requires = "charon-base/1.0@charon/stable", "charon-apple/1.0@charon/stable"
    python_requires_extend = "charon-base.CharonPort", "charon-apple.ApplePort"

    def source(self):
        data = self.conan_data["sources"][self.version]
        Git(self).fetch_commit(url=data["url"], commit=data["commit"])

    def build(self):
        cmake = CMake(self)
        cmake.configure(variables={
            "BUILD_SHARED_LIBS": False,
            "BUILD_TESTING": False,
            "INSTALL_DOCS": False,
            "INSTALL_PKG_CONFIG_MODULE": False,
            "INSTALL_CMAKE_PACKAGE_MODULE": False,
        })
        cmake.build()

    def package(self):
        CMake(self).install()
        rmdir(self, os.path.join(self.package_folder, "share"))
        copy(self, "COPYING", self.source_folder, os.path.join(self.package_folder, "licenses"))

    def package_info(self):
        self.cpp_info.set_property("cmake_file_name", "Ogg")
        self.cpp_info.set_property("cmake_target_name", "Ogg::ogg")
        self.cpp_info.libs = ["ogg"]

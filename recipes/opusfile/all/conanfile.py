import os

from conan import ConanFile
from conan.tools.cmake import CMake
from conan.tools.files import copy, rmdir
from conan.tools.scm import Git


class OpusfileConan(ConanFile):
    name = "opusfile"
    user = "itglegacy"
    channel = "stable"
    package_type = "static-library"
    description = "opusfile, the Ogg Opus playback library, built by its own CMake project without HTTP"
    license = "BSD-3-Clause"
    homepage = "https://github.com/xiph/opusfile"

    python_requires = "charon-base/1.0@charon/stable", "charon-apple/1.0@charon/stable"
    python_requires_extend = "charon-base.CharonPort", "charon-apple.ApplePort"

    def requirements(self):
        self.requires("ogg/1.3.6+7.g06a5e02@itglegacy/stable", transitive_headers=True)
        self.requires("opus/1.6.1+68.g503d81b@itglegacy/stable", transitive_headers=True)

    def source(self):
        data = self.conan_data["sources"][self.version]
        git = Git(self)
        git.clone(url=data["url"], target=".", args=["--filter=blob:none", "--no-checkout"])
        git.checkout(data["commit"])

    def build(self):
        cmake = CMake(self)
        cmake.configure(variables={
            "BUILD_TESTING": False,
            "OP_DISABLE_HTTP": True,
            "OP_DISABLE_EXAMPLES": True,
            "OP_DISABLE_DOCS": True,
        })
        cmake.build()

    def package(self):
        CMake(self).install()
        rmdir(self, os.path.join(self.package_folder, "lib", "cmake"))
        rmdir(self, os.path.join(self.package_folder, "lib", "pkgconfig"))
        rmdir(self, os.path.join(self.package_folder, "share"))
        copy(self, "COPYING", self.source_folder, os.path.join(self.package_folder, "licenses"))

    def package_info(self):
        self.cpp_info.set_property("cmake_file_name", "OpusFile")
        self.cpp_info.set_property("cmake_target_name", "OpusFile::opusfile")
        self.cpp_info.libs = ["opusfile"]
        self.cpp_info.includedirs = ["include", os.path.join("include", "opus")]
        self.cpp_info.requires = ["ogg::ogg", "opus::opus"]

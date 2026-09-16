import os

from conan import ConanFile
from conan.tools.cmake import CMake
from conan.tools.files import copy, rmdir
from conan.tools.scm import Git


class WebpConan(ConanFile):
    name = "webp"
    user = "itglegacy"
    channel = "stable"
    package_type = "static-library"
    description = "libwebp, the WebP image codec, built by its own CMake project"
    license = "BSD-3-Clause"
    homepage = "https://chromium.googlesource.com/webm/libwebp"

    python_requires = "charon-base/1.0@charon/stable", "charon-apple/1.0@charon/stable"
    python_requires_extend = "charon-base.CharonPort", "charon-apple.ApplePort"

    def source(self):
        data = self.conan_data["sources"][self.version]
        Git(self).fetch_commit(url=data["url"], commit=data["commit"])

    def build(self):
        cmake = CMake(self)
        cmake.configure(variables={
            "BUILD_SHARED_LIBS": False,
            "WEBP_LINK_STATIC": True,
            "WEBP_BUILD_ANIM_UTILS": False,
            "WEBP_BUILD_CWEBP": False,
            "WEBP_BUILD_DWEBP": False,
            "WEBP_BUILD_GIF2WEBP": False,
            "WEBP_BUILD_IMG2WEBP": False,
            "WEBP_BUILD_VWEBP": False,
            "WEBP_BUILD_WEBPINFO": False,
            "WEBP_BUILD_LIBWEBPMUX": False,
            "WEBP_BUILD_WEBPMUX": False,
            "WEBP_BUILD_EXTRAS": False,
            "WEBP_BUILD_FUZZTEST": False,
        })
        cmake.build()

    def package(self):
        CMake(self).install()
        for folder in (os.path.join("lib", "cmake"), os.path.join("lib", "pkgconfig"), "share"):
            rmdir(self, os.path.join(self.package_folder, folder))
        copy(self, "COPYING", self.source_folder, os.path.join(self.package_folder, "licenses"))

    def package_info(self):
        self.cpp_info.set_property("cmake_file_name", "WebP")
        self.cpp_info.components["sharpyuv"].set_property("cmake_target_name", "WebP::sharpyuv")
        self.cpp_info.components["sharpyuv"].libs = ["sharpyuv"]
        self.cpp_info.components["webp"].set_property("cmake_target_name", "WebP::webp")
        self.cpp_info.components["webp"].libs = ["webp"]
        self.cpp_info.components["webp"].requires = ["sharpyuv"]
        self.cpp_info.components["webpdecoder"].set_property("cmake_target_name", "WebP::webpdecoder")
        self.cpp_info.components["webpdecoder"].libs = ["webpdecoder"]
        self.cpp_info.components["webpdemux"].set_property("cmake_target_name", "WebP::webpdemux")
        self.cpp_info.components["webpdemux"].libs = ["webpdemux"]
        self.cpp_info.components["webpdemux"].requires = ["webp"]

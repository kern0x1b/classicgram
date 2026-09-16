import os

from conan import ConanFile
from conan.tools.files import copy
from conan.tools.gnu import Autotools, AutotoolsToolchain
from conan.tools.scm import Git


class QuircConan(ConanFile):
    name = "quirc"
    user = "itglegacy"
    channel = "stable"
    package_type = "static-library"
    description = "quirc, the QR-code decoder, built by its own Makefile's library target"
    license = "ISC"
    homepage = "https://github.com/dlbeer/quirc"

    python_requires = "charon-base/1.0@charon/stable", "charon-apple/1.0@charon/stable"
    python_requires_extend = "charon-base.CharonPort", "charon-apple.ApplePort"

    def source(self):
        data = self.conan_data["sources"][self.version]
        Git(self).fetch_commit(url=data["url"], commit=data["commit"])

    def generate(self):
        super().generate()
        AutotoolsToolchain(self).generate()

    def build(self):
        Autotools(self).make(target="libquirc.a", args=[
            f"-C {self.source_folder}", "SDL_CFLAGS=", "OPENCV_CFLAGS="])

    def package(self):
        copy(self, "libquirc.a", self.source_folder, os.path.join(self.package_folder, "lib"), keep_path=False)
        copy(self, "quirc.h", os.path.join(self.source_folder, "lib"),
             os.path.join(self.package_folder, "include"), keep_path=False)
        copy(self, "LICENSE", self.source_folder, os.path.join(self.package_folder, "licenses"))

    def package_info(self):
        self.cpp_info.libs = ["quirc"]

import os

from conan import ConanFile
from conan.tools.files import copy, rm, rmdir
from conan.tools.gnu import Autotools, AutotoolsToolchain, PkgConfigDeps
from conan.tools.scm import Git


class LibopusencConan(ConanFile):
    name = "libopusenc"
    user = "itglegacy"
    channel = "stable"
    package_type = "static-library"
    description = "libopusenc, xiph's library for writing Ogg Opus files, built by its own autotools project"
    license = "BSD-3-Clause"
    homepage = "https://github.com/xiph/libopusenc"

    python_requires = "charon-base/1.0@charon/stable", "charon-apple/1.0@charon/stable"
    python_requires_extend = "charon-base.CharonPort", "charon-apple.ApplePort"

    def requirements(self):
        self.requires("opus/1.6.1+68.g503d81b@itglegacy/stable", transitive_headers=True)

    def build_requirements(self):
        self.tool_requires("libtool/2.4.7")
        self.tool_requires("pkgconf/2.5.1")

    def source(self):
        data = self.conan_data["sources"][self.version]
        git = Git(self)
        git.clone(url=data["url"], target=".", args=["--filter=blob:none", "--no-checkout"])
        git.checkout(data["commit"])

    def generate(self):
        super().generate()
        toolchain = AutotoolsToolchain(self)
        toolchain.configure_args += ["--enable-static", "--disable-shared",
                                     "--disable-examples", "--disable-doc"]
        toolchain.generate()
        PkgConfigDeps(self).generate()

    def build(self):
        autotools = Autotools(self)
        autotools.autoreconf()
        autotools.configure()
        autotools.make()

    def package(self):
        Autotools(self).install()
        rm(self, "*.la", os.path.join(self.package_folder, "lib"))
        rmdir(self, os.path.join(self.package_folder, "lib", "pkgconfig"))
        rmdir(self, os.path.join(self.package_folder, "share"))
        copy(self, "COPYING", self.source_folder, os.path.join(self.package_folder, "licenses"))

    def package_info(self):
        self.cpp_info.set_property("pkg_config_name", "libopusenc")
        self.cpp_info.libs = ["opusenc"]
        self.cpp_info.includedirs = ["include", os.path.join("include", "opus")]
        self.cpp_info.requires = ["opus::opus"]

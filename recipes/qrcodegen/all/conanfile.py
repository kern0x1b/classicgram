import os

from conan import ConanFile
from conan.tools.files import copy, save, load
from conan.tools.gnu import Autotools, AutotoolsToolchain
from conan.tools.scm import Git


class QrcodegenConan(ConanFile):
    name = "qrcodegen"
    user = "itglegacy"
    channel = "stable"
    package_type = "static-library"
    description = "Project Nayuki's QR Code generator library, the C implementation, compiled by its own Makefile and archived with the platform's ar, since that Makefile's archive rule passes GNU ar's `--`"
    license = "MIT"
    homepage = "https://www.nayuki.io/page/qr-code-generator-library"

    python_requires = "charon-base/1.0@charon/stable", "charon-apple/1.0@charon/stable"
    python_requires_extend = "charon-base.CharonPort", "charon-apple.ApplePort"

    def source(self):
        data = self.conan_data["sources"][self.version]
        Git(self).fetch_commit(url=data["url"], commit=data["commit"])

    def generate(self):
        super().generate()
        AutotoolsToolchain(self).generate()

    def build(self):
        source = os.path.join(self.source_folder, "c")
        Autotools(self).make(target="qrcodegen.o", args=[f"-C {source}"])
        self.run("ar rcs libqrcodegen.a qrcodegen.o", cwd=source)

    def package(self):
        source = os.path.join(self.source_folder, "c")
        copy(self, "libqrcodegen.a", source, os.path.join(self.package_folder, "lib"), keep_path=False)
        copy(self, "qrcodegen.h", source, os.path.join(self.package_folder, "include"), keep_path=False)
        readme = load(self, os.path.join(self.source_folder, "Readme.markdown"))
        save(self, os.path.join(self.package_folder, "licenses", "LICENSE"), readme[readme.index("License\n-------"):])

    def package_info(self):
        self.cpp_info.libs = ["qrcodegen"]

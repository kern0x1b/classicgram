from conan import ConanFile


class ItgLegacyDepsConan(ConanFile):
    name = "itglegacy-deps"
    user = "itglegacy"
    channel = "stable"
    version = "1.0"
    description = "The Makefile's own view of what iTgLegacy depends on, resolved through Conan"

    python_requires = "ios6-base/1.0@ios6/stable"
    python_requires_extend = "ios6-base.Ios6Port"

    def requirements(self):
        self.requires("tdlib/1.8.0@ios6/stable")
        self.requires("openssl/3.0.15@itglegacy/stable")
        self.requires("ogg/unpinned@itglegacy/stable")
        self.requires("quirc/unpinned@itglegacy/stable")
        self.requires("opusenc/unpinned@itglegacy/stable")
        self.requires("opusfile/unpinned@itglegacy/stable")
        self.requires("opus/1.3.1@itglegacy/stable")
        self.requires("libvpx/1.13.1@itglegacy/stable")
        self.requires("libtgvoip/2.4.4-itglegacy@itglegacy/stable")

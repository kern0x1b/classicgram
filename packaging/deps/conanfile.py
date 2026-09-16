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
        self.requires("openssl/3.0.22@itglegacy/stable")
        self.requires("ogg/1.3.6@itglegacy/stable")
        self.requires("quirc/1.2+git@itglegacy/stable")
        self.requires("opusenc/0.1.10@itglegacy/stable")
        self.requires("opusfile/0.12@itglegacy/stable")
        self.requires("opus/1.6.1@itglegacy/stable")
        self.requires("libvpx/1.16.0@itglegacy/stable")
        self.requires("libtgvoip/2.4.4-itglegacy@itglegacy/stable")
        self.requires("webp/1.6.0@itglegacy/stable")

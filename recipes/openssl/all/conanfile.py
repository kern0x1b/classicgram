import os

from conan import ConanFile
from conan.errors import ConanException, ConanInvalidConfiguration
from conan.tools.files import apply_conandata_patches, copy
from conan.tools.scm import Git


class OpenSSLConan(ConanFile):
    name = "openssl"
    user = "itglegacy"
    channel = "stable"
    package_type = "static-library"
    description = ("OpenSSL, the newest release, configured through its own ios-cross and ios64-cross "
                   "targets; armv7 carries a perlasm translator fix for OPENSSL_armcap_P, which upstream's "
                   "armv4 assembly can no longer reach on Mach-O since 3.1.3 (openssl/openssl#26510)")
    license = "Apache-2.0"
    homepage = "https://www.openssl.org"

    python_requires = "charon-base/1.0@charon/stable", "charon-apple/1.0@charon/stable"
    python_requires_extend = "charon-base.CharonPort", "charon-apple.ApplePort"

    exports_sources = "patches/*"

    _configure_targets = {"armv7": "ios-cross", "armv8": "ios64-cross"}

    def validate(self):
        super().validate()
        if str(self.settings.arch) not in self._configure_targets:
            raise ConanInvalidConfiguration(f"openssl has no iOS Configure target for {self.settings.arch}")

    def source(self):
        data = self.conan_data["sources"][self.version]
        Git(self).fetch_commit(url=data["url"], commit=data["commit"])
        apply_conandata_patches(self)

    def _cross_environment(self):
        sdk = os.path.normpath(self.sdk_path)
        cross_top, cross_sdk = os.path.dirname(os.path.dirname(sdk)), os.path.basename(sdk)
        if not os.path.isdir(os.path.join(cross_top, "SDKs", cross_sdk)):
            raise ConanException(f"OpenSSL's iOS targets read the SDK as $(CROSS_TOP)/SDKs/$(CROSS_SDK); "
                                 f"{sdk} is not laid out that way")
        commit_time = Git(self, folder=self.source_folder).run("log -1 --format=%ct")
        return {"CROSS_TOP": cross_top, "CROSS_SDK": cross_sdk, "SOURCE_DATE_EPOCH": commit_time}

    def build(self):
        arch = str(self.settings.arch)
        atomics = ["-DBROKEN_CLANG_ATOMICS"] if arch == "armv7" else []
        environment = " ".join(f'{key}="{value}"' for key, value in self._cross_environment().items())
        options = ["no-shared", "no-dso", "no-tests", "no-docs", "no-apps", "no-engine", "no-async",
                   *atomics, f"-mios-version-min={self.settings.os.version}"]
        self.run(f'{environment} ./Configure {self._configure_targets[arch]} {" ".join(options)}',
                 cwd=self.source_folder)
        self.run(f"{environment} make -j{os.cpu_count()} build_libs", cwd=self.source_folder)

    def package(self):
        for library in ("libcrypto.a", "libssl.a"):
            copy(self, library, self.source_folder, os.path.join(self.package_folder, "lib"), keep_path=False)
        copy(self, "*.h", os.path.join(self.source_folder, "include", "openssl"),
             os.path.join(self.package_folder, "include", "openssl"))
        copy(self, "LICENSE.txt", self.source_folder, os.path.join(self.package_folder, "licenses"))

    def package_info(self):
        self.cpp_info.set_property("cmake_file_name", "OpenSSL")
        self.cpp_info.components["crypto"].set_property("cmake_target_name", "OpenSSL::Crypto")
        self.cpp_info.components["crypto"].libs = ["crypto"]
        self.cpp_info.components["ssl"].set_property("cmake_target_name", "OpenSSL::SSL")
        self.cpp_info.components["ssl"].libs = ["ssl"]
        self.cpp_info.components["ssl"].requires = ["crypto"]

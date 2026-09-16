import os

from conan import ConanFile
from conan.errors import ConanException
from conan.tools.files import copy, replace_in_file
from conan.tools.scm import Git


class OpenSSLConan(ConanFile):
    name = "openssl"
    user = "itglegacy"
    channel = "stable"
    version = "3.0.22"
    package_type = "static-library"
    description = ("OpenSSL 3.0.22, the latest patch release of the 3.0 LTS branch (supported through "
                   "2026) - 3.5/3.6 moved OPENSSL_armcap_P from an assembly .comm to a C global, which "
                   "breaks the PC-relative addressing several armv4 .S files use to reach it without a "
                   "GOT, for the iOS 6 / armv7 and armv8 profiles this port targets")
    license = "Apache-2.0"
    homepage = "https://www.openssl.org"

    python_requires = "ios6-base/1.0@ios6/stable"
    python_requires_extend = "ios6-base.Ios6Port"

    _armcap_old = (
        '\t$ret .= ".non_lazy_symbol_pointer\\n";\n'
        '\t$ret .= "$name:\\n";\n'
        '\t$ret .= ".indirect_symbol\\t_$name\\n";\n'
        '\t$ret .= ".long\\t0";'
    )
    _armcap_new = (
        '\t$ret .= ".data\\n";\n'
        '\t$ret .= ".align\\t2\\n";\n'
        '\t$ret .= "$name:\\n";\n'
        '\t$ret .= ".long\\t_$name\\n";\n'
        '\t$ret .= ".text";'
    )

    def source(self):
        data = self.conan_data["sources"][self.version]
        Git(self).fetch_commit(url=data["url"], commit=data["commit"])
        replace_in_file(self, os.path.join(self.source_folder, "crypto", "perlasm", "arm-xlate.pl"),
                         self._armcap_old, self._armcap_new)

    def _real_sdk_path(self):
        sdk = self.conf.get("tools.apple:sdk_path")
        if not sdk or not os.path.isdir(sdk):
            raise ConanException(f"tools.apple:sdk_path does not point at a real SDK: {sdk!r}")
        return sdk

    def build(self):
        arch = str(self.settings.arch)
        min_version = str(self.settings.os.version)
        sdk = self._real_sdk_path()

        if arch == "armv7":
            config_target = "ios-cross"
            no_libatomic = "-DBROKEN_CLANG_ATOMICS"
        elif arch == "armv8":
            config_target = "ios64-cross"
            no_libatomic = ""
        else:
            raise ConanException(f"openssl/{self.version} has no iOS Configure target for arch {arch!r}")

        env = {
            "CROSS_COMPILE": "",
            "CROSS_TOP": "/nonexistent",
            "CROSS_SDK": "placeholder.sdk",
            "SOURCE_DATE_EPOCH": "1700000000",
        }
        exports = " ".join(f'{k}="{v}"' for k, v in env.items())

        self.run(f'{exports} ./Configure {config_target} no-shared no-dso no-tests no-engine no-async '
                  f'-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 {no_libatomic} '
                  f'-isysroot "{sdk}" -mios-version-min={min_version}',
                  cwd=self.source_folder)
        self.run(f'{exports} make -j{os.cpu_count()} build_libs', cwd=self.source_folder)

    def package(self):
        for lib in ("libcrypto.a", "libssl.a"):
            copy(self, lib, self.source_folder, os.path.join(self.package_folder, "lib"), keep_path=False)
        copy(self, "*.h", os.path.join(self.source_folder, "include", "openssl"),
             os.path.join(self.package_folder, "include", "openssl"))
        copy(self, "LICENSE.txt", self.source_folder, os.path.join(self.package_folder, "licenses"))

    def package_info(self):
        self.cpp_info.libs = ["ssl", "crypto"]

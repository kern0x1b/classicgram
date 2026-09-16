import os
import shutil

from conan import ConanFile
from conan.errors import ConanException
from conan.tools.apple import to_apple_arch
from conan.tools.files import copy, download, replace_in_file
from conan.tools.scm import Git


_VOIP_BACKGROUND_REPLACEMENTS = [
    ("td/telegram/net/Session.cpp", [
        ('#include <tuple>\n#include <utility>\n\nnamespace td {\n\nnamespace detail {',
         '#include <tuple>\n#include <utility>\n\n'
         '#include "td/utils/port/config.h"\n'
         '\n'
         '#if TD_DARWIN_IOS\n'
         'extern "C" {\n'
         '\n'
         'typedef void (*td_ios_primary_socket_callback)(int fd);\n'
         '\n'
         'static td_ios_primary_socket_callback td_ios_primary_socket_cb = nullptr;\n'
         '\n'
         '__attribute__((visibility("default"))) void td_ios_set_primary_socket_callback(\n'
         '    td_ios_primary_socket_callback callback) {\n'
         '  td_ios_primary_socket_cb = callback;\n'
         '}\n'
         '}\n'
         '#endif\n'
         '\n'
         'namespace td {\n'
         '\n'
         'namespace detail {'),
        ('  info->connection_->set_online(connection_online_flag_, is_primary_);\n'
         '  info->connection_->set_name(name);\n'
         '  Scheduler::subscribe(info->connection_->get_poll_info().extract_pollable_fd(this));',
         '  info->connection_->set_online(connection_online_flag_, is_primary_);\n'
         '  info->connection_->set_name(name);\n'
         '#if TD_DARWIN_IOS\n'
         '  if (is_main_ && is_primary_ && info->connection_id_ == 0 && '
         'td_ios_primary_socket_cb != nullptr) {\n'
         '    const auto &primary_native_fd = info->connection_->get_poll_info().native_fd();\n'
         '    if (primary_native_fd) {\n'
         '      td_ios_primary_socket_cb(primary_native_fd.socket());\n'
         '    }\n'
         '  }\n'
         '#endif\n'
         '  Scheduler::subscribe(info->connection_->get_poll_info().extract_pollable_fd(this));'),
    ]),
    ("tdclientjson_export_list", [
        ('_td_set_log_message_callback',
         '_td_set_log_message_callback\n_td_ios_set_primary_socket_callback'),
    ]),
]

_EMUTLS_DIR = "compiler-rt-builtins"
_EMULATED_TLS_VERSION = "9.0"


class TdlibConan(ConanFile):
    name = "tdlib"
    user = "ios6"
    channel = "stable"
    version = "1.8.0"
    package_type = "shared-library"
    description = ("TDLib's libtdjson, fetched vanilla from upstream, built with emulated "
                   "thread-local storage wherever the target compiler lacks real __thread, "
                   "plus the backgrounded VoIP socket hook this port always needs")
    license = "BSL-1.0"
    homepage = "https://github.com/tdlib/td"

    python_requires = "ios6-base/1.0@ios6/stable"
    python_requires_extend = "ios6-base.Ios6Port"

    exports_sources = "compat/*", "fix-armv7-macho.c"

    def requirements(self):
        self.requires("openssl/3.0.22@itglegacy/stable")

    def source(self):
        tdlib = self.conan_data["sources"]["tdlib"]
        Git(self).fetch_commit(url=tdlib["url"], commit=tdlib["commit"])
        runtime = self.conan_data["sources"]["compiler-rt-builtins"]
        for filename, checksum in runtime["files"].items():
            download(self, runtime["url"] + "/" + filename,
                     os.path.join(self.source_folder, _EMUTLS_DIR, filename),
                     sha256=checksum)

    def _apply_replacements(self, mapping):
        for relative_path, replacements in mapping:
            path = os.path.join(self.source_folder, relative_path)
            for old, new in replacements:
                replace_in_file(self, path, old, new)

    def _apple_arch(self):
        return to_apple_arch(self)

    def _real_sdk_path(self):
        sdk = self.conf.get("tools.apple:sdk_path")
        if not sdk or not os.path.isdir(sdk):
            raise ConanException(f"tools.apple:sdk_path does not point at a real SDK: {sdk!r}")
        return sdk

    def _has_real_thread_local(self):
        clang = shutil.which("clang++") or "/usr/bin/clang++"
        arch = self._apple_arch()
        sdk = self._real_sdk_path()
        min_version = str(self.settings.os.version)
        probe_src = os.path.join(self.build_folder, "_tls_probe.cpp")
        probe_obj = os.path.join(self.build_folder, "_tls_probe.o")
        os.makedirs(self.build_folder, exist_ok=True)
        with open(probe_src, "w") as f:
            f.write("static __thread int x;\nint main() { x = 1; return x; }\n")
        rc = self.run(
            f'"{clang}" -arch {arch} -isysroot "{sdk}" -miphoneos-version-min={min_version} '
            f'-c "{probe_src}" -o "{probe_obj}"',
            ignore_errors=True, quiet=True)
        return rc == 0

    def _build_emutls_runtime(self, build_dir):
        clang = shutil.which("clang") or "/usr/bin/clang"
        arch = self._apple_arch()
        sdk = self._real_sdk_path()
        min_version = str(self.settings.os.version)
        arch_flag = "-mthumb" if arch == "armv7" else ""
        builtins = os.path.join(self.source_folder, _EMUTLS_DIR)
        emutls_o = os.path.join(build_dir, "emutls.o")
        self.run(
            f'"{clang}" -arch {arch} {arch_flag} -Os -isysroot "{sdk}" '
            f'-miphoneos-version-min={min_version} -I "{builtins}" '
            f'-c "{os.path.join(builtins, "emutls.c")}" -o "{emutls_o}"'
        )
        return emutls_o

    def _require(self, tool):
        if shutil.which(tool) is None:
            raise ConanException(f"{tool} not found on PATH (brew install {tool})")

    def build(self):
        for tool in ("cmake", "gperf", "ccache"):
            self._require(tool)

        self._apply_replacements(_VOIP_BACKGROUND_REPLACEMENTS)

        src = self.source_folder
        arch = self._apple_arch()
        min_version = str(self.settings.os.version)
        sdk = self._real_sdk_path()
        clang = shutil.which("clang") or "/usr/bin/clang"
        clangxx = shutil.which("clang++") or "/usr/bin/clang++"

        cxx_stdlib_inc = ""
        cxx_stdlib_dir = self.conf.get("user.itglegacy:cxx_stdlib_include")
        if cxx_stdlib_dir:
            cxx_stdlib_inc = f"-isystem {cxx_stdlib_dir}"

        native_build = os.path.join(self.build_folder, "native-build")
        if not os.path.isdir(native_build):
            self.output.info("pregenerating sources")
            os.makedirs(native_build)
            self.run(f'cmake -DTD_GENERATE_SOURCE_FILES=ON '
                     f'-DCMAKE_C_FLAGS="-I{src}" -DCMAKE_CXX_FLAGS="-I{src}" '
                     f'"{src}"', cwd=native_build)
            self.run("cmake --build . --target prepare_cross_compiling", cwd=native_build)

        build_dir = os.path.join(self.build_folder, "cross-build")
        os.makedirs(build_dir, exist_ok=True)
        compat_o = os.path.join(build_dir, "ios7_compat.o")
        arch_flag = "-mthumb" if arch == "armv7" else ""
        self.run(
            f'"{clang}" -arch {arch} {arch_flag} -Os -isysroot "{sdk}" '
            f'-miphoneos-version-min={min_version} '
            f'-c "{os.path.join(src, "compat", "weak_import_shims.c")}" -o "{compat_o}"'
        )

        openssl_include, openssl_crypto, openssl_ssl = self._openssl_paths()

        linker_flags = f"-install_name @executable_path/libtdjson.dylib {compat_o}"
        if "ld64" in self.dependencies.build:
            ld64 = self.dependencies.build["ld64"]
            linker_flags = f"-B{ld64.package_folder}/bin {linker_flags}"

        c_flags = f"-Wno-error {arch_flag} -Os -g -I{src}"
        cxx_flags = f"{c_flags} {cxx_stdlib_inc}"
        deployment_target = min_version

        if self._has_real_thread_local():
            self.output.info("target compiler supports real __thread - TDLib stays vanilla for it")
        else:
            self.output.info(
                f"target has no real __thread at iOS {min_version} - compiling against iOS "
                f"{_EMULATED_TLS_VERSION} with -femulated-tls and linking compiler-rt's "
                f"__emutls_get_address, then recording iOS {min_version} in the Mach-O")
            emutls_o = self._build_emutls_runtime(build_dir)
            deployment_target = _EMULATED_TLS_VERSION
            c_flags = f"{c_flags} -femulated-tls"
            cxx_flags = f"{cxx_flags} -femulated-tls"
            linker_flags = f"{linker_flags} {emutls_o} -miphoneos-version-min={min_version}"

        self.run(
            f'cmake "{src}" '
            f'-DCMAKE_BUILD_TYPE=RelWithDebInfo '
            f'-DCMAKE_C_COMPILER_LAUNCHER=ccache '
            f'-DCMAKE_CXX_COMPILER_LAUNCHER=ccache '
            f'-DCMAKE_C_COMPILER="{clang}" '
            f'-DCMAKE_CXX_COMPILER="{clangxx}" '
            f'-DCMAKE_SYSTEM_NAME=iOS '
            f'-DCMAKE_OSX_SYSROOT="{sdk}" '
            f'-DCMAKE_OSX_ARCHITECTURES="{arch}" '
            f'-DCMAKE_OSX_DEPLOYMENT_TARGET={deployment_target} '
            f'-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY '
            f'-DATOMICS_FOUND=TRUE -DATOMICS_LIBRARIES="" '
            f'-DCMAKE_C_FLAGS="{c_flags}" '
            f'-DCMAKE_CXX_FLAGS="{cxx_flags}" '
            f'-DCMAKE_SHARED_LINKER_FLAGS="{linker_flags}" '
            f'-DOPENSSL_INCLUDE_DIR="{openssl_include}" '
            f'-DOPENSSL_CRYPTO_LIBRARY="{openssl_crypto}" '
            f'-DOPENSSL_SSL_LIBRARY="{openssl_ssl}" '
            f'-DBUILD_SHARED_LIBS=ON '
            f'-DTD_ENABLE_LTO=OFF '
            f'-DCMAKE_POLICY_DEFAULT_CMP0074=NEW',
            cwd=build_dir,
        )
        self.run(f"cmake --build . --target tdjson -- -j{os.cpu_count()}", cwd=build_dir)

        dylib = self._find_dylib(build_dir)

        self.run(f'install_name_tool -id "@executable_path/libtdjson.dylib" "{dylib}"')

        if arch == "armv7":
            machofix = os.path.join(self.build_folder, "machofix")
            if not os.path.isfile(machofix):
                self.run(f'cc -O2 -o "{machofix}" '
                         f'"{os.path.join(src, "fix-armv7-macho.c")}"')
            self.run(f'"{machofix}" "{dylib}"')

    def _openssl_paths(self):
        openssl = self.dependencies.host["openssl"]
        return (os.path.join(openssl.package_folder, "include"),
                os.path.join(openssl.package_folder, "lib", "libcrypto.a"),
                os.path.join(openssl.package_folder, "lib", "libssl.a"))

    def _find_dylib(self, build_dir):
        for dirpath, _, filenames in os.walk(build_dir):
            for filename in filenames:
                if filename.startswith("libtdjson") and filename.endswith(".dylib") and \
                        not os.path.islink(os.path.join(dirpath, filename)):
                    return os.path.join(dirpath, filename)
        raise ConanException("no dylib produced")

    def package(self):
        build_dir = os.path.join(self.build_folder, "cross-build")
        dylib = self._find_dylib(build_dir)
        copy(self, os.path.basename(dylib), os.path.dirname(dylib),
             os.path.join(self.package_folder, "lib"), keep_path=False)
        renamed = os.path.join(self.package_folder, "lib", os.path.basename(dylib))
        final = os.path.join(self.package_folder, "lib", "libtdjson.dylib")
        if renamed != final:
            os.replace(renamed, final)
        copy(self, "*.h",
             os.path.join(self.source_folder, "td", "telegram"),
             os.path.join(self.package_folder, "include", "td", "telegram"),
             keep_path=False)
        copy(self, "td_api.tl",
             os.path.join(self.source_folder, "td", "generate", "scheme"),
             os.path.join(self.package_folder, "res"), keep_path=False)

    def package_info(self):
        self.cpp_info.libs = ["tdjson"]
        self.cpp_info.libdirs = ["lib"]

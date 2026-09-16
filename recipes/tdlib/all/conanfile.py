import os
import shutil

from conan import ConanFile
from conan.errors import ConanException
from conan.tools.cmake import CMake, CMakeToolchain
from conan.tools.env import Environment
from conan.tools.files import apply_conandata_patches, copy, download
from conan.tools.scm import Git


_EMUTLS_DIR = "compiler-rt-builtins"
_EMULATED_TLS_VERSION = "9.0"
_SYSTEM_CALLS = ("clock_gettime", "fdopendir")


class TdlibConan(ConanFile):
    name = "tdlib"
    user = "itglegacy"
    channel = "stable"
    package_type = "shared-library"
    description = ("TDLib's libtdjson, fetched vanilla from upstream with this port's backgrounded VoIP "
                   "socket hook as a patch, built by its own CMake project with emulated thread-local storage "
                   "wherever the target compiler lacks real __thread")
    license = "BSL-1.0"
    homepage = "https://github.com/tdlib/td"

    python_requires = "charon-base/1.0@charon/stable", "charon-apple/1.0@charon/stable"
    python_requires_extend = "charon-base.CharonPort", "charon-apple.ApplePort"

    generators = "VirtualBuildEnv"

    exports_sources = "patches/*"

    def requirements(self):
        self.requires("openssl/4.0.2@itglegacy/stable")
        self.requires("libcxx/23.1.1@charon/stable")
        self.requires("apple-compat/1.0@charon/stable")

    def source(self):
        sources = self.conan_data["sources"][self.version]
        tdlib = sources["tdlib"]
        Git(self).fetch_commit(url=tdlib["url"], commit=tdlib["commit"])
        apply_conandata_patches(self)
        runtime = sources["compiler-rt-builtins"]
        for filename, checksum in runtime["files"].items():
            download(self, runtime["url"] + "/" + filename,
                     os.path.join(self.source_folder, _EMUTLS_DIR, filename),
                     sha256=checksum)

    def layout(self):
        super().layout()
        self.folders.build = "cross-build"

    @property
    def _cross_folder(self):
        return self.build_folder

    @property
    def _native_folder(self):
        return os.path.join(self.source_folder, "native-build")

    def _target_c_command(self):
        clang = shutil.which("clang") or "/usr/bin/clang"
        flags = " ".join(self.conf.get("tools.build:cflags", default=[], check_type=list))
        return (f'"{clang}" -arch {self.apple_architecture} -Os -isysroot "{self.sdk_path}" '
                f'-miphoneos-version-min={self.settings.os.version} {flags}')

    def _has_real_thread_local(self):
        clangxx = shutil.which("clang++") or "/usr/bin/clang++"
        probe = os.path.join(self.build_folder, "_tls_probe.cpp")
        os.makedirs(self.build_folder, exist_ok=True)
        with open(probe, "w") as handle:
            handle.write("static __thread int x;\nint main() { x = 1; return x; }\n")
        status = self.run(
            f'"{clangxx}" -arch {self.apple_architecture} -isysroot "{self.sdk_path}" '
            f'-miphoneos-version-min={self.settings.os.version} -fsyntax-only "{probe}"',
            ignore_errors=True, quiet=True)
        return status == 0

    def generate(self):
        super().generate()
        host_tools = Environment()
        host_tools.unset("IPHONEOS_DEPLOYMENT_TARGET")
        host_tools.vars(self, scope="hosttools").save_script("conanhosttoolsenv")

        libcxx = self.dependencies["libcxx"].cpp_info.components
        headers, runtime = libcxx["headers"], libcxx["runtime"]
        openssl = self.dependencies["openssl"].cpp_info.components
        compat = [self.dependencies["apple-compat"].cpp_info.components[call] for call in _SYSTEM_CALLS]

        toolchain = CMakeToolchain(self)
        toolchain.blocks.remove("find_paths")
        toolchain.extra_cflags = ["-Wno-error", f"-I{self.source_folder}",
                                  *(flag for component in compat for flag in component.cflags)]
        toolchain.extra_cxxflags = ["-Wno-error", f"-I{self.source_folder}",
                                    *(flag for component in compat for flag in component.cxxflags), *headers.cxxflags,
                                    *(f"-isystem {folder}" for folder in headers.includedirs),
                                    *(f"-D{define}" for define in runtime.defines)]
        toolchain.extra_sharedlinkflags = ["-nostdlib++",
                                           *(f"-L{folder}" for component in [*compat, runtime]
                                             for folder in component.libdirs),
                                           *dict.fromkeys(f"-l{library}" for component in [*compat, runtime]
                                                          for library in component.libs)]
        variables = toolchain.cache_variables
        variables.update({
            "BUILD_SHARED_LIBS": True,
            "TD_ENABLE_LTO": False,
            "ATOMICS_FOUND": True,
            "ATOMICS_LIBRARIES": "",
            "OPENSSL_INCLUDE_DIR": openssl["crypto"].includedirs[0],
            "OPENSSL_CRYPTO_LIBRARY": os.path.join(openssl["crypto"].libdirs[0], "libcrypto.a"),
            "OPENSSL_SSL_LIBRARY": os.path.join(openssl["ssl"].libdirs[0], "libssl.a"),
            "CMAKE_C_COMPILER_LAUNCHER": "ccache",
            "CMAKE_CXX_COMPILER_LAUNCHER": "ccache",
        })
        if self._has_real_thread_local():
            self.output.info("the target compiler has real __thread, so TDLib builds at the deployment target")
        else:
            self.output.info(
                f"no real __thread at iOS {self.settings.os.version}: compiling against iOS {_EMULATED_TLS_VERSION} "
                f"with -femulated-tls, linking compiler-rt's __emutls_get_address and recording iOS "
                f"{self.settings.os.version} in the Mach-O")
            toolchain.extra_cflags.append("-femulated-tls")
            toolchain.extra_cxxflags.append("-femulated-tls")
            toolchain.extra_sharedlinkflags += [os.path.join(self._cross_folder, "emutls.o"),
                                                f"-miphoneos-version-min={self.settings.os.version}"]
            variables["CMAKE_OSX_DEPLOYMENT_TARGET"] = _EMULATED_TLS_VERSION
        toolchain.generate()

    def _require(self, tool):
        if shutil.which(tool) is None:
            raise ConanException(f"{tool} not found on PATH (brew install {tool})")

    def build(self):
        for tool in ("cmake", "gperf", "ccache"):
            self._require(tool)

        if not os.path.isdir(self._native_folder):
            self.output.info("pregenerating sources with a native build")
            os.makedirs(self._native_folder)
            host_tools = ["conanbuild", "conanhosttoolsenv"]
            self.run(f'cmake -DTD_GENERATE_SOURCE_FILES=ON "{self.source_folder}"',
                     cwd=self._native_folder, env=host_tools)
            self.run("cmake --build . --target prepare_cross_compiling", cwd=self._native_folder, env=host_tools)

        os.makedirs(self._cross_folder, exist_ok=True)
        compile_c = self._target_c_command()
        builtins = os.path.join(self.source_folder, _EMUTLS_DIR)
        self.run(f'{compile_c} -I "{builtins}" -c "{os.path.join(builtins, "emutls.c")}" '
                 f'-o "{os.path.join(self._cross_folder, "emutls.o")}"')

        cmake = CMake(self)
        cmake.configure(build_script_folder=self.source_folder, variables={
            "CMAKE_BUILD_TYPE": "RelWithDebInfo",
            "CMAKE_C_FLAGS_RELWITHDEBINFO": "-Os -g -DNDEBUG",
            "CMAKE_CXX_FLAGS_RELWITHDEBINFO": "-Os -g -DNDEBUG",
        })
        cmake.build(target="tdjson")

    def _built_dylib(self):
        for dirpath, _, filenames in os.walk(self.build_folder):
            for filename in filenames:
                path = os.path.join(dirpath, filename)
                if filename.startswith("libtdjson") and filename.endswith(".dylib") and not os.path.islink(path):
                    return path
        raise ConanException("the build produced no libtdjson dylib")

    def package(self):
        dylib = self._built_dylib()
        copy(self, os.path.basename(dylib), os.path.dirname(dylib), os.path.join(self.package_folder, "lib"),
             keep_path=False)
        packaged = os.path.join(self.package_folder, "lib", os.path.basename(dylib))
        final = os.path.join(self.package_folder, "lib", "libtdjson.dylib")
        if packaged != final:
            os.replace(packaged, final)
        copy(self, "*.h", os.path.join(self.source_folder, "td", "telegram"),
             os.path.join(self.package_folder, "include", "td", "telegram"), keep_path=False)
        copy(self, "td_api.tl", os.path.join(self.source_folder, "td", "generate", "scheme"),
             os.path.join(self.package_folder, "res"), keep_path=False)

    def package_info(self):
        self.cpp_info.libs = ["tdjson"]
        self.cpp_info.requires = ["openssl::crypto", "openssl::ssl", "libcxx::runtime",
                                  *(f"apple-compat::{call}" for call in _SYSTEM_CALLS)]

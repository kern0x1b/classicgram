import os

from conan import ConanFile
from conan.errors import ConanException
from conan.tools.cmake import CMake, CMakeToolchain
from conan.tools.env import Environment
from conan.tools.files import apply_conandata_patches, copy
from conan.tools.scm import Git


_EMULATED_TLS_VERSION = "9.0"


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

    def build_requirements(self):
        self.tool_requires("gperf/3.1")

    def source(self):
        tdlib = self.conan_data["sources"][self.version]
        Git(self).fetch_commit(url=tdlib["url"], commit=tdlib["commit"])
        apply_conandata_patches(self)

    def layout(self):
        super().layout()
        self.folders.build = "cross-build"

    @property
    def _native_folder(self):
        return os.path.join(self.source_folder, "native-build")

    def _has_real_thread_local(self):
        probe = os.path.join(self.build_folder, "_tls_probe.cpp")
        os.makedirs(self.build_folder, exist_ok=True)
        with open(probe, "w") as handle:
            handle.write("static __thread int x;\nint main() { x = 1; return x; }\n")
        status = self.run(
            f'clang++ -arch {self.apple_architecture} -isysroot "{self.sdk_path}" '
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
        compat = list(self.dependencies["apple-compat"].cpp_info.components.values())

        toolchain = CMakeToolchain(self)
        toolchain.blocks.remove("find_paths")
        toolchain.extra_cflags = [flag for component in compat for flag in component.cflags]
        toolchain.extra_cxxflags = [*(flag for component in compat for flag in component.cxxflags), *headers.cxxflags,
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
            "OPENSSL_INCLUDE_DIR": openssl["crypto"].includedirs[0],
            "OPENSSL_CRYPTO_LIBRARY": os.path.join(openssl["crypto"].libdirs[0], "libcrypto.a"),
            "OPENSSL_SSL_LIBRARY": os.path.join(openssl["ssl"].libdirs[0], "libssl.a"),
        })
        if self._has_real_thread_local():
            self.output.info("the target compiler has real __thread, so TDLib builds at the deployment target")
        else:
            self.output.info(
                f"no real __thread at iOS {self.settings.os.version}: compiling against iOS {_EMULATED_TLS_VERSION} "
                f"with -femulated-tls, taking __emutls_get_address from the compiler's own runtime and recording iOS "
                f"{self.settings.os.version} in the Mach-O")
            toolchain.extra_cflags.append("-femulated-tls")
            toolchain.extra_cxxflags.append("-femulated-tls")
            toolchain.extra_sharedlinkflags.append(f"-miphoneos-version-min={self.settings.os.version}")
            variables["CMAKE_OSX_DEPLOYMENT_TARGET"] = _EMULATED_TLS_VERSION
        toolchain.generate()

    def build(self):
        if not os.path.isdir(self._native_folder):
            self.output.info("pregenerating sources with a native build")
            os.makedirs(self._native_folder)
            host_tools = ["conanbuild", "conanhosttoolsenv"]
            self.run(f'cmake -DTD_GENERATE_SOURCE_FILES=ON "{self.source_folder}"',
                     cwd=self._native_folder, env=host_tools)
            self.run("cmake --build . --target prepare_cross_compiling", cwd=self._native_folder, env=host_tools)

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

    def _compat_calls(self):
        return list(self.dependencies["apple-compat"].cpp_info.components)

    def package_info(self):
        self.cpp_info.libs = ["tdjson"]
        self.cpp_info.requires = ["openssl::crypto", "openssl::ssl", "libcxx::runtime",
                                  *(f"apple-compat::{call}" for call in self._compat_calls())]

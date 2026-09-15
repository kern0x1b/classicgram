import os
import shutil

from conan import ConanFile
from conan.errors import ConanException
from conan.tools.apple import to_apple_arch
from conan.tools.files import copy, replace_in_file
from conan.tools.scm import Git


_TLS_REPLACEMENTS = [
    ("td/telegram/ClientJson.cpp", [
        ('#include "td/utils/port/thread_local.h"\n#include "td/utils/SliceBuilder.h"',
         '#include "td/utils/port/thread_local.h"\n#include "compat/emulated_tls.h"\n'
         '#include "td/utils/SliceBuilder.h"'),
        ('static TD_THREAD_LOCAL string *current_output;\n\n'
         'static const char *store_string(string str) {\n'
         '  init_thread_local<string>(current_output);',
         'static const char *store_string(string str) {\n'
         '  TD_EMULATED_TLS_LOCAL(string *, current_output);\n'
         '  init_thread_local<string>(current_output);'),
    ]),
    ("td/telegram/net/Session.cpp", [
        ('#include "td/utils/port/thread_local.h"\n#include "td/utils/Random.h"',
         '#include "td/utils/port/thread_local.h"\n#include "compat/emulated_tls.h"\n'
         '#include "td/utils/Random.h"'),
        ('  static TD_THREAD_LOCAL Semaphore *semaphore_;\n'
         '  Semaphore &get_handshake_semaphore() {\n'
         '    auto old_context = set_context(std::make_shared<ActorContext>());\n'
         '    auto old_tag = set_tag(string());\n'
         '    init_thread_local<Semaphore>(semaphore_, 50);\n'
         '    set_context(std::move(old_context));\n'
         '    set_tag(std::move(old_tag));\n'
         '    return *semaphore_;\n'
         '  }',
         '  static Semaphore *&semaphore_();\n'
         '  Semaphore &get_handshake_semaphore() {\n'
         '    auto old_context = set_context(std::make_shared<ActorContext>());\n'
         '    auto old_tag = set_tag(string());\n'
         '    init_thread_local<Semaphore>(semaphore_(), 50);\n'
         '    set_context(std::move(old_context));\n'
         '    set_tag(std::move(old_tag));\n'
         '    return *semaphore_();\n'
         '  }'),
        ('TD_THREAD_LOCAL Semaphore *GenAuthKeyActor::semaphore_{};',
         'Semaphore *&GenAuthKeyActor::semaphore_() {\n'
         '  return ::td::detail::emulated_tls_ref<Semaphore *, __COUNTER__>();\n'
         '}'),
    ]),
    ("tdactor/td/actor/ConcurrentScheduler.cpp", [
        ('#include "td/utils/port/thread_local.h"\n#include "td/utils/ScopeGuard.h"',
         '#include "td/utils/port/thread_local.h"\n#include "compat/emulated_tls.h"\n'
         '#include "td/utils/ScopeGuard.h"'),
        ('static TD_THREAD_LOCAL double emscripten_timeout;',
         'static double &emscripten_timeout() {\n'
         '  return ::td::detail::emulated_tls_ref<double, __COUNTER__>();\n'
         '}'),
        ('  emscripten_timeout = get_main_timeout().at();',
         '  emscripten_timeout() = get_main_timeout().at();'),
        ('  return Timestamp::at(emscripten_timeout).in();',
         '  return Timestamp::at(emscripten_timeout()).in();'),
        ('  emscripten_timeout = 0;',
         '  emscripten_timeout() = 0;'),
    ]),
    ("tdactor/td/actor/impl/Scheduler-decl.h", [
        ('  static TD_THREAD_LOCAL Scheduler *scheduler_;\n'
         '  static TD_THREAD_LOCAL ActorContext *context_;',
         '  static Scheduler *&scheduler_();\n'
         '  static ActorContext *&context_();'),
    ]),
    ("tdactor/td/actor/impl/Scheduler.cpp", [
        ('#include "td/utils/port/thread_local.h"\n#include "td/utils/Promise.h"',
         '#include "td/utils/port/thread_local.h"\n#include "compat/emulated_tls.h"\n'
         '#include "td/utils/Promise.h"'),
        ('TD_THREAD_LOCAL Scheduler *Scheduler::scheduler_;   // static zero-initialized\n'
         'TD_THREAD_LOCAL ActorContext *Scheduler::context_;  // static zero-initialized',
         'Scheduler *&Scheduler::scheduler_() {\n'
         '  return ::td::detail::emulated_tls_ref<Scheduler *, __COUNTER__>();\n'
         '}\n'
         'ActorContext *&Scheduler::context_() {\n'
         '  return ::td::detail::emulated_tls_ref<ActorContext *, __COUNTER__>();\n'
         '}'),
        ('Scheduler *Scheduler::instance() {\n'
         '  return scheduler_;\n'
         '}',
         'Scheduler *Scheduler::instance() {\n'
         '  return scheduler_();\n'
         '}'),
        ('ActorContext *&Scheduler::context() {\n'
         '  return context_;\n'
         '}',
         'ActorContext *&Scheduler::context() {\n'
         '  return context_();\n'
         '}'),
        ('  LOG_TAG = context_->tag_;',
         '  LOG_TAG = context_()->tag_;'),
        ('void Scheduler::set_scheduler(Scheduler *scheduler) {\n'
         '  scheduler_ = scheduler;\n'
         '}',
         'void Scheduler::set_scheduler(Scheduler *scheduler) {\n'
         '  scheduler_() = scheduler;\n'
         '}'),
        ('  ActorContext *current_context = context_;\n'
         '  context_ = empty_context.get();\n'
         '\n'
         '  const char *current_tag = LOG_TAG;\n'
         '  LOG_TAG = nullptr;\n'
         '\n'
         '  run_on_scheduler(sched_id, std::move(action));\n'
         '\n'
         '  context_ = current_context;',
         '  ActorContext *current_context = context_();\n'
         '  context_() = empty_context.get();\n'
         '\n'
         '  const char *current_tag = LOG_TAG;\n'
         '  LOG_TAG = nullptr;\n'
         '\n'
         '  run_on_scheduler(sched_id, std::move(action));\n'
         '\n'
         '  context_() = current_context;'),
    ]),
    ("tdutils/td/utils/BufferedUdp.cpp", [
        ('#include "td/utils/BufferedUdp.h"\n\nchar disable_linker_warning',
         '#include "td/utils/BufferedUdp.h"\n#include "compat/emulated_tls.h"\n\n'
         'char disable_linker_warning'),
        ('TD_THREAD_LOCAL detail::UdpReader *BufferedUdp::udp_reader_;',
         'detail::UdpReader *&BufferedUdp::udp_reader_() {\n'
         '  return ::td::detail::emulated_tls_ref<detail::UdpReader *, __COUNTER__>();\n'
         '}'),
    ]),
    ("tdutils/td/utils/BufferedUdp.h", [
        ('    init_thread_local<detail::UdpReader>(udp_reader_);\n'
         '    return udp_reader_->read_once(as_fd(), input_);\n'
         '  }\n'
         '\n'
         '  static TD_THREAD_LOCAL detail::UdpReader *udp_reader_;',
         '    init_thread_local<detail::UdpReader>(udp_reader_());\n'
         '    return udp_reader_()->read_once(as_fd(), input_);\n'
         '  }\n'
         '\n'
         '  static detail::UdpReader *&udp_reader_();'),
    ]),
    ("tdutils/td/utils/Context.h", [
        ('#include "td/utils/port/thread_local.h"\n\nnamespace td {',
         '#include "td/utils/port/thread_local.h"\n#include "compat/emulated_tls.h"\n\n'
         'namespace td {'),
        ('  static Impl *get() {\n'
         '    return context_;\n'
         '  }\n'
         '  class Guard {\n'
         '   public:\n'
         '    explicit Guard(Impl *new_context) {\n'
         '      old_context_ = context_;\n'
         '      context_ = new_context;\n'
         '    }\n'
         '    ~Guard() {\n'
         '      context_ = old_context_;\n'
         '    }',
         '  static Impl *get() {\n'
         '    return context_();\n'
         '  }\n'
         '  class Guard {\n'
         '   public:\n'
         '    explicit Guard(Impl *new_context) {\n'
         '      old_context_ = context_();\n'
         '      context_() = new_context;\n'
         '    }\n'
         '    ~Guard() {\n'
         '      context_() = old_context_;\n'
         '    }'),
        (' private:\n'
         '  static TD_THREAD_LOCAL Impl *context_;\n'
         '};\n'
         '\n'
         'template <class Impl>\n'
         'TD_THREAD_LOCAL Impl *Context<Impl>::context_;\n'
         '\n'
         '}  // namespace td',
         ' private:\n'
         '  static Impl *&context_() {\n'
         '    return ::td::detail::emulated_tls_ref<Impl *, 0>();\n'
         '  }\n'
         '};\n'
         '\n'
         '}  // namespace td'),
    ]),
    ("tdutils/td/utils/Random.cpp", [
        ('#include "td/utils/port/thread_local.h"\n\n#if TD_HAVE_OPENSSL',
         '#include "td/utils/port/thread_local.h"\n#include "compat/emulated_tls.h"\n\n'
         '#if TD_HAVE_OPENSSL'),
        ('  static TD_THREAD_LOCAL unsigned char *buf;  // static zero-initialized\n'
         '  static TD_THREAD_LOCAL size_t buf_pos;\n'
         '  static TD_THREAD_LOCAL int64 generation;',
         '  TD_EMULATED_TLS_LOCAL(unsigned char *, buf);  // static zero-initialized\n'
         '  TD_EMULATED_TLS_LOCAL(size_t, buf_pos);\n'
         '  TD_EMULATED_TLS_LOCAL(int64, generation);'),
        ('  static TD_THREAD_LOCAL std::random_device *rd;',
         '  TD_EMULATED_TLS_LOCAL(std::random_device *, rd);'),
        ('  static TD_THREAD_LOCAL std::mt19937 *gen;',
         '  TD_EMULATED_TLS_LOCAL(std::mt19937 *, gen);'),
        ('  static TD_THREAD_LOCAL std::mt19937_64 *gen;',
         '  TD_EMULATED_TLS_LOCAL(std::mt19937_64 *, gen);'),
    ]),
    ("tdutils/td/utils/StackAllocator.cpp", [
        ('#include "td/utils/port/thread_local.h"\n\n#include <array>',
         '#include "td/utils/port/thread_local.h"\n#include "compat/emulated_tls.h"\n\n'
         '#include <array>'),
        ('    static TD_THREAD_LOCAL ArrayAllocator *array_allocator;  // static zero-initialized',
         '    TD_EMULATED_TLS_LOCAL(ArrayAllocator *, array_allocator);  // static zero-initialized'),
    ]),
    ("tdutils/td/utils/Status.cpp", [
        ('#include "td/utils/port/thread_local.h"\n\n#include <string.h>',
         '#include "td/utils/port/thread_local.h"\n#include "compat/emulated_tls.h"\n\n'
         '#include <string.h>'),
        ('  static TD_THREAD_LOCAL char *buf;',
         '  TD_EMULATED_TLS_LOCAL(char *, buf);'),
    ]),
    ("tdutils/td/utils/StringBuilder.cpp", [
        ('#include "td/utils/port/thread_local.h"\n\n#include <cstdio>',
         '#include "td/utils/port/thread_local.h"\n#include "compat/emulated_tls.h"\n\n'
         '#include <cstdio>'),
        ('  static TD_THREAD_LOCAL std::stringstream *ss;',
         '  TD_EMULATED_TLS_LOCAL(std::stringstream *, ss);'),
    ]),
    ("tdutils/td/utils/buffer.cpp", [
        ('#include "td/utils/port/thread_local.h"\n\n#include <cstddef>',
         '#include "td/utils/port/thread_local.h"\n#include "compat/emulated_tls.h"\n\n'
         '#include <cstddef>'),
        ('TD_THREAD_LOCAL BufferAllocator::BufferRawTls *BufferAllocator::buffer_raw_tls;  '
         '// static zero-initialized',
         'BufferAllocator::BufferRawTls *&BufferAllocator::buffer_raw_tls() {\n'
         '  return ::td::detail::emulated_tls_ref<BufferAllocator::BufferRawTls *, __COUNTER__>();\n'
         '}'),
        ('  init_thread_local<BufferRawTls>(buffer_raw_tls);\n'
         '\n'
         '  auto buffer_raw = buffer_raw_tls->buffer_raw.get();\n'
         '  if (buffer_raw == nullptr || buffer_raw->data_size_ - '
         'buffer_raw->end_.load(std::memory_order_relaxed) < size) {\n'
         '    buffer_raw = create_buffer_raw(4096 * 4);\n'
         '    buffer_raw_tls->buffer_raw = std::unique_ptr<BufferRaw, '
         'BufferAllocator::BufferRawDeleter>(buffer_raw);',
         '  init_thread_local<BufferRawTls>(buffer_raw_tls());\n'
         '\n'
         '  auto buffer_raw = buffer_raw_tls()->buffer_raw.get();\n'
         '  if (buffer_raw == nullptr || buffer_raw->data_size_ - '
         'buffer_raw->end_.load(std::memory_order_relaxed) < size) {\n'
         '    buffer_raw = create_buffer_raw(4096 * 4);\n'
         '    buffer_raw_tls()->buffer_raw = std::unique_ptr<BufferRaw, '
         'BufferAllocator::BufferRawDeleter>(buffer_raw);'),
    ]),
    ("tdutils/td/utils/buffer.h", [
        ('  static TD_THREAD_LOCAL BufferRawTls *buffer_raw_tls;',
         '  static BufferRawTls *&buffer_raw_tls();'),
    ]),
    ("tdutils/td/utils/crypto.cpp", [
        ('#include "td/utils/port/thread_local.h"\n#include "td/utils/Random.h"',
         '#include "td/utils/port/thread_local.h"\n#include "compat/emulated_tls.h"\n'
         '#include "td/utils/Random.h"'),
        ('    static TD_THREAD_LOCAL const EVP_CIPHER *evp_cipher;',
         '    TD_EMULATED_TLS_LOCAL(const EVP_CIPHER *, evp_cipher);'),
        ('  static TD_THREAD_LOCAL EVP_MD_CTX *ctx;\n'
         '  if (unlikely(ctx == nullptr)) {\n'
         '    ctx = EVP_MD_CTX_new();\n'
         '    LOG_IF(FATAL, ctx == nullptr);\n'
         '    detail::add_thread_local_destructor(create_destructor([] {\n'
         '      EVP_MD_CTX_free(ctx);\n'
         '      ctx = nullptr;\n'
         '    }));',
         '  TD_EMULATED_TLS_LOCAL(EVP_MD_CTX *, ctx);\n'
         '  if (unlikely(ctx == nullptr)) {\n'
         '    ctx = EVP_MD_CTX_new();\n'
         '    LOG_IF(FATAL, ctx == nullptr);\n'
         '    detail::add_thread_local_destructor(create_destructor([&ctx] {\n'
         '      EVP_MD_CTX_free(ctx);\n'
         '      ctx = nullptr;\n'
         '    }));'),
        ('  static TD_THREAD_LOCAL const EVP_MD_CTX *evp_md_ctx;',
         '  TD_EMULATED_TLS_LOCAL(const EVP_MD_CTX *, evp_md_ctx);'),
        ('  static TD_THREAD_LOCAL int id;',
         '  TD_EMULATED_TLS_LOCAL(int, id);'),
        ('  static TD_THREAD_LOCAL EVP_MAC_CTX *ctx = nullptr;',
         '  TD_EMULATED_TLS_LOCAL(EVP_MAC_CTX *, ctx);'),
    ]),
    ("tdutils/td/utils/logging.cpp", [
        ('#include "td/utils/TsCerr.h"\n\n#include <atomic>',
         '#include "td/utils/TsCerr.h"\n#include "compat/emulated_tls.h"\n\n#include <atomic>'),
        ('TD_THREAD_LOCAL const char *Logger::tag_ = nullptr;\n'
         'TD_THREAD_LOCAL const char *Logger::tag2_ = nullptr;',
         'const char *&Logger::tag_() {\n'
         '  return ::td::detail::emulated_tls_ref<const char *, __COUNTER__>();\n'
         '}\n'
         'const char *&Logger::tag2_() {\n'
         '  return ::td::detail::emulated_tls_ref<const char *, __COUNTER__>();\n'
         '}'),
        ('  if (tag_ != nullptr && *tag_) {\n'
         '    sb_ << "[#" << Slice(tag_) << \']\';\n'
         '  }\n'
         '\n'
         '  // context from tag2_\n'
         '  if (tag2_ != nullptr && *tag2_) {\n'
         '    sb_ << "[!" << Slice(tag2_) << \']\';\n'
         '  }',
         '  if (tag_() != nullptr && *tag_()) {\n'
         '    sb_ << "[#" << Slice(tag_()) << \']\';\n'
         '  }\n'
         '\n'
         '  // context from tag2_\n'
         '  if (tag2_() != nullptr && *tag2_()) {\n'
         '    sb_ << "[!" << Slice(tag2_()) << \']\';\n'
         '  }'),
    ]),
    ("tdutils/td/utils/logging.h", [
        ('#define LOG_TAG ::td::Logger::tag_\n'
         '#define LOG_TAG2 ::td::Logger::tag2_',
         '#define LOG_TAG ::td::Logger::tag_()\n'
         '#define LOG_TAG2 ::td::Logger::tag2_()'),
        ('  static TD_THREAD_LOCAL const char *tag_;\n'
         '  static TD_THREAD_LOCAL const char *tag2_;',
         '  static const char *&tag_();\n'
         '  static const char *&tag2_();'),
    ]),
    ("tdutils/td/utils/misc.cpp", [
        ('#include "td/utils/utf8.h"\n\n#include <algorithm>',
         '#include "td/utils/utf8.h"\n#include "compat/emulated_tls.h"\n\n#include <algorithm>'),
        ('  static TD_THREAD_LOCAL std::stringstream *ss;',
         '  TD_EMULATED_TLS_LOCAL(std::stringstream *, ss);'),
    ]),
    ("tdutils/td/utils/port/IPAddress.cpp", [
        ('#include "td/utils/port/thread_local.h"\n#include "td/utils/ScopeGuard.h"',
         '#include "td/utils/port/thread_local.h"\n#include "compat/emulated_tls.h"\n'
         '#include "td/utils/ScopeGuard.h"'),
        ('  static TD_THREAD_LOCAL char *buf;',
         '  TD_EMULATED_TLS_LOCAL(char *, buf);'),
    ]),
    ("tdutils/td/utils/port/thread_local.cpp", [
        ('#include "td/utils/port/thread_local.h"\n\nnamespace td {',
         '#include "td/utils/port/thread_local.h"\n#include "compat/emulated_tls.h"\n\n'
         'namespace td {'),
        ('static TD_THREAD_LOCAL int32 thread_id_;\n'
         'static TD_THREAD_LOCAL std::vector<unique_ptr<Destructor>> *thread_local_destructors;\n'
         '\n'
         'void add_thread_local_destructor(unique_ptr<Destructor> destructor) {\n'
         '  if (thread_local_destructors == nullptr) {\n'
         '    thread_local_destructors = new std::vector<unique_ptr<Destructor>>();\n'
         '  }\n'
         '  thread_local_destructors->push_back(std::move(destructor));\n'
         '}',
         'TD_EMULATED_TLS_MEMBER(int32, thread_id_)\n'
         'TD_EMULATED_TLS_MEMBER(std::vector<unique_ptr<Destructor>> *, thread_local_destructors)\n'
         '\n'
         'void add_thread_local_destructor(unique_ptr<Destructor> destructor) {\n'
         '  if (thread_local_destructors() == nullptr) {\n'
         '    thread_local_destructors() = new std::vector<unique_ptr<Destructor>>();\n'
         '  }\n'
         '  thread_local_destructors()->push_back(std::move(destructor));\n'
         '}'),
        ('  auto to_delete = detail::thread_local_destructors;\n'
         '  detail::thread_local_destructors = nullptr;\n'
         '  delete to_delete;\n'
         '  CHECK(detail::thread_local_destructors == nullptr);\n'
         '}\n'
         '\n'
         'void set_thread_id(int32 id) {\n'
         '  detail::thread_id_ = id;\n'
         '}\n'
         '\n'
         'int32 get_thread_id() {\n'
         '  return detail::thread_id_;\n'
         '}',
         '  auto to_delete = detail::thread_local_destructors();\n'
         '  detail::thread_local_destructors() = nullptr;\n'
         '  delete to_delete;\n'
         '  CHECK(detail::thread_local_destructors() == nullptr);\n'
         '}\n'
         '\n'
         'void set_thread_id(int32 id) {\n'
         '  detail::thread_id_() = id;\n'
         '}\n'
         '\n'
         'int32 get_thread_id() {\n'
         '  return detail::thread_id_();\n'
         '}'),
    ]),
    ("tdutils/td/utils/simple_tests.h", [
        ('#include "td/utils/port/thread_local.h"\n#include "td/utils/Slice.h"',
         '#include "td/utils/port/thread_local.h"\n#include "compat/emulated_tls.h"\n'
         '#include "td/utils/Slice.h"'),
        ('    static TD_THREAD_LOCAL DebugContext *instance{};',
         '    TD_EMULATED_TLS_LOCAL(DebugContext *, instance);'),
    ]),
]

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

_TDLIB_COMMIT = "022d60202e446ad1287b9fb68e687c8a0760788b"
_TDLIB_URL = "https://github.com/tdlib/td.git"


class TdlibConan(ConanFile):
    name = "tdlib"
    user = "ios6"
    channel = "stable"
    version = "1.8.0"
    package_type = "shared-library"
    description = ("TDLib's libtdjson, fetched vanilla from upstream, with the iOS 6 "
                   "thread-local-storage emulation applied only where the target compiler "
                   "genuinely lacks real __thread support, plus the backgrounded VoIP socket "
                   "hook this port always needs")
    license = "BSL-1.0"
    homepage = "https://github.com/tdlib/td"

    python_requires = "ios6-base/1.0@ios6/stable"
    python_requires_extend = "ios6-base.Ios6Port"

    exports_sources = "compat/*", "fix-armv7-macho.c"

    def source(self):
        Git(self).fetch_commit(url=_TDLIB_URL, commit=_TDLIB_COMMIT)

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

    def _require(self, tool):
        if shutil.which(tool) is None:
            raise ConanException(f"{tool} not found on PATH (brew install {tool})")

    def build(self):
        for tool in ("cmake", "gperf", "ccache"):
            self._require(tool)

        self._apply_replacements(_VOIP_BACKGROUND_REPLACEMENTS)
        if not self._has_real_thread_local():
            self.output.info("target has no real __thread support - applying TLS emulation")
            self._apply_replacements(_TLS_REPLACEMENTS)
        else:
            self.output.info("target compiler supports real __thread - TDLib stays vanilla for it")

        src = self.source_folder
        arch = self._apple_arch()
        min_version = str(self.settings.os.version)
        sdk = self._real_sdk_path()
        clang = shutil.which("clang") or "/usr/bin/clang"
        clangxx = shutil.which("clang++") or "/usr/bin/clang++"

        cxx_stdlib_inc = ""
        root = os.environ.get("ITGLEGACY_ROOT")
        if root:
            for sdk_name in ("iPhoneOS16.5.sdk", "iPhoneOS15.6.sdk"):
                candidate = os.path.join(root, "build", "sdks", sdk_name, "usr", "include", "c++", "v1")
                if os.path.isdir(candidate):
                    cxx_stdlib_inc = f"-isystem {candidate}"
                    break

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

        openssl_include, openssl_crypto, openssl_ssl = self._openssl_paths(arch)

        linker_flags = f"-install_name @executable_path/libtdjson.dylib {compat_o}"
        if "ld64" in self.dependencies.build:
            ld64 = self.dependencies.build["ld64"]
            linker_flags = f"-B{ld64.package_folder}/bin {linker_flags}"

        c_flags = f"-Wno-error {arch_flag} -Os -g -I{src}"
        cxx_flags = f"{c_flags} {cxx_stdlib_inc}"

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
            f'-DCMAKE_OSX_DEPLOYMENT_TARGET={min_version} '
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

    def _openssl_paths(self, arch):
        if "openssl" in self.dependencies.host:
            openssl = self.dependencies.host["openssl"]
            return (os.path.join(openssl.package_folder, "include"),
                    os.path.join(openssl.package_folder, "lib", "libcrypto.a"),
                    os.path.join(openssl.package_folder, "lib", "libssl.a"))
        root = os.environ.get("ITGLEGACY_ROOT")
        if not root:
            raise ConanException(
                "openssl is not a requires() of this recipe yet and ITGLEGACY_ROOT is not set - "
                "point it at the iTgLegacy checkout to use its prebuilt OpenSSL libs "
                "as a stopgap until openssl/x.y.z@ios6/stable exists")
        return (os.path.join(root, "third_party", "openssl", "prebuilt", "include"),
                os.path.join(root, "build", arch, "libs", "libcrypto.a"),
                os.path.join(root, "build", arch, "libs", "libssl.a"))

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

    def package_info(self):
        self.cpp_info.libs = ["tdjson"]
        self.cpp_info.libdirs = ["lib"]

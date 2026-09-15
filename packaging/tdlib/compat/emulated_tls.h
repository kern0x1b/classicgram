#pragma once

#include <pthread.h>
#include <new>

namespace td {
namespace detail {
template <class T, int Tag>
T &emulated_tls_ref() {
  static pthread_key_t key = [] {
    pthread_key_t k;
    pthread_key_create(&k, [](void *p) { delete static_cast<T *>(p); });
    return k;
  }();
  auto *p = static_cast<T *>(pthread_getspecific(key));
  if (p == nullptr) {
    p = new T();
    pthread_setspecific(key, p);
  }
  return *p;
}
}
}

#define TD_EMULATED_TLS_LOCAL(Type, Name) auto &Name = ::td::detail::emulated_tls_ref<Type, __COUNTER__>()

#define TD_EMULATED_TLS_MEMBER(Type, Name) \
  static Type &Name() { return ::td::detail::emulated_tls_ref<Type, __COUNTER__>(); }

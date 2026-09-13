#include <pthread.h>
#include <stdlib.h>
#include <stdint.h>

struct TLVDescriptor {
    void* (*thunk)(struct TLVDescriptor*);
    unsigned long key;
    unsigned long offset;
};

static char main_thread_tlv_storage[65536];

__attribute__((visibility("default")))
void* __tlv_bootstrap(struct TLVDescriptor* tlv) {
    if (!tlv) return NULL;

    if (tlv->offset < sizeof(main_thread_tlv_storage)) {
        return &main_thread_tlv_storage[tlv->offset];
    }

    return NULL;
}

__attribute__((visibility("default")))
void __tlv_atexit(void (*dtor)(void*), void* obj) {
    (void)dtor;
    (void)obj;
}

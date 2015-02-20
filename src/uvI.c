#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <execinfo.h>

#include "it.h"
#include "uvI.h"


static uvI_thread_t* pool;


uv_lib_t* uvI_dlopen(const char* filename) {
    uv_lib_t* lib = (uv_lib_t*) malloc(sizeof(uv_lib_t));
    if (!lib) it_errors("malloc(sizeof(uv_lib_t)): failed to create");
    if (uv_dlopen(filename, lib))
        uvI_dlerror(lib, "uv_dlopen: failed to open %s", filename);
    return lib;
}


void uvI_init() {
    static int inited = FALSE;
    if (inited) return;
    inited = TRUE;

    pool = NULL;
    pool = uvI_thread_tmp();
    if (!pool) it_errors("failed to create thread pool!");
}

uvI_thread_t* uvI_thread_malloc() {
    uvI_thread_t* thread = (uvI_thread_t*) calloc(1, sizeof(uvI_thread_t));
    if (!thread) return NULL;
    thread->backtrace = (uvI_stacktrace_t*) malloc(sizeof(uvI_stacktrace_t));
    if (!thread->backtrace) {
        free(thread);
        return NULL;
    }
    thread->safe = TRUE;
    thread->size = C_STACK_MINSIZE;
    thread->backtrace->count = 0;
    return thread;
}

uvI_thread_t* uvI_thread_new() {
    uvI_thread_t* thread = uvI_thread_malloc();
    if (!thread) return NULL;
    // append to pool
    uvI_thread_t* next = pool;
    while (next->next) next = next->next;
    next->next = thread;
    return thread;
}

uvI_thread_t* uvI_thread_tmp() {
    uvI_thread_t* thread = uvI_thread_malloc();
    if (!thread) return NULL;
    thread->pthread = pthread_self();
    // prepend tmps to pool
    thread->next = pool;
    pool = thread;
    return thread;
}

int uvI_thread_create(uvI_thread_t* thread, void (*entry)(void *arg), void* arg) {
    return uv_thread_create(&(thread->pthread), entry, arg);
}

uvI_thread_t* uvI_thread_self() {
    return uvI_thread_pool(pthread_self());
}

uvI_thread_t* uvI_thread_pool(const uv_thread_t pthread) {
    uvI_thread_t* next = pool;
    while (next) {
        if (pthread_equal(pthread, next->pthread))
            return next;
        next = next->next;
    }
    return NULL;
}

int uvI_thread_pool_index(const uv_thread_t pthread) {
    uvI_thread_t* next = pool;
    int i = 0;
    while (next) {
        if (pthread_equal(pthread, next->pthread))
            return i;
        next = next->next;
        i++;
    }
    return -1;
}

int uvI_thread_notch(uvI_thread_t* thread) {
    int pos = thread->count;
    if (++(thread->count) < thread->size)
        return pos;
    int old_size = thread->size;
    thread->size = thread->size == 0 ? 1 : 2 * thread->size;
    // resize struct, since it contains full jmp_buf
    thread = // stub to disable attribute warn_unused_result (noop)
    realloc(thread, sizeof(uvI_thread_t) +
                    sizeof(jmp_buf) *
                    (thread->size - old_size - C_STACK_MINSIZE));
    return pos;
}

void uvI_thread_unnotch(uvI_thread_t* thread) {
    --(thread->count);
}

void uvI_thread_stacktrace(uvI_thread_t* thread) {
    thread->backtrace->count = backtrace(thread->backtrace->addrs, BACK_TRACE_SIZE);
}

void uvI_thread_jmp(uvI_thread_t* thread, int num) {
    longjmp(thread->jmp[thread->count - 1], num);
}

void uvI_thread_free(uvI_thread_t* thread) {
    if (!thread) return;
    // remove from pool
    if (thread == pool) {
        pool = thread->next;
    } else {
        uvI_thread_t* next = pool;
        while (next->next) {
            if (next->next == thread) {
                if (thread->next) {
                    next->next = thread->next;
                } else {
                    next->next = NULL;
                }
                break;
            }
            next = next->next;
        }
    }
    // free all mallocd
    free(thread->backtrace);
    free(thread);
}

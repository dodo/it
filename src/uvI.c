#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <execinfo.h>

#include "it.h"
#include "uvI.h"


uvI_thread_t pool;


uv_lib_t* uvI_dlopen(const char* filename) {
    uv_lib_t* lib = malloc(sizeof(uv_lib_t));
    if (!lib) it_errors("malloc(sizeof(uv_lib_t)): failed to create");
    if (uv_dlopen(filename, lib))
        uvI_dlerror(lib, "uv_dlopen: failed to open %s", filename);
    return lib;
}


void uvI_init() {
    static int inited = FALSE;
    if (inited) return;
    inited = TRUE;

    pool.next = NULL;
    pool.count = 0;
    pool.pthread = pthread_self();
    pool.backtrace = malloc(sizeof(uvI_stacktrace_t));
    if (!pool.backtrace)
        it_errors("malloc(sizeof(uvI_stacktrace_t)) failed!");
    pool.backtrace->count = 0;
}

uvI_thread_t* uvI_thread_new() {
    uvI_thread_t* thread = malloc(sizeof(uvI_thread_t));
    if (!thread) return NULL;
    thread->next = NULL;
    thread->count = 0;
    thread->backtrace = malloc(sizeof(uvI_stacktrace_t));
    if (!thread->backtrace) {
        free(thread);
        return NULL;
    }
    thread->backtrace->count = 0;
    // append to pool
    uvI_thread_t* next = &pool;
    while (next->next) next = next->next;
    next->next = thread;
    return thread;
}

int uvI_thread_create(uvI_thread_t* thread, void (*entry)(void *arg), void* arg) {
    return uv_thread_create(&(thread->pthread), entry, arg);
}

uvI_thread_t* uvI_thread_self() {
    return uvI_thread_pool(pthread_self());
}

uvI_thread_t* uvI_thread_pool(const uv_thread_t pthread) {
    uvI_thread_t* next = &pool;
    while (next) {
        if (pthread_equal(pthread, next->pthread))
            return next;
        next = next->next;
    }
    return NULL;
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
    uvI_thread_t* next = &pool;
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
    // free all mallocd
    free(thread->backtrace);
    free(thread);
}

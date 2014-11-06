#ifndef UVI_H
#define UVI_H

#include <uv.h>

#include "it-errors.h"


#define uvI_dlsym(lib, name, var) \
    do{ if (uv_dlsym(lib,name, (void**) (var))) \
        uvI_dlerror(lib, "uv_dlsym: failed to sym "name); \
    } while (0)


typedef struct {
    int count;
    void *addrs[BACK_TRACE_SIZE];
} uvI_stacktrace_t;


typedef struct uvI_thread_s uvI_thread_t;
struct uvI_thread_s {
    uv_thread_t pthread;
    jmp_buf jmp[C_STACK_SIZE];
    int count;
    uvI_stacktrace_t *backtrace;
    uvI_thread_t *next;
};


extern uv_lib_t* uvI_dlopen(const char* filename);


extern void uvI_init();
extern uvI_thread_t* uvI_thread_new();
extern int uvI_thread_create(uvI_thread_t* thread, void (*entry)(void *arg), void* arg);

extern uvI_thread_t* uvI_thread_self();
extern uvI_thread_t* uvI_thread_pool(pthread_t pthread);
extern void uvI_thread_stacktrace(uvI_thread_t* thread);
extern const char* uvI_debug_stacktrace(uvI_thread_t* thread, lua_State* L);

extern int uvI_thread_breakpoint(uvI_thread_t* thread);
extern void uvI_thread_jmp(uvI_thread_t* thread, int num);

extern void uvI_thread_save(uvI_thread_t* thread);
extern void uvI_thread_restore(uvI_thread_t* thread);

extern void uvI_thread_free(uvI_thread_t* thread);


#endif /* UVI_H */
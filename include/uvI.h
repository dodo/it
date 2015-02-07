#ifndef UVI_H
#define UVI_H

#include <uv.h>

#include "it-types.h"
#include "it-errors.h"


#define uvI_dlsym(lib, name, var) \
    do{ if (uv_dlsym(lib,name, (void**) (var))) \
        uvI_dlerror(lib, "uv_dlsym: failed to sym "name); \
    } while (0)

#if UV_VERSION_MAJOR == 0 && UV_VERSION_MINOR == 10 // libuv 0.10

    #define uvI_loop_delete(loop) \
        (uv_loop_delete(loop))

#elif UV_VERSION_MAJOR >= 1 // libuv >=1.0

    #define uvI_loop_delete(loop) \
        do{ if (loop && !uv_loop_close(loop)) \
            free(loop); \
        } while (0)

#endif

typedef struct uvI_stacktrace_s uvI_stacktrace_t;
struct uvI_stacktrace_s {
    int count;
    void *addrs[BACK_TRACE_SIZE];
};


typedef struct uvI_thread_s uvI_thread_t;
struct uvI_thread_s {
    uv_thread_t pthread;
    uvI_stacktrace_t *backtrace;
    uvI_thread_t *next;
    int size;
    int count;
    bool safe;
    jmp_buf jmp[C_STACK_MINSIZE];
};


extern uv_lib_t* uvI_dlopen(const char* filename);


extern void uvI_init();
extern uvI_thread_t* uvI_thread_malloc();
extern uvI_thread_t* uvI_thread_new();
extern uvI_thread_t* uvI_thread_tmp();
extern int uvI_thread_create(uvI_thread_t* thread, void (*entry)(void *arg), void* arg);

extern uvI_thread_t* uvI_thread_self();
extern uvI_thread_t* uvI_thread_pool(pthread_t pthread);

extern int  uvI_thread_notch(uvI_thread_t* thread);
extern void uvI_thread_unnotch(uvI_thread_t* thread);

extern void uvI_thread_stacktrace(uvI_thread_t* thread);
extern const char* uvI_debug_stacktrace(uvI_thread_t* thread, lua_State* L);

extern int uvI_thread_breakpoint(uvI_thread_t* thread);
extern void uvI_thread_jmp(uvI_thread_t* thread, int num);

extern void uvI_thread_save(uvI_thread_t* thread);
extern void uvI_thread_restore(uvI_thread_t* thread);

extern void uvI_thread_free(uvI_thread_t* thread);


#endif /* UVI_H */

#ifndef IT_TYPES_H
#define IT_TYPES_H

#include <uv.h>
#include <lua.h>


#define stdnon  (FILE*) -1

#ifndef __cplusplus
  typedef enum { false, true } bool;
#endif

#define TRUE 1
#define FALSE 0

typedef struct {
    lua_State *lua;
    uv_loop_t *loop;
    const char *err;
    bool free;
} it_states;


typedef struct {
    it_states *ctx;
    uv_signal_t *sigint;
    int argc; char **argv;
    int exit_code;
} it_processes;


typedef void (*uvI_thread_callback) (void *priv);

typedef struct {
    it_states *ctx;
    uv_thread_t *thread;
    uv_idle_t *idle;
    uvI_thread_callback on_init;
    uvI_thread_callback on_idle;
    uvI_thread_callback on_free;
    bool closed;
    void* priv;
} it_threads;


#endif /* IT_TYPES_H */
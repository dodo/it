#ifndef IT_TYPES_H
#define IT_TYPES_H

#include <uv.h>
#include <lua.h>


#define stdnon  (FILE*) -1

#ifndef __cplusplus
    #include <stdbool.h>
#endif

#define TRUE 1
#define FALSE 0


typedef enum {
    LUAI_TYPE_NIL = 0,
    LUAI_TYPE_CDATA,
    LUAI_TYPE_NUMBER,
    LUAI_TYPE_STRING,
    LUAI_TYPE_BOOLEAN,
    LUAI_TYPE_MAX
} luaI_types;

typedef struct {
    luaI_types type;
    union {
        void* cdata;
        double number;
        const char* string;
        int boolean;
    } v;
} luaI_value;

typedef struct {
    int refc;
} it_refcounts;

typedef struct {
    int refc;
    lua_State *lua;
    uv_loop_t *loop;
    const char *err;
    bool safe;
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
    int refc;
    it_states *ctx;
    uv_thread_t *thread;
    uv_idle_t *idle;
    uvI_thread_callback on_init;
    uvI_thread_callback on_idle;
    uvI_thread_callback on_free;
    bool closed;
    void* priv;
} it_threads;



typedef struct it_queues it_queues;
typedef void (*uvI_async_callback) (void *priv, it_queues* queue);

typedef struct {
    int refc;
    it_threads *thread;
    uv_async_t *async;
    uv_mutex_t *mutex;
    it_queues  *queue;
    it_queues  *last;
    uvI_async_callback on_sync;
    void* priv;
} it_asyncs;

struct it_queues {
    it_queues *next;
    const char* key;
    luaI_value **values;
    int size;
    int count;
};


#endif /* IT_TYPES_H */

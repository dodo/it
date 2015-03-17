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


typedef enum _luaI_types {
    LUAI_TYPE_NIL = 0,
    LUAI_TYPE_CDATA,
    LUAI_TYPE_NUMBER,
    LUAI_TYPE_STRING,
    LUAI_TYPE_BOOLEAN,
    LUAI_TYPE_FUNCTION,
    LUAI_TYPE_CFUNCTION,
    LUAI_TYPE_MAX
} luaI_types;

typedef struct _luaI_userdata {
    void* pointer;
} luaI_userdata;

typedef struct _luaI_cfunction {
    lua_CFunction cfunction;
} luaI_cfunction;

typedef struct _luaI_function {
    size_t      size;
    char const* name;
    char const* dump;
} luaI_function;

typedef struct _luaI_value {
    luaI_types type;
    union {
        void* cdata;
        double number;
        const char* string;
        bool boolean;
        luaI_function* function;
        luaI_cfunction* cfunction;
    } v;
} luaI_value;

typedef struct _it_refcounts {
    int refc;
} it_refcounts;

typedef struct _it_states {
    int refc;
    lua_State *lua;
    const char *err;
    const char *name;
    bool safe;
} it_states;


typedef struct _it_processes {
    /* lua publics */
    int argc; char **argv;
    int exit_code;
    uv_loop_t *loop;
    /* lua privates */
    it_states *ctx;
    uv_idle_t *init;
    uv_signal_t *sigint;
} it_processes;


typedef void (*uvI_thread_callback) (void *priv);

typedef struct _it_threads {
    int refc;
    it_states *ctx;
    uv_thread_t *thread;
    uv_loop_t *loop;
    uv_idle_t *idle;
    uvI_thread_callback on_init;
    uvI_thread_callback on_idle;
    uvI_thread_callback on_free;
    const char *name;
    bool closed;
    bool stop;
    void* priv;
} it_threads;



typedef struct _it_queues it_queues;
typedef void (*uvI_async_callback) (void *priv, it_queues* queue);

typedef struct _it_asyncs {
    int refc;
    it_threads *thread;
    uv_async_t *async;
    uv_mutex_t *mutex;
    it_queues  *queue;
    it_queues  *last;
    uvI_async_callback on_sync;
    void* priv;
} it_asyncs;

struct _it_queues {
    it_queues *next;
    int size;
    int count;
    const char* key;
    luaI_value **values;
};


#endif /* IT_TYPES_H */

#ifndef IT_TYPES_H
#define IT_TYPES_H

#include <uv.h>
#include <lua.h>
#include <schroedinger/schro.h>
#include <oggz/oggz.h>

#define stdnon  (FILE*) -1


typedef struct {
    lua_State *lua;
    uv_loop_t *loop;
    schro_bool free;
} it_states;


typedef struct {
    it_states *ctx;
    uv_signal_t *sigint;
    int argc; char **argv;
    int exit_code;
} it_processes;

typedef struct {
    uv_loop_t *loop;
    uv_idle_t *idle;
    it_states *ctx;
    uv_thread_t *thread;
    SchroEncoder *encoder;
    OGGZ *container;
    ogg_int64_t granulepos;
    ogg_int64_t packetno;
    schro_bool eos_pulled;
    schro_bool closed;
    long serialno;
    int frames;
    int length;
    unsigned char *buffer;
} it_encodes;

typedef struct {
    schro_bool free;
    void *buffer;
} it_buffers;

typedef struct {
    SchroFrame *frame;
    int size;
    int width;
    int height;
} it_frames;


#endif /* IT_TYPES_H */
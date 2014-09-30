#ifndef IT_TYPES_H
#define IT_TYPES_H

#include <uv.h>
#include <lua.h>
#include <schroedinger/schro.h>


typedef struct {
    lua_State *lua;
    uv_loop_t *loop;
} it_states;


typedef struct {
    it_states *ctx;
    uv_signal_t *sigint;
    int argc; char **argv;
    int exit_code;
} it_processes;

typedef struct {
    SchroEncoder *encoder;
    uv_thread_t *thread;
    uv_loop_t *loop;
    uv_idle_t *idle;
    int frames;
    int size;
    int width;
    int height;
    uint8_t *buffer;
    schro_bool closed;
} it_encodes;

#endif /* IT_TYPES_H */
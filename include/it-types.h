#ifndef IT_TYPES_H
#define IT_TYPES_H

#include <uv.h>
#include <lua.h>


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

#endif /* IT_TYPES_H */
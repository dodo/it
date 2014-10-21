#ifndef IT_H
#define IT_H

#include <assert.h>

#include <uv.h>
#include <lua.h>

#include "it-types.h"

#define IT_NAMES "muSchro0m it"
#define IT_VERSIONS "0.0.1"

#define it_prints_error(msg, ...) \
        fprintf(stderr, "internal error: "msg"\n", ##__VA_ARGS__)

#define it_errors(msg, ...) { \
        it_prints_error(msg, ##__VA_ARGS__); \
        assert(0); \
    }

#define luaI_error(L, msg, ...) { \
        return luaL_error(L, "internal error: "msg, ##__VA_ARGS__); \
    }

#define uvI_error(loop,msg) { \
        uv_err_t err = uv_last_error(loop); \
        it_errors(msg, uv_err_name(err), uv_strerror(err)); \
    }

#define uvI_lua_error(L,loop,msg) { \
        uv_err_t err = uv_last_error(loop); \
        luaI_error(L, msg, uv_err_name(err), uv_strerror(err)); \
    }

#define sdlI_error(msg) { \
        it_errors(msg, SDL_GetError()); \
    }

#define sdlI_lua_error(L,msg) { \
        luaI_error(L, msg, SDL_GetError()); \
    }

int it_gets_cwd_lua(lua_State* L);


#endif /* IT_H */
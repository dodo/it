#ifndef IT_ERRORS_H
#define IT_ERRORS_H

#include <stdlib.h>

#include <uv.h>
#include <lua.h>


#define BACK_TRACE_SIZE 64


#define printerr(msg, ...) \
        fprintf(stderr, msg"\n", ##__VA_ARGS__)

#define it_prints_error(msg, ...) \
        printerr("internal error: "msg, ##__VA_ARGS__)

#define it_errors(msg, ...) { \
        it_prints_error(msg, ##__VA_ARGS__); \
        abort(); \
    }

#define luaI_error(L, msg, ...) { \
        return luaL_error(L, "internal error: "msg, ##__VA_ARGS__); \
    }

#define uvI_dlerror(lib, msg, ...) { \
         it_errors(msg" (%s)", ##__VA_ARGS__, uv_dlerror(lib)); \
    }

#define uvI_error(loop,msg) { \
        uv_err_t err = uv_last_error(loop); \
        it_errors(msg, uv_err_name(err), uv_strerror(err)); \
    }

#define uvI_lua_error(L, loop, msg) { \
        uv_err_t err = uv_last_error(loop); \
        luaI_error(L, msg, uv_err_name(err), uv_strerror(err)); \
    }

#define sdlI_error(msg) { \
        it_errors(msg, SDL_GetError()); \
    }

#define sdlI_lua_error(L, msg) { \
        luaI_error(L, msg, SDL_GetError()); \
    }


extern int at_panic(lua_State* L);
extern void at_fatal_panic(int signum);
extern int at_luajit_cfunction_call(lua_State* L, lua_CFunction func);

int luaI_stacktrace(lua_State* L);
int luaI_init_errorhandling(lua_State* L);


#endif /* IT_ERRORS_H */
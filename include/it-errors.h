#ifndef IT_ERRORS_H
#define IT_ERRORS_H

#include <stdlib.h>
#include <setjmp.h>

#include <uv.h>
#include <lua.h>


#define BACK_TRACE_SIZE 64
#define C_STACK_MINSIZE 2
#define IT_CHECKSUMS 42


#define putz(s, ...) \
        printf("%d "s"\n", uvI_thread_pool_index(pthread_self()), ##__VA_ARGS__)

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

#define uvI_lua_dlerror(L, lib, msg, ...) { \
         luaI_error(L, msg" (%s)", ##__VA_ARGS__, uv_dlerror(lib)); \
    }

#if UV_VERSION_MAJOR == 0 && UV_VERSION_MINOR == 10 // libuv 0.10

    #define uvI_error(loop, err, msg) { \
            uv_err_t err = uv_last_error(loop); \
            it_errors(msg, uv_err_name(err), uv_strerror(err)); \
        }

    #define uvI_lua_error(L, loop, err, msg) { \
            uv_err_t err = uv_last_error(loop); \
            luaI_error(L, msg, uv_err_name(err), uv_strerror(err)); \
        }

#elif UV_VERSION_MAJOR >= 1 // libuv >=1.0

    #define uvI_error(loop, err, msg) { \
            it_errors(msg, uv_err_name(err), uv_strerror(err)); \
        }

    #define uvI_lua_error(L, loop, err, msg) \
        do{ if (loop && !uv_loop_close(loop)) \
            free(loop); \
        } while (0)

#endif

#define sdlI_error(msg) { \
        it_errors(msg, SDL_GetError()); \
    }

#define sdlI_lua_error(L, msg) { \
        luaI_error(L, msg, SDL_GetError()); \
    }


extern int at_panic(lua_State* L);
extern void at_fatal_panic(int signum);
extern int luaI_xpcall(lua_State* L, int nargs, int nresults, int safe);
extern int luaI_pcall_with(lua_State* L, int nargs, int nresults, lua_CFunction f);

extern int luaI_stacktrace(lua_State* L);
extern int luaI_simpleerror(lua_State* L);
extern int luaI_init_errorhandling(lua_State* L);


#endif /* IT_ERRORS_H */

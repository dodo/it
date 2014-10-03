#ifndef IT_H
#define IT_H

#include <assert.h>

#include <uv.h>
#include <lua.h>

#include "it-types.h"


#define uvI_error(loop,msg) { \
        uv_err_t err = uv_last_error(loop); \
        fprintf(stderr, "internal error: "msg"\n", uv_err_name(err), uv_strerror(err)); \
        assert(0); \
    }

#define uvI_lua_error(L,loop,msg) { \
        uv_err_t err = uv_last_error(loop); \
        return luaL_error(L, "internal error: "msg, uv_err_name(err), uv_strerror(err)); \
    }


int it_gets_cwd_lua(lua_State* L);


#endif /* IT_H */
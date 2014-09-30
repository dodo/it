#include "lua/process.h"

#include "it.h"
#include "luaI.h"


int it_exits_process_lua(lua_State* L) {
    it_processes* process = luaI_getprocess(L);
    int code = 0;
    if (lua_gettop(L) && !lua_isnil(L, 1))
        code = luaL_checkint(L, 1);
    process->exit_code = code;
    uv_stop(process->ctx->loop);
    return 0;
}

int it_gets_cwd_process_lua(lua_State* L) {
    lua_pushstring(L, getcwd(NULL, 0)); // thanks to gnu c
    return 1;
}

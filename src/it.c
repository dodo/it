#include "it.h"

#include "luaI.h"


int it_runs_ctx(it_states* ctx) {
    luaI_getglobalfield(ctx->lua, "context", "run");
    if (lua_pcall(ctx->lua, 0, 0, 0)) {
        return lua_error(ctx->lua);
    }
    return 0;
}

int it_gets_cwd_lua(lua_State* L) {
    lua_pushstring(L, getcwd(NULL, 0)); // thanks to gnu c
    return 1;
}

int it_exits_lua(lua_State* L) {
    it_processes* process = luaI_getprocess(L);
    int code = 0;
    if (lua_gettop(L))
        code = luaL_checkint(L, 1);
    process->exit_code = code;
    uv_stop(process->ctx->loop);
    return 0;
}

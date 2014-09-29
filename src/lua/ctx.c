#include "lua/ctx.h"

#include "it.h"
#include "luaI.h"


int it_imports_ctx_lua(lua_State* L) {
    it_states* ctx = luaL_checkudata(L, 1, "Context");
    luaL_checktype(L, 2, LUA_TFUNCTION);
    lua_pushvalue(L, 2);
    // copy function and import into context
    luaI_getglobalfield(ctx->lua, "context", "import");
    luaI_copyfunction(ctx->lua, L);
    if (lua_pcall(ctx->lua, 1, 0, 0)) {
        return lua_error(ctx->lua);
    }
    return 0;
}

int it_calls_ctx_lua(lua_State* L) {
    it_runs_ctx(luaL_checkudata(L, 1, "Context"));
    return 0;
}

int it_kills_ctx_lua(lua_State* L) {
    it_states* ctx = luaL_checkudata(L, 1, "Context");
    lua_close(ctx->lua);
    ctx->loop = NULL;
    return 0;
}

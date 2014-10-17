#include "it.h"
#include "luaI.h"

#include "lua/ctx.h"


void it_frees_ctx(it_states* ctx) {
    if (ctx->free && ctx->lua) {
        luaI_close(ctx->lua, "context", -1);
        ctx->lua = NULL;
    }
    if (ctx->free && ctx->loop) {
        ctx->loop = NULL;
    }
    ctx->free = FALSE;
}


int it_new_ctx_lua(lua_State* L) { // ()
    it_states* state = luaI_getstate(L);
    it_states* ctx = lua_newuserdata(L, sizeof(it_states));
    ctx->loop = state->loop;
    if (luaI_newstate(ctx)) {
        lua_pushnil(L);
        return 1;
    }
    luaI_setmetatable(L, "Context");
    luaI_dofile(ctx->lua, "lib/context.lua");
    return 1;
}

int it_imports_ctx_lua(lua_State* L) { // (state_userdata, function)
    it_states* ctx = luaL_checkudata(L, 1, "Context");
    luaL_checktype(L, 2, LUA_TFUNCTION);
    lua_pushvalue(L, 2);
    // copy function and import into context
    luaI_getglobalfield(ctx->lua, "context", "import");
    luaI_copyfunction(ctx->lua, L);
    luaI_pcall(ctx->lua, 1, 0);
    return 0;
}

int it_calls_ctx_lua(lua_State* L) { // (state_userdata)
    it_states* ctx = luaL_checkudata(L, 1, "Context");
    luaI_getglobalfield(ctx->lua, "context", "run");
    luaI_pcall(ctx->lua, 0, 0);
    return 0;
}

int it_kills_ctx_lua(lua_State* L) { // (state_userdata)
    it_states* ctx = luaL_checkudata(L, 1, "Context");
    it_frees_ctx(ctx);
    return 0;
}

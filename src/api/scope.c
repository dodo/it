#include "it.h"
#include "luaI.h"
#include "core-types.h"

#include "api/scope.h"


int it_imports_scope_lua(lua_State* L) { // (ctx_userdata, lua_function)
    it_states* ctx = (it_states*) lua_touserdata(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);
    lua_pushvalue(L, 2);
    // copy function and import into context
    luaI_getglobalfield(ctx->lua, "context", "import");
    luaI_copyfunction(ctx->lua, L);
    luaI_pcall_in(ctx, 1, 0);
    return 0;
}

int it_defines_scope_lua(lua_State* L) { // (ctx_userdata, name, value)
    it_states*  ctx = (it_states*) lua_touserdata(L, 1);
    const char* name = lua_tostring(L, 2);
    luaI_value* value = luaI_getvalue(L, 3);
    if (!value) return 0;
    luaI_pushvalue(ctx->lua, value);
    luaI_setdefine(ctx->lua, name);
    free(value);
    return 0;
}

void it_inits_scope(it_states* ctx, it_processes* process, it_states* state) {
    ctx->loop = state->loop;
    if (luaI_newstate(ctx)) return;
    lua_pushlightuserdata(ctx->lua, process);
    luaI_setdefine(ctx->lua, "_it_processes_");
    luaI_dofile(ctx->lua, luaI_getlibpath(ctx->lua, "context.lua"));
}

void it_defines_cdata_scope(it_states* ctx, const char* name, void* cdata) {
    if (!ctx) return;
    lua_pushlightuserdata(ctx->lua, cdata);
    luaI_setdefine(ctx->lua, name);
}

void it_calls_scope(it_states* ctx) {
    if (!ctx) return;
    luaI_getglobalfield(ctx->lua, "context", "run");
    luaI_pcall_in(ctx, 0, 0);
}

void it_frees_scope(it_states* ctx) {
    if (!ctx) return;
    // scope always referenced in itself
    if (ctx->free && it_unrefs((it_refcounts*) ctx) > 1) return;
    if (ctx->free && ctx->lua) {
        lua_State* L = ctx->lua;
        ctx->lua = NULL;
        // might take a while …
        luaI_close(L, "context", -1);
    }
    if (ctx->free && ctx->loop) {
        ctx->loop = NULL;
    }
    ctx->free = FALSE;
}

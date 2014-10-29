#include "it.h"
#include "luaI.h"

#include "api/scope.h"


int it_imports_scope_lua(lua_State* L) {
    it_states* ctx = (it_states*) lua_touserdata(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);
    lua_pushvalue(L, 2);
    // copy function and import into context
    luaI_getglobalfield(ctx->lua, "context", "import");
    luaI_copyfunction(ctx->lua, L);
    luaI_pcall(ctx->lua, 1, 0);
    return 0;
}

void it_inits_scope(it_states* ctx, it_processes* process, it_states* state) {
    ctx->loop = state->loop;
    if (luaI_newstate(ctx)) return;
    lua_pushlightuserdata(ctx->lua, process);
    luaI_setglobalfield(ctx->lua, "_it", "process");
    luaI_dofile(ctx->lua, "lib/context.lua");
}

void it_defines_cdata_scope(it_states* ctx, const char* name, void* cdata) {
    if (!ctx) return;
    lua_pushlightuserdata(ctx->lua, cdata);
    lua_setglobal(ctx->lua, name);
}

void it_defines_number_scope(it_states* ctx, const char* name, double number) {
    if (!ctx) return;
    lua_pushnumber(ctx->lua, number);
    lua_setglobal(ctx->lua, name);
}

void it_defines_string_scope(it_states* ctx, const char* name, const char* string) {
    if (!ctx) return;
    lua_pushstring(ctx->lua, string);
    lua_setglobal(ctx->lua, name);
}

void it_calls_scope(it_states* ctx) {
    if (!ctx) return;
    luaI_getglobalfield(ctx->lua, "context", "run");
    luaI_pcall(ctx->lua, 0, 0);
}

void it_frees_scope(it_states* ctx) {
    if (!ctx) return;
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
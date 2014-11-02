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
    luaI_setdefine(ctx->lua, "process");
    luaI_dofile(ctx->lua, "lib/context.lua");
}

void it_defines_cdata_scope(it_states* ctx, const char* name, void* cdata) {
    if (!ctx) return;
    lua_pushlightuserdata(ctx->lua, cdata);
    luaI_setdefine(ctx->lua, name);
}

void it_defines_number_scope(it_states* ctx, const char* name, double number) {
    if (!ctx) return;
    lua_pushnumber(ctx->lua, number);
    luaI_setdefine(ctx->lua, name);
}

void it_defines_string_scope(it_states* ctx, const char* name, const char* string) {
    if (!ctx) return;
    lua_pushstring(ctx->lua, string);
    luaI_setdefine(ctx->lua, name);
}

void it_defines_boolean_scope(it_states* ctx, const char* name, int b) {
    if (!ctx) return;
    lua_pushboolean(ctx->lua, b);
    luaI_setdefine(ctx->lua, name);
}

void it_calls_scope(it_states* ctx) {
    if (!ctx) return;
    lua_getglobal(ctx->lua, "_TRACEBACK");
    luaI_getglobalfield(ctx->lua, "context", "run");
    if (lua_pcall(ctx->lua, 0, 0, -2)) {
        ctx->err = lua_tostring(ctx->lua, -1);
    }
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

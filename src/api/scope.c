#include "it.h"
#include "uvI.h"
#include "luaI.h"
#include "core-types.h"

#include "api/scope.h"


it_states* it_allocs_scope() {
    it_states* ctx = (it_states*) calloc(1, sizeof(it_states));
    if (!ctx)
        it_errors("calloc(1, sizeof(it_states)): failed to allocate scope");
    ctx->refc = 1;
    ctx->safe = TRUE;
    return ctx;
}

int it_imports_scope_lua(lua_State* L) { // (ctx_userdata, lua_function)
    it_states* ctx = (it_states*) lua_touserdata(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);
    lua_pushvalue(L, 2);
    // copy function and import into context
    luaI_getglobalfield(ctx->lua, "process", "context");
    luaI_getlocalfield(ctx->lua, "import");
    luaI_copyfunction(ctx->lua, L);
    luaI_pcall_in(ctx, 1, 0);
    return 0;
}

int it_defines_scope_lua(lua_State* L) { // (ctx_userdata, name, value)
    it_states*  ctx = (it_states*) lua_touserdata(L, 1);
    const char* name = lua_tostring(L, 2);
    luaI_value* value = luaI_getvalue(L, 3);
    if (!value || !ctx->lua) return 0;
    luaI_pushvalue(ctx->lua, value);
    luaI_setdefine(ctx->lua, name);
    free(value);
    return 0;
}

void it_inits_scope(it_states* ctx, it_processes* process) {
    if (!ctx) return;
    if (luaI_newstate(NULL, ctx)) return;
    ctx->err = NULL;
    luaI_setprocess(ctx->lua, process);
    luaI_dofile(ctx->lua, luaI_getlibpath(ctx->lua, "context.lua"));
}

void it_defines_cdata_scope(it_states* ctx, const char* name, void* cdata) {
    if (!ctx || !ctx->lua) return;
    lua_pushlightuserdata(ctx->lua, cdata);
    luaI_setdefine(ctx->lua, name);
}

void it_calls_scope(it_states* ctx) {
    if (!ctx || !ctx->lua) return;
    luaI_getglobalfield(ctx->lua, "process", "context");
    luaI_getlocalfield(ctx->lua, "run");
    luaI_pcall_in(ctx, 0, 0);
    it_collectsgarbage_scope(ctx);
}

void it_collectsgarbage_scope(it_states* ctx) {
    if (!ctx || !ctx->lua) return;
    // free all unused data and other stuff
    if (!ctx->err) luaI_gc(ctx->lua);
}

void it_closes_scope(it_states* ctx) {
    if (!ctx) return;
    if (ctx->lua) {
        lua_State* L = ctx->lua;
        ctx->lua = NULL;
        // might take a while …
        lua_getglobal(L, "process");
        luaI_close(L, -1);
    }
}

void it_frees_scope(it_states* ctx) { // = __gc
    if (!ctx) return;
    if (it_unrefs((it_refcounts*) ctx) > 0) return;
    it_closes_scope(ctx);
    if (!ctx->refc) // just to be sure
        free(ctx);
}

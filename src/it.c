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

int it_boots_lua(lua_State* L) {
    it_processes* process = luaI_getprocess(L);
    // process.argv
    lua_createtable(L, process->argc, 0);
    int i; for (i = 0; i < process->argc; i++) {
        lua_pushstring(L, process->argv[i]);
        lua_rawseti(L, -2, i);
    }
    lua_setfield(L, -2, "argv");
    // process.exit
    lua_pushcfunction(L, it_exits_lua);
    lua_setfield(L, -2, "exit");
    // process.cwd
    lua_pushcfunction(L, it_gets_cwd_lua);
    lua_setfield(L, -2, "cwd");
    // process.pid
    lua_pushinteger(L, getpid());
    lua_setfield(L, -2, "pid");
    return 0;
}

int it_forks_lua(lua_State* L) {
    it_states* ctx;
    it_states* state = luaI_getstate(L);
    ctx = lua_newuserdata(L, sizeof(it_states));
    ctx->loop = state->loop;
    ctx->lua = luaI_newstate(ctx);
    luaI_setmetatable(L, "Context");
    lua_createtable(ctx->lua, 0, 1);
    lua_pushcfunction(ctx->lua, it_forks_lua);
    lua_setfield(ctx->lua, -2, "forks");
    lua_setglobal(ctx->lua, "_it");
    luaI_dofile(ctx->lua, "lib/context.lua");
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

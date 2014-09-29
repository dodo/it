#include "lua/it.h"

#include "it.h"
#include "luaI.h"


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
    if (luaI_newstate(ctx)) {
        lua_pushnil(L);
        return 1;
    }
    luaI_setmetatable(L, "Context");
    lua_createtable(ctx->lua, 0, 1);
    lua_pushcfunction(ctx->lua, it_forks_lua);
    lua_setfield(ctx->lua, -2, "forks");
    lua_setglobal(ctx->lua, "_it");
    luaI_dofile(ctx->lua, "lib/context.lua");
    return 1;
}
